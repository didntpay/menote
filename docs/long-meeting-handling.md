# Long-meeting handling — implementation plan

## Problem

End-to-end on a 1-hour recording today:

```
[ End click ]
    │
    ├─ transcribe          ~6–15 min  ← static "transcribing" the whole time
    ├─ Claude /v1/messages ~30–60 s   ← spinner
    └─ persist             instant
    Total: 7–16 min of spinner
```

Two specific failure modes:

1. **No progress signal during transcribe.** WhisperKit is chunking internally
   (30 s windows) but we don't surface it. User can't tell if it's working,
   stalled, or about to crash.
2. **Single non-streaming Claude call.** 30–60 s of dead air after the
   transcript is ready. With a 4 000-token transcript the API call returns
   long before Claude is "done thinking" — we just don't see it.

Neither requires re-architecting. WhisperKit already supports a callback
form; Anthropic already supports streaming.

## Goals

- Real per-segment progress during transcription.
- Cancellable pipeline (transcribe + LLM both abortable).
- Streaming Claude responses so generation feels interactive.
- Handle multi-hour recordings without quality loss (action-item dedup, etc.).

## Non-goals

- Custom audio chunking on our side. WhisperKit's internal 30 s windows are
  already correct; manually pre-splitting the file introduces boundary
  errors and parallel-CoreML OOM risk.
- Multi-pass Claude for short meetings. The single-shot call is *better*
  quality (full context = better dedup) for anything under ~45 min.

---

## Phase 1 — WhisperKit live progress + cancel

### Code delta

`WhisperKitTranscriber.swift`:

```swift
let results = try await pipe.transcribe(audioPath: audioURL.path) { [weak self] result in
    // Fires after each ~30s decoded window.
    let frac = Double(result.timings.totalDecodingFallbacks) / ...  // exact field name TBD; depends on WhisperKit 0.18 surface
    Task { @MainActor in
        self?.onProgress?("transcribing", frac)
    }
    return !Task.isCancelled   // returning false stops WhisperKit cleanly
}
```

`AppController.swift`:

```swift
private var pipelineTask: Task<Void, Never>?

func endRecording() {
    ...
    pipelineTask = Task { await runGenerationPipeline(session: session) }
}

func cancelGeneration() {
    pipelineTask?.cancel()
    pipelineTask = nil
    appState = .idle
    // delete the un-persisted session dir on disk
}
```

### UI

Sidebar `.generating` cell gets a Cancel control next to the progress text:

```
[ ◌ transcribing · 47%        ✕ ]
```

### Edge cases

- **Cancel during model download.** Let it finish — partial model files cause
  WhisperKit to redownload from scratch on next attempt.
- **Cancel during transcribe.** Discard partial transcript, delete the session
  directory, return to `.idle`. No persisted meeting record.
- **Cancel during Claude call.** `URLSession.data(for:)` respects `Task.cancel()`
  natively. The streaming variant (Phase 2) will need explicit handling.

### Done when

- 1-hour transcript shows progress incrementing every 2–4 s.
- Clicking ✕ during transcribe returns the app to idle within 1 s.
- No leftover files in `meetings/` for cancelled sessions.

### Effort

~½ day.

---

## Phase 2 — Streaming Claude

### How Anthropic streams `tool_use`

The streaming endpoint emits SSE events. The relevant ones for forced tool
output:

```
event: message_start
event: content_block_start    {type: "tool_use", id, name}
event: content_block_delta    {type: "input_json_delta", partial_json: "{\"title\": \"Roadmap"}
event: content_block_delta    {type: "input_json_delta", partial_json: " review · Q2\""}
...
event: content_block_stop
event: message_stop
```

`partial_json` strings are fragments — concatenating them gives the full
JSON object that the existing decoder consumes today.

### Two strategies

**Strategy A — Buffer and finalise (recommended first cut)**

Concatenate all `partial_json` deltas into a string buffer. When the stream
ends, decode the complete buffer with `JSONDecoder`.

User-facing change: while streaming, emit a synthetic progress signal
(`bytes received / expected bytes`, or just a rolling indeterminate animation)
so the pill shows `writing notes · 45%` advancing live instead of frozen.

Pros: ~50 lines of net change. Same decoder. Cancellable via `URLSession.bytes`.
Cons: notes don't render field-by-field — full reveal at end.

**Strategy B — Progressive field reveal**

Same buffer accumulation, plus a partial-JSON parser that emits fields as
they become complete. As `title` is fully written into the buffer, push it
to `NotesController` and re-render. Then `summary`. Then each `actionItem`
appears as its `}` arrives.

Pros: notes feel alive — title in ~2 s, summary streaming line-by-line,
action items popping in one at a time.

Cons: need a tolerant JSON parser. `JSONDecoder` requires complete JSON.
Three options:

- **Bracket-balance + field slice** — ~80 lines. Watch the buffer for
  `"title":"..."` patterns, slice when the closing `"` (with proper escape
  handling) lands. Brittle if schema changes.
- **Recursive descent parser for our schema** — ~150 lines. Robust but
  schema-coupled.
- **swift-json-stream** (3rd party) — adds dep; quality unknown.

### Recommended sequence

1. Build Strategy A first. Ship it. Use it.
2. If 30–60 s spinner-during-streaming still feels too long, add B's
   progressive parser on top. Same streaming plumbing, only the consumer
   changes.

### Stream consumption shape

```swift
let (bytes, response) = try await URLSession.shared.bytes(for: request)

var buffer = ""
for try await line in bytes.lines {
    guard line.hasPrefix("data: ") else { continue }
    let json = String(line.dropFirst(6))
    if let event = parseSSEEvent(json) {
        switch event {
        case .inputJsonDelta(let frag):
            buffer.append(frag)
            await onProgress?("writing notes", estimatedFraction(buffer))
        case .messageStop:
            break
        ...
        }
    }
}
return try JSONDecoder().decode(NotesData.self, from: Data(buffer.utf8))
```

### Edge cases

- **Network drop mid-stream.** Anthropic streams don't auto-resume. We lose
  the partial buffer and have to retry from scratch. Surface as `.error`
  with a "Retry" affordance.
- **`event: error` mid-stream.** Discard the buffer, surface the error
  payload to the user, return to `.idle`.
- **Backpressure.** Claude streams at 30–50 tok/sec; SwiftUI renders at 60
  Hz. We're fine. If it ever becomes a problem, debounce `onProgress` to
  100 ms.

### Done when (Strategy A)

- Streaming pill shows a moving progress percentage during the Claude call.
- Cancel button stops the stream within 200 ms.
- Network drop produces a `.error` state with a retry path.
- Quality matches non-streaming output (same prompt, same `tool_use`).

### Effort

~½ day for A. ~1 day extra if we add B.

---

## Phase 3 — Long-meeting chunking (optional, threshold-gated)

### When this earns its complexity

Only above ~45 min of transcript (~8 000 input tokens). Below that, the
single-shot Claude call is fast enough with streaming and quality is better
(full context = better action-item dedup).

If we never record meetings > 45 min, skip this phase entirely.

### Map-reduce shape

```
transcript
    │
    ├─ slice into ~10-min chunks
    │
    ├─► 5× extract pass (parallel)
    │     prompt: "Segment 3 of 5. Earlier covered: {running summary}.
    │             Extract action items + key points from THIS segment."
    │     output: { keyPoints: [...], actionItems: [...] }
    │
    └─► consolidate pass (single call)
          prompt: "Here are 5 partial extractions from a meeting transcript.
                   Synthesize one coherent notes document. Dedupe action
                   items. Write a unified summary."
          output: NotesData
```

### Trade-offs

- **Parallel speedup**: 5 chunks in parallel ≈ 20 s vs 60 s for one big call.
  Wall-time win.
- **6× API cost**: still cents. Not a real concern.
- **Action-item dedup**: weaker than single-shot. The consolidate pass sees
  partial extractions, not raw transcript context. Worth A/B testing on real
  multi-hour meetings before committing.
- **Streaming during chunked mode**: only the consolidate pass streams.
  Per-chunk extractions are non-streaming. UI shows
  `extracting · 3 of 5 complete` then switches to streaming for the merge.

### When to build

After Phase 1 + 2 are live and stable. We'll only know if it's needed by
recording actual long sessions.

### Effort

~1 day if we decide to do it.

---

## Order of operations

1. **Phase 1** (½ day) — ship, use for a week.
2. **Phase 2-A** (½ day) — ship, use for a week.
3. **Phase 2-B** (1 day, optional) — only if 2-A still feels slow.
4. **Phase 3** (1 day, optional) — only if long-meeting recordings become
   common AND single-shot starts dropping action items.

Three to four half-days total. Each phase has a clear done-criteria above.

## Risks and unknowns

- WhisperKit 0.18's `transcribe(audioPath:callback:)` signature differs from
  the older docs. Need to verify the exact callback shape before writing
  Phase 1 code.
- Anthropic's streaming + `tool_use` is documented but I haven't shipped it
  in Swift before. First implementation may discover SSE-parsing quirks.
- Cancellation through SwiftUI's `Task.isCancelled` works for our code but
  WhisperKit's internal `for await` loops may or may not respect it. Worst
  case: cancellation is silent until the next callback fires (2–4 s lag).

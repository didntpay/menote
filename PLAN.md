# Menote — Product plan

A local-first, Granola-style meeting notes app for macOS. Manual mode: the user
clicks a button to start recording; the app transcribes locally with WhisperKit
and synthesises notes via Claude.

**Status**: post-MVP. The end-to-end loop (record → on-device transcribe →
Claude notes → local storage → display) ships and works for typical meetings.
Active focus is now on UX polish for longer meetings, distribution path, and
post-recording editing. See **Roadmap** below.

---

## Current product surface

- **Platform**: macOS 14.0+
- **Mode**: Manual only — user clicks **Start note-taking** to begin
- **In-meeting UI**: floating recorder panel (timer, pause, end, mic meter)
- **Generation UX**: ambient — recorder closes when user clicks End; progress
  shown as a menu-bar pill; macOS notification fires when notes are ready
- **Notes layout**: actions-first — action items at top, then summary, then key
  points; transcript on a separate tab
- **Storage**: fully local (audio + transcript + notes as files)
- **Network**: only outbound calls are (1) WhisperKit downloading the model on
  first run, (2) Claude API for note synthesis
- **Global shortcut**: `⌘⇧R` starts recording from anywhere
- **Signing**: Personal Team / Apple Development cert (per-developer via
  `Local.xcconfig`). Stable identity, no Keychain or TCC re-prompts on rebuild

### Out of scope (current)

- Calendar integration / auto-detection
- Sharing, collaboration, cloud sync
- Live transcript view during the meeting
- User typing during the meeting (no title input, tags, or jot textarea)
- Task-system integrations (Linear/Asana/etc. chips on action items —
  `externalRef` field is reserved in the schema)
- Custom templates (single hardcoded prompt)
- Speaker diarisation (`speakerId` field reserved in the schema)
- Editing notes after generation (read-only; data model ready for it)
- Notarisation / Developer ID Application signing (needed before broad
  distribution; requires Apple Developer Program)
- System audio capture (intentionally dropped — see Decisions log)

---

## Visual theme

Modern light cream aesthetic — clean typography, restrained color, native
SwiftUI primitives. The original "paper / handwritten" direction was
abandoned because SwiftUI couldn't render the irregular borders and bundled
fonts faithfully on macOS.

- **Background**: warm off-white cream (`#FAF7F0`), used for both sidebar and
  content (unified canvas; vertical 1pt divider between them)
- **Cards**: pure white with 1pt `#E8E3D5` border + 4% shadow
- **Title bar**: transparent + `.fullSizeContentView` so backgrounds extend up
- **Accent pill** (for action-items badge): peach `#F4D7B5` / `#8C4F1F`
- **Typography**: SF Pro Text throughout, 30pt semibold for meeting titles,
  small-caps tracked labels for `SUMMARY` / `KEY POINTS`
- **Recording dot**: pulsing red `#C0392B`, frozen when paused

---

## Core flows

### Flow 1 — Launch
- Menu bar icon + main window
- Click icon (or press `⌘⇧R`) → focuses main window and starts recording

### Flow 2 — Sidebar
- Meetings grouped by **Today / This Week / Earlier** with relative timestamps
- Click any meeting to open its notes in the detail pane

### Flow 3 — First-run permissions (one-time)
- Microphone permission via the standard system prompt
- If previously denied, **Open Settings** button deep-links to
  `System Settings → Privacy & Security → Microphone`
- Auto-refreshes status when the user returns from System Settings

### Flow 4 — Start meeting
- Click **Start note-taking** (or press `⌘⇧R`)
- Floating recorder panel appears (~320×140, always on top, draggable):
  ```
  ●  00:42        ⏸  ⏹
  ▮▮▮▮▮▮▮▮▮▯▯▯▯▯▯▯▯▯▯▯▯▯▯▯
  ```
  - Red dot: pulsing while active, frozen when paused
  - Yellow pause button (compact glyph) → Pause / Resume
  - Red stop button (compact glyph) → End meeting
  - Mic level meter (24-bar waveform-shaped)

### Flow 5 — Menu-bar pill while recording
- Menu bar shows `● 12:34` with elapsed time updating each second
- Click the menu-bar icon → re-opens the recorder window

### Flow 6 — End → ambient generation
1. User clicks ⏹ in the recorder
2. Recorder window closes
3. Menu bar pill cycles through stages:
   - `preparing model` (first run only) or `loading model`
   - `downloading model · 47%` (first run only)
   - `transcribing` *(currently a single block; live progress is on the roadmap)*
   - `writing notes · 78%`
   - `finishing up · 99%`
4. macOS notification: *"Notes for {title} are ready · N action items"*
5. Pill briefly shows `✓ notes ready` then clears

### Flow 7 — Notes window (actions-first)

Two tabs: **Notes** and **Transcript**.

**Notes** tab:
```
Roadmap review · Q2                          (30pt semibold)
Sat, May 17 · 10:42 AM   42 min   [3 action items]

┌─ ○ Action items                          1 of 3 done ─┐
│  ☐  Share onboarding spec                              │
│     Maya · by Tue                                      │
│  ☐  Scope migration ticket                             │
│     Ravi · this sprint                                 │
│  ☑  Schedule follow-up review                          │
│     auto · invite sent                                 │
└────────────────────────────────────────────────────────┘

SUMMARY
The team aligned on onboarding rewrite as Q2's top priority…

KEY POINTS
•  Onboarding rewrite is the Q2 priority
•  Engineering needs ~3 weeks of migration runway
```

**Transcript** tab: timestamped segments, monospaced timecodes.

- Action items are checkable; state persists in `notes.json`.
- Otherwise read-only (editing is on the roadmap).

### Flow 8 — Past meetings
- Click any sidebar row → opens its notes
- Read-only today

### Flow 9 — Pause
- Pause stops mic capture (creates a gap in audio); resume starts a new segment
- Segments concatenated automatically by AVAudioRecorder

---

## Architecture

```
┌─ Menote (macOS app, signed with Personal Team) ────┐
│                                                    │
│  Menu bar icon + global ⌘⇧R                        │
│  Main window (sidebar + Notes/Transcript detail)   │
│  Floating recorder (~320×140)                      │
│  Menu-bar pill (live timer / generating progress)  │
│  macOS notification → focuses Notes view           │
│                                                    │
└────────────────┬───────────────────────────────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
   AVAudioRecorder    WhisperKit (small.en, on-device CoreML)
   (mic capture)            │
        │                   ▼
        └─► audio.m4a → transcript.json
                                │
                                ▼
                       Claude API (direct from app, user's key in Keychain)
                                │
                                ▼
                          notes.json
                                │
                                ▼
                    JSON files (local filesystem)
```

No backend server. Swift app calls Claude directly using the user's API key.

### MVC layering

- `AppController` — top-level coordinator. Owns state (`appState`,
  `recentMeetings`, `notesJustReady`), drives the generation pipeline.
- `RecorderController` — recording lifecycle, owns `AudioCaptureManager`.
- `NotesController` — opens past meetings, persists action-item toggles.
- Views are display-only. State flows via `@Published` and `Combine` forwarders.

---

## Tech stack

| Layer | Choice | Notes |
|---|---|---|
| Shell | Swift + SwiftUI | Pure native; no WKWebView |
| Mic capture | AVAudioRecorder | AAC m4a, 44.1 kHz mono |
| Transcription | [WhisperKit](https://github.com/argmaxinc/WhisperKit) | Swift-native, CoreML, Neural Engine on Apple Silicon |
| Whisper model | `openai_whisper-small.en` (~466 MB) | Downloaded once on first transcription |
| LLM | Claude Sonnet 4.6 via Anthropic API | Forced `tool_use` for structured JSON output |
| Notifications | UserNotifications framework | Native macOS notification on done |
| Global shortcut | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | `⌘⇧R` |
| Storage | JSON files | One directory per meeting; `meetings.json` index |
| API key storage | macOS Keychain | User-provided in Settings |
| Project gen | [xcodegen](https://github.com/yonaskolb/XcodeGen) | `project.yml` is source of truth |
| Signing | Personal Team via `Local.xcconfig` (gitignored) | Stable identity, no TCC/keychain re-prompts |

---

## Extensibility seams (already in place)

These aren't shipping today but the architecture leaves clean hooks:

- **Editing notes** — notes are structured JSON (title, summary, keyPoints,
  actionItems), not parsed markdown. Mutate fields directly.
- **Diarisation** — transcript schema is `segments: [{ start, end, text, speakerId? }]`.
  Drop in a diariser by populating the field.
- **Pluggable transcription** — `Transcriber` protocol. WhisperKit today;
  whisperX, cloud STT, etc. behind the same interface.
- **Pluggable LLM** — `NotesGenerator` protocol. Claude today; on-device
  Foundation Models, OpenAI, etc. later.
- **Task-system integrations** — action items have an optional `externalRef`
  field reserved for future Linear/Asana sync.

---

## Data model

### Filesystem layout

```
~/Library/Application Support/Menote/
├── meetings.json                  # index (array of MeetingRecord)
└── meetings/
    └── <uuid>/
        ├── audio.m4a              # mic only
        ├── transcript.json        # WhisperKit output + timestamps
        └── notes.json             # Claude output (structured)
```

### Transcript JSON

```json
{
  "language": "en",
  "segments": [
    { "start": 0.0, "end": 3.2, "text": "Hey, thanks for joining.", "speakerId": null }
  ]
}
```

### Notes JSON

```json
{
  "title": "Q2 roadmap sync",
  "summary": "Discussed shipping the notes editor and pushing diarisation to v1.2.",
  "keyPoints": ["Editor blocked on schema migration", "..."],
  "actionItems": [
    {
      "id": "uuid-here",
      "text": "Spike CoreML diarisation",
      "owner": "Wei",
      "due": null,
      "done": false,
      "externalRef": null
    }
  ]
}
```

`done` is local-only checkbox state. `externalRef` is reserved for future
task-system sync.

---

## LLM prompt

Forced tool use via Anthropic's `tool_choice: { type: "tool", name: "create_meeting_notes" }`
so Claude must emit a `tool_use` block matching the schema:

```
Summarize this meeting transcript. Call create_meeting_notes with the result.

Prioritize action items — they appear first in the user's view, so extract
them carefully. Only include items that are explicitly stated as something
to do; do not invent.

- title: under 60 chars, descriptive of the meeting's main topic
- actionItems: explicit todos; include owner and due if stated, leave null if not
- summary: 2–3 sentences of what was discussed
- keyPoints: bullet-worthy discussion points (not action items)

Transcript:
{transcript}
```

---

## Project layout

```
Menote/
├── Menote.xcodeproj/         # generated by xcodegen; committed
├── Menote/
│   ├── App/                  # entry point, AppDelegate, controllers
│   │   ├── AppController.swift
│   │   ├── AppDelegate.swift
│   │   ├── MenoteApp.swift
│   │   ├── NotesController.swift
│   │   ├── RecorderController.swift
│   │   └── StatusBarController.swift
│   ├── Core/
│   │   ├── Audio/            # AVAudioRecorder
│   │   ├── Keychain/         # API key
│   │   ├── LLM/              # NotesGenerator protocol + Claude impl
│   │   ├── Notifications/    # UserNotifications wrapper
│   │   ├── Storage/          # MeetingStore + models + grouping helpers
│   │   └── Transcription/    # Transcriber protocol + WhisperKit impl
│   ├── Theme/                # design tokens, SectionLabel, Pill, .card()
│   ├── Views/                # SwiftUI views, grouped by feature
│   │   ├── Main/             # MainView, sidebar, tabs
│   │   ├── Notes/            # NotesView + TranscriptView
│   │   ├── Recorder/         # floating panel
│   │   ├── Permissions/      # mic permission sheet
│   │   ├── Settings/         # API key + shortcut
│   │   ├── Dropdown/         # legacy menu-bar dropdown (unused)
│   │   └── Generation/       # legacy generation pill (folded into status bar)
│   ├── Resources/            # AppIcon.appiconset
│   ├── Info.plist
│   └── Menote.entitlements
├── Local.xcconfig.example    # signing template (copy to Local.xcconfig)
├── project.yml               # xcodegen source of truth
├── PLAN.md
└── README.md
```

---

## Roadmap

### Now (in flight)

- **Live transcription progress + cancel** — wire WhisperKit's per-segment
  callback into `onProgress`. User sees real `transcribing · N%` instead of
  a static "transcribing". Returning `false` from the callback stops the
  pipeline. A Cancel control in the sidebar's `.generating` state lets the
  user abort. ~half day of work.
- **Streaming Claude responses** — switch the Anthropic call to `stream: true`.
  First pass: animated progress while streaming. Second pass (optional):
  progressive field reveal as the JSON arrives. Trims 30–60s of spinner from
  the post-meeting wait. ~half to one day.

### Next (planned, ordered)

- **Editing notes** — title, summary, key points, action item text. Persists
  to `notes.json`. Need a save indicator + undo discipline.
- **Search across meetings** — full-text over `notes.json` + `transcript.json`.
  Lightweight in-memory index is sufficient at this data size.
- **Long-meeting threshold + chunked Claude pass** — only kicks in above
  ~45 minutes. Map-reduce: extract per-chunk in parallel, consolidate at the
  end. Below threshold, single-shot stays.
- **Notarisation / Developer ID** — Apple Developer Program enrolment +
  notarise on release. Required for sharing builds with non-developers.

### Later (not committed)

- **Speaker diarisation** — populate `speakerId` per segment. Probably via
  WhisperX or a CoreML model. Schema is ready.
- **Calendar auto-detection** — Granola's headline feature; v2.
- **Custom templates** — user-defined note structures and prompts.
- **Live transcript view** — optional side panel during the recording.
- **Mic-only fallback** — already shipped; revisit if users ask for system audio.
- **Task-system integrations** — Linear / Asana sync via `externalRef`.
- **iOS / iPad companion** — view-only over iCloud sync. Big undertaking.

---

## Decisions log

| Decision | Choice | Why |
|---|---|---|
| Name | Menote (renamed from Granolap) | Cleaner, less derivative |
| Wrapper vs pure native | Pure SwiftUI | No backend, small UI surface; WKWebView buys nothing |
| Backend | None | Claude API called directly from Swift |
| Transcription | Local (WhisperKit `small.en`) | Local-first principle; runs on Neural Engine |
| LLM | Cloud (Claude Sonnet 4.6) | Quality over local; forced `tool_use` for structured output |
| API key | User-provided, Keychain-stored | Zero infra; per-user secret |
| In-meeting typing | None | Minimal in-meeting UI; respect "ambient" design intent |
| Generation UX | Ambient (recorder closes → menu-bar progress → notification) | Doesn't block the user |
| Notes layout | Actions-first | Stronger POV than summary-first |
| Notes editing | Read-only (current); planned for next milestone | Faster to ship; schema ready |
| Diarisation | Skipped | Schema ready; revisit when needed |
| macOS floor | 14.0+ | Modern SwiftUI, current SCStream API (if we ever bring back system audio) |
| Architecture | MVC | `AppController` + `RecorderController` + `NotesController`; views are display-only |
| Folder structure | `Views/` (was `Features/`) | Views contain no business logic; name matches reality |
| Main UI | NavigationSplitView → HStack | Custom HStack gives us control over divider + title-bar painting |
| Storage | JSON files (not GRDB/SQLite) | Sub-10 KB per meeting; no DB churn worth the dependency |
| Audio capture | AVAudioRecorder, mic only | SCStream system-audio mix was originally planned; dropped for simpler permissions story and to avoid screen-recording prompt |
| Visual theme | Modern light cream (was: paper/handwritten) | SwiftUI couldn't render hand-drawn borders or bundled Caveat font faithfully; cleaner direction lands better in native primitives |
| Window chrome | Transparent title bar via `AppDelegate` NSWindow config | SwiftUI doesn't expose `titlebarAppearsTransparent` or `.fullSizeContentView` |
| Signing | Personal Team via `Local.xcconfig` (gitignored) | Free; stable binary identity stops Keychain/TCC re-prompts. Upgrade to Developer ID + notarisation when distributing |
| Reproducibility | `Package.resolved` committed, `Local.xcconfig` template | Consistent SPM versions across machines; per-developer signing without exposing team IDs |
| Heading font | SF Pro semibold (was: SF Pro Rounded; originally: Caveat) | Cleaner with the modern light theme; no bundled assets needed |
| Global shortcut | `⌘⇧R` | From original prototype |

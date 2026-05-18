# Menote

A local-first, Granola-style meeting notes app for macOS. Manual mode: click
**Start note-taking**, the app records the mic, transcribes locally with
WhisperKit (`small.en`, ~466 MB downloaded on first use), and synthesises
notes via the Anthropic Claude API.

See [`PLAN.md`](./PLAN.md) for the full product spec and design decisions.

## Requirements

- macOS 14.0 or later
- Xcode 15+
- An Apple ID (free Apple Developer account is enough — no $99/yr program needed for personal use)
- An Anthropic API key (entered in-app via Settings)

## Building from a fresh clone

```bash
git clone git@github.com:didntpay/menote.git
cd menote
```

### 1. Add your signing identity

Menote requires a stable code-signing identity so macOS doesn't re-prompt for
keychain / microphone permission on every rebuild. The team ID is per-developer,
so it lives in a gitignored file:

```bash
cp Local.xcconfig.example Local.xcconfig
```

Then open `Local.xcconfig` and fill in your **Team ID**. To find it:

1. Open Xcode → **Settings → Accounts** and sign in with your Apple ID (any free Apple ID works).
2. In a terminal, run:
   ```bash
   security find-identity -p codesigning -v
   ```
   The 10-character code in parentheses (e.g. `UA7BCUSWFY`) is your Team ID.

### 2. Open and build

```bash
open Menote.xcodeproj
```

Hit ⌘R. First build will resolve SPM dependencies (KeyboardShortcuts, WhisperKit
and its tree) — that's a one-time ~2-minute wait. Subsequent builds are fast.

### 3. Configure on first launch

- Open **Settings** from the sidebar footer and paste your Anthropic API key
- On first **Start note-taking**, grant microphone access when prompted
- On first recording end, WhisperKit downloads the `small.en` model
  (~466 MB) — you'll see a progress pill in the menu bar

## Project layout

```
Menote/
├── App/                  # entry point, controllers, AppDelegate
├── Core/
│   ├── Audio/            # AVAudioRecorder-based mic capture
│   ├── Keychain/         # API-key storage
│   ├── LLM/              # Claude notes generation
│   ├── Notifications/    # macOS notification on done
│   ├── Storage/          # JSON-file persistence + models
│   └── Transcription/    # WhisperKit pipeline
├── Theme/                # design tokens + reusable view modifiers
├── Views/                # SwiftUI views, organised by feature
└── Resources/            # asset catalog (icons, etc.)
```

Architecture: MVC. `AppController` is the top-level coordinator; `RecorderController`
and `NotesController` own their respective domains. Views are display-only.

## Modifying the project

The `.xcodeproj` is generated from [`project.yml`](./project.yml) via
[xcodegen](https://github.com/yonaskolb/XcodeGen). If you add/move source
files manually in Xcode, your changes will be wiped the next time someone
regenerates.

To install xcodegen and regenerate:

```bash
brew install xcodegen
xcodegen generate
```

`Menote.xcodeproj` is committed so the project builds without xcodegen for
most contributors — only needed if you're changing `project.yml`.

## Sharing builds with other people

Personal Team signing only lets the app run on **your** machines. To
distribute to others without "unidentified developer" warnings, you'll need
the Apple Developer Program ($99/yr) → Developer ID Application certificate
+ notarisation. Until then, recipients can right-click the `.app` → **Open**
to bypass Gatekeeper.

## License

Personal project. No license declared yet.

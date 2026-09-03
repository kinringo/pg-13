# PG-13 architecture

Rewritten 2026-08-14 against the code, replacing the 2026-05 version that had drifted in five places. Pre-edit copy: `~/Claude/Archive/pg13-architecture-2026-08-14-pre-audit.md`.

Everything below was verified by reading the source, not carried over from the old doc. Where the doc and the code disagree in future, the code wins and this file is the thing to fix.

## What it is

A prompt generator built on the Claude API, with prompts saved to Supabase. Two targets share one codebase:

- **macOS**: a menu bar app. Sparkles icon in the status bar, floating NSPanel, non-activating.
- **iOS**: `PG-13 iOS/PG13iOSApp.swift`, added since the last version of this doc. A stale duplicate at `PG13iOS/` was never in the target and was archived on 2026-08-21.

The panel is *not* always-on-top. `PG13App.swift` line 125 sets `panel.level = .normal`, so it behaves like a normal window in the stacking order.

## File layout

One tree. The two legacy trees (`/Users/mariaelena/prompt widget/`, `/Users/mariaelena/PromptGenerator/`) were confirmed gone from disk on 2026-07-12, and the old copy-before-build workflow is obsolete.

```
Design-and-Code/PG-13/
  Shared/                      ← cross-platform, both targets
    AppState.swift             AppState + GenerateViewModel + HistoryViewModel
    Services.swift             ClaudeService, SupabaseConfig, AuthService, CloudHistoryStore, HistoryStore
    DesignSystem.swift         enum QM tokens, QMButton, FieldLabel
    PlatformFields.swift       QMTextField / QMTextArea wrappers
    KeychainHelper.swift       Keychain read/write + UserDefaults migration
    Models.swift               PromptRecord and friends
    Markdown.swift             document builder, linter, MarkdownExporter, MarkdownDocViewModel, MarkdownPreview, DocsView
    GenerateView.swift
    HistoryViews.swift
    FolderViews.swift
  PG-13 macOS/
    PG13App.swift              macOS AppDelegate, NSPanel, stoplight buttons
  PG-13 iOS/PG13iOSApp.swift   iOS entry point
```

## Architecture

- **AppDelegate** (macOS only): `NSStatusBar` icon, creates the `NSPanel`, conforms to `NSWindowDelegate`.
- **AppState**: singleton `ObservableObject`. Holds `activeTab` (0 Generate, 1 Docs, 2 History, 3 Folders), `lightMode`, and the view models. Calls `KeychainHelper.migrateFromUserDefaults` once at launch.
- **GenerateViewModel**: role, goal, extra info, tone and output-type selection, generate and refine, copy/share/save/edit state.
- **MarkdownDocViewModel**: the Docs tab. Doc type, title, subject, audience, required sections, depth. Depth sets both the length rule in the system prompt and `maxTokens` (1200 / 2500 / 4000), so the two cannot drift apart. The draft autosaves to `UserDefaults` on an 800ms debounce, because the macOS panel dismisses whenever focus leaves it.
- **HistoryViewModel**: saved prompts, expand/collapse, folder assignment.
- **Folder views**: folder list plus drill-in.

## Services

`Shared/Services.swift`:

- **ClaudeService**: model `claude-sonnet-5` (line 23), direct `URLSession` HTTP, `x-api-key` header, `anthropic-version: 2023-06-01`.
- **SupabaseConfig**: `https://lgbkozbwnilhsuvfpxnd.supabase.co` (line 55). The old doc said project `mamflwiavkwybrsttwlr`; that was the pre-auth project and is no longer what ships.
- **AuthService**: Supabase Auth. Session stored in Keychain under `supabase_session`.
- **CloudHistoryStore**: per-user rows with RLS.
- **HistoryStore**: local on-device store, kept for the migration path.

### Credential storage

Keychain, not UserDefaults. `KeychainHelper.save(key: "anthropic_api_key")`; `ClaudeService` reads it via `KeychainHelper.load`. `migrateFromUserDefaults` moves a pre-existing UserDefaults key across once, then removes it. UserDefaults now holds only the `pg13Light` theme flag.

The Supabase anon key is still hardcoded, which is correct: it is the publishable key.

## Design tokens

`enum QM` in `Shared/DesignSystem.swift`. The system is adaptive light/dark now, not the single dark palette the old doc described.

| Token | Light | Dark |
|---|---|---|
| `bgBase` | `FBF0E8` | `0D0D0D` |
| `bgElevated` | `F5F5F5` | `141414` |
| `bgHover` | `EDE5DB` | `1A0A12` |
| `textPrimary` | `1D1538` | `EAEAEA` |
| `textSecondary` | `4A2840` | `8C8C8C` |
| `textMuted` | `9B8898` | `4A4A4A` |
| `border` | `C8B8B0` | `2A2A2A` |
| `borderHot` | `FF5C8A` | `E535AB` |
| `accentMagenta` | `991060` | `E535AB` |
| `accentRed` | `CC2030` | `E63946` |
| `accentAmber` | `A06800` | `F2A900` |

Fixed in both modes: `accentCyan` `00E5FF`, `borderTeal` `5FBFAE`, `accentText` `1D1538` (dark text on bright cyan buttons).

`accentCyan` is now real cyan. The old doc's note that "accentCyan renders magenta, token name kept" is obsolete: magenta moved to its own `accentMagenta` token.

Zero border-radius everywhere. No Circle shapes, no gradients. Font is `QM.mono(size)`, system monospaced.

This is the legacy Quiet Machinery system and it stays. Soft OS v2 is the web system only. Do not restyle the app to v2 without an explicit ask.

## Key UI components

- `QMTextField`: single-line `NSTextField` wrapper, mono, no focus ring.
- `QMTextArea`: multiline `_QMTextView` inside an NSScrollView. Overrides `mouseDown` to force first responder, which is how deletion works reliably inside a non-activating panel.
- `QMButton`: `.primary` / `.ghost` / `.danger` / `.active`.
- `TagToggle`, `FlowLayout` (macOS 13+ `Layout`), `onChangeCompat` for the macOS 13 vs 14 `onChange` signature split.

## Stoplight buttons (macOS)

- Red: hides the panel. `windowShouldClose` returns false, then `orderOut`. Back to the menu bar.
- Yellow: default NSPanel miniaturize.
- Green: `zoomPanel()` toggles 420x680 compact and 560x`min(screen height - 32, 880)` expanded. The old doc's 420x700 and 580x900 are both wrong.

## Deployment

Personal install, built in Xcode: Product, Archive, Distribute App, Copy App, Export, drag to /Applications.

- First launch: right-click, Open, to get past Gatekeeper. Development cert, one time.
- App name PG-13 across `CFBundleDisplayName`, `CFBundleName`, `PRODUCT_NAME`.
- Launch at login: System Settings, General, Login Items.

## Keeping Supabase awake

Free Supabase projects pause after about seven days without API activity. A
paused project has its subdomain withdrawn from DNS, so sign-in, sign-up, and
history sync all fail at the transport layer. This happened on 2026-09-02 and
looked like a broken Create Account button. `Net.supabase` now names it.

Two pings stop it recurring, on purpose. They fail in different ways, so
neither is a single point of failure.

### 1. GitHub Action (primary)

`.github/workflows/supabase-keepalive.yml`, every other day at 09:17 UTC, plus
a manual `workflow_dispatch` button. Runs in the cloud, so it does not care
whether any machine is switched on.

It reads the URL and publishable key out of `Shared/Services.swift` at runtime
rather than duplicating them in repo variables. One source of truth: repoint
`SupabaseConfig` and the workflow follows. If that struct is ever restructured
the workflow fails loudly rather than silently pinging nothing.

It also asserts that an unauthenticated request returns `[]`. If rows ever come
back, RLS has been switched off or a policy widened, and the run fails. That
turns the keepalive into a standing check on the one thing that makes shipping
a public key safe.

One caveat: GitHub disables scheduled workflows in repositories with no commits
for 60 days, and emails the owner first. A commit, or the manual dispatch
button, re-enables it.

### 2. macOS launch agent (backup)

Once a day, while this Mac is awake. Lives outside the repo, since it holds no
secret worth versioning and is specific to this machine:

| Piece | Path |
|---|---|
| Script | `~/.local/bin/pg13-supabase-keepalive.sh` |
| Launch agent | `~/Library/LaunchAgents/space.mariamaria.pg13-keepalive.plist` |
| Log | `~/Library/Logs/pg13-keepalive.log` |

```bash
# Check it is alive and see the recent history.
launchctl list | grep pg13
tail -5 ~/Library/Logs/pg13-keepalive.log

# Remove it.
launchctl bootout gui/$UID/space.mariamaria.pg13-keepalive
rm ~/Library/LaunchAgents/space.mariamaria.pg13-keepalive.plist
```

### The request, and what is unproven

Both pings send the same thing: `select id limit 1` against `prompt_history`
with the publishable key. Row-level security returns an empty array to an
unauthenticated caller, which is the point. It counts as activity and proves
RLS is working in the same request.

The premise, that an API request resets Supabase's idle clock, is their
documented behaviour and has not been verified here across a full seven-day
cycle. The Action history and the local log are the evidence. If the project
pauses again despite green runs, the premise is wrong and the ping needs to be
heavier, most likely an authenticated write.

## Known gotchas

- `import Combine` is required. This toolchain does not re-export `@Published` and `ObservableObject` through SwiftUI.
- `.nonactivatingPanel` means the window never becomes key, which is why `QMTextArea` overrides `mouseDown`.
- `PRODUCT_NAME` was `$(TARGET_NAME)` and is overridden to `"PG-13"` in both Debug and Release configs in `project.pbxproj`. The target, scheme, project file and source folder were all renamed to PG-13 on 2026-08-22. Only `PRODUCT_BUNDLE_IDENTIFIER` still says promptgenerator, left alone deliberately so the Keychain items stay reachable.

## Open risks

Carried from the 2026-07-22 audit, still unfixed in the code:

1. **Migration can drop history.** `CloudHistoryStore.migrateLocalIfNeeded()` calls `savePrompt` with `try?` per record, and `HistoryStore.migrateOut()` renames the local file to `.migrated` before any cloud save is confirmed. If saves fail partway (offline, expired session), those records never reach the cloud and the local file is already retired. Fix: only retire the file after every save succeeds. This becomes real the moment sync runs on a second device, which the iOS target now makes likely.
2. **App icon set.** `AppIcon.appiconset/Contents.json` points the 1024 marketing slot at a file named `broken.png`, and two 1024 entries have no filename. Xcode warns; App Store submission would fail. Low stakes for a personal install.
3. `GenerateViewModel.clear()` does not reset `copyFlash` and `shareFlash`. The History folder list is fetched once per load, so a folder created on another device will not appear until reload. Both cosmetic.

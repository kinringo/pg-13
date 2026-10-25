# PG-13 architecture

Rewritten 2026-08-14 against the code, replacing the 2026-05 version that had drifted in five places. Pre-edit copy: `~/Claude/Archive/pg13-architecture-2026-08-14-pre-audit.md`. Re-checked 2026-09-03 (Supabase URL, migration, app icon) and 2026-09-23 (lean pass). Pre-edit copy for that pass: `~/Claude/Archive/pg13-architecture-2026-09-03-pre-migration-fix.md`.

Everything below was verified by reading the source, not carried over from the old doc. Where the doc and the code disagree in future, the code wins and this file is the thing to fix.

## What it is

A prompt generator built on the Claude API, with prompts saved to Supabase. Two targets share one codebase:

- **macOS**: a menu bar app. Sparkles icon in the status bar, floating NSPanel, non-activating.
- **iOS**: `PG-13 iOS/PG13iOSApp.swift`, added since the last version of this doc. A stale duplicate at `PG13iOS/` was never in the target and was archived on 2026-08-21.

The panel is *not* always-on-top. `PG13App.swift` line 127 sets `panel.level = .normal`, so it behaves like a normal window in the stacking order.

## File layout

One tree. The two legacy trees (`/Users/mariaelena/prompt widget/`, `/Users/mariaelena/PromptGenerator/`) were confirmed gone from disk on 2026-07-12, and the old copy-before-build workflow is obsolete.

```
Design-and-Code/PG-13/
  Shared/                      ← cross-platform, both targets
    AppState.swift             AppState + GenerateViewModel + HistoryViewModel
    Services.swift             ClaudeService, SupabaseConfig, AuthService, CloudHistoryStore, HistoryStore
    DesignSystem.swift         enum QM tokens (mirrors Figma), fonts, QMButton, FieldLabel, FormField
    Components.swift           one SwiftUI view per Figma component (header, tabs, fields, buttons, ...)
    AppShell.swift             shared frame: header + tabs + screen; ProfileView (sign-in, account edits, theme)
    PlatformFields.swift       QMTextField / QMTextArea wrappers
    KeychainHelper.swift       Keychain read/write + UserDefaults migration
    Models.swift               PromptRecord, shareText(), String.capped, ServiceError, Anthropic types
    Markdown.swift             document builder, linter, MarkdownExporter; MarkdownDocViewModel and DocsView are unused since SKILL took the Docs tab
    GenerateView.swift
    HistoryViews.swift
    FolderViews.swift
  PG-13 macOS/
    PG13App.swift              macOS AppDelegate, NSPanel, stoplight buttons
  PG-13 iOS/PG13iOSApp.swift   iOS entry point
  PG-13 iOS/Fonts, PG-13 macOS/Fonts   JetBrains Mono (Regular/Medium/Bold), Space Mono Regular, Geist Mono (Regular/Bold, tabs only; OFL)
```

## Architecture

- **AppDelegate** (macOS only): `NSStatusBar` icon, creates the `NSPanel`, conforms to `NSWindowDelegate`.
- **AppState**: singleton `ObservableObject`. Holds `activeTab` (`AppTab`: 0 Prompt, 1 Skill, 2 History (labelled SAVED), 3 Folders, 4 Profile), `lightMode`, and the view models (`generateVM`, `skillVM`). Calls `KeychainHelper.migrateFromUserDefaults` once at launch.
- **GenerateViewModel**: role, goal, extra info, tone and output-type selection, generate and refine, copy/share/save/edit state.
- **SkillViewModel**: the Skill tab. Name, what it does / when to use, steps and rules go to Claude with a SKILL.md system prompt (frontmatter `name` and `description`, then numbered steps and rules, no em dashes). Saves with `kind = 'skill'`: `goal` holds the name, `role` the purpose, `generated_prompt` the file. Refine, copy, share, export and save-to-folder match the Prompt tab.
- **MarkdownDocViewModel** (unused, kept for now): the old Docs tab. Doc type, title, subject, audience, required sections, depth. Depth sets both the length rule in the system prompt and `maxTokens` (1200 / 2500 / 4000), so the two cannot drift apart. The draft autosaves to `UserDefaults` on an 800ms debounce, because the macOS panel dismisses whenever focus leaves it.
- **HistoryViewModel**: saved prompts, expand/collapse, folder assignment.
- **Folder views**: folder list plus drill-in.

## Services

`Shared/Services.swift`:

- **ClaudeService**: model `claude-sonnet-5` (line 52), direct `URLSession` HTTP, `x-api-key` header, `anthropic-version: 2023-06-01`.
- **SupabaseConfig**: `https://kxkpewnebbftderbizph.supabase.co` (line 93). Earlier docs named `lgbkozbwnilhsuvfpxnd` (post-auth project) and `mamflwiavkwybrsttwlr` (pre-auth). Neither is what ships now. The keepalive workflow reads this URL from source, so it follows a repoint automatically.
- **AuthService**: Supabase Auth. Session stored in Keychain under `supabase_session`. `updateUser` (PUT /auth/v1/user) changes the password at once; a new email waits on Supabase's confirmation link. No password reset yet: it needs Supabase auth email plus a page for the reset link.
- **CloudHistoryStore**: per-user rows with RLS. `kind` ('prompt' or 'skill', default 'prompt') was added 2026-10-24 (`supabase/kind.sql`); older builds that never send it still save prompts.
- **HistoryStore**: reads and retires the pre-sync `prompt_history.json`. It has no other API; it exists only for the one-time migration. Live save/load goes through the cloud store. Unsigned users can generate and export; Save on Generate fails until they sign in.

### Credential storage

Keychain, not UserDefaults. `KeychainHelper.save(key: "anthropic_api_key")`; `ClaudeService` reads it via `KeychainHelper.load`. `migrateFromUserDefaults` moves a pre-existing UserDefaults key across once, then removes it. UserDefaults now holds only the `pg13Light` theme flag.

The Supabase anon key is still hardcoded, which is correct: it is the publishable key.

## Design tokens

`enum QM` in `Shared/DesignSystem.swift` mirrors the Figma file "prompt-generator" (`dn6XnEybPsH7QQ71yZVxXe`, page "21 · Global Components"). Each Figma variable maps to one `QM` member with the same name: `background/screen` → `QM.screen`, `text/nav-active` → `QM.textNavActive`, `border/accent-teal` → `QM.borderAccentTeal`, and so on. Light and dark values come from the Figma Light/Dark modes; hex with alpha is written AARRGGBB.

- **Spacing / radius / stroke:** `QM.Space` (2, 4, 8, 10, 12, 16, 20), `QM.Radius` (sm 2, md 4, window 5), `QM.stroke` 0.5 (stroke/default; one device pixel on Retina). Figma's Spacing collection.
- **Type:** the Figma text styles, as `Font.custom(..., relativeTo:)` so they scale with Dynamic Type: `labelSection`, `navTab`, `navLabel` / `navLabelActive` (Geist Mono, the tab row), `bodyPrompt`, `labelControl`, `headingScreen`, `headingReference`, `bodyReference`. Fonts are bundled and registered at launch by `QM.registerFonts()`.
- **Legacy names** (`bgBase`, `accentCyan`, `textMuted`, ...) alias the new tokens so older views (Docs, Markdown preview) pick up the new palette. New code uses the Figma names.

The Quiet Machinery look (zero radius, system mono, `#0D0D0D`/magenta) is retired as of the 2026-10-23 redesign. Screens follow the Figma file.

## Key UI components

- `QMTextField`: single-line `NSTextField` wrapper, mono, no focus ring.
- `QMTextArea`: multiline `_QMTextView` inside an NSScrollView. Overrides `mouseDown` to force first responder, which is how deletion works reliably inside a non-activating panel.
- `QMButton`: `.primary` / `.ghost` / `.danger` / `.active`.
- `TagToggle`, `FormField`, `FlowLayout` (a `Layout`; the deployment targets are macOS 13 / iOS 16, so it needs no fallback), `onChangeCompat` for the macOS 13 vs 14 `onChange` signature split.

## Stoplight buttons (macOS)

- Red: hides the panel. `windowShouldClose` returns false, then `orderOut`. Back to the menu bar.
- Yellow: default NSPanel miniaturize.
- Green: `zoomPanel()` toggles 500x600 compact (`AppDelegate.compactSize`, the Figma desktop frame) and 560x`min(screen height - 32, 880)` expanded. The whole frame is 500x600: the content runs under the title bar, so the frame is set directly, not the content rect.

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

The GitHub Action keeps it awake; the launch agent watches for a pause. See
"The request, and what is unproven" below for why one anonymous read was not
enough.

### 1. GitHub Action (keepalive)

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

### 2. macOS launch agent (alarm)

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

The first design sent only `select id limit 1` against `prompt_history` with
the publishable key, from both pings. That premise was wrong. The project
paused on 2026-09-12 (local pings green through 09-11) and again on 2026-10-07
(local ping green on 10-06 at 20:09, Action red from 10-07 on). An anonymous
read that RLS answers with `[]` does not reset the idle clock.

Since 2026-10-23 the Action makes two requests:

1. The same anonymous read, kept as the RLS check. It must return `[]`.
2. A password sign-in as a dedicated keepalive user, then an upsert of that
   user's single row in `keepalive` (`supabase/keepalive.sql`). This is a real
   authenticated write.

Setup, once:

- Run `supabase/keepalive.sql` in the SQL editor.
- Create the keepalive user under Authentication, Users, with "Auto Confirm
  User" on. It is not a person's account.
- Add repo secrets `KEEPALIVE_EMAIL` and `KEEPALIVE_PASSWORD`.

Still unproven: that an authenticated write resets the clock. It needs one full
seven-day cycle of green runs with the project staying up. If it pauses again
despite that, the free plan cannot be kept awake this way, and the options are
the Pro plan or resuming by hand.

The launch agent still sends only the anonymous read. It is an alarm now, not a
keepalive: a `FAIL 000` line in its log means the project is paused.

## Known gotchas

- `import Combine` is required. This toolchain does not re-export `@Published` and `ObservableObject` through SwiftUI.
- `.nonactivatingPanel` means the window never becomes key, which is why `QMTextArea` overrides `mouseDown`.
- `PRODUCT_NAME` was `$(TARGET_NAME)` and is overridden to `"PG-13"` in both Debug and Release configs in `project.pbxproj`. The target, scheme, project file and source folder were all renamed to PG-13 on 2026-08-22. Only `PRODUCT_BUNDLE_IDENTIFIER` still says promptgenerator, left alone deliberately so the Keychain items stay reachable.

## Open risks

Carried from the 2026-07-22 audit, re-checked against the code on 2026-09-03:

1. **iOS app icon.** macOS `AppIcon.appiconset` has real PNGs for every mac slot. iOS still has dark and tinted 1024 entries with no `filename`. Xcode warns; App Store / TestFlight would fail. Low stakes for a personal install. The old `broken.png` marketing slot is gone.
2. The History folder list is fetched once per load, so a folder created on another device will not appear until reload. Cosmetic.

### Fixed 2026-09-03: local migration no longer retires first

`CloudHistoryStore.migrateLocalIfNeeded()` used to call `HistoryStore.migrateOut()`, which renamed the local file to `.migrated` before any cloud save was confirmed, and each save used `try?`. Offline or expired-session failures dropped those records.

The local file is now read with `peekPending()`, each record is saved with a real `do/catch`, and `finishMigration(keeping:)` either retires the file (all saved) or rewrites it with the leftovers (retry on the next sign-in). Records that already landed in the cloud are dropped from the local file so a retry does not duplicate them.

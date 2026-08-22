# PG-13

A prompt generator that lives in the macOS menu bar, with a companion iOS app.

You describe what you want in plain language. PG-13 turns it into a single,
ready-to-use prompt through the Claude API, then saves it to a private history
you can search, file into folders, and export as markdown.

Built with SwiftUI. One shared codebase, two targets, no third-party dependencies.

![Platforms](https://img.shields.io/badge/platform-macOS%2013%2B%20%7C%20iOS%2016%2B-lightgrey)
![Swift](https://img.shields.io/badge/swift-5.0-orange)

---

## What it does

- **Generate.** Give it a role, a goal, optional context, a tone, and an output
  type. It returns one prompt, not an essay about your prompt.
- **Refine.** Ask for a change in plain language ("make it shorter", "add a
  constraint about tone") and the prompt is revised in place, versioned.
- **Save and organise.** Prompts sync to your own Supabase row via email
  sign-in. File them into folders.
- **Export markdown.** Any single prompt, an entire folder, or your whole
  library, as a formatted `.md` document with metadata and a table of contents.
- **Light and dark.** Both themes ship, toggled from the header.

## Layout

```
Shared/              cross-platform: models, services, view models, all views
  AppState.swift       view models, prompt construction
  Services.swift       Claude API, Supabase auth, cloud + local history stores
  Markdown.swift       markdown document builder and export controller
  DesignSystem.swift   QM design tokens, buttons, flow layout
  GenerateView.swift   the generate tab
  HistoryViews.swift   auth gate, history list, per-row actions
  FolderViews.swift    folder list and drill-down
  PlatformFields.swift AppKit and UIKit text field bridges
  KeychainHelper.swift Keychain read/write
  Models.swift         PromptRecord, ServiceError, Anthropic request/response

PG-13 macOS/         macOS target: menu bar item, floating NSPanel, ContentView
PG-13 iOS/           iOS target: tab-bar shell
```

## Running it

Requires Xcode 15 or later.

```bash
open PG-13.xcodeproj
```

Pick the `PG-13` scheme for macOS or `PG-13 iOS` for the phone, then
build and run.

### Anthropic API key

PG-13 never stores a key in the repo. On first generate it prompts for one and
writes it to the Keychain (`com.pg13.promptgenerator`, account
`anthropic_api_key`), readable only while the device is unlocked and excluded
from backups.

For development you can set it in the environment instead, which takes
precedence over the Keychain:

```bash
export ANTHROPIC_API_KEY=sk-ant-...
```

Get a key at [console.anthropic.com](https://console.anthropic.com/).

### Supabase sync

History and folders are optional. Without signing in, the app generates and
exports fine, and the History and Folders tabs show a sign-in gate.

The project ships a Supabase project URL and a **publishable** anon key in
`Shared/Services.swift`. That key is designed to be client-side and carries no
privileges on its own: every row is protected by row-level security keyed to
`auth.uid()`, and the app authenticates with a per-user JWT. Point it at your
own project by editing `SupabaseConfig`, with a table:

```sql
create table prompt_history (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null default auth.uid() references auth.users,
  goal             text not null,
  role             text,
  tone             text,
  style            text,
  generated_prompt text not null,
  folder           text,
  used             boolean default false,
  created_at       timestamptz not null default now()
);

alter table prompt_history enable row level security;

create policy "own rows select" on prompt_history
  for select using (auth.uid() = user_id);
create policy "own rows insert" on prompt_history
  for insert with check (auth.uid() = user_id);
create policy "own rows update" on prompt_history
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows delete" on prompt_history
  for delete using (auth.uid() = user_id);

create index prompt_history_user_created_idx on prompt_history (user_id, created_at desc);
create index prompt_history_user_folder_idx  on prompt_history (user_id, folder);
```

RLS is not optional here. Without that policy the publishable key would expose
every row to every client.

## Design

PG-13 uses the "Quiet Machinery" token set: monospace type, square corners,
hairline borders, cyan and magenta accents on near-black or cream. Tokens live
in `DesignSystem.swift` as `QM`. Colours are declared once as adaptive pairs so
both themes come from one definition.

## Known gaps

- The five bundled IBM Plex font files are not currently loaded. Type falls back
  to the system monospace face.
- History loads the 50 most recent prompts, with no pagination past that.
- Sign-up assumes email confirmation is disabled on the Supabase project. With
  confirmation on, the immediate sign-in after sign-up will fail.

## Licence

Personal project. All rights reserved.

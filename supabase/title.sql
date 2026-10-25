-- Short title Claude suggests for a saved prompt, shown in the Saved list.
--
-- Additive: nullable, so existing rows and older app builds that never send
-- `title` keep working; the app falls back to `goal` when it is null.
-- Safe to re-run.

alter table public.prompt_history
  add column if not exists title text;

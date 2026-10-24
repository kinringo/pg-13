-- Prompt or skill, for the SKILL tab and the PROMPT / SKILL badge in History.
--
-- Applied 2026-10-24. Additive: existing rows and older app builds that never
-- send `kind` get 'prompt'. Safe to re-run.

alter table public.prompt_history
  add column if not exists kind text not null default 'prompt'
  constraint prompt_history_kind_check check (kind in ('prompt', 'skill'));

-- Agency Books (open access, with deletion tracking)
-- Run in Supabase > SQL Editor > New query > Run. Safe to re-run; keeps existing entries.

create table if not exists public.transactions (
  id text primary key,
  type text not null check (type in ('income','expense')),
  date date not null,
  party text not null,
  cat text not null,
  descr text not null default '',
  amount numeric(14,2) not null check (amount >= 0),
  status text not null check (status in ('paid','unpaid')),
  by_name text not null default '',
  created bigint not null default (extract(epoch from now()) * 1000)::bigint
);
alter table public.transactions add column if not exists deleted_at bigint;
alter table public.transactions add column if not exists deleted_by text;
create index if not exists transactions_date_idx on public.transactions (date desc);

-- Activity log: who added, deleted, restored or changed what, and when.
create table if not exists public.activity_log (
  id bigint generated always as identity primary key,
  at bigint not null default (extract(epoch from now()) * 1000)::bigint,
  action text not null,
  entry_id text not null,
  summary text not null default '',
  by_name text not null default ''
);
create index if not exists activity_log_at_idx on public.activity_log (at desc);

alter table public.transactions enable row level security;
alter table public.activity_log enable row level security;

drop policy if exists "open access" on public.transactions;
drop policy if exists "partners only" on public.transactions;
create policy "open access" on public.transactions for all to anon, authenticated using (true) with check (true);

drop policy if exists "log read" on public.activity_log;
drop policy if exists "log insert" on public.activity_log;
create policy "log read" on public.activity_log for select to anon, authenticated using (true);
create policy "log insert" on public.activity_log for insert to anon, authenticated with check (true);

-- Entries can never be permanently erased from the app; "delete" only marks them deleted.
-- The activity log can only be read and added to, never edited or erased.
revoke all on public.transactions from anon, authenticated;
revoke all on public.activity_log from anon, authenticated;
grant select, insert, update on public.transactions to anon, authenticated;
grant select, insert on public.activity_log to anon, authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;

-- Live updates between phones (safe to re-run: skips tables already added).
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='transactions') then
    alter publication supabase_realtime add table public.transactions;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='activity_log') then
    alter publication supabase_realtime add table public.activity_log;
  end if;
end $$;

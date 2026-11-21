-- Agency Books (OPEN ACCESS, no login): run in Supabase > SQL Editor > New query > Run.
-- WARNING: anyone who has your app link can read, add, edit and delete entries.

create table if not exists public.transactions (
  id        text primary key,
  type      text not null check (type in ('income','expense')),
  date      date not null,
  party     text not null,
  cat       text not null,
  descr     text not null default '',
  amount    numeric(14,2) not null check (amount >= 0),
  status    text not null check (status in ('paid','unpaid')),
  by_name   text not null default '',
  created   bigint not null default (extract(epoch from now()) * 1000)::bigint
);

create index if not exists transactions_date_idx on public.transactions (date desc);

alter table public.transactions enable row level security;

drop policy if exists "partners only" on public.transactions;
drop policy if exists "open access" on public.transactions;
create policy "open access" on public.transactions
  for all to anon, authenticated
  using (true) with check (true);

grant select, insert, update, delete on public.transactions to anon, authenticated;

-- Live updates between phones (ignore the error if it says it is already added).
alter publication supabase_realtime add table public.transactions;

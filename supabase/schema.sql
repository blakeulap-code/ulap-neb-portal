-- ULAP NEB Position Paper Portal — Supabase schema
-- Paste this into the Supabase SQL editor (Project → SQL Editor → New query) and run it once.
-- Auth: Supabase Auth handles magic-link email sign-in. Each signed-in user is matched to a
-- row in `members` by email — that's how the app knows a person's name/title/role.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Members of the NEB + Secretariat. The Secretariat pre-populates this table
-- (name, title, email, role) before anyone logs in.
-- ---------------------------------------------------------------------------
create table members (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  name text not null,
  title text,
  role text not null default 'neb' check (role in ('neb', 'secretariat')),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Position papers (the registry). Content fields mirror what's already in the
-- static build's SEED data; the Secretariat maintains these.
-- ---------------------------------------------------------------------------
create table papers (
  id text primary key,                      -- e.g. 'pp-2026-0001'
  ref text not null,
  measure text,
  title text not null,
  area text,
  sender text,
  sender_type text,
  office text,
  priority text,
  status text not null default 'For Approval',
  position text,                            -- ULAP's recommended position: support | amend | oppose | study
  summary text,
  requested_action text,
  recommendation text,
  draft_file text,                          -- storage path or public URL to the drafted .docx
  required_approvals int not null default 11,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Sign-offs — one row per member decision on a paper. A member can update
-- (upsert) their own decision but each (paper, member) pair is unique.
-- ---------------------------------------------------------------------------
create table signoffs (
  id uuid primary key default gen_random_uuid(),
  paper_id text not null references papers(id) on delete cascade,
  member_id uuid not null references members(id) on delete cascade,
  decision text not null check (decision in ('approve', 'disapprove')),
  signature_data text,                      -- base64 PNG from the signature pad, or null (typed name used instead)
  signed_at timestamptz not null default now(),
  unique (paper_id, member_id)
);

-- ---------------------------------------------------------------------------
-- Revision notes / queries / endorsements, threaded per paper.
-- ---------------------------------------------------------------------------
create table notes (
  id uuid primary key default gen_random_uuid(),
  paper_id text not null references papers(id) on delete cascade,
  member_id uuid not null references members(id) on delete cascade,
  type text not null default 'query' check (type in ('revision', 'query', 'endorse')),
  body text not null,
  resolved boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Supporting documents attached to a paper (uploaded to Supabase Storage;
-- this table just indexes them).
-- ---------------------------------------------------------------------------
create table documents (
  id uuid primary key default gen_random_uuid(),
  paper_id text not null references papers(id) on delete cascade,
  name text not null,
  size bigint,
  ext text,
  storage_path text not null,
  uploaded_by uuid references members(id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table members   enable row level security;
alter table papers    enable row level security;
alter table signoffs  enable row level security;
alter table notes     enable row level security;
alter table documents enable row level security;

-- helper: the members-row of the currently authenticated user
create or replace function me() returns members as $$
  select * from members where email = auth.jwt() ->> 'email' limit 1;
$$ language sql stable;

create or replace function is_secretariat() returns boolean as $$
  select coalesce((select role from members where email = auth.jwt() ->> 'email') = 'secretariat', false);
$$ language sql stable;

-- members: any signed-in user can read the roster; only Secretariat can change it
create policy "members readable by signed-in users" on members for select using (auth.role() = 'authenticated');
create policy "members writable by secretariat" on members for all using (is_secretariat()) with check (is_secretariat());

-- papers: readable by any signed-in user; only Secretariat can create/edit
create policy "papers readable by signed-in users" on papers for select using (auth.role() = 'authenticated');
create policy "papers writable by secretariat" on papers for all using (is_secretariat()) with check (is_secretariat());

-- signoffs: readable by anyone signed in; a member can only insert/update/delete their OWN signoff (or Secretariat, any)
create policy "signoffs readable by signed-in users" on signoffs for select using (auth.role() = 'authenticated');
create policy "signoffs insertable by self" on signoffs for insert with check (member_id = (select id from members where email = auth.jwt() ->> 'email'));
create policy "signoffs updatable by self or secretariat" on signoffs for update using (member_id = (select id from members where email = auth.jwt() ->> 'email') or is_secretariat());
create policy "signoffs deletable by self or secretariat" on signoffs for delete using (member_id = (select id from members where email = auth.jwt() ->> 'email') or is_secretariat());

-- notes: readable by anyone signed in; anyone signed in can post; only the poster or Secretariat can resolve/edit
create policy "notes readable by signed-in users" on notes for select using (auth.role() = 'authenticated');
create policy "notes insertable by signed-in users" on notes for insert with check (auth.role() = 'authenticated');
create policy "notes updatable by author or secretariat" on notes for update using (member_id = (select id from members where email = auth.jwt() ->> 'email') or is_secretariat());

-- documents: readable by anyone signed in; anyone signed in can upload
create policy "documents readable by signed-in users" on documents for select using (auth.role() = 'authenticated');
create policy "documents insertable by signed-in users" on documents for insert with check (auth.role() = 'authenticated');

-- DSGVO Art. 7(1): Nachweis Einwilligung Foto-Veroeffentlichung
create table if not exists upload_consents (id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users (id) on delete cascade, purpose text not null, text_version text not null, created_at timestamptz not null default now());
alter table upload_consents enable row level security;
create policy "upload_consents_insert_own" on upload_consents for insert to authenticated with check (auth.uid() = user_id);
create policy "upload_consents_select_own" on upload_consents for select to authenticated using (auth.uid() = user_id);
create index if not exists idx_upload_consents_user on upload_consents (user_id);

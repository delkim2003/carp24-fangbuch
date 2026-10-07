-- Pre-Moderation: Anzeigen erst nach Freigabe sichtbar + Pruef-Protokoll
alter table marketplace_items alter column status set default 'pending';
create table if not exists moderation_log (id uuid primary key default gen_random_uuid(), item_id uuid not null references marketplace_items (id) on delete cascade, admin_id uuid not null, decision text not null, checklist jsonb not null, note text, created_at timestamptz not null default now());
alter table moderation_log enable row level security;
create index if not exists idx_moderation_log_item on moderation_log (item_id);
alter table marketplace_items drop constraint if exists marketplace_items_status_check;
alter table marketplace_items add constraint marketplace_items_status_check check (status in ('active','sold','pending','rejected'));

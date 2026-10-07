-- DSGVO Art. 5(1)(c)+(e): Push-Token werden nach 90 Tagen ohne erfolgreiche Zustellung geloescht
alter table push_subscriptions add column if not exists last_success_at timestamptz;
create index if not exists idx_push_subs_last_success on push_subscriptions (last_success_at);

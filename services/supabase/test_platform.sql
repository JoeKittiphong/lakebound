-- Disposable test-cluster stand-ins for Supabase-managed schemas (never deploy).
create schema auth;
create function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
grant usage on schema auth to anon,authenticated;
create function auth.jwt() returns jsonb language sql stable as $$
 select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb
$$;
create schema realtime;
create table realtime.messages(extension text);
alter table realtime.messages enable row level security;
grant usage on schema realtime to authenticated;
grant select,insert on realtime.messages to authenticated;
create function realtime.topic() returns text language sql stable as $$
 select current_setting('realtime.topic',true)
$$;

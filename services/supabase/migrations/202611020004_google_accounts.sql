begin;
create table lakebound_private.accounts (
 auth_id uuid primary key, player_id text not null unique references lakebound_private.players,
 guest_token text not null check(guest_token ~ '^[a-f0-9]{64}$'),
 created_at timestamptz not null default clock_timestamp()
);
alter table lakebound_private.accounts enable row level security;
revoke all on lakebound_private.accounts from public,anon,authenticated;

create function public.lakebound_account(payload jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' set statement_timeout='8s' as $$
declare uid uuid:=auth.uid(); account lakebound_private.accounts%rowtype;
 pid text; secret text; player_name text;
begin
 if uid is null or coalesce(auth.jwt()->'app_metadata'->>'provider','')<>'google'
 or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'google_login_required'; end if;
 if jsonb_typeof(payload) is distinct from 'object' or octet_length(payload::text)>1024 then raise exception 'invalid_payload'; end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text,42));
 select * into account from lakebound_private.accounts where auth_id=uid;
 if not found then
  if not(select writes_enabled from lakebound_private.control where singleton) then raise exception 'migration_in_progress'; end if;
  pid:=replace(gen_random_uuid()::text,'-','');
  secret:=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
  player_name:='นักตกปลา '||substr(pid,1,6);
  insert into lakebound_private.players(player_id,player_name,token_hash) values(pid,player_name,
   translate(encode(sha256(convert_to(to_json(secret)::text,'UTF8')),'base64'),'+/','-_'));
  insert into lakebound_private.accounts(auth_id,player_id,guest_token) values(uid,pid,secret) returning * into account;
 end if;
 select p.player_name into player_name from lakebound_private.players p where p.player_id=account.player_id;
 return jsonb_build_object('identity',jsonb_build_object('id',account.player_id,'token',account.guest_token,'name',player_name));
exception when raise_exception then return jsonb_build_object('error',sqlerrm);
end $$;
revoke all on function public.lakebound_account(jsonb) from public,anon;
grant execute on function public.lakebound_account(jsonb) to authenticated;
commit;

begin;
-- Public boards stay readable. Old guest-only builds cannot repopulate the
-- cleared leaderboard after the Google account reset.
alter function public.lakebound_rankings(jsonb) set schema lakebound_private;
revoke all on function lakebound_private.lakebound_rankings(jsonb) from public,anon,authenticated;
create function public.lakebound_rankings(payload jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' set statement_timeout='8s' as $$
begin
 if payload ? 'player_id' or payload ? 'token' or payload ? 'player_name' or payload ? 'catches' then
  if auth.uid() is null or coalesce(auth.jwt()->'app_metadata'->>'provider','')<>'google'
  or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then return jsonb_build_object('error','google_login_required'); end if;
  if not exists(select 1 from lakebound_private.accounts where auth_id=auth.uid() and player_id=payload->>'player_id') then
   return jsonb_build_object('error','account_mismatch');
  end if;
 end if;
 return lakebound_private.lakebound_rankings(payload);
end $$;
revoke all on function public.lakebound_rankings(jsonb) from public;
grant execute on function public.lakebound_rankings(jsonb) to anon,authenticated;
commit;

begin;
-- Keep the thoroughly tested state machine, but bind it to the Google account
-- rather than letting another Supabase identity claim arbitrary guest profiles.
alter function public.lakebound_matches(jsonb) set schema lakebound_private;
revoke all on function lakebound_private.lakebound_matches(jsonb) from public,anon,authenticated;
create function public.lakebound_matches(payload jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' set statement_timeout='8s' as $$
begin
 if auth.uid() is null or coalesce(auth.jwt()->'app_metadata'->>'provider','')<>'google'
 or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then
  return jsonb_build_object('error','google_login_required');
 end if;
 if not exists(select 1 from lakebound_private.accounts where auth_id=auth.uid() and player_id=payload->>'player_id') then
  return jsonb_build_object('error','account_mismatch');
 end if;
 return lakebound_private.lakebound_matches(payload);
end $$;
revoke all on function public.lakebound_matches(jsonb) from public,anon;
grant execute on function public.lakebound_matches(jsonb) to authenticated;
commit;

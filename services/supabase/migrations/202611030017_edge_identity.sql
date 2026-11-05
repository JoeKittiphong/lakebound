begin;
-- JWT validation remains Supabase's job. Never return the permanent profile token.
create function public.lakebound_edge_identity() returns jsonb
language sql stable security definer set search_path='' as $identity$
 select case when auth.uid() is null or coalesce(auth.jwt()->'app_metadata'->>'provider','')<>'google'
  or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then jsonb_build_object('error','google_login_required')
 else coalesce((select jsonb_build_object('id',a.player_id,'name',p.player_name,'expires_at',(auth.jwt()->>'exp')::bigint)
  from lakebound_private.accounts a join lakebound_private.players p using(player_id) where a.auth_id=auth.uid()),jsonb_build_object('error','account_mismatch')) end
$identity$;
revoke all on function public.lakebound_edge_identity() from public,anon;
grant execute on function public.lakebound_edge_identity() to authenticated;
notify pgrst,'reload schema';
commit;

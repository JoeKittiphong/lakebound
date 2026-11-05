begin;
create function lakebound_private.cloud_catch_wire(c lakebound_private.cloud_catches) returns jsonb
language sql stable set search_path='' as $$
 select jsonb_build_array(c.catch_id,lakebound_private.cloud_code('map',c.map_id),lakebound_private.cloud_code('fish',c.species),c.grams,c.time_ms,c.depth_cm,
 lakebound_private.cloud_code('item',c.bait),(select data from lakebound_private.cloud_contexts where auth_id=c.auth_id and device=c.device and id=c.context),c.fish_key,c.flags,c.location)
$$;
create function lakebound_private.cloud_checkpoint(uid uuid) returns bigint
language plpgsql set search_path='' as $$
declare rev bigint;d jsonb;rows jsonb:='[]';page_rows jsonb:='[]';r record;k text;v jsonb;part jsonb;n integer:=0;begin
 select revision,data into rev,d from lakebound_private.cloud_state where auth_id=uid;
 if exists(select 1 from lakebound_private.cloud_checkpoints where auth_id=uid and revision=rev) then return rev;end if;
 for k,v in select key,value from jsonb_each(d) loop
  if k in ('i','sp','sl','e','s','a') then
   for r in select key,value from jsonb_each(v) loop rows:=rows||jsonb_build_array(jsonb_build_array(k,r.key,r.value));end loop;
  elsif k='m' then
   rows:=rows||jsonb_build_array(jsonb_build_array('m','s',v->'s'),jsonb_build_array('m','t',v->'t'));
   for r in select key,value from jsonb_each(v->'e') loop rows:=rows||jsonb_build_array(jsonb_build_array('me',r.key,r.value));end loop;
  elsif k='b' then
   for r in select value from jsonb_array_elements(v) loop rows:=rows||jsonb_build_array(jsonb_build_array('b',r.value,true));end loop;
  else rows:=rows||jsonb_build_array(jsonb_build_array(k,'',v));end if;
 end loop;
 for r in select * from lakebound_private.cloud_stats where auth_id=uid order by species loop
  rows:=rows||jsonb_build_array(jsonb_build_array('h',lakebound_private.cloud_code('fish',r.species),jsonb_build_array(r.count,r.total,r.best,r.smallest,r.last)));
 end loop;
 for r in select c.* from (select cc.*,row_number() over(partition by species order by grams desc,time_ms,catch_id) pos from lakebound_private.cloud_catches cc where auth_id=uid) c
 where pos<=10 or d->'b' ? catch_id order by time_ms,catch_id loop
  rows:=rows||jsonb_build_array(jsonb_build_array('j',r.catch_id,lakebound_private.cloud_catch_wire((r.auth_id,r.catch_id,r.device,r.seq,r.map_id,r.species,r.grams,r.time_ms,r.depth_cm,r.bait,r.context,r.fish_key,r.flags,r.location)::lakebound_private.cloud_catches)));
 end loop;
 for r in select distinct on(map_id,species) * from lakebound_private.cloud_catches where auth_id=uid order by map_id,species,grams desc,time_ms,catch_id loop
  rows:=rows||jsonb_build_array(jsonb_build_array('k',r.map_id||':'||r.species,lakebound_private.cloud_catch_wire((r.auth_id,r.catch_id,r.device,r.seq,r.map_id,r.species,r.grams,r.time_ms,r.depth_cm,r.bait,r.context,r.fish_key,r.flags,r.location)::lakebound_private.cloud_catches)));
 end loop;
 for r in select map_id,count(*) n from lakebound_private.cloud_catches where auth_id=uid and (flags&1)=1 group by map_id loop
  rows:=rows||jsonb_build_array(jsonb_build_array('bc',r.map_id,r.n));
 end loop;
 for part in select value from jsonb_array_elements(rows) loop
  if jsonb_array_length(page_rows)>=64 or octet_length((page_rows||jsonb_build_array(part))::text)>12000 then
   insert into lakebound_private.cloud_checkpoint_pages values(uid,rev,n,page_rows);n:=n+1;page_rows:='[]';
  end if;
  if octet_length(part::text)>12000 then raise exception 'checkpoint_entry_too_large';end if;
  page_rows:=page_rows||jsonb_build_array(part);
 end loop;
 insert into lakebound_private.cloud_checkpoint_pages values(uid,rev,n,page_rows);
 insert into lakebound_private.cloud_checkpoints values(uid,rev,n+1,now());
 -- Keep three immutable revisions, so paging a snapshot cannot mix versions.
 delete from lakebound_private.cloud_checkpoint_pages where auth_id=uid and revision not in(select revision from lakebound_private.cloud_checkpoints where auth_id=uid order by revision desc limit 3);
 delete from lakebound_private.cloud_checkpoints where auth_id=uid and revision not in(select revision from lakebound_private.cloud_checkpoints where auth_id=uid order by revision desc limit 3);
 return rev;
end $$;
alter function public.lakebound_sync(jsonb) rename to lakebound_sync_core;
alter function public.lakebound_sync_core(jsonb) set schema lakebound_private;
revoke all on function lakebound_private.lakebound_sync_core(jsonb) from public,anon,authenticated;
create function public.lakebound_sync(p jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' set statement_timeout='8s' as $$
declare uid uuid:=auth.uid();response jsonb;rev bigint;requested_page integer;rows jsonb;since bigint;delta jsonb;begin
 response:=lakebound_private.lakebound_sync_core(p);
 if jsonb_typeof(response)='object' then return response;end if;
 rev:=(response->>1)::bigint;
 if p ? 'g' then
  if p ? 'f' or p ? 'o' then raise exception 'invalid_restore_request';end if;
  rev:=lakebound_private.cloud_int(p->'g'->0,0,9007199254740991);
  requested_page:=lakebound_private.cloud_int(p->'g'->1,-1,10000);
  if requested_page=-1 then
   rev:=lakebound_private.cloud_checkpoint(uid);
   select jsonb_build_array(rev,pages) into rows from lakebound_private.cloud_checkpoints where auth_id=uid and revision=rev;
   return jsonb_build_array(2,rev,response->2,jsonb_build_object('cp',rows));
  end if;
  select data into rows from lakebound_private.cloud_checkpoint_pages where auth_id=uid and revision=rev and cloud_checkpoint_pages.page=requested_page;
  if rows is null then raise exception 'checkpoint_expired';end if;
  return jsonb_build_array(2,rev,response->2,jsonb_build_object('page',jsonb_build_array(rev,requested_page,rows)));
 end if;
 if not(p ? 'd') then return response;end if;
 since:=lakebound_private.cloud_int(coalesce(p->'r','0'),0,9007199254740991);
 if since>rev then raise exception 'revision_ahead';end if;
 delta:=coalesce(response->3,'{}');
 select coalesce(jsonb_agg(jsonb_build_array(lakebound_private.cloud_code('fish',s.species),s.count,s.total,s.best,s.smallest,s.last)),'[]') into rows
 from lakebound_private.cloud_stats s where auth_id=uid and exists(select 1 from lakebound_private.cloud_catches c join lakebound_private.cloud_events e using(auth_id,device,seq) where c.auth_id=uid and c.species=s.species and e.revision>since);
 if rows<>'[]' then delta:=delta||jsonb_build_object('h',rows);end if;
 if exists(select 1 from lakebound_private.cloud_events where auth_id=uid and device<>p->>'d' and revision>since) then
  delta:=delta||jsonb_build_object('resync',true);
 end if;
 return case when delta='{}' then response else jsonb_build_array(2,rev,response->2,delta) end;
exception when raise_exception then return jsonb_build_object('error',sqlerrm);
 when invalid_text_representation or numeric_value_out_of_range then return jsonb_build_object('error','invalid_payload');
end $$;
revoke all on function public.lakebound_sync(jsonb) from public,anon;
grant execute on function public.lakebound_sync(jsonb) to authenticated;
revoke all on all functions in schema lakebound_private from public,anon,authenticated;
commit;

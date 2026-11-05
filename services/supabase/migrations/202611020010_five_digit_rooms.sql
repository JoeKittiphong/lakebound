-- Keep UUID membership/Realtime authorization; only the human join code changes.
begin;
lock table lakebound_private.match_rooms in share row exclusive mode;
do $migration$
declare definition text; previous text; insertion text; replacement text; room record; candidate text; attempt integer; updated boolean;
begin
 definition:=pg_get_functiondef('lakebound_private.lakebound_matches(jsonb)'::regprocedure);
 previous:=$old$rc:=upper(substr(replace(gen_random_uuid()::text,'-',''),1,10));$old$;
 insertion:=$old$insert into lakebound_private.match_rooms(code,host,map_id) values(rc,pid,payload->>'map') returning id into rid;$old$;
 replacement:=$new$  -- Five decimal digits, including leading zeros. Retry collisions atomically.
  for n in 1..128 loop
   rc:=lpad(floor(random()*100000)::integer::text,5,'0');
   insert into lakebound_private.match_rooms(code,host,map_id) values(rc,pid,payload->>'map')
    on conflict(code) do nothing returning id into rid;
   exit when rid is not null;
  end loop;
  if rid is null then raise exception 'room_codes_busy'; end if;$new$;
 -- Match statements separately; deployment line endings/indentation can differ.
 if strpos(definition,previous)>0 then
  if strpos(definition,insertion)=0 then raise exception 'unexpected_room_insert'; end if;
  definition:=replace(definition,insertion,'');
  definition:=replace(definition,previous,replacement);
  if strpos(definition,'^[A-Za-z0-9]{10}$')=0 then raise exception 'unexpected_join_validator'; end if;
  definition:=replace(definition,'^[A-Za-z0-9]{10}$','^[0-9]{5}$');
  execute definition;
 elsif strpos(definition,'for n in 1..128 loop')=0 or strpos(definition,'^[0-9]{5}$')=0 then
  raise exception 'unexpected_match_function';
 end if;
 -- Preserve existing rooms, round IDs, members and scores while updating codes.
 for room in select id from lakebound_private.match_rooms where code !~ '^[0-9]{5}$' order by id loop
  updated:=false;
  for attempt in 1..128 loop
   candidate:=lpad(floor(random()*100000)::integer::text,5,'0');
   begin
    update lakebound_private.match_rooms set code=candidate where id=room.id;
    updated:=true;
    exit;
   exception when unique_violation then null;
   end;
  end loop;
  if not updated then raise exception 'room_codes_busy'; end if;
 end loop;
end $migration$;
commit;

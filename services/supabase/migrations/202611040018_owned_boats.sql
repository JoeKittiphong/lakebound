-- Append-only catalog update. No balance grants, world hulls or existing-save resets.
do $boats$
declare catalog jsonb; item_id integer; source text;
begin
 select data into catalog from lakebound_private.cloud_catalog where version=1 for update;
 if catalog is null then raise exception 'missing_cloud_catalog'; end if;
 select ordinality-1 into item_id from jsonb_array_elements_text(catalog->'item') with ordinality where value='lake_skiff';
 if item_id is null then
  item_id:=jsonb_array_length(catalog->'item');
  if item_id<>81 then raise exception 'unexpected_boat_wire_id_%',item_id;end if;
  catalog:=jsonb_set(catalog,'{item}',(catalog->'item')||'"lake_skiff"'::jsonb);
 end if;
 if item_id<>81 then raise exception 'boat_catalog_mismatch';end if;
 catalog:=jsonb_set(catalog,array['defs','item',item_id::text],'{"id":"lake_skiff","price":1500,"quantity":1,"kind":"boat","recovery":2,"capacity_g":25000,"length_cm":6500}'::jsonb);
 update lakebound_private.cloud_catalog set data=catalog where version=1;
 select pg_get_functiondef('lakebound_private.cloud_apply(uuid,text,bigint,text,jsonb,jsonb,bigint)'::regprocedure) into source;
 if position('''rod'',''reel'',''line'',''bait'',''lure'',''box'',''boat''' in source)=0 then
  if position('''rod'',''reel'',''line'',''bait'',''lure'',''box''' in source)=0 then raise exception 'unexpected_slot_guard';end if;
  source:=replace(source,'''rod'',''reel'',''line'',''bait'',''lure'',''box''','''rod'',''reel'',''line'',''bait'',''lure'',''box'',''boat''');
  execute source;
 end if;
end $boats$;

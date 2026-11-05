-- Additive cloud API. Requires Google accounts migration 004, no reset script.
begin;
create table lakebound_private.cloud_catalog(version integer primary key,data jsonb not null);
create table lakebound_private.cloud_state(
 auth_id uuid primary key references lakebound_private.accounts(auth_id),
 revision bigint not null default 0, data jsonb not null, updated_at timestamptz not null default now());
create table lakebound_private.cloud_devices(
 auth_id uuid references lakebound_private.cloud_state,device text check(device ~ '^[a-f0-9]{16}$'),
 ack bigint not null default 0,primary key(auth_id,device));
create table lakebound_private.cloud_events(
 auth_id uuid,device text,seq bigint check(seq between 1 and 9007199254740991),
 fingerprint text not null,result jsonb not null default 'null',revision bigint not null,
 primary key(auth_id,device,seq),foreign key(auth_id,device) references lakebound_private.cloud_devices);
create table lakebound_private.cloud_catches(
 auth_id uuid references lakebound_private.cloud_state,catch_id text check(length(catch_id) between 1 and 128),
 device text not null,seq bigint not null,map_id text not null,species text not null,
 grams bigint not null check(grams between 1 and 1000000000),time_ms bigint not null,depth_cm integer not null,
 bait text not null,context integer not null,fish_key text not null,flags integer not null,location jsonb,
 primary key(auth_id,catch_id));
create index cloud_catches_order on lakebound_private.cloud_catches(auth_id,species,grams desc,time_ms,catch_id);
create table lakebound_private.cloud_stats(
 auth_id uuid references lakebound_private.cloud_state,species text,count bigint not null,total bigint not null,
 best bigint not null,smallest bigint not null,last bigint not null,primary key(auth_id,species));
create table lakebound_private.cloud_contexts(auth_id uuid,device text,id integer,data jsonb not null,primary key(auth_id,device,id));
create table lakebound_private.cloud_ledger(auth_id uuid,device text,seq bigint,coins bigint,diamonds bigint,kind text,primary key(auth_id,device,seq));
create table lakebound_private.cloud_verified_receipts(
 receipt text primary key,auth_id uuid not null,coins integer not null default 0,diamonds integer not null default 0,
 applied boolean not null default false,provider text not null);
create table lakebound_private.cloud_checkpoint_pages(auth_id uuid,revision bigint,page integer,data jsonb not null,primary key(auth_id,revision,page));
create table lakebound_private.cloud_checkpoints(auth_id uuid,revision bigint,pages integer not null,created_at timestamptz not null default now(),primary key(auth_id,revision));
create table lakebound_private.cloud_settings(singleton boolean primary key default true check(singleton),enabled boolean not null default false,config_version integer not null default 1,config jsonb not null default '{}');
insert into lakebound_private.cloud_settings(singleton) values(true);
do $$ declare name text; begin
 foreach name in array array['cloud_catalog','cloud_state','cloud_devices','cloud_events','cloud_catches','cloud_stats','cloud_contexts','cloud_ledger','cloud_verified_receipts','cloud_checkpoint_pages','cloud_checkpoints','cloud_settings'] loop
  execute format('alter table lakebound_private.%I enable row level security',name);
  execute format('revoke all on lakebound_private.%I from public,anon,authenticated',name);
 end loop;
end $$;

create function lakebound_private.cloud_int(v jsonb,lo bigint,hi bigint) returns bigint
language plpgsql immutable set search_path='' as $$
declare n numeric;begin
 if jsonb_typeof(v) is distinct from 'number' then raise exception 'invalid_integer';end if;
 n:=(v#>>'{}')::numeric;
 if n<>trunc(n) or n<lo or n>hi then raise exception 'invalid_integer';end if;
 return n::bigint;
end $$;
create function lakebound_private.cloud_key(kind text,n jsonb) returns text
language plpgsql stable set search_path='' as $$
declare i integer;value text;begin
 i:=lakebound_private.cloud_int(n,0,100000);
 select data->kind->>i into value from lakebound_private.cloud_catalog where version=1;
 if value is null then raise exception 'unknown_catalog_id';end if;
 return value;
end $$;
create function lakebound_private.cloud_code(kind text,id text) returns integer
language sql stable set search_path='' as $$
 select (ordinality-1)::integer from lakebound_private.cloud_catalog,
 jsonb_array_elements_text(data->kind) with ordinality where version=1 and value=id limit 1
$$;
create function lakebound_private.cloud_default() returns jsonb
language plpgsql stable set search_path='' as $$
declare item text;i jsonb:='{}';e jsonb:='{}';begin
 foreach item in array array['worm','dough','minnow','light_rod','basic_reel','small_box'] loop
  i:=i||jsonb_build_object(lakebound_private.cloud_code('item',item)::text,case item when 'worm' then 20 when 'dough' then 10 else 1 end);
 end loop;
 e:=jsonb_build_object('bait',lakebound_private.cloud_code('item','worm'),'lure',lakebound_private.cloud_code('item','minnow'),
  'rod',lakebound_private.cloud_code('item','light_rod'),'reel',lakebound_private.cloud_code('item','basic_reel'),
  'box',lakebound_private.cloud_code('item','small_box'),'line',lakebound_private.cloud_code('item','nylon'));
 return jsonb_build_object('w',jsonb_build_array(350,0),'i',i,'sp','{}'::jsonb,'sl','{}'::jsonb,'e',e,'t',lakebound_private.cloud_code('rig','float'),
 'ln',6500,'b','[]'::jsonb,'p','{}'::jsonb,'m',jsonb_build_object('s',false,'t',0,'e','{}'::jsonb),'s','{}'::jsonb,'a','{}'::jsonb,'nx',1,'n','');
end $$;

-- Progress is derived from facts, never from a client-supplied progress total.
create function lakebound_private.cloud_missions(d jsonb,c lakebound_private.cloud_catches) returns jsonb
language plpgsql set search_path='' as $$
declare def record;entry jsonb;mid text;metric text;token text;progress numeric;target numeric;finger text;begin
 if not coalesce((d#>>'{m,s}')::boolean,false) or (c.flags&2)=0 then return d;end if;
 for def in select key,value from lakebound_private.cloud_catalog,jsonb_each(data#>'{defs,mission}') where version=1 loop
  mid:=def.key;metric:=def.value->>'metric';target:=(def.value->>'target')::numeric;
  if def.value->>'map'<>c.map_id or (def.value->>'species'<>'' and def.value->>'species'<>c.species)
  or (def.value->>'bait'<>'' and def.value->>'bait'<>c.bait) or c.grams<(def.value->>'min_g')::bigint
  or c.depth_cm<(def.value->>'min_depth')::integer or c.depth_cm>(def.value->>'max_depth')::integer
  or ((def.value->>'boss')::boolean and (c.flags&1)=0) then continue;end if;
  if def.value->>'kind'<>'any' and def.value->>'kind'<>coalesce((select value->>'kind' from lakebound_private.cloud_catalog,jsonb_each(data#>'{defs,item}') where version=1 and value->>'id'=c.bait),'') then continue;end if;
  entry:=coalesce(d#>array['m','e',mid],jsonb_build_array((def.value->>'revision')::integer,0,false,'[]'::jsonb,'[]'::jsonb));
  if (entry->>2)::boolean or (entry->>1)::numeric>=target then continue;end if;
  finger:=c.map_id||':'||c.fish_key;
  if entry->3 ? finger then continue;end if;
  token:=case when metric='species' then c.species when metric='baits' then c.bait else '' end;
  if token<>'' and entry->4 ? token then continue;end if;
  progress:=(entry->>1)::numeric+case when metric='weight' then c.grams::numeric/1000 else 1 end;
  entry:=jsonb_set(entry,'{1}',to_jsonb(least(progress,target)));
  entry:=jsonb_set(entry,'{3}',(entry->3)||to_jsonb(finger));
  if token<>'' then entry:=jsonb_set(entry,'{4}',(entry->4)||to_jsonb(token));end if;
  d:=jsonb_set(d,array['m','e',mid],entry,true);
 end loop;
 return d;
end $$;

create function lakebound_private.cloud_apply(uid uuid,device_id text,seq_id bigint,kind text,event_row jsonb,d jsonb,base_time bigint) returns jsonb
language plpgsql set search_path='' as $$
declare c lakebound_private.cloud_catches%rowtype;pid text;op integer;item integer;def jsonb;
 key text;key2 text;name text;amount integer;coin bigint;diamond bigint;cost bigint;entry jsonb;rec record;
 coins_before bigint:=(d#>>'{w,0}')::bigint;diamonds_before bigint:=(d#>>'{w,1}')::bigint;
begin
 if kind='f' then
  if jsonb_array_length(event_row)<>12 then raise exception 'invalid_catch';end if;
  c.auth_id:=uid;c.device:=device_id;c.seq:=seq_id;c.map_id:=lakebound_private.cloud_key('map',event_row->1);c.species:=lakebound_private.cloud_key('fish',event_row->2);
  if c.map_id='' or c.species='' then raise exception 'invalid_catch';end if;
  c.grams:=lakebound_private.cloud_int(event_row->3,1,1000000000);
  c.time_ms:=base_time+lakebound_private.cloud_int(event_row->4,-9007199254740991,9007199254740991);
  if c.time_ms<0 or c.time_ms>extract(epoch from now())*1000+86400000 then raise exception 'invalid_catch';end if;
  c.depth_cm:=lakebound_private.cloud_int(event_row->5,0,1000000);c.bait:=lakebound_private.cloud_key('item',event_row->6);
  c.context:=lakebound_private.cloud_int(event_row->7,1,2147483647);
  if not exists(select 1 from lakebound_private.cloud_contexts where auth_id=uid and device=device_id and id=c.context) then raise exception 'missing_context';end if;
  if jsonb_typeof(event_row->8)<>'string' or length(event_row->>8) not between 1 and 256 then raise exception 'invalid_fish_key';end if;
  c.fish_key:=event_row->>8;c.flags:=lakebound_private.cloud_int(event_row->9,0,3);c.location:=event_row->10;
  if c.location<>'null'::jsonb then
   if jsonb_typeof(c.location)<>'array' or jsonb_array_length(c.location)<>5 then raise exception 'invalid_location';end if;
   perform lakebound_private.cloud_int(c.location->0,-10000000,10000000);perform lakebound_private.cloud_int(c.location->1,-10000000,10000000);
   perform lakebound_private.cloud_int(c.location->2,-10000000,10000000);perform lakebound_private.cloud_int(c.location->3,-10000000,10000000);
   perform lakebound_private.cloud_int(c.location->4,0,1);
  end if;
  if jsonb_typeof(event_row->11)<>'string' or length(event_row->>11) not between 1 and 128 or event_row->>11 ~ '[[:cntrl:]]' then raise exception 'invalid_catch';end if;
  c.catch_id:=event_row->>11;
  if exists(select 1 from lakebound_private.cloud_catches where auth_id=uid and catch_id=c.catch_id) then raise exception 'duplicate_catch_id';end if;
  insert into lakebound_private.cloud_catches select c.*;
  insert into lakebound_private.cloud_stats as s values(uid,c.species,1,c.grams,c.grams,c.grams,c.grams)
  on conflict(auth_id,species) do update set count=s.count+1,total=s.total+excluded.total,best=greatest(s.best,excluded.best),smallest=least(s.smallest,excluded.smallest),last=excluded.last;
  select player_id into pid from lakebound_private.accounts where auth_id=uid;
  insert into lakebound_private.scores as sc values(pid,c.map_id,c.species,c.catch_id,c.grams,c.time_ms::numeric/1000)
  on conflict(player_id,map_id,species_id) do update set catch_id=excluded.catch_id,weight_g=excluded.weight_g,caught_at=excluded.caught_at
  where excluded.weight_g>sc.weight_g or (excluded.weight_g=sc.weight_g and (excluded.caught_at,excluded.catch_id)<(sc.caught_at,sc.catch_id));
  return lakebound_private.cloud_missions(d,c);
 end if;
 op:=lakebound_private.cloud_int(event_row->1,2,20);
 coin:=coins_before;diamond:=diamonds_before;
 if op=2 then
  item:=lakebound_private.cloud_int(event_row->2,1,100000);key:=item::text;
  select data#>array['defs','item',key] into def from lakebound_private.cloud_catalog where version=1;
  if def is null then raise exception 'unknown_catalog_id';end if;
  cost:=(def->>'price')::integer;
  if coin<cost then raise exception 'insufficient_coins';end if;
  if def->>'kind' not in ('bait','lure','line') and coalesce((d#>>array['i',key])::integer,0)>0 then raise exception 'already_owned';end if;
  if def->>'kind'='line' then d:=jsonb_set(d,array['sp',key],to_jsonb(coalesce((d#>>array['sp',key])::integer,0)+1),true);
  else d:=jsonb_set(d,array['i',key],to_jsonb(coalesce((d#>>array['i',key])::integer,0)+(def->>'quantity')::integer),true);end if;
  coin:=coin-cost;
 elsif op=3 then
  key:=lakebound_private.cloud_int(event_row->2,1,100000)::text;
  if coalesce((d#>>array['i',key])::integer,0)<1 then raise exception 'out_of_stock';end if;
  d:=jsonb_set(d,array['i',key],to_jsonb((d#>>array['i',key])::integer-1));
 elsif op=4 then
  key:=event_row->>2;
  select * into c from lakebound_private.cloud_catches where auth_id=uid and catch_id=key;
  if not found then raise exception 'unknown_catch';end if;
  if d->'b' ? key then raise exception 'already_stored';end if;
  select data#>array['defs','item',d#>>'{e,box}'] into def from lakebound_private.cloud_catalog where version=1;
  if def is null or (select coalesce(sum(grams),0) from lakebound_private.cloud_catches where auth_id=uid and d->'b' ? catch_id)+c.grams>(def->>'capacity_g')::bigint then raise exception 'box_full';end if;
  d:=jsonb_set(d,'{b}',(d->'b')||to_jsonb(key));
 elsif op=5 then
  if jsonb_typeof(event_row->2)<>'array' or jsonb_array_length(event_row->2)>100 then raise exception 'invalid_sale';end if;
  for key in select jsonb_array_elements_text(event_row->2) loop
   if not(d->'b' ? key) then raise exception 'not_stored';end if;
   select grams into cost from lakebound_private.cloud_catches where auth_id=uid and catch_id=key;
   coin:=coin+greatest(1,round(cost::numeric*35/1000)::bigint);
   d:=jsonb_set(d,'{b}',(d->'b')-key);
  end loop;
 elsif op=6 then
  key:=event_row->>2;
  if not(d->'b' ? key) then raise exception 'not_stored';end if;
  d:=jsonb_set(d,'{b}',(d->'b')-key);
 elsif op=7 then
  key:=lakebound_private.cloud_int(event_row->2,1,100000)::text;
  select data#>array['defs','mission',key] into def from lakebound_private.cloud_catalog where version=1;
  entry:=d#>array['m','e',key];
  if def is null or entry is null or (entry->>1)::numeric<(def->>'target')::numeric or (entry->>2)::boolean then raise exception 'reward_not_available';end if;
  d:=jsonb_set(d,array['m','e',key,'2'],'true');coin:=coin+(def->>'reward')::integer;
 elsif op=8 then
  amount:=lakebound_private.cloud_int(event_row->2,0,1);item:=lakebound_private.cloud_int(event_row->3,0,100000);
  if item<>0 then perform lakebound_private.cloud_key('mission',to_jsonb(item));end if;
  d:=jsonb_set(d,'{m,s}',to_jsonb(amount=1));d:=jsonb_set(d,'{m,t}',to_jsonb(item));
 elsif op=9 then
  item:=lakebound_private.cloud_int(event_row->2,1,2147483647);
  if jsonb_typeof(event_row->3)<>'array' or jsonb_array_length(event_row->3)<>4 then raise exception 'invalid_context';end if;
  perform lakebound_private.cloud_key('item',event_row->3->0);perform lakebound_private.cloud_key('item',event_row->3->1);perform lakebound_private.cloud_key('item',event_row->3->2);perform lakebound_private.cloud_key('rig',event_row->3->3);
  if exists(select 1 from lakebound_private.cloud_contexts where auth_id=uid and device=device_id and id=item and data<>event_row->3) then raise exception 'conflicting_context';end if;
  insert into lakebound_private.cloud_contexts values(uid,device_id,item,event_row->3) on conflict do nothing;
 elsif op=10 then
  key:=event_row->>2;name:=event_row->>3;
  if jsonb_typeof(event_row->2)<>'string' or jsonb_typeof(event_row->3)<>'string' or length(name)>240 or octet_length(name)>960 then raise exception 'invalid_note';end if;
  if not exists(select 1 from lakebound_private.cloud_catches where auth_id=uid and catch_id=key) then raise exception 'unknown_catch';end if;
  if name='' then d:=jsonb_set(d,'{a}',(d->'a')-key);else d:=jsonb_set(d,array['a',key],to_jsonb(name),true);end if;
 elsif op=11 then
  key:=event_row->>2;perform lakebound_private.cloud_key('map',event_row->3);
  perform lakebound_private.cloud_int(event_row->4,-10000000,10000000);perform lakebound_private.cloud_int(event_row->5,-10000000,10000000);perform lakebound_private.cloud_int(event_row->6,0,1);
  if jsonb_typeof(event_row->2)<>'string' or length(key) not between 1 and 128 or jsonb_typeof(event_row->7)<>'string' or length(event_row->>7)>80 or octet_length(event_row->>7)>320 then raise exception 'invalid_spot';end if;
  if not(d->'s' ? key) and (select count(*) from jsonb_object_keys(d->'s'))>=200 then raise exception 'too_many_spots';end if;
  d:=jsonb_set(d,array['s',key],jsonb_build_array(event_row->3,event_row->4,event_row->5,event_row->6,event_row->7),true);
  d:=jsonb_set(d,'{nx}',to_jsonb(greatest((d->>'nx')::bigint,lakebound_private.cloud_int(event_row->8,1,9007199254740991))));
 elsif op=12 then
  d:=jsonb_set(d,'{s}',(d->'s')-(event_row->>2));
 elsif op=13 then
  if jsonb_typeof(event_row->2)<>'object' then raise exception 'invalid_loadout';end if;
  for key,key2 in select k,v#>>'{}' from jsonb_each(event_row->2) x(k,v) loop
   if key not in ('rod','reel','line','bait','lure','box') then raise exception 'invalid_slot';end if;
   perform lakebound_private.cloud_key('item',to_jsonb(key2::integer));
   if key2<>'0' and key2<>d#>>array['e',key] and coalesce((d#>>array['i',key2])::integer,0)<1 then raise exception 'not_owned';end if;
  end loop;
  d:=jsonb_set(d,'{e}',event_row->2);perform lakebound_private.cloud_key('rig',event_row->3);d:=jsonb_set(d,'{t}',event_row->3);
 elsif op=14 then
  amount:=lakebound_private.cloud_int(event_row->2,0,10000000);key:=lakebound_private.cloud_int(event_row->3,0,100000)::text;
  d:=jsonb_set(d,'{ln}',to_jsonb(greatest(0,(d->>'ln')::integer-amount)));
  if key<>'0' then
   select data#>array['defs','item',key] into def from lakebound_private.cloud_catalog where version=1;
   if def->>'kind'='lure' and coalesce((d#>>array['i',key])::integer,0)>0 then
    d:=jsonb_set(d,array['i',key],to_jsonb((d#>>array['i',key])::integer-1));
    d:=jsonb_set(d,'{p}',jsonb_build_object('id',event_row#>>'{4,id}','lure',key::integer,'cost',(def->>'recovery')::integer));
   end if;
  end if;
 elsif op=15 then d:=jsonb_set(d,'{p}','{}');
 elsif op=16 then
  if d->'p'='{}' or diamond<(d#>>'{p,cost}')::integer then raise exception 'recovery_unavailable';end if;
  diamond:=diamond-(d#>>'{p,cost}')::integer;key:=d#>>'{p,lure}';
  d:=jsonb_set(d,array['i',key],to_jsonb(coalesce((d#>>array['i',key])::integer,0)+1),true);d:=jsonb_set(d,'{p}','{}');
 elsif op=17 then
  select * into rec from lakebound_private.cloud_verified_receipts where receipt=event_row->>2 and auth_id=uid and not applied for update;
  if not found then raise exception 'receipt_not_verified';end if;
  coin:=coin+rec.coins;diamond:=diamond+rec.diamonds;
  update lakebound_private.cloud_verified_receipts set applied=true where receipt=rec.receipt;
 elsif op=18 then
  key:=lakebound_private.cloud_code('item','worm')::text;key2:=lakebound_private.cloud_code('item','dough')::text;
  if coin>=20 or d->'b'<>'[]' or d->'p'<>'{}' or (coalesce((d#>>array['i',key])::integer,0)+coalesce((d#>>array['i',key2])::integer,0)>0 and (d->>'ln')::integer>=100) then raise exception 'supplies_not_available';end if;
  d:=jsonb_set(d,array['i',key],to_jsonb(greatest(3,coalesce((d#>>array['i',key])::integer,0))),true);
  d:=jsonb_set(d,'{e,bait}',to_jsonb(key::integer));
  if (d->>'ln')::integer<100 then d:=jsonb_set(d,'{ln}','1500');d:=jsonb_set(d,'{e,line}',to_jsonb(lakebound_private.cloud_code('item','fine_line')));end if;
 elsif op=19 then
  name:=btrim(event_row->>2);
  if jsonb_typeof(event_row->2)<>'string' or char_length(name) not between 2 and 24 or name ~ '[[:cntrl:]<>\[\]]' then raise exception 'invalid_name';end if;
  d:=jsonb_set(d,'{n}',to_jsonb(name));
  update lakebound_private.players set player_name=name,updated_at=now() where player_id=(select player_id from lakebound_private.accounts where auth_id=uid);
 elsif op=20 then
  key:=lakebound_private.cloud_int(event_row->2,1,100000)::text;
  select data#>array['defs','item',key] into def from lakebound_private.cloud_catalog where version=1;
  if def is null then raise exception 'unknown_catalog_id';end if;
  name:=def->>'kind';
  if name='line' then
   if coalesce((d#>>array['sp',key])::integer,0)<1 then raise exception 'out_of_stock';end if;
   key2:=d#>>'{e,line}';
   if key2<>'0' and (d->>'ln')::integer>0 then d:=jsonb_set(d,array['sl',key2],coalesce(d#>array['sl',key2],'[]')||to_jsonb((d->>'ln')::integer),true);end if;
   d:=jsonb_set(d,array['sp',key],to_jsonb((d#>>array['sp',key])::integer-1));d:=jsonb_set(d,'{ln}',def->'length_cm');
  elsif coalesce((d#>>array['i',key])::integer,0)<1 then raise exception 'not_owned';end if;
  if name='rod' and key<>d#>>'{e,rod}' then d:=jsonb_set(d,'{e,reel}','0');d:=jsonb_set(d,'{e,line}','0');d:=jsonb_set(d,'{e,bait}','0');d:=jsonb_set(d,'{ln}','0');d:=jsonb_set(d,'{t}','0');end if;
  d:=jsonb_set(d,array['e',name],to_jsonb(key::integer));
  if name in ('bait','lure') then d:=jsonb_set(d,'{e,bait}',to_jsonb(key::integer));end if;
 end if;
 d:=jsonb_set(d,'{w}',jsonb_build_array(coin,diamond));
 if coin<>coins_before or diamond<>diamonds_before then insert into lakebound_private.cloud_ledger values(uid,device_id,seq_id,coin-coins_before,diamond-diamonds_before,'op:'||op);end if;
 return d;
end $$;

create function public.lakebound_sync(p jsonb) returns jsonb
language plpgsql volatile security definer set search_path='' set statement_timeout='8s' as $$
declare uid uuid:=auth.uid();device_id text;rev bigint;ack_id bigint;seq_id bigint;d jsonb;before jsonb;event record;
 event_row jsonb;canonical jsonb;finger text;prior text;outcome jsonb;delta jsonb:='{}';rejections jsonb:='[]';base_time bigint:=0;lm text;leader jsonb;lv text;touched jsonb:='{}';event_before jsonb;changed jsonb;
begin
 if uid is null or coalesce(auth.jwt()->'app_metadata'->>'provider','')<>'google' or coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then return jsonb_build_object('error','google_login_required');end if;
 if not exists(select 1 from lakebound_private.accounts where auth_id=uid) then return jsonb_build_object('error','account_not_ready');end if;
 if not(select enabled from lakebound_private.cloud_settings where singleton) then return jsonb_build_object('error','cloud_not_enabled');end if;
 if jsonb_typeof(p) is distinct from 'object' or octet_length(p::text)>32768 or p->>'v' is distinct from '2' then raise exception 'invalid_payload';end if;
 if p ? 'c' and p->>'c'<>'1' then raise exception 'catalog_version';end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text,73));
 insert into lakebound_private.cloud_state(auth_id,data) values(uid,lakebound_private.cloud_default()) on conflict do nothing;
 select revision,data into rev,d from lakebound_private.cloud_state where auth_id=uid for update;
 if not(p ? 'd') then return jsonb_build_array(2,rev);end if;
 device_id:=p->>'d';if jsonb_typeof(p->'d')<>'string' or device_id !~ '^[a-f0-9]{16}$' then raise exception 'invalid_device';end if;
 insert into lakebound_private.cloud_devices values(uid,device_id,0) on conflict do nothing;
 select ack into ack_id from lakebound_private.cloud_devices where auth_id=uid and device=device_id for update;
 if p ? 't' then base_time:=lakebound_private.cloud_int(p->'t',0,9007199254740991);end if;
 if jsonb_typeof(coalesce(p->'f','[]'))<>'array' or jsonb_typeof(coalesce(p->'o','[]'))<>'array' or jsonb_array_length(coalesce(p->'f','[]'))+jsonb_array_length(coalesce(p->'o','[]'))>64 then raise exception 'invalid_batch';end if;
 before:=d;
 for event in select kind,value from (select 'f' kind,value from jsonb_array_elements(coalesce(p->'f','[]')) union all select 'o',value from jsonb_array_elements(coalesce(p->'o','[]'))) incoming_rows order by lakebound_private.cloud_int(value->0,1,9007199254740991) loop
  event_row:=event.value;if jsonb_typeof(event_row)<>'array' then raise exception 'invalid_event';end if;
  seq_id:=lakebound_private.cloud_int(event_row->0,1,9007199254740991);canonical:=event_row;
  if event.kind='f' then canonical:=jsonb_set(event_row,'{4}',to_jsonb(base_time+lakebound_private.cloud_int(event_row->4,-9007199254740991,9007199254740991)));end if;
  finger:=md5(event.kind||canonical::text);
  select fingerprint,result into prior,outcome from lakebound_private.cloud_events where auth_id=uid and device=device_id and seq=seq_id;
  if found then
   if prior<>finger then raise exception 'conflicting_event';end if;
   if outcome ? 'e' then rejections:=rejections||jsonb_build_array(jsonb_build_array(seq_id,outcome->'e'));end if;
   for lm in select jsonb_array_elements_text(coalesce(outcome->'k','[]')) loop touched:=touched||jsonb_build_object(lm,true);end loop;
   continue;
  end if;
  if seq_id<>ack_id+1 then raise exception 'sequence_gap';end if;
  outcome:='{}';event_before:=d;
  begin
   d:=lakebound_private.cloud_apply(uid,device_id,seq_id,event.kind,event_row,d,base_time);
  exception when raise_exception then
   if sqlerrm not in ('insufficient_coins','already_owned','out_of_stock','unknown_catch','already_stored','box_full','not_stored','reward_not_available','not_owned','recovery_unavailable','receipt_not_verified','supplies_not_available','duplicate_catch_id') then raise;end if;
   outcome:=jsonb_build_object('e',sqlerrm);rejections:=rejections||jsonb_build_array(jsonb_build_array(seq_id,sqlerrm));
  end;
  changed:='[]';
  for lm,leader in select key,value from jsonb_each(d) loop
   if leader is distinct from event_before->lm then changed:=changed||to_jsonb(lm);touched:=touched||jsonb_build_object(lm,true);end if;
  end loop;
  outcome:=outcome||jsonb_build_object('k',changed);
  rev:=rev+1;ack_id:=seq_id;
  insert into lakebound_private.cloud_events values(uid,device_id,seq_id,finger,outcome,rev);
 end loop;
 update lakebound_private.cloud_devices set ack=ack_id where auth_id=uid and device=device_id;
 update lakebound_private.cloud_state set revision=rev,data=d,updated_at=now() where auth_id=uid;
 -- Send changed economy/loadout fields, not an entire save or journal.
 for lm,leader in select key,value from jsonb_each(d) loop
  if leader is distinct from before->lm or touched ? lm then delta:=delta||jsonb_build_object(lm,leader);end if;
 end loop;
 if rejections<>'[]' then delta:=delta||jsonb_build_object('reject',rejections);end if;
 if p ? 'l' then
  lm:=lakebound_private.cloud_key('map',p->'l'->0);
  select jsonb_build_array(sc.player_id,pl.player_name,lakebound_private.cloud_code('fish',sc.species_id),sc.weight_g)
   into leader from lakebound_private.scores sc join lakebound_private.players pl using(player_id)
   where sc.map_id=lm order by weight_g desc,caught_at,player_id,catch_id,species_id limit 1;
  leader:=coalesce(leader,'[]');lv:=md5(leader::text);
  if lv is distinct from p#>>'{l,1}' then delta:=delta||jsonb_build_object('leader',jsonb_build_array(p->'l'->0,lv,leader));end if;
 end if;
 return case when delta='{}' then jsonb_build_array(2,rev,ack_id) else jsonb_build_array(2,rev,ack_id,delta) end;
exception when raise_exception then return jsonb_build_object('error',sqlerrm);
 when invalid_text_representation or numeric_value_out_of_range or not_null_violation or check_violation then return jsonb_build_object('error','invalid_payload');
end $$;
revoke all on all functions in schema lakebound_private from public,anon,authenticated;
revoke all on function public.lakebound_sync(jsonb) from public,anon;
grant execute on function public.lakebound_sync(jsonb) to authenticated;
commit;

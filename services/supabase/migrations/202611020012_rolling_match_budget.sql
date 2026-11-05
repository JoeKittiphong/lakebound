-- Billing periods can start on any day. Reserve over 33 UTC dates instead of
-- resetting on calendar-month boundaries; keep the existing private column name.
begin;
do $patch$
declare d text; old_key text:=$s$month_key:=date_trunc('month',stamp at time zone 'UTC')::date;$s$;
 old_sum text:=$s$select reserved into used from lakebound_private.match_budget where month=month_key;$s$;
begin
 d:=pg_get_functiondef('public.lakebound_matches(jsonb)'::regprocedure);
 if strpos(d,old_key)=0 or strpos(d,old_sum)=0 then raise exception 'unexpected_budget_gateway'; end if;
 d:=replace(d,old_key,$s$month_key:=(stamp at time zone 'UTC')::date;$s$);
 d:=replace(d,old_sum,$s$select coalesce(sum(reserved),0) into used from lakebound_private.match_budget where month>=month_key-32;$s$);
 execute d;
end $patch$;
commit;

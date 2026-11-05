"""Validate a private Sheets XLSX backup and prepare an atomic SQL import.

Never prints credential hashes. Output belongs in ignored .local/, not source.
Run with the bundled Python runtime (openpyxl is used only for extraction).
"""
import argparse
import datetime as dt
import hashlib
import json
import re
from pathlib import Path
import openpyxl

MAPS = {'river','lotus_marsh','forest_stream','wild_reservoir','mangrove_estuary','coral_coast'}

def text(value):
    return str(value or '').removeprefix("'")

def timestamp(value):
    if isinstance(value, dt.datetime):
        return value.replace(tzinfo=value.tzinfo or dt.timezone.utc).timestamp()
    return dt.datetime.fromisoformat(str(value).replace('Z','+00:00')).timestamp()

def quote(value):
    return "'" + str(value).replace("'", "''") + "'"

def prepare(source, output):
    output.mkdir(parents=True, exist_ok=True)
    book = openpyxl.load_workbook(source, read_only=True, data_only=True)
    catalog_sql=(Path(__file__).parent/'migrations/202611020002_catalog.sql').read_text()
    species=set(re.findall(r"\('([^']+)'\)",catalog_sql))
    def rows(name, header):
        sheet=book[name]
        values=sheet.iter_rows(values_only=True)
        actual=next(values)
        if list(actual[:len(header)]) != header:
            raise ValueError(f'{name}: unexpected columns')
        return [r for r in values if r and r[0] is not None and str(r[0]).strip()]
    players=rows('Players',['player_id','player_name','token_hash','created_at_utc','updated_at_utc'])
    scores=rows('Scores',['player_id','map_id','species_id','catch_id','fish_name','weight_g','caught_at_utc'])
    ids=set(); keys=set(); statements=['begin;']
    for r in players:
        pid,name,digest=map(text,r[:3])
        assert re.fullmatch('[a-f0-9]{32}',pid), 'Invalid player ID'
        assert pid not in ids, 'Duplicate player ID'
        assert 2<=len(name.strip())<=24 and not re.search(r'[\x00-\x1f<>\[\]]',name), 'Invalid player name'
        assert re.fullmatch(r'[A-Za-z0-9_-]{43}=',digest), 'Invalid legacy digest'
        ids.add(pid)
        created,updated=timestamp(r[3]),timestamp(r[4])
        statements.append('insert into lakebound_private.players as p(player_id,player_name,token_hash,created_at,updated_at) values ('+
          ','.join([quote(pid),quote(name.strip()),quote(digest),f'to_timestamp({created})',f'to_timestamp({updated})'])+
          ') on conflict(player_id) do update set player_name=excluded.player_name,updated_at=excluded.updated_at where p.token_hash=excluded.token_hash and p.updated_at<excluded.updated_at;')
        # Never overwrite credentials of an existing guest, even on an accidental re-import.
        statements.append(f"do $$ begin if not exists(select 1 from lakebound_private.players where player_id={quote(pid)} and token_hash={quote(digest)}) then raise exception 'Imported credential conflict'; end if; end $$;")
    for r in scores:
        pid,map_id,fish,catch_id=map(text,r[:4]); grams=int(r[5]); seconds=timestamp(r[6])
        assert pid in ids and map_id in MAPS and fish in species,'Invalid score references'
        assert 1<=grams<=1000000000 and float(r[5])==grams,'Invalid grams'
        assert seconds>=0 and seconds<=dt.datetime.now(dt.timezone.utc).timestamp()+86400,'Invalid catch time'
        assert 1<=len(catch_id)<=128 and not re.search(r'[\x00-\x1f]',catch_id),'Invalid catch ID'
        # Legacy workbooks can contain repeated map/species rows. The same
        # deterministic best-catch ordering as the RPC merges them safely.
        key=(pid,map_id,fish); keys.add(key)
        statements.append('insert into lakebound_private.scores as sc(player_id,map_id,species_id,catch_id,weight_g,caught_at) values ('+
          ','.join(map(quote,[pid,map_id,fish,catch_id]))+f',{grams},{seconds:.3f}) on conflict(player_id,map_id,species_id) do update set catch_id=excluded.catch_id,weight_g=excluded.weight_g,caught_at=excluded.caught_at where excluded.weight_g>sc.weight_g or (excluded.weight_g=sc.weight_g and (excluded.caught_at,excluded.catch_id)<(sc.caught_at,sc.catch_id));')
    statements+=['commit;','select (select count(*) from lakebound_private.players) as players,(select count(*) from lakebound_private.scores) as scores;']
    (output/'import.sql').write_text('\n'.join(statements),encoding='utf-8')
    manifest={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'players':len(players),'scores':len(keys),'source_score_rows':len(scores),'merged_rows':len(scores)-len(keys),'source':source.name}
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    book.close()
    print(json.dumps(manifest))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path)
    parser.add_argument('--output',type=Path,default=Path(__file__).parent/'.local')
    args=parser.parse_args(); prepare(args.source,args.output)

import test from 'node:test';import assert from 'node:assert/strict';import {Registry} from '../src/registry.mjs';
const player=i=>({id:i.toString(16).padStart(32,'0'),name:'QA '+i});
function fixture(){let time=1000;const r=new Registry({now:()=>time});r.presence(Array.from({length:101},(_,i)=>player(i+1).id));return {r,advance:n=>time+=n};}
test('100 players fill 20 isolated five-seat rooms and room 21 is denied',()=>{
 const {r}=fixture(),rooms=[];
 for(let i=1;i<=100;i++){const room=r.command(player(i),{op:'quick_join'});assert.equal(room.members.length,(i-1)%5+1);rooms.push(room.id);}
 assert.equal(new Set(rooms).size,20);assert.equal(r.playerCount(),100);
 assert.equal(r.command(player(101),{op:'quick_join'}).error,'capacity_full');
 assert.equal(r.command(player(1),{op:'state',room_id:rooms[5]}).error,'not_a_member');
 assert.equal(r.command(player(1),{op:'quick_join'}).id,rooms[0]);
 r.command(player(5),{op:'leave',room_id:rooms[0]});assert.equal(r.command(player(101),{op:'quick_join'}).id,rooms[0]);
 assert.ok([...r.rooms.values()].every(x=>JSON.stringify(x).length<131072));
});
test('loading barrier, round clock, fish exclusion, immutable retry, rematch and persistence',()=>{
 const {r,advance}=fixture(),a=player(1),b=player(2);let room=r.command(a,{op:'create',map:'river',duration:180,rule:'total_weight'});const id=room.id;
 assert.equal(r.command(b,{op:'join',code:room.code}).members.length,2);
 assert.equal(r.command(a,{op:'start',room_id:id}).error,'players_not_ready');
 for(const p of [a,b])r.command(p,{op:'ready',room_id:id,ready:true});
 assert.equal(r.command(b,{op:'start',room_id:id}).error,'host_only');
 assert.equal(r.command(a,{op:'start',room_id:id}).phase,'loading');
 assert.equal(r.command(a,{op:'loaded',room_id:id}).phase,'loading');
 room=r.command(b,{op:'loaded',room_id:id});assert.equal(room.phase,'countdown');assert.equal(room.ends_at-room.starts_at,180);
 const common={room_id:id,round_id:room.round_id,fish_id:1,species:'tilapia',grams:1234};
 assert.equal(r.command(a,{op:'claim_fish',...common}).error,'outside_match');advance(5);
 room=r.command(a,{op:'claim_fish',...common});const claim=room.fish_claims[0][2];
 assert.equal(r.command(b,{op:'claim_fish',...common}).error,'fish_taken');
 assert.equal(r.command(a,{op:'claim_fish',...common,grams:9999}).fish_claims[0][5],1234);
 const caught={op:'catch',...common,claim_id:claim,catch_id:'a'.repeat(32)};
 assert.equal(r.command(b,caught).error,'fish_claim_required');assert.equal(r.command(a,{...caught,grams:9999}).error,'fish_claim_mismatch');
 assert.equal(r.command(a,caught).members[0].grams,1234);assert.equal(r.command(a,caught).members[0].grams,1234);
 assert.equal(r.command(b,{op:'claim_fish',...common}).error,'fish_consumed');
 const restored=new Registry({rooms:structuredClone([...r.rooms.values()]),now:r.now});restored.presence([a.id,b.id]);
 assert.equal(restored.command(a,{op:'state',room_id:id}).members[0].grams,1234);
 advance(180);assert.equal(r.command(a,{op:'state',room_id:id}).phase,'finished');
 const next=r.command(a,{op:'rematch',room_id:id});assert.notEqual(next.round_id,common.round_id);assert.equal(next.members[0].grams,0);
 assert.equal(r.command(a,caught).error,'wrong_round');
});
test('rules, input validation, timeout and stale memberships',()=>{
 for(const mode of ['total_weight','biggest_fish','species_total']){
  const {r,advance}=fixture(),a=player(1),b=player(2);
  const room=r.command(a,{op:'create',map:'river',rule:mode,...(mode==='species_total'?{target_species:'tilapia'}:{})});
  r.command(b,{op:'join',code:room.code});for(const p of [a,b])r.command(p,{op:'ready',room_id:room.id,ready:true});r.command(a,{op:'start',room_id:room.id});for(const p of [a,b])r.command(p,{op:'loaded',room_id:room.id});advance(5);
  for(const [i,species,grams]of [[1,'tilapia',1000],[2,'tilapia',2000],[3,'snakehead',8000]]){
   const p={room_id:room.id,round_id:room.round_id,fish_id:i,species,grams};const claim=r.command(a,{...p,op:'claim_fish'}).fish_claims.find(c=>c[0]===i);
   r.command(a,{...p,op:'catch',claim_id:claim[2],catch_id:String(i).repeat(32)});
  }
  assert.equal(r.command(a,{op:'state',room_id:room.id}).members[0].grams,{total_weight:11000,biggest_fish:8000,species_total:3000}[mode]);
 }
 const {r,advance}=fixture(),a=player(1),b=player(2);
 for(const duration of [1,180.5,'180',null])assert.equal(r.command(a,{op:'create',map:'river',duration}).error,'invalid_duration');
 const room=r.command(a,{op:'create',map:'river'});r.command(b,{op:'join',code:room.code});
 r.presence([b.id]);r.disconnect(a.id);advance(76);
 assert.equal(r.command(b,{op:'state',room_id:room.id}).host,b.id);
 assert.equal(r.command(a,{op:'join',code:room.code}).members.filter(m=>m.id===a.id).length,1);
});
test('1,000 sequential users can play quick rooms without an artificial monthly reservation',()=>{
 const {r}=fixture();let count=0;
 for(let i=1;i<=1000;i++){
  const p=player(i);r.presence([p.id]);const room=r.command(p,{op:'quick_join'});assert.ok(room.id,room.error);r.command(p,{op:'leave',room_id:room.id});count++;
 }
 assert.equal(count,1000);r.cleanup();assert.ok(r.rooms.size<=20);
});
test('last explicit leave immediately deletes a running room, its code and fish state',()=>{
 const {r,advance}=fixture(),a=player(1),b=player(2);
 let room=r.command(a,{op:'quick_join'});r.command(b,{op:'join',code:room.code});
 for(const p of [a,b])r.command(p,{op:'ready',room_id:room.id,ready:true});r.command(a,{op:'start',room_id:room.id});
 for(const p of [a,b])r.command(p,{op:'loaded',room_id:room.id});advance(5);
 room=r.command(a,{op:'claim_fish',room_id:room.id,round_id:room.round_id,fish_id:1,species:'tilapia',grams:1234});
 assert.equal(r.command(a,{op:'leave',room_id:room.id}).phase,'running');
 assert.ok(r.rooms.has(room.id));
 const last=r.command(b,{op:'leave',room_id:room.id});assert.equal(last.phase,'cancelled');
 assert.equal(r.rooms.has(room.id),false);assert.equal(r.playerCount(),0);assert.ok(r.deleted.has(room.id));
 assert.equal(r.command(a,{op:'join',code:room.code}).error,'room_not_found');
 assert.equal(r.command(b,{op:'state',room_id:room.id}).error,'room_not_found');
 assert.equal(r.command(b,{op:'rematch',room_id:room.id}).error,'room_not_found');
 assert.notEqual(r.command(a,{op:'quick_join'}).id,room.id);
});
test('last socket disconnect releases room immediately; reconnect grace requires another online player',()=>{
 const {r}=fixture(),a=player(1),b=player(2);
 const room=r.command(a,{op:'quick_join'});r.command(b,{op:'join',code:room.code});
 r.presence([b.id]);r.disconnect(a.id);
 assert.ok(r.rooms.has(room.id));assert.equal(r.current(a.id).id,room.id);
 r.presence([a.id,b.id]);assert.equal(r.command(a,{op:'quick_join'}).id,room.id);
 r.presence([b.id]);r.disconnect(a.id);r.presence([]);r.disconnect(b.id);
 assert.equal(r.rooms.size,0);assert.equal(r.playerCount(),0);
 r.presence([a.id]);assert.equal(r.command(a,{op:'state',room_id:room.id}).error,'room_not_found');
 assert.notEqual(r.command(a,{op:'quick_join'}).id,room.id);
});

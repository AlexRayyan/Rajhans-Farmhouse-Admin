const {before,after,beforeEach,test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,getDocs,collection,writeBatch,Timestamp,serverTimestamp,deleteField,updateDoc,deleteDoc,runTransaction,query,where,setLogLevel}=require('firebase/firestore');
setLogLevel('silent');let env,serial=0;
const id=n=>String(n).padStart(20,'B');
const mutation=()=>String(++serial).padStart(20,'M');
const dayMs=86400000;
const futureYear=new Date().getUTCFullYear()+1;
const future=s=>s.replace('2027-',futureYear+'-');
const keys=b=>Array.from({length:(b.checkOutAt.toMillis()-b.checkInAt.toMillis())/dayMs},(_,i)=>String(b.checkInAt.toMillis()+i*dayMs));
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-rajhans',firestore:{rules:fs.readFileSync(path.join(__dirname,'../firestore/firestore.rules'),'utf8')}})});
after(async()=>{await env?.cleanup()});
beforeEach(async()=>{await env.clearFirestore();await env.withSecurityRulesDisabled(async ctx=>{const db=ctx.firestore();await setDoc(doc(db,'admins/owner'),{active:true});await setDoc(doc(db,'availability/state'),{slots:{},revision:0,lastBookingId:'',mutationId:'',updatedAt:Timestamp.fromMillis(0)})})});
const admin=()=>env.authenticatedContext('owner').firestore();
function booking(day='2027-01-30',nights=1,extra={},absolute=false){const start=new Date((absolute?day:future(day))+'T05:30:00Z');return {guestName:'Test Guest',phone:'+919876543210',notes:'',source:'phone',guestCount:2,totalPaise:1500000,paidPaise:0,
 checkInAt:Timestamp.fromDate(start),checkOutAt:Timestamp.fromMillis(start.getTime()+nights*dayMs),slotId:String(start.getTime()),slotIds:Array.from({length:nights},(_,i)=>String(start.getTime()+i*dayMs)),status:'confirmed',createdBy:'owner',updatedBy:'owner',createdAt:serverTimestamp(),updatedAt:serverTimestamp(),revision:0,mutationId:mutation(),...extra}}
async function reserve(db,bid,data,{transform,dropOld=true}={}){
 const stateRef=doc(db,'availability/state'),bookRef=doc(db,'bookings',bid);
 const state=(await getDoc(stateRef)).data(),previous=(await getDoc(bookRef)).data();const slots={...state.slots};
 if(previous&&dropOld)for(const key of keys(previous))delete slots[key];
 if(data.status==='confirmed')for(const key of keys(data))slots[key]=bid;
 if(transform)transform(slots);
 const batch=writeBatch(db);batch.set(bookRef,data);batch.set(stateRef,{...state,slots,revision:state.revision+1,lastBookingId:bid,mutationId:data.mutationId,updatedAt:serverTimestamp()});return batch.commit();
}
async function edit(db,bid,changes){const previous=(await getDoc(doc(db,'bookings',bid))).data();const combined={...previous,...changes};return {...combined,slotIds:keys(combined),revision:previous.revision+1,mutationId:mutation(),updatedAt:serverTimestamp()}}
test('one-day, multi-day and 100-guest bookings work; adjacent checkout can be reused',async()=>{const db=admin();await assertSucceeds(reserve(db,id(1),booking('2027-01-30',4)));await assertSucceeds(reserve(db,id(2),booking('2027-02-03',1,{guestCount:100})))});
test('maximum 31-night reservation and disjoint reschedule fit rule limits',async()=>{const db=admin();await assertSucceeds(reserve(db,id(1),booking('2027-01-01',31)));const next=booking('2027-07-01',31);await assertSucceeds(reserve(db,id(1),await edit(db,id(1),{checkInAt:next.checkInAt,checkOutAt:next.checkOutAt,slotId:next.slotId})))});
test('past dates are rejected on the server, while today is allowed',async()=>{const shifted=new Date(Date.now()+19800000);const today=shifted.toISOString().slice(0,10),past=new Date(Date.parse(today+'T00:00:00Z')-dayMs).toISOString().slice(0,10);const db=admin();await assertFails(reserve(db,id(1),booking(past,1,{},true)));await assertSucceeds(reserve(db,id(2),booking(today,1,{},true)))});
test('anonymous, non-admin and revoked users cannot read or write guest data',async()=>{for(const db of [env.unauthenticatedContext().firestore(),env.authenticatedContext('stranger').firestore()]){await assertFails(getDocs(collection(db,'bookings')));await assertFails(getDoc(doc(db,'availability/state')));await assertFails(setDoc(doc(db,'admins/stranger'),{active:true}))}const db=admin();await env.withSecurityRulesDisabled(ctx=>updateDoc(doc(ctx.firestore(),'admins/owner'),{active:false}));await assertFails(getDocs(collection(db,'bookings')))});
test('booking-only, availability-only and legacy slot writes are rejected',async()=>{const db=admin(),b=booking();await assertFails(setDoc(doc(db,'bookings',id(1)),b));await assertFails(updateDoc(doc(db,'availability/state'),{revision:1,mutationId:mutation(),lastBookingId:id(1),updatedAt:serverTimestamp()}));await assertFails(setDoc(doc(db,'slots',b.slotId),{bookingId:id(1),checkInAt:b.checkInAt}))});
test('overlapping multi-day reservations cannot overwrite an occupied middle night',async()=>{const db=admin();await reserve(db,id(1),booking('2027-01-30',4));await assertFails(reserve(db,id(2),booking('2027-02-01',5)))});
test('a missing middle night or an outside-range lock cannot pass coverage validation',async()=>{const db=admin(),b=booking('2027-01-30',4);await assertFails(reserve(db,id(1),b,{transform:slots=>delete slots[keys(b)[1]]}));await assertFails(reserve(db,id(1),booking('2027-01-30',4),{transform:slots=>{delete slots[keys(b)[1]];slots[String(b.checkOutAt.toMillis()+dayMs)]=id(1)}}))});
test('simultaneous transactions cannot both reserve overlapping dates',async()=>{const db=admin();async function create(bid,b){return runTransaction(db,async tx=>{const ref=doc(db,'availability/state'),state=(await tx.get(ref)).data(),slots={...state.slots};for(const key of keys(b)){if(slots[key])throw Error('occupied');slots[key]=bid}tx.set(doc(db,'bookings',bid),b);tx.set(ref,{slots,revision:state.revision+1,lastBookingId:bid,mutationId:b.mutationId,updatedAt:serverTimestamp()})})}const results=await Promise.allSettled([create(id(1),booking('2027-01-30',4)),create(id(2),booking('2027-02-01',3))]);assert.equal(results.filter(r=>r.status==='fulfilled').length,1)});
test('reschedule must release old exclusive nights and preserve unrelated bookings',async()=>{const db=admin();await reserve(db,id(1),booking('2027-01-30',4));await reserve(db,id(2),booking('2027-04-01',2));const next=booking('2027-02-01',4);const data=await edit(db,id(1),{checkInAt:next.checkInAt,checkOutAt:next.checkOutAt,slotId:next.slotId});await assertFails(reserve(db,id(1),data,{dropOld:false}));await assertFails(reserve(db,id(1),data,{transform:slots=>delete slots[String(Date.parse(future('2027-04-01T05:30:00Z')))]}));await assertSucceeds(reserve(db,id(1),data))});
test('cancellation releases all nights, retains the record and prevents reactivation',async()=>{const db=admin(),original=booking('2027-01-30',4);await reserve(db,id(1),original);const cancelled=await edit(db,id(1),{status:'cancelled'});await assertFails(reserve(db,id(1),cancelled,{dropOld:false}));await assertSucceeds(reserve(db,id(1),cancelled));await assertFails(deleteDoc(doc(db,'bookings',id(1))));await assertFails(reserve(db,id(1),await edit(db,id(1),{status:'confirmed'})));await assertSucceeds(reserve(db,id(2),booking('2027-01-30',4)))});
test('new guest counts are 2..100 and malformed amounts/audit/schema are denied',async()=>{const db=admin();for(const extra of [{guestCount:1},{guestCount:101},{guestCount:2.5},{totalPaise:-1},{totalPaise:1.5},{totalPaise:1000000001},{paidPaise:1500001},{guestName:'x'.repeat(121)},{notes:'x'.repeat(1001)},{createdBy:'stranger'},{createdAt:Timestamp.fromMillis(0)},{unknown:true},{slotIds:['bad']},{slotIds:[42]}])await assertFails(reserve(db,id(1),booking('2027-01-30',2,extra)))});
test('updates validate every field and preserve immutable creation audit',async()=>{const db=admin();await reserve(db,id(1),booking('2027-01-30',2));for(const extra of [{guestCount:101},{guestName:'x'.repeat(121)},{totalPaise:'10000'},{createdBy:'stranger'},{createdAt:Timestamp.fromMillis(0)},{paidPaise:1500001},{extra:true}])await assertFails(reserve(db,id(1),await edit(db,id(1),extra)));await assertSucceeds(reserve(db,id(1),await edit(db,id(1),{guestCount:100,guestName:'Edited Guest'})))});
test('non-whole nights, wrong check-in time and stays over 31 nights are rejected',async()=>{const db=admin(),b=booking();for(const extra of [{checkOutAt:Timestamp.fromMillis(b.checkInAt.toMillis()+dayMs+60000)},{checkInAt:Timestamp.fromMillis(b.checkInAt.toMillis()+60000),checkOutAt:Timestamp.fromMillis(b.checkOutAt.toMillis()+60000)},{checkOutAt:Timestamp.fromMillis(b.checkInAt.toMillis()+32*dayMs)}]){const data={...booking(),...extra};data.slotId=String(data.checkInAt.toMillis());data.slotIds=keys(data);await assertFails(reserve(db,id(1),data))}});
test('cross-month overlap query includes stays that began in the previous month',async()=>{const db=admin();await reserve(db,id(1),booking('2027-01-30',4));const result=await getDocs(query(collection(db,'bookings'),where('checkInAt','<',Timestamp.fromDate(new Date(future('2027-03-01T05:30:00Z')))),where('checkOutAt','>',Timestamp.fromDate(new Date(future('2027-02-01T05:30:00Z'))))));assert.equal(result.size,1)});
test('operator-migrated one-guest legacy bookings remain cancellable without data loss',async()=>{const b=booking('2027-01-30',1,{guestCount:1});delete b.mutationId;b.createdAt=Timestamp.fromMillis(0);b.updatedAt=Timestamp.fromMillis(0);await env.withSecurityRulesDisabled(async ctx=>{const db=ctx.firestore();await setDoc(doc(db,'bookings',id(1)),b);await updateDoc(doc(db,'availability/state'),{slots:{[b.slotId]:id(1)}})});const db=admin();await assertSucceeds(reserve(db,id(1),await edit(db,id(1),{status:'cancelled'})))});




const creationCode=()=>{const t=new Date(Date.now()+19800000);return String(t.getUTCDate()).padStart(2,'0')+String(t.getUTCMonth()+1).padStart(2,'0')+String(t.getUTCFullYear()%100).padStart(2,'0')};
async function namedReserve(db,day='2027-05-01',nights=2,extra={},changeState=x=>x) {
 const stateRef=doc(db,'availability/state');let result,observed;
 for(let attempt=0;;attempt++){try {
 await runTransaction(db,async tx=>{
  const state=(await tx.get(stateRef)).data(),date=creationCode(),number=state.sequenceDate===date?state.sequenceNumber+1:1;
  observed=state.revision;
  const code='RF'+date+(number===1?'':'-'+String(number).padStart(2,'0'));
  const data={...booking(day,nights),bookingCode:code,...extra};
  const bid='Test Guest - '+data.bookingCode,slots={...state.slots};
  await tx.get(doc(db,'bookings',bid));
  for(const key of keys(data)){if(slots[key])throw Error('occupied');slots[key]=bid}
  tx.set(doc(db,'bookings',bid),data);tx.set(stateRef,changeState({...state,slots,revision:state.revision+1,lastBookingId:bid,mutationId:data.mutationId,updatedAt:serverTimestamp(),sequenceDate:date,sequenceNumber:number}));result=bid;
 });return result;
 } catch(e){if(attempt>=3 || e.code!=='permission-denied' || (await getDoc(stateRef)).data().revision===observed)throw e;}
 }
}
test('readable IDs, 31-night stays and recorded advance/full payments are valid',async()=>{
 const db=admin(),bid=await namedReserve(db,'2027-05-01',31,{paidPaise:500000});
 assert.equal(bid,'Test Guest - RF'+creationCode());
 await assertSucceeds(reserve(db,bid,await edit(db,bid,{paidPaise:1500000})));
 await assertFails(reserve(db,bid,await edit(db,bid,{paidPaise:1500001})));
 await assertFails(reserve(db,bid,await edit(db,bid,{paidPaise:-1})));
 await assertFails(reserve(db,bid,await edit(db,bid,{paidPaise:1.5})));
 await assertFails(reserve(db,bid,await edit(db,bid,{bookingCode:'RF010100'})));
 await assertSucceeds(reserve(db,bid,await edit(db,bid,{status:'cancelled'})));
 assert.equal((await getDoc(doc(db,'bookings',bid))).data().paidPaise,1500000);
});
test('same-day codes increment atomically and reject duplicate, skipped or forged sequences',async()=>{
 const db=admin();await namedReserve(db,'2027-05-01');
 const second=await namedReserve(db,'2027-06-01');assert.equal(second,'Test Guest - RF'+creationCode()+'-02');
 await assertFails(namedReserve(db,'2027-07-01',1,{},s=>({...s,sequenceNumber:99})));
 await assertFails(namedReserve(db,'2027-07-01',1,{bookingCode:'RF010100'},s=>({...s,sequenceDate:'010100'})));
 await assertFails(namedReserve(db,'2027-07-01',1,{bookingCode:'RF'+creationCode()}));
 const bid='Test Guest - RF'+creationCode();const changed=await edit(db,bid,{guestName:'Renamed Guest'});
 await assertSucceeds(reserve(db,bid,changed));
 await assertFails(updateDoc(doc(db,'availability/state'),{sequenceNumber:0}));
});
test('concurrent named reservations allocate different codes without losing their locks',async()=>{
 const db=admin();const results=await Promise.all([namedReserve(db,'2027-05-01'),namedReserve(db,'2027-06-01')]);
 assert.equal(new Set(results).size,2);const state=(await getDoc(doc(db,'availability/state'))).data();assert.equal(state.sequenceNumber,2);assert.equal(Object.keys(state.slots).length,4);
});

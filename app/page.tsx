'use client'

import { useEffect, useMemo, useRef, useState } from 'react'
import { getSupabaseBrowserClient, loginNameToEmail } from '@/lib/supabase'

type Lang='en'|'mr'
type Role='Super Admin'|'Admin'|'Treasurer'|'Volunteer'|'Viewer'
type RouteRow={id:string;name:string}
type Donor={id:string;name:string;contactPerson:string;mobile:string;pan:string;reference:string;routeId:string;route:string;expected:number;received:number;lastYear:number;lastYearReceipt:string;status:'Pending'|'Partial'|'Collected'}
type Member={id:string;name:string;mobile:string;birthDate:string}
type AppUser={userId:string;loginName:string;name:string;mobile:string;role:Role;active:boolean}
type Receipt={id:string;paymentId:string;receiptNo:string;donorId:string;donorName:string;mobile:string;amount:number;amountWords:string;date:string;paymentReceivedDate:string;mode:string;paymentStatus:'paid'|'receipt_pending';type:'Normal'|'80G';pan:string;areaName:string;collector:string;chequeNo:string;bankName:string;googleDriveUrl:string;googleDriveFileId:string}
type ReceiptAudit={id:string;receiptId:string;receiptNo:string;editedBy:string;editedAt:string;reason:string;changes:Record<string,{from:any;to:any}>}
type ImportPreview={kind:'donors'|'members';valid:any[];invalid:{row:number;reason:string}[];fileName:string}

const roleFromDb=(r:string):Role=>r==='owner'?'Super Admin':r==='admin'?'Admin':r==='treasurer'?'Treasurer':r==='viewer'?'Viewer':'Volunteer'
const tr={
 en:{dashboard:'Dashboard',routeCollection:'Route Collection',donors:'Donors',pending:'Pending',receipts:'Receipts',eighty:'80G',members:'Members',reports:'Reports',admin:'Admin Panel',logout:'Logout',selectRoute:'Select Route',allRoutes:'All Routes',search:'Search donor, contact person, mobile or route',addDonor:'Add Donor',bulkDonors:'Bulk Upload Donors',bulkMembers:'Bulk Upload Members',addMember:'Add Member',addUser:'Add User',addRoute:'Add Route',collect:'Collect',expected:'Expected',collected:'Collected',pendingAmt:'Pending',donorsCount:'Total Donors',pendingDonors:'Pending Receipts',name:'Donor Name',contact:'Contact Person',mobile:'Mobile Number',route:'Route',lastDonation:'Last Year Donation',lastReceipt:'Last Year Receipt No.',balance:'Balance',status:'Status',save:'Save',cancel:'Cancel',paymentMode:'Payment Mode',pan:'PAN Number',amount:'Amount',receipt:'Receipt',userManagement:'User Management',loginName:'Login Name',password:'Password',role:'Role',active:'Active',birthDate:'Birth Date',downloadTemplate:'Download Template',upload:'Choose Excel / CSV',import:'Import Valid Rows',changeRoute:'Change Route',deleteDonor:'Delete',bulkDelete:'Delete Selected',confirmDelete:'Delete this donor?',confirmBulkDelete:'Delete all selected donors?',editCollectionRoute:'Edit Route',routeUpdated:'Route updated successfully.',editRoute:'Edit',editDonor:'Edit Donor',updateDonor:'Update Donor',deleteRoute:'Delete Route',confirmDeleteRoute:'Delete this route?',routeInUse:'This route still has donors. Change those donors to another route before deleting it.',editUser:'Edit User',updateUser:'Update User',optional:'Optional',manualReceipt:'Receipt Number',manualReceiptHelp:'Optional — enter only if a physical receipt is already issued',downloadCollectionExcel:'Download Collection Excel',paymentPending:'Receipt Given - Payment Pending',collectionDate:'Collection Date',reference:'Reference',daywise:'Day-wise Report',sendWhatsapp:'Send on WhatsApp',editReceipt:'Edit Receipt',receiptAudit:'Receipt Audit Log',editReason:'Reason for Edit',saveReceiptChanges:'Save Receipt Changes',saveAndSend:'Save & Send',donationCollected:'Donation Collected'},
 mr:{dashboard:'डॅशबोर्ड',routeCollection:'मार्गनिहाय संकलन',donors:'देणगीदार',pending:'बाकी',receipts:'पावत्या',eighty:'80G',members:'सदस्य',reports:'अहवाल',admin:'अॅडमिन पॅनेल',logout:'लॉगआउट',selectRoute:'मार्ग निवडा',allRoutes:'सर्व मार्ग',search:'देणगीदार, संपर्क व्यक्ती, मोबाईल किंवा मार्ग शोधा',addDonor:'देणगीदार जोडा',bulkDonors:'देणगीदार Bulk Upload',bulkMembers:'सदस्य Bulk Upload',addMember:'सदस्य जोडा',addUser:'वापरकर्ता जोडा',addRoute:'मार्ग जोडा',collect:'जमा करा',expected:'अपेक्षित',collected:'जमा',pendingAmt:'बाकी',donorsCount:'एकूण देणगीदार',pendingDonors:'बाकी पावत्या',name:'देणगीदाराचे नाव',contact:'संपर्क व्यक्ती',mobile:'मोबाईल नंबर',route:'मार्ग',lastDonation:'मागील वर्ष देणगी',lastReceipt:'मागील वर्ष पावती क्र.',balance:'बाकी',status:'स्थिती',save:'जतन करा',cancel:'रद्द',paymentMode:'पेमेंट पद्धत',pan:'PAN क्रमांक',amount:'रक्कम',receipt:'पावती',userManagement:'वापरकर्ता व्यवस्थापन',loginName:'लॉगिन नाव',password:'पासवर्ड',role:'भूमिका',active:'सक्रिय',birthDate:'जन्मतारीख',downloadTemplate:'टेम्पलेट डाउनलोड',upload:'Excel / CSV निवडा',import:'वैध नोंदी आयात करा',changeRoute:'मार्ग बदला',deleteDonor:'हटवा',bulkDelete:'निवडलेले हटवा',confirmDelete:'हा देणगीदार हटवायचा आहे का?',confirmBulkDelete:'निवडलेले सर्व देणगीदार हटवायचे आहेत का?',editCollectionRoute:'मार्ग बदला',routeUpdated:'मार्ग यशस्वीरित्या बदलला.',editRoute:'नाव बदला',deleteRoute:'मार्ग हटवा',confirmDeleteRoute:'हा मार्ग हटवायचा आहे का?',routeInUse:'या मार्गावर अजून देणगीदार आहेत. मार्ग हटवण्यापूर्वी त्या देणगीदारांचा मार्ग बदला.',editUser:'वापरकर्ता संपादित करा',updateUser:'वापरकर्ता अपडेट करा',optional:'ऐच्छिक',manualReceipt:'पावती क्रमांक',manualReceiptHelp:'ऐच्छिक — भौतिक पावती आधीच दिली असल्यासच भरा',downloadCollectionExcel:'कलेक्शन Excel डाउनलोड',paymentPending:'पावती दिली - पेमेंट बाकी',collectionDate:'संकलन दिनांक',reference:'संदर्भ',daywise:'दिवसनिहाय अहवाल',sendWhatsapp:'WhatsApp वर पाठवा',editReceipt:'पावती संपादित करा',receiptAudit:'पावती बदल नोंद',editReason:'बदलाचे कारण',saveReceiptChanges:'पावती बदल जतन करा',saveAndSend:'जतन करा आणि पाठवा',editDonor:'देणगीदार संपादित करा',updateDonor:'देणगीदार अपडेट करा',donationCollected:'देणगी जमा झाली'}
}
const money=(n:number)=>new Intl.NumberFormat('en-IN',{style:'currency',currency:'INR',maximumFractionDigits:0}).format(n)
const englishName=(v:string)=>/^[A-Za-z0-9 .,&'()\/-]+$/.test(v.trim())
const keyify=(v:string)=>String(v||'').trim().toLowerCase().replace(/[^a-z0-9]/g,'')
const normalizeSearch=(v:any)=>String(v??'').toLowerCase().trim().replace(/\s+/g,' ')
const searchMatches=(query:string,...values:any[])=>{
 const q=normalizeSearch(query)
 if(!q)return true
 const hay=values.map(normalizeSearch).join(' ')
 return q.split(' ').filter(Boolean).every(token=>hay.includes(token))
}
const findVal=(row:Record<string,any>,aliases:string[])=>{const m=Object.fromEntries(Object.entries(row).map(([k,v])=>[keyify(k),v]));for(const a of aliases){if(m[keyify(a)]!==undefined)return m[keyify(a)]}return ''}
const parseMoney=(v:any)=>{const n=Number(String(v??'').replace(/[₹,\s]/g,''));return Number.isFinite(n)?n:0}
const normalizeDate=(v:any)=>{if(!v)return null;if(v instanceof Date&&!isNaN(v.getTime()))return v.toISOString().slice(0,10);const s=String(v).trim();const m=s.match(/^(\d{1,2})[-\/.](\d{1,2})[-\/.](\d{4})$/);return m?`${m[3]}-${m[2].padStart(2,'0')}-${m[1].padStart(2,'0')}`:s}

export default function Home(){
 const supabase=useMemo(()=>getSupabaseBrowserClient(),[])
 const [lang,setLang]=useState<Lang>('en');const L=tr[lang]
 const [loading,setLoading]=useState(true);const [session,setSession]=useState<any>(null);const [profile,setProfile]=useState<AppUser|null>(null);const [orgId,setOrgId]=useState('');const [orgName,setOrgName]=useState('Rajasthan Yuvak Mandal')
 const [login,setLogin]=useState({username:'',password:''});const [loginError,setLoginError]=useState('');const [dayReportDate,setDayReportDate]=useState(new Date().toISOString().slice(0,10))
 const [active,setActive]=useState('dashboard');const [routes,setRoutes]=useState<RouteRow[]>([]);const [donors,setDonors]=useState<Donor[]>([]);const [members,setMembers]=useState<Member[]>([]);const [receipts,setReceipts]=useState<Receipt[]>([]);const [users,setUsers]=useState<AppUser[]>([]);const [receiptAudits,setReceiptAudits]=useState<ReceiptAudit[]>([]);const [driveConnected,setDriveConnected]=useState(false);const [driveBusy,setDriveBusy]=useState(false);const [bulkDriveUpload,setBulkDriveUpload]=useState({running:false,total:0,done:0,uploaded:0,skipped:0,failed:0,current:''})
 const [selectedRoute,setSelectedRoute]=useState('');const [pendingRoute,setPendingRoute]=useState('');const [q,setQ]=useState('');const [dashboardQ,setDashboardQ]=useState('');const [dashboardDonor,setDashboardDonor]=useState<Donor|null>(null);const [settleReceipt,setSettleReceipt]=useState<Receipt|null>(null);const [settleForm,setSettleForm]=useState({mode:'Cash',date:new Date().toISOString().slice(0,10),chequeNo:'',bankName:''});const [modal,setModal]=useState<string|null>(null);const [editReceipt,setEditReceipt]=useState<Receipt|null>(null);const [editReceiptForm,setEditReceiptForm]=useState({receiptNo:'',donorName:'',mobile:'',pan:'',date:'',amount:'',mode:'Cash',chequeNo:'',bankName:'',areaName:'',is80g:false,reason:''});const [selectedDonorIds,setSelectedDonorIds]=useState<string[]>([]);const [collectRouteEdit,setCollectRouteEdit]=useState(false);const [editingDonor,setEditingDonor]=useState<Donor|null>(null);const [editingUser,setEditingUser]=useState<AppUser|null>(null);const [selected,setSelected]=useState<Donor|null>(null);const [viewReceipt,setViewReceipt]=useState<Receipt|null>(null);const [preparedReceiptFile,setPreparedReceiptFile]=useState<File|null>(null);const [receiptSharePreparing,setReceiptSharePreparing]=useState(false);const [preview,setPreview]=useState<ImportPreview|null>(null);const fileRef=useRef<HTMLInputElement>(null)
 const [form,setForm]=useState({name:'',contactPerson:'',mobile:'',reference:'',routeId:'',expected:'',lastYear:'',lastReceipt:'',amount:'',receiptNumber:'',collectionDate:new Date().toISOString().slice(0,10),mode:'Cash',pan:'',is80g:false,chequeNo:'',bankName:'',memberName:'',memberMobile:'',birthDate:'',newRoute:'',userName:'',userMobile:'',username:'',password:'',role:'Volunteer' as Role,userActive:true})
 const isAdmin=profile&&['Super Admin','Admin'].includes(profile.role);const isSuperAdmin=profile?.role==='Super Admin';const canDownloadReports=!!profile&&['Super Admin','Admin','Treasurer'].includes(profile.role)

 useEffect(()=>{if(!supabase){setLoading(false);return}supabase.auth.getSession().then(({data})=>{setSession(data.session);if(data.session)loadAll(data.session.user.id);else setLoading(false)});const {data:sub}=supabase.auth.onAuthStateChange((_e,s)=>{setSession(s);if(!s){setProfile(null);setLoading(false)}});return()=>sub.subscription.unsubscribe()},[])

 useEffect(()=>{if(!session)return;loadDriveStatus();const p=new URLSearchParams(window.location.search);if(p.get('google_drive')==='connected'){setDriveConnected(true);window.history.replaceState({},'',window.location.pathname);alert('Google Drive connected successfully.')}else if(p.get('google_drive')==='error'){const msg=p.get('message')||'Google Drive connection failed.';window.history.replaceState({},'',window.location.pathname);alert(msg)}},[session])
 useEffect(()=>{let cancelled=false;if(modal!=='receipt'||!viewReceipt){setPreparedReceiptFile(null);setReceiptSharePreparing(false);return}setPreparedReceiptFile(null);setReceiptSharePreparing(true);createReceiptImage(viewReceipt).then(file=>{if(!cancelled)setPreparedReceiptFile(file)}).catch(()=>{if(!cancelled)setPreparedReceiptFile(null)}).finally(()=>{if(!cancelled)setReceiptSharePreparing(false)});return()=>{cancelled=true}},[modal,viewReceipt])

 async function loadAll(userId?:string){
  if(!supabase)return;setLoading(true)
  try{
   const uid=userId||session?.user?.id;if(!uid)return
   const {data:p,error:pe}=await supabase.from('organization_members').select('*').eq('user_id',uid).eq('active',true).single();if(pe)throw pe
   setOrgId(p.organization_id);setProfile({userId:p.user_id,loginName:p.login_name,name:p.display_name,mobile:p.mobile||'',role:roleFromDb(p.role),active:p.active})
   const [orgR,routeR,donorR,peopleR,paymentR,receiptR,userR,auditR]=await Promise.all([
    supabase.from('organizations').select('*').eq('id',p.organization_id).single(),
    supabase.from('routes').select('*').eq('organization_id',p.organization_id).eq('active',true).order('name'),
    supabase.from('donors').select('*,routes(name)').eq('organization_id',p.organization_id).eq('active',true).order('name'),
    supabase.from('organization_people').select('*').eq('organization_id',p.organization_id).eq('active',true).order('name'),
    supabase.from('payments').select('*').eq('organization_id',p.organization_id),
    supabase.from('receipts').select('*').eq('organization_id',p.organization_id).order('issued_at',{ascending:false}),
    supabase.from('organization_members').select('*').eq('organization_id',p.organization_id).order('display_name'),
    supabase.from('receipt_audit_log').select('*').eq('organization_id',p.organization_id).order('edited_at',{ascending:false}).limit(500)
   ])
   if(orgR.data)setOrgName(orgR.data.name);setRoutes((routeR.data||[]).map((r:any)=>({id:r.id,name:r.name})))
   const paid=new Map<string,number>();for(const x of paymentR.data||[])if((x.payment_status||'paid')==='paid')paid.set(x.donor_id,(paid.get(x.donor_id)||0)+Number(x.amount))
   setDonors((donorR.data||[]).map((d:any)=>{const received=paid.get(d.id)||0,expected=Number(d.current_expected_amount||0);return{id:d.id,name:d.name,contactPerson:d.contact_person||'',mobile:d.mobile||'',pan:d.pan||'',reference:d.reference||'',routeId:d.route_id||'',route:d.routes?.name||'',expected,received,lastYear:Number(d.last_year_donation||0),lastYearReceipt:d.last_year_receipt_number||'',status:received<=0?'Pending':received>=expected&&expected>0?'Collected':'Partial'}}))
   setMembers((peopleR.data||[]).map((m:any)=>({id:m.id,name:m.name,mobile:m.mobile,birthDate:m.birth_date||''})))
   setReceipts((receiptR.data||[]).map((r:any)=>{const pay=(paymentR.data||[]).find((p:any)=>p.id===r.payment_id);return {id:r.id,paymentId:r.payment_id,receiptNo:r.receipt_number,donorId:pay?.donor_id||'',donorName:r.donor_name_snapshot,mobile:r.donor_mobile_snapshot||'',amount:Number(pay?.amount||0),amountWords:r.amount_words_snapshot,date:pay?.payment_date?new Date(pay.payment_date+'T00:00:00').toLocaleDateString('en-GB').replaceAll('/','-'):new Date(r.issued_at).toLocaleDateString('en-GB').replaceAll('/','-'),paymentReceivedDate:pay?.payment_received_date?new Date(pay.payment_received_date+'T00:00:00').toLocaleDateString('en-GB').replaceAll('/','-'):'',mode:(pay?.payment_status==='receipt_pending'?'Receipt Given - Payment Pending':pay?.mode?String(pay.mode).replace(/^./,c=>c.toUpperCase()):r.payment_mode_snapshot),paymentStatus:(pay?.payment_status||'paid') as 'paid'|'receipt_pending',type:r.receipt_type==='80g'?'80G':'Normal',pan:r.donor_pan_snapshot||'',areaName:r.area_name_snapshot||'',collector:r.collected_by_name_snapshot,chequeNo:r.cheque_number_snapshot||'',bankName:r.bank_name_snapshot||'',googleDriveUrl:r.google_drive_url||'',googleDriveFileId:r.google_drive_file_id||''}}))
   setUsers((userR.data||[]).map((u:any)=>({userId:u.user_id,loginName:u.login_name,name:u.display_name,mobile:u.mobile||'',role:roleFromDb(u.role),active:u.active})))
   setReceiptAudits((auditR.data||[]).map((a:any)=>({id:a.id,receiptId:a.receipt_id,receiptNo:a.receipt_number_snapshot||'',editedBy:a.edited_by_name||'',editedAt:new Date(a.edited_at).toLocaleString('en-IN'),reason:a.reason||'',changes:a.changed_fields||{}})))
  }catch(e:any){setLoginError(e.message||'Could not load RYM_VARGANI data.')}finally{setLoading(false)}
 }

 async function doLogin(){if(!supabase)return;setLoginError('');const {data,error}=await supabase.auth.signInWithPassword({email:loginNameToEmail(login.username),password:login.password});if(error){setLoginError('Invalid login name or password.');return}setSession(data.session);await loadAll(data.user.id)}
 async function doLogout(){await supabase?.auth.signOut();setSession(null);setProfile(null);setOrgId('')}

 async function addDonor(){if(!supabase||!form.name.trim()||!orgId)return;if(!englishName(form.name)){alert('Donor Name must be in English only.');return}const payload={organization_id:orgId,name:form.name.trim(),contact_person:form.contactPerson.trim()||null,mobile:form.mobile.trim()||null,pan:form.pan.trim().toUpperCase()||null,reference:form.reference.trim()||null,route_id:form.routeId||null,current_expected_amount:parseMoney(form.expected),last_year_donation:parseMoney(form.lastYear),last_year_receipt_number:form.lastReceipt.trim()||null};const {error}=await supabase.from('donors').insert(payload);if(error)return alert(error.message);setModal(null);resetForm();await loadAll()}
 function openEditDonor(d:Donor){
  setEditingDonor(d)
  setForm(f=>({...f,name:d.name,contactPerson:d.contactPerson||'',mobile:d.mobile||'',pan:d.pan||'',reference:d.reference||'',routeId:d.routeId||'',expected:String(d.expected||0),lastYear:String(d.lastYear||0),lastReceipt:d.lastYearReceipt||''}))
  setModal('editDonor')
 }
 async function updateDonor(){
  if(!supabase||!editingDonor||!isAdmin)return
  if(!form.name.trim())return alert('Donor Name is required.')
  if(!englishName(form.name))return alert('Donor Name must be in English only.')
  const payload={name:form.name.trim(),contact_person:form.contactPerson.trim()||null,mobile:form.mobile.trim()||null,pan:form.pan.trim().toUpperCase()||null,reference:form.reference.trim()||null,route_id:form.routeId||null,current_expected_amount:parseMoney(form.expected),last_year_donation:parseMoney(form.lastYear),last_year_receipt_number:form.lastReceipt.trim()||null,updated_at:new Date().toISOString()}
  const {error}=await supabase.from('donors').update(payload).eq('id',editingDonor.id).eq('organization_id',orgId)
  if(error)return alert(error.message)
  setModal(null);setEditingDonor(null);resetForm();await loadAll();alert('Donor updated successfully.')
 }
 async function addMember(){if(!supabase||!form.memberName.trim()||!form.memberMobile.trim())return alert('Name and Mobile Number are compulsory.');const {error}=await supabase.from('organization_people').insert({organization_id:orgId,name:form.memberName.trim(),mobile:form.memberMobile.trim(),birth_date:form.birthDate||null});if(error)return alert(error.message);setModal(null);resetForm();await loadAll()}
 async function addRoute(){if(!supabase||!isAdmin||!form.newRoute.trim())return;const {error}=await supabase.from('routes').insert({organization_id:orgId,name:form.newRoute.trim()});if(error)return alert(error.message);setModal(null);resetForm();await loadAll()}
 async function renameRoute(route:RouteRow){if(!supabase||!isAdmin)return;const next=window.prompt(lang==='mr'?'नवीन मार्गाचे नाव':'New route name',route.name);if(next===null)return;const name=next.trim();if(!name||name===route.name)return;const {error}=await supabase.from('routes').update({name}).eq('id',route.id).eq('organization_id',orgId);if(error)return alert(error.message);await loadAll()}
 async function deleteRoute(route:RouteRow){if(!supabase||!isAdmin)return;const count=donors.filter(d=>d.routeId===route.id).length;if(count>0){alert(`${L.routeInUse} (${count})`);return}if(!window.confirm(`${L.confirmDeleteRoute}\n\n${route.name}`))return;const {error}=await supabase.from('routes').update({active:false}).eq('id',route.id).eq('organization_id',orgId);if(error)return alert(error.message);if(selectedRoute===route.id)setSelectedRoute('');await loadAll()}
 async function addUser(){if(!supabase||!isAdmin)return;const {data:{session:s}}=await supabase.auth.getSession();if(!s)return;const r=await fetch('/api/admin/users',{method:'POST',headers:{'content-type':'application/json',authorization:`Bearer ${s.access_token}`},body:JSON.stringify({loginName:form.username,password:form.password,displayName:form.userName,mobile:form.userMobile,role:form.role})});const j=await r.json();if(!r.ok)return alert(j.error);setModal(null);resetForm();await loadAll();alert('User created successfully.')}
 async function updateUser(){if(!supabase||!isSuperAdmin||!editingUser)return;const {data:{session:s}}=await supabase.auth.getSession();if(!s)return;const r=await fetch('/api/admin/users',{method:'PATCH',headers:{'content-type':'application/json',authorization:`Bearer ${s.access_token}`},body:JSON.stringify({userId:editingUser.userId,displayName:form.userName,mobile:form.userMobile,role:form.role,active:form.userActive,password:form.password||undefined})});const j=await r.json();if(!r.ok)return alert(j.error);setModal(null);setEditingUser(null);resetForm();await loadAll();alert('User updated successfully.')}
 async function openEditUser(u:AppUser){setEditingUser(u);setForm(f=>({...f,userName:u.name,userMobile:u.mobile,username:u.loginName,password:'',role:u.role,userActive:u.active}));setModal('editUser')}
 async function changeDonorRoute(donorId:string,routeId:string){if(!supabase)return;const {error}=await supabase.rpc('change_donor_route',{p_donor_id:donorId,p_route_id:routeId||null});if(error)return alert(error.message);await loadAll()}
 async function deleteDonor(d:Donor){if(!supabase||!isAdmin)return;if(!window.confirm(`${L.confirmDelete}\n\n${d.name}`))return;const {error}=await supabase.rpc('admin_remove_donor',{p_donor_id:d.id});if(error)return alert(error.message);if(selected?.id===d.id)setSelected(null);setSelectedDonorIds(ids=>ids.filter(id=>id!==d.id));await loadAll()}
 async function bulkDeleteDonors(){if(!supabase||!isSuperAdmin||!selectedDonorIds.length)return;if(!window.confirm(`${L.confirmBulkDelete}\n\n${selectedDonorIds.length} donor(s)`))return;for(const id of selectedDonorIds){const {error}=await supabase.rpc('admin_remove_donor',{p_donor_id:id});if(error){alert(error.message);return}}setSelectedDonorIds([]);await loadAll()}
 async function changeSelectedDonorRoute(routeId:string){if(!selected)return;await changeDonorRoute(selected.id,routeId);const r=routes.find(x=>x.id===routeId);setSelected({...selected,routeId,route:r?.name||''});setCollectRouteEdit(false)}
 function openCollection(d:Donor){
  if(d.status==='Collected')return
  setSelected(d);setCollectRouteEdit(false);resetForm();
  setForm(f=>({...f,amount:d.lastYear>0?String(d.lastYear):'',pan:d.pan}));
  setModal('collect')
 }
 async function collect(sendAfterSave=false){
  if(!supabase||!selected)return
  const amount=parseMoney(form.amount);if(amount<=0)return alert('Enter a valid amount.')
  if(form.receiptNumber.trim()){
   const duplicate=receipts.some(r=>r.receiptNo.trim().toLowerCase()===form.receiptNumber.trim().toLowerCase())
   if(duplicate)return alert(`Receipt number already exists: ${form.receiptNumber.trim()}`)
  }
  if(form.mode==='Cheque'&&!form.chequeNo.trim())return alert('Cheque Number is compulsory for cheque payment.')
  if(!form.collectionDate)return alert('Select collection date.')
  const whatsappWindow=sendAfterSave?window.open('about:blank','_blank'):null
  const isPaymentPending=form.mode==='Receipt Given - Payment Pending';const modeForDb=isPaymentPending?'other':form.mode.toLowerCase()
  const {data,error}=await supabase.rpc('record_donation',{p_donor_id:selected.id,p_amount:amount,p_mode:modeForDb,p_is_80g:form.is80g,p_pan:form.pan||selected.pan||null,p_cheque_no:form.chequeNo||null,p_bank_name:form.bankName||null,p_receipt_number:form.receiptNumber.trim()||null,p_payment_date:form.collectionDate,p_payment_pending:isPaymentPending})
  if(error){if(whatsappWindow&&!whatsappWindow.closed)whatsappWindow.close();return alert(error.message)}
  setModal(null);resetForm();await loadAll()
  const r=Array.isArray(data)?data[0]:data
  if(r){
   const issuedReceipt:Receipt={id:r.id,paymentId:r.payment_id,receiptNo:r.receipt_number,donorId:selected.id,donorName:r.donor_name_snapshot,mobile:r.donor_mobile_snapshot||'',amount,amountWords:r.amount_words_snapshot,date:new Date(form.collectionDate+'T00:00:00').toLocaleDateString('en-GB').replaceAll('/','-'),paymentReceivedDate:isPaymentPending?'':new Date(form.collectionDate+'T00:00:00').toLocaleDateString('en-GB').replaceAll('/','-'),mode:r.payment_mode_snapshot,paymentStatus:isPaymentPending?'receipt_pending':'paid',type:r.receipt_type==='80g'?'80G':'Normal',pan:r.donor_pan_snapshot||'',areaName:r.area_name_snapshot||selected.route||'',collector:r.collected_by_name_snapshot,chequeNo:r.cheque_number_snapshot||'',bankName:r.bank_name_snapshot||'',googleDriveUrl:'',googleDriveFileId:''}
   setViewReceipt(issuedReceipt);setModal('receipt')
   if(sendAfterSave){
    const uploaded=await uploadReceiptToDrive(issuedReceipt)
    const url=uploaded.googleDriveUrl?whatsappUrl(uploaded):whatsappUrl(issuedReceipt)
    if(whatsappWindow&&!whatsappWindow.closed)whatsappWindow.location.href=url;else window.location.href=url
   }else{
    uploadReceiptToDrive(issuedReceipt,true)
   }
  }
 }
 async function settlePendingReceipt(receipt:Receipt){
  setSettleReceipt(receipt)
  setSettleForm({mode:'Cash',date:new Date().toISOString().slice(0,10),chequeNo:'',bankName:''})
  setModal('settlePayment')
 }
 async function confirmSettlePendingReceipt(){
  if(!supabase||!settleReceipt)return
  if(!settleForm.date)return alert('Select payment received date.')
  if(settleForm.mode==='Cheque'&&!settleForm.chequeNo.trim())return alert('Cheque Number is required.')
  const {error}=await supabase.rpc('settle_pending_payment',{p_payment_id:settleReceipt.paymentId,p_mode:settleForm.mode.toLowerCase(),p_cheque_no:settleForm.chequeNo.trim()||null,p_bank_name:settleForm.bankName.trim()||null,p_payment_date:settleForm.date})
  if(error)return alert(error.message)
  setModal(null);setSettleReceipt(null);await loadAll();alert('Payment status updated successfully.')
 }
 async function loadDriveStatus(){
  if(!supabase||!session)return
  try{
   const {data:{session:sess}}=await supabase.auth.getSession();if(!sess)return
   const r=await fetch('/api/google/status',{headers:{authorization:`Bearer ${sess.access_token}`}})
   const j=await r.json();if(r.ok)setDriveConnected(!!j.connected)
  }catch{}
 }
 async function connectGoogleDrive(){
  if(!supabase||!isAdmin)return
  setDriveBusy(true)
  try{
   const {data:{session:sess}}=await supabase.auth.getSession();if(!sess)return
   const r=await fetch('/api/google/connect',{method:'POST',headers:{authorization:`Bearer ${sess.access_token}`}})
   const j=await r.json();if(!r.ok)throw new Error(j.error||'Could not start Google Drive connection.')
   window.location.href=j.url
  }catch(e:any){alert(e?.message||'Could not connect Google Drive.')}finally{setDriveBusy(false)}
 }
 async function createReceiptPdf(receipt:Receipt):Promise<File|null>{
  const imageFile=await createReceiptImage(receipt);if(!imageFile)return null
  const dataUrl=await new Promise<string>((resolve,reject)=>{const fr=new FileReader();fr.onload=()=>resolve(String(fr.result||''));fr.onerror=()=>reject(fr.error);fr.readAsDataURL(imageFile)})
  const {jsPDF}=await import('jspdf')
  const pdf=new jsPDF({orientation:'landscape',unit:'px',format:[1536,1024],hotfixes:['px_scaling']})
  pdf.addImage(dataUrl,'PNG',0,0,1536,1024,undefined,'FAST')
  const blob=pdf.output('blob')
  const safeName=receipt.donorName.replace(/[^A-Za-z0-9_-]+/g,'-').replace(/^-+|-+$/g,'')
  return new File([blob],`RYM-Receipt-${receipt.receiptNo}-${safeName||'Donor'}.pdf`,{type:'application/pdf'})
 }
 async function uploadReceiptToDrive(receipt:Receipt,quiet=false):Promise<Receipt>{
  if(receipt.googleDriveUrl)return receipt
  if(!supabase)return receipt
  try{
   const {data:{session:sess}}=await supabase.auth.getSession();if(!sess)throw new Error('Please log in again.')
   const pdf=await createReceiptPdf(receipt);if(!pdf)throw new Error('Could not prepare receipt PDF.')
   const formData=new FormData();formData.append('receiptId',receipt.id);formData.append('filename',pdf.name);formData.append('file',pdf)
   const r=await fetch('/api/google/upload-receipt',{method:'POST',headers:{authorization:`Bearer ${sess.access_token}`},body:formData})
   const j=await r.json();if(!r.ok)throw new Error(j.error||'Google Drive upload failed.')
   const updated={...receipt,googleDriveUrl:String(j.url||''),googleDriveFileId:String(j.fileId||'')}
   setReceipts(rows=>rows.map(x=>x.id===receipt.id?updated:x));setViewReceipt(v=>v?.id===receipt.id?updated:v)
   return updated
  }catch(e:any){if(!quiet)alert(e?.message||'Could not upload receipt to Google Drive.');return receipt}
 }

 async function bulkUploadExistingReceipts(){
  if(!supabase||!isAdmin)return
  if(!driveConnected)return alert('Connect Google Drive first.')
  if(bulkDriveUpload.running)return
  const already=receipts.filter(r=>!!r.googleDriveUrl).length
  const pending=receipts.filter(r=>!r.googleDriveUrl)
  if(!pending.length)return alert(`All ${receipts.length} receipt(s) are already available in Google Drive.`)
  if(!window.confirm(`Upload ${pending.length} existing receipt PDF(s) to Google Drive?\n\n${already} receipt(s) already uploaded will be skipped.\n\nKeep this page open until the process completes.`))return

  let uploaded=0,failed=0
  setBulkDriveUpload({running:true,total:pending.length,done:0,uploaded:0,skipped:already,failed:0,current:''})
  for(let i=0;i<pending.length;i++){
   const receipt=pending[i]
   setBulkDriveUpload(v=>({...v,current:`Receipt ${receipt.receiptNo} — ${receipt.donorName}`,done:i}))
   try{
    const result=await uploadReceiptToDrive(receipt,true)
    if(result.googleDriveUrl)uploaded++;else failed++
   }catch{failed++}
   setBulkDriveUpload(v=>({...v,done:i+1,uploaded,failed}))
   // Small pause keeps long browser jobs responsive and avoids burst uploads.
   await new Promise(resolve=>setTimeout(resolve,120))
  }
  setBulkDriveUpload(v=>({...v,running:false,current:'Completed',done:pending.length,uploaded,failed}))
  await loadAll()
  alert(`Google Drive receipt upload completed.\n\nUploaded: ${uploaded}\nAlready uploaded / skipped: ${already}\nFailed: ${failed}${failed?'\n\nYou can run the upload again to retry failed receipts.':''}`)
 }

 function currentDonorForReceipt(receipt:Receipt){
  return donors.find(d=>d.id===receipt.donorId)||null
 }
 function currentReceiptMobile(receipt:Receipt){
  return currentDonorForReceipt(receipt)?.mobile||receipt.mobile||''
 }
 function currentReceiptDonorName(receipt:Receipt){
  return currentDonorForReceipt(receipt)?.name||receipt.donorName
 }
 function whatsappUrl(receipt:Receipt){
  const mobile=String(currentReceiptMobile(receipt)).replace(/\D/g,'')
  const indian=mobile.length===10?`91${mobile}`:mobile.startsWith('0')&&mobile.length===11?`91${mobile.slice(1)}`:mobile
  const donorName=currentReceiptDonorName(receipt)
  const link=receipt.googleDriveUrl?`\n\nReceipt PDF: ${receipt.googleDriveUrl}`:''
  const msg=encodeURIComponent(`Namaskar ${donorName},\n\nThank you for your donation to Rajasthan Yuvak Mandal, Sangamner.\n\nReceipt No.: ${receipt.receiptNo}\nAmount: ₹${receipt.amount.toLocaleString('en-IN')}/-\nReceipt Date: ${receipt.date.split('-').reverse().join('/')}${link}\n\nधन्यवाद!\nRajasthan Yuvak Mandal, Sangamner`)
  return `https://wa.me/${indian}?text=${msg}`
 }
 async function shareReceipt(receipt:Receipt){
  const mobile=String(currentReceiptMobile(receipt)).replace(/\D/g,'')
  if(!mobile)return alert('Donor mobile number is not available for this donor.')
  const uploaded=await uploadReceiptToDrive(receipt)
  if(!uploaded.googleDriveUrl)return
  window.location.href=whatsappUrl(uploaded)
 }
 function donorWhatsappNumber(mobile:string){
  const digits=String(mobile||'').replace(/\D/g,'')
  return digits.length===10?`91${digits}`:digits.startsWith('0')&&digits.length===11?`91${digits.slice(1)}`:digits
 }
 async function sendDashboardReceipt(receipt:Receipt){
  const mobile=donorWhatsappNumber(currentReceiptMobile(receipt))
  if(!mobile)return alert('Donor mobile number is not available.')
  const uploaded=await uploadReceiptToDrive(receipt)
  if(!uploaded.googleDriveUrl)return
  window.location.href=whatsappUrl(uploaded)
 }
 function sendPaymentReminder(receipt:Receipt){
  const mobile=donorWhatsappNumber(currentReceiptMobile(receipt))
  if(!mobile)return alert('Donor mobile number is not available.')
  const qrLink=`${window.location.origin}/rym-payment-qr.jpeg`
  const donorName=currentReceiptDonorName(receipt)
  const msg=encodeURIComponent(`Namaskar ${donorName},\n\nThis is a gentle reminder from Rajasthan Yuvak Mandal, Sangamner.\n\nReceipt No.: ${receipt.receiptNo}\nAmount: ₹${receipt.amount.toLocaleString('en-IN')}/-\n\nThe receipt has already been issued, but the donation payment is still pending. Kindly make the payment at your convenience.\n\nPayment QR: ${qrLink}\n\nधन्यवाद!\nRajasthan Yuvak Mandal, Sangamner`)
  window.location.href=`https://wa.me/${mobile}?text=${msg}`
 }
 async function createReceiptImage(receipt:Receipt):Promise<File|null>{
  const img=new Image();img.crossOrigin='anonymous';img.src='/rym-receipt-template.jpeg';await new Promise((res,rej)=>{img.onload=()=>res(null);img.onerror=rej})
  const c=document.createElement('canvas');c.width=1536;c.height=1024;const ctx=c.getContext('2d');if(!ctx)return null;ctx.drawImage(img,0,0,c.width,c.height)
  const [dd='',mm='',yyyy='']=receipt.date.split('-');ctx.fillStyle='#111';ctx.textBaseline='middle'
  const fitText=(v:string,x:number,y:number,max:number,base=31,min=20,weight=700,align:'left'|'center'='left')=>{let size=base;ctx.textAlign=align;while(size>min){ctx.font=`${weight} ${size}px Arial, sans-serif`;if(ctx.measureText(v).width<=max)break;size--}ctx.fillText(v,x,y);ctx.textAlign='left'}
  // V1.6.9.9: receipt file is prepared/downloaded before opening the donor's exact WhatsApp chat. These coordinates mirror the final
  // calibrated on-screen receipt preview so View, Print/PDF and WhatsApp
  // all produce the same layout. Canvas size is exactly 1536 x 1024.
  const W=c.width,H=c.height
  const centerY=(topPct:number,heightPct:number)=>H*((topPct+heightPct/2)/100)

  // Receipt number: same position as .receiptCanvas .rvNo in globals.css.
  fitText(receipt.receiptNo,W*0.1335,centerY(34.15,4.2),W*0.215,34,22,700)

  // Date: reproduce the opaque preview overlay exactly so the pre-printed
  // slashes/year cannot show through in exported PNG/PDF/WhatsApp images.
  const dateX=W*0.821,dateY=H*0.342,dateW=W*0.154,dateH=H*0.056
  ctx.fillStyle='rgb(255,239,216)'
  ctx.fillRect(dateX-3,dateY-3,dateW+6,dateH+6)
  ctx.fillStyle='#111'
  fitText(`${dd} / ${mm} / ${yyyy}`,dateX+dateW/2,dateY+dateH/2,dateW-12,32,22,700,'center')

  // Donor name: mirrors .rvName (14.5% left / 39.2% top).
  fitText(receipt.donorName,W*0.145,centerY(39.2,4.8),W*0.78,36,22,700)
  fitText(receipt.mobile||'',275,505,430,33,22,700)
  fitText(receipt.pan||'',930,525,440,32,21,700)
  fitText(receipt.amountWords,250,587,925,32,20,700)

  // Numeric amount: center it inside the same white box used by .rvAmount.
  const amountX=W*0.108,amountY=H*0.69,amountW=W*0.23,amountH=H*0.072
  ctx.fillStyle='#fff';ctx.fillRect(amountX,amountY,amountW,amountH)
  ctx.fillStyle='#c91414'
  fitText(`₹ ${new Intl.NumberFormat('en-IN').format(receipt.amount)}/-`,amountX+amountW/2,amountY+amountH/2,amountW-16,46,30,700,'center')
  ctx.fillStyle='#111'

  if(receipt.mode.toLowerCase()==='cheque'){fitText(receipt.chequeNo||'',258,815,280,30,20,700);fitText(receipt.bankName||'',258,875,280,29,19,700)}
  fitText(receipt.collector,1280,845,320,30,19,700,'center')
  const blob=await new Promise<Blob|null>(resolve=>c.toBlob(resolve,'image/png',1));return blob?new File([blob],`RYM_VARGANI-${receipt.receiptNo.replace(/[^A-Za-z0-9_-]/g,'-')}.png`,{type:'image/png'}):null
 }
 async function printReceipt(receipt:Receipt){
  // Open synchronously from the click so mobile/desktop browsers do not block it.
  const win=window.open('','_blank','width=1200,height=850')
  if(!win)return alert('Please allow pop-ups for RYM_VARGANI to print the receipt.')
  win.document.write('<!doctype html><html><head><title>Preparing receipt...</title></head><body style="font-family:Arial,sans-serif;padding:24px">Preparing receipt...</body></html>')
  try{
   const file=preparedReceiptFile||await createReceiptImage(receipt);if(!file){win.close();return alert('Could not prepare receipt for printing.')}
   const url=URL.createObjectURL(file)
   win.document.open();win.document.write(`<!doctype html><html><head><title>Receipt ${receipt.receiptNo}</title><style>@page{size:landscape;margin:6mm}html,body{margin:0;padding:0;background:#fff}body{display:flex;align-items:flex-start;justify-content:center}img{display:block;width:100%;max-width:100%;height:auto;page-break-inside:avoid;break-inside:avoid;print-color-adjust:exact;-webkit-print-color-adjust:exact}@media print{html,body{width:100%;height:auto;overflow:visible}img{width:100%;height:auto}}</style></head><body><img id="r" src="${url}" alt="Receipt"></body></html>`);win.document.close()
   const ri=win.document.getElementById('r') as HTMLImageElement|null;if(ri)ri.onload=()=>{setTimeout(()=>{win.focus();win.print();setTimeout(()=>URL.revokeObjectURL(url),5000)},120)}
  }catch(e:any){win.close();alert(e?.message||'Unable to print receipt.')}
 }
 function resetForm(){setForm({name:'',contactPerson:'',mobile:'',reference:'',routeId:'',expected:'',lastYear:'',lastReceipt:'',amount:'',receiptNumber:'',collectionDate:new Date().toISOString().slice(0,10),mode:'Cash',pan:'',is80g:false,chequeNo:'',bankName:'',memberName:'',memberMobile:'',birthDate:'',newRoute:'',userName:'',userMobile:'',username:'',password:'',role:'Volunteer',userActive:true})}

 async function openEditReceipt(r:Receipt){
  setEditReceipt(r)
  setEditReceiptForm({receiptNo:r.receiptNo,donorName:r.donorName,mobile:r.mobile||'',pan:r.pan||'',date:r.date.split('-').reverse().join('-'),amount:String(r.amount),mode:r.paymentStatus==='receipt_pending'?'Receipt Given - Payment Pending':r.mode,chequeNo:r.chequeNo||'',bankName:r.bankName||'',areaName:r.areaName||'',is80g:r.type==='80G',reason:''})
  setModal('editReceipt')
 }
 async function saveReceiptEdit(){
  if(!supabase||!editReceipt)return
  const amount=parseMoney(editReceiptForm.amount);if(amount<=0)return alert('Enter a valid amount.')
  if(!editReceiptForm.receiptNo.trim())return alert('Receipt Number is required.')
  const duplicate=receipts.some(r=>r.id!==editReceipt.id&&r.receiptNo.trim().toLowerCase()===editReceiptForm.receiptNo.trim().toLowerCase())
  if(duplicate)return alert(`Receipt number already exists: ${editReceiptForm.receiptNo.trim()}`)
  if(!editReceiptForm.donorName.trim())return alert('Donor Name is required.')
  if(!editReceiptForm.date)return alert('Select receipt date.')
  if(editReceiptForm.mode==='Cheque'&&!editReceiptForm.chequeNo.trim())return alert('Cheque Number is compulsory for cheque payment.')
  const {error}=await supabase.rpc('edit_receipt_with_audit',{p_receipt_id:editReceipt.id,p_receipt_number:editReceiptForm.receiptNo.trim(),p_donor_name:editReceiptForm.donorName.trim(),p_mobile:editReceiptForm.mobile.trim()||null,p_pan:editReceiptForm.pan.trim().toUpperCase()||null,p_amount:amount,p_payment_date:editReceiptForm.date,p_mode:editReceiptForm.mode,p_cheque_no:editReceiptForm.chequeNo.trim()||null,p_bank_name:editReceiptForm.bankName.trim()||null,p_area_name:editReceiptForm.areaName.trim()||null,p_is_80g:editReceiptForm.is80g,p_reason:editReceiptForm.reason.trim()||null})
  if(error)return alert(error.message)
  // Any edit changes the rendered receipt. Remove the old Drive copy so the
  // next View/WhatsApp action always generates and uploads the corrected PDF.
  if(editReceipt.googleDriveFileId&&session){
   try{await fetch('/api/google/delete-receipt',{method:'POST',headers:{'content-type':'application/json',authorization:`Bearer ${session.access_token}`},body:JSON.stringify({fileId:editReceipt.googleDriveFileId})})}catch{}
  }
  setModal(null);setEditReceipt(null);await loadAll();alert('Receipt updated. A fresh PDF will be generated before it is sent again.')
 }
 async function handleFile(file?:File,kind:'donors'|'members'='donors'){if(!file)return;const XLSX=await import('xlsx');const wb=XLSX.read(await file.arrayBuffer(),{type:'array',cellDates:true});const rows=XLSX.utils.sheet_to_json<Record<string,any>>(wb.Sheets[wb.SheetNames[0]],{defval:''});const valid:any[]=[],invalid:{row:number;reason:string}[]=[];rows.forEach((row,i)=>{if(kind==='donors'){const name=String(findVal(row,['Donor Name','Donar Name','Name'])).trim();if(!name)invalid.push({row:i+2,reason:'Donor Name is required'});else if(!englishName(name))invalid.push({row:i+2,reason:'Donor Name must be in English'});else valid.push({name,contactPerson:String(findVal(row,['Contact Person'])).trim(),mobile:String(findVal(row,['Mobile Number','Mobile'])).trim(),pan:String(findVal(row,['PAN Number','PAN','Pan Number'])).trim().toUpperCase(),reference:String(findVal(row,['Reference','Referred By'])).trim(),lastYear:parseMoney(findVal(row,['Last Year Donation'])),lastReceipt:String(findVal(row,['Last Year Donation Receipt Number','Last Year Receipt No','Last Year Receipt Number'])).trim(),route:String(findVal(row,['Route'])).trim()})}else{const name=String(findVal(row,['Name of Member','Member Name','Name'])).trim(),mobile=String(findVal(row,['Mobile Number','Mobile'])).trim();if(!name||!mobile)invalid.push({row:i+2,reason:'Name and Mobile Number are required'});else valid.push({name,mobile,birthDate:normalizeDate(findVal(row,['Birth Date','DOB']))})}});setPreview({kind,valid,invalid,fileName:file.name})}
 async function importRows(){
  if(!supabase||!preview||!isAdmin)return
  try{
   if(preview.kind==='donors'){
    const normalizeRouteKey=(value:any)=>String(value||'').trim().replace(/\s+/g,' ').toLocaleLowerCase('en-IN')

    // Always read the latest active routes from Supabase before importing.
    // This avoids stale browser state and lets us safely reuse routes that already exist.
    const {data:dbRoutes,error:routeLoadError}=await supabase
     .from('routes')
     .select('id,name')
     .eq('organization_id',orgId)
     .eq('active',true)
    if(routeLoadError)throw routeLoadError

    const routeMap=new Map<string,string>()
    for(const route of dbRoutes||[])routeMap.set(normalizeRouteKey(route.name),route.id)

    // Extract each route only once from the spreadsheet, normalize spaces/case,
    // and create only routes that are truly missing.
    const requestedRoutes=new Map<string,string>()
    for(const row of preview.valid){
     const cleanName=String(row.route||'').trim().replace(/\s+/g,' ')
     if(cleanName){
      const key=normalizeRouteKey(cleanName)
      if(!requestedRoutes.has(key))requestedRoutes.set(key,cleanName)
     }
    }

    let reusedRoutes=0,newRoutes=0
    for(const [key,routeName] of requestedRoutes){
     if(routeMap.has(key)){reusedRoutes++;continue}

     // Upsert against the database unique key. If another request created the route
     // between our SELECT and this call, Supabase returns/reuses the existing row.
     const {data,error}=await supabase
      .from('routes')
      .upsert({organization_id:orgId,name:routeName,active:true},{onConflict:'organization_id,name'})
      .select('id,name')
      .single()
     if(error)throw error
     routeMap.set(normalizeRouteKey(data.name),data.id)
     newRoutes++
    }

    // Insert donors in batches rather than one network request per donor.
    const donorRows=preview.valid.map(row=>{
     const cleanRoute=String(row.route||'').trim().replace(/\s+/g,' ')
     const routeId=cleanRoute?routeMap.get(normalizeRouteKey(cleanRoute))||null:null
     return {
      organization_id:orgId,
      name:String(row.name).trim(),
      contact_person:row.contactPerson||null,
      mobile:row.mobile||null,
      pan:row.pan||null,
      reference:row.reference||null,
      route_id:routeId,
      last_year_donation:row.lastYear,
      last_year_receipt_number:row.lastReceipt||null,
      current_expected_amount:row.lastYear
     }
    })

    const batchSize=200
    for(let i=0;i<donorRows.length;i+=batchSize){
     const {error}=await supabase.from('donors').insert(donorRows.slice(i,i+batchSize))
     if(error)throw error
    }

    setModal(null);setPreview(null);setEditingUser(null);setEditingDonor(null);await loadAll()
    alert(`Bulk upload completed.\n\nDonors imported: ${donorRows.length}\nExisting routes reused: ${reusedRoutes}\nNew routes created: ${newRoutes}`)
   }else{
    const rows=preview.valid.map(r=>({organization_id:orgId,name:r.name,mobile:r.mobile,birth_date:r.birthDate||null}))
    const {error}=await supabase.from('organization_people').upsert(rows,{onConflict:'organization_id,mobile'})
    if(error)throw error
    setModal(null);setPreview(null);setEditingUser(null);setEditingDonor(null);await loadAll()
    alert(`Members imported: ${rows.length}`)
   }
  }catch(e:any){alert(e.message)}
 }
 async function downloadTemplate(kind:'donors'|'members'){const XLSX=await import('xlsx');const data=kind==='donors'?[{'Donor Name':'ABC Traders','Contact Person':'Rajesh Jain','Mobile Number':'9876543210','PAN Number':'ABCDE1234F','Reference':'Sagar Maniyar','Last Year Donation':5100,'Last Year Donation Receipt Number':'RYM-25-001','Route':'Main Road'}]:[{'Name of Member':'Amit Bhandari','Mobile Number':'9822000101','Birth Date':'12-03-1988'}];const ws=XLSX.utils.json_to_sheet(data),wb=XLSX.utils.book_new();XLSX.utils.book_append_sheet(wb,ws,'Template');XLSX.writeFile(wb,kind==='donors'?'RYM_VARGANI-Donor-Template.xlsx':'RYM_VARGANI-Member-Template.xlsx')}

 const stats=useMemo(()=>{const expected=donors.reduce((s,d)=>s+d.expected,0),received=donors.reduce((s,d)=>s+d.received,0);return{expected,received,pending:Math.max(0,expected-received),count:donors.length,progress:expected?Math.min(100,Math.round(received/expected*100)):0}},[donors])
 const pendingReceiptByDonor=useMemo(()=>{const map=new Map<string,Receipt>();for(const r of receipts){if(r.paymentStatus==='receipt_pending'&&r.donorId&&!map.has(r.donorId))map.set(r.donorId,r)}return map},[receipts])
 const pendingDonorCount=useMemo(()=>donors.filter(d=>d.status!=='Collected'&&!pendingReceiptByDonor.has(d.id)).length,[donors,pendingReceiptByDonor])
 const receiptPaymentPendingAmount=useMemo(()=>receipts.filter(r=>r.paymentStatus==='receipt_pending').reduce((sum,r)=>sum+r.amount,0),[receipts])
 const shown=donors.filter(d=>(active!=='route'||((!selectedRoute||d.routeId===selectedRoute)&&d.status!=='Collected'&&!pendingReceiptByDonor.has(d.id)))&&(active!=='pending'||(d.status!=='Collected'&&(!pendingRoute||d.routeId===pendingRoute)))&&searchMatches(q,d.name,d.contactPerson,d.mobile,d.route,d.reference,d.pan,d.lastYearReceipt)).sort((a,b)=>active==='pending'?((a.route||'').localeCompare(b.route||'',undefined,{sensitivity:'base'})||(a.name||'').localeCompare(b.name||'',undefined,{sensitivity:'base'})):0)

 if(!supabase)return <div className="loginPage"><div className="loginCard"><h1>RYM_VARGANI</h1><p>Supabase is not configured. Copy <b>.env.example</b> to <b>.env.local</b> and add your Supabase keys.</p></div></div>
 if(loading)return <div className="loginPage"><div className="loginCard"><h1>RYM_VARGANI</h1><p>Loading live database…</p></div></div>
 if(!session||!profile)return <div className="loginPage"><div className="loginCard"><img className="brandLogo loginBrandLogo" src="/rym-logo.jpg" alt="Rajasthan Yuvak Mandal logo"/><h1>RYM_VARGANI</h1><p>Live Database Login</p><label className="field"><span>Login Name</span><input value={login.username} onChange={e=>setLogin({...login,username:e.target.value})}/></label><label className="field"><span>Password</span><input type="password" value={login.password} onChange={e=>setLogin({...login,password:e.target.value})} onKeyDown={e=>e.key==='Enter'&&doLogin()}/></label>{loginError&&<div className="alert">{loginError}</div>}<button className="primary full" onClick={doLogin}>Login</button></div></div>

 return <div className="shell"><aside><div className="logoBox"><img className="brandLogo" src="/rym-logo.jpg" alt="Rajasthan Yuvak Mandal logo"/><div><b>RYM_VARGANI</b><small>{orgName}</small></div></div><nav>{[['dashboard','⌂',L.dashboard],['route','⌖',L.routeCollection],['donors','♙',L.donors],['pending','◷',L.pending],['receipts','▤',L.receipts],['paymentPending','⌛',L.paymentPending],['80g','✦',L.eighty],['members','♚',L.members],['reports','▥',L.reports],['daywise','▦',L.daywise],...(isAdmin?[['admin','⚙',L.admin]]:[])].map((x:any)=><button key={x[0]} className={active===x[0]?'active':''} onClick={()=>setActive(x[0])}><span>{x[1]}</span>{x[2]}</button>)}</nav><div className="sideBottom"><small>Logged in as</small><b>{profile.name}</b><span>{profile.role}</span><button className="ghost" onClick={doLogout}>{L.logout}</button></div></aside>
 <main><header><div><h1>{active==='route'?L.routeCollection:active==='admin'?L.admin:L[active as keyof typeof L]||'RYM_VARGANI'}</h1><small>Live · {orgName}</small></div><div className="headerActions"><button className="langBtn" onClick={()=>setLang(lang==='en'?'mr':'en')}>{lang==='en'?'मराठी':'English'}</button><button className="mobileLogoutBtn" onClick={doLogout}>↪ {L.logout}</button></div></header>
 {active==='dashboard'&&<><section className="stats dashboardStats"><Stat label={L.expected} value={money(stats.expected)} icon="◎"/><Stat label={L.collected} value={money(stats.received)} icon="₹" accent/><Stat label={L.pendingAmt} value={money(stats.pending)} icon="◷" warn/><Stat label={L.donorsCount} value={String(stats.count)} icon="♙"/><Stat label={L.pendingDonors} value={String(pendingDonorCount)} icon="◷" warn/><Stat label="Receipt Given - Payment Pending" value={money(receiptPaymentPendingAmount)} icon="⌛" warn/></section><section className="card dashboardDonorSearch"><div className="tableHead"><div><b>Search Donor</b><small>Search by donor name</small></div><input className="search" placeholder="Type donor name..." value={dashboardQ} onChange={e=>{setDashboardQ(e.target.value);setDashboardDonor(null)}}/></div>{dashboardQ.trim()&&<div className="dashboardSearchResults">{donors.filter(d=>searchMatches(dashboardQ,d.name)).slice(0,12).map(d=>{const pr=pendingReceiptByDonor.get(d.id);const paid=receipts.filter(r=>r.donorId===d.id&&r.paymentStatus==='paid').sort((a,b)=>String(b.receiptNo).localeCompare(String(a.receiptNo),undefined,{numeric:true}))[0];const status=pr?'Receipt Given - Payment Pending':d.status==='Collected'?'Donation Collected':'Pending';return <button key={d.id} className={`dashboardDonorResult ${dashboardDonor?.id===d.id?'selected':''}`} onClick={()=>setDashboardDonor(d)}><b>{d.name}</b><span>{status}</span></button>})}{!donors.some(d=>searchMatches(dashboardQ,d.name))&&<div className="empty">No donor found.</div>}</div>}{dashboardDonor&&(()=>{const pr=pendingReceiptByDonor.get(dashboardDonor.id);const paid=receipts.filter(r=>r.donorId===dashboardDonor.id&&r.paymentStatus==='paid').sort((a,b)=>String(b.receiptNo).localeCompare(String(a.receiptNo),undefined,{numeric:true}))[0];return <div className="dashboardDonorActions"><div className="dashboardDonorIdentity"><b>{dashboardDonor.name}</b><small>{pr?`Receipt ${pr.receiptNo} · Payment Pending`:dashboardDonor.status==='Collected'?'Donation Collected':'Donation Pending'}</small></div><div className="dashboardLastYear"><small>{L.lastDonation}</small><b>{money(dashboardDonor.lastYear)}</b></div><div className="rowActions">{pr?<><button className="primary" onClick={()=>settlePendingReceipt(pr)}>Mark Payment</button><button className="smallBtn reminderBtn" onClick={()=>sendPaymentReminder(pr)}>WhatsApp Reminder</button></>:dashboardDonor.status==='Collected'&&paid?<button className="primary whatsappBtn" onClick={()=>sendDashboardReceipt(paid)}>Send Receipt</button>:<button className="primary" onClick={()=>openCollection(dashboardDonor)}>Collect</button>}</div></div>})()}</section><section className="card progressCard"><div><b>Collection Progress</b><strong>{stats.progress}%</strong></div><div className="progress"><span style={{width:`${stats.progress}%`}}/></div></section><DatewiseGraph receipts={receipts}/></>}
 {(active==='donors'||active==='pending'||active==='route')&&<section className="card donorCard donorListCard"><div className="tableHead"><div>{active==='route'&&<select className="routeSelect" value={selectedRoute} onChange={e=>setSelectedRoute(e.target.value)}><option value="">{L.allRoutes}</option>{routes.map(r=><option key={r.id} value={r.id}>{r.name}</option>)}</select>}{active==='pending'&&<select className="routeSelect" value={pendingRoute} onChange={e=>setPendingRoute(e.target.value)}><option value="">{L.allRoutes}</option>{routes.map(r=><option key={r.id} value={r.id}>{r.name}</option>)}</select>}<input className="search" placeholder={L.search} value={q} onChange={e=>setQ(e.target.value)}/></div><div className="actions">{isSuperAdmin&&selectedDonorIds.length>0&&<button className="ghost dangerBtn" onClick={bulkDeleteDonors}>🗑 {L.bulkDelete} ({selectedDonorIds.length})</button>}<button className="ghost" onClick={()=>{setEditingDonor(null);resetForm();setModal('donor')}}>+ {L.addDonor}</button>{isAdmin&&<button className="ghost" onClick={()=>{setPreview(null);setModal('importDonors')}}>⇧ {L.bulkDonors}</button>}</div></div><div className="tableWrap"><table><thead><tr>{isSuperAdmin&&<th className="selectCol"><input type="checkbox" checked={shown.length>0&&shown.every(d=>selectedDonorIds.includes(d.id))} onChange={e=>setSelectedDonorIds(e.target.checked?Array.from(new Set([...selectedDonorIds,...shown.map(d=>d.id)])):selectedDonorIds.filter(id=>!shown.some(d=>d.id===id)))}/></th>}<th>{L.name}</th><th>{L.pan}</th><th>{L.route}</th><th>{L.lastDonation}</th><th>{L.expected}</th><th>{L.collected}</th><th>{L.balance}</th><th>{L.status}</th><th></th></tr></thead><tbody>{shown.map(d=>{const pendingReceipt=pendingReceiptByDonor.get(d.id);return <tr key={d.id}>{isSuperAdmin&&<td className="selectCol"><input type="checkbox" checked={selectedDonorIds.includes(d.id)} onChange={e=>setSelectedDonorIds(ids=>e.target.checked?[...ids,d.id]:ids.filter(id=>id!==d.id))}/></td>}<td><b>{d.name}</b><small>{d.mobile}</small></td><td>{d.pan||'—'}</td><td><select className="inlineRouteSelect" value={d.routeId} onChange={e=>changeDonorRoute(d.id,e.target.value)} aria-label={`${L.changeRoute}: ${d.name}`}><option value="">—</option>{routes.map(r=><option key={r.id} value={r.id}>{r.name}</option>)}</select></td><td>{money(d.lastYear)}<small>{d.lastYearReceipt}</small></td><td>{money(d.expected)}</td><td>{money(d.received)}</td><td>{money(Math.max(0,d.expected-d.received))}</td><td>{pendingReceipt?<PaymentPendingStatus receiptNo={pendingReceipt.receiptNo}/>:<StatusPill status={d.status}/>}</td><td><div className="rowActions">{d.status==='Collected'?<button className="smallBtn collectedAction" disabled>{L.donationCollected}</button>:<button className="smallBtn" onClick={()=>openCollection(d)}>{L.collect}</button>}{isAdmin&&<button className="smallBtn" onClick={()=>openEditDonor(d)}>✎ {L.editDonor}</button>}{isAdmin&&<button className="smallBtn dangerBtn" onClick={()=>deleteDonor(d)}>{L.deleteDonor}</button>}</div></td></tr>})}</tbody></table>{!shown.length&&<div className="empty">No donors found.</div>}</div><div className="mobileDonorList">{shown.map(d=>{const pendingReceipt=pendingReceiptByDonor.get(d.id);return active==='route'?<article className="mobileDonorCard routeCollectionCompact" key={`m-${d.id}`}><div className="mobileDonorTop compactTop"><div><b>{d.name}</b><small>{d.mobile||'No mobile'}</small></div></div>{pendingReceipt&&<PaymentPendingStatus receiptNo={pendingReceipt.receiptNo} mobile/>}<div className="mobileRouteRow"><span>{L.route}</span><select className="inlineRouteSelect" value={d.routeId} onChange={e=>changeDonorRoute(d.id,e.target.value)}><option value="">—</option>{routes.map(r=><option key={r.id} value={r.id}>{r.name}</option>)}</select></div><div className="routeCompactLastYear"><span>{L.lastDonation}</span><b>{money(d.lastYear)}</b></div><div className="mobileDonorActions">{d.status==='Collected'?<button className="primary collectedAction" disabled>{L.donationCollected}</button>:<button className="primary" onClick={()=>openCollection(d)}>{L.collect}</button>}</div></article>:<article className="mobileDonorCard" key={`m-${d.id}`}><div className="mobileDonorTop"><div>{isSuperAdmin&&<input className="mobileSelect" type="checkbox" checked={selectedDonorIds.includes(d.id)} onChange={e=>setSelectedDonorIds(ids=>e.target.checked?[...ids,d.id]:ids.filter(id=>id!==d.id))}/>}<b>{d.name}</b><small>{d.mobile||'No mobile'}</small></div>{pendingReceipt?<PaymentPendingStatus receiptNo={pendingReceipt.receiptNo} mobile/>:<StatusPill status={d.status}/>}</div><div className="mobileRouteRow"><span>{L.route}</span><select className="inlineRouteSelect" value={d.routeId} onChange={e=>changeDonorRoute(d.id,e.target.value)}><option value="">—</option>{routes.map(r=><option key={r.id} value={r.id}>{r.name}</option>)}</select></div><div className="mobileDonorGrid"><div><span>{L.pan}</span><b>{d.pan||'—'}</b></div><div><span>{L.lastDonation}</span><b>{money(d.lastYear)}</b><small>{d.lastYearReceipt}</small></div><div><span>{L.expected}</span><b>{money(d.expected)}</b></div><div><span>{L.collected}</span><b>{money(d.received)}</b></div><div className="balanceCell"><span>{L.balance}</span><b>{money(Math.max(0,d.expected-d.received))}</b></div></div><div className="mobileDonorActions donorMobileActionGrid">{d.status==='Collected'?<button className="primary collectedAction" disabled>{L.donationCollected}</button>:<button className="primary" onClick={()=>openCollection(d)}>{L.collect}</button>}{isAdmin&&<button className="ghost editDonorBtn" onClick={()=>openEditDonor(d)}>✎ {L.editDonor}</button>}{isAdmin&&<button className="ghost dangerBtn" onClick={()=>deleteDonor(d)}>{L.deleteDonor}</button>}</div></article>})}{!shown.length&&<div className="empty">No donors found.</div>}</div></section>}
 {active==='receipts'&&<ReceiptCentre receipts={receipts} only80g={false} onView={r=>{setViewReceipt(r);setModal('receipt')}} onEdit={openEditReceipt}/>}{active==='80g'&&<ReceiptCentre receipts={receipts} only80g onView={r=>{setViewReceipt(r);setModal('receipt')}} onEdit={openEditReceipt}/>}
 {active==='members'&&<section className="card donorCard"><div className="tableHead"><b>{L.members}</b>{isAdmin&&<div className="actions"><button className="ghost" onClick={()=>{resetForm();setModal('member')}}>+ {L.addMember}</button><button className="ghost" onClick={()=>{setPreview(null);setModal('importMembers')}}>⇧ {L.bulkMembers}</button></div>}</div><div className="tableWrap"><table><thead><tr><th>Name</th><th>Mobile</th><th>{L.birthDate}</th></tr></thead><tbody>{members.map(m=><tr key={m.id}><td><b>{m.name}</b></td><td>{m.mobile}</td><td>{m.birthDate||'—'}</td></tr>)}</tbody></table></div></section>}
 {active==='reports'&&<Reports donors={donors} receipts={receipts} canDownload={canDownloadReports}/>} {active==='paymentPending'&&<PendingPayments receipts={receipts} onSettle={settlePendingReceipt}/>} {active==='daywise'&&<DaywiseReport receipts={receipts} date={dayReportDate} setDate={setDayReportDate}/>} 
 {active==='admin'&&isAdmin&&<><section className="card donorCard"><div className="tableHead"><b>{L.userManagement}</b><button className="primary" onClick={()=>{resetForm();setModal('user')}}>+ {L.addUser}</button></div><div className="tableWrap"><table><thead><tr><th>{L.loginName}</th><th>Name</th><th>Mobile</th><th>{L.role}</th><th>{L.active}</th>{isSuperAdmin&&<th>Action</th>}</tr></thead><tbody>{users.map(u=><tr key={u.userId}><td><b>{u.loginName}</b></td><td>{u.name}</td><td>{u.mobile||'—'}</td><td>{u.role}</td><td>{u.active?'Yes':'No'}</td>{isSuperAdmin&&<td><button className="smallBtn" onClick={()=>openEditUser(u)}>✎ {L.editUser}</button></td>}</tr>)}</tbody></table></div></section><section className="card driveIntegrationCard">
 <div className="tableHead">
  <div><b>Google Drive Receipts</b><small>{driveConnected?'Connected — receipt PDFs can be uploaded automatically.':'Not connected — connect the Mandal Google Drive account.'}</small></div>
  <div className="rowActions">
   <button className={driveConnected?'smallBtn':'primary'} disabled={driveBusy||bulkDriveUpload.running} onClick={connectGoogleDrive}>{driveBusy?'Connecting...':driveConnected?'Reconnect Google Drive':'Connect Google Drive'}</button>
   {driveConnected&&<button className="primary" disabled={bulkDriveUpload.running||!receipts.length} onClick={bulkUploadExistingReceipts}>{bulkDriveUpload.running?'Uploading Existing Receipts…':'Upload All Existing Receipts'}</button>}
  </div>
 </div>
 {driveConnected&&<div className="driveSummary">
  <span><b>{receipts.filter(r=>!!r.googleDriveUrl).length}</b> in Drive</span>
  <span><b>{receipts.filter(r=>!r.googleDriveUrl).length}</b> waiting</span>
  <span><b>{receipts.length}</b> total receipts</span>
 </div>}
 {bulkDriveUpload.running&&<div className="driveBulkProgress">
  <div className="driveProgressHead"><b>{bulkDriveUpload.done} / {bulkDriveUpload.total}</b><span>{bulkDriveUpload.current}</span></div>
  <div className="driveProgressTrack"><span style={{width:`${bulkDriveUpload.total?Math.round(bulkDriveUpload.done/bulkDriveUpload.total*100):0}%`}}/></div>
  <small>Uploaded: {bulkDriveUpload.uploaded} · Failed: {bulkDriveUpload.failed} · Previously uploaded: {bulkDriveUpload.skipped}</small>
 </div>}
 {!bulkDriveUpload.running&&bulkDriveUpload.total>0&&<div className="driveBulkResult"><small>Last run — Uploaded: <b>{bulkDriveUpload.uploaded}</b> · Failed: <b>{bulkDriveUpload.failed}</b> · Skipped/already in Drive: <b>{bulkDriveUpload.skipped}</b></small></div>}
</section><section className="card"><div className="tableHead"><b>Routes</b><button className="ghost" onClick={()=>{resetForm();setModal('route')}}>+ {L.addRoute}</button></div><div className="routeManager">{routes.map(r=>{const count=donors.filter(d=>d.routeId===r.id).length;return <div className="routeManageRow" key={r.id}><div><b>{r.name}</b><small>{count} {lang==='mr'?'देणगीदार':'donors'}</small></div><div className="rowActions"><button className="smallBtn" onClick={()=>renameRoute(r)}>✎ {L.editRoute}</button><button className="smallBtn dangerBtn" onClick={()=>deleteRoute(r)} disabled={count>0} title={count>0?L.routeInUse:''}>🗑 {L.deleteRoute}</button></div></div>})}</div></section><section className="card auditCard"><div className="tableHead"><div><b>{L.receiptAudit}</b><small>{receiptAudits.length} recorded edit(s)</small></div></div><div className="tableWrap"><table><thead><tr><th>Receipt</th><th>Edited By</th><th>Date / Time</th><th>Changes</th><th>Reason</th></tr></thead><tbody>{receiptAudits.map(a=><tr key={a.id}><td><b>{a.receiptNo}</b></td><td>{a.editedBy}</td><td>{a.editedAt}</td><td><div className="auditChanges">{Object.entries(a.changes||{}).map(([field,v]:any)=><span key={field}><b>{field.replaceAll('_',' ')}</b>: {String(v?.from??'—')} → {String(v?.to??'—')}</span>)}</div></td><td>{a.reason||'—'}</td></tr>)}</tbody></table>{!receiptAudits.length&&<div className="empty">No receipt edits have been recorded.</div>}</div></section></>}
 </main>
 {modal&&<div className="overlay"><div className={`modal ${modal==='receipt'?'receiptModal':''} ${(modal==='importDonors'||modal==='importMembers')?'wideModal':''}`}><div className="modalHead"><div><small>RYM_VARGANI · Live Database</small><h3>{modal==='donor'?L.addDonor:modal==='editDonor'?L.editDonor:modal==='member'?L.addMember:modal==='collect'?`${L.collect} — ${selected?.name}`:modal==='receipt'?L.receipt:modal==='editReceipt'?L.editReceipt:modal==='settlePayment'?'Mark Payment Received':modal==='user'?L.addUser:modal==='editUser'?L.editUser:modal==='route'?L.addRoute:modal==='importDonors'?L.bulkDonors:L.bulkMembers}</h3></div><button onClick={()=>{setModal(null);setPreview(null);setEditingUser(null);setEditingDonor(null)}}>×</button></div>
 {(modal==='donor'||modal==='editDonor')&&<div className="formGrid"><Field label={`${L.name} *`}><input value={form.name} onChange={e=>setForm({...form,name:e.target.value})}/></Field><Field label={L.contact}><input value={form.contactPerson} onChange={e=>setForm({...form,contactPerson:e.target.value})}/></Field><Field label={L.mobile}><input value={form.mobile} onChange={e=>setForm({...form,mobile:e.target.value})}/></Field><Field label={`${L.pan} (${L.optional})`}><input value={form.pan} onChange={e=>setForm({...form,pan:e.target.value.toUpperCase()})} placeholder="ABCDE1234F"/></Field><Field label={`${L.reference} (${L.optional})`}><input value={form.reference} onChange={e=>setForm({...form,reference:e.target.value})} placeholder="Member / reference name"/></Field><Field label={L.route}><select value={form.routeId} onChange={e=>setForm({...form,routeId:e.target.value})}><option value="">—</option>{routes.map(r=><option key={r.id} value={r.id}>{r.name}</option>)}</select></Field><Field label="Current Expected Amount"><input type="number" value={form.expected} onChange={e=>setForm({...form,expected:e.target.value})}/></Field><Field label={L.lastDonation}><input type="number" value={form.lastYear} onChange={e=>setForm({...form,lastYear:e.target.value})}/></Field><Field label={L.lastReceipt}><input value={form.lastReceipt} onChange={e=>setForm({...form,lastReceipt:e.target.value})}/></Field></div>}
 {modal==='member'&&<div className="formGrid"><Field label="Name *"><input value={form.memberName} onChange={e=>setForm({...form,memberName:e.target.value})}/></Field><Field label="Mobile Number *"><input value={form.memberMobile} onChange={e=>setForm({...form,memberMobile:e.target.value})}/></Field><Field label={L.birthDate}><input type="date" value={form.birthDate} onChange={e=>setForm({...form,birthDate:e.target.value})}/></Field></div>}
 {modal==='collect'&&selected&&<div className="formGrid"><Field label={L.name}><input value={selected.name} disabled/></Field><label className="field"><span className="fieldLabelRow"><span>{L.route}</span><button type="button" className="routeEditBtn" onClick={()=>setCollectRouteEdit(v=>!v)}>✎ {L.editCollectionRoute}</button></span>{collectRouteEdit?<select value={selected.routeId} onChange={e=>changeSelectedDonorRoute(e.target.value)}><option value="">—</option>{routes.map(r=><option key={r.id} value={r.id}>{r.name}</option>)}</select>:<input value={selected.route||'—'} disabled/>}</label><Field label={`${L.amount} *`}><input type="number" value={form.amount} onChange={e=>setForm({...form,amount:e.target.value})}/></Field><Field label={`${L.collectionDate} *`}><input type="date" value={form.collectionDate} onChange={e=>setForm({...form,collectionDate:e.target.value})}/></Field><Field label={`${L.manualReceipt} (${L.optional})`}><input value={form.receiptNumber} onChange={e=>setForm({...form,receiptNumber:e.target.value})} placeholder={L.manualReceiptHelp}/></Field><Field label={L.paymentMode}><select value={form.mode} onChange={e=>setForm({...form,mode:e.target.value})}><option>Cash</option><option>UPI</option><option>Bank</option><option>Cheque</option><option>Receipt Given - Payment Pending</option></select></Field><Field label={L.pan}><input value={form.pan} onChange={e=>setForm({...form,pan:e.target.value.toUpperCase()})}/></Field><Field label="रक्कम स्वीकारणार"><input value={profile.name} disabled/></Field>{form.mode==='Cheque'&&<><Field label="Cheque Number *"><input value={form.chequeNo} onChange={e=>setForm({...form,chequeNo:e.target.value})}/></Field><Field label="Bank Name"><input value={form.bankName} onChange={e=>setForm({...form,bankName:e.target.value})}/></Field></>}<label className="check"><input type="checkbox" checked={form.is80g} onChange={e=>setForm({...form,is80g:e.target.checked})}/><span>80G Receipt</span></label></div>}
 {modal==='user'&&<div className="formGrid"><Field label="Full Name *"><input value={form.userName} onChange={e=>setForm({...form,userName:e.target.value})}/></Field><Field label="Mobile"><input value={form.userMobile} onChange={e=>setForm({...form,userMobile:e.target.value})}/></Field><Field label={`${L.loginName} *`}><input value={form.username} onChange={e=>setForm({...form,username:e.target.value})}/></Field><Field label={`${L.password} *`}><input type="password" value={form.password} onChange={e=>setForm({...form,password:e.target.value})}/></Field><Field label={L.role}><select value={form.role} onChange={e=>setForm({...form,role:e.target.value as Role})}>{(isSuperAdmin?(['Super Admin','Admin','Treasurer','Volunteer','Viewer'] as Role[]):(['Treasurer','Volunteer','Viewer'] as Role[])).map(r=><option key={r}>{r}</option>)}</select></Field></div>}
 {modal==='editUser'&&editingUser&&<div className="formGrid"><Field label="Full Name *"><input value={form.userName} onChange={e=>setForm({...form,userName:e.target.value})}/></Field><Field label="Mobile"><input value={form.userMobile} onChange={e=>setForm({...form,userMobile:e.target.value})}/></Field><Field label={L.loginName}><input value={editingUser.loginName} disabled/></Field><Field label={`${L.password} (${L.optional} — reset password)`}><input type="password" value={form.password} onChange={e=>setForm({...form,password:e.target.value})} placeholder="Leave blank to keep current password"/></Field><Field label={L.role}><select value={form.role} onChange={e=>setForm({...form,role:e.target.value as Role})}>{(['Super Admin','Admin','Treasurer','Volunteer','Viewer'] as Role[]).map(r=><option key={r}>{r}</option>)}</select></Field><label className="check"><input type="checkbox" checked={form.userActive} onChange={e=>setForm({...form,userActive:e.target.checked})}/><span>{L.active}</span></label></div>}
 {modal==='route'&&<div className="formGrid"><Field label="Route Name *"><input value={form.newRoute} onChange={e=>setForm({...form,newRoute:e.target.value})}/></Field></div>}
 {(modal==='importDonors'||modal==='importMembers')&&<div className="importBody"><div className="importInfo"><b>{modal==='importDonors'?'Donor Name* · Contact Person · Mobile Number · PAN Number (Optional) · Reference (Optional) · Last Year Donation · Last Year Receipt Number · Route':'Name of Member* · Mobile Number* · Birth Date'}</b><button className="ghost compact" onClick={()=>downloadTemplate(modal==='importDonors'?'donors':'members')}>↓ {L.downloadTemplate}</button></div><label className="dropzone"><span>⇧</span><b>{L.upload}</b><small>.xlsx, .xls, .csv</small><input ref={fileRef} type="file" accept=".xlsx,.xls,.csv" onChange={e=>handleFile(e.target.files?.[0],modal==='importDonors'?'donors':'members')}/></label>{preview&&<><div className="importSummary"><div><small>Valid rows</small><b>{preview.valid.length}</b></div><div className={preview.invalid.length?'hasErrors':''}><small>Invalid rows</small><b>{preview.invalid.length}</b></div><span>{preview.fileName}</span></div>{preview.invalid.length>0&&<div className="errorList">{preview.invalid.slice(0,10).map((x,i)=><span key={i}>Row {x.row}: {x.reason}</span>)}</div>}</>}</div>}
 {modal==='editReceipt'&&editReceipt&&<div className="formGrid receiptEditGrid"><Field label="Receipt Number *"><input value={editReceiptForm.receiptNo} onChange={e=>setEditReceiptForm({...editReceiptForm,receiptNo:e.target.value})}/></Field><Field label="Donor Name *"><input value={editReceiptForm.donorName} onChange={e=>setEditReceiptForm({...editReceiptForm,donorName:e.target.value})}/></Field><Field label="Mobile Number"><input value={editReceiptForm.mobile} onChange={e=>setEditReceiptForm({...editReceiptForm,mobile:e.target.value})}/></Field><Field label="PAN"><input value={editReceiptForm.pan} onChange={e=>setEditReceiptForm({...editReceiptForm,pan:e.target.value.toUpperCase()})}/></Field><Field label="Collection Date *"><input type="date" value={editReceiptForm.date} onChange={e=>setEditReceiptForm({...editReceiptForm,date:e.target.value})}/></Field><Field label="Amount *"><input type="number" value={editReceiptForm.amount} onChange={e=>setEditReceiptForm({...editReceiptForm,amount:e.target.value})}/></Field><Field label="Payment Mode"><select value={editReceiptForm.mode} onChange={e=>setEditReceiptForm({...editReceiptForm,mode:e.target.value})}><option>Cash</option><option>UPI</option><option>Bank</option><option>Cheque</option><option>Receipt Given - Payment Pending</option></select></Field><Field label="Area / Route on Receipt"><input value={editReceiptForm.areaName} onChange={e=>setEditReceiptForm({...editReceiptForm,areaName:e.target.value})}/></Field>{editReceiptForm.mode==='Cheque'&&<><Field label="Cheque Number *"><input value={editReceiptForm.chequeNo} onChange={e=>setEditReceiptForm({...editReceiptForm,chequeNo:e.target.value})}/></Field><Field label="Bank Name"><input value={editReceiptForm.bankName} onChange={e=>setEditReceiptForm({...editReceiptForm,bankName:e.target.value})}/></Field></>}<label className="check"><input type="checkbox" checked={editReceiptForm.is80g} onChange={e=>setEditReceiptForm({...editReceiptForm,is80g:e.target.checked})}/><span>80G Receipt</span></label><Field label={`${L.editReason} (${L.optional})`}><input value={editReceiptForm.reason} onChange={e=>setEditReceiptForm({...editReceiptForm,reason:e.target.value})} placeholder="Correction / reason for change"/></Field><div className="editAuditNotice">This edit will be recorded in the Admin audit log. Nothing about the edit will be printed on the donor receipt.</div></div>}
 {modal==='settlePayment'&&settleReceipt&&<div className="formGrid"><Field label="Receipt Number"><input value={settleReceipt.receiptNo} disabled/></Field><Field label="Donor"><input value={settleReceipt.donorName} disabled/></Field><Field label="Amount"><input value={money(settleReceipt.amount)} disabled/></Field><Field label="Payment Mode *"><select value={settleForm.mode} onChange={e=>setSettleForm({...settleForm,mode:e.target.value})}><option>Cash</option><option>UPI</option><option>Bank</option><option>Cheque</option></select></Field><Field label="Payment Received Date *"><input type="date" value={settleForm.date} onChange={e=>setSettleForm({...settleForm,date:e.target.value})}/></Field>{settleForm.mode==='Cheque'&&<><Field label="Cheque Number *"><input value={settleForm.chequeNo} onChange={e=>setSettleForm({...settleForm,chequeNo:e.target.value})}/></Field><Field label="Bank Name"><input value={settleForm.bankName} onChange={e=>setSettleForm({...settleForm,bankName:e.target.value})}/></Field></>}</div>}
 {modal==='receipt'&&viewReceipt&&<div className="receiptBody"><ReceiptDesign receipt={viewReceipt}/></div>}
 <div className="modalFoot noPrint"><button className="ghost" onClick={()=>{setModal(null);setPreview(null);setEditingUser(null);setEditingDonor(null)}}>{L.cancel}</button>{modal==='receipt'?<><button className="ghost whatsappBtn" onClick={()=>viewReceipt&&shareReceipt(viewReceipt)}>WhatsApp Donor</button><button className="primary" onClick={()=>viewReceipt&&printReceipt(viewReceipt)}>🖨 Print / Save PDF</button></>:modal==='editReceipt'?<button className="primary" onClick={saveReceiptEdit}>{L.saveReceiptChanges}</button>:modal==='settlePayment'?<button className="primary" onClick={confirmSettlePendingReceipt}>Mark Payment Received</button>:modal==='editDonor'?<button className="primary" onClick={updateDonor}>{L.updateDonor}</button>:(modal==='importDonors'||modal==='importMembers')?<button className="primary" disabled={!preview?.valid.length} onClick={importRows}>{L.import} {preview?.valid.length?`(${preview.valid.length})`:''}</button>:modal==='collect'?<button className="primary saveSendBtn" onClick={()=>collect(true)}>💬 {L.saveAndSend}</button>:<button className="primary" onClick={modal==='donor'?addDonor:modal==='member'?addMember:modal==='user'?addUser:modal==='editUser'?updateUser:addRoute}>{L.save}</button>}</div></div></div>}
 </div>
}

function Stat({label,value,icon,accent,warn}:{label:string,value:string,icon:string,accent?:boolean,warn?:boolean}){return <div className={`stat ${accent?'accent':''} ${warn?'warn':''}`}><div className="statIcon">{icon}</div><div><small>{label}</small><strong>{value}</strong></div></div>}
function StatusPill({status}:{status:Donor['status']}){return <span className={`pill ${status.toLowerCase()}`}>{status}</span>}
function PaymentPendingStatus({receiptNo,mobile=false}:{receiptNo:string,mobile?:boolean}){return <div className={`paymentPendingStatus ${mobile?'mobilePendingStatus':''}`}><span className="paymentPendingBadge">Payment Pending</span><small>Receipt No. <b>{receiptNo}</b></small></div>}
function Field({label,children}:{label:string,children:React.ReactNode}){return <label className="field"><span>{label}</span>{children}</label>}
function ReceiptCentre({receipts,only80g,onView,onEdit}:{receipts:Receipt[],only80g:boolean,onView:(r:Receipt)=>void,onEdit:(r:Receipt)=>void}){
 const [receiptSearch,setReceiptSearch]=useState('')
 const query=receiptSearch.trim()
 const rows=receipts
  .filter(r=>only80g?r.type==='80G':true)
  .filter(r=>searchMatches(query,r.receiptNo,r.donorName,r.mobile,r.date,r.date.replaceAll('-','/'),r.mode,r.collector,r.pan,r.areaName,r.type,r.amount))
  .slice()
  .sort((a,b)=>String(b.receiptNo||'').localeCompare(String(a.receiptNo||''),undefined,{numeric:true,sensitivity:'base'}))
 return <section className="card donorCard"><div className="tableHead receiptTableHead"><div><b>{only80g?'80G Receipts':'Receipt Centre'}</b><small>{rows.length} receipt(s) · {money(rows.reduce((sum,r)=>sum+r.amount,0))} · Receipt No. high to low</small></div><div className="receiptSearchWrap"><input type="search" autoComplete="off" className="search receiptSearch" placeholder="Search receipt no., donor, mobile, date, mode..." value={receiptSearch} onChange={e=>setReceiptSearch(e.target.value)}/>{receiptSearch&&<button type="button" className="smallBtn receiptSearchClear" onClick={()=>setReceiptSearch('')}>Clear</button>}</div></div><div className="tableWrap"><table><thead><tr><th>Receipt No.</th><th>Donor</th><th>Date</th><th>Type</th><th>Mode</th><th>Collector</th><th>Amount</th><th></th></tr></thead><tbody>{rows.map(r=><tr key={r.id}><td><b>{r.receiptNo}</b></td><td>{r.donorName}<small>{r.mobile}</small></td><td>{r.date}</td><td>{r.type}</td><td>{r.mode}</td><td>{r.collector}</td><td><b>{money(r.amount)}</b></td><td><div className="rowActions"><button className="smallBtn" onClick={()=>onView(r)}>View / Print</button><button className="smallBtn" onClick={()=>onEdit(r)}>✎ Edit Receipt</button></div></td></tr>)}</tbody></table>{!rows.length&&<div className="empty">{query?'No matching receipts.':'No receipts yet.'}</div>}</div></section>}
function ReceiptDesign({receipt}:{receipt:Receipt}){const [dd='',mm='',yyyy='']=receipt.date.split('-');return <div className="receiptPrintArea"><div className="receiptCanvas"><img src="/rym-receipt-template.jpeg" alt="Donation receipt"/><div className="rv rvNo">{receipt.receiptNo}</div><div className="rv rvDate">{dd} / {mm} / {yyyy}</div><div className="rv rvName">{receipt.donorName}</div>{receipt.mobile&&<div className="rv rvMobile">{receipt.mobile}</div>}{receipt.pan&&<div className="rv rvPan">{receipt.pan}</div>}<div className="rv rvWords">{receipt.amountWords}</div><div className="rv rvAmount">₹ {new Intl.NumberFormat('en-IN').format(receipt.amount)}/-</div>{receipt.mode.toLowerCase()==='cheque'&&<><div className="rv rvCheque">{receipt.chequeNo}</div>{receipt.bankName&&<div className="rv rvBank">{receipt.bankName}</div>}</>}<div className="rv rvCollector">{receipt.collector}</div></div></div>}

function DatewiseGraph({receipts}:{receipts:Receipt[]}){
 const paid=receipts.filter(r=>r.paymentStatus==='paid'&&r.paymentReceivedDate);const by=new Map<string,number>();for(const r of paid)by.set(r.paymentReceivedDate,(by.get(r.paymentReceivedDate)||0)+r.amount)
 const rows=Array.from(by.entries()).sort((a,b)=>{const pa=a[0].split('-').reverse().join('-'),pb=b[0].split('-').reverse().join('-');return pa.localeCompare(pb)}).slice(-14);const max=Math.max(1,...rows.map(x=>x[1]))
 return <section className="card dateGraph"><div className="tableHead"><div><b>Date-wise Collection</b><small>Paid collection by actual payment received date</small></div></div><div className="graphBars">{rows.length?rows.map(([date,amount])=><div className="graphCol" key={date}><div className="barValue">{money(amount)}</div><div className="barTrack"><span style={{height:`${Math.max(5,Math.round(amount/max*100))}%`}}/></div><small>{date.slice(0,5)}</small></div>):<div className="empty">No collection data yet.</div>}</div></section>
}
function PendingPayments({receipts,onSettle}:{receipts:Receipt[],onSettle:(r:Receipt)=>void}){const rows=receipts.filter(r=>r.paymentStatus==='receipt_pending');return <section className="card donorCard"><div className="tableHead"><div><b>Receipt Given - Payment Pending</b><small>{rows.length} pending receipts · {money(rows.reduce((s,r)=>s+r.amount,0))}</small></div></div><div className="tableWrap"><table><thead><tr><th>Receipt No.</th><th>Donor</th><th>Date</th><th>Area</th><th>Amount</th><th></th></tr></thead><tbody>{rows.map(r=><tr key={r.id}><td><b>{r.receiptNo}</b></td><td>{r.donorName}<small>{r.mobile}</small></td><td>{r.date}</td><td>{r.areaName}</td><td><b>{money(r.amount)}</b></td><td><button className="smallBtn primary" onClick={()=>onSettle(r)}>Mark Payment Received</button></td></tr>)}</tbody></table>{!rows.length&&<div className="empty">No pending receipt payments.</div>}</div></section>}
function DaywiseReport({receipts,date,setDate}:{receipts:Receipt[],date:string,setDate:(v:string)=>void}){
 const [modeFilter,setModeFilter]=useState('All')
 const [reportView,setReportView]=useState<'summary'|'detailed'>('summary')
 const display=date.split('-').reverse().join('-')
 const paidRows=receipts.filter(r=>r.paymentStatus==='paid'&&r.paymentReceivedDate===display)
 const pendingRows=receipts.filter(r=>r.paymentStatus==='receipt_pending'&&r.date===display)
 const total=(mode:string)=>paidRows.filter(r=>r.mode.toLowerCase()===mode.toLowerCase()).reduce((sum,r)=>sum+r.amount,0)
 const cash=total('Cash'),upi=total('UPI'),cheque=total('Cheque'),pending=pendingRows.reduce((sum,r)=>sum+r.amount,0),dayTotal=cash+upi+cheque
 const allRows=[...paidRows,...pendingRows]
 const rows=modeFilter==='All'?allRows:modeFilter==='Receipt Given - Payment Pending'?pendingRows:paidRows.filter(r=>r.mode.toLowerCase()===modeFilter.toLowerCase())
 const displayMode=(r:Receipt)=>r.paymentStatus==='receipt_pending'?'Receipt Given - Payment Pending':r.mode
 return <>
  <section className="card dayFilter">
   <div><b>Day-wise Collection Report</b><small>Paid amounts use Payment Received Date; pending receipts use Receipt Date</small></div>
   <div className="dayFilterControls">
    <input type="date" value={date} onChange={e=>setDate(e.target.value)}/>
    <select value={modeFilter} onChange={e=>setModeFilter(e.target.value)}>
     <option>All</option><option>Cash</option><option>UPI</option><option>Bank</option><option>Cheque</option><option>Receipt Given - Payment Pending</option>
    </select>
   </div>
  </section>

  <section className="stats dayStats">
   <Stat label="Cash Collection" value={money(cash)} icon="₹"/>
   <Stat label="UPI Collection" value={money(upi)} icon="↗" accent/>
   <Stat label="Cheque Collection" value={money(cheque)} icon="▤"/>
   <Stat label="Receipt Issued - Payment Pending" value={money(pending)} icon="⌛" warn/>
   <Stat label="Total Day's Collection" value={money(dayTotal)} icon="Σ" accent/>
  </section>

  <section className="card dayActivityCard">
   <div className="tableHead dayActivityHead">
    <div><b>Activity on {display}</b><small>{modeFilter==='All'?'All payment modes':modeFilter} · {rows.length} record(s)</small></div>
    <div className="dayViewToggle" role="group" aria-label="Day-wise report view">
     <button type="button" className={reportView==='summary'?'active':''} onClick={()=>setReportView('summary')}>Summary</button>
     <button type="button" className={reportView==='detailed'?'active':''} onClick={()=>setReportView('detailed')}>Detailed View</button>
    </div>
   </div>

   {reportView==='summary'?<div className="daySummaryList">
    <div className="daySummaryHeader"><span>Donor Name</span><span>Mode of Payment</span><span>Amount</span></div>
    {rows.map(r=><div className="daySummaryRow" key={`summary-${r.id}`}>
     <span className="summaryDonor">{r.donorName}</span>
     <span className="summaryMode">{displayMode(r)}</span>
     <span className="summaryAmount"><b>{money(r.amount)}</b></span>
    </div>)}
    {!rows.length&&<div className="empty">No matching collection activity on this date.</div>}
   </div>:<div className="dayDetailedList">
    {rows.map(r=><article className="dayDetailedCard" key={`detail-${r.id}`}>
     <div className="detailTop"><div><small>Donor Name</small><b>{r.donorName}</b></div><strong>{money(r.amount)}</strong></div>
     <div className="detailGrid">
      <div><small>Receipt</small><b>{r.receiptNo}</b></div>
      <div><small>Mode of Payment</small><b>{displayMode(r)}</b></div>
      <div><small>Amount</small><b>{money(r.amount)}</b></div>
      <div><small>Receipt Date</small><b>{r.date}</b></div>
      <div><small>Payment Received Date</small><b>{r.paymentReceivedDate||'—'}</b></div>
      <div><small>Status</small><b>{r.paymentStatus==='receipt_pending'?'Payment Pending':'Paid'}</b></div>
     </div>
    </article>)}
    {!rows.length&&<div className="empty">No matching collection activity on this date.</div>}
   </div>}
  </section>
 </> }
function Reports({donors,receipts,canDownload}:{donors:Donor[],receipts:Receipt[],canDownload:boolean}){
 const [collectionExpanded,setCollectionExpanded]=useState(false)
 const total=receipts.filter(r=>r.paymentStatus==='paid').reduce((sum,r)=>sum+r.amount,0),pending=donors.reduce((sum,d)=>sum+Math.max(0,d.expected-d.received),0)
 const modes=['Cash','UPI','Bank','Cheque','Receipt Given - Payment Pending'].map(mode=>({mode,amount:mode==='Receipt Given - Payment Pending'?receipts.filter(r=>r.paymentStatus==='receipt_pending').reduce((sum,r)=>sum+r.amount,0):receipts.filter(r=>r.paymentStatus==='paid'&&r.mode.toLowerCase()===mode.toLowerCase()).reduce((sum,r)=>sum+r.amount,0)}))
 const routeNames=Array.from(new Set(donors.map(d=>d.route).filter(Boolean)))
 async function downloadExcel(){
  const XLSX=await import('xlsx')
  const rows=receipts.map((r,i)=>{
   const donor=donors.find(d=>d.id===r.donorId)
   return {
    'Sr No.':i+1,
    'DonarName':r.donorName,
    'ContactNumber':donor?.mobile||r.mobile||'',
    'PAN':r.pan||donor?.pan||'',
    'ReceiptNumber':r.receiptNo,
    'ReceiptDate':r.date,
    'CollectionDate':r.paymentReceivedDate||r.date,
    'AreaName':r.areaName||donor?.route||'',
    'ModeofPayment':r.paymentStatus==='receipt_pending'?'Receipt Given - Payment Pending':r.mode,
    'Amount':r.amount
   }
  })
  const ws=XLSX.utils.json_to_sheet(rows,{header:['Sr No.','DonarName','ContactNumber','PAN','ReceiptNumber','ReceiptDate','CollectionDate','AreaName','ModeofPayment','Amount']})
  ws['!cols']=[{wch:8},{wch:30},{wch:18},{wch:16},{wch:24},{wch:14},{wch:16},{wch:28},{wch:28},{wch:14}]
  const wb=XLSX.utils.book_new();XLSX.utils.book_append_sheet(wb,ws,'Collection Report')
  XLSX.writeFile(wb,`RYM_VARGANI-Collection-Report-${new Date().toISOString().slice(0,10)}.xlsx`)
 }
 return <><section className="stats"><Stat label="Receipted Collection" value={money(total)} icon="₹" accent/><Stat label="Receipts Issued" value={String(receipts.length)} icon="▤"/><Stat label="80G" value={money(receipts.filter(r=>r.type==='80G').reduce((sum,r)=>sum+r.amount,0))} icon="✦"/><Stat label="Pending" value={money(pending)} icon="◷" warn/></section>
 <section className="card reportDownloadCard expandableReportHead">
  <button type="button" className="reportExpandButton" onClick={()=>setCollectionExpanded(v=>!v)} aria-expanded={collectionExpanded}>
   <div><b>Donor Collection Report</b><small>{receipts.length} record(s) · {collectionExpanded?'Click to collapse':'Click to expand'}</small></div>
   <span className="expandChevron">{collectionExpanded?'▲':'▼'}</span>
  </button>
  {collectionExpanded&&<div className="expandedReportActions"><small>Sr No. · DonarName · ContactNumber · PAN · ReceiptNumber · ReceiptDate · CollectionDate · AreaName · ModeofPayment · Amount</small>{canDownload&&<button className="primary" onClick={downloadExcel}>↓ Download Collection Excel</button>}</div>}
 </section>
 {collectionExpanded&&<section className="card collectionReportCard"><div className="tableWrap"><table><thead><tr><th>Sr No.</th><th>Donor</th><th>Contact</th><th>PAN</th><th>Receipt No.</th><th>Receipt Date</th><th>Collection Date</th><th>Area</th><th>Mode</th><th>Amount</th></tr></thead><tbody>{receipts.map((r,i)=>{const donor=donors.find(d=>d.id===r.donorId);return <tr key={r.id}><td>{i+1}</td><td>{r.donorName}</td><td>{donor?.mobile||r.mobile}</td><td>{r.pan||donor?.pan||'—'}</td><td>{r.receiptNo}</td><td>{r.date}</td><td>{r.paymentReceivedDate||r.date}</td><td>{r.areaName||donor?.route}</td><td>{r.paymentStatus==='receipt_pending'?'Receipt Given - Payment Pending':r.mode}</td><td><b>{money(r.amount)}</b></td></tr>})}</tbody></table></div></section>}
 <section className="grid2"><div className="card"><b>Payment Mode Report</b><div className="reportRows">{modes.map(x=><div key={x.mode}><span>{x.mode}</span><b>{money(x.amount)}</b></div>)}</div></div><div className="card"><b>Route-wise Report</b><div className="reportRows">{routeNames.map(route=>{const ds=donors.filter(d=>d.route===route);return <div key={route}><span>{route}<small>{ds.length} donors · Pending {money(ds.reduce((sum,d)=>sum+Math.max(0,d.expected-d.received),0))}</small></span><b>{money(ds.reduce((sum,d)=>sum+d.received,0))}</b></div>})}</div></div></section></>
}

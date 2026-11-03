import {createClient} from 'npm:@supabase/supabase-js@2.118.0';
const origins=new Set(['https://foodbridge-share-hope.singh-01-nidhi11.chatgpt.site','http://terminal.local:4173','https://foodbridge-sharehope-next-gen-x2.vercel.app','https://foodbridge-sharehope.vercel.app']);
Deno.serve(async (req:Request)=>{
 const origin=req.headers.get('Origin')||'';
 const headers:Record<string,string>={'Content-Type':'application/json','Vary':'Origin','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS'};
 if(origins.has(origin))headers['Access-Control-Allow-Origin']=origin;
 const respond=(d:unknown,status=200)=>new Response(JSON.stringify(d),{status,headers});
 if(origin&&!origins.has(origin))return respond({error:'This website is not allowed to register FoodBridge users.'},403);
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(req.method!=='POST')return respond({error:'Use POST.'},405);
 if(Number(req.headers.get('Content-Length')||'0')>8192)return respond({error:'Request is too large.'},413);
 try{
  const body=await req.text();if(body.length>8192)return respond({error:'Request is too large.'},413);
  const d=JSON.parse(body);const email=String(d.email||'').trim().toLowerCase();const password=String(d.password||'');const name=String(d.name||'').trim();const organization=String(d.organization||'').trim();const city=String(d.city||'').trim();const role=String(d.role||'');
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||email.length>254||password.length<8||password.length>128||name.length<2||name.length>100||organization.length<2||organization.length>150||city.length<2||city.length>100||!['donor','ngo','volunteer'].includes(role))return respond({error:'Enter valid account details, a password of at least 8 characters, and a donor, NGO or volunteer role.'},400);
  const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
  const hash=async(v:string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(v)))).map(b=>b.toString(16).padStart(2,'0')).join('');
  const ip=req.headers.get('x-real-ip')||req.headers.get('cf-connecting-ip')||req.headers.get('x-forwarded-for')?.split(',')[0]?.trim()||'unavailable';
  for(const [k,limit] of [['ip:'+await hash(ip),15],['email:'+await hash(email),4]] as [string,number][]){const r=await admin.rpc('fb_signup_allowed',{p_key:k,p_limit:limit});if(r.error)return respond({error:'Registration is temporarily unavailable. Please retry shortly.'},503);if(!r.data)return respond({error:'Too many registration attempts. Please try again in 15 minutes.'},429)}
  const {data,error}=await admin.auth.admin.createUser({email,password,email_confirm:true,user_metadata:{fb_name:name,fb_org:organization,fb_city:city,fb_role:role}});
  if(error)return respond({error:error.message.includes('already')?'An account already uses this email. Please sign in.':error.message},400);
  const profile=await admin.from('fb_profiles').insert({id:data.user.id,name,organization,city,role});
  if(profile.error){await admin.auth.admin.deleteUser(data.user.id);return respond({error:'Could not create your FoodBridge profile. Please retry.'},500)}
  return respond({ok:true},201);
 }catch{return respond({error:'Could not complete registration. Please check the details and try again.'},400)}
});

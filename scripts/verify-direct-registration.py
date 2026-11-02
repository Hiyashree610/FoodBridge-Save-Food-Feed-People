import urllib.request,urllib.error,json,secrets,uuid
url='https://rzuhxzzlczqcbnagbmiz.supabase.co';key='sb_publishable_z1OOkFLyDaUK50EkEiHAuQ_8nHd8VLQ';anon='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ6dWh4enpsY3pxY2JuYWdibWl6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI4NTU3OTgsImV4cCI6MjEwODQzMTc5OH0.nB2r6b5XKEMFFtbCzAOCj4eJ_K21R3SZtRpR6RCI3LU'
def post(path,d,token=anon):
 req=urllib.request.Request(url+path,data=json.dumps(d).encode(),headers={'Content-Type':'application/json','apikey':key,'Authorization':'Bearer '+token,'Origin':'https://foodbridge-share-hope.singh-01-nidhi11.chatgpt.site'})
 try:
  with urllib.request.urlopen(req,timeout=35) as r:return r.status,json.load(r),r.headers
 except urllib.error.HTTPError as e:return e.code,json.load(e),e.headers
email='foodbridge-direct-'+uuid.uuid4().hex[:10]+'@example.com';password=secrets.token_urlsafe(22)
d={'email':email,'password':password,'name':'Direct registration QA','organization':'Disposable QA fixture','city':'Bengaluru','role':'ngo'}
code,data,h=post('/functions/v1/foodbridge-register',d);assert code==201,(code,data);assert h.get('Access-Control-Allow-Origin')=='https://foodbridge-share-hope.singh-01-nidhi11.chatgpt.site';print('PASS: registration succeeds without OTP or confirmation email',flush=True)
code,s,_=post('/auth/v1/token?grant_type=password',{'email':email,'password':password});assert code==200,(code,s);uid=s['user']['id'];assert s['user']['email_confirmed_at'];print('PASS: immediate email/password sign-in',flush=True)
req=urllib.request.Request(url+'/rest/v1/fb_profiles?id=eq.'+uid+'&select=*',headers={'apikey':key,'Authorization':'Bearer '+s['access_token']})
with urllib.request.urlopen(req,timeout=35) as r:profile=json.load(r)[0]
assert profile['role']=='ngo' and profile['name']=='Direct registration QA';print('PASS: shared database profile and NGO dashboard role created automatically',flush=True)
code,data,_=post('/functions/v1/foodbridge-register',{**d,'role':'admin'});assert code==400;print('PASS: public admin registration denied',flush=True)
code,data,_=post('/functions/v1/foodbridge-register',d);assert code==400;print('PASS: duplicate email does not overwrite account',flush=True)
print('CLEANUP_USER_ID='+uid,flush=True)

import urllib.request,urllib.error,json,sys,uuid,base64,datetime,time
print('Ready for test credentials on stdin.',flush=True)
password=sys.stdin.readline().strip()
base='https://rzuhxzzlczqcbnagbmiz.supabase.co';key='sb_publishable_z1OOkFLyDaUK50EkEiHAuQ_8nHd8VLQ'
def call(path,data=None,token=None,method=None,raw=None,headers=None,ok=True):
 h={'apikey':key,'Content-Type':'application/json'}
 if token:h['Authorization']='Bearer '+token
 if headers:h.update(headers)
 req=urllib.request.Request(base+path,data=raw if raw is not None else json.dumps(data).encode() if data is not None else None,headers=h,method=method)
 try:
  with urllib.request.urlopen(req,timeout=35) as r:
   b=r.read();return json.loads(b) if b and 'json' in r.headers.get('Content-Type','') else b
 except urllib.error.HTTPError as e:
  b=e.read().decode()
  if ok:raise RuntimeError(str(e.code)+' '+b)
  return {'rejected':e.code,'message':b}
sessions={}
for role in ['donor','ngo','volunteer','admin']:
 s=call('/auth/v1/token?grant_type=password',{'email':'foodbridge-'+role+'@demo.example','password':password});sessions[role]=s;print('PASS: '+role+' email/password authentication',flush=True)
def act(role,action,data={},ok=True):return call('/rest/v1/rpc/fb_action',{'p_action':action,'p_data':data},sessions[role]['access_token'],ok=ok)
donor=sessions['donor']['user']['id'];path=donor+'/'+str(uuid.uuid4())+'.png';png=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/f9sAAAAASUVORK5CYII=')
call('/storage/v1/object/foodbridge-images/'+path,token=sessions['donor']['access_token'],raw=png,method='POST',headers={'Content-Type':'image/png'});print('PASS: authenticated image upload',flush=True)
call('/storage/v1/object/sign/foodbridge-images/'+path,{'expiresIn':60},sessions['ngo']['access_token']);print('PASS: NGO can retrieve signed food image',flush=True)
now=datetime.datetime.now(datetime.timezone.utc);data={'title':'QA WORKFLOW FIXTURE — NOT REAL FOOD','description':'Disposable integration test record. Not an actual donation.','category':'Cooked meals','diet':'Vegetarian','servings':25,'weight_kg':8,'city':'Bengaluru','location':'QA fixture location, not a pickup address','lat':12.97,'lng':77.59,'prepared_at':(now-datetime.timedelta(minutes=30)).isoformat(),'deadline':(now+datetime.timedelta(hours=4)).isoformat(),'allergens':'Test only','handling':'Test fixture only','image_path':path,'safety_confirmed':True}
food=act('donor','create_food',data)['id'];print('PASS: donor publishes food with stored image',flush=True)
assert act('ngo','approve',{'food_id':food,'request_id':str(uuid.uuid4())},False).get('rejected');print('PASS: unauthorized approval rejected',flush=True)
act('ngo','request',{'food_id':food,'message':'QA distribution request','delivery_address':'QA receiving location, not real address'})
req=call('/rest/v1/fb_requests?food_id=eq.'+food+'&select=*',token=sessions['donor']['access_token'])[0]
assert act('ngo','request',{'food_id':food,'message':'Duplicate request','delivery_address':'QA location'},False).get('rejected');print('PASS: duplicate NGO requests rejected',flush=True)
act('donor','approve',{'food_id':food,'request_id':req['id']});print('PASS: donor approves NGO request',flush=True)
assert act('donor','approve',{'food_id':food,'request_id':req['id']},False).get('rejected');print('PASS: repeated approval prevented',flush=True)
act('volunteer','claim',{'food_id':food});print('PASS: volunteer accepts pickup',flush=True)
assert act('volunteer','claim',{'food_id':food},False).get('rejected');print('PASS: pickup cannot be claimed twice',flush=True)
assert act('ngo','deliver',{'food_id':food},False).get('rejected');print('PASS: delivery cannot precede pickup',flush=True)
act('volunteer','pickup',{'food_id':food});act('ngo','deliver',{'food_id':food});print('PASS: pickup → NGO-confirmed delivery',flush=True)
f=call('/rest/v1/fb_food?id=eq.'+food+'&select=*',token=sessions['ngo']['access_token'])[0];assert f['status']=='delivered' and f['delivered_at'] and f['servings']==25;print('PASS: shared completed donation and impact source data',flush=True)
ns=call('/rest/v1/fb_notifications?select=*',token=sessions['ngo']['access_token']);assert ns and all(n['user_id']==sessions['ngo']['user']['id'] for n in ns);print('PASS: notifications restricted to their owner',flush=True)
act('ngo','read_notifications');print('PASS: mark notifications read',flush=True)
events=call('/rest/v1/fb_events?food_id=eq.'+food+'&select=*',token=sessions['admin']['access_token']);assert len(events)==6;print('PASS: six-stage audit history',flush=True)
# Exercise explicit assignment and request rejection on a second disposable record.
data['title']='QA SECOND FIXTURE — NOT REAL FOOD';second=act('donor','create_food',data)['id'];act('ngo','request',{'food_id':second,'message':'Second QA request','delivery_address':'QA receiving location'});r=call('/rest/v1/fb_requests?food_id=eq.'+second+'&select=*',token=sessions['donor']['access_token'])[0];act('donor','reject',{'food_id':second,'request_id':r['id']});print('PASS: donor rejects NGO request',flush=True)
# Admin safety hold stops all further actions.
act('admin','flag',{'food_id':second,'reason':'QA safety hold test, no actual food'});assert act('ngo','request',{'food_id':second,'message':'Invalid test request','delivery_address':'QA receiving address'},False).get('rejected');print('PASS: admin safety hold enforced',flush=True)
act('admin','admin_user',{'user_id':sessions['volunteer']['user']['id'],'active':False});assert act('volunteer','read_notifications',{},False).get('rejected');act('admin','admin_user',{'user_id':sessions['volunteer']['user']['id'],'active':True});print('PASS: admin account pause and restoration enforced',flush=True)
print(json.dumps({'test_food_ids':[food,second],'image_path':path}),flush=True)

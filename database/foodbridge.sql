create schema if not exists fb_private;
revoke all on schema fb_private from public,anon;
grant usage on schema fb_private to authenticated;
create table public.fb_profiles(id uuid primary key references auth.users(id) on delete cascade,name text not null check(length(name) between 2 and 100),organization text not null check(length(organization) between 2 and 150),role text not null check(role in ('donor','ngo','volunteer','admin')),city text not null check(length(city) between 2 and 100),active boolean not null default true,created_at timestamptz not null default now());
create table public.fb_food(id uuid primary key default gen_random_uuid(),donor_id uuid not null references public.fb_profiles(id),title text not null check(length(title) between 3 and 120),description text not null check(length(description) between 5 and 2000),category text not null check(category in ('Cooked meals','Produce','Bakery','Packaged food','Other')),diet text not null check(diet in ('Vegetarian','Vegan','Non-vegetarian')),servings int not null check(servings between 1 and 100000),weight_kg numeric(10,2) not null check(weight_kg>0 and weight_kg<=100000),city text not null,location text not null check(length(location) between 5 and 400),lat double precision check(lat between -90 and 90),lng double precision check(lng between -180 and 180),prepared_at timestamptz not null,deadline timestamptz not null,allergens text not null default '',handling text not null check(length(handling) between 3 and 600),image_path text,ngo_id uuid references public.fb_profiles(id),volunteer_id uuid references public.fb_profiles(id),status text not null default 'available' check(status in ('available','approved','assigned','picked_up','delivered','cancelled','flagged')),created_at timestamptz not null default now(),delivered_at timestamptz,check(deadline>prepared_at));
create table public.fb_requests(id uuid primary key default gen_random_uuid(),food_id uuid not null references public.fb_food(id),ngo_id uuid not null references public.fb_profiles(id),message text not null check(length(message) between 3 and 1000),delivery_address text not null check(length(delivery_address) between 5 and 400),status text not null default 'pending' check(status in ('pending','approved','rejected','cancelled')),created_at timestamptz not null default now(),unique(food_id,ngo_id));
create table public.fb_events(id uuid primary key default gen_random_uuid(),food_id uuid not null references public.fb_food(id),actor_id uuid not null references public.fb_profiles(id),event text not null,detail text not null default '',created_at timestamptz not null default now());
create table public.fb_notifications(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.fb_profiles(id),title text not null,body text not null,food_id uuid references public.fb_food(id),is_read boolean not null default false,created_at timestamptz not null default now());
create index fb_food_donor on public.fb_food(donor_id);
create index fb_food_ngo on public.fb_food(ngo_id);
create index fb_food_volunteer on public.fb_food(volunteer_id);
create index fb_food_browse on public.fb_food(status,deadline,city);
create index fb_requests_food on public.fb_requests(food_id);
create index fb_requests_ngo on public.fb_requests(ngo_id);
create index fb_events_food on public.fb_events(food_id,created_at);
create index fb_events_actor on public.fb_events(actor_id);
create index fb_notifications_user on public.fb_notifications(user_id,created_at desc);
create index fb_notifications_food on public.fb_notifications(food_id);
alter table public.fb_profiles enable row level security;alter table public.fb_food enable row level security;alter table public.fb_requests enable row level security;alter table public.fb_events enable row level security;alter table public.fb_notifications enable row level security;
create function fb_private.role_of() returns text language sql stable security definer set search_path='' as $$select role from public.fb_profiles where id=auth.uid() and active$$;
revoke all on function fb_private.role_of() from public,anon;grant execute on function fb_private.role_of() to authenticated;
create policy fb_profiles_read on public.fb_profiles for select to authenticated using (id=(select auth.uid()) or (select fb_private.role_of()) is not null);
create policy fb_food_read on public.fb_food for select to authenticated using ((select fb_private.role_of()) is not null);
create policy fb_requests_read on public.fb_requests for select to authenticated using(ngo_id=(select auth.uid()) or (select fb_private.role_of())='admin' or exists(select 1 from public.fb_food f where f.id=food_id and (f.donor_id=(select auth.uid()) or f.volunteer_id=(select auth.uid()))));
create policy fb_events_read on public.fb_events for select to authenticated using((select fb_private.role_of()) is not null);
create policy fb_notifications_read on public.fb_notifications for select to authenticated using(user_id=(select auth.uid()));
grant select on public.fb_profiles,public.fb_food,public.fb_requests,public.fb_events,public.fb_notifications to authenticated;
revoke insert,update,delete on public.fb_profiles,public.fb_food,public.fb_requests,public.fb_events,public.fb_notifications from anon,authenticated;
create function fb_private.perform(p_action text,p_data jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();r text;f public.fb_food;req public.fb_requests;target uuid;newid uuid;v uuid;detail text;nm text;
begin
if u is null then raise exception 'Please sign in to continue';end if;
if p_action='register' then
 if exists(select 1 from public.fb_profiles where id=u) then raise exception 'Your FoodBridge profile already exists';end if;
 if coalesce(p_data->>'role','') not in ('donor','ngo','volunteer') then raise exception 'Choose a valid registration role';end if;
 insert into public.fb_profiles(id,name,organization,city,role) values(u,trim(p_data->>'name'),trim(p_data->>'organization'),trim(p_data->>'city'),p_data->>'role');
 return jsonb_build_object('ok',true);
end if;
select role,name into r,nm from public.fb_profiles where id=u and active;
if r is null then raise exception 'Complete your profile or contact an administrator if your account is paused';end if;
if p_action='read_notifications' then update public.fb_notifications set is_read=true where user_id=u;return jsonb_build_object('ok',true);end if;
if p_action='update_profile' then update public.fb_profiles set name=trim(p_data->>'name'),organization=trim(p_data->>'organization'),city=trim(p_data->>'city') where id=u;return jsonb_build_object('ok',true);end if;
if p_action='admin_user' then
 if r<>'admin' then raise exception 'Administrator access required';end if;
 target:=(p_data->>'user_id')::uuid;
 if target=u then raise exception 'You cannot pause your own administrator account';end if;
 update public.fb_profiles set active=(p_data->>'active')::boolean where id=target and role<>'admin';
 return jsonb_build_object('ok',true);
end if;
if p_action='create_food' then
 if r<>'donor' then raise exception 'Only donors can publish surplus food';end if;
 if (p_data->>'deadline')::timestamptz<=now() or (p_data->>'prepared_at')::timestamptz>now()+interval '5 minutes' then raise exception 'Preparation must be in the past and pickup deadline must be in the future';end if;
 if coalesce((p_data->>'safety_confirmed')::boolean,false) is not true then raise exception 'Confirm the food handling declaration';end if;
 if p_data->>'image_path' is not null and (split_part(p_data->>'image_path','/',1)<>u::text or not exists(select 1 from storage.objects where bucket_id='foodbridge-images' and name=p_data->>'image_path' and owner_id=u::text)) then raise exception 'Upload your food image first';end if;
 insert into public.fb_food(donor_id,title,description,category,diet,servings,weight_kg,city,location,lat,lng,prepared_at,deadline,allergens,handling,image_path) values(u,trim(p_data->>'title'),trim(p_data->>'description'),p_data->>'category',p_data->>'diet',(p_data->>'servings')::int,(p_data->>'weight_kg')::numeric,trim(p_data->>'city'),trim(p_data->>'location'),(p_data->>'lat')::float,(p_data->>'lng')::float,(p_data->>'prepared_at')::timestamptz,(p_data->>'deadline')::timestamptz,coalesce(p_data->>'allergens',''),p_data->>'handling',p_data->>'image_path') returning id into newid;
 insert into public.fb_events(food_id,actor_id,event) values(newid,u,'Food listed');return jsonb_build_object('ok',true,'id',newid);
end if;
select * into f from public.fb_food where id=(p_data->>'food_id')::uuid for update;
if f.id is null then raise exception 'Donation not found';end if;
if p_action in ('request','approve','claim','assign','pickup') and f.deadline<=now() then raise exception 'Pickup deadline has passed. This donation cannot be collected';end if;
if p_action='request' then
 if r<>'ngo' or f.status<>'available' then raise exception 'Only NGOs can request available food';end if;
 insert into public.fb_requests(food_id,ngo_id,message,delivery_address) values(f.id,u,trim(p_data->>'message'),trim(p_data->>'delivery_address'));
 insert into public.fb_notifications(user_id,title,body,food_id) values(f.donor_id,'New donation request',nm||' requested '||f.title,f.id);detail:='NGO requested donation';
elsif p_action in ('approve','reject') then
 if f.donor_id<>u or r<>'donor' or f.status<>'available' then raise exception 'Only the donor can review requests for an available listing';end if;
 select * into req from public.fb_requests where id=(p_data->>'request_id')::uuid and food_id=f.id and status='pending' for update;
 if req.id is null then raise exception 'This request has already been reviewed';end if;
 update public.fb_requests set status=case when p_action='approve' then 'approved' else 'rejected' end where id=req.id;
 if p_action='approve' then
  if not exists(select 1 from public.fb_profiles where id=req.ngo_id and active) then raise exception 'NGO account is paused';end if;
  update public.fb_food set ngo_id=req.ngo_id,status='approved' where id=f.id;
  insert into public.fb_notifications(user_id,title,body,food_id) select ngo_id,'Request closed','Another NGO was selected for '||f.title,f.id from public.fb_requests where food_id=f.id and status='pending';
  update public.fb_requests set status='rejected' where food_id=f.id and status='pending';
  insert into public.fb_notifications(user_id,title,body,food_id) select id,'Pickup available',f.title||' in '||f.city||' needs a volunteer',f.id from public.fb_profiles where role='volunteer' and active;
 end if;
 insert into public.fb_notifications(user_id,title,body,food_id) values(req.ngo_id,case when p_action='approve' then 'Request approved' else 'Request declined' end,f.title,f.id);detail:=case when p_action='approve' then 'Request approved' else 'Request declined' end;
elsif p_action in ('assign','claim') then
 if f.status<>'approved' then raise exception 'This pickup is no longer available';end if;
 if p_action='claim' then if r<>'volunteer' then raise exception 'Volunteer access required';end if;v:=u;
 else if not ((r='donor' and f.donor_id=u) or r='admin') then raise exception 'Only the donor or administrator can assign a volunteer';end if;v:=(p_data->>'volunteer_id')::uuid;end if;
 if not exists(select 1 from public.fb_profiles where id=v and role='volunteer' and active) then raise exception 'Select an active volunteer';end if;
 update public.fb_food set volunteer_id=v,status='assigned' where id=f.id;
 insert into public.fb_notifications(user_id,title,body,food_id) select x,'Volunteer assigned',f.title,f.id from unnest(array[f.donor_id,f.ngo_id,v]) x;detail:='Volunteer assigned';
elsif p_action='pickup' then
 if r<>'volunteer' or f.volunteer_id<>u or f.status<>'assigned' then raise exception 'Only the assigned volunteer can confirm pickup';end if;
 update public.fb_food set status='picked_up' where id=f.id;
 insert into public.fb_notifications(user_id,title,body,food_id) values(f.ngo_id,'Food is on the way',f.title||' has been collected. Confirm receipt after delivery.',f.id);detail:='Food collected';
elsif p_action='deliver' then
 if r<>'ngo' or f.ngo_id<>u or f.status<>'picked_up' then raise exception 'Only the selected NGO can confirm receipt after pickup';end if;
 update public.fb_food set status='delivered',delivered_at=now() where id=f.id;
 insert into public.fb_notifications(user_id,title,body,food_id) select x,'Delivery confirmed',f.title||' · '||f.servings||' portions delivered',f.id from unnest(array[f.donor_id,f.volunteer_id,u]) x;detail:='Delivery confirmed by NGO';
elsif p_action='cancel' then
 if f.donor_id<>u or r<>'donor' or f.status not in ('available','approved','assigned') then raise exception 'Only the donor can cancel before pickup';end if;
 update public.fb_food set status='cancelled' where id=f.id;
 insert into public.fb_notifications(user_id,title,body,food_id) select x,'Donation cancelled',f.title,f.id from unnest(array[f.ngo_id,f.volunteer_id]) x where x is not null;
 update public.fb_requests set status='cancelled' where food_id=f.id and status in ('pending','approved');detail:='Donation cancelled';
elsif p_action='flag' then
 if r<>'admin' or f.status in ('delivered','cancelled','flagged') then raise exception 'Administrator can flag only active donations';end if;
 if length(trim(coalesce(p_data->>'reason','')))<5 then raise exception 'Provide a reason for the safety alert';end if;
 update public.fb_food set status='flagged' where id=f.id;
 insert into public.fb_notifications(user_id,title,body,food_id) select x,'Food safety alert',p_data->>'reason',f.id from unnest(array[f.donor_id,f.ngo_id,f.volunteer_id]) x where x is not null;detail:='Safety hold: '||(p_data->>'reason');
else raise exception 'Unknown action';end if;
insert into public.fb_events(food_id,actor_id,event) values(f.id,u,detail);
return jsonb_build_object('ok',true,'id',f.id);
end$$;
revoke all on function fb_private.perform(text,jsonb) from public,anon;grant execute on function fb_private.perform(text,jsonb) to authenticated;
create function public.fb_action(p_action text,p_data jsonb default '{}'::jsonb) returns jsonb language sql security invoker set search_path='' as $$select fb_private.perform(p_action,p_data)$$;
revoke all on function public.fb_action(text,jsonb) from public,anon;grant execute on function public.fb_action(text,jsonb) to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('foodbridge-images','foodbridge-images',false,5242880,array['image/jpeg','image/png','image/webp']);
create policy fb_images_read on storage.objects for select to authenticated using(bucket_id='foodbridge-images' and ((select fb_private.role_of()) is not null));
create policy fb_images_insert on storage.objects for insert to authenticated with check(bucket_id='foodbridge-images' and (storage.foldername(name))[1]=(select auth.uid())::text and (select fb_private.role_of())='donor');
create policy fb_images_delete on storage.objects for delete to authenticated using(bucket_id='foodbridge-images' and (storage.foldername(name))[1]=(select auth.uid())::text and not exists(select 1 from public.fb_food where image_path=name));

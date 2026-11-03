'use client';
import {createClient} from '@supabase/supabase-js';
export const supabase=createClient('https://rzuhxzzlczqcbnagbmiz.supabase.co','sb_publishable_z1OOkFLyDaUK50EkEiHAuQ_8nHd8VLQ');
export type Profile={id:string;name:string;organization:string;role:'donor'|'ngo'|'volunteer'|'admin';city:string;active:boolean};
export type Food={id:string;donor_id:string;title:string;description:string;category:string;diet:string;servings:number;weight_kg:number;city:string;location:string;lat:number|null;lng:number|null;prepared_at:string;deadline:string;allergens:string;handling:string;image_path:string|null;image_url?:string;ngo_id:string|null;volunteer_id:string|null;status:string;created_at:string;delivered_at:string|null};

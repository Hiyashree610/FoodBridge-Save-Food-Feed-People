# Vercel deployment

Live: https://foodbridge-sharehope.vercel.app

The Vercel frontend is in `vercel-app`. Build: `npm run build`; output: `dist`; install: `npm install`; Node 24. Supabase authentication, PostgreSQL, storage and Edge Functions remain the shared backend. Registration allows the new Vercel origin. Do not expose service-role credentials in frontend code.

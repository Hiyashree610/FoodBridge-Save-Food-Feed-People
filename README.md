# FoodBridge — Save Food, Feed People

**Don’t Waste Food. Share Hope.**

FoodBridge connects food donors, NGOs and volunteers through a shared database and four role-specific dashboards.

## Working features
- Email/password registration and sign-in, without OTP or email confirmation for FoodBridge registration
- Food listings with images, portions, weight, pickup address, optional coordinates and deadlines
- City, category, search and distance filters
- NGO requests and donor approval/rejection
- Donor/admin volunteer assignment or volunteer self-acceptance
- Volunteer pickup confirmation and receiving NGO delivery confirmation
- Donation history, portions/weight impact statistics and in-app notifications
- Admin analytics, safety holds and account pause/restore controls

## Stack
React, TypeScript, Tailwind CSS and custom CSS, Vinext/Vite, Supabase PostgreSQL/Auth/Storage/Edge Functions.

## Source structure
- `app/page.tsx`: homepage, registration and role dashboards
- `app/supabase.ts`: Supabase client and application types
- `app/globals.css`: responsive theme
- `public/food-hero.svg`: homepage artwork
- `database/foodbridge.sql`: core database schema, RLS policies, actions and image bucket
- `database/direct-registration.sql`: registration rate-limit table and server-only helper
- `supabase/functions/foodbridge-register/index.ts`: server-side registration without email confirmation

## Local setup
Use Node.js meeting `package.json` engines and pnpm matching its `packageManager` version.

```sh
pnpm install --frozen-lockfile
pnpm dev
```

Open the URL printed by the terminal. To check and build:

```sh
pnpm exec tsc --noEmit
pnpm build
```

## Supabase and independent deployment
The source currently points to the existing deployed Supabase project using browser-safe publishable/anon keys. These keys do not replace authentication or RLS.

For a separate installation:
1. Create or select your Supabase project.
2. Apply `database/foodbridge.sql`, then `database/direct-registration.sql` once to a fresh database.
3. Deploy the `foodbridge-register` Edge Function with JWT verification enabled. Its service-role key stays server-side in the function environment; never put that key in frontend code.
4. Replace project URL and browser keys in `app/supabase.ts`, registration endpoint/headers in `app/page.tsx`, and the project references in the optional test scripts.
5. Add your new website origin to the registration function’s allowed-origin list.
6. Create an administrator profile through a trusted database administrator. Public registration permits donor, NGO and volunteer roles only.
7. Build and deploy to compatible hosting. GitHub Pages alone does not run the full Vinext application.

The existing `.openai/hosting.json` identifies the original Sites deployment; a separate hosting setup needs its own configuration.

## Data and testing
This repository contains source code and SQL setup, not live user records, passwords, sessions or uploaded donation images. Images are in a private Supabase bucket with signed access. Notifications and dashboard records refresh every 30 seconds.

The optional `scripts/verify-*.py` scripts create QA accounts or donation fixtures. Review them and use a disposable test environment when running your own checks. Presentation account passwords are not included in this repository.

## Live website
https://foodbridge-share-hope.singh-01-nidhi11.chatgpt.site

Exported from application commit `ec547fb8cf5d46d15c146f8f601cad5a0cb8f46e`.

# Database

cutouts runs on a free Supabase project: Postgres, image storage and the admin login.

## Files, in the order to run them

| File | What it does |
|---|---|
| `supabase/000_audit.sql` | Read-only. Lists every policy, which tables have RLS on, and the bucket limits. Run it first whenever you want to check the state. |
| `supabase/001_schema.sql` | The four tables as they exist, so the project can be rebuilt from scratch. |
| `supabase/002_security.sql` | The hardening on top: no listing of Storage, WebP-only 3 MB buckets, length checks and hourly limits. Safe to run more than once. |

The policies themselves and the `is_admin()` function live in the project. `is_admin()` checks the signed-in user against the `admins` table, so the admin's email never appears in this public repo.

## Tables

| Table | Holds | Who can read | Who can write |
|---|---|---|---|
| `collages` | Ali's collages, with their layers | everyone | admin |
| `community` | collages sent by visitors | everyone sees `approved` ones; admin sees all | anyone can insert with `approved = false`; admin approves or deletes |
| `scraps` | the scrap pile | everyone sees `published` ones; admin sees all | anyone can insert unpublished `v-…` scraps; admin does the rest |
| `hidden` | built-in pieces that were taken down | everyone | admin |
| `admins` | who may moderate | nobody from the site | nobody from the site |

Text fields have maximum lengths (`check` constraints). A trigger stops more than 30 collages or 150 scraps waiting per hour, and closes the inbox at 300 pending.

## Storage

Buckets `collages`, `community` and `scraps` are public by link, WebP only, 3 MB max. Visitors can upload only to `community/<uuid>.webp` and `scraps/v/<uuid>.webp`. Nobody but the admin can list what's inside. Images are redrawn in a canvas before upload, which strips location and camera data.

## Sign-in

Magic link only, with `shouldCreateUser: false`, and "Allow new users to sign up" is off. Redirect URLs allowed: `https://cut-outs.vercel.app/**` and the Vercel previews.

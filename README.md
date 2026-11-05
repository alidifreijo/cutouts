# cutouts

Analog collages on a green cutting mat, plus a little studio where anyone can make their own collage from the scraps.

- **the table** — the collages, loose on an endless mat you drag around. Click one to see it up close.
- **make a mess** — drag scraps onto an A4 sheet, add text, stack print-style effects, cut images into pieces, glue it to the table.
- **add scraps** — photograph a collage or a magazine page, cut out bits for everyone's pile. Everything waits for a look before it's public.

Collages made from found magazine imagery. Personal, non-commercial project.

## Structure

```
index.html          the table + make a mess
studio.html         add scraps (also loaded inside index.html)
privacy.html  404.html
js/app.js           everything behind index.html
js/studio.js        everything behind studio.html
js/vendor/          supabase-js 2.45.4, heic2any 0.0.4 (self-hosted, pinned)
js/vercel-queues.js Vercel Analytics queue (kept out of the HTML for the CSP)
css/page.css  fonts/ small pages + the handwritten font
a/  s/              built-in collages and scraps (WebP)
supabase/           000_audit.sql · 001_schema.sql · 002_security.sql
vercel.json         security headers
.github/workflows/  keepalive, backup
```

No build step on the server. The pages are generated from the working copy with `build.py` + `publish.py`, which move every script out of the HTML.

## Run it locally

Any static server works: `npx serve .` or `python3 -m http.server`. To test with the real headers, serve with something that applies `vercel.json` (the CSP blocks inline scripts, so a plain server won't catch mistakes).

## Supabase

Tables `collages` (Ali's), `community` (visitors' collages, `approved` false until moderated), `scraps` (visitors' ones start `published=false` with ids `v-…`), `hidden` (built-ins taken down), `admins`.
Buckets `collages`, `community`, `scraps`: public read by URL, WebP only, 3 MB max.

- Row Level Security is on everywhere. Visitors can read published things and insert pending ones; only `is_admin()` can approve, edit or delete.
- Who is admin lives in `public.admins`, not in the site's code. The browser only uses it to decide whether to show the moderation UI.
- Magic-link login with `shouldCreateUser: false`, and sign-ups are off in the dashboard.
- Triggers cap pending uploads per hour and the size of the inbox; `check` constraints cap every text field.

## Scheduled tasks

| Workflow | When | What | Needs |
|---|---|---|---|
| keepalive | every 3 days | reads one row so the free project isn't paused | nothing (public key) |
| backup | Mondays | `pg_dump` of `public`, AES256 with gpg, artifact kept 90 days | `SUPABASE_DB_URL`, `BACKUP_PASSPHRASE` |

Images in Storage aren't in the backup; the originals live in `a/` and `s/` and visitors' uploads can be re-sent.

## Security

- Hosted on **Vercel** with `vercel.json`: CSP without inline scripts, `frame-ancestors`, `nosniff`, `Referrer-Policy`, `Permissions-Policy`, `COOP`, HSTS.
- Exceptions, all on `studio.html` only:
  - `'unsafe-eval'`: heic2any (iPhone photos) builds functions at runtime.
  - `'wasm-unsafe-eval'`, `https://esm.sh`, `https://staticimgly.com`, `blob:`: background removal (`@imgly/background-removal@1.4.5`), loaded only when someone presses "Remove background".
  - `frame-ancestors 'self'`: the studio is shown inside the table page.
- Google Fonts (`fonts.googleapis.com` / `fonts.gstatic.com`) for the typefaces of the text tool.
- Text typed by visitors is always escaped before it's drawn.
- Secret scanning and push protection are on.

## If something goes wrong

- **A key leaked** → rotate it in Supabase → Settings → API Keys (the publishable key is public by design; a `sb_secret_…` key never goes in the repo).
- **Flood of uploads** → Supabase → Authentication → Policies, drop `community_send` / `scraps_send` and the storage `storage_send_*` policies. The site keeps working, sending just fails.
- **Something nasty sent** → reject it from the studio inbox (deletes row and file).
- **Broken deploy** → Vercel → Deployments → last good one → "Promote to Production".
- **Data lost** → download the latest `backup` artifact, `gpg -d`, `psql -f`.
- **Account stolen** → password and 2FA first, then rotate keys.

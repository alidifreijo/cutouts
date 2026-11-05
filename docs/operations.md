# Operations

How the site is protected, what runs on its own and what to do when something goes wrong.

## Security

- **Headers** (`vercel.json`): a Content-Security-Policy that only lets the page load its own files, Supabase and Google Fonts; no inline scripts; no framing by other sites; plus HSTS, nosniff, Referrer-Policy, Permissions-Policy and COOP.
- **Exceptions, all on `studio.html` only:** `'unsafe-eval'` for heic2any (iPhone photos); `'wasm-unsafe-eval'`, `esm.sh`, `staticimgly.com` and `blob:` for background removal, which loads only when someone presses "Remove background"; `frame-ancestors 'self'` because the studio is shown inside the table page. If you add a new outside service, add its address to the CSP or the browser will block it.
- **Data**: Row Level Security on every table, hourly limits, WebP-only uploads into fixed folders, and a review queue before anything goes public.
- **Secrets**: only the publishable key is in the code. The database URL and the backup passphrase live in GitHub → Settings → Secrets and nowhere else. Workflows split the password out of the address before using it, so it can't end up in a public log.

## Scheduled jobs (GitHub Actions)

| Workflow | When | What | Needs |
|---|---|---|---|
| keepalive | every 3 days | reads one row so the free project isn't paused | nothing (public key) |
| backup | Mondays | `pg_dump` of `public`, AES256 with gpg, artifact kept 90 days | `SUPABASE_DB_URL`, `BACKUP_PASSPHRASE` |

Images in Storage aren't in the backup: the originals live in `a/` and `s/`, and visitors can re-send theirs.

## If something goes wrong

1. **A key or password leaked**: Supabase → Database → Settings → reset the password (letters and numbers only), update `SUPABASE_DB_URL` in GitHub, delete the workflow run that showed it, and run the job again. The publishable key is public by design.
2. **Someone is flooding uploads**: in the SQL Editor drop the visitors' insert policies (`anyone submits`, `visitors send scraps`, `anyone uploads to community`, `anyone uploads motion layers`, `visitors upload scraps`). The site keeps working; sending just fails until you recreate them.
3. **Something nasty was sent**: reject it from the studio inbox (`/?studio`), which deletes the row and the file.
4. **The site is broken after a push**: Vercel → Deployments → the last good one → ⋯ → Promote to Production. Then fix it calmly.
5. **Data lost or damaged**: Actions → backup → newest run → download the artifact, `gpg --decrypt` it, and run it in a fresh SQL Editor tab.
6. **An account was taken over**: change the password and check 2FA on Gmail, GitHub, Vercel and Supabase first, then go through 1 and 4.

## Monitoring

- **Vercel Analytics and Speed Insights**: visits and real loading speed, without cookies.
- **UptimeRobot**: checks the site every five minutes and emails the owner if it stops answering.

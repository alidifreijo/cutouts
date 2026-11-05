-- Read-only. Run in Supabase → SQL Editor and paste the three results back. Nothing here is secret.

-- 1. Every policy on our tables and on Storage
select tablename, policyname, cmd, roles, qual, with_check
from pg_policies where schemaname in ('public','storage') order by 1,2;

-- 2. RLS on/off per table
select relname as table, relrowsecurity as rls_on, relforcerowsecurity as rls_forced
from pg_class where relnamespace='public'::regnamespace and relkind='r' order by 1;

-- 3. Buckets and their limits
select id, public, file_size_limit, allowed_mime_types from storage.buckets order by 1;

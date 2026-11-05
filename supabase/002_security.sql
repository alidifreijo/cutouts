-- cutouts · permissions. Replaces every existing policy on these tables and buckets.
-- Run once, after pasting the result of 000_audit.sql to Claude.

-- ---------- admins: who may moderate. The email lives here, never in the site's code.
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.admins enable row level security;  -- no policies: nobody can read or edit it from the site

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;
grant execute on function public.is_admin() to anon, authenticated;

-- Make Ali the admin (her auth user must already exist: she has signed in before).
insert into public.admins(user_id)
select id from auth.users where lower(email) = lower('REPLACE_WITH_YOUR_EMAIL')
on conflict do nothing;

-- ---------- wipe old policies on our tables, then write them again explicitly
do $$ declare r record; begin
  for r in select policyname, tablename from pg_policies
           where schemaname='public' and tablename in ('collages','community','scraps','hidden','admins') loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

alter table public.collages  enable row level security;
alter table public.community enable row level security;
alter table public.scraps    enable row level security;
alter table public.hidden    enable row level security;

-- collages: Ali's own. Everyone reads, only admin writes.
create policy collages_read  on public.collages for select to anon, authenticated using (true);
create policy collages_admin on public.collages for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- community: visitors' collages. Everyone sees approved ones; anyone can send one, always as pending.
create policy community_read     on public.community for select to anon, authenticated using (approved or public.is_admin());
create policy community_send     on public.community for insert to anon, authenticated with check (approved = false);
create policy community_moderate on public.community for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy community_delete   on public.community for delete to authenticated using (public.is_admin());

-- scraps: everyone reads published ones; visitors send unpublished ones under v-…; admin does the rest.
create policy scraps_read  on public.scraps for select to anon, authenticated using (published or public.is_admin());
create policy scraps_send  on public.scraps for insert to anon, authenticated
  with check (published = false and id like 'v-%' and image_path like 'v/%' and collage_id is null);
create policy scraps_admin_insert on public.scraps for insert to authenticated with check (public.is_admin());
create policy scraps_admin_update on public.scraps for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy scraps_admin_delete on public.scraps for delete to authenticated using (public.is_admin());

-- hidden: list of built-in pieces Ali took down. Everyone reads, only admin writes.
create policy hidden_read  on public.hidden for select to anon, authenticated using (true);
create policy hidden_admin on public.hidden for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------- sizes: nobody can stuff a novel into a field
alter table public.community drop constraint if exists community_lengths;
alter table public.community add constraint community_lengths check (
  char_length(coalesce(title,'')) <= 60 and char_length(coalesce(description,'')) <= 280
  and char_length(coalesce(signed,'')) <= 40 and char_length(image_path) <= 80
  and coalesce(w,0) between 0 and 2000 and coalesce(h,0) between 0 and 3000);
alter table public.scraps drop constraint if exists scraps_lengths;
alter table public.scraps add constraint scraps_lengths check (
  char_length(coalesce(title,'')) <= 80 and char_length(coalesce(signed,'')) <= 40
  and char_length(id) <= 120 and char_length(image_path) <= 140
  and coalesce(w,0) between 0 and 2000 and coalesce(h,0) between 0 and 2000);

-- ---------- rate limits: visitors can't flood the inbox
create or replace function public.limit_pending() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if public.is_admin() then return new; end if;
  if tg_table_name = 'community' and
     (select count(*) from public.community where not approved and created_at > now() - interval '1 hour') >= 30 then
    raise exception 'Too many collages waiting. Try again later.';
  end if;
  if tg_table_name = 'scraps' and
     (select count(*) from public.scraps where not published and created_at > now() - interval '1 hour') >= 150 then
    raise exception 'Too many scraps waiting. Try again later.';
  end if;
  if (select count(*) from public.community where not approved) >= 300 then
    raise exception 'The inbox is full. Try again in a few days.';
  end if;
  return new;
end $$;
drop trigger if exists community_limit on public.community;
create trigger community_limit before insert on public.community for each row execute function public.limit_pending();
drop trigger if exists scraps_limit on public.scraps;
create trigger scraps_limit before insert on public.scraps for each row execute function public.limit_pending();

-- ---------- storage: size and type limits, uploads only where the site puts them
update storage.buckets set file_size_limit = 3145728, allowed_mime_types = array['image/webp']
where id in ('community','scraps','collages');

do $$ declare r record; begin
  for r in select policyname from pg_policies where schemaname='storage' and tablename='objects'
           and (coalesce(qual,'')||coalesce(with_check,'')) ~ '(community|scraps|collages)' loop
    execute format('drop policy %I on storage.objects', r.policyname);
  end loop;
end $$;
-- Public buckets serve files by URL without any select policy, so no "list everything" policy for visitors.
create policy storage_admin_all on storage.objects for all to authenticated
  using (bucket_id in ('community','scraps','collages') and public.is_admin())
  with check (bucket_id in ('community','scraps','collages') and public.is_admin());
create policy storage_send_community on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'community' and name ~ '^[0-9a-f-]{36}(-m[0-9]{1,2})?\.webp$');
create policy storage_send_scraps on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'scraps' and name ~ '^v/[0-9a-f-]{36}\.webp$');

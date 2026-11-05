-- cutouts · hardening on top of the existing policies (which were already right: pending stays private,
-- visitors can only send pending things, only is_admin() moderates). Safe to run more than once.

-- 1. Storage: public buckets serve files by URL without any policy, so visitors don't need SELECT.
--    With it, anyone could LIST every file, including pending and rejected uploads.
drop policy if exists "community images are public" on storage.objects;
drop policy if exists "cutouts images are public"   on storage.objects;
drop policy if exists "admin reads images"          on storage.objects;
create policy "admin reads images" on storage.objects for select to authenticated
  using (bucket_id in ('collages','community','scraps') and public.is_admin());

-- 2. Buckets: the site only ever uploads WebP, up to 3 MB
update storage.buckets set file_size_limit = 3145728, allowed_mime_types = array['image/webp']
where id in ('collages','community','scraps');

-- 3. The site asks the database whether you're the admin (instead of comparing emails in the browser)
grant execute on function public.is_admin() to anon, authenticated;

-- 4. Sizes: nobody can stuff a novel into a field
alter table public.community drop constraint if exists community_lengths;
alter table public.community add constraint community_lengths check (
  char_length(coalesce(title,'')) <= 60 and char_length(coalesce(description,'')) <= 280
  and char_length(coalesce(signed,'')) <= 40 and char_length(image_path) <= 80
  and coalesce(w,0) between 0 and 2000 and coalesce(h,0) between 0 and 3000) not valid;
alter table public.scraps drop constraint if exists scraps_lengths;
alter table public.scraps add constraint scraps_lengths check (
  char_length(coalesce(title,'')) <= 80 and char_length(coalesce(signed,'')) <= 40
  and char_length(id) <= 120 and char_length(image_path) <= 140
  and coalesce(w,0) between 0 and 2000 and coalesce(h,0) between 0 and 2000) not valid;

-- 5. Rate limits: visitors can't flood the inbox
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

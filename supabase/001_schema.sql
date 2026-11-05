-- cutouts · tables as they exist today, so the project can be rebuilt from scratch.
-- Safe to run on the live project: everything is "if not exists".

create table if not exists public.collages (
  id text primary key,
  title text,
  description text,
  image_path text not null,
  w int, h int,
  layers jsonb,
  motion jsonb,
  sort int,
  created_at timestamptz not null default now()
);

create table if not exists public.community (
  id uuid primary key default gen_random_uuid(),
  image_path text not null,
  title text,
  description text,
  signed text,
  w int, h int,
  batch uuid,
  motion jsonb,
  approved boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.scraps (
  id text primary key,
  title text,
  cluster text,
  image_path text not null,
  w int, h int,
  collage_id text,
  sort int,
  signed text,
  batch uuid,
  published boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.hidden (
  id text primary key,
  created_at timestamptz not null default now()
);

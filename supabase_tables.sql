-- Run this SQL in your Supabase dashboard (SQL Editor)
-- to create the tables required for the Nutrition feature.

-- ── Food Logs ────────────────────────────────────────────────────────────────
create table if not exists food_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     text not null,
  date        date not null,
  meal_type   text not null check (meal_type in ('breakfast','lunch','dinner','snack')),
  food_name   text not null,
  calories    integer not null default 0,
  protein_g   numeric(6,2) default 0,
  carb_g      numeric(6,2) default 0,
  fat_g       numeric(6,2) default 0,
  quantity    numeric(6,2) default 1,
  unit        text default 'serving',
  created_at  timestamptz default now()
);

create index if not exists food_logs_user_date on food_logs (user_id, date);

-- ── Recipes ──────────────────────────────────────────────────────────────────
create table if not exists recipes (
  id                   uuid primary key default gen_random_uuid(),
  user_id              text not null,
  name                 text not null,
  description          text default '',
  servings             integer default 1,
  calories_per_serving integer not null default 0,
  protein_g            numeric(6,2) default 0,
  carb_g               numeric(6,2) default 0,
  fat_g                numeric(6,2) default 0,
  ingredients          jsonb default '[]',
  instructions         text default '',
  tags                 text[] default '{}',
  created_at           timestamptz default now()
);

create index if not exists recipes_user_id on recipes (user_id);

-- ── Migration 2026-07-07: recipe import attribution ──────────────────────────
-- Imported recipes always link back to the original creator/post.
alter table recipes add column if not exists source_url      text;
alter table recipes add column if not exists source_platform text;
alter table recipes add column if not exists source_creator  text;

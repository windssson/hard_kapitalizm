alter table public.farm_types
  drop column if exists slot_capacity;

alter table public.farm_types
  drop column if exists created_at;

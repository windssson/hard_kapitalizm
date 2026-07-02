update public.tenders
set status = 'disabled',
    updated_at = timezone('utc'::text, now())
where title = 'Demo Ihale';

drop function if exists public.create_demo_tender(
  text,
  uuid,
  integer,
  integer,
  numeric,
  numeric,
  integer,
  integer
);

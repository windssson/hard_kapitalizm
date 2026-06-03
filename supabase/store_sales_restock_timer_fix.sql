create or replace function public.reset_store_sale_timer_on_restock()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if coalesce(old.quantity, 0) <= 0
     and coalesce(new.quantity, 0) > 0 then
    new.pending_sale := 0;
    new.last_sale_processed_at := timezone('utc'::text, now());
    new.updated_at := timezone('utc'::text, now());
  end if;

  if (
    coalesce(old.product_id, '') <> coalesce(new.product_id, '')
    or coalesce(old.quality_level, 0) <> coalesce(new.quality_level, 0)
  )
  and coalesce(new.quantity, 0) = 0 then
    new.pending_sale := 0;
    new.last_sale_processed_at := timezone('utc'::text, now());
    new.updated_at := timezone('utc'::text, now());
  end if;

  return new;
end;
$$;

drop trigger if exists trg_reset_store_sale_timer_on_restock
on public.store_slots;

create trigger trg_reset_store_sale_timer_on_restock
before update of quantity, product_id, quality_level
on public.store_slots
for each row
execute function public.reset_store_sale_timer_on_restock();


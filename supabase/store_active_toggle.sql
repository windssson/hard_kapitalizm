create or replace function public.set_store_active(
  p_store_id uuid,
  p_is_active boolean
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_player_id uuid := auth.uid();
  v_store record;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  update public.stores
  set is_active = coalesce(p_is_active, true),
      updated_at = timezone('utc'::text, now())
  where id = p_store_id
    and player_id = v_player_id
  returning id, is_active
  into v_store;

  if not found then
    raise exception 'Magaza bulunamadi veya size ait degil.';
  end if;

  return jsonb_build_object(
    'success', true,
    'store_id', v_store.id,
    'is_active', v_store.is_active
  );
end;
$$;

grant execute on function public.set_store_active(uuid, boolean)
to anon, authenticated, service_role;


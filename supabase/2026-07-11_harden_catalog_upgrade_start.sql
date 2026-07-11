-- Complete expired snapshots before checking whether a new upgrade can start.
-- Keeping the original implementation private avoids duplicating its logic.

alter function public.start_catalog_building_upgrade(uuid, text, uuid)
  rename to start_catalog_building_upgrade_impl;

revoke all on function public.start_catalog_building_upgrade_impl(uuid, text, uuid)
  from public, anon, authenticated;

create function public.start_catalog_building_upgrade(
  p_player_id uuid,
  p_building_kind text,
  p_entity_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
begin
  if p_player_id is null or p_player_id <> auth.uid() then
    raise exception 'Gecersiz oyuncu.';
  end if;

  perform public.complete_due_building_upgrades(100);

  return public.start_catalog_building_upgrade_impl(
    p_player_id,
    p_building_kind,
    p_entity_id
  );
end;
$function$;

revoke all on function public.start_catalog_building_upgrade(uuid, text, uuid)
  from public, anon;
grant execute on function public.start_catalog_building_upgrade(uuid, text, uuid)
  to authenticated;


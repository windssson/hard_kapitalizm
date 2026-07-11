-- Enforce one active building upgrade per player across the whole game.
-- Existing concurrent upgrades are grandfathered and block every new start
-- until all of them complete; no paid upgrade is cancelled or refunded.

alter function public.start_building_upgrade(uuid, text, uuid)
  rename to start_building_upgrade_impl;

revoke all on function public.start_building_upgrade_impl(uuid, text, uuid)
  from public, anon, authenticated;

create function public.start_building_upgrade(
  p_player_id uuid,
  p_building_kind text,
  p_entity_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_active public.building_upgrades%rowtype;
begin
  if p_player_id is null or p_player_id <> auth.uid() then
    raise exception 'Gecersiz oyuncu.';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('global-building-upgrade:' || p_player_id::text, 0)
  );
  perform public.complete_due_building_upgrades(100);

  select * into v_active
  from public.building_upgrades
  where player_id = p_player_id and status = 'in_progress'
  order by finish_at asc, started_at asc
  limit 1;

  if found then
    return jsonb_build_object(
      'success', false,
      'message', 'Ayni anda yalnizca tek yukseltme yapabilirsin.',
      'block_reason', 'active_upgrade',
      'active_upgrade_id', v_active.id,
      'active_building_kind', v_active.building_kind,
      'active_entity_id', v_active.entity_id,
      'active_finish_at', v_active.finish_at
    );
  end if;

  return public.start_building_upgrade_impl(
    p_player_id,
    p_building_kind,
    p_entity_id
  );
end;
$function$;

revoke all on function public.start_building_upgrade(uuid, text, uuid)
  from public, anon;
grant execute on function public.start_building_upgrade(uuid, text, uuid)
  to authenticated;

create or replace function public.start_catalog_building_upgrade(
  p_player_id uuid,
  p_building_kind text,
  p_entity_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_active public.building_upgrades%rowtype;
begin
  if p_player_id is null or p_player_id <> auth.uid() then
    raise exception 'Gecersiz oyuncu.';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('global-building-upgrade:' || p_player_id::text, 0)
  );
  perform public.complete_due_building_upgrades(100);

  select * into v_active
  from public.building_upgrades
  where player_id = p_player_id and status = 'in_progress'
  order by finish_at asc, started_at asc
  limit 1;

  if found then
    return jsonb_build_object(
      'success', false,
      'message', 'Ayni anda yalnizca tek yukseltme yapabilirsin.',
      'block_reason', 'active_upgrade',
      'active_upgrade_id', v_active.id,
      'active_building_kind', v_active.building_kind,
      'active_entity_id', v_active.entity_id,
      'active_finish_at', v_active.finish_at
    );
  end if;

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


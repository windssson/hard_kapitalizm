-- Surface the global single-upgrade guard in upgrade previews so the client
-- can disable the action before submitting it.

alter function public.get_building_upgrade_quote(text, uuid)
  rename to get_building_upgrade_quote_impl;

revoke all on function public.get_building_upgrade_quote_impl(text, uuid)
  from public, anon, authenticated;

create function public.get_building_upgrade_quote(
  p_building_kind text,
  p_entity_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_player_id uuid := auth.uid();
  v_quote jsonb;
  v_active public.building_upgrades%rowtype;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  v_quote := public.get_building_upgrade_quote_impl(
    p_building_kind,
    p_entity_id
  );

  if v_quote->>'block_reason' = 'maximum_level' then
    return v_quote;
  end if;

  select * into v_active
  from public.building_upgrades
  where player_id = v_player_id and status = 'in_progress'
  order by finish_at asc, started_at asc
  limit 1;

  if found then
    return v_quote || jsonb_build_object(
      'can_upgrade', false,
      'block_reason', 'active_upgrade',
      'active_upgrade_id', v_active.id,
      'active_building_kind', v_active.building_kind,
      'active_entity_id', v_active.entity_id,
      'active_finish_at', v_active.finish_at
    );
  end if;

  return v_quote;
end;
$function$;

revoke all on function public.get_building_upgrade_quote(text, uuid)
  from public, anon;
grant execute on function public.get_building_upgrade_quote(text, uuid)
  to authenticated;


-- Tax Lock System: Exceeding a level-based tax limit will freeze production and lock the game UI.

-- 1. Create a function to determine the tax limit based on the player's level
CREATE OR REPLACE FUNCTION public.get_player_tax_limit(p_level integer)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
begin
  if p_level <= 1 then return 10000;
  elsif p_level = 2 then return 25000;
  elsif p_level = 3 then return 50000;
  elsif p_level = 4 then return 100000;
  elsif p_level = 5 then return 250000;
  elsif p_level = 6 then return 500000;
  elsif p_level = 7 then return 1000000;
  else return p_level * 200000;
  end if;
end;
$$;

-- 2. Create a function to check if the player is tax blocked
CREATE OR REPLACE FUNCTION public.is_player_tax_blocked(p_player_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_tax_debt numeric;
  v_level integer;
  v_limit numeric;
begin
  if p_player_id is null then
    return false;
  end if;

  select coalesce(tax_debt, 0) into v_tax_debt
  from public.player_taxes
  where player_id = p_player_id;

  if v_tax_debt <= 0 then
    return false;
  end if;

  select coalesce(level, 1) into v_level
  from public.players
  where id = p_player_id;

  v_limit := public.get_player_tax_limit(v_level);

  return v_tax_debt > v_limit;
end;
$$;

-- 3. Create a function to get detailed tax status for the client
CREATE OR REPLACE FUNCTION public.get_player_tax_status()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_player_id uuid := auth.uid();
  v_tax_debt numeric := 0;
  v_level integer := 1;
  v_limit numeric := 0;
  v_is_blocked boolean := false;
begin
  if v_player_id is null then
    return jsonb_build_object(
      'tax_debt', 0,
      'tax_limit', 0,
      'is_blocked', false
    );
  end if;

  select coalesce(tax_debt, 0) into v_tax_debt
  from public.player_taxes
  where player_id = v_player_id;

  select coalesce(level, 1) into v_level
  from public.players
  where id = v_player_id;

  v_limit := public.get_player_tax_limit(v_level);
  v_is_blocked := v_tax_debt > v_limit;

  return jsonb_build_object(
    'tax_debt', v_tax_debt,
    'tax_limit', v_limit,
    'is_blocked', v_is_blocked
  );
end;
$$;

-- 4. Redefine process_player_production_entry to freeze production if tax blocked
CREATE OR REPLACE FUNCTION public.process_player_production_entry(p_player_id uuid DEFAULT auth.uid(), p_owner_kind text DEFAULT NULL::text, p_owner_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_boosts_result jsonb := jsonb_build_object('success', true, 'completed_count', 0);
  v_upgrades_result jsonb := jsonb_build_object('success', true, 'completed_count', 0);
  v_factory_result jsonb := jsonb_build_object('success', true, 'processed_count', 0, 'produced_count', 0, 'pending_only_count', 0, 'skipped_count', 0, 'total_produced', 0);
  v_field_farm_result jsonb := jsonb_build_object('success', true, 'processed_count', 0, 'produced_count', 0, 'pending_only_count', 0, 'skipped_count', 0, 'total_produced', 0);
  v_mine_result jsonb := jsonb_build_object('success', true, 'processed_count', 0, 'produced_count', 0, 'pending_only_count', 0, 'skipped_count', 0, 'total_produced', 0);
begin
  if p_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  -- Tax Block Check: If the player is tax blocked, freeze their production calculations!
  if public.is_player_tax_blocked(p_player_id) then
    return jsonb_build_object(
      'success', false,
      'tax_blocked', true,
      'message', 'Vergi borcu limiti asildigi icin uretim donduruldu.'
    );
  end if;

  if p_owner_kind is null then
    v_boosts_result := public.complete_due_building_boosts(100);
    v_upgrades_result := public.complete_due_building_upgrades(100);
  elsif p_owner_id is not null then
    if exists (
      select 1
      from public.building_upgrades bu
      where bu.player_id = p_player_id
        and bu.building_kind = p_owner_kind
        and bu.entity_id = p_owner_id
        and bu.status = 'in_progress'
        and bu.finish_at <= timezone('utc'::text, now())
    ) then
      v_upgrades_result := public.complete_due_building_upgrades(100);
    end if;
  end if;

  if p_owner_kind is null or p_owner_kind = 'factory' then
    v_factory_result := public.process_factory_production_entry(
      p_player_id,
      case when p_owner_kind = 'factory' then p_owner_id else null end
    );
  end if;

  if p_owner_kind is null or p_owner_kind in ('field', 'farm') then
    v_field_farm_result := public.process_field_farm_production_entry(
      p_player_id,
      case when p_owner_kind in ('field', 'farm') then p_owner_kind else null end,
      case when p_owner_kind in ('field', 'farm') then p_owner_id else null end
    );
  end if;

  if p_owner_kind is null or p_owner_kind = 'mine' then
    v_mine_result := public.process_mine_production_entry(
      p_player_id,
      case when p_owner_kind = 'mine' then p_owner_id else null end
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'completed_due_building_boosts', case
      when p_owner_kind is null then v_boosts_result
      else jsonb_build_object('success', true, 'completed_count', 0, 'skipped', true)
    end,
    'completed_due_building_upgrades', v_upgrades_result,
    'factory', v_factory_result,
    'field_farm', v_field_farm_result,
    'mine', v_mine_result
  );
end;
$function$;

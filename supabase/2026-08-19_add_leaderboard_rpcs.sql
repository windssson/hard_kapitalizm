-- ==============================================================================
-- Migration: 2026-08-19_add_leaderboard_rpcs.sql
-- Description: Adds get_leaderboard and get_player_leaderboard_rank_info RPCs
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.get_leaderboard(
  p_sort_by_field text DEFAULT 'company_value',
  p_limit integer DEFAULT 100
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_sql text;
  v_sort_col text;
  v_result jsonb;
BEGIN
  v_sort_col := CASE lower(trim(coalesce(p_sort_by_field, 'company_value')))
    WHEN 'company_value' THEN 'company_value'
    WHEN 'level' THEN 'level'
    WHEN 'achievement_unlocked_count' THEN 'achievement_unlocked_count'
    WHEN 'cash' THEN 'cash'
    WHEN 'gold' THEN 'gold'
    WHEN 'experience' THEN 'experience'
    WHEN 'business_value' THEN 'business_value'
    WHEN 'inventory_value' THEN 'inventory_value'
    WHEN 'vehicle_value' THEN 'vehicle_value'
    ELSE 'company_value'
  END;

  v_sql := format(
    'SELECT coalesce(jsonb_agg(to_jsonb(t)), ''[]''::jsonb)
     FROM (
       SELECT 
         player_id,
         player_name,
         company_name,
         avatar_id,
         level,
         experience,
         cash,
         gold,
         company_value,
         business_value,
         inventory_value,
         vehicle_value,
         building_base_value,
         building_upgrade_value,
         warehouse_inventory_value,
         store_inventory_value,
         production_inventory_value,
         achievement_unlocked_count,
         achievement_total_count,
         created_at,
         updated_at
       FROM public.player_leaderboard_stats
       ORDER BY %I DESC NULLS LAST, level DESC, player_name ASC
       LIMIT %L
     ) t',
    v_sort_col,
    coalesce(p_limit, 100)
  );

  EXECUTE v_sql INTO v_result;

  RETURN coalesce(v_result, '[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_player_leaderboard_rank_info(
  p_player_id uuid,
  p_sort_by_field text DEFAULT 'company_value'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_sort_col text;
  v_sql text;
  v_rank bigint;
  v_entry jsonb;
BEGIN
  -- Oyuncunun güncel verisini yenile
  PERFORM public.refresh_player_leaderboard_stats(p_player_id);

  v_sort_col := CASE lower(trim(coalesce(p_sort_by_field, 'company_value')))
    WHEN 'company_value' THEN 'company_value'
    WHEN 'level' THEN 'level'
    WHEN 'achievement_unlocked_count' THEN 'achievement_unlocked_count'
    WHEN 'cash' THEN 'cash'
    WHEN 'gold' THEN 'gold'
    WHEN 'experience' THEN 'experience'
    WHEN 'business_value' THEN 'business_value'
    WHEN 'inventory_value' THEN 'inventory_value'
    WHEN 'vehicle_value' THEN 'vehicle_value'
    ELSE 'company_value'
  END;

  v_sql := format(
    'WITH ranked AS (
       SELECT 
         player_id,
         row_number() OVER (ORDER BY %I DESC NULLS LAST, level DESC, player_name ASC) as rank_pos,
         to_jsonb(pls) as entry_data
       FROM public.player_leaderboard_stats pls
     )
     SELECT rank_pos, entry_data
     FROM ranked
     WHERE player_id = %L',
    v_sort_col,
    p_player_id
  );

  EXECUTE v_sql INTO v_rank, v_entry;

  IF v_rank IS NULL THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'rank', v_rank,
    'entry', v_entry
  );
END;
$$;

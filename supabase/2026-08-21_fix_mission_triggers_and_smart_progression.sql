-- 2026-08-21: Mission System Rigorous Fixes & Logistics Transfer Trigger
-- 1. Add handle_logistics_transfer_mission_progress trigger for logistics_transfers.
-- 2. Deactivate legacy achievement rows in mission_definitions.
-- 3. Enhance sync_player_mission_snapshot so existing infrastructure (store, warehouse, field, farm, factory, mine, arge)
--    validates the currently active main mission immediately without forcing players to re-build.
-- 4. Clean up and verify all event handlers.

-- 1. LOGISTICS TRANSFER TRIGGER
CREATE OR REPLACE FUNCTION public.handle_logistics_transfer_mission_progress()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
begin
  if tg_op = 'UPDATE'
     and new.status = 'completed'
     and coalesce(old.status, '') <> 'completed' then
    if new.buyer_player_id is not null then
      perform public.increment_player_mission_progress(new.buyer_player_id, 'logistics_transfer_completed', 1);
      perform public.increment_player_achievement_progress(new.buyer_player_id, 'logistics_transfer_completed', 1);
    end if;
  end if;

  return new;
end;
$function$;

DROP TRIGGER IF EXISTS trg_logistics_transfers_mission_progress ON public.logistics_transfers;
CREATE TRIGGER trg_logistics_transfers_mission_progress
AFTER UPDATE ON public.logistics_transfers
FOR EACH ROW
EXECUTE FUNCTION public.handle_logistics_transfer_mission_progress();

-- 2. DEACTIVATE LEGACY ROWS IN MISSION_DEFINITIONS
UPDATE public.mission_definitions
SET is_active = false
WHERE mission_type IN ('achievement', 'side');

-- 3. SMART SNAPSHOT SYNC WITH ASSET VALIDATION FOR MAIN & DAILY & WEEKLY MISSIONS
CREATE OR REPLACE FUNCTION public.sync_player_mission_snapshot(p_player_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
declare
  v_now timestamptz := timezone('utc', now());
  v_today date := timezone('Europe/Istanbul', now())::date;
  v_week_start date := date_trunc('week', timezone('Europe/Istanbul', now()))::date;
begin
  if p_player_id is null then
    return;
  end if;

  perform public.ensure_player_mission_rows(p_player_id);

  with mission_counts as (
    -- Building ownership counts (All-time existing assets)
    select 'building_construction_completed_store'::text as event_key, 'all'::text as period_kind, count(*)::int as current_count
    from public.stores where player_id = p_player_id

    union all
    select 'building_construction_completed_warehouse', 'all', count(*)::int
    from public.warehouses where player_id = p_player_id

    union all
    select 'building_construction_completed_field', 'all', count(*)::int
    from public.fields where player_id = p_player_id

    union all
    select 'building_construction_completed_farm', 'all', count(*)::int
    from public.farms where player_id = p_player_id

    union all
    select 'building_construction_completed_factory', 'all', count(*)::int
    from public.factories where player_id = p_player_id

    union all
    select 'building_construction_completed_mine', 'all', count(*)::int
    from public.mines where player_id = p_player_id

    union all
    select 'building_construction_completed', 'all', count(*)::int
    from public.building_constructions where player_id = p_player_id and status = 'complete'

    union all
    select 'building_upgrade_completed', 'all', count(*)::int
    from public.building_upgrades where player_id = p_player_id and status = 'completed'

    union all
    select 'arge_research_completed', 'all', count(*)::int
    from public.arge_researches where player_id = p_player_id and status = 'completed'

    -- Daily stats
    union all
    select 'building_upgrade_completed', 'daily', count(*)::int
    from public.building_upgrades where player_id = p_player_id and status = 'completed' and completed_at::date = v_today

    union all
    select 'store_sale_completed', 'daily', coalesce(sum(sold_quantity), 0)::int
    from public.store_daily_performance where player_id = p_player_id and performance_date = v_today

    union all
    select 'product_produced', 'daily', coalesce(sum(produced_quantity), 0)::int
    from public.player_daily_production_stats where player_id = p_player_id and production_date = v_today

    union all
    select 'logistics_transfer_completed', 'daily', count(*)::int
    from public.logistics_transfers where status = 'completed' and p_player_id in (buyer_player_id, seller_player_id) and completed_at::date = v_today

    -- Weekly stats
    union all
    select 'store_sale_completed', 'weekly', coalesce(sum(sold_quantity), 0)::int
    from public.store_daily_performance where player_id = p_player_id and performance_date >= v_week_start

    union all
    select 'product_produced', 'weekly', coalesce(sum(produced_quantity), 0)::int
    from public.player_daily_production_stats where player_id = p_player_id and production_date >= v_week_start

    union all
    select 'logistics_transfer_completed', 'weekly', count(*)::int
    from public.logistics_transfers where status = 'completed' and p_player_id in (buyer_player_id, seller_player_id) and completed_at::date >= v_week_start

    union all
    select 'arge_research_completed', 'weekly', count(*)::int
    from public.arge_researches where player_id = p_player_id and status = 'completed' and completed_at::date >= v_week_start
  )
  update public.player_missions pm
  set
    progress_count = greatest(pm.progress_count, least(md.target_count, mc.current_count)),
    is_completed = pm.is_completed or mc.current_count >= md.target_count,
    completed_at = case
      when pm.is_completed = false and mc.current_count >= md.target_count and pm.completed_at is null then v_now
      else pm.completed_at
    end,
    updated_at = case
      when greatest(pm.progress_count, least(md.target_count, mc.current_count)) <> pm.progress_count
        or (pm.is_completed = false and mc.current_count >= md.target_count)
      then v_now
      else pm.updated_at
    end
  from public.mission_definitions md
  join mission_counts mc
    on mc.event_key = md.event_key
   and mc.period_kind = case
      when md.mission_type = 'daily' then 'daily'
      when md.mission_type = 'weekly' then 'weekly'
      else 'all'
    end
  where pm.player_id = p_player_id
    and pm.mission_id = md.id
    and pm.is_claimed = false
    and md.is_active = true
    -- Ana görevlerde sadece yapı/bina/AR-GE sahiplikleri geriye dönük taranır.
    -- Satış, üretim ve transfer hedefleri ise aktif aşamada oynanarak tamamlanır.
    and (
      md.mission_type in ('daily', 'weekly')
      or (
        md.mission_type = 'main'
        and md.event_key in (
          'building_construction_completed_store',
          'building_construction_completed_warehouse',
          'building_construction_completed_field',
          'building_construction_completed_farm',
          'building_construction_completed_factory',
          'building_construction_completed_mine',
          'arge_research_completed'
        )
        and (
          md.required_mission_id is null
          or exists (
            select 1 from public.player_missions req
            where req.player_id = p_player_id
              and req.mission_id = md.required_mission_id
              and req.is_claimed = true
          )
        )
      )
    );
end;
$function$;

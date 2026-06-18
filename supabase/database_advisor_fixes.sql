-- ====================================================================
-- 1. RLS OPTİMİZASYONU (Auth RLS Initialization Plan)
-- ====================================================================

-- logistics_finance_entries
DROP POLICY IF EXISTS "Players can view their own logistics finance entries" ON public.logistics_finance_entries;
CREATE POLICY "Players can view their own logistics finance entries" ON public.logistics_finance_entries
  FOR SELECT TO authenticated USING (player_id = (SELECT auth.uid()));

-- player_daily_production_stats
DROP POLICY IF EXISTS "player_daily_production_stats_select_own" ON public.player_daily_production_stats;
CREATE POLICY "player_daily_production_stats_select_own" ON public.player_daily_production_stats
  FOR SELECT TO authenticated USING (player_id = (SELECT auth.uid()));

-- player_leaderboard_stats (insert)
DROP POLICY IF EXISTS "player_leaderboard_stats_insert_own" ON public.player_leaderboard_stats;
CREATE POLICY "player_leaderboard_stats_insert_own" ON public.player_leaderboard_stats
  FOR INSERT TO authenticated WITH CHECK (player_id = (SELECT auth.uid()));

-- player_leaderboard_stats (update)
DROP POLICY IF EXISTS "player_leaderboard_stats_update_own" ON public.player_leaderboard_stats;
CREATE POLICY "player_leaderboard_stats_update_own" ON public.player_leaderboard_stats
  FOR UPDATE TO authenticated USING (player_id = (SELECT auth.uid())) WITH CHECK (player_id = (SELECT auth.uid()));


-- ====================================================================
-- 2. İNDEKSLENMEMİŞ YABANCI ANAHTARLAR (Unindexed Foreign Keys)
-- ====================================================================

CREATE INDEX IF NOT EXISTS idx_logistics_finance_entries_logistics_company_id ON public.logistics_finance_entries(logistics_company_id);
CREATE INDEX IF NOT EXISTS idx_logistics_finance_entries_related_transfer_id ON public.logistics_finance_entries(related_transfer_id);
CREATE INDEX IF NOT EXISTS idx_logistics_finance_entries_related_warehouse_slot_id ON public.logistics_finance_entries(related_warehouse_slot_id);
CREATE INDEX IF NOT EXISTS idx_logistics_finance_entries_vehicle_id ON public.logistics_finance_entries(vehicle_id);


-- ====================================================================
-- 3. KULLANILMAYAN İNDEKSLERİN KALDIRILMASI (Unused Indexes)
-- ====================================================================

DROP INDEX IF EXISTS public.idx_achievement_definitions_active_order;
DROP INDEX IF EXISTS public.idx_logistics_transfers_buyer_warehouse_id;
DROP INDEX IF EXISTS public.idx_logistics_transfers_seller_warehouse_id;
DROP INDEX IF EXISTS public.idx_logistics_transfers_seller_warehouse_slot_id;
DROP INDEX IF EXISTS public.idx_player_missions_mission_id;
DROP INDEX IF EXISTS public.idx_player_product_quality_levels_product_id;
DROP INDEX IF EXISTS public.idx_store_daily_performance_store_slot_id;
DROP INDEX IF EXISTS public.idx_factories_factory_type_id;
DROP INDEX IF EXISTS public.idx_fields_active_output_capacity;
DROP INDEX IF EXISTS public.idx_farms_active_output_capacity;
DROP INDEX IF EXISTS public.idx_mines_mine_type_id;
DROP INDEX IF EXISTS public.idx_player_achievements_achievement_id;
DROP INDEX IF EXISTS public.idx_fields_city_id;
DROP INDEX IF EXISTS public.idx_fields_field_type_id;
DROP INDEX IF EXISTS public.idx_farms_farm_type_id;
DROP INDEX IF EXISTS public.idx_player_daily_production_stats_owner;
DROP INDEX IF EXISTS public.idx_warehouses_warehouse_type_id;
DROP INDEX IF EXISTS public.idx_player_leaderboard_stats_level_experience;
DROP INDEX IF EXISTS public.idx_logistics_vehicles_vehicle_type_id;
DROP INDEX IF EXISTS public.idx_logistics_vehicles_route_city_a_id;
DROP INDEX IF EXISTS public.idx_logistics_vehicles_route_city_b_id;
DROP INDEX IF EXISTS public.idx_player_experience_logs_player_created_at;
DROP INDEX IF EXISTS public.idx_building_upgrades_finish_at;
DROP INDEX IF EXISTS public.idx_building_boosts_finish_at;
DROP INDEX IF EXISTS public.idx_building_boosts_player_id;
DROP INDEX IF EXISTS public.idx_player_notifications_player_created;


-- ====================================================================
-- 4. GÜVENLİK/YETKİ DÜZENLEMELERİ (Security Definer Execute Permissions)
-- ====================================================================

-- Tüm public şemasındaki fonksiyonların PUBLIC ve anon yetkilerini revoke et
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon;

-- Arka planda/sistem tarafından çalışması gereken fonksiyonların yetkilerini authenticated rolünden de kaldır
REVOKE EXECUTE ON FUNCTION public.complete_due_warehouse_upgrades(integer) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.complete_due_building_boosts(integer) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.complete_due_building_constructions(integer) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.complete_due_building_upgrades(integer) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.complete_due_arge_researches() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.refresh_all_leaderboard_stats() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.refresh_player_leaderboard_stats(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.upsert_player_daily_production_stat(uuid, text, uuid, text, bigint, numeric, date) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.process_mine_production_entry(uuid, uuid, integer, integer) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.process_factory_production_entry(uuid, uuid, integer, integer) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.process_field_farm_production_entry(uuid, text, uuid, integer, integer) FROM authenticated;

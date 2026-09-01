-- =========================================================================================
-- MIGRATION: 2026-09-01_security_advisor_fixes.sql
-- 1. function_search_path_mutable (38 fonksiyon) için search_path = 'public' sabitlendi.
-- 2. anon rolü tamamen kilitlendi: Oyunda anonim oturum kaldırıldığı ve auth şart olduğu için
--    PUBLIC ve anon rollerinden tüm tablo ve fonksiyon yetkileri geri alındı.
-- 3. Eklentiler (pg_trgm, fuzzystrmatch) extensions şemasına taşındı.
-- 4. Yalnızca cron ve iç tetikleyicilere ait yardımcı fonksiyonların authenticated erişimi kapatıldı.
-- =========================================================================================

-- 1. SEARCH PATH SABİTLEME (38 Fonksiyon)
ALTER FUNCTION public.set_player_headquarters_city(p_city_id uuid) SET search_path = 'public';
ALTER FUNCTION public.ensure_player_record_exists(p_user_id uuid, p_city_id uuid) SET search_path = 'public';
ALTER FUNCTION public.get_active_marketing_campaigns() SET search_path = 'public';
ALTER FUNCTION public.update_product_market_stats() SET search_path = 'public';
ALTER FUNCTION public.get_market_listings_for_product(p_product_id text) SET search_path = 'public';
ALTER FUNCTION public.get_market_listings_for_player(p_player_id uuid) SET search_path = 'public';
ALTER FUNCTION public.add_production_slot(p_player_id uuid, p_owner_kind text, p_owner_id uuid) SET search_path = 'public';
ALTER FUNCTION public.process_factory_production_entry(p_player_id uuid, p_factory_id uuid, p_tick_minutes integer, p_max_ticks integer) SET search_path = 'public';
ALTER FUNCTION public.process_mine_production_entry(p_player_id uuid, p_mine_id uuid, p_tick_minutes integer, p_max_ticks integer) SET search_path = 'public';
ALTER FUNCTION public.get_tender_detail(p_tender_id uuid, p_player_tender_id uuid) SET search_path = 'public';
ALTER FUNCTION public.start_multi_production_to_warehouse_transfer(p_source_owner_kind text, p_source_owner_id uuid, p_buyer_warehouse_id uuid, p_items jsonb, p_vehicle_id uuid) SET search_path = 'public';
ALTER FUNCTION public.change_production_slot_product(p_player_id uuid, p_production_slot_id uuid, p_product_id text, p_quality_level integer) SET search_path = 'public';
ALTER FUNCTION public.start_multi_warehouse_to_production_transfer(p_source_warehouse_id uuid, p_items jsonb, p_vehicle_id uuid, p_production_inventory_id uuid) SET search_path = 'public';
ALTER FUNCTION public.sell_store(p_store_id uuid, p_confirm boolean) SET search_path = 'public';
ALTER FUNCTION public.ensure_npc_rental_vehicle(p_from_city_id uuid, p_to_city_id uuid, p_vehicle_type_id uuid) SET search_path = 'public';
ALTER FUNCTION public.repair_all_logistics_vehicles(p_player_id uuid) SET search_path = 'public';
ALTER FUNCTION public.claim_daily_streak_reward(p_reward_cash numeric, p_reward_gold numeric) SET search_path = 'public';
ALTER FUNCTION public.get_player_active_products_data(p_player_id uuid) SET search_path = 'public';
ALTER FUNCTION public.trim_chat_messages() SET search_path = 'public';
ALTER FUNCTION public.get_logistics_transfer_items(p_transfer_id uuid) SET search_path = 'public';
ALTER FUNCTION public.filter_profanity_text(p_text text) SET search_path = 'public';
ALTER FUNCTION public.get_npc_rental_vehicle_option(p_from_city_id uuid, p_to_city_id uuid, p_distance_km numeric) SET search_path = 'public';
ALTER FUNCTION public.complete_logistics_transfer_internal(p_transfer_id uuid, p_player_id uuid) SET search_path = 'public';
ALTER FUNCTION public.create_brand_company(p_brand_name text, p_logo_id text, p_theme_color text) SET search_path = 'public';
ALTER FUNCTION public.assign_production_slot_product(p_player_id uuid, p_production_slot_id uuid, p_product_id text, p_quality_level integer) SET search_path = 'public';
ALTER FUNCTION public.start_arge_center_construction(p_player_id uuid, p_name text) SET search_path = 'public';
ALTER FUNCTION public.sell_building(p_building_id uuid, p_building_kind text, p_confirm boolean) SET search_path = 'public';
ALTER FUNCTION public.shift_daily_product_prices() SET search_path = 'public';
ALTER FUNCTION public.complete_arge_research(p_research_id uuid) SET search_path = 'public';
ALTER FUNCTION public.fill_store_shelves(p_player_id uuid, p_store_id uuid) SET search_path = 'public';
ALTER FUNCTION public.discard_warehouse_slot(p_player_id uuid, p_warehouse_slot_id uuid) SET search_path = 'public';
ALTER FUNCTION public.start_arge_research(p_player_id uuid, p_product_id text) SET search_path = 'public';
ALTER FUNCTION public.transfer_store_slot_to_store_warehouse(p_player_id uuid, p_store_slot_id uuid, p_quantity integer) SET search_path = 'public';
ALTER FUNCTION public.patent_brand_company_product(p_product_id text) SET search_path = 'public';
ALTER FUNCTION public.start_marketing_campaign(p_campaign_type text) SET search_path = 'public';
ALTER FUNCTION public.start_multi_logistics_transfer(p_source_entity_kind text, p_source_entity_id uuid, p_target_entity_kind text, p_target_entity_id uuid, p_items jsonb, p_vehicle_id uuid) SET search_path = 'public';
ALTER FUNCTION public.unregister_push_token(p_token text) SET search_path = 'public';
ALTER FUNCTION public.get_player_profile(p_player_id uuid) SET search_path = 'public';

-- 2. ANON VE PUBLIC YETKİLERİNİN GERİ ALINMASI (REVOKE)
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE EXECUTE ON ALL PROCEDURES IN SCHEMA public FROM PUBLIC;
REVOKE EXECUTE ON ALL ROUTINES IN SCHEMA public FROM PUBLIC;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA public TO authenticated;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA public TO service_role;
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA public TO service_role;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON ROUTINES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON ROUTINES TO authenticated, service_role;

-- 3. EKLENTİLERİN EXTENSIONS ŞEMASINA ALINMASI
CREATE SCHEMA IF NOT EXISTS extensions;
ALTER EXTENSION pg_trgm SET SCHEMA extensions;
ALTER EXTENSION fuzzystrmatch SET SCHEMA extensions;

-- 4. İÇ VE CRON FONKSİYONLARININ AUTHENTICATED ERİŞİMİNİN KALDIRILMASI
REVOKE EXECUTE ON FUNCTION public.maintain_open_tenders() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.process_all_players_production() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.process_bank_ticks() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.record_daily_company_value_snapshots() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.refresh_all_leaderboard_stats() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.shift_daily_product_prices() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.update_product_market_stats() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.complete_due_arge_researches() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.complete_due_building_constructions(p_limit integer) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.complete_due_building_boosts(p_limit integer) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.complete_due_player_building_boosts(p_player_id uuid, p_limit integer) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.complete_due_player_building_upgrades(p_player_id uuid, p_limit integer, p_building_kind text, p_entity_id uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.complete_logistics_transfer_internal(p_transfer_id uuid, p_player_id uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.complete_player_tender(p_player_tender_id uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.consume_rewarded_ad_usage_v2(p_player_id uuid, p_reward_kind text, p_cooldown_seconds integer, p_daily_limit integer, p_metadata jsonb, p_resource_key text, p_resource_value text, p_resource_daily_limit integer) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.ensure_npc_logistics_account() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.ensure_npc_rental_vehicle(p_from_city_id uuid, p_to_city_id uuid, p_vehicle_type_id uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.ensure_open_tenders() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.ensure_player_achievement_rows(p_player_id uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.ensure_player_mission_rows(p_player_id uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.finish_building_boost(p_player_id uuid, p_boost_id uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.generate_open_tenders(p_target_open_count integer, p_max_generate integer) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_building_upgrade_quote_impl(p_building_kind text, p_entity_id uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_cities_catalog(p_only_active boolean) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_homepage_dashboard_summary(p_player_id uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_npc_logistics_player_id() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_player_hourly_income_estimate(p_player_id uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_player_tax_limit(p_level integer) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.grant_player_experience(p_player_id uuid, p_amount integer, p_reason text, p_meta jsonb) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_arge_research_mission_progress() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_building_construction_mission_progress() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_building_upgrade_mission_progress() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_logistics_transfer_mission_progress() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_production_mission_progress() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_store_sales_mission_progress() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.increment_player_achievement_progress(p_player_id uuid, p_event_key text, p_amount integer, p_meta jsonb) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.increment_player_mission_progress(p_player_id uuid, p_event_key text, p_amount integer, p_meta jsonb) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.is_player_tax_blocked(p_player_id uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.log_player_cash_change(p_player_id uuid, p_amount numeric, p_balance_before numeric, p_category text, p_note text, p_ref_id uuid, p_ref_kind text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.process_logistics_vehicle_rental_payout(p_vehicle_id uuid, p_transfer_id uuid, p_renter_player_id uuid, p_rental_cost numeric, p_distance_km numeric) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.process_player_production_core(p_player_id uuid, p_owner_kind text, p_owner_id uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.reset_player_daily_missions(p_player_id uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.reset_player_weekly_missions(p_player_id uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.sync_player_achievement_snapshot(p_player_id uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.sync_player_mission_snapshot(p_player_id uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.trim_chat_messages() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.upsert_player_daily_production_stat(p_player_id uuid, p_owner_kind text, p_owner_id uuid, p_product_id text, p_quantity bigint, p_total_cost numeric, p_production_date date) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.cleanup_database_bloat() FROM authenticated;

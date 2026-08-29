-- ============================================================================
-- Migration: Add missing foreign key covering indexes
-- Resolves Supabase Database Linter performance warnings for unindexed FKs.
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_fields_city_id ON public.fields(city_id);
CREATE INDEX IF NOT EXISTS idx_fields_field_type_id ON public.fields(field_type_id);
CREATE INDEX IF NOT EXISTS idx_mines_mine_type_id ON public.mines(mine_type_id);
CREATE INDEX IF NOT EXISTS idx_player_tenders_city_id ON public.player_tenders(city_id);
CREATE INDEX IF NOT EXISTS idx_player_tenders_product_id ON public.player_tenders(product_id);
CREATE INDEX IF NOT EXISTS idx_push_notification_logs_notification_id ON public.push_notification_logs(notification_id);
CREATE INDEX IF NOT EXISTS idx_tender_deliveries_vehicle_id ON public.tender_deliveries(vehicle_id);

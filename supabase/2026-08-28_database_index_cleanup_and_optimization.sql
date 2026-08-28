-- ============================================================================
-- Migration: Database Index Cleanup and Performance Optimization
-- 1. Drop unused redundant indexes to eliminate write amplification
-- 2. Add high-impact missing indexes to eliminate 130M+ sequential scan row reads
-- ============================================================================

-- 1. DROP UNUSED / REDUNDANT INDEXES
DROP INDEX IF EXISTS public.idx_production_inventory_field_farm_input;
DROP INDEX IF EXISTS public.idx_building_upgrades_due;
DROP INDEX IF EXISTS public.idx_building_upgrades_player_due;
DROP INDEX IF EXISTS public.idx_push_notification_logs_notification_id;
DROP INDEX IF EXISTS public.idx_player_tenders_deadline_status;
DROP INDEX IF EXISTS public.idx_player_tenders_city_id;
DROP INDEX IF EXISTS public.idx_player_tenders_product_id;
DROP INDEX IF EXISTS public.idx_mines_mine_type_id;
DROP INDEX IF EXISTS public.idx_fields_city_id;
DROP INDEX IF EXISTS public.idx_fields_field_type_id;
DROP INDEX IF EXISTS public.idx_tender_deliveries_vehicle_id;

-- 2. ADD MISSING CRITICAL PERFORMANCE INDEXES

-- A. Push Notification Queue: Eliminates 56,000+ seq scans and 133M row reads in cron job
CREATE INDEX IF NOT EXISTS idx_push_notification_queue_status_player
  ON public.push_notification_queue (status, player_id);

CREATE INDEX IF NOT EXISTS idx_push_notification_queue_pending_notification
  ON public.push_notification_queue (notification_id)
  WHERE status = 'pending';

-- B. Push Notification Logs: Speeds up anti-spam cooldown and deduplication checks
CREATE INDEX IF NOT EXISTS idx_push_notification_logs_player_sent_at
  ON public.push_notification_logs (player_id, sent_at DESC);

-- C. Player Notifications: Speeds up dashboard and notification list queries
CREATE INDEX IF NOT EXISTS idx_player_notifications_player_created
  ON public.player_notifications (player_id, created_at DESC);

-- D. Building Constructions: Eliminates 66,000+ seq scans on construction queries
CREATE INDEX IF NOT EXISTS idx_building_constructions_player_status
  ON public.building_constructions (player_id, status);

CREATE INDEX IF NOT EXISTS idx_building_constructions_status_finish
  ON public.building_constructions (status, finish_at);

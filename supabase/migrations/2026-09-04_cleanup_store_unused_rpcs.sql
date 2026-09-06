-- Migration: 2026-09-04_cleanup_store_unused_rpcs.sql
-- Description: Drop unused get_store_history_items RPC after removing store history UI

DROP FUNCTION IF EXISTS public.get_store_history_items(uuid);

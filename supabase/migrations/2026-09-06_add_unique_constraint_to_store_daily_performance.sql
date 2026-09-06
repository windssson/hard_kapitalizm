-- Migration: Add UNIQUE constraint on (performance_date, store_slot_id) to store_daily_performance
-- Fixes PostgreSQL error 42P10: there is no unique or exclusion constraint matching the ON CONFLICT specification
-- Date: 2026-09-06

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'store_daily_performance_date_slot_key'
      AND conrelid = 'public.store_daily_performance'::regclass
  ) THEN
    ALTER TABLE public.store_daily_performance 
    ADD CONSTRAINT store_daily_performance_date_slot_key 
    UNIQUE (performance_date, store_slot_id);
  END IF;
END $$;

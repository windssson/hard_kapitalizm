-- Create indexes for foreign keys without covering indexes to optimize lookup/join/delete performance

-- 1. Oyuncu tabloları (Player-owned entities)
CREATE INDEX IF NOT EXISTS idx_stores_player_id ON public.stores(player_id);
CREATE INDEX IF NOT EXISTS idx_warehouses_player_id ON public.warehouses(player_id);
CREATE INDEX IF NOT EXISTS idx_factories_player_id ON public.factories(player_id);
CREATE INDEX IF NOT EXISTS idx_farms_player_id ON public.farms(player_id);
CREATE INDEX IF NOT EXISTS idx_fields_player_id ON public.fields(player_id);
CREATE INDEX IF NOT EXISTS idx_mines_player_id ON public.mines(player_id);
CREATE INDEX IF NOT EXISTS idx_logistics_vehicles_player_id ON public.logistics_vehicles(player_id);

-- 2. Slot tabloları (Child slot entities)
CREATE INDEX IF NOT EXISTS idx_store_slots_store_id ON public.store_slots(store_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_slots_warehouse_id ON public.warehouse_slots(warehouse_id);

-- 3. Üretim slotları (Polymorphic parent owner_id & owner_kind)
CREATE INDEX IF NOT EXISTS idx_production_slots_owner_id_kind ON public.production_slots(owner_id, owner_kind);

-- 4. Transfer ve kalem tabloları (Logistics transfers & items)
CREATE INDEX IF NOT EXISTS idx_logistics_transfers_buyer_player_id ON public.logistics_transfers(buyer_player_id);
CREATE INDEX IF NOT EXISTS idx_logistics_transfers_seller_player_id ON public.logistics_transfers(seller_player_id);
CREATE INDEX IF NOT EXISTS idx_logistics_transfer_items_transfer_id ON public.logistics_transfer_items(transfer_id);

-- 5. Günlük performans ve geçmiş tabloları
CREATE INDEX IF NOT EXISTS idx_store_daily_performance_player_id_store_id ON public.store_daily_performance(player_id, store_id);
CREATE INDEX IF NOT EXISTS idx_player_experience_logs_player_id ON public.player_experience_logs(player_id);
CREATE INDEX IF NOT EXISTS idx_player_achievements_player_id ON public.player_achievements(player_id);

-- Create indexes for foreign keys without covering indexes to optimize join/delete performance

-- 1. Index for target_production_inventory_id on logistics_transfer_items
CREATE INDEX IF NOT EXISTS idx_logistics_transfer_items_target_prod_inv_id 
ON public.logistics_transfer_items(target_production_inventory_id);

-- 2. Index for required_mission_id on mission_definitions
CREATE INDEX IF NOT EXISTS idx_mission_definitions_required_mission_id 
ON public.mission_definitions(required_mission_id);

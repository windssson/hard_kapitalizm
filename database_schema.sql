-- ============================================================
-- HARD KAPİTALİZM - VERİTABANI ŞEMASI
-- Proje: kapitalizm (Supabase / PostgreSQL 17)
-- Dışa Aktarılma: 2026-05-23
-- ============================================================

-- Gerekli extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. TABLOLAR
-- ============================================================

CREATE TABLE IF NOT EXISTS public.arge_researches (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL,
  product_id text NOT NULL,
  product_name text NOT NULL,
  current_quality integer NOT NULL,
  target_quality integer NOT NULL,
  cost_paid numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'in_progress',
  started_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  finish_at timestamp with time zone NOT NULL,
  completed_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.building_constructions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL,
  building_kind text NOT NULL,
  params jsonb NOT NULL,
  status text NOT NULL DEFAULT 'in_progress',
  started_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  finish_at timestamp with time zone NOT NULL,
  completed_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS public.cities (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  population integer NOT NULL DEFAULT 0,
  tax_rate numeric NOT NULL DEFAULT 0,
  map_position_x numeric NOT NULL DEFAULT 0,
  map_position_y numeric NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.factories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL,
  factory_type_id uuid NOT NULL,
  city_id uuid NOT NULL,
  name text NOT NULL,
  level integer NOT NULL DEFAULT 1,
  product_id text,
  quality_level integer NOT NULL DEFAULT 0,
  input_capacity integer NOT NULL DEFAULT 0,
  output_capacity integer NOT NULL DEFAULT 0,
  boost_multiplier numeric NOT NULL DEFAULT 1.00,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.factory_types (
  id uuid NOT NULL,
  name text,
  icon text,
  accepted_product_ids text,
  cost integer,
  required_level integer,
  construction_time_minutes integer,
  created_at timestamp with time zone,
  input_capacity integer,
  output_capacity integer
);

CREATE TABLE IF NOT EXISTS public.farm_types (
  id uuid NOT NULL,
  name text,
  icon text,
  accepted_product_ids text,
  cost integer,
  required_level integer,
  construction_time_minutes integer,
  input_capacity integer,
  output_capacity integer DEFAULT 0,
  max_slot_count integer DEFAULT 5
);

CREATE TABLE IF NOT EXISTS public.farms (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL,
  farm_type_id uuid NOT NULL,
  city_id uuid NOT NULL,
  name text NOT NULL,
  level integer NOT NULL DEFAULT 1,
  current_slot_count integer NOT NULL DEFAULT 0,
  max_slot_count integer NOT NULL DEFAULT 0,
  input_capacity integer NOT NULL DEFAULT 0,
  output_capacity integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.field_types (
  id uuid NOT NULL,
  name text,
  icon text,
  accepted_product_ids text,
  cost integer,
  required_level integer,
  construction_time_minutes integer,
  created_at timestamp with time zone,
  input_capacity integer,
  output_capacity integer,
  slot_capacity integer,
  max_slot_count integer DEFAULT 5
);

CREATE TABLE IF NOT EXISTS public.fields (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL,
  field_type_id uuid NOT NULL,
  city_id uuid NOT NULL,
  name text NOT NULL,
  level integer NOT NULL DEFAULT 1,
  current_slot_count integer NOT NULL DEFAULT 0,
  max_slot_count integer NOT NULL DEFAULT 0,
  input_capacity integer NOT NULL DEFAULT 0,
  output_capacity integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.logistics_companies (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL,
  city_id uuid,
  name text NOT NULL,
  level integer NOT NULL DEFAULT 1,
  current_vehicle_count integer NOT NULL DEFAULT 0,
  max_vehicle_count integer NOT NULL DEFAULT 0,
  fuel_capacity integer NOT NULL DEFAULT 0,
  current_fuel integer NOT NULL DEFAULT 0,
  fuel_cost numeric NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.logistics_company_types (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  cost integer NOT NULL DEFAULT 0,
  required_level integer NOT NULL DEFAULT 1,
  construction_time_minutes integer NOT NULL DEFAULT 0,
  max_vehicle_count integer NOT NULL DEFAULT 0,
  fuel_capacity integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.logistics_transfers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  buyer_player_id uuid NOT NULL,
  seller_player_id uuid NOT NULL,
  buyer_warehouse_id uuid,
  seller_warehouse_id uuid,
  seller_warehouse_slot_id uuid,
  logistics_vehicle_id uuid,
  vehicle_owner_player_id uuid,
  is_rental boolean NOT NULL DEFAULT false,
  product_id text NOT NULL,
  quality_level integer NOT NULL,
  quantity integer NOT NULL,
  unit_price numeric NOT NULL,
  total_price numeric NOT NULL,
  product_unit_volume numeric NOT NULL,
  reserved_capacity_amount numeric NOT NULL,
  distance_km numeric NOT NULL,
  fuel_used numeric NOT NULL,
  condition_loss numeric NOT NULL,
  rental_cost numeric NOT NULL DEFAULT 0,
  transport_cost numeric NOT NULL DEFAULT 0,
  started_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  finish_at timestamp with time zone NOT NULL,
  completed_at timestamp with time zone,
  status text NOT NULL DEFAULT 'in_transit',
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  buyer_store_id uuid,
  buyer_store_slot_id uuid,
  transfer_type text NOT NULL DEFAULT 'market_to_warehouse',
  seller_store_id uuid,
  seller_store_slot_id uuid,
  seller_entity_kind text,
  buyer_entity_kind text,
  seller_production_inventory_id uuid,
  buyer_production_inventory_id uuid
);

CREATE TABLE IF NOT EXISTS public.logistics_vehicle_types (
  id uuid NOT NULL,
  name text,
  type text,
  description text,
  capacity integer,
  speed_kmh integer,
  fuel_capacity integer,
  fuel_rate numeric,
  purchase_price integer,
  icon text,
  created_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS public.logistics_vehicles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL,
  logistics_company_id uuid NOT NULL,
  logistics_vehicle_type_id uuid NOT NULL,
  capacity integer NOT NULL DEFAULT 0,
  speed_kmh integer NOT NULL DEFAULT 0,
  fuel_capacity integer NOT NULL DEFAULT 0,
  current_fuel integer NOT NULL DEFAULT 0,
  fuel_rate numeric NOT NULL DEFAULT 0,
  condition integer NOT NULL DEFAULT 100,
  status text NOT NULL DEFAULT 'idle',
  is_available_for_rent boolean NOT NULL DEFAULT false,
  rental_price numeric NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  route_city_a_id uuid,
  route_city_b_id uuid
);

CREATE TABLE IF NOT EXISTS public.mine_types (
  id uuid NOT NULL,
  name text,
  icon text,
  accepted_product_ids text,
  cost integer,
  required_level integer,
  construction_time_minutes integer,
  created_at timestamp with time zone,
  output_capacity integer
);

CREATE TABLE IF NOT EXISTS public.mines (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL,
  mine_type_id uuid NOT NULL,
  city_id uuid NOT NULL,
  name text NOT NULL,
  level integer NOT NULL DEFAULT 1,
  product_id text,
  quality_level integer NOT NULL DEFAULT 0,
  output_capacity integer NOT NULL DEFAULT 0,
  boost_multiplier numeric NOT NULL DEFAULT 1.00,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.player_product_quality_levels (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL,
  product_id text NOT NULL,
  max_quality_level integer NOT NULL DEFAULT 1,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.players (
  id uuid NOT NULL,
  company_name text NOT NULL DEFAULT 'Yeni Holding',
  avatar_id text NOT NULL DEFAULT 'avatar_1.webp',
  level integer NOT NULL DEFAULT 1,
  experience integer NOT NULL DEFAULT 0,
  cash numeric NOT NULL DEFAULT 100000,
  gold numeric NOT NULL DEFAULT 100,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  player_name text NOT NULL DEFAULT 'Oyuncu'
);

CREATE TABLE IF NOT EXISTS public.production_inventory (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  owner_kind text NOT NULL,
  owner_id uuid NOT NULL,
  inventory_type text NOT NULL,
  product_id text NOT NULL,
  quality_level integer NOT NULL,
  quantity integer NOT NULL DEFAULT 0,
  pending_quantity numeric NOT NULL DEFAULT 0,
  cost numeric NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.production_slots (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  owner_kind text NOT NULL,
  owner_id uuid NOT NULL,
  slot_index integer NOT NULL,
  product_id text,
  quality_level integer NOT NULL DEFAULT 0,
  boost_multiplier numeric NOT NULL DEFAULT 1.00,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.products (
  id text NOT NULL,
  urun_adi text,
  urun_iconu text,
  birim_hacim numeric,
  birim_agirlik numeric,
  hammadde_1_id text,
  hammadde_1_miktar numeric,
  hammadde_2_id text,
  hammadde_2_miktar numeric,
  hammadde_3_id text,
  hammadde_3_miktar numeric,
  uretim_birimi text,
  baz_satis_fiyati numeric,
  uretim_adedi integer,
  satis_adedi integer,
  en_dusuk_fiyat numeric,
  en_yuksek_fiyat numeric,
  ortalama_fiyat numeric,
  satici_sayisi integer,
  created_at timestamp with time zone,
  piyasadaki_stok integer
);

CREATE TABLE IF NOT EXISTS public.store_daily_performance (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  performance_date date NOT NULL,
  player_id uuid NOT NULL,
  store_id uuid NOT NULL,
  store_slot_id uuid NOT NULL,
  slot_index integer NOT NULL,
  product_id text,
  product_name text,
  quality_level integer NOT NULL DEFAULT 0,
  sold_quantity integer NOT NULL DEFAULT 0,
  revenue numeric NOT NULL DEFAULT 0,
  profit numeric NOT NULL DEFAULT 0,
  sale_event_count integer NOT NULL DEFAULT 0,
  last_sale_at timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.store_slots (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL,
  slot_index integer NOT NULL,
  product_id text,
  quantity integer NOT NULL DEFAULT 0,
  quality_level integer NOT NULL DEFAULT 0,
  price numeric NOT NULL DEFAULT 0,
  cost numeric NOT NULL DEFAULT 0,
  boost_multiplier numeric NOT NULL DEFAULT 1.00,
  pending_sale numeric NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  capacity integer NOT NULL DEFAULT 0,
  last_sale_processed_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  pending_quantity integer NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.store_types (
  id uuid NOT NULL,
  name text,
  icon text,
  accepted_product_ids text,
  cost integer,
  required_level integer,
  created_at timestamp with time zone,
  base_slot_count integer,
  construction_time_minutes integer,
  max_slot_count integer,
  slot_capacity integer
);

CREATE TABLE IF NOT EXISTS public.stores (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL,
  store_type_id uuid NOT NULL,
  city_id uuid NOT NULL,
  name text NOT NULL,
  level integer NOT NULL DEFAULT 1,
  current_slot_count integer NOT NULL DEFAULT 0,
  max_slot_count integer NOT NULL DEFAULT 0,
  slot_capacity integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now())
);

CREATE TABLE IF NOT EXISTS public.warehouse_slots (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  warehouse_id uuid NOT NULL,
  slot_index integer NOT NULL,
  product_id text,
  quality_level integer NOT NULL DEFAULT 0,
  quantity integer NOT NULL DEFAULT 0,
  cost numeric NOT NULL DEFAULT 0,
  is_available_for_sale boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  price numeric NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.warehouse_types (
  id uuid NOT NULL,
  name text,
  icon text,
  accepted_production_units text,
  base_capacity integer,
  cost integer,
  required_level integer,
  construction_time_minutes integer,
  accepted_product_ids text,
  max_slot_count integer
);

CREATE TABLE IF NOT EXISTS public.warehouses (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL,
  warehouse_type_id uuid NOT NULL,
  city_id uuid NOT NULL,
  name text NOT NULL,
  level integer NOT NULL DEFAULT 1,
  capacity numeric NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc', now()),
  reserved_capacity numeric NOT NULL DEFAULT 0
);

-- ============================================================
-- 2. PRIMARY KEY KISITLAMALARI
-- ============================================================

ALTER TABLE public.arge_researches ADD CONSTRAINT arge_researches_pkey PRIMARY KEY (id);
ALTER TABLE public.building_constructions ADD CONSTRAINT building_constructions_pkey PRIMARY KEY (id);
ALTER TABLE public.cities ADD CONSTRAINT cities_pkey PRIMARY KEY (id);
ALTER TABLE public.factories ADD CONSTRAINT factories_pkey PRIMARY KEY (id);
ALTER TABLE public.factory_types ADD CONSTRAINT fabrika_types_pkey PRIMARY KEY (id);
ALTER TABLE public.farm_types ADD CONSTRAINT farm_types_pkey PRIMARY KEY (id);
ALTER TABLE public.farms ADD CONSTRAINT farms_pkey PRIMARY KEY (id);
ALTER TABLE public.field_types ADD CONSTRAINT ciftlik_types_pkey PRIMARY KEY (id);
ALTER TABLE public.fields ADD CONSTRAINT fields_pkey PRIMARY KEY (id);
ALTER TABLE public.logistics_companies ADD CONSTRAINT logistics_companies_pkey PRIMARY KEY (id);
ALTER TABLE public.logistics_company_types ADD CONSTRAINT logistics_company_types_pkey PRIMARY KEY (id);
ALTER TABLE public.logistics_transfers ADD CONSTRAINT logistics_transfers_pkey PRIMARY KEY (id);
ALTER TABLE public.logistics_vehicle_types ADD CONSTRAINT logistics_vehicle_types_pkey PRIMARY KEY (id);
ALTER TABLE public.logistics_vehicles ADD CONSTRAINT logistics_vehicles_pkey PRIMARY KEY (id);
ALTER TABLE public.mine_types ADD CONSTRAINT maden_types_pkey PRIMARY KEY (id);
ALTER TABLE public.mines ADD CONSTRAINT mines_pkey PRIMARY KEY (id);
ALTER TABLE public.player_product_quality_levels ADD CONSTRAINT player_product_quality_levels_pkey PRIMARY KEY (id);
ALTER TABLE public.players ADD CONSTRAINT players_pkey PRIMARY KEY (id);
ALTER TABLE public.production_inventory ADD CONSTRAINT production_inventory_pkey PRIMARY KEY (id);
ALTER TABLE public.production_slots ADD CONSTRAINT production_slots_pkey PRIMARY KEY (id);
ALTER TABLE public.products ADD CONSTRAINT products_pkey PRIMARY KEY (id);
ALTER TABLE public.store_daily_performance ADD CONSTRAINT store_daily_performance_pkey PRIMARY KEY (id);
ALTER TABLE public.store_slots ADD CONSTRAINT store_slots_pkey PRIMARY KEY (id);
ALTER TABLE public.store_types ADD CONSTRAINT store_types_pkey PRIMARY KEY (id);
ALTER TABLE public.stores ADD CONSTRAINT stores_pkey PRIMARY KEY (id);
ALTER TABLE public.warehouse_slots ADD CONSTRAINT warehouse_slots_pkey PRIMARY KEY (id);
ALTER TABLE public.warehouse_types ADD CONSTRAINT warehouse_types_pkey PRIMARY KEY (id);
ALTER TABLE public.warehouses ADD CONSTRAINT warehouses_pkey PRIMARY KEY (id);

-- ============================================================
-- 3. FOREIGN KEY KISITLAMALARI
-- ============================================================

ALTER TABLE public.arge_researches ADD CONSTRAINT arge_researches_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id);
ALTER TABLE public.building_constructions ADD CONSTRAINT building_constructions_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id);
ALTER TABLE public.factories ADD CONSTRAINT factories_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id);
ALTER TABLE public.factories ADD CONSTRAINT factories_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
ALTER TABLE public.factories ADD CONSTRAINT factories_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id);
ALTER TABLE public.factories ADD CONSTRAINT factories_factory_type_id_fkey FOREIGN KEY (factory_type_id) REFERENCES public.factory_types(id);
ALTER TABLE public.farms ADD CONSTRAINT farms_farm_type_id_fkey FOREIGN KEY (farm_type_id) REFERENCES public.farm_types(id);
ALTER TABLE public.farms ADD CONSTRAINT farms_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id);
ALTER TABLE public.farms ADD CONSTRAINT farms_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id);
ALTER TABLE public.fields ADD CONSTRAINT fields_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id);
ALTER TABLE public.fields ADD CONSTRAINT fields_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id);
ALTER TABLE public.fields ADD CONSTRAINT fields_field_type_id_fkey FOREIGN KEY (field_type_id) REFERENCES public.field_types(id);
ALTER TABLE public.logistics_companies ADD CONSTRAINT logistics_companies_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id);
ALTER TABLE public.logistics_companies ADD CONSTRAINT logistics_companies_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id);
ALTER TABLE public.logistics_transfers ADD CONSTRAINT logistics_transfers_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
ALTER TABLE public.logistics_transfers ADD CONSTRAINT logistics_transfers_buyer_player_id_fkey FOREIGN KEY (buyer_player_id) REFERENCES public.players(id);
ALTER TABLE public.logistics_transfers ADD CONSTRAINT logistics_transfers_seller_player_id_fkey FOREIGN KEY (seller_player_id) REFERENCES public.players(id);
ALTER TABLE public.logistics_transfers ADD CONSTRAINT logistics_transfers_buyer_warehouse_id_fkey FOREIGN KEY (buyer_warehouse_id) REFERENCES public.warehouses(id);
ALTER TABLE public.logistics_transfers ADD CONSTRAINT logistics_transfers_seller_warehouse_id_fkey FOREIGN KEY (seller_warehouse_id) REFERENCES public.warehouses(id);
ALTER TABLE public.logistics_transfers ADD CONSTRAINT logistics_transfers_seller_warehouse_slot_id_fkey FOREIGN KEY (seller_warehouse_slot_id) REFERENCES public.warehouse_slots(id);
ALTER TABLE public.logistics_transfers ADD CONSTRAINT logistics_transfers_logistics_vehicle_id_fkey FOREIGN KEY (logistics_vehicle_id) REFERENCES public.logistics_vehicles(id);
ALTER TABLE public.logistics_transfers ADD CONSTRAINT logistics_transfers_vehicle_owner_player_id_fkey FOREIGN KEY (vehicle_owner_player_id) REFERENCES public.players(id);
ALTER TABLE public.logistics_transfers ADD CONSTRAINT logistics_transfers_buyer_store_id_fkey FOREIGN KEY (buyer_store_id) REFERENCES public.stores(id);
ALTER TABLE public.logistics_transfers ADD CONSTRAINT logistics_transfers_buyer_store_slot_id_fkey FOREIGN KEY (buyer_store_slot_id) REFERENCES public.store_slots(id);
ALTER TABLE public.logistics_transfers ADD CONSTRAINT logistics_transfers_seller_store_id_fkey FOREIGN KEY (seller_store_id) REFERENCES public.stores(id);
ALTER TABLE public.logistics_transfers ADD CONSTRAINT logistics_transfers_seller_store_slot_id_fkey FOREIGN KEY (seller_store_slot_id) REFERENCES public.store_slots(id);
ALTER TABLE public.logistics_transfers ADD CONSTRAINT logistics_transfers_seller_production_inventory_fk FOREIGN KEY (seller_production_inventory_id) REFERENCES public.production_inventory(id);
ALTER TABLE public.logistics_transfers ADD CONSTRAINT logistics_transfers_buyer_production_inventory_fk FOREIGN KEY (buyer_production_inventory_id) REFERENCES public.production_inventory(id);
ALTER TABLE public.logistics_vehicles ADD CONSTRAINT logistics_vehicles_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id);
ALTER TABLE public.logistics_vehicles ADD CONSTRAINT logistics_vehicles_route_city_a_id_fkey FOREIGN KEY (route_city_a_id) REFERENCES public.cities(id);
ALTER TABLE public.logistics_vehicles ADD CONSTRAINT logistics_vehicles_logistics_company_id_fkey FOREIGN KEY (logistics_company_id) REFERENCES public.logistics_companies(id);
ALTER TABLE public.logistics_vehicles ADD CONSTRAINT logistics_vehicles_logistics_vehicle_type_id_fkey FOREIGN KEY (logistics_vehicle_type_id) REFERENCES public.logistics_vehicle_types(id);
ALTER TABLE public.logistics_vehicles ADD CONSTRAINT logistics_vehicles_route_city_b_id_fkey FOREIGN KEY (route_city_b_id) REFERENCES public.cities(id);
ALTER TABLE public.mines ADD CONSTRAINT mines_mine_type_id_fkey FOREIGN KEY (mine_type_id) REFERENCES public.mine_types(id);
ALTER TABLE public.mines ADD CONSTRAINT mines_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id);
ALTER TABLE public.mines ADD CONSTRAINT mines_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id);
ALTER TABLE public.mines ADD CONSTRAINT mines_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
ALTER TABLE public.player_product_quality_levels ADD CONSTRAINT player_product_quality_levels_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id);
ALTER TABLE public.player_product_quality_levels ADD CONSTRAINT player_product_quality_levels_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
ALTER TABLE public.production_inventory ADD CONSTRAINT production_inventory_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
ALTER TABLE public.production_slots ADD CONSTRAINT production_slots_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
ALTER TABLE public.store_daily_performance ADD CONSTRAINT store_daily_performance_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id);
ALTER TABLE public.store_daily_performance ADD CONSTRAINT store_daily_performance_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id);
ALTER TABLE public.store_daily_performance ADD CONSTRAINT store_daily_performance_store_slot_id_fkey FOREIGN KEY (store_slot_id) REFERENCES public.store_slots(id);
ALTER TABLE public.store_slots ADD CONSTRAINT store_slots_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
ALTER TABLE public.store_slots ADD CONSTRAINT store_slots_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id);
ALTER TABLE public.stores ADD CONSTRAINT stores_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id);
ALTER TABLE public.stores ADD CONSTRAINT stores_store_type_id_fkey FOREIGN KEY (store_type_id) REFERENCES public.store_types(id);
ALTER TABLE public.stores ADD CONSTRAINT stores_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id);
ALTER TABLE public.warehouse_slots ADD CONSTRAINT warehouse_slots_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouses(id);
ALTER TABLE public.warehouse_slots ADD CONSTRAINT warehouse_slots_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id);
ALTER TABLE public.warehouses ADD CONSTRAINT warehouses_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id);
ALTER TABLE public.warehouses ADD CONSTRAINT warehouses_warehouse_type_id_fkey FOREIGN KEY (warehouse_type_id) REFERENCES public.warehouse_types(id);
ALTER TABLE public.warehouses ADD CONSTRAINT warehouses_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id);

-- ============================================================
-- 4. İNDEXLER
-- ============================================================


CREATE INDEX IF NOT EXISTS idx_arge_researches_player_id ON public.arge_researches USING btree (player_id);
CREATE INDEX IF NOT EXISTS idx_arge_researches_status ON public.arge_researches USING btree (status);
CREATE INDEX IF NOT EXISTS idx_building_constructions_finish_at ON public.building_constructions USING btree (finish_at);
CREATE INDEX IF NOT EXISTS idx_building_constructions_player_id ON public.building_constructions USING btree (player_id);
CREATE INDEX IF NOT EXISTS idx_building_constructions_status ON public.building_constructions USING btree (status);
CREATE INDEX IF NOT EXISTS idx_factories_city_id ON public.factories USING btree (city_id);
CREATE INDEX IF NOT EXISTS idx_factories_factory_type_id ON public.factories USING btree (factory_type_id);
CREATE INDEX IF NOT EXISTS idx_factories_player_id ON public.factories USING btree (player_id);
CREATE INDEX IF NOT EXISTS idx_factories_product_id ON public.factories USING btree (product_id);
CREATE INDEX IF NOT EXISTS idx_farms_city_id ON public.farms USING btree (city_id);
CREATE INDEX IF NOT EXISTS idx_farms_farm_type_id ON public.farms USING btree (farm_type_id);
CREATE INDEX IF NOT EXISTS idx_farms_player_id ON public.farms USING btree (player_id);
CREATE INDEX IF NOT EXISTS idx_fields_city_id ON public.fields USING btree (city_id);
CREATE INDEX IF NOT EXISTS idx_fields_field_type_id ON public.fields USING btree (field_type_id);
CREATE INDEX IF NOT EXISTS idx_fields_player_id ON public.fields USING btree (player_id);
CREATE INDEX IF NOT EXISTS idx_logistics_companies_city_id ON public.logistics_companies USING btree (city_id);
CREATE INDEX IF NOT EXISTS idx_logistics_companies_player_id ON public.logistics_companies USING btree (player_id);
CREATE INDEX IF NOT EXISTS idx_logistics_transfers_buyer_player_id ON public.logistics_transfers USING btree (buyer_player_id);
CREATE INDEX IF NOT EXISTS idx_logistics_transfers_buyer_store_id ON public.logistics_transfers USING btree (buyer_store_id);
CREATE INDEX IF NOT EXISTS idx_logistics_transfers_buyer_warehouse_id ON public.logistics_transfers USING btree (buyer_warehouse_id);
CREATE INDEX IF NOT EXISTS idx_logistics_transfers_finish_at ON public.logistics_transfers USING btree (finish_at);
CREATE INDEX IF NOT EXISTS idx_logistics_transfers_seller_player_id ON public.logistics_transfers USING btree (seller_player_id);
CREATE INDEX IF NOT EXISTS idx_logistics_transfers_seller_warehouse_id ON public.logistics_transfers USING btree (seller_warehouse_id);
CREATE INDEX IF NOT EXISTS idx_logistics_transfers_status ON public.logistics_transfers USING btree (status);
CREATE INDEX IF NOT EXISTS idx_logistics_transfers_vehicle_id ON public.logistics_transfers USING btree (logistics_vehicle_id);
CREATE INDEX IF NOT EXISTS idx_logistics_vehicles_company_id ON public.logistics_vehicles USING btree (logistics_company_id);
CREATE INDEX IF NOT EXISTS idx_logistics_vehicles_player_id ON public.logistics_vehicles USING btree (player_id);
CREATE INDEX IF NOT EXISTS idx_logistics_vehicles_route_city_a_id ON public.logistics_vehicles USING btree (route_city_a_id);
CREATE INDEX IF NOT EXISTS idx_logistics_vehicles_route_city_b_id ON public.logistics_vehicles USING btree (route_city_b_id);
CREATE INDEX IF NOT EXISTS idx_logistics_vehicles_status ON public.logistics_vehicles USING btree (status);
CREATE INDEX IF NOT EXISTS idx_logistics_vehicles_vehicle_type_id ON public.logistics_vehicles USING btree (logistics_vehicle_type_id);
CREATE INDEX IF NOT EXISTS idx_mines_active_product ON public.mines USING btree (id, product_id, quality_level) WHERE ((is_active = true) AND (product_id IS NOT NULL));
CREATE INDEX IF NOT EXISTS idx_mines_city_id ON public.mines USING btree (city_id);
CREATE INDEX IF NOT EXISTS idx_mines_mine_type_id ON public.mines USING btree (mine_type_id);
CREATE INDEX IF NOT EXISTS idx_mines_player_id ON public.mines USING btree (player_id);
CREATE INDEX IF NOT EXISTS idx_mines_product_id ON public.mines USING btree (product_id);
CREATE UNIQUE INDEX IF NOT EXISTS player_product_quality_levels_unique ON public.player_product_quality_levels USING btree (player_id, product_id);
CREATE INDEX IF NOT EXISTS idx_production_inventory_field_farm_input ON public.production_inventory USING btree (owner_kind, owner_id, product_id, quality_level) WHERE ((owner_kind = ANY (ARRAY['field'::text, 'farm'::text])) AND (inventory_type = 'input'::text));
CREATE INDEX IF NOT EXISTS idx_production_inventory_field_farm_output ON public.production_inventory USING btree (owner_kind, owner_id, product_id, quality_level) WHERE ((owner_kind = ANY (ARRAY['field'::text, 'farm'::text])) AND (inventory_type = 'output'::text));
CREATE INDEX IF NOT EXISTS idx_production_inventory_mine_output_active ON public.production_inventory USING btree (owner_id, product_id, quality_level) WHERE ((owner_kind = 'mine'::text) AND (inventory_type = 'output'::text));
CREATE INDEX IF NOT EXISTS idx_production_inventory_owner ON public.production_inventory USING btree (owner_kind, owner_id);
CREATE INDEX IF NOT EXISTS idx_production_inventory_owner_inventory_type ON public.production_inventory USING btree (owner_kind, owner_id, inventory_type);
CREATE INDEX IF NOT EXISTS idx_production_inventory_product_id ON public.production_inventory USING btree (product_id);
CREATE UNIQUE INDEX IF NOT EXISTS production_inventory_unique_item ON public.production_inventory USING btree (owner_kind, owner_id, inventory_type, product_id, quality_level);
CREATE INDEX IF NOT EXISTS idx_production_slots_field_farm_active ON public.production_slots USING btree (owner_kind, owner_id, product_id, quality_level, slot_index) WHERE ((owner_kind = ANY (ARRAY['field'::text, 'farm'::text])) AND (is_active = true) AND (product_id IS NOT NULL));
CREATE INDEX IF NOT EXISTS idx_production_slots_owner ON public.production_slots USING btree (owner_kind, owner_id);
CREATE INDEX IF NOT EXISTS idx_production_slots_product_id ON public.production_slots USING btree (product_id);
CREATE UNIQUE INDEX IF NOT EXISTS production_slots_unique_slot_index ON public.production_slots USING btree (owner_kind, owner_id, slot_index);
CREATE INDEX IF NOT EXISTS idx_store_daily_performance_player_date ON public.store_daily_performance USING btree (player_id, performance_date DESC);
CREATE INDEX IF NOT EXISTS idx_store_daily_performance_store_date ON public.store_daily_performance USING btree (store_id, performance_date DESC);
CREATE UNIQUE INDEX IF NOT EXISTS store_daily_performance_performance_date_store_id_store_slo_key ON public.store_daily_performance USING btree (performance_date, store_id, store_slot_id);
CREATE INDEX IF NOT EXISTS idx_store_slots_product_id ON public.store_slots USING btree (product_id);
CREATE INDEX IF NOT EXISTS idx_store_slots_store_id ON public.store_slots USING btree (store_id);
CREATE UNIQUE INDEX IF NOT EXISTS store_slots_unique_slot_index ON public.store_slots USING btree (store_id, slot_index);
CREATE INDEX IF NOT EXISTS idx_stores_city_id ON public.stores USING btree (city_id);
CREATE INDEX IF NOT EXISTS idx_stores_player_id ON public.stores USING btree (player_id);
CREATE INDEX IF NOT EXISTS idx_stores_store_type_id ON public.stores USING btree (store_type_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_slots_product_id ON public.warehouse_slots USING btree (product_id);
CREATE INDEX IF NOT EXISTS idx_warehouse_slots_warehouse_id ON public.warehouse_slots USING btree (warehouse_id);
CREATE UNIQUE INDEX IF NOT EXISTS warehouse_slots_unique_slot_index ON public.warehouse_slots USING btree (warehouse_id, slot_index);
CREATE INDEX IF NOT EXISTS idx_warehouses_city_id ON public.warehouses USING btree (city_id);
CREATE INDEX IF NOT EXISTS idx_warehouses_player_id ON public.warehouses USING btree (player_id);
CREATE INDEX IF NOT EXISTS idx_warehouses_warehouse_type_id ON public.warehouses USING btree (warehouse_type_id);

-- ============================================================
-- 5. ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Tüm tablolarda RLS etkinleştirilmiştir
ALTER TABLE public.arge_researches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.building_constructions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.factories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.factory_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.farm_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.farms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.field_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fields ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logistics_companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logistics_company_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logistics_transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logistics_vehicle_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logistics_vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mine_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_product_quality_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.production_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.production_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_daily_performance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 6. FONKSIYONLAR (Toplam: 106 adet)
-- ============================================================

CREATE OR REPLACE FUNCTION public.add_product_to_warehouse(p_player_id uuid, p_warehouse_id uuid, p_product_id text, p_quality_level integer, p_quantity integer, p_cost numeric, p_transport_cost numeric DEFAULT 0, p_release_reserved_capacity boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_warehouse record;
  v_product record;
  v_existing_slot record;

  v_used_capacity numeric := 0;
  v_incoming_capacity numeric := 0;
  v_available_capacity numeric := 0;

  v_new_slot_index integer;
  v_slot_id uuid;

  v_new_quantity integer;
  v_new_cost numeric;

  v_reserved_before numeric := 0;
  v_reserved_after numeric := 0;
  v_released_reserved_capacity numeric := 0;

  v_transport_unit_cost numeric := 0;
  v_effective_unit_cost numeric := 0;
begin
  if p_product_id is null or length(trim(p_product_id)) = 0 then
    raise exception 'Ürün id boş olamaz.';
  end if;

  if p_quality_level < 1 or p_quality_level > 5 then
    raise exception 'Kalite seviyesi 1 ile 5 arasında olmalıdır.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Eklenecek miktar 0''dan büyük olmalıdır.';
  end if;

  if p_cost is null or p_cost < 0 then
    raise exception 'Ürün maliyeti 0 veya daha büyük olmalıdır.';
  end if;

  if p_transport_cost is null or p_transport_cost < 0 then
    raise exception 'Nakliye maliyeti 0 veya daha büyük olmalıdır.';
  end if;

  v_transport_unit_cost := p_transport_cost / p_quantity;
  v_effective_unit_cost := p_cost + v_transport_unit_cost;

  -- Depoyu kilitle
  select *
  into v_warehouse
  from public.warehouses
  where id = p_warehouse_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'Depo bulunamadı veya oyuncuya ait değil.';
  end if;

  -- Ürün bilgisi
  select *
  into v_product
  from public.products
  where id = p_product_id;

  if not found then
    raise exception 'Ürün bulunamadı.';
  end if;

  if v_product.birim_hacim is null or v_product.birim_hacim <= 0 then
    raise exception 'Ürünün birim_hacim değeri geçerli değil.';
  end if;

  v_incoming_capacity := p_quantity * v_product.birim_hacim;
  v_reserved_before := coalesce(v_warehouse.reserved_capacity, 0);

  -- Mevcut kullanılan kapasite
  select coalesce(sum(ws.quantity * p.birim_hacim), 0)
  into v_used_capacity
  from public.warehouse_slots ws
  join public.products p on p.id = ws.product_id
  where ws.warehouse_id = p_warehouse_id;

  -- Rezervsiz eklemede boş kapasite kontrolü
  if p_release_reserved_capacity = false then
    v_available_capacity :=
      coalesce(v_warehouse.capacity, 0)
      - v_used_capacity
      - v_reserved_before;

    if v_incoming_capacity > v_available_capacity then
      raise exception 'Depo kapasitesi yetersiz. Boş kapasite: %, Eklenecek hacim: %',
        v_available_capacity,
        v_incoming_capacity;
    end if;
  else
    -- Transfer tamamlanıyorsa, alan önceden rezerve edilmiş kabul edilir
    if v_used_capacity + v_incoming_capacity > coalesce(v_warehouse.capacity, 0) then
      raise exception 'Depo kapasitesi yetersiz. Kullanılan hacim: %, Eklenecek hacim: %, Kapasite: %',
        v_used_capacity,
        v_incoming_capacity,
        v_warehouse.capacity;
    end if;
  end if;

  -- Aynı ürün + kalite slotu var mı?
  select *
  into v_existing_slot
  from public.warehouse_slots
  where warehouse_id = p_warehouse_id
    and product_id = p_product_id
    and quality_level = p_quality_level
  for update;

  if found then
    v_slot_id := v_existing_slot.id;
    v_new_quantity := v_existing_slot.quantity + p_quantity;

    v_new_cost :=
      (
        (v_existing_slot.quantity * v_existing_slot.cost)
        +
        (p_quantity * v_effective_unit_cost)
      )
      / v_new_quantity;

    update public.warehouse_slots
    set
      quantity = v_new_quantity,
      cost = v_new_cost,
      updated_at = timezone('utc'::text, now())
    where id = v_existing_slot.id;

  else
    select coalesce(max(slot_index), 0) + 1
    into v_new_slot_index
    from public.warehouse_slots
    where warehouse_id = p_warehouse_id;

    insert into public.warehouse_slots (
      warehouse_id,
      slot_index,
      product_id,
      quality_level,
      quantity,
      cost,
      is_available_for_sale
    )
    values (
      p_warehouse_id,
      v_new_slot_index,
      p_product_id,
      p_quality_level,
      p_quantity,
      v_effective_unit_cost,
      false
    )
    returning id into v_slot_id;

    v_new_quantity := p_quantity;
    v_new_cost := v_effective_unit_cost;
  end if;

  -- Transferden geldiyse rezerv kapasiteyi düş
  if p_release_reserved_capacity = true then
    v_released_reserved_capacity := least(v_reserved_before, v_incoming_capacity);
    v_reserved_after := greatest(v_reserved_before - v_incoming_capacity, 0);

    update public.warehouses
    set
      reserved_capacity = v_reserved_after,
      updated_at = timezone('utc'::text, now())
    where id = p_warehouse_id;
  else
    v_released_reserved_capacity := 0;
    v_reserved_after := v_reserved_before;

    update public.warehouses
    set updated_at = timezone('utc'::text, now())
    where id = p_warehouse_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'warehouse_id', p_warehouse_id,
    'warehouse_slot_id', v_slot_id,
    'product_id', p_product_id,
    'quality_level', p_quality_level,
    'added_quantity', p_quantity,
    'base_unit_cost', p_cost,
    'transport_cost', p_transport_cost,
    'transport_unit_cost', v_transport_unit_cost,
    'effective_unit_cost', v_effective_unit_cost,
    'unit_volume', v_product.birim_hacim,
    'added_capacity', v_incoming_capacity,
    'quantity_after', v_new_quantity,
    'cost_after', v_new_cost,
    'reserved_capacity_before', v_reserved_before,
    'released_reserved_capacity', v_released_reserved_capacity,
    'reserved_capacity_after', v_reserved_after
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.add_production_slot(p_player_id uuid, p_owner_kind text, p_owner_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_owner record;
  v_new_slot_index integer;
  v_slot_id uuid;
  v_current_slot_count integer;
  v_max_slot_count integer;
begin
  if p_owner_kind not in ('field', 'farm') then
    raise exception 'Geçersiz owner_kind. Sadece field veya farm olabilir. Gelen: %',
      p_owner_kind;
  end if;

  -- FIELD
  if p_owner_kind = 'field' then

    select *
    into v_owner
    from public.fields
    where id = p_owner_id
      and player_id = p_player_id
    for update;

    if not found then
      raise exception 'Tarla bulunamadı veya oyuncuya ait değil.';
    end if;

    v_current_slot_count := v_owner.current_slot_count;
    v_max_slot_count := v_owner.max_slot_count;

    if v_current_slot_count >= v_max_slot_count then
      raise exception 'Tarlada açılabilecek maksimum üretim slotu sayısına ulaşıldı. Mevcut: %, Maksimum: %',
        v_current_slot_count,
        v_max_slot_count;
    end if;

  -- FARM
  elsif p_owner_kind = 'farm' then

    select *
    into v_owner
    from public.farms
    where id = p_owner_id
      and player_id = p_player_id
    for update;

    if not found then
      raise exception 'Çiftlik bulunamadı veya oyuncuya ait değil.';
    end if;

    v_current_slot_count := v_owner.current_slot_count;
    v_max_slot_count := v_owner.max_slot_count;

    if v_current_slot_count >= v_max_slot_count then
      raise exception 'Çiftlikte açılabilecek maksimum üretim slotu sayısına ulaşıldı. Mevcut: %, Maksimum: %',
        v_current_slot_count,
        v_max_slot_count;
    end if;

  end if;

  -- Yeni slot index hesapla
  select coalesce(max(slot_index), 0) + 1
  into v_new_slot_index
  from public.production_slots
  where owner_kind = p_owner_kind
    and owner_id = p_owner_id;

  -- Boş üretim slotu oluştur
  insert into public.production_slots (
    owner_kind,
    owner_id,
    slot_index,
    product_id,
    quality_level,
    boost_multiplier,
    is_active
  )
  values (
    p_owner_kind,
    p_owner_id,
    v_new_slot_index,
    null,
    0,
    1.00,
    true
  )
  returning id into v_slot_id;

  -- Sayaç güncelle
  if p_owner_kind = 'field' then

    update public.fields
    set
      current_slot_count = current_slot_count + 1,
      updated_at = timezone('utc'::text, now())
    where id = p_owner_id;

  elsif p_owner_kind = 'farm' then

    update public.farms
    set
      current_slot_count = current_slot_count + 1,
      updated_at = timezone('utc'::text, now())
    where id = p_owner_id;

  end if;

  return jsonb_build_object(
    'success', true,
    'production_slot_id', v_slot_id,
    'owner_kind', p_owner_kind,
    'owner_id', p_owner_id,
    'slot_index', v_new_slot_index,
    'current_slot_count', v_current_slot_count + 1,
    'max_slot_count', v_max_slot_count
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.add_store_slot(p_player_id uuid, p_store_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_store record;
  v_new_slot_index integer;
  v_slot_id uuid;
begin
  -- Mağazayı kilitleyerek al
  select *
  into v_store
  from public.stores
  where id = p_store_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'Mağaza bulunamadı veya oyuncuya ait değil.';
  end if;

  -- Slot sınırı kontrolü
  if v_store.current_slot_count >= v_store.max_slot_count then
    raise exception 'Mağazada açılabilecek maksimum slot sayısına ulaşıldı. Mevcut: %, Maksimum: %',
      v_store.current_slot_count,
      v_store.max_slot_count;
  end if;

  -- Yeni slot index hesapla
  select coalesce(max(slot_index), 0) + 1
  into v_new_slot_index
  from public.store_slots
  where store_id = p_store_id;

  -- Boş slot oluştur
  insert into public.store_slots (
    store_id,
    slot_index,
    product_id,
    quantity,
    quality_level,
    price,
    cost,
    capacity,
    boost_multiplier,
    pending_sale,
    is_active
  )
  values (
    p_store_id,
    v_new_slot_index,
    null,
    0,
    0,
    0,
    0,
    coalesce(v_store.slot_capacity, 0),
    1.00,
    0,
    true
  )
  returning id into v_slot_id;

  -- Mağazanın slot sayısını artır
  update public.stores
  set
    current_slot_count = current_slot_count + 1,
    updated_at = timezone('utc'::text, now())
  where id = p_store_id;

  return jsonb_build_object(
    'success', true,
    'store_id', p_store_id,
    'slot_id', v_slot_id,
    'slot_index', v_new_slot_index,
    'capacity', coalesce(v_store.slot_capacity, 0),
    'current_slot_count', v_store.current_slot_count + 1,
    'max_slot_count', v_store.max_slot_count
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.assign_production_slot_product(p_player_id uuid, p_production_slot_id uuid, p_product_id text, p_quality_level integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_slot public.production_slots%rowtype;
  v_product public.products%rowtype;

  v_owner_player_id uuid;
  v_owner_type_id uuid;
  v_accepted_product_ids text;
  v_product_unit text;

  v_max_quality integer;
  v_duplicate_slot_index integer;

  v_created_input_count integer := 0;
  v_created_output_count integer := 0;

  v_hammadde_1_id text;
  v_hammadde_2_id text;
  v_hammadde_3_id text;

  v_hammadde_1_miktar numeric;
  v_hammadde_2_miktar numeric;
  v_hammadde_3_miktar numeric;

  v_input_quality_level integer := 1;
  v_inventory_id uuid;
  v_output_inventory_id uuid;
begin
  perform pg_advisory_xact_lock(hashtext('field_farm_production_lock'));

  if p_quality_level is null or p_quality_level < 1 or p_quality_level > 5 then
    raise exception 'Kalite seviyesi 1 ile 5 arasinda olmalidir.';
  end if;

  select *
  into v_slot
  from public.production_slots
  where id = p_production_slot_id
  for update;

  if not found then
    raise exception 'Uretim slotu bulunamadi.';
  end if;

  if coalesce(v_slot.product_id, '') <> '' and coalesce(v_slot.quality_level, 0) > 0 then
    raise exception 'Bu slotta zaten urun var. Urun degistirme akisini kullan.';
  end if;

  if v_slot.owner_kind not in ('field', 'farm') then
    raise exception 'Gecersiz production slot owner_kind: %', v_slot.owner_kind;
  end if;

  if v_slot.owner_kind = 'field' then
    select f.player_id, f.field_type_id, ft.accepted_product_ids
    into v_owner_player_id, v_owner_type_id, v_accepted_product_ids
    from public.fields f
    join public.field_types ft on ft.id = f.field_type_id
    where f.id = v_slot.owner_id;
  elsif v_slot.owner_kind = 'farm' then
    select fa.player_id, fa.farm_type_id, ft.accepted_product_ids
    into v_owner_player_id, v_owner_type_id, v_accepted_product_ids
    from public.farms fa
    join public.farm_types ft on ft.id = fa.farm_type_id
    where fa.id = v_slot.owner_id;
  end if;

  if v_owner_player_id is null then
    raise exception 'Uretim slotunun bagli oldugu yapi bulunamadi.';
  end if;

  if v_owner_player_id <> p_player_id then
    raise exception 'Bu uretim slotu oyuncuya ait degil.';
  end if;

  select *
  into v_product
  from public.products
  where id = p_product_id;

  if not found then
    raise exception 'Urun bulunamadi: %', p_product_id;
  end if;

  v_product_unit := lower(trim(coalesce(v_product.uretim_birimi, '')));

  if v_slot.owner_kind = 'field'
     and v_product_unit not in ('farm', 'ciftlik', 'çiftlik') then
    raise exception 'Bu urun ciftlik urunu degil: %', p_product_id;
  end if;

  if v_slot.owner_kind = 'farm'
     and v_product_unit not in ('field', 'tarla') then
    raise exception 'Bu urun tarla urunu degil: %', p_product_id;
  end if;

  if v_accepted_product_ids is null
     or not (p_product_id = any(regexp_split_to_array(v_accepted_product_ids, '\s*,\s*'))) then
    raise exception 'Bu yapi turu bu urunu uretemez: %', p_product_id;
  end if;

  select ps.slot_index
  into v_duplicate_slot_index
  from public.production_slots ps
  where ps.owner_kind = v_slot.owner_kind
    and ps.owner_id = v_slot.owner_id
    and ps.id <> v_slot.id
    and ps.product_id = p_product_id
  limit 1;

  if v_duplicate_slot_index is not null then
    raise exception 'Ayni uretim biriminde ayni urun yalnizca tek slotta uretilebilir. Urun zaten slot % uzerinde ayarli.', v_duplicate_slot_index;
  end if;

  select coalesce(max(max_quality_level), 1)
  into v_max_quality
  from public.player_product_quality_levels
  where player_id = p_player_id
    and product_id = p_product_id;

  if v_max_quality is null then
    v_max_quality := 1;
  end if;

  if p_quality_level > v_max_quality then
    raise exception 'Oyuncu bu urun icin kalite % seviyesine ulasmadi. Mevcut maksimum kalite: %', p_quality_level, v_max_quality;
  end if;

  update public.production_slots
  set product_id = p_product_id,
      quality_level = p_quality_level,
      updated_at = timezone('utc'::text, now())
  where id = p_production_slot_id;

  v_hammadde_1_id := nullif(v_product.hammadde_1_id, '');
  v_hammadde_2_id := nullif(v_product.hammadde_2_id, '');
  v_hammadde_3_id := nullif(v_product.hammadde_3_id, '');

  v_hammadde_1_miktar := coalesce(v_product.hammadde_1_miktar, 0);
  v_hammadde_2_miktar := coalesce(v_product.hammadde_2_miktar, 0);
  v_hammadde_3_miktar := coalesce(v_product.hammadde_3_miktar, 0);

  if v_hammadde_1_id is not null and v_hammadde_1_miktar > 0 then
    select id into v_inventory_id
    from public.production_inventory
    where owner_kind = v_slot.owner_kind
      and owner_id = v_slot.owner_id
      and inventory_type = 'input'
      and product_id = v_hammadde_1_id
      and quality_level = v_input_quality_level;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, quantity, pending_quantity, cost
      ) values (
        v_slot.owner_kind, v_slot.owner_id, 'input', v_hammadde_1_id, v_input_quality_level, 0, 0, 0
      );
      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  if v_hammadde_2_id is not null and v_hammadde_2_miktar > 0 then
    select id into v_inventory_id
    from public.production_inventory
    where owner_kind = v_slot.owner_kind
      and owner_id = v_slot.owner_id
      and inventory_type = 'input'
      and product_id = v_hammadde_2_id
      and quality_level = v_input_quality_level;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, quantity, pending_quantity, cost
      ) values (
        v_slot.owner_kind, v_slot.owner_id, 'input', v_hammadde_2_id, v_input_quality_level, 0, 0, 0
      );
      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  if v_hammadde_3_id is not null and v_hammadde_3_miktar > 0 then
    select id into v_inventory_id
    from public.production_inventory
    where owner_kind = v_slot.owner_kind
      and owner_id = v_slot.owner_id
      and inventory_type = 'input'
      and product_id = v_hammadde_3_id
      and quality_level = v_input_quality_level;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, quantity, pending_quantity, cost
      ) values (
        v_slot.owner_kind, v_slot.owner_id, 'input', v_hammadde_3_id, v_input_quality_level, 0, 0, 0
      );
      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  select id into v_output_inventory_id
  from public.production_inventory
  where owner_kind = v_slot.owner_kind
    and owner_id = v_slot.owner_id
    and inventory_type = 'output'
    and product_id = p_product_id
    and quality_level = p_quality_level;

  if not found then
    insert into public.production_inventory (
      owner_kind, owner_id, inventory_type, product_id, quality_level, quantity, pending_quantity, cost
    ) values (
      v_slot.owner_kind, v_slot.owner_id, 'output', p_product_id, p_quality_level, 0, 0, 0
    ) returning id into v_output_inventory_id;
    v_created_output_count := 1;
  end if;

  return jsonb_build_object(
    'success', true,
    'mode', 'assign',
    'production_slot_id', p_production_slot_id,
    'owner_kind', v_slot.owner_kind,
    'owner_id', v_slot.owner_id,
    'owner_type_id', v_owner_type_id,
    'product_id', p_product_id,
    'product_name', v_product.urun_adi,
    'quality_level', p_quality_level,
    'input_quality_level', v_input_quality_level,
    'player_max_quality_level', v_max_quality,
    'created_input_count', v_created_input_count,
    'created_output_count', v_created_output_count,
    'output_inventory_id', v_output_inventory_id
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.cancel_building_construction(p_player_id uuid, p_construction_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_construction record;
  v_now timestamptz := timezone('utc'::text, now());

  v_cost numeric := 0;
  v_refund_rate numeric := 0.50;
  v_refund_amount numeric := 0;
  v_new_cash numeric := 0;
begin
  -- İnşaat kaydını kilitleyerek al
  select *
  into v_construction
  from public.building_constructions
  where id = p_construction_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'İnşaat kaydı bulunamadı.';
  end if;

  if v_construction.status <> 'in_progress' then
    raise exception 'Sadece devam eden inşaatlar iptal edilebilir. Mevcut durum: %',
      v_construction.status;
  end if;

  -- Cost params içinden alınır
  v_cost := coalesce((v_construction.params->>'cost')::numeric, 0);

  -- %50 iade
  v_refund_amount := floor(v_cost * v_refund_rate);

  -- Oyuncuya iade yap
  update public.players
  set cash = cash + v_refund_amount
  where id = p_player_id
  returning cash into v_new_cash;

  -- İnşaatı iptal et
  update public.building_constructions
  set
    status = 'cancelled',
    completed_at = v_now
  where id = p_construction_id;

  return jsonb_build_object(
    'success', true,
    'construction_id', p_construction_id,
    'building_kind', v_construction.building_kind,
    'status', 'cancelled',
    'cancelled_at', v_now,
    'original_cost', v_cost,
    'refund_rate', v_refund_rate,
    'refund_amount', v_refund_amount,
    'current_cash', v_new_cash
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.change_production_slot_product(p_player_id uuid, p_production_slot_id uuid, p_product_id text, p_quality_level integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_slot public.production_slots%rowtype;
  v_product public.products%rowtype;

  v_owner_player_id uuid;
  v_owner_type_id uuid;
  v_accepted_product_ids text;
  v_product_unit text;

  v_old_product_id text;
  v_old_quality_level integer;
  v_same_setting boolean;
  v_duplicate_slot_index integer;

  v_max_quality integer;
  v_existing_output_quantity integer := 0;
  v_cleared_output_pending numeric := 0;

  v_created_input_count integer := 0;
  v_created_output_count integer := 0;
  v_deleted_obsolete_count integer := 0;

  v_hammadde_1_id text;
  v_hammadde_2_id text;
  v_hammadde_3_id text;

  v_hammadde_1_miktar numeric;
  v_hammadde_2_miktar numeric;
  v_hammadde_3_miktar numeric;

  v_input_quality_level integer := 1;
  v_inventory_id uuid;
  v_output_inventory_id uuid;
begin
  perform pg_advisory_xact_lock(hashtext('field_farm_production_lock'));

  if p_quality_level is null or p_quality_level < 1 or p_quality_level > 5 then
    raise exception 'Kalite seviyesi 1 ile 5 arasinda olmalidir.';
  end if;

  select *
  into v_slot
  from public.production_slots
  where id = p_production_slot_id
  for update;

  if not found then
    raise exception 'Uretim slotu bulunamadi.';
  end if;

  if coalesce(v_slot.product_id, '') = '' or coalesce(v_slot.quality_level, 0) <= 0 then
    raise exception 'Bu slotta henuz urun yok. Ilk urun secme akisini kullan.';
  end if;

  if v_slot.owner_kind not in ('field', 'farm') then
    raise exception 'Gecersiz production slot owner_kind: %', v_slot.owner_kind;
  end if;

  v_old_product_id := v_slot.product_id;
  v_old_quality_level := v_slot.quality_level;

  if v_slot.owner_kind = 'field' then
    select f.player_id, f.field_type_id, ft.accepted_product_ids
    into v_owner_player_id, v_owner_type_id, v_accepted_product_ids
    from public.fields f
    join public.field_types ft on ft.id = f.field_type_id
    where f.id = v_slot.owner_id;
  elsif v_slot.owner_kind = 'farm' then
    select fa.player_id, fa.farm_type_id, ft.accepted_product_ids
    into v_owner_player_id, v_owner_type_id, v_accepted_product_ids
    from public.farms fa
    join public.farm_types ft on ft.id = fa.farm_type_id
    where fa.id = v_slot.owner_id;
  end if;

  if v_owner_player_id is null then
    raise exception 'Uretim slotunun bagli oldugu yapi bulunamadi.';
  end if;

  if v_owner_player_id <> p_player_id then
    raise exception 'Bu uretim slotu oyuncuya ait degil.';
  end if;

  select *
  into v_product
  from public.products
  where id = p_product_id;

  if not found then
    raise exception 'Urun bulunamadi: %', p_product_id;
  end if;

  v_product_unit := lower(trim(coalesce(v_product.uretim_birimi, '')));

  if v_slot.owner_kind = 'field'
     and v_product_unit not in ('farm', 'ciftlik', 'çiftlik') then
    raise exception 'Bu urun ciftlik urunu degil: %', p_product_id;
  end if;

  if v_slot.owner_kind = 'farm'
     and v_product_unit not in ('field', 'tarla') then
    raise exception 'Bu urun tarla urunu degil: %', p_product_id;
  end if;

  if v_accepted_product_ids is null
     or not (p_product_id = any(regexp_split_to_array(v_accepted_product_ids, '\s*,\s*'))) then
    raise exception 'Bu yapi turu bu urunu uretemez: %', p_product_id;
  end if;

  select ps.slot_index
  into v_duplicate_slot_index
  from public.production_slots ps
  where ps.owner_kind = v_slot.owner_kind
    and ps.owner_id = v_slot.owner_id
    and ps.id <> v_slot.id
    and ps.product_id = p_product_id
  limit 1;

  if v_duplicate_slot_index is not null then
    raise exception 'Ayni uretim biriminde ayni urun yalnizca tek slotta uretilebilir. Urun zaten slot % uzerinde ayarli.', v_duplicate_slot_index;
  end if;

  select coalesce(max(max_quality_level), 1)
  into v_max_quality
  from public.player_product_quality_levels
  where player_id = p_player_id
    and product_id = p_product_id;

  if v_max_quality is null then
    v_max_quality := 1;
  end if;

  if p_quality_level > v_max_quality then
    raise exception 'Oyuncu bu urun icin kalite % seviyesine ulasmadi. Mevcut maksimum kalite: %', p_quality_level, v_max_quality;
  end if;

  v_same_setting := v_old_product_id = p_product_id and v_old_quality_level = p_quality_level;

  if not v_same_setting then
    select coalesce(quantity, 0), coalesce(pending_quantity, 0)
    into v_existing_output_quantity, v_cleared_output_pending
    from public.production_inventory pi
    where pi.owner_kind = v_slot.owner_kind
      and pi.owner_id = v_slot.owner_id
      and pi.inventory_type = 'output'
      and pi.product_id = v_old_product_id
      and pi.quality_level = v_old_quality_level
    for update;

    if v_existing_output_quantity > 0 then
      raise exception 'Mevcut urunun output stogu var. Urun degistirmeden once bu urune ait outputu depoya aktar.';
    end if;

    if coalesce(v_cleared_output_pending, 0) > 0 then
      update public.production_inventory pi
      set pending_quantity = 0
      where pi.owner_kind = v_slot.owner_kind
        and pi.owner_id = v_slot.owner_id
        and pi.inventory_type = 'output'
        and pi.product_id = v_old_product_id
        and pi.quality_level = v_old_quality_level;
    end if;
  else
    v_existing_output_quantity := 0;
    v_cleared_output_pending := 0;
  end if;

  update public.production_slots
  set product_id = p_product_id,
      quality_level = p_quality_level,
      updated_at = timezone('utc'::text, now())
  where id = p_production_slot_id;

  v_hammadde_1_id := nullif(v_product.hammadde_1_id, '');
  v_hammadde_2_id := nullif(v_product.hammadde_2_id, '');
  v_hammadde_3_id := nullif(v_product.hammadde_3_id, '');

  v_hammadde_1_miktar := coalesce(v_product.hammadde_1_miktar, 0);
  v_hammadde_2_miktar := coalesce(v_product.hammadde_2_miktar, 0);
  v_hammadde_3_miktar := coalesce(v_product.hammadde_3_miktar, 0);

  if v_hammadde_1_id is not null and v_hammadde_1_miktar > 0 then
    select id into v_inventory_id
    from public.production_inventory
    where owner_kind = v_slot.owner_kind
      and owner_id = v_slot.owner_id
      and inventory_type = 'input'
      and product_id = v_hammadde_1_id
      and quality_level = v_input_quality_level;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, quantity, pending_quantity, cost
      ) values (
        v_slot.owner_kind, v_slot.owner_id, 'input', v_hammadde_1_id, v_input_quality_level, 0, 0, 0
      );
      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  if v_hammadde_2_id is not null and v_hammadde_2_miktar > 0 then
    select id into v_inventory_id
    from public.production_inventory
    where owner_kind = v_slot.owner_kind
      and owner_id = v_slot.owner_id
      and inventory_type = 'input'
      and product_id = v_hammadde_2_id
      and quality_level = v_input_quality_level;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, quantity, pending_quantity, cost
      ) values (
        v_slot.owner_kind, v_slot.owner_id, 'input', v_hammadde_2_id, v_input_quality_level, 0, 0, 0
      );
      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  if v_hammadde_3_id is not null and v_hammadde_3_miktar > 0 then
    select id into v_inventory_id
    from public.production_inventory
    where owner_kind = v_slot.owner_kind
      and owner_id = v_slot.owner_id
      and inventory_type = 'input'
      and product_id = v_hammadde_3_id
      and quality_level = v_input_quality_level;

    if not found then
      insert into public.production_inventory (
        owner_kind, owner_id, inventory_type, product_id, quality_level, quantity, pending_quantity, cost
      ) values (
        v_slot.owner_kind, v_slot.owner_id, 'input', v_hammadde_3_id, v_input_quality_level, 0, 0, 0
      );
      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  select id into v_output_inventory_id
  from public.production_inventory
  where owner_kind = v_slot.owner_kind
    and owner_id = v_slot.owner_id
    and inventory_type = 'output'
    and product_id = p_product_id
    and quality_level = p_quality_level;

  if not found then
    insert into public.production_inventory (
      owner_kind, owner_id, inventory_type, product_id, quality_level, quantity, pending_quantity, cost
    ) values (
      v_slot.owner_kind, v_slot.owner_id, 'output', p_product_id, p_quality_level, 0, 0, 0
    ) returning id into v_output_inventory_id;
    v_created_output_count := 1;
  end if;

  if not v_same_setting then
    delete from public.production_inventory pi
    where pi.owner_kind = v_slot.owner_kind
      and pi.owner_id = v_slot.owner_id
      and coalesce(pi.quantity, 0) = 0
      and coalesce(pi.pending_quantity, 0) = 0
      and not exists (
        select 1
        from public.logistics_transfers lt
        where lt.seller_production_inventory_id = pi.id
           or lt.buyer_production_inventory_id = pi.id
      )
      and not (
        pi.inventory_type = 'output'
        and exists (
          select 1
          from public.production_slots ps
          where ps.owner_kind = pi.owner_kind
            and ps.owner_id = pi.owner_id
            and coalesce(ps.product_id, '') <> ''
            and ps.product_id = pi.product_id
            and ps.quality_level = pi.quality_level
        )
      )
      and not (
        pi.inventory_type = 'input'
        and pi.quality_level = v_input_quality_level
        and exists (
          select 1
          from public.production_slots ps
          join public.products pr on pr.id = ps.product_id
          where ps.owner_kind = pi.owner_kind
            and ps.owner_id = pi.owner_id
            and coalesce(ps.product_id, '') <> ''
            and (
              (nullif(pr.hammadde_1_id, '') = pi.product_id and coalesce(pr.hammadde_1_miktar, 0) > 0)
              or (nullif(pr.hammadde_2_id, '') = pi.product_id and coalesce(pr.hammadde_2_miktar, 0) > 0)
              or (nullif(pr.hammadde_3_id, '') = pi.product_id and coalesce(pr.hammadde_3_miktar, 0) > 0)
            )
        )
      );

    get diagnostics v_deleted_obsolete_count = row_count;
  end if;

  return jsonb_build_object(
    'success', true,
    'mode', 'change',
    'production_slot_id', p_production_slot_id,
    'owner_kind', v_slot.owner_kind,
    'owner_id', v_slot.owner_id,
    'owner_type_id', v_owner_type_id,
    'old_product_id', v_old_product_id,
    'old_quality_level', v_old_quality_level,
    'product_id', p_product_id,
    'product_name', v_product.urun_adi,
    'quality_level', p_quality_level,
    'input_quality_level', v_input_quality_level,
    'player_max_quality_level', v_max_quality,
    'same_setting', v_same_setting,
    'existing_output_quantity', coalesce(v_existing_output_quantity, 0),
    'cleared_output_pending_quantity', coalesce(v_cleared_output_pending, 0),
    'created_input_count', v_created_input_count,
    'created_output_count', v_created_output_count,
    'deleted_obsolete_inventory_count', v_deleted_obsolete_count,
    'output_inventory_id', v_output_inventory_id
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.clear_store_slot_product(p_player_id uuid, p_store_slot_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_slot record;
begin
  -- Slotu ve bağlı mağazayı kilitleyerek al
  select
    ss.*,
    s.player_id
  into v_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  where ss.id = p_store_slot_id
  for update;

  if not found then
    raise exception 'Mağaza slotu bulunamadı.';
  end if;

  if v_slot.player_id <> p_player_id then
    raise exception 'Bu slot oyuncuya ait değil.';
  end if;

  if v_slot.quantity > 0 then
    raise exception 'Stok bulunan slot boşaltılamaz. Önce stok sıfırlanmalıdır.';
  end if;

  update public.store_slots
  set
    product_id = null,
    quality_level = 0,
    price = 0,
    cost = 0,
    pending_sale = 0,
    updated_at = timezone('utc'::text, now())
  where id = p_store_slot_id;

  return jsonb_build_object(
    'success', true,
    'store_slot_id', p_store_slot_id,
    'store_id', v_slot.store_id,
    'product_id', null,
    'quality_level', 0,
    'quantity', 0,
    'price', 0,
    'cost', 0,
    'pending_sale', 0
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.complete_arge_research(p_research_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_research arge_researches%rowtype;
  v_now timestamptz := timezone('utc', now());
begin
  select * into v_research
  from arge_researches
  where id = p_research_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Araştırma bulunamadı.');
  end if;

  if v_research.status <> 'in_progress' then
    return jsonb_build_object('success', false, 'message', 'Bu araştırma zaten tamamlanmış.');
  end if;

  if v_research.finish_at > v_now then
    return jsonb_build_object('success', false, 'message', 'Araştırma henüz tamamlanmadı.');
  end if;

  -- Kaliteyi güncelle
  insert into player_product_quality_levels (player_id, product_id, max_quality_level, created_at, updated_at)
  values (v_research.player_id, v_research.product_id, v_research.target_quality, v_now, v_now)
  on conflict (player_id, product_id) DO UPDATE
    set max_quality_level = EXCLUDED.max_quality_level, updated_at = v_now;

  -- Araştırmayı tamamlandı yap
  update arge_researches
  set status = 'completed', completed_at = v_now
  where id = p_research_id;

  return jsonb_build_object(
    'success', true,
    'product_id', v_research.product_id,
    'product_name', v_research.product_name,
    'new_quality_level', v_research.target_quality
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.complete_building_construction(p_player_id uuid, p_construction_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_construction record;
  v_now timestamptz := timezone('utc'::text, now());

  v_created_id uuid;
begin
  -- İnşaat kaydını kilitleyerek al
  select *
  into v_construction
  from public.building_constructions
  where id = p_construction_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'İnşaat kaydı bulunamadı.';
  end if;

  if v_construction.status <> 'in_progress' then
    raise exception 'Bu inşaat tamamlanabilir durumda değil. Mevcut durum: %', v_construction.status;
  end if;

  if v_construction.finish_at > v_now then
    raise exception 'İnşaat henüz bitmedi. Bitiş zamanı: %', v_construction.finish_at;
  end if;

  -- STORE
  if v_construction.building_kind = 'store' then

    insert into public.stores (
      player_id,
      store_type_id,
      city_id,
      name,
      level,
      current_slot_count,
      max_slot_count,
      slot_capacity,
      is_active
    )
    values (
      p_player_id,
      (v_construction.params->>'store_type_id')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'current_slot_count')::integer, 0),
      coalesce((v_construction.params->>'max_slot_count')::integer, 0),
      coalesce((v_construction.params->>'slot_capacity')::integer, 0),
      true
    )
    returning id into v_created_id;

  -- WAREHOUSE
  elsif v_construction.building_kind = 'warehouse' then

    insert into public.warehouses (
      player_id,
      warehouse_type_id,
      city_id,
      name,
      level,
      capacity,
      is_active
    )
    values (
      p_player_id,
      (v_construction.params->>'warehouse_type_id')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'capacity')::numeric, 0),
      true
    )
    returning id into v_created_id;

  -- FACTORY
  elsif v_construction.building_kind = 'factory' then

    insert into public.factories (
      player_id,
      factory_type_id,
      city_id,
      name,
      level,
      product_id,
      quality_level,
      input_capacity,
      output_capacity,
      boost_multiplier,
      is_active
    )
    values (
      p_player_id,
      (v_construction.params->>'factory_type_id')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      null,
      coalesce((v_construction.params->>'quality_level')::integer, 0),
      coalesce((v_construction.params->>'input_capacity')::integer, 0),
      coalesce((v_construction.params->>'output_capacity')::integer, 0),
      coalesce((v_construction.params->>'boost_multiplier')::numeric, 1.00),
      true
    )
    returning id into v_created_id;

  -- FIELD
  elsif v_construction.building_kind = 'field' then

    insert into public.fields (
      player_id,
      field_type_id,
      city_id,
      name,
      level,
      current_slot_count,
      max_slot_count,
      input_capacity,
      output_capacity,
      is_active
    )
    values (
      p_player_id,
      (v_construction.params->>'field_type_id')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'current_slot_count')::integer, 0),
      coalesce((v_construction.params->>'max_slot_count')::integer, 0),
      coalesce((v_construction.params->>'input_capacity')::integer, 0),
      coalesce((v_construction.params->>'output_capacity')::integer, 0),
      true
    )
    returning id into v_created_id;

  -- FARM
  elsif v_construction.building_kind = 'farm' then

    insert into public.farms (
      player_id,
      farm_type_id,
      city_id,
      name,
      level,
      current_slot_count,
      max_slot_count,
      input_capacity,
      output_capacity,
      is_active
    )
    values (
      p_player_id,
      (v_construction.params->>'farm_type_id')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'current_slot_count')::integer, 0),
      coalesce((v_construction.params->>'max_slot_count')::integer, 0),
      coalesce((v_construction.params->>'input_capacity')::integer, 0),
      coalesce((v_construction.params->>'output_capacity')::integer, 0),
      true
    )
    returning id into v_created_id;

  -- MINE
  elsif v_construction.building_kind = 'mine' then

    insert into public.mines (
      player_id,
      mine_type_id,
      city_id,
      name,
      level,
      product_id,
      quality_level,
      output_capacity,
      boost_multiplier,
      is_active
    )
    values (
      p_player_id,
      (v_construction.params->>'mine_type_id')::uuid,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      null,
      coalesce((v_construction.params->>'quality_level')::integer, 0),
      coalesce((v_construction.params->>'output_capacity')::integer, 0),
      coalesce((v_construction.params->>'boost_multiplier')::numeric, 1.00),
      true
    )
    returning id into v_created_id;

  -- LOGISTICS COMPANY
  elsif v_construction.building_kind = 'logistics_company' then

    insert into public.logistics_companies (
      player_id,
      city_id,
      name,
      level,
      current_vehicle_count,
      max_vehicle_count,
      fuel_capacity,
      current_fuel,
      fuel_cost,
      is_active
    )
    values (
      p_player_id,
      (v_construction.params->>'city_id')::uuid,
      v_construction.params->>'name',
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'current_vehicle_count')::integer, 0),
      coalesce((v_construction.params->>'max_vehicle_count')::integer, 0),
      coalesce((v_construction.params->>'fuel_capacity')::integer, 0),
      coalesce((v_construction.params->>'current_fuel')::integer, 0),
      coalesce((v_construction.params->>'fuel_cost')::numeric, 0),
      true
    )
    returning id into v_created_id;

  else
    raise exception 'Geçersiz building_kind: %', v_construction.building_kind;
  end if;

  -- İnşaatı tamamlandı yap
  update public.building_constructions
  set
    status = 'complete',
    completed_at = v_now
  where id = p_construction_id;

  return jsonb_build_object(
    'success', true,
    'construction_id', p_construction_id,
    'building_kind', v_construction.building_kind,
    'created_id', v_created_id,
    'status', 'complete',
    'completed_at', v_now
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.complete_due_arge_researches()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_row arge_researches%rowtype;
  v_count integer := 0;
begin
  for v_row in
    select * from arge_researches
    where status = 'in_progress' and finish_at <= timezone('utc', now())
    for update skip locked
  loop
    insert into player_product_quality_levels (player_id, product_id, max_quality_level, created_at, updated_at)
    values (v_row.player_id, v_row.product_id, v_row.target_quality, timezone('utc', now()), timezone('utc', now()))
    on conflict (player_id, product_id) DO UPDATE
      set max_quality_level = EXCLUDED.max_quality_level, updated_at = timezone('utc', now());

    update arge_researches
    set status = 'completed', completed_at = timezone('utc', now())
    where id = v_row.id;

    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('success', true, 'completed_count', v_count);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.complete_due_building_constructions(p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row record;
  v_completed_count integer := 0;
  v_failed_count integer := 0;
  v_result jsonb;
begin
  for v_row in
    select
      id,
      player_id
    from public.building_constructions
    where status = 'in_progress'
      and finish_at <= timezone('utc'::text, now())
    order by finish_at asc
    limit p_limit
    for update skip locked
  loop
    begin
      select public.complete_building_construction(
        v_row.player_id,
        v_row.id
      )
      into v_result;

      v_completed_count := v_completed_count + 1;

    exception when others then
      v_failed_count := v_failed_count + 1;
    end;
  end loop;

  return jsonb_build_object(
    'success', true,
    'completed_count', v_completed_count,
    'failed_count', v_failed_count
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.complete_due_market_transfers(p_buyer_player_id uuid DEFAULT auth.uid(), p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_completed_count integer := 0;
  v_transfer record;
  v_result jsonb;
  v_ids uuid[] := '{}';
begin
  for v_transfer in
    select lt.id, lt.transfer_type
    from public.logistics_transfers lt
    where lt.status = 'in_transit'
      and lt.finish_at <= timezone('utc'::text, now())
      and (p_buyer_player_id is null or lt.buyer_player_id = p_buyer_player_id)
    order by lt.finish_at asc
    limit greatest(coalesce(p_limit, 100), 1)
    for update skip locked
  loop
    if coalesce(v_transfer.transfer_type, '') in ('warehouse_to_production', 'production_to_warehouse') then
      v_result := public.complete_production_logistics_transfer(v_transfer.id);
    else
      v_result := public.complete_market_transfer_system(v_transfer.id);
    end if;

    if coalesce((v_result ->> 'success')::boolean, false) then
      v_completed_count := v_completed_count + 1;
      v_ids := array_append(v_ids, v_transfer.id);
    end if;
  end loop;

  return jsonb_build_object(
    'success', true,
    'completed_count', v_completed_count,
    'transfer_ids', v_ids
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.complete_market_transfer(p_transfer_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_transfer record;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  select *
  into v_transfer
  from public.logistics_transfers
  where id = p_transfer_id
    and buyer_player_id = v_player_id
  for update;

  if not found then
    raise exception 'Transfer bulunamadi veya size ait degil.';
  end if;

  if v_transfer.finish_at > timezone('utc'::text, now()) then
    raise exception 'Transfer suresi heniz dolmadi.';
  end if;

  return public.complete_market_transfer_system(p_transfer_id);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.complete_market_transfer_system(p_transfer_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_transfer record;
  v_add_result jsonb;
  v_store_slot record;
  v_incoming_unit_cost numeric := 0;
  v_new_cost numeric := 0;
begin
  select *
  into v_transfer
  from public.logistics_transfers
  where id = p_transfer_id
  for update;

  if not found then
    raise exception 'Transfer bulunamadi.';
  end if;

  if v_transfer.status <> 'in_transit' then
    return jsonb_build_object(
      'success', true,
      'transfer_id', p_transfer_id,
      'status', v_transfer.status,
      'skipped', true
    );
  end if;

  if coalesce(v_transfer.transfer_type, 'market_to_warehouse') in ('market_to_store', 'warehouse_to_store') then
    select *
    into v_store_slot
    from public.store_slots
    where id = v_transfer.buyer_store_slot_id
    for update;

    if not found then
      raise exception 'Hedef magaza slotu bulunamadi.';
    end if;

    if v_store_slot.product_id is null or v_store_slot.quality_level = 0 then
      raise exception 'Hedef magaza slotunda urun veya kalite bilgisi yok.';
    end if;

    if v_store_slot.product_id <> v_transfer.product_id or v_store_slot.quality_level <> v_transfer.quality_level then
      raise exception 'Hedef magaza slotu urun/kalite uyumsuz.';
    end if;

    v_incoming_unit_cost := coalesce(v_transfer.unit_price, 0)
      + case when v_transfer.quantity > 0 then coalesce(v_transfer.transport_cost, 0) / v_transfer.quantity else 0 end;

    if coalesce(v_store_slot.quantity, 0) + v_transfer.quantity > v_store_slot.capacity then
      raise exception 'Hedef magaza slot kapasitesi asildi.';
    end if;

    v_new_cost := case
      when coalesce(v_store_slot.quantity, 0) + v_transfer.quantity > 0 then
        (
          coalesce(v_store_slot.quantity, 0) * coalesce(v_store_slot.cost, 0)
          + v_transfer.quantity * v_incoming_unit_cost
        ) / (coalesce(v_store_slot.quantity, 0) + v_transfer.quantity)
      else coalesce(v_store_slot.cost, 0)
    end;

    update public.store_slots
    set
      quantity = quantity + v_transfer.quantity,
      pending_quantity = greatest(coalesce(pending_quantity, 0) - v_transfer.quantity, 0),
      cost = v_new_cost,
      updated_at = timezone('utc'::text, now())
    where id = v_transfer.buyer_store_slot_id;

    v_add_result := jsonb_build_object(
      'success', true,
      'target', 'store_slot',
      'store_slot_id', v_transfer.buyer_store_slot_id,
      'quantity_added', v_transfer.quantity,
      'new_cost', v_new_cost
    );
  else
    v_add_result := public.add_product_to_warehouse(
      v_transfer.buyer_player_id,
      v_transfer.buyer_warehouse_id,
      v_transfer.product_id,
      v_transfer.quality_level,
      v_transfer.quantity,
      v_transfer.unit_price,
      v_transfer.transport_cost,
      true
    );
  end if;

  update public.logistics_vehicles
  set
    status = 'idle',
    updated_at = timezone('utc'::text, now())
  where id = v_transfer.logistics_vehicle_id;

  update public.logistics_transfers
  set
    status = 'completed',
    completed_at = timezone('utc'::text, now()),
    updated_at = timezone('utc'::text, now())
  where id = p_transfer_id;

  return jsonb_build_object(
    'success', true,
    'transfer_id', p_transfer_id,
    'status', 'completed',
    'warehouse_result', v_add_result
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.complete_production_logistics_transfer(p_transfer_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_transfer record;
  v_inventory record;
  v_incoming_unit_cost numeric := 0;
  v_new_cost numeric := 0;
  v_add_result jsonb;
begin
  select *
  into v_transfer
  from public.logistics_transfers
  where id = p_transfer_id
  for update;

  if not found then
    raise exception 'Transfer bulunamadi.';
  end if;

  if v_transfer.status <> 'in_transit' then
    return jsonb_build_object(
      'success', true,
      'transfer_id', p_transfer_id,
      'status', v_transfer.status,
      'skipped', true
    );
  end if;

  if v_transfer.transfer_type = 'warehouse_to_production' then
    select *
    into v_inventory
    from public.production_inventory
    where id = v_transfer.buyer_production_inventory_id
    for update;

    if not found then
      raise exception 'Hedef production inventory bulunamadi.';
    end if;

    if v_inventory.inventory_type <> 'input' then
      raise exception 'Hedef production inventory input tipinde degil.';
    end if;

    if v_inventory.product_id <> v_transfer.product_id
       or v_inventory.quality_level <> v_transfer.quality_level then
      raise exception 'Hedef production inventory urun/kalite uyumsuz.';
    end if;

    v_incoming_unit_cost := coalesce(v_transfer.unit_price, 0)
      + case when v_transfer.quantity > 0 then coalesce(v_transfer.transport_cost, 0) / v_transfer.quantity else 0 end;

    v_new_cost := case
      when coalesce(v_inventory.quantity, 0) + v_transfer.quantity > 0 then
        (
          coalesce(v_inventory.quantity, 0) * coalesce(v_inventory.cost, 0)
          + v_transfer.quantity * v_incoming_unit_cost
        ) / (coalesce(v_inventory.quantity, 0) + v_transfer.quantity)
      else coalesce(v_inventory.cost, 0)
    end;

    update public.production_inventory
    set
      quantity = coalesce(quantity, 0) + v_transfer.quantity,
      pending_quantity = greatest(coalesce(pending_quantity, 0) - v_transfer.quantity, 0),
      cost = v_new_cost
    where id = v_transfer.buyer_production_inventory_id;

    v_add_result := jsonb_build_object(
      'success', true,
      'target', 'production_inventory',
      'production_inventory_id', v_transfer.buyer_production_inventory_id,
      'quantity_added', v_transfer.quantity,
      'new_cost', v_new_cost
    );
  elsif v_transfer.transfer_type = 'production_to_warehouse' then
    v_add_result := public.add_product_to_warehouse(
      v_transfer.buyer_player_id,
      v_transfer.buyer_warehouse_id,
      v_transfer.product_id,
      v_transfer.quality_level,
      v_transfer.quantity,
      v_transfer.unit_price,
      v_transfer.transport_cost,
      true
    );
  else
    raise exception 'Desteklenmeyen production transfer type: %', v_transfer.transfer_type;
  end if;

  update public.logistics_vehicles
  set
    status = 'idle',
    updated_at = timezone('utc'::text, now())
  where id = v_transfer.logistics_vehicle_id;

  update public.logistics_transfers
  set
    status = 'completed',
    completed_at = timezone('utc'::text, now()),
    updated_at = timezone('utc'::text, now())
  where id = p_transfer_id;

  return jsonb_build_object(
    'success', true,
    'transfer_id', p_transfer_id,
    'status', 'completed',
    'result', v_add_result
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.ensure_player_record_exists(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player public.players%rowtype;
  v_created boolean := false;
begin
  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Yetkisiz istek.';
  end if;

  select *
  into v_player
  from public.players
  where id = p_user_id;

  if not found then
    insert into public.players (
      id,
      player_name,
      company_name,
      avatar_id,
      level,
      experience,
      cash,
      gold
    )
    values (
      p_user_id,
      'Oyuncu_' || left(p_user_id::text, 4),
      'Yeni Holding',
      'ae1.webp',
      1,
      0,
      100000,
      100
    )
    returning *
    into v_player;

    v_created := true;
  end if;

  return jsonb_build_object(
    'created', v_created,
    'player', to_jsonb(v_player)
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.finish_arge_with_gold(p_player_id uuid, p_research_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_research arge_researches%rowtype;
  v_player players%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_remaining_minutes integer;
  v_gold_cost integer;
begin
  select * into v_research
  from arge_researches
  where id = p_research_id and player_id = p_player_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Arastirma bulunamadi.');
  end if;

  if v_research.status <> 'in_progress' then
    return jsonb_build_object('success', false, 'message', 'Bu arastirma zaten tamamlanmis.');
  end if;

  if v_research.finish_at <= v_now then
    return public.complete_arge_research(p_research_id);
  end if;

  v_remaining_minutes := ceil(extract(epoch from (v_research.finish_at - v_now)) / 60.0);
  v_gold_cost := greatest(1, ceil(v_remaining_minutes::numeric / 30.0)::integer);

  select * into v_player from players where id = p_player_id;
  if v_player.gold < v_gold_cost then
    return jsonb_build_object(
      'success', false,
      'message', format('Yetersiz altin. Gerekli: %s ★, Mevcut: %s ★.', v_gold_cost, v_player.gold::integer)
    );
  end if;

  update players
  set gold = gold - v_gold_cost
  where id = p_player_id;

  update arge_researches
  set finish_at = v_now
  where id = p_research_id;

  return public.complete_arge_research(p_research_id) || jsonb_build_object('gold_spent', v_gold_cost);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.finish_construction_with_gold(p_player_id uuid, p_construction_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_player_gold numeric;
  v_gold_cost integer;
  v_construction record;
  v_remaining_minutes float;
BEGIN
  -- 1. İnşaat kaydını kontrol et
  SELECT * INTO v_construction FROM public.building_constructions 
  WHERE id = p_construction_id AND player_id = p_player_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'İnşaat kaydı bulunamadı.');
  END IF;

  IF v_construction.status <> 'in_progress' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Bu inşaat zaten tamamlanmış veya iptal edilmiş.');
  END IF;

  -- 2. Dinamik maliyet hesapla (Her 10 dk için 1 altın, yukarı yuvarla)
  -- extract(epoch from ...) saniye farkını verir, 60'a bölerek dakikayı buluruz.
  v_remaining_minutes := EXTRACT(EPOCH FROM (v_construction.finish_at - timezone('utc'::text, now()))) / 60.0;
  
  -- Eğer süre zaten dolmuşsa maliyet 0 veya 1 olsun (garanti olsun)
  IF v_remaining_minutes <= 0 THEN
    v_gold_cost := 0;
  ELSE
    v_gold_cost := ceil(v_remaining_minutes / 10.0);
  END IF;

  -- 3. Oyuncunun altınını kontrol et
  SELECT gold INTO v_player_gold FROM public.players WHERE id = p_player_id FOR UPDATE;
  
  IF v_player_gold < v_gold_cost THEN
    RETURN jsonb_build_object('success', false, 'message', 'Yetersiz altın. Gereken: ' || v_gold_cost);
  END IF;

  -- 4. Altını düş
  UPDATE public.players SET gold = gold - v_gold_cost WHERE id = p_player_id;

  -- 5. İnşaatın bitiş süresini geçmişe çek
  UPDATE public.building_constructions 
  SET finish_at = timezone('utc'::text, now()) - interval '1 second'
  WHERE id = p_construction_id;

  -- 6. Mevcut tamamlama fonksiyonunu çağır
  RETURN public.complete_building_construction(p_player_id, p_construction_id);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_active_cities()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.get_cities_catalog(true);
$function$
;

CREATE OR REPLACE FUNCTION public.get_all_products_catalog()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(to_jsonb(p) order by p.urun_adi),
    '[]'::jsonb
  )
  from public.products p;
$function$
;

CREATE OR REPLACE FUNCTION public.get_arge_products_with_quality()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'urun_adi', p.urun_adi,
        'urun_iconu', p.urun_iconu,
        'baz_satis_fiyati', p.baz_satis_fiyati,
        'uretim_birimi', p.uretim_birimi,
        'current_quality_level', coalesce(ppql.max_quality_level, 1)
      )
      order by p.urun_adi
    ),
    '[]'::jsonb
  )
  from public.products p
  left join public.player_product_quality_levels ppql
    on ppql.product_id = p.id
   and ppql.player_id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.get_available_products_for_store(p_store_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_store_type_id UUID;
    v_accepted_ids TEXT;
    v_current_product_ids TEXT[];
    v_products JSONB;
BEGIN
    -- 1. Mağazanın tipini bul
    SELECT store_type_id INTO v_store_type_id
    FROM stores
    WHERE id = p_store_id;

    -- 2. Mağaza tipine göre kabul edilen ürünleri al
    SELECT accepted_product_ids INTO v_accepted_ids
    FROM store_types
    WHERE id = v_store_type_id;

    -- 3. Mevcut slotlardaki ürünleri bul
    SELECT array_agg(product_id) INTO v_current_product_ids
    FROM store_slots
    WHERE store_id = p_store_id AND product_id IS NOT NULL;

    -- 4. Ürünleri getir
    SELECT jsonb_agg(jsonb_build_object(
        'id', p.id,
        'name', p.urun_adi,
        'icon', p.urun_iconu,
        'base_price', p.baz_satis_fiyati
    )) INTO v_products
    FROM products p
    WHERE p.id = ANY(string_to_array(v_accepted_ids, ','))
    AND (v_current_product_ids IS NULL OR NOT (p.id = ANY(v_current_product_ids)));

    RETURN jsonb_build_object(
        'success', true,
        'products', COALESCE(v_products, '[]'::jsonb)
    );
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'message', SQLERRM
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_buyer_active_market_transfers()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', lt.id,
        'product_id', lt.product_id,
        'quantity', lt.quantity,
        'status', lt.status,
        'started_at', lt.started_at,
        'finish_at', lt.finish_at,
        'is_rental', lt.is_rental,
        'total_price', lt.total_price,
        'rental_cost', lt.rental_cost
      )
      order by lt.finish_at
    ),
    '[]'::jsonb
  )
  from public.logistics_transfers lt
  where lt.buyer_player_id = auth.uid()
    and lt.status = 'in_transit';
$function$
;

CREATE OR REPLACE FUNCTION public.get_buyer_transfer_history_items()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(item order by completed_at desc nulls last),
    '[]'::jsonb
  )
  from (
    select
      lt.completed_at,
      (
        jsonb_build_object(
          'id', lt.id,
          'quantity', lt.quantity,
          'status', lt.status,
          'is_rental', lt.is_rental,
          'total_price', lt.total_price,
          'rental_cost', lt.rental_cost,
          'started_at', lt.started_at,
          'finish_at', lt.finish_at,
          'completed_at', lt.completed_at,
          'seller_entity_kind', lt.seller_entity_kind,
          'buyer_entity_kind', lt.buyer_entity_kind,
          'product',
          (
            select jsonb_build_object(
              'id', p.id,
              'urun_adi', p.urun_adi,
              'urun_iconu', p.urun_iconu
            )
            from public.products p
            where p.id = lt.product_id
          ),
          'seller_warehouse',
          case
            when lt.seller_warehouse_id is null then null
            else (
              select
                to_jsonb(w) ||
                jsonb_build_object(
                  'city',
                  (
                    select jsonb_build_object('id', c.id, 'name', c.name)
                    from public.cities c
                    where c.id = w.city_id
                  )
                )
              from public.warehouses w
              where w.id = lt.seller_warehouse_id
            )
          end,
          'seller_store',
          case
            when lt.seller_store_id is null then null
            else (
              select
                to_jsonb(s) ||
                jsonb_build_object(
                  'city',
                  (
                    select jsonb_build_object('id', c.id, 'name', c.name)
                    from public.cities c
                    where c.id = s.city_id
                  )
                )
              from public.stores s
              where s.id = lt.seller_store_id
            )
          end,
          'seller_production_inventory',
          case
            when lt.seller_production_inventory_id is null then null
            else (
              select jsonb_build_object(
                'id', pi.id,
                'inventory_type', pi.inventory_type
              )
              from public.production_inventory pi
              where pi.id = lt.seller_production_inventory_id
            )
          end,
          'buyer_warehouse',
          case
            when lt.buyer_warehouse_id is null then null
            else (
              select
                to_jsonb(w) ||
                jsonb_build_object(
                  'city',
                  (
                    select jsonb_build_object('id', c.id, 'name', c.name)
                    from public.cities c
                    where c.id = w.city_id
                  )
                )
              from public.warehouses w
              where w.id = lt.buyer_warehouse_id
            )
          end,
          'buyer_store',
          case
            when lt.buyer_store_id is null then null
            else (
              select
                to_jsonb(s) ||
                jsonb_build_object(
                  'city',
                  (
                    select jsonb_build_object('id', c.id, 'name', c.name)
                    from public.cities c
                    where c.id = s.city_id
                  )
                )
              from public.stores s
              where s.id = lt.buyer_store_id
            )
          end,
          'buyer_production_inventory',
          case
            when lt.buyer_production_inventory_id is null then null
            else (
              select jsonb_build_object(
                'id', pi.id,
                'inventory_type', pi.inventory_type
              )
              from public.production_inventory pi
              where pi.id = lt.buyer_production_inventory_id
            )
          end
        )
      ) as item
    from public.logistics_transfers lt
    where lt.buyer_player_id = auth.uid()
      and lt.status <> 'in_transit'
    order by lt.completed_at desc nulls last
    limit 50
  ) history_rows;
$function$
;

CREATE OR REPLACE FUNCTION public.get_buyer_transfer_map_items()
 RETURNS TABLE(id uuid, quantity integer, status text, is_rental boolean, total_price numeric, rental_cost numeric, started_at timestamp with time zone, finish_at timestamp with time zone, product_id text, product_name text, product_icon text, seller_entity_kind text, buyer_entity_kind text, seller_warehouse_id uuid, seller_warehouse_name text, seller_city_id uuid, seller_city_name text, seller_city_x numeric, seller_city_y numeric, buyer_warehouse_id uuid, buyer_warehouse_name text, buyer_city_id uuid, buyer_city_name text, buyer_city_x numeric, buyer_city_y numeric)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    lt.id,
    lt.quantity,
    lt.status,
    lt.is_rental,
    lt.total_price,
    lt.rental_cost,
    lt.started_at,
    lt.finish_at,
    p.id as product_id,
    p.urun_adi as product_name,
    p.urun_iconu as product_icon,
    coalesce(
      lt.seller_entity_kind,
      case
        when lt.seller_production_inventory_id is not null then 'production_inventory'
        when lt.seller_store_id is not null or lt.seller_store_slot_id is not null then 'store_slot'
        else 'warehouse'
      end
    ) as seller_entity_kind,
    coalesce(
      lt.buyer_entity_kind,
      case
        when lt.buyer_production_inventory_id is not null then 'production_inventory'
        when lt.buyer_store_id is not null or lt.buyer_store_slot_id is not null then 'store_slot'
        else 'warehouse'
      end
    ) as buyer_entity_kind,
    coalesce(sw.id, ss.id, spi.id) as seller_warehouse_id,
    coalesce(
      sw.name,
      ss.name,
      case
        when spi.id is not null then
          coalesce(sf.name, sfi.name, sfa.name, sm.name, 'Uretim')
          || ' '
          || case when spi.inventory_type = 'input' then 'Input' else 'Output' end
        else null
      end
    ) as seller_warehouse_name,
    coalesce(sc_w.id, sc_s.id, sc_p.id) as seller_city_id,
    coalesce(sc_w.name, sc_s.name, sc_p.name) as seller_city_name,
    coalesce(sc_w.map_position_x, sc_s.map_position_x, sc_p.map_position_x) as seller_city_x,
    coalesce(sc_w.map_position_y, sc_s.map_position_y, sc_p.map_position_y) as seller_city_y,
    coalesce(bw.id, bs.id, bpi.id) as buyer_warehouse_id,
    coalesce(
      bw.name,
      bs.name,
      case
        when bpi.id is not null then
          coalesce(bf.name, bfi.name, bfa.name, bm.name, 'Uretim')
          || ' '
          || case when bpi.inventory_type = 'input' then 'Input' else 'Output' end
        else null
      end
    ) as buyer_warehouse_name,
    coalesce(bc_w.id, bc_s.id, bc_p.id) as buyer_city_id,
    coalesce(bc_w.name, bc_s.name, bc_p.name) as buyer_city_name,
    coalesce(bc_w.map_position_x, bc_s.map_position_x, bc_p.map_position_x) as buyer_city_x,
    coalesce(bc_w.map_position_y, bc_s.map_position_y, bc_p.map_position_y) as buyer_city_y
  from public.logistics_transfers lt
  join public.products p on p.id = lt.product_id
  left join public.warehouses sw on sw.id = lt.seller_warehouse_id
  left join public.cities sc_w on sc_w.id = sw.city_id
  left join public.stores ss on ss.id = lt.seller_store_id
  left join public.cities sc_s on sc_s.id = ss.city_id
  left join public.production_inventory spi on spi.id = lt.seller_production_inventory_id
  left join public.factories sf on sf.id = spi.owner_id and spi.owner_kind = 'factory'
  left join public.fields sfi on sfi.id = spi.owner_id and spi.owner_kind = 'field'
  left join public.farms sfa on sfa.id = spi.owner_id and spi.owner_kind = 'farm'
  left join public.mines sm on sm.id = spi.owner_id and spi.owner_kind = 'mine'
  left join public.cities sc_p on sc_p.id = coalesce(sf.city_id, sfi.city_id, sfa.city_id, sm.city_id)
  left join public.warehouses bw on bw.id = lt.buyer_warehouse_id
  left join public.cities bc_w on bc_w.id = bw.city_id
  left join public.stores bs on bs.id = lt.buyer_store_id
  left join public.cities bc_s on bc_s.id = bs.city_id
  left join public.production_inventory bpi on bpi.id = lt.buyer_production_inventory_id
  left join public.factories bf on bf.id = bpi.owner_id and bpi.owner_kind = 'factory'
  left join public.fields bfi on bfi.id = bpi.owner_id and bpi.owner_kind = 'field'
  left join public.farms bfa on bfa.id = bpi.owner_id and bpi.owner_kind = 'farm'
  left join public.mines bm on bm.id = bpi.owner_id and bpi.owner_kind = 'mine'
  left join public.cities bc_p on bc_p.id = coalesce(bf.city_id, bfi.city_id, bfa.city_id, bm.city_id)
  where lt.buyer_player_id = auth.uid()
    and lt.status = 'in_transit'
  order by lt.finish_at asc;
$function$
;

CREATE OR REPLACE FUNCTION public.get_cities_catalog(p_only_active boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(to_jsonb(c) order by c.name),
    '[]'::jsonb
  )
  from public.cities c
  where (not p_only_active) or c.is_active = true;
$function$
;

CREATE OR REPLACE FUNCTION public.get_city_map_detail(p_city_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'id', c.id,
    'name', c.name,
    'map_position_x', c.map_position_x,
    'map_position_y', c.map_position_y
  )
  from public.cities c
  where c.id = p_city_id;
$function$
;

CREATE OR REPLACE FUNCTION public.get_factory_detail_data(p_factory_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'factory', to_jsonb(f),
    'factory_type', to_jsonb(ft),
    'city_name', coalesce(c.name, 'Bilinmeyen Sehir'),
    'product', case when p.id is null then null else to_jsonb(p) end,
    'inventories',
      coalesce((
        select jsonb_agg(
          to_jsonb(pi) || jsonb_build_object(
            'product',
            case when prod.id is null then null else to_jsonb(prod) end
          )
          order by pi.id
        )
        from public.production_inventory pi
        left join public.products prod on prod.id = pi.product_id
        where pi.owner_kind = 'factory'
          and pi.owner_id = f.id
      ), '[]'::jsonb)
  )
  from public.factories f
  left join public.factory_types ft on ft.id = f.factory_type_id
  left join public.cities c on c.id = f.city_id
  left join public.products p on p.id = f.product_id
  where f.id = p_factory_id
    and f.player_id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.get_factory_list_items()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'factory', to_jsonb(f),
        'city_name', c.name,
        'factory_type_name', coalesce(ft.name, 'Bilinmeyen Fabrika'),
        'factory_type_icon', coalesce(ft.icon, 'factory.webp'),
        'input_stock_quantity',
          coalesce((
            select sum(pi.quantity)::int
            from public.production_inventory pi
            where pi.owner_kind = 'factory'
              and pi.owner_id = f.id
              and pi.inventory_type = 'input'
          ), 0),
        'output_stock_quantity',
          coalesce((
            select sum(pi.quantity)::int
            from public.production_inventory pi
            where pi.owner_kind = 'factory'
              and pi.owner_id = f.id
              and pi.inventory_type = 'output'
          ), 0),
        'selected_product',
          case when p.id is null then null else to_jsonb(p) end
      )
      order by f.created_at
    ),
    '[]'::jsonb
  )
  from public.factories f
  left join public.cities c on c.id = f.city_id
  left join public.factory_types ft on ft.id = f.factory_type_id
  left join public.products p on p.id = f.product_id
  where f.player_id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.get_factory_types_catalog()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(to_jsonb(ft) order by ft.required_level, ft.cost),
    '[]'::jsonb
  )
  from public.factory_types ft;
$function$
;

CREATE OR REPLACE FUNCTION public.get_farm_detail(p_player_id uuid, p_farm_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_auth_user uuid := auth.uid();
  v_farm record;
  v_farm_type record;
  v_city_name text;
  v_slots jsonb := '[]'::jsonb;
  v_inventories jsonb := '[]'::jsonb;
begin
  if v_auth_user is null then
    raise exception 'Oturum bulunamadi.';
  end if;

  if v_auth_user <> p_player_id then
    raise exception 'Yetkisiz istek.';
  end if;

  select f.*, c.name as city_name
  into v_farm
  from public.farms f
  left join public.cities c on c.id = f.city_id
  where f.id = p_farm_id
    and f.player_id = p_player_id;

  if not found then
    raise exception 'Tarla bulunamadi veya oyuncuya ait degil.';
  end if;

  select *
  into v_farm_type
  from public.farm_types
  where id = v_farm.farm_type_id;

  v_city_name := coalesce(v_farm.city_name, 'Bilinmeyen Sehir');

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ps.id,
        'owner_kind', ps.owner_kind,
        'owner_id', ps.owner_id,
        'slot_index', ps.slot_index,
        'product_id', ps.product_id,
        'quality_level', ps.quality_level,
        'boost_multiplier', ps.boost_multiplier,
        'is_active', ps.is_active,
        'product', case
          when p.id is null then null
          else jsonb_build_object(
            'id', p.id,
            'urun_adi', p.urun_adi,
            'urun_iconu', p.urun_iconu,
            'birim_hacim', p.birim_hacim,
            'birim_agirlik', p.birim_agirlik,
            'hammadde_1_id', p.hammadde_1_id,
            'hammadde_1_miktar', p.hammadde_1_miktar,
            'hammadde_2_id', p.hammadde_2_id,
            'hammadde_2_miktar', p.hammadde_2_miktar,
            'hammadde_3_id', p.hammadde_3_id,
            'hammadde_3_miktar', p.hammadde_3_miktar,
            'uretim_birimi', p.uretim_birimi,
            'baz_satis_fiyati', p.baz_satis_fiyati,
            'uretim_adedi', p.uretim_adedi,
            'satis_adedi', p.satis_adedi,
            'en_dusuk_fiyat', p.en_dusuk_fiyat,
            'en_yuksek_fiyat', p.en_yuksek_fiyat,
            'ortalama_fiyat', p.ortalama_fiyat,
            'satici_sayisi', p.satici_sayisi,
            'piyasadaki_stok', p.piyasadaki_stok,
            'created_at', p.created_at
          )
        end
      )
      order by ps.slot_index
    ),
    '[]'::jsonb
  )
  into v_slots
  from public.production_slots ps
  left join public.products p on p.id = ps.product_id
  where ps.owner_kind = 'farm'
    and ps.owner_id = p_farm_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', pi.id,
        'owner_kind', pi.owner_kind,
        'owner_id', pi.owner_id,
        'inventory_type', pi.inventory_type,
        'product_id', pi.product_id,
        'quality_level', pi.quality_level,
        'quantity', pi.quantity,
        'pending_quantity', pi.pending_quantity,
        'cost', pi.cost,
        'product', case
          when p.id is null then null
          else jsonb_build_object(
            'id', p.id,
            'urun_adi', p.urun_adi,
            'urun_iconu', p.urun_iconu,
            'birim_hacim', p.birim_hacim,
            'birim_agirlik', p.birim_agirlik,
            'hammadde_1_id', p.hammadde_1_id,
            'hammadde_1_miktar', p.hammadde_1_miktar,
            'hammadde_2_id', p.hammadde_2_id,
            'hammadde_2_miktar', p.hammadde_2_miktar,
            'hammadde_3_id', p.hammadde_3_id,
            'hammadde_3_miktar', p.hammadde_3_miktar,
            'uretim_birimi', p.uretim_birimi,
            'baz_satis_fiyati', p.baz_satis_fiyati,
            'uretim_adedi', p.uretim_adedi,
            'satis_adedi', p.satis_adedi,
            'en_dusuk_fiyat', p.en_dusuk_fiyat,
            'en_yuksek_fiyat', p.en_yuksek_fiyat,
            'ortalama_fiyat', p.ortalama_fiyat,
            'satici_sayisi', p.satici_sayisi,
            'piyasadaki_stok', p.piyasadaki_stok,
            'created_at', p.created_at
          )
        end
      )
      order by pi.inventory_type, pi.product_id, pi.quality_level
    ),
    '[]'::jsonb
  )
  into v_inventories
  from public.production_inventory pi
  left join public.products p on p.id = pi.product_id
  where pi.owner_kind = 'farm'
    and pi.owner_id = p_farm_id;

  return jsonb_build_object(
    'success', true,
    'farm', jsonb_build_object(
      'farm', to_jsonb(v_farm) - 'city_name',
      'farm_type', to_jsonb(v_farm_type),
      'city_name', v_city_name,
      'slots', v_slots,
      'inventories', v_inventories
    )
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_farm_list_items()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'farm', to_jsonb(f),
        'city_name', c.name,
        'farm_type_name', coalesce(ft.name, 'Bilinmeyen Tarla'),
        'farm_type_icon', coalesce(ft.icon, 'farm.webp'),
        'output_stock_quantity',
          coalesce((
            select sum(pi.quantity)::int
            from public.production_inventory pi
            where pi.owner_kind = 'farm'
              and pi.owner_id = f.id
              and pi.inventory_type = 'output'
          ), 0),
        'slots',
          coalesce((
            select jsonb_agg(
              to_jsonb(ps) || jsonb_build_object(
                'product',
                case when p.id is null then null else to_jsonb(p) end
              )
              order by ps.slot_index
            )
            from public.production_slots ps
            left join public.products p on p.id = ps.product_id
            where ps.owner_kind = 'farm'
              and ps.owner_id = f.id
          ), '[]'::jsonb)
      )
      order by f.created_at
    ),
    '[]'::jsonb
  )
  from public.farms f
  left join public.cities c on c.id = f.city_id
  left join public.farm_types ft on ft.id = f.farm_type_id
  where f.player_id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.get_farm_types_catalog()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(to_jsonb(ft) order by ft.required_level, ft.cost),
    '[]'::jsonb
  )
  from public.farm_types ft;
$function$
;

CREATE OR REPLACE FUNCTION public.get_field_detail_data(p_field_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'field', to_jsonb(f),
    'field_type', to_jsonb(ft),
    'city_name', coalesce(c.name, 'Bilinmeyen Sehir'),
    'slots',
      coalesce((
        select jsonb_agg(
          to_jsonb(ps) || jsonb_build_object(
            'product',
            case when p.id is null then null else to_jsonb(p) end
          )
          order by ps.slot_index
        )
        from public.production_slots ps
        left join public.products p on p.id = ps.product_id
        where ps.owner_kind = 'field'
          and ps.owner_id = f.id
      ), '[]'::jsonb),
    'inventories',
      coalesce((
        select jsonb_agg(
          to_jsonb(pi) || jsonb_build_object(
            'product',
            case when p.id is null then null else to_jsonb(p) end
          )
          order by pi.id
        )
        from public.production_inventory pi
        left join public.products p on p.id = pi.product_id
        where pi.owner_kind = 'field'
          and pi.owner_id = f.id
      ), '[]'::jsonb)
  )
  from public.fields f
  left join public.field_types ft on ft.id = f.field_type_id
  left join public.cities c on c.id = f.city_id
  where f.id = p_field_id
    and f.player_id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.get_field_list_items()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'field', to_jsonb(f),
        'city_name', c.name,
        'field_type_name', coalesce(ft.name, 'Bilinmeyen Ciftlik'),
        'field_type_icon', coalesce(ft.icon, 'field.webp'),
        'output_stock_quantity',
          coalesce((
            select sum(pi.quantity)::int
            from public.production_inventory pi
            where pi.owner_kind = 'field'
              and pi.owner_id = f.id
              and pi.inventory_type = 'output'
          ), 0),
        'slots',
          coalesce((
            select jsonb_agg(
              to_jsonb(ps) || jsonb_build_object(
                'product',
                case when p.id is null then null else to_jsonb(p) end
              )
              order by ps.slot_index
            )
            from public.production_slots ps
            left join public.products p on p.id = ps.product_id
            where ps.owner_kind = 'field'
              and ps.owner_id = f.id
          ), '[]'::jsonb)
      )
      order by f.created_at
    ),
    '[]'::jsonb
  )
  from public.fields f
  left join public.cities c on c.id = f.city_id
  left join public.field_types ft on ft.id = f.field_type_id
  where f.player_id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.get_field_types_catalog()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(to_jsonb(ft) order by ft.required_level, ft.cost),
    '[]'::jsonb
  )
  from public.field_types ft;
$function$
;

CREATE OR REPLACE FUNCTION public.get_logistics_company_types_catalog()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(to_jsonb(lct) order by lct.required_level, lct.cost),
    '[]'::jsonb
  )
  from public.logistics_company_types lct;
$function$
;

CREATE OR REPLACE FUNCTION public.get_logistics_vehicle_types_catalog()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(to_jsonb(lvt) order by lvt.purchase_price),
    '[]'::jsonb
  )
  from public.logistics_vehicle_types lvt;
$function$
;

CREATE OR REPLACE FUNCTION public.get_market_buyer_store_slot_detail(p_store_slot_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select (
    to_jsonb(ss) ||
    jsonb_build_object(
      'store',
      (
        select
          to_jsonb(s) ||
          jsonb_build_object(
            'city',
            (
              select jsonb_build_object(
                'id', c.id,
                'name', c.name,
                'map_position_x', c.map_position_x,
                'map_position_y', c.map_position_y
              )
              from public.cities c
              where c.id = s.city_id
            )
          )
        from public.stores s
        where s.id = ss.store_id
      )
    )
  )
  from public.store_slots ss
  join public.stores owner_store on owner_store.id = ss.store_id
  where ss.id = p_store_slot_id
    and owner_store.player_id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.get_market_buyer_warehouse_detail(p_warehouse_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select (
    to_jsonb(w) ||
    jsonb_build_object(
      'city',
      (
        select jsonb_build_object(
          'name', c.name,
          'map_position_x', c.map_position_x,
          'map_position_y', c.map_position_y
        )
        from public.cities c
        where c.id = w.city_id
      ),
      'warehouse_type',
      (
        select jsonb_build_object('icon', wt.icon)
        from public.warehouse_types wt
        where wt.id = w.warehouse_type_id
      )
    )
  )
  from public.warehouses w
  where w.id = p_warehouse_id
    and w.player_id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.get_market_listings_for_product(p_product_id text)
 RETURNS TABLE(slot_id uuid, warehouse_id uuid, warehouse_name text, warehouse_icon text, city_id uuid, city_name text, city_x numeric, city_y numeric, seller_player_id uuid, quantity integer, quality_level integer, price numeric, cost numeric, is_available_for_sale boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    ws.id as slot_id,
    w.id as warehouse_id,
    w.name as warehouse_name,
    wt.icon as warehouse_icon,
    c.id as city_id,
    c.name as city_name,
    c.map_position_x as city_x,
    c.map_position_y as city_y,
    w.player_id as seller_player_id,
    ws.quantity,
    ws.quality_level,
    ws.price,
    ws.cost,
    ws.is_available_for_sale
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  left join public.warehouse_types wt on wt.id = w.warehouse_type_id
  left join public.cities c on c.id = w.city_id
  where ws.product_id = p_product_id
    and ws.is_available_for_sale = true
    and ws.quantity > 0
    and coalesce(ws.price, 0) > 0
    and w.is_active = true
    and w.player_id <> auth.uid()
  order by ws.price asc, ws.quality_level desc, ws.quantity desc, ws.updated_at desc;
$function$
;

CREATE OR REPLACE FUNCTION public.get_market_product_detail(p_product_id text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select to_jsonb(p)
  from public.products p
  where p.id = p_product_id;
$function$
;

CREATE OR REPLACE FUNCTION public.get_market_transfer_vehicle_options(p_buyer_warehouse_id uuid, p_seller_slot_id uuid, p_quantity integer)
 RETURNS TABLE(vehicle_id uuid, vehicle_owner_player_id uuid, vehicle_name text, is_rental boolean, capacity integer, speed_kmh integer, current_fuel integer, fuel_capacity integer, fuel_rate numeric, condition integer, rental_price numeric, distance_km numeric, fuel_needed numeric, condition_needed numeric, rental_cost numeric, estimated_duration_seconds integer, can_select boolean, disabled_reason text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_buyer_id uuid := auth.uid();
  v_buyer_warehouse record;
  v_seller_slot record;
  v_product record;
  v_distance_km numeric := 0;
  v_required_capacity numeric := 0;
begin
  if v_buyer_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select w.*, c.map_position_x as city_x, c.map_position_y as city_y
  into v_buyer_warehouse
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id
    and w.player_id = v_buyer_id;

  if not found then
    raise exception 'Alici deposu bulunamadi veya size ait degil.';
  end if;

  select ws.*, w.player_id as seller_player_id, w.city_id as seller_city_id, c.map_position_x as city_x, c.map_position_y as city_y
  into v_seller_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  join public.cities c on c.id = w.city_id
  where ws.id = p_seller_slot_id
    and ws.is_available_for_sale = true;

  if not found then
    raise exception 'Satici slotu bulunamadi.';
  end if;

  if v_seller_slot.seller_player_id = v_buyer_id then
    raise exception 'Kendi ilaninizi satin alamazsiniz.';
  end if;

  if p_quantity > v_seller_slot.quantity then
    raise exception 'Istenen miktar mevcut stoktan fazla.';
  end if;

  select * into v_product
  from public.products
  where id = v_seller_slot.product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_seller_slot.city_x - v_buyer_warehouse.city_x) / 2)), 2) +
      cos(radians(v_buyer_warehouse.city_x)) *
      cos(radians(v_seller_slot.city_x)) *
      power(sin(radians((v_seller_slot.city_y - v_buyer_warehouse.city_y) / 2)), 2)
    )
  );

  return query
  with candidates as (
    select
      lv.id as vehicle_id,
      lv.player_id as vehicle_owner_player_id,
      lvt.name as vehicle_name,
      (lv.player_id <> v_buyer_id) as is_rental,
      lv.capacity,
      lv.speed_kmh,
      lv.current_fuel,
      lv.fuel_capacity,
      lv.fuel_rate,
      lv.condition,
      lv.rental_price,
      v_distance_km as distance_km,
      ceil(v_distance_km * lv.fuel_rate) as fuel_needed,
      ceil(v_distance_km * 0.02) as condition_needed,
      case
        when lv.player_id <> v_buyer_id then ceil(v_distance_km * lv.rental_price)
        else 0
      end as rental_cost,
      greatest(1, ceil(((v_distance_km / greatest(lv.speed_kmh, 1)) / 4.0) * 3600))::integer as estimated_duration_seconds,
      lv.status,
      lv.is_available_for_rent,
      lc.is_active as company_is_active,
      public.logistics_vehicle_matches_route(lv.route_city_a_id, lv.route_city_b_id, v_seller_slot.seller_city_id, v_buyer_warehouse.city_id) as route_matches
    from public.logistics_vehicles lv
    join public.logistics_vehicle_types lvt on lvt.id = lv.logistics_vehicle_type_id
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where lv.player_id <> v_seller_slot.seller_player_id
      and (
        lv.player_id = v_buyer_id
        or (lv.player_id <> v_buyer_id and lv.is_available_for_rent = true)
      )
  )
  select
    c.vehicle_id,
    c.vehicle_owner_player_id,
    c.vehicle_name,
    c.is_rental,
    c.capacity,
    c.speed_kmh,
    c.current_fuel,
    c.fuel_capacity,
    c.fuel_rate,
    c.condition,
    c.rental_price,
    c.distance_km,
    c.fuel_needed,
    c.condition_needed,
    c.rental_cost,
    c.estimated_duration_seconds,
    (
      c.route_matches = true
      and c.status = 'idle'
      and c.company_is_active = true
      and c.capacity >= v_required_capacity
      and c.current_fuel >= c.fuel_needed
      and c.condition > c.condition_needed
    ) as can_select,
    case
      when c.route_matches is not true then 'Aracin rotasi bu sehir ciftini desteklemiyor.'
      when c.status <> 'idle' then 'Arac su anda uygun degil.'
      when c.company_is_active = false then 'Nakliye firmasi aktif degil.'
      when c.capacity < v_required_capacity then 'Kapasite yetersiz.'
      when c.current_fuel < c.fuel_needed then 'Yakit yetersiz.'
      when c.condition <= c.condition_needed then 'Kondisyon yetersiz.'
      else null
    end as disabled_reason
  from candidates c
  order by c.is_rental asc, can_select desc, c.capacity asc, c.rental_price asc, c.vehicle_name asc;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_market_transfer_vehicle_options_for_store(p_store_slot_id uuid, p_seller_slot_id uuid, p_quantity integer)
 RETURNS TABLE(vehicle_id uuid, vehicle_owner_player_id uuid, vehicle_name text, is_rental boolean, capacity integer, speed_kmh integer, current_fuel integer, fuel_capacity integer, fuel_rate numeric, condition integer, rental_price numeric, distance_km numeric, fuel_needed numeric, condition_needed numeric, rental_cost numeric, estimated_duration_seconds integer, can_select boolean, disabled_reason text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_buyer_id uuid := auth.uid();
  v_store_slot record;
  v_seller_slot record;
  v_product record;
  v_distance_km numeric := 0;
  v_required_capacity numeric := 0;
begin
  if v_buyer_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select ss.*, s.player_id, s.is_active as store_is_active, s.city_id as store_city_id, c.map_position_x as city_x, c.map_position_y as city_y
  into v_store_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  join public.cities c on c.id = s.city_id
  where ss.id = p_store_slot_id;

  if not found or v_store_slot.player_id <> v_buyer_id then
    raise exception 'Magaza slotu bulunamadi veya size ait degil.';
  end if;

  if v_store_slot.store_is_active is not true then
    raise exception 'Magaza aktif degil.';
  end if;

  select ws.*, w.player_id as seller_player_id, w.city_id as seller_city_id, c.map_position_x as city_x, c.map_position_y as city_y
  into v_seller_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  join public.cities c on c.id = w.city_id
  where ws.id = p_seller_slot_id
    and ws.is_available_for_sale = true;

  if not found then
    raise exception 'Satici slotu bulunamadi.';
  end if;

  if v_seller_slot.seller_player_id = v_buyer_id then
    raise exception 'Kendi ilaninizi satin alamazsiniz.';
  end if;

  if p_quantity > v_seller_slot.quantity then
    raise exception 'Istenen miktar mevcut stoktan fazla.';
  end if;

  if v_store_slot.product_id is not null and v_store_slot.quality_level > 0 and (
    v_store_slot.product_id <> v_seller_slot.product_id
    or v_store_slot.quality_level <> v_seller_slot.quality_level
  ) and (v_store_slot.quantity > 0 or coalesce(v_store_slot.pending_quantity, 0) > 0) then
    raise exception 'Slotta farkli urun veya kalite icin aktif stok/rezerve var.';
  end if;

  if (coalesce(v_store_slot.quantity, 0) + coalesce(v_store_slot.pending_quantity, 0) + p_quantity) > v_store_slot.capacity then
    raise exception 'Magaza slot kapasitesi yetersiz.';
  end if;

  select * into v_product
  from public.products
  where id = v_seller_slot.product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_seller_slot.city_x - v_store_slot.city_x) / 2)), 2) +
      cos(radians(v_store_slot.city_x)) *
      cos(radians(v_seller_slot.city_x)) *
      power(sin(radians((v_seller_slot.city_y - v_store_slot.city_y) / 2)), 2)
    )
  );

  return query
  with candidates as (
    select
      lv.id as vehicle_id,
      lv.player_id as vehicle_owner_player_id,
      lvt.name as vehicle_name,
      (lv.player_id <> v_buyer_id) as is_rental,
      lv.capacity,
      lv.speed_kmh,
      lv.current_fuel,
      lv.fuel_capacity,
      lv.fuel_rate,
      lv.condition,
      lv.rental_price,
      v_distance_km as distance_km,
      ceil(v_distance_km * lv.fuel_rate) as fuel_needed,
      ceil(v_distance_km * 0.02) as condition_needed,
      case when lv.player_id <> v_buyer_id then ceil(v_distance_km * lv.rental_price) else 0 end as rental_cost,
      greatest(1, ceil(((v_distance_km / greatest(lv.speed_kmh, 1)) / 4.0) * 3600))::integer as estimated_duration_seconds,
      lv.status,
      lv.is_available_for_rent,
      lc.is_active as company_is_active,
      public.logistics_vehicle_matches_route(lv.route_city_a_id, lv.route_city_b_id, v_seller_slot.seller_city_id, v_store_slot.store_city_id) as route_matches
    from public.logistics_vehicles lv
    join public.logistics_vehicle_types lvt on lvt.id = lv.logistics_vehicle_type_id
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where lv.player_id <> v_seller_slot.seller_player_id
      and (
        lv.player_id = v_buyer_id
        or (lv.player_id <> v_buyer_id and lv.is_available_for_rent = true)
      )
  )
  select
    c.vehicle_id,
    c.vehicle_owner_player_id,
    c.vehicle_name,
    c.is_rental,
    c.capacity,
    c.speed_kmh,
    c.current_fuel,
    c.fuel_capacity,
    c.fuel_rate,
    c.condition,
    c.rental_price,
    c.distance_km,
    c.fuel_needed,
    c.condition_needed,
    c.rental_cost,
    c.estimated_duration_seconds,
    (
      c.route_matches = true
      and c.status = 'idle'
      and c.company_is_active = true
      and c.capacity >= v_required_capacity
      and c.current_fuel >= c.fuel_needed
      and c.condition > c.condition_needed
    ) as can_select,
    case
      when c.route_matches is not true then 'Aracin rotasi bu sehir ciftini desteklemiyor.'
      when c.status <> 'idle' then 'Arac su anda uygun degil.'
      when c.company_is_active = false then 'Nakliye firmasi aktif degil.'
      when c.capacity < v_required_capacity then 'Kapasite yetersiz.'
      when c.current_fuel < c.fuel_needed then 'Yakit yetersiz.'
      when c.condition <= c.condition_needed then 'Kondisyon yetersiz.'
      else null
    end as disabled_reason
  from candidates c
  order by c.is_rental asc, can_select desc, c.capacity asc, c.rental_price asc, c.vehicle_name asc;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_mine_detail_data(p_mine_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'mine', to_jsonb(m),
    'mine_type', to_jsonb(mt),
    'city_name', coalesce(c.name, 'Bilinmeyen Sehir'),
    'product', case when p.id is null then null else to_jsonb(p) end,
    'inventories',
      coalesce((
        select jsonb_agg(
          to_jsonb(pi) || jsonb_build_object(
            'product',
            case when prod.id is null then null else to_jsonb(prod) end
          )
          order by pi.id
        )
        from public.production_inventory pi
        left join public.products prod on prod.id = pi.product_id
        where pi.owner_kind = 'mine'
          and pi.owner_id = m.id
      ), '[]'::jsonb)
  )
  from public.mines m
  left join public.mine_types mt on mt.id = m.mine_type_id
  left join public.cities c on c.id = m.city_id
  left join public.products p on p.id = m.product_id
  where m.id = p_mine_id
    and m.player_id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.get_mine_list_items()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'mine', to_jsonb(m),
        'city_name', c.name,
        'mine_type_name', coalesce(mt.name, 'Bilinmeyen Maden'),
        'mine_type_icon', coalesce(mt.icon, 'mine.webp'),
        'output_stock_quantity',
          coalesce((
            select sum(pi.quantity)::int
            from public.production_inventory pi
            where pi.owner_kind = 'mine'
              and pi.owner_id = m.id
              and pi.inventory_type = 'output'
          ), 0),
        'selected_product',
          case when p.id is null then null else to_jsonb(p) end
      )
      order by m.created_at
    ),
    '[]'::jsonb
  )
  from public.mines m
  left join public.cities c on c.id = m.city_id
  left join public.mine_types mt on mt.id = m.mine_type_id
  left join public.products p on p.id = m.product_id
  where m.player_id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.get_mine_types_catalog()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(to_jsonb(mt) order by mt.required_level, mt.cost),
    '[]'::jsonb
  )
  from public.mine_types mt;
$function$
;

CREATE OR REPLACE FUNCTION public.get_player_active_warehouses_basic()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(
      (
        to_jsonb(w) ||
        jsonb_build_object(
          'city',
          (
            select jsonb_build_object('name', c.name)
            from public.cities c
            where c.id = w.city_id
          )
        )
      )
      order by w.created_at
    ),
    '[]'::jsonb
  )
  from public.warehouses w
  where w.player_id = auth.uid()
    and w.is_active = true;
$function$
;

CREATE OR REPLACE FUNCTION public.get_player_active_warehouses_with_slots(p_city_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(
      (
        to_jsonb(w) ||
        jsonb_build_object(
          'city',
          (
            select jsonb_build_object('name', c.name)
            from public.cities c
            where c.id = w.city_id
          ),
          'warehouse_slots',
          coalesce(
            (
              select jsonb_agg(
                to_jsonb(ws) ||
                jsonb_build_object('product', to_jsonb(p))
                order by ws.id
              )
              from public.warehouse_slots ws
              left join public.products p on p.id = ws.product_id
              where ws.warehouse_id = w.id
            ),
            '[]'::jsonb
          )
        )
      )
      order by w.created_at
    ),
    '[]'::jsonb
  )
  from public.warehouses w
  where w.player_id = auth.uid()
    and w.is_active = true
    and (p_city_id is null or w.city_id = p_city_id);
$function$
;

CREATE OR REPLACE FUNCTION public.get_player_building_constructions(p_building_kind text, p_status text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(to_jsonb(bc) order by bc.started_at),
    '[]'::jsonb
  )
  from public.building_constructions bc
  where bc.player_id = auth.uid()
    and bc.building_kind = p_building_kind
    and (p_status is null or bc.status = p_status);
$function$
;

CREATE OR REPLACE FUNCTION public.get_player_logistics_company()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select to_jsonb(lc)
  from public.logistics_companies lc
  where lc.player_id = auth.uid()
  order by lc.created_at
  limit 1;
$function$
;

CREATE OR REPLACE FUNCTION public.get_player_logistics_vehicle_performance()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(to_jsonb(stats) order by stats.last_activity_at desc nulls last),
    '[]'::jsonb
  )
  from (
    select
      lt.logistics_vehicle_id as vehicle_id,
      count(*)::int as total_trips,
      count(*) filter (where lt.status = 'completed')::int as completed_trips,
      count(*) filter (where lt.status = 'in_transit')::int as active_trips,
      count(*) filter (where lt.is_rental = true)::int as rental_trips,
      coalesce(sum(case when lt.is_rental then lt.rental_cost else 0 end), 0)::double precision as rental_revenue,
      max(coalesce(lt.completed_at, lt.finish_at, lt.started_at)) as last_activity_at
    from public.logistics_transfers lt
    where lt.vehicle_owner_player_id = auth.uid()
      and lt.logistics_vehicle_id is not null
    group by lt.logistics_vehicle_id
  ) stats;
$function$
;

CREATE OR REPLACE FUNCTION public.get_player_warehouse_detail(p_warehouse_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select (
    to_jsonb(w) ||
    jsonb_build_object(
      'warehouse_slots',
      coalesce(
        (
          select jsonb_agg(
            to_jsonb(ws) ||
            jsonb_build_object('product', to_jsonb(p))
            order by ws.id
          )
          from public.warehouse_slots ws
          left join public.products p on p.id = ws.product_id
          where ws.warehouse_id = w.id
        ),
        '[]'::jsonb
      ),
      'city',
      (
        select to_jsonb(c)
        from public.cities c
        where c.id = w.city_id
      ),
      'warehouse_type',
      (
        select to_jsonb(wt)
        from public.warehouse_types wt
        where wt.id = w.warehouse_type_id
      )
    )
  )
  from public.warehouses w
  where w.id = p_warehouse_id
    and w.player_id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.get_player_warehouses_raw()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(
      (
        to_jsonb(w) ||
        jsonb_build_object(
          'warehouse_slots',
          coalesce(
            (
              select jsonb_agg(
                to_jsonb(ws) ||
                jsonb_build_object('product', to_jsonb(p))
                order by ws.id
              )
              from public.warehouse_slots ws
              left join public.products p on p.id = ws.product_id
              where ws.warehouse_id = w.id
            ),
            '[]'::jsonb
          ),
          'city',
          (
            select to_jsonb(c)
            from public.cities c
            where c.id = w.city_id
          ),
          'warehouse_type',
          (
            select to_jsonb(wt)
            from public.warehouse_types wt
            where wt.id = w.warehouse_type_id
          )
        )
      )
      order by w.created_at
    ),
    '[]'::jsonb
  )
  from public.warehouses w
  where w.player_id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.get_producible_products_for_owner_type(p_player_id uuid, p_owner_kind text, p_type_id uuid)
 RETURNS TABLE(id text, urun_adi text, urun_iconu text, birim_hacim numeric, birim_agirlik numeric, hammadde_1_id text, hammadde_1_miktar numeric, hammadde_2_id text, hammadde_2_miktar numeric, hammadde_3_id text, hammadde_3_miktar numeric, uretim_birimi text, baz_satis_fiyati numeric, uretim_adedi integer, satis_adedi integer, en_dusuk_fiyat numeric, en_yuksek_fiyat numeric, ortalama_fiyat numeric, satici_sayisi integer, piyasadaki_stok integer, created_at timestamp with time zone, max_quality_level integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_owner_kind text := lower(trim(coalesce(p_owner_kind, '')));
  v_accepted_product_ids text;
  v_allowed_units text[];
  v_auth_player_id uuid;
begin
  v_auth_player_id := auth.uid();

  if v_auth_player_id is null then
    raise exception 'Oturum bulunamadi.';
  end if;

  if p_player_id is null or p_player_id <> v_auth_player_id then
    raise exception 'Gecersiz oyuncu kimligi.';
  end if;

  if p_type_id is null then
    raise exception 'Isletme turu bos olamaz.';
  end if;

  case v_owner_kind
    when 'field' then
      select ft.accepted_product_ids
      into v_accepted_product_ids
      from public.field_types ft
      where ft.id = p_type_id;

      v_allowed_units := array['farm', 'ciftlik', 'çiftlik'];

    when 'farm' then
      select ft.accepted_product_ids
      into v_accepted_product_ids
      from public.farm_types ft
      where ft.id = p_type_id;

      v_allowed_units := array['field', 'tarla'];

    when 'factory' then
      select ft.accepted_product_ids
      into v_accepted_product_ids
      from public.factory_types ft
      where ft.id = p_type_id;

      v_allowed_units := array['factory', 'fabrika'];

    when 'mine' then
      select mt.accepted_product_ids
      into v_accepted_product_ids
      from public.mine_types mt
      where mt.id = p_type_id;

      v_allowed_units := array['mine', 'maden'];

    else
      raise exception 'Desteklenmeyen owner_kind: %', p_owner_kind;
  end case;

  if not found then
    raise exception 'Isletme turu bulunamadi.';
  end if;

  if coalesce(trim(v_accepted_product_ids), '') = '' then
    return;
  end if;

  return query
  with quality_levels as (
    select
      ppql.product_id,
      max(ppql.max_quality_level)::integer as max_quality_level
    from public.player_product_quality_levels ppql
    where ppql.player_id = p_player_id
    group by ppql.product_id
  )
  select
    p.id,
    p.urun_adi,
    p.urun_iconu,
    p.birim_hacim,
    p.birim_agirlik,
    p.hammadde_1_id,
    p.hammadde_1_miktar,
    p.hammadde_2_id,
    p.hammadde_2_miktar,
    p.hammadde_3_id,
    p.hammadde_3_miktar,
    p.uretim_birimi,
    p.baz_satis_fiyati,
    p.uretim_adedi,
    p.satis_adedi,
    p.en_dusuk_fiyat,
    p.en_yuksek_fiyat,
    p.ortalama_fiyat,
    p.satici_sayisi,
    p.piyasadaki_stok,
    p.created_at,
    coalesce(ql.max_quality_level, 1) as max_quality_level
  from public.products p
  left join quality_levels ql on ql.product_id = p.id
  where p.id = any(regexp_split_to_array(v_accepted_product_ids, '\s*,\s*'))
    and lower(trim(coalesce(p.uretim_birimi, ''))) = any(v_allowed_units)
  order by p.urun_adi asc;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_production_input_transfer_vehicle_options(p_warehouse_slot_id uuid, p_production_inventory_id uuid, p_quantity integer)
 RETURNS TABLE(vehicle_id uuid, vehicle_owner_player_id uuid, vehicle_name text, is_rental boolean, capacity integer, speed_kmh integer, current_fuel integer, fuel_capacity integer, fuel_rate numeric, condition integer, rental_price numeric, distance_km numeric, fuel_needed numeric, condition_needed numeric, rental_cost numeric, estimated_duration_seconds integer, can_select boolean, disabled_reason text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_warehouse_slot record;
  v_inventory record;
  v_owner_city_id uuid;
  v_owner_player_id uuid;
  v_target_city record;
  v_product record;
  v_required_capacity numeric := 0;
  v_distance_km numeric := 0;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select
    ws.*,
    w.player_id,
    w.id as warehouse_id,
    w.city_id,
    w.is_active as warehouse_is_active,
    c.map_position_x as city_x,
    c.map_position_y as city_y
  into v_warehouse_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  join public.cities c on c.id = w.city_id
  where ws.id = p_warehouse_slot_id;

  if not found or v_warehouse_slot.player_id <> v_player_id then
    raise exception 'Depo slotu bulunamadi veya size ait degil.';
  end if;

  if v_warehouse_slot.warehouse_is_active is not true then
    raise exception 'Kaynak depo aktif degil.';
  end if;

  if p_quantity > coalesce(v_warehouse_slot.quantity, 0) then
    raise exception 'Istenen miktar mevcut stoktan fazla.';
  end if;

  select *
  into v_inventory
  from public.production_inventory
  where id = p_production_inventory_id;

  if not found then
    raise exception 'Production inventory bulunamadi.';
  end if;

  if v_inventory.inventory_type <> 'input' then
    raise exception 'Sadece input inventory icin hammadde lojistigi desteklenir.';
  end if;

  if v_inventory.owner_kind not in ('factory', 'field', 'farm') then
    raise exception 'Bu owner_kind icin input lojistigi desteklenmiyor: %', v_inventory.owner_kind;
  end if;

  if v_inventory.owner_kind = 'factory' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.factories
    where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'field' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.fields
    where id = v_inventory.owner_id;
  else
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.farms
    where id = v_inventory.owner_id;
  end if;

  if v_owner_player_id is null then
    raise exception 'Hedef uretim birimi bulunamadi.';
  end if;

  if v_owner_player_id <> v_player_id then
    raise exception 'Hedef uretim birimi size ait degil.';
  end if;

  if v_inventory.product_id <> v_warehouse_slot.product_id then
    raise exception 'Depo slotundaki urun ile input inventory urunu ayni olmalidir.';
  end if;

  if v_inventory.quality_level <> v_warehouse_slot.quality_level then
    raise exception 'Depo slotundaki kalite ile input inventory kalitesi ayni olmalidir.';
  end if;

  select *
  into v_product
  from public.products
  where id = v_warehouse_slot.product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  select * into v_target_city from public.cities where id = v_owner_city_id;
  if not found then
    raise exception 'Hedef sehir bulunamadi.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_warehouse_slot.city_x - v_target_city.map_position_x) / 2)), 2)
      +
      cos(radians(v_target_city.map_position_x)) *
      cos(radians(v_warehouse_slot.city_x)) *
      power(sin(radians((v_warehouse_slot.city_y - v_target_city.map_position_y) / 2)), 2)
    )
  );

  return query
  with candidates as (
    select
      lv.id as vehicle_id,
      lv.player_id as vehicle_owner_player_id,
      lvt.name as vehicle_name,
      (lv.player_id <> v_player_id) as is_rental,
      lv.capacity,
      lv.speed_kmh,
      lv.current_fuel,
      lv.fuel_capacity,
      lv.fuel_rate,
      lv.condition,
      lv.rental_price,
      v_distance_km as distance_km,
      ceil(v_distance_km * lv.fuel_rate) as fuel_needed,
      ceil(v_distance_km * 0.02) as condition_needed,
      case when lv.player_id <> v_player_id then ceil(v_distance_km * lv.rental_price) else 0 end as rental_cost,
      greatest(1, ceil(((v_distance_km / greatest(lv.speed_kmh, 1)) / 4.0) * 3600))::integer as estimated_duration_seconds,
      lv.status,
      lc.is_active as company_is_active,
      public.logistics_vehicle_matches_route(lv.route_city_a_id, lv.route_city_b_id, v_warehouse_slot.city_id, v_owner_city_id) as route_matches
    from public.logistics_vehicles lv
    join public.logistics_vehicle_types lvt on lvt.id = lv.logistics_vehicle_type_id
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where lv.player_id = v_player_id
       or (lv.player_id <> v_player_id and lv.is_available_for_rent = true)
  )
  select
    c.vehicle_id,
    c.vehicle_owner_player_id,
    c.vehicle_name,
    c.is_rental,
    c.capacity,
    c.speed_kmh,
    c.current_fuel,
    c.fuel_capacity,
    c.fuel_rate,
    c.condition,
    c.rental_price,
    c.distance_km,
    c.fuel_needed,
    c.condition_needed,
    c.rental_cost,
    c.estimated_duration_seconds,
    (
      c.route_matches = true
      and c.status = 'idle'
      and c.company_is_active = true
      and c.capacity >= v_required_capacity
      and c.current_fuel >= c.fuel_needed
      and c.condition > c.condition_needed
    ) as can_select,
    case
      when c.route_matches is not true then 'Aracin rotasi bu sehir ciftini desteklemiyor.'
      when c.status <> 'idle' then 'Arac su anda uygun degil.'
      when c.company_is_active = false then 'Nakliye firmasi aktif degil.'
      when c.capacity < v_required_capacity then 'Kapasite yetersiz.'
      when c.current_fuel < c.fuel_needed then 'Yakit yetersiz.'
      when c.condition <= c.condition_needed then 'Kondisyon yetersiz.'
      else null
    end as disabled_reason
  from candidates c
  order by c.is_rental asc, can_select desc, c.capacity asc, c.rental_price asc, c.vehicle_name asc;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_production_output_transfer_vehicle_options(p_production_inventory_id uuid, p_buyer_warehouse_id uuid, p_quantity integer)
 RETURNS TABLE(vehicle_id uuid, vehicle_owner_player_id uuid, vehicle_name text, is_rental boolean, capacity integer, speed_kmh integer, current_fuel integer, fuel_capacity integer, fuel_rate numeric, condition integer, rental_price numeric, distance_km numeric, fuel_needed numeric, condition_needed numeric, rental_cost numeric, estimated_duration_seconds integer, can_select boolean, disabled_reason text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_inventory record;
  v_owner_city_id uuid;
  v_owner_player_id uuid;
  v_source_city record;
  v_buyer_warehouse record;
  v_product record;
  v_required_capacity numeric := 0;
  v_distance_km numeric := 0;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select *
  into v_inventory
  from public.production_inventory
  where id = p_production_inventory_id;

  if not found then
    raise exception 'Production inventory bulunamadi.';
  end if;

  if v_inventory.inventory_type <> 'output' then
    raise exception 'Sadece output inventory icin output lojistigi desteklenir.';
  end if;

  if v_inventory.owner_kind not in ('factory', 'field', 'farm', 'mine') then
    raise exception 'Bu owner_kind icin output lojistigi desteklenmiyor: %', v_inventory.owner_kind;
  end if;

  if coalesce(v_inventory.quantity, 0) < p_quantity then
    raise exception 'Istenen miktar mevcut output stoktan fazla.';
  end if;

  if v_inventory.owner_kind = 'factory' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.factories
    where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'field' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.fields
    where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'farm' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.farms
    where id = v_inventory.owner_id;
  else
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.mines
    where id = v_inventory.owner_id;
  end if;

  if v_owner_player_id is null then
    raise exception 'Kaynak uretim birimi bulunamadi.';
  end if;

  if v_owner_player_id <> v_player_id then
    raise exception 'Kaynak uretim birimi size ait degil.';
  end if;

  select
    w.*,
    c.map_position_x as city_x,
    c.map_position_y as city_y
  into v_buyer_warehouse
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id
    and w.player_id = v_player_id;

  if not found then
    raise exception 'Hedef depo bulunamadi veya size ait degil.';
  end if;

  if v_buyer_warehouse.is_active is not true then
    raise exception 'Hedef depo aktif degil.';
  end if;

  select *
  into v_product
  from public.products
  where id = v_inventory.product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  select * into v_source_city from public.cities where id = v_owner_city_id;
  if not found then
    raise exception 'Kaynak sehir bulunamadi.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_source_city.map_position_x - v_buyer_warehouse.city_x) / 2)), 2)
      +
      cos(radians(v_buyer_warehouse.city_x)) *
      cos(radians(v_source_city.map_position_x)) *
      power(sin(radians((v_source_city.map_position_y - v_buyer_warehouse.city_y) / 2)), 2)
    )
  );

  return query
  with candidates as (
    select
      lv.id as vehicle_id,
      lv.player_id as vehicle_owner_player_id,
      lvt.name as vehicle_name,
      (lv.player_id <> v_player_id) as is_rental,
      lv.capacity,
      lv.speed_kmh,
      lv.current_fuel,
      lv.fuel_capacity,
      lv.fuel_rate,
      lv.condition,
      lv.rental_price,
      v_distance_km as distance_km,
      ceil(v_distance_km * lv.fuel_rate) as fuel_needed,
      ceil(v_distance_km * 0.02) as condition_needed,
      case when lv.player_id <> v_player_id then ceil(v_distance_km * lv.rental_price) else 0 end as rental_cost,
      greatest(1, ceil(((v_distance_km / greatest(lv.speed_kmh, 1)) / 4.0) * 3600))::integer as estimated_duration_seconds,
      lv.status,
      lc.is_active as company_is_active,
      public.logistics_vehicle_matches_route(lv.route_city_a_id, lv.route_city_b_id, v_owner_city_id, v_buyer_warehouse.city_id) as route_matches
    from public.logistics_vehicles lv
    join public.logistics_vehicle_types lvt on lvt.id = lv.logistics_vehicle_type_id
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where lv.player_id = v_player_id
       or (lv.player_id <> v_player_id and lv.is_available_for_rent = true)
  )
  select
    c.vehicle_id,
    c.vehicle_owner_player_id,
    c.vehicle_name,
    c.is_rental,
    c.capacity,
    c.speed_kmh,
    c.current_fuel,
    c.fuel_capacity,
    c.fuel_rate,
    c.condition,
    c.rental_price,
    c.distance_km,
    c.fuel_needed,
    c.condition_needed,
    c.rental_cost,
    c.estimated_duration_seconds,
    (
      c.route_matches = true
      and c.status = 'idle'
      and c.company_is_active = true
      and c.capacity >= v_required_capacity
      and c.current_fuel >= c.fuel_needed
      and c.condition > c.condition_needed
    ) as can_select,
    case
      when c.route_matches is not true then 'Aracin rotasi bu sehir ciftini desteklemiyor.'
      when c.status <> 'idle' then 'Arac su anda uygun degil.'
      when c.company_is_active = false then 'Nakliye firmasi aktif degil.'
      when c.capacity < v_required_capacity then 'Kapasite yetersiz.'
      when c.current_fuel < c.fuel_needed then 'Yakit yetersiz.'
      when c.condition <= c.condition_needed then 'Kondisyon yetersiz.'
      else null
    end as disabled_reason
  from candidates c
  order by c.is_rental asc, can_select desc, c.capacity asc, c.rental_price asc, c.vehicle_name asc;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_store_daily_performance(p_player_id uuid, p_store_id uuid, p_days integer DEFAULT 14)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_store_id uuid;
  v_rows jsonb := '[]'::jsonb;
  v_summary jsonb;
  v_from_date date := timezone('Europe/Istanbul', now())::date - greatest(coalesce(p_days, 14), 1) + 1;
begin
  select s.id into v_store_id
  from stores s
  where s.id = p_store_id
    and s.player_id = p_player_id;

  if v_store_id is null then
    return jsonb_build_object(
      'success', false,
      'message', 'Magaza bulunamadi.'
    );
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'performance_date', perf.performance_date,
        'store_slot_id', perf.store_slot_id,
        'slot_index', perf.slot_index,
        'product_id', perf.product_id,
        'product_name', perf.product_name,
        'quality_level', perf.quality_level,
        'sold_quantity', perf.sold_quantity,
        'revenue', perf.revenue,
        'profit', perf.profit,
        'sale_event_count', perf.sale_event_count,
        'last_sale_at', perf.last_sale_at
      )
      order by perf.performance_date desc, perf.slot_index asc
    ),
    '[]'::jsonb
  ) into v_rows
  from public.store_daily_performance perf
  where perf.store_id = p_store_id
    and perf.performance_date >= v_from_date;

  select jsonb_build_object(
    'total_revenue', coalesce(sum(perf.revenue), 0),
    'total_profit', coalesce(sum(perf.profit), 0),
    'total_sold_quantity', coalesce(sum(perf.sold_quantity), 0),
    'total_sale_events', coalesce(sum(perf.sale_event_count), 0)
  ) into v_summary
  from public.store_daily_performance perf
  where perf.store_id = p_store_id
    and perf.performance_date >= v_from_date;

  return jsonb_build_object(
    'success', true,
    'summary', v_summary,
    'rows', v_rows
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_store_detail(p_player_id uuid, p_store_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    case
      when s.id is null then
        jsonb_build_object(
          'success', false,
          'message', 'Magaza bulunamadi veya oyuncuya ait degil.',
          'player_id', p_player_id,
          'store_id', p_store_id
        )
      else
        jsonb_build_object(
          'success', true,
          'player_id', p_player_id,
          'store', jsonb_build_object(
            'id', s.id,
            'player_id', s.player_id,
            'name', s.name,
            'level', s.level,
            'is_active', s.is_active,
            'current_slot_count', s.current_slot_count,
            'max_slot_count', s.max_slot_count,
            'slot_capacity', s.slot_capacity,
            'city', jsonb_build_object(
              'id', c.id,
              'name', c.name
            ),
            'store_type', jsonb_build_object(
              'id', st.id,
              'name', st.name,
              'icon', st.icon
            ),
            'summary', jsonb_build_object(
              'slot_count', coalesce(slot_data.slot_count, 0),
              'active_slot_count', coalesce(slot_data.active_slot_count, 0),
              'filled_slot_count', coalesce(slot_data.filled_slot_count, 0),
              'empty_slot_count', greatest(
                coalesce(slot_data.slot_count, 0)
                - coalesce(slot_data.filled_slot_count, 0),
                0
              ),
              'total_quantity', coalesce(slot_data.total_quantity, 0),
              'total_capacity', coalesce(slot_data.total_capacity, 0),
              'pending_quantity', coalesce(slot_data.pending_quantity, 0),
              'available_capacity', greatest(
                coalesce(slot_data.total_capacity, 0)
                - coalesce(slot_data.total_quantity, 0)
                - coalesce(slot_data.pending_quantity, 0),
                0
              ),
              'used_capacity_ratio', case
                when coalesce(slot_data.total_capacity, 0) > 0 then
                  round(
                    (
                      coalesce(slot_data.total_quantity, 0)
                      + coalesce(slot_data.pending_quantity, 0)
                    )::numeric / slot_data.total_capacity::numeric,
                    4
                  )
                else 0
              end,
              'pending_sale_total', coalesce(slot_data.pending_sale_total, 0),
              'total_stock_cost_value', coalesce(slot_data.total_stock_cost_value, 0),
              'total_stock_sale_value', coalesce(slot_data.total_stock_sale_value, 0)
            ),
            'slots', coalesce(slot_data.slots, '[]'::jsonb)
          )
        )
    end
  from stores s
  join cities c on c.id = s.city_id
  join store_types st on st.id = s.store_type_id
  left join lateral (
    select
      count(ss.id) as slot_count,
      count(ss.id) filter (where ss.is_active = true) as active_slot_count,
      count(ss.id) filter (
        where ss.product_id is not null and ss.quality_level between 1 and 5
      ) as filled_slot_count,
      coalesce(sum(ss.quantity), 0) as total_quantity,
      coalesce(sum(ss.capacity), 0) as total_capacity,
      coalesce(sum(ss.pending_quantity), 0) as pending_quantity,
      coalesce(sum(ss.pending_sale), 0) as pending_sale_total,
      coalesce(sum(ss.quantity * ss.cost), 0) as total_stock_cost_value,
      coalesce(sum(ss.quantity * ss.price), 0) as total_stock_sale_value,
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id', ss.id,
            'store_id', ss.store_id,
            'slot_index', ss.slot_index,
            'product_id', ss.product_id,
            'quantity', ss.quantity,
            'quality_level', ss.quality_level,
            'price', ss.price,
            'cost', ss.cost,
            'capacity', ss.capacity,
            'boost_multiplier', ss.boost_multiplier,
            'pending_sale', ss.pending_sale,
            'pending_quantity', ss.pending_quantity,
            'is_active', ss.is_active,
            'created_at', ss.created_at,
            'updated_at', ss.updated_at,
            'is_empty', case
              when ss.product_id is null or ss.quality_level = 0 then true
              else false
            end,
            'available_capacity', greatest(ss.capacity - ss.quantity - ss.pending_quantity, 0),
            'used_capacity_ratio', case
              when ss.capacity > 0 then
                round((ss.quantity + ss.pending_quantity)::numeric / ss.capacity::numeric, 4)
              else 0
            end,
            'stock_cost_value', ss.quantity * ss.cost,
            'stock_sale_value', ss.quantity * ss.price,
            'product', case
              when p.id is null then null
              else jsonb_build_object(
                'id', p.id,
                'urun_adi', p.urun_adi,
                'urun_iconu', p.urun_iconu,
                'uretim_birimi', p.uretim_birimi,
                'baz_satis_fiyati', p.baz_satis_fiyati,
                'ortalama_fiyat', p.ortalama_fiyat,
                'en_dusuk_fiyat', p.en_dusuk_fiyat,
                'en_yuksek_fiyat', p.en_yuksek_fiyat,
                'birim_hacim', p.birim_hacim,
                'birim_agirlik', p.birim_agirlik,
                'satis_adedi', p.satis_adedi,
                'piyasadaki_stok', p.piyasadaki_stok,
                'satici_sayisi', p.satici_sayisi
              )
            end
          )
          order by ss.slot_index asc
        ),
        '[]'::jsonb
      ) as slots
    from store_slots ss
    left join products p on p.id = ss.product_id
    where ss.store_id = s.id
  ) slot_data on true
  where s.player_id = p_player_id
    and s.id = p_store_id;
$function$
;

CREATE OR REPLACE FUNCTION public.get_store_history_items(p_store_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with transfer_items as (
    select jsonb_build_object(
      'id', 'transfer_' || lt.id::text,
      'type',
        case when lt.buyer_store_id = p_store_id then 'incoming_transfer' else 'outgoing_transfer' end,
      'happened_at', coalesce(lt.completed_at, lt.finish_at, lt.started_at),
      'title',
        case
          when lt.buyer_store_id = p_store_id then
            case when coalesce(lt.total_price, 0) > 0 then 'Pazardan Geldi' else 'Depodan Geldi' end
          else 'Depoya Gonderildi'
        end,
      'subtitle',
        case
          when lt.buyer_store_id = p_store_id then
            coalesce(sw.name, 'Depo') || ' | ' || coalesce(sc.name, 'Sehir')
          else
            coalesce(bw.name, 'Depo') || ' | ' || coalesce(bc.name, 'Sehir')
        end,
      'product_name', coalesce(p.urun_adi, 'Urun'),
      'quantity', coalesce(lt.quantity, 0),
      'amount', coalesce(lt.total_price, 0),
      'secondary_amount', lt.rental_cost,
      'quality_level', lt.quality_level,
      'status', coalesce(lt.status, 'completed')
    ) as item
    from public.logistics_transfers lt
    left join public.warehouses sw on sw.id = lt.seller_warehouse_id
    left join public.cities sc on sc.id = sw.city_id
    left join public.warehouses bw on bw.id = lt.buyer_warehouse_id
    left join public.cities bc on bc.id = bw.city_id
    left join public.products p on p.id = lt.product_id
    join public.stores s on s.id = p_store_id and s.player_id = auth.uid()
    where (lt.buyer_store_id = p_store_id or lt.seller_store_id = p_store_id)
      and lt.status <> 'in_transit'
  ),
  sale_items as (
    select jsonb_build_object(
      'id', 'sale_' || sdp.id::text,
      'type', 'sale',
      'happened_at', coalesce(sdp.last_sale_at, sdp.performance_date::timestamp),
      'title', 'Satis Ozeti',
      'subtitle', coalesce(sdp.sale_event_count, 0)::text || ' satis islemi',
      'product_name', coalesce(sdp.product_name, 'Urun'),
      'quantity', coalesce(sdp.sold_quantity, 0),
      'amount', coalesce(sdp.revenue, 0),
      'secondary_amount', sdp.profit,
      'quality_level', sdp.quality_level,
      'status', 'completed'
    ) as item
    from public.store_daily_performance sdp
    join public.stores s on s.id = sdp.store_id and s.player_id = auth.uid()
    where sdp.store_id = p_store_id
      and sdp.sold_quantity > 0
  ),
  all_items as (
    select item from transfer_items
    union all
    select item from sale_items
  )
  select coalesce(
    jsonb_agg(item order by (item->>'happened_at')::timestamptz desc),
    '[]'::jsonb
  )
  from (
    select item
    from all_items
    order by (item->>'happened_at')::timestamptz desc
    limit 100
  ) ranked;
$function$
;

CREATE OR REPLACE FUNCTION public.get_store_to_warehouse_vehicle_options(p_store_slot_id uuid, p_buyer_warehouse_id uuid, p_quantity integer)
 RETURNS TABLE(vehicle_id uuid, vehicle_owner_player_id uuid, vehicle_name text, is_rental boolean, capacity integer, speed_kmh integer, current_fuel integer, fuel_capacity integer, fuel_rate numeric, condition integer, rental_price numeric, distance_km numeric, fuel_needed numeric, condition_needed numeric, rental_cost numeric, estimated_duration_seconds integer, can_select boolean, disabled_reason text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_store_slot record;
  v_buyer_warehouse record;
  v_product record;
  v_required_capacity numeric := 0;
  v_distance_km numeric := 0;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select ss.*, s.player_id, s.is_active as store_is_active, s.city_id as store_city_id, c.map_position_x as city_x, c.map_position_y as city_y
  into v_store_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  join public.cities c on c.id = s.city_id
  where ss.id = p_store_slot_id;

  if not found or v_store_slot.player_id <> v_player_id then
    raise exception 'Magaza slotu bulunamadi veya size ait degil.';
  end if;

  if v_store_slot.store_is_active is not true then
    raise exception 'Magaza aktif degil.';
  end if;

  if coalesce(v_store_slot.product_id, '') = '' or coalesce(v_store_slot.quality_level, 0) = 0 then
    raise exception 'Magaza slotunda gecerli urun veya kalite yok.';
  end if;

  if p_quantity > coalesce(v_store_slot.quantity, 0) then
    raise exception 'Istenen miktar mevcut stoktan fazla.';
  end if;

  select w.*, c.map_position_x as city_x, c.map_position_y as city_y
  into v_buyer_warehouse
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id
    and w.player_id = v_player_id;

  if not found then
    raise exception 'Hedef depo bulunamadi veya size ait degil.';
  end if;

  if v_buyer_warehouse.is_active is not true then
    raise exception 'Hedef depo aktif degil.';
  end if;

  select * into v_product
  from public.products
  where id = v_store_slot.product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_store_slot.city_x - v_buyer_warehouse.city_x) / 2)), 2) +
      cos(radians(v_buyer_warehouse.city_x)) *
      cos(radians(v_store_slot.city_x)) *
      power(sin(radians((v_store_slot.city_y - v_buyer_warehouse.city_y) / 2)), 2)
    )
  );

  return query
  with candidates as (
    select
      lv.id as vehicle_id,
      lv.player_id as vehicle_owner_player_id,
      lvt.name as vehicle_name,
      (lv.player_id <> v_player_id) as is_rental,
      lv.capacity,
      lv.speed_kmh,
      lv.current_fuel,
      lv.fuel_capacity,
      lv.fuel_rate,
      lv.condition,
      lv.rental_price,
      v_distance_km as distance_km,
      ceil(v_distance_km * lv.fuel_rate) as fuel_needed,
      ceil(v_distance_km * 0.02) as condition_needed,
      case when lv.player_id <> v_player_id then ceil(v_distance_km * lv.rental_price) else 0 end as rental_cost,
      greatest(1, ceil(((v_distance_km / greatest(lv.speed_kmh, 1)) / 4.0) * 3600))::integer as estimated_duration_seconds,
      lv.status,
      lv.is_available_for_rent,
      lc.is_active as company_is_active,
      public.logistics_vehicle_matches_route(lv.route_city_a_id, lv.route_city_b_id, v_store_slot.store_city_id, v_buyer_warehouse.city_id) as route_matches
    from public.logistics_vehicles lv
    join public.logistics_vehicle_types lvt on lvt.id = lv.logistics_vehicle_type_id
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where lv.player_id = v_player_id
       or (lv.player_id <> v_player_id and lv.is_available_for_rent = true)
  )
  select
    c.vehicle_id,
    c.vehicle_owner_player_id,
    c.vehicle_name,
    c.is_rental,
    c.capacity,
    c.speed_kmh,
    c.current_fuel,
    c.fuel_capacity,
    c.fuel_rate,
    c.condition,
    c.rental_price,
    c.distance_km,
    c.fuel_needed,
    c.condition_needed,
    c.rental_cost,
    c.estimated_duration_seconds,
    (
      c.route_matches = true
      and c.status = 'idle'
      and c.company_is_active = true
      and c.capacity >= v_required_capacity
      and c.current_fuel >= c.fuel_needed
      and c.condition > c.condition_needed
    ) as can_select,
    case
      when c.route_matches is not true then 'Aracin rotasi bu sehir ciftini desteklemiyor.'
      when c.status <> 'idle' then 'Arac su anda uygun degil.'
      when c.company_is_active = false then 'Nakliye firmasi aktif degil.'
      when c.capacity < v_required_capacity then 'Kapasite yetersiz.'
      when c.current_fuel < c.fuel_needed then 'Yakit yetersiz.'
      when c.condition <= c.condition_needed then 'Kondisyon yetersiz.'
      else null
    end as disabled_reason
  from candidates c
  order by c.is_rental asc, can_select desc, c.capacity asc, c.rental_price asc, c.vehicle_name asc;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_store_transfer_vehicle_options(p_store_slot_id uuid, p_warehouse_slot_id uuid, p_quantity integer)
 RETURNS TABLE(vehicle_id uuid, vehicle_owner_player_id uuid, vehicle_name text, is_rental boolean, capacity integer, speed_kmh integer, current_fuel integer, fuel_capacity integer, fuel_rate numeric, condition integer, rental_price numeric, distance_km numeric, fuel_needed numeric, condition_needed numeric, rental_cost numeric, estimated_duration_seconds integer, can_select boolean, disabled_reason text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_store_slot record;
  v_warehouse_slot record;
  v_product record;
  v_required_capacity numeric := 0;
  v_distance_km numeric := 0;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select ss.*, s.player_id, s.is_active as store_is_active, s.city_id as store_city_id, c.map_position_x as city_x, c.map_position_y as city_y
  into v_store_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  join public.cities c on c.id = s.city_id
  where ss.id = p_store_slot_id;

  if not found or v_store_slot.player_id <> v_player_id then
    raise exception 'Magaza slotu bulunamadi veya size ait degil.';
  end if;

  if v_store_slot.store_is_active is not true then
    raise exception 'Magaza aktif degil.';
  end if;

  select ws.*, w.player_id as warehouse_player_id, w.city_id as warehouse_city_id, c.map_position_x as city_x, c.map_position_y as city_y
  into v_warehouse_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  join public.cities c on c.id = w.city_id
  where ws.id = p_warehouse_slot_id;

  if not found or v_warehouse_slot.warehouse_player_id <> v_player_id then
    raise exception 'Depo slotu bulunamadi veya size ait degil.';
  end if;

  if p_quantity > v_warehouse_slot.quantity then
    raise exception 'Istenen miktar mevcut stoktan fazla.';
  end if;

  if v_store_slot.product_id is not null and v_store_slot.quality_level > 0 and (
    v_store_slot.product_id <> v_warehouse_slot.product_id
    or v_store_slot.quality_level <> v_warehouse_slot.quality_level
  ) and (v_store_slot.quantity > 0 or coalesce(v_store_slot.pending_quantity, 0) > 0) then
    raise exception 'Slotta farkli urun veya kalite icin aktif stok/rezerve var.';
  end if;

  if (coalesce(v_store_slot.quantity, 0) + coalesce(v_store_slot.pending_quantity, 0) + p_quantity) > v_store_slot.capacity then
    raise exception 'Magaza slot kapasitesi yetersiz.';
  end if;

  select * into v_product from public.products where id = v_warehouse_slot.product_id;
  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_warehouse_slot.city_x - v_store_slot.city_x) / 2)), 2) +
      cos(radians(v_store_slot.city_x)) *
      cos(radians(v_warehouse_slot.city_x)) *
      power(sin(radians((v_warehouse_slot.city_y - v_store_slot.city_y) / 2)), 2)
    )
  );

  return query
  with candidates as (
    select
      lv.id as vehicle_id,
      lv.player_id as vehicle_owner_player_id,
      lvt.name as vehicle_name,
      (lv.player_id <> v_player_id) as is_rental,
      lv.capacity,
      lv.speed_kmh,
      lv.current_fuel,
      lv.fuel_capacity,
      lv.fuel_rate,
      lv.condition,
      lv.rental_price,
      v_distance_km as distance_km,
      ceil(v_distance_km * lv.fuel_rate) as fuel_needed,
      ceil(v_distance_km * 0.02) as condition_needed,
      case when lv.player_id <> v_player_id then ceil(v_distance_km * lv.rental_price) else 0 end as rental_cost,
      greatest(1, ceil(((v_distance_km / greatest(lv.speed_kmh, 1)) / 4.0) * 3600))::integer as estimated_duration_seconds,
      lv.status,
      lv.is_available_for_rent,
      lc.is_active as company_is_active,
      public.logistics_vehicle_matches_route(lv.route_city_a_id, lv.route_city_b_id, v_warehouse_slot.warehouse_city_id, v_store_slot.store_city_id) as route_matches
    from public.logistics_vehicles lv
    join public.logistics_vehicle_types lvt on lvt.id = lv.logistics_vehicle_type_id
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where lv.player_id = v_player_id
       or (lv.player_id <> v_player_id and lv.is_available_for_rent = true)
  )
  select
    c.vehicle_id,
    c.vehicle_owner_player_id,
    c.vehicle_name,
    c.is_rental,
    c.capacity,
    c.speed_kmh,
    c.current_fuel,
    c.fuel_capacity,
    c.fuel_rate,
    c.condition,
    c.rental_price,
    c.distance_km,
    c.fuel_needed,
    c.condition_needed,
    c.rental_cost,
    c.estimated_duration_seconds,
    (
      c.route_matches = true
      and c.status = 'idle'
      and c.company_is_active = true
      and c.capacity >= v_required_capacity
      and c.current_fuel >= c.fuel_needed
      and c.condition > c.condition_needed
    ) as can_select,
    case
      when c.route_matches is not true then 'Aracin rotasi bu sehir ciftini desteklemiyor.'
      when c.status <> 'idle' then 'Arac su anda uygun degil.'
      when c.company_is_active = false then 'Nakliye firmasi aktif degil.'
      when c.capacity < v_required_capacity then 'Kapasite yetersiz.'
      when c.current_fuel < c.fuel_needed then 'Yakit yetersiz.'
      when c.condition <= c.condition_needed then 'Kondisyon yetersiz.'
      else null
    end as disabled_reason
  from candidates c
  order by c.is_rental asc, can_select desc, c.capacity asc, c.rental_price asc, c.vehicle_name asc;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_store_types_catalog()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(to_jsonb(st) order by st.required_level, st.cost),
    '[]'::jsonb
  )
  from public.store_types st;
$function$
;

CREATE OR REPLACE FUNCTION public.get_stores_list(p_player_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'success', true,
    'player_id', p_player_id,
    'store_count', count(s.id),
    'stores', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', s.id,
          'name', s.name,
          'city_id', s.city_id,
          'city_name', c.name,
          'level', s.level,
          'is_active', s.is_active,
          'store_type', jsonb_build_object(
            'id', st.id,
            'name', st.name,
            'icon', st.icon
          ),
          'summary', jsonb_build_object(
            'total_quantity', coalesce(slot_summary.total_quantity, 0),
            'total_capacity', coalesce(slot_summary.total_capacity, 0),
            'pending_quantity', coalesce(slot_summary.pending_quantity, 0),
            'available_capacity', greatest(
              coalesce(slot_summary.total_capacity, 0)
              - coalesce(slot_summary.total_quantity, 0)
              - coalesce(slot_summary.pending_quantity, 0),
              0
            ),
            'used_capacity_ratio', case
              when coalesce(slot_summary.total_capacity, 0) > 0 then
                round(
                  (
                    coalesce(slot_summary.total_quantity, 0)
                    + coalesce(slot_summary.pending_quantity, 0)
                  )::numeric / slot_summary.total_capacity::numeric,
                  4
                )
              else 0
            end
          ),
          'slots', coalesce(slot_summary.slots, '[]'::jsonb)
        )
        order by s.created_at asc, s.name asc
      ),
      '[]'::jsonb
    )
  )
  from stores s
  join cities c on c.id = s.city_id
  join store_types st on st.id = s.store_type_id
  left join lateral (
    select
      coalesce(sum(ss.quantity), 0) as total_quantity,
      coalesce(sum(ss.capacity), 0) as total_capacity,
      coalesce(sum(ss.pending_quantity), 0) as pending_quantity,
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'slot_id', ss.id,
            'slot_index', ss.slot_index,
            'product_id', ss.product_id,
            'product_name', p.urun_adi,
            'product_icon', p.urun_iconu,
            'quality_level', ss.quality_level,
            'quantity', ss.quantity,
            'capacity', ss.capacity,
            'pending_quantity', ss.pending_quantity,
            'is_active', ss.is_active,
            'is_empty', case
              when ss.product_id is null or ss.quality_level = 0 then true
              else false
            end,
            'used_capacity_ratio', case
              when ss.capacity > 0 then
                round((ss.quantity + ss.pending_quantity)::numeric / ss.capacity::numeric, 4)
              else 0
            end
          )
          order by ss.slot_index asc
        ),
        '[]'::jsonb
      ) as slots
    from store_slots ss
    left join products p on p.id = ss.product_id
    where ss.store_id = s.id
  ) slot_summary on true
  where s.player_id = p_player_id;
$function$
;

CREATE OR REPLACE FUNCTION public.get_warehouse_capacity_status(p_warehouse_id uuid)
 RETURNS TABLE(warehouse_id uuid, total_capacity numeric, used_capacity numeric, reserved_capacity numeric, available_capacity numeric)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with target_warehouse as (
    select w.id, w.capacity::numeric as total_capacity, w.reserved_capacity::numeric as reserved_capacity
    from public.warehouses w
    where w.id = p_warehouse_id
      and w.player_id = auth.uid()
  ),
  used_space as (
    select
      ws.warehouse_id,
      coalesce(sum(ws.quantity::numeric * coalesce(p.birim_hacim, 0)), 0) as used_capacity
    from public.warehouse_slots ws
    join public.products p on p.id = ws.product_id
    where ws.warehouse_id = p_warehouse_id
    group by ws.warehouse_id
  )
  select
    tw.id as warehouse_id,
    tw.total_capacity,
    coalesce(us.used_capacity, 0) as used_capacity,
    tw.reserved_capacity,
    greatest(tw.total_capacity - coalesce(us.used_capacity, 0) - tw.reserved_capacity, 0) as available_capacity
  from target_warehouse tw
  left join used_space us on us.warehouse_id = tw.id;
$function$
;

CREATE OR REPLACE FUNCTION public.get_warehouse_type_detail(p_type_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select to_jsonb(wt)
  from public.warehouse_types wt
  where wt.id = p_type_id;
$function$
;

CREATE OR REPLACE FUNCTION public.get_warehouse_types_catalog()
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    jsonb_agg(to_jsonb(wt) order by wt.required_level, wt.cost),
    '[]'::jsonb
  )
  from public.warehouse_types wt;
$function$
;

CREATE OR REPLACE FUNCTION public.logistics_vehicle_matches_route(p_route_city_a_id uuid, p_route_city_b_id uuid, p_from_city_id uuid, p_to_city_id uuid)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select
    p_route_city_a_id is not null
    and p_route_city_b_id is not null
    and (
      (p_route_city_a_id = p_from_city_id and p_route_city_b_id = p_to_city_id)
      or
      (p_route_city_a_id = p_to_city_id and p_route_city_b_id = p_from_city_id)
    );
$function$
;

CREATE OR REPLACE FUNCTION public.now_turkey()
 RETURNS timestamp without time zone
 LANGUAGE sql
 STABLE
AS $function$
  select timezone('Europe/Istanbul', now());
$function$
;

CREATE OR REPLACE FUNCTION public.process_factory_production()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_has_lock boolean;

  v_processed_count integer := 0;
  v_produced_count integer := 0;
  v_skipped_count integer := 0;
  v_total_produced integer := 0;
begin
  /*
    Fabrika üretim cron fonksiyonu.

    Cron 10 dakikada bir çalışır.
    products.uretim_adedi saatlik üretimdir.
    Her cron çalışmasında:
      products.uretim_adedi / 6 * factories.boost_multiplier

    Bu fonksiyon:
    - Ürün doğrulamaz.
    - Inventory oluşturmaz.
    - Üretim ayarı değiştirmez.
    - Eski ürün/kalite stoklarını kapasiteye katmaz.
    - Sadece aktif product_id + quality_level output satırını işler.

    set_factory_product fonksiyonu:
    - Ürün/kalite doğrulamasını yapar.
    - Input/output inventory kayıtlarını oluşturur.
    - Stok varsa ürün/kalite değişimini engeller.
  */

  v_has_lock := pg_try_advisory_xact_lock(hashtext('factory_production_lock'));

  if not v_has_lock then
    return jsonb_build_object(
      'success', true,
      'skipped', true,
      'reason', 'factory_production_already_running',
      'processed_count', 0,
      'produced_count', 0,
      'skipped_count', 0,
      'total_produced', 0
    );
  end if;

  with factory_candidates as (
    select
      f.id as factory_id,
      f.product_id,
      f.quality_level,
      f.output_capacity,
      f.boost_multiplier,

      p.uretim_adedi,

      nullif(p.hammadde_1_id, '') as h1_id,
      nullif(p.hammadde_2_id, '') as h2_id,
      nullif(p.hammadde_3_id, '') as h3_id,

      coalesce(p.hammadde_1_miktar, 0) as h1_per_unit,
      coalesce(p.hammadde_2_miktar, 0) as h2_per_unit,
      coalesce(p.hammadde_3_miktar, 0) as h3_per_unit,

      out_pi.id as output_inventory_id,
      out_pi.quantity as output_quantity,
      out_pi.pending_quantity as output_pending_quantity,
      out_pi.cost as output_cost,

      greatest(f.output_capacity - out_pi.quantity, 0) as available_output_capacity,

      (
        coalesce(out_pi.pending_quantity, 0)
        +
        (
          (coalesce(p.uretim_adedi, 0)::numeric / 6)
          *
          coalesce(f.boost_multiplier, 1)
        )
      ) as raw_output
    from factories f
    join products p
      on p.id = f.product_id
    join production_inventory out_pi
      on out_pi.owner_kind = 'factory'
     and out_pi.owner_id = f.id
     and out_pi.inventory_type = 'output'
     and out_pi.product_id = f.product_id
     and out_pi.quality_level = f.quality_level
    where f.is_active = true
      and f.product_id is not null
      and f.quality_level between 1 and 5
      and f.output_capacity > out_pi.quantity
      and coalesce(p.uretim_adedi, 0) > 0
  ),

  calculated_output as (
    select
      fc.*,

      floor(fc.raw_output)::integer as whole_output,

      least(
        floor(fc.raw_output)::integer,
        fc.available_output_capacity
      )::integer as output_to_produce
    from factory_candidates fc
  ),

  required_inputs as (
    select
      co.*,

      case
        when co.h1_id is not null and co.h1_per_unit > 0
          then ceil(co.output_to_produce * co.h1_per_unit)::integer
        else 0
      end as h1_required,

      case
        when co.h2_id is not null and co.h2_per_unit > 0
          then ceil(co.output_to_produce * co.h2_per_unit)::integer
        else 0
      end as h2_required,

      case
        when co.h3_id is not null and co.h3_per_unit > 0
          then ceil(co.output_to_produce * co.h3_per_unit)::integer
        else 0
      end as h3_required
    from calculated_output co
    where co.output_to_produce > 0
  ),

  input_joined as (
    select
      ri.*,

      h1_pi.id as h1_inventory_id,
      coalesce(h1_pi.quantity, 0) as h1_quantity,
      coalesce(h1_pi.cost, 0) as h1_cost,

      h2_pi.id as h2_inventory_id,
      coalesce(h2_pi.quantity, 0) as h2_quantity,
      coalesce(h2_pi.cost, 0) as h2_cost,

      h3_pi.id as h3_inventory_id,
      coalesce(h3_pi.quantity, 0) as h3_quantity,
      coalesce(h3_pi.cost, 0) as h3_cost
    from required_inputs ri

    left join production_inventory h1_pi
      on h1_pi.owner_kind = 'factory'
     and h1_pi.owner_id = ri.factory_id
     and h1_pi.inventory_type = 'input'
     and h1_pi.product_id = ri.h1_id
     and h1_pi.quality_level = ri.quality_level

    left join production_inventory h2_pi
      on h2_pi.owner_kind = 'factory'
     and h2_pi.owner_id = ri.factory_id
     and h2_pi.inventory_type = 'input'
     and h2_pi.product_id = ri.h2_id
     and h2_pi.quality_level = ri.quality_level

    left join production_inventory h3_pi
      on h3_pi.owner_kind = 'factory'
     and h3_pi.owner_id = ri.factory_id
     and h3_pi.inventory_type = 'input'
     and h3_pi.product_id = ri.h3_id
     and h3_pi.quality_level = ri.quality_level
  ),

  producible as (
    select
      ij.*,

      (
        (ij.h1_required = 0 or ij.h1_quantity >= ij.h1_required)
        and
        (ij.h2_required = 0 or ij.h2_quantity >= ij.h2_required)
        and
        (ij.h3_required = 0 or ij.h3_quantity >= ij.h3_required)
      ) as has_enough_input,

      (
        (
          (ij.h1_required * ij.h1_cost)
          +
          (ij.h2_required * ij.h2_cost)
          +
          (ij.h3_required * ij.h3_cost)
        ) * 1.05
      ) as total_input_cost
    from input_joined ij
  ),

  produced_factories as (
    select *
    from producible
    where has_enough_input = true
  ),

  /*
    Input tüketimi.
    Her hammadde ayrı update edilir.
  */
  consume_h1 as (
    update production_inventory pi
    set quantity = pi.quantity - pf.h1_required
    from produced_factories pf
    where pf.h1_required > 0
      and pi.id = pf.h1_inventory_id
    returning pi.id
  ),

  consume_h2 as (
    update production_inventory pi
    set quantity = pi.quantity - pf.h2_required
    from produced_factories pf
    where pf.h2_required > 0
      and pi.id = pf.h2_inventory_id
    returning pi.id
  ),

  consume_h3 as (
    update production_inventory pi
    set quantity = pi.quantity - pf.h3_required
    from produced_factories pf
    where pf.h3_required > 0
      and pi.id = pf.h3_inventory_id
    returning pi.id
  ),

  update_output as (
    update production_inventory pi
    set
      quantity = pi.quantity + pf.output_to_produce,

      pending_quantity =
        case
          when pf.output_to_produce < pf.whole_output then 0
          else pf.raw_output - pf.whole_output
        end,

      cost =
        case
          when pi.quantity + pf.output_to_produce > 0 then
            (
              (pi.quantity * pi.cost)
              +
              (
                pf.output_to_produce
                *
                case
                  when pf.output_to_produce > 0
                    then pf.total_input_cost / pf.output_to_produce
                  else 0
                end
              )
            )
            /
            (pi.quantity + pf.output_to_produce)
          else pi.cost
        end
    from produced_factories pf
    where pi.id = pf.output_inventory_id
    returning
      pi.id,
      pf.factory_id,
      pf.output_to_produce
  ),

  /*
    Sadece pending oluşan ama tam ürün üretmeyen fabrikalar.
    Bunlarda input tüketimi yok.
  */
  pending_only as (
    update production_inventory pi
    set pending_quantity = co.raw_output
    from calculated_output co
    where co.output_to_produce = 0
      and co.raw_output <> co.output_pending_quantity
      and pi.id = co.output_inventory_id
    returning pi.id
  ),

  counts as (
    select
      (select count(*) from factory_candidates) as processed_count,
      (select count(*) from update_output) as produced_count,
      (select count(*) from pending_only) as pending_only_count,
      (select coalesce(sum(output_to_produce), 0) from update_output) as total_produced,
      (
        (select count(*) from factory_candidates)
        -
        (select count(*) from update_output)
        -
        (select count(*) from pending_only)
      ) as skipped_count
  )

  select
    processed_count,
    produced_count,
    skipped_count,
    total_produced
  into
    v_processed_count,
    v_produced_count,
    v_skipped_count,
    v_total_produced
  from counts;

  return jsonb_build_object(
    'success', true,
    'skipped', false,
    'processed_count', v_processed_count,
    'produced_count', v_produced_count,
    'skipped_count', v_skipped_count,
    'total_produced', v_total_produced
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.process_field_farm_production()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_has_lock boolean;
  v_processed_count integer := 0;
  v_produced_count integer := 0;
  v_skipped_count integer := 0;
  v_total_produced integer := 0;
begin
  v_has_lock := pg_try_advisory_xact_lock(hashtext('field_farm_production_lock'));

  if not v_has_lock then
    return jsonb_build_object(
      'success', true,
      'skipped', true,
      'reason', 'field_farm_production_already_running',
      'processed_count', 0,
      'produced_count', 0,
      'skipped_count', 0,
      'total_produced', 0
    );
  end if;

  with active_slots as (
    select
      ps.id as production_slot_id,
      ps.owner_kind,
      ps.owner_id,
      ps.slot_index,
      ps.product_id,
      ps.quality_level,
      ps.boost_multiplier,
      case
        when ps.owner_kind = 'field' then f.output_capacity
        when ps.owner_kind = 'farm' then fa.output_capacity
      end as owner_output_capacity,
      p.uretim_adedi,
      nullif(p.hammadde_1_id, '') as h1_id,
      nullif(p.hammadde_2_id, '') as h2_id,
      nullif(p.hammadde_3_id, '') as h3_id,
      coalesce(p.hammadde_1_miktar, 0) as h1_per_unit,
      coalesce(p.hammadde_2_miktar, 0) as h2_per_unit,
      coalesce(p.hammadde_3_miktar, 0) as h3_per_unit
    from production_slots ps
    join products p on p.id = ps.product_id
    left join fields f on ps.owner_kind = 'field' and f.id = ps.owner_id
    left join farms fa on ps.owner_kind = 'farm' and fa.id = ps.owner_id
    where ps.is_active = true
      and ps.owner_kind in ('field', 'farm')
      and ps.product_id is not null
      and ps.quality_level between 1 and 5
      and coalesce(p.uretim_adedi, 0) > 0
      and (
        nullif(p.hammadde_1_id, '') is not null
        or nullif(p.hammadde_2_id, '') is not null
        or nullif(p.hammadde_3_id, '') is not null
      )
      and (
        (ps.owner_kind = 'field' and f.is_active = true and f.output_capacity > 0)
        or
        (ps.owner_kind = 'farm' and fa.is_active = true and fa.output_capacity > 0)
      )
  ),
  active_owners as (
    select distinct owner_kind, owner_id
    from active_slots
  ),
  owner_output_totals as (
    select
      pi.owner_kind,
      pi.owner_id,
      coalesce(sum(pi.quantity), 0) as total_output_quantity
    from production_inventory pi
    join active_owners ao on ao.owner_kind = pi.owner_kind and ao.owner_id = pi.owner_id
    where pi.inventory_type = 'output'
    group by pi.owner_kind, pi.owner_id
  ),
  output_joined as (
    select
      s.*,
      out_pi.id as output_inventory_id,
      out_pi.quantity as output_quantity,
      out_pi.pending_quantity as output_pending_quantity,
      out_pi.cost as output_cost,
      coalesce(oot.total_output_quantity, 0) as total_output_quantity,
      greatest(s.owner_output_capacity - coalesce(oot.total_output_quantity, 0), 0) as owner_available_output_capacity,
      (
        coalesce(out_pi.pending_quantity, 0)
        + ((coalesce(s.uretim_adedi, 0)::numeric / 6) * coalesce(s.boost_multiplier, 1))
      ) as raw_output
    from active_slots s
    join production_inventory out_pi
      on out_pi.owner_kind = s.owner_kind
     and out_pi.owner_id = s.owner_id
     and out_pi.inventory_type = 'output'
     and out_pi.product_id = s.product_id
     and out_pi.quality_level = s.quality_level
    left join owner_output_totals oot on oot.owner_kind = s.owner_kind and oot.owner_id = s.owner_id
    where s.owner_output_capacity > coalesce(oot.total_output_quantity, 0)
  ),
  calculated_raw as (
    select oj.*, floor(oj.raw_output)::integer as whole_output
    from output_joined oj
  ),
  capacity_ordered as (
    select
      cr.*,
      coalesce(
        sum(cr.whole_output) over (
          partition by cr.owner_kind, cr.owner_id
          order by cr.slot_index asc, cr.production_slot_id asc
          rows between unbounded preceding and 1 preceding
        ),
        0
      ) as previous_requested_output
    from calculated_raw cr
  ),
  calculated_output as (
    select
      co.*,
      greatest(
        least(co.whole_output, co.owner_available_output_capacity - co.previous_requested_output),
        0
      )::integer as output_to_produce
    from capacity_ordered co
  ),
  required_inputs as (
    select
      co.*,
      case when co.h1_id is not null and co.h1_per_unit > 0 then ceil(co.output_to_produce * co.h1_per_unit)::integer else 0 end as h1_required,
      case when co.h2_id is not null and co.h2_per_unit > 0 then ceil(co.output_to_produce * co.h2_per_unit)::integer else 0 end as h2_required,
      case when co.h3_id is not null and co.h3_per_unit > 0 then ceil(co.output_to_produce * co.h3_per_unit)::integer else 0 end as h3_required
    from calculated_output co
    where co.output_to_produce > 0
  ),
  input_joined as (
    select
      ri.*,
      h1_pi.id as h1_inventory_id,
      coalesce(h1_pi.quantity, 0) as h1_quantity,
      coalesce(h1_pi.cost, 0) as h1_cost,
      h2_pi.id as h2_inventory_id,
      coalesce(h2_pi.quantity, 0) as h2_quantity,
      coalesce(h2_pi.cost, 0) as h2_cost,
      h3_pi.id as h3_inventory_id,
      coalesce(h3_pi.quantity, 0) as h3_quantity,
      coalesce(h3_pi.cost, 0) as h3_cost
    from required_inputs ri
    left join production_inventory h1_pi
      on h1_pi.owner_kind = ri.owner_kind
     and h1_pi.owner_id = ri.owner_id
     and h1_pi.inventory_type = 'input'
     and h1_pi.product_id = ri.h1_id
     and h1_pi.quality_level = 1
    left join production_inventory h2_pi
      on h2_pi.owner_kind = ri.owner_kind
     and h2_pi.owner_id = ri.owner_id
     and h2_pi.inventory_type = 'input'
     and h2_pi.product_id = ri.h2_id
     and h2_pi.quality_level = 1
    left join production_inventory h3_pi
      on h3_pi.owner_kind = ri.owner_kind
     and h3_pi.owner_id = ri.owner_id
     and h3_pi.inventory_type = 'input'
     and h3_pi.product_id = ri.h3_id
     and h3_pi.quality_level = 1
  ),
  producible as (
    select
      ij.*,
      ((ij.h1_required = 0 or ij.h1_quantity >= ij.h1_required)
        and (ij.h2_required = 0 or ij.h2_quantity >= ij.h2_required)
        and (ij.h3_required = 0 or ij.h3_quantity >= ij.h3_required)) as has_enough_input,
      ((ij.h1_required * ij.h1_cost) + (ij.h2_required * ij.h2_cost) + (ij.h3_required * ij.h3_cost)) as total_input_cost,
      (((ij.h1_required * ij.h1_cost) + (ij.h2_required * ij.h2_cost) + (ij.h3_required * ij.h3_cost)) * 1.05) as total_production_cost,
      (ij.h1_required + ij.h2_required + ij.h3_required) as total_required_input_quantity
    from input_joined ij
  ),
  produced_slots as (
    select *
    from producible
    where has_enough_input = true
      and total_required_input_quantity > 0
  ),
  consume_h1 as (
    update production_inventory pi
    set quantity = pi.quantity - ps.h1_required
    from produced_slots ps
    where ps.h1_required > 0
      and pi.id = ps.h1_inventory_id
    returning pi.id
  ),
  consume_h2 as (
    update production_inventory pi
    set quantity = pi.quantity - ps.h2_required
    from produced_slots ps
    where ps.h2_required > 0
      and pi.id = ps.h2_inventory_id
    returning pi.id
  ),
  consume_h3 as (
    update production_inventory pi
    set quantity = pi.quantity - ps.h3_required
    from produced_slots ps
    where ps.h3_required > 0
      and pi.id = ps.h3_inventory_id
    returning pi.id
  ),
  update_output as (
    update production_inventory pi
    set quantity = pi.quantity + ps.output_to_produce,
        pending_quantity = case when ps.output_to_produce < ps.whole_output then 0 else ps.raw_output - ps.whole_output end,
        cost = case
          when pi.quantity + ps.output_to_produce > 0 then (((pi.quantity * pi.cost) + ps.total_production_cost) / (pi.quantity + ps.output_to_produce))
          else pi.cost
        end
    from produced_slots ps
    where pi.id = ps.output_inventory_id
    returning pi.id, ps.production_slot_id, ps.output_to_produce
  ),
  pending_only as (
    update production_inventory pi
    set pending_quantity = co.raw_output
    from calculated_output co
    where co.output_to_produce = 0
      and co.whole_output = 0
      and co.raw_output <> co.output_pending_quantity
      and pi.id = co.output_inventory_id
    returning pi.id
  ),
  counts as (
    select
      (select count(*) from output_joined) as processed_count,
      (select count(*) from update_output) as produced_count,
      (select count(*) from pending_only) as pending_only_count,
      (select coalesce(sum(output_to_produce), 0) from update_output) as total_produced,
      ((select count(*) from output_joined) - (select count(*) from update_output)) as skipped_count
  )
  select processed_count, produced_count + pending_only_count, skipped_count, total_produced
  into v_processed_count, v_produced_count, v_skipped_count, v_total_produced
  from counts;

  return jsonb_build_object(
    'success', true,
    'processed_count', coalesce(v_processed_count, 0),
    'produced_count', coalesce(v_produced_count, 0),
    'skipped_count', coalesce(v_skipped_count, 0),
    'total_produced', coalesce(v_total_produced, 0)
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.process_mine_production()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_has_lock boolean;

  v_processed_count integer := 0;
  v_produced_count integer := 0;
  v_pending_only_count integer := 0;
  v_total_produced integer := 0;
begin
  /*
    Aynı anda ikinci maden cron çalışmasını engeller.
    Advisory lock performans için değil, veri çakışmasını önlemek içindir.
  */
  v_has_lock := pg_try_advisory_xact_lock(hashtext('mine_production_lock'));

  if not v_has_lock then
    return jsonb_build_object(
      'success', true,
      'skipped', true,
      'reason', 'mine_production_already_running',
      'processed_count', 0,
      'produced_count', 0,
      'pending_only_count', 0,
      'total_produced', 0
    );
  end if;

  with candidates as (
    select
      pi.id as inventory_id,
      (
        coalesce(pi.pending_quantity, 0)
        +
        (
          (coalesce(p.uretim_adedi, 0)::numeric / 6)
          *
          coalesce(m.boost_multiplier, 1)
        )
      ) as raw_production,
      greatest(m.output_capacity - pi.quantity, 0) as available_capacity
    from production_inventory pi
    join mines m
      on m.id = pi.owner_id
     and pi.owner_kind = 'mine'
     and pi.inventory_type = 'output'
     and pi.product_id = m.product_id
     and pi.quality_level = m.quality_level
    join products p
      on p.id = m.product_id
    where m.is_active = true
      and m.product_id is not null
      and m.quality_level between 1 and 5
      and m.output_capacity > pi.quantity
      and coalesce(p.uretim_adedi, 0) > 0
  ),

  calculated as (
    select
      inventory_id,
      raw_production,
      floor(raw_production)::integer as whole_production,
      least(
        floor(raw_production)::integer,
        available_capacity
      )::integer as produced_quantity
    from candidates
  ),

  updated_rows as (
    update production_inventory pi
    set
      quantity = pi.quantity + c.produced_quantity,
      pending_quantity =
        case
          when c.produced_quantity < c.whole_production then 0
          else c.raw_production - c.whole_production
        end
    from calculated c
    where pi.id = c.inventory_id
      and (
        c.produced_quantity > 0
        or c.raw_production <> pi.pending_quantity
      )
    returning
      pi.id,
      c.produced_quantity
  )

  select
    count(*),
    count(*) filter (where produced_quantity > 0),
    count(*) filter (where produced_quantity = 0),
    coalesce(sum(produced_quantity), 0)
  into
    v_processed_count,
    v_produced_count,
    v_pending_only_count,
    v_total_produced
  from updated_rows;

  return jsonb_build_object(
    'success', true,
    'skipped', false,
    'processed_count', v_processed_count,
    'produced_count', v_produced_count,
    'pending_only_count', v_pending_only_count,
    'total_produced', v_total_produced
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.process_store_sales_on_entry(p_player_id uuid, p_store_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_store stores%rowtype;
  v_now timestamptz := now();
  v_processed boolean := false;
  v_total_revenue numeric := 0;
  v_total_profit numeric := 0;
  v_total_sold_quantity integer := 0;
  v_elapsed_minutes_max integer := 0;
  v_items jsonb := '[]'::jsonb;
  v_slot record;
  v_elapsed_minutes numeric;
  v_base_demand numeric;
  v_generated_demand numeric;
  v_available_demand numeric;
  v_price_ratio numeric;
  v_price_multiplier numeric;
  v_quality_multiplier numeric;
  v_sold_qty integer;
  v_revenue numeric;
  v_profit numeric;
  v_pending_after numeric;
  v_performance_date date := timezone('Europe/Istanbul', v_now)::date;
begin
  select *
  into v_store
  from stores
  where id = p_store_id
    and player_id = p_player_id
  for update;

  if not found then
    return jsonb_build_object(
      'success', false,
      'processed', false,
      'message', 'Magaza bulunamadi.'
    );
  end if;

  if coalesce(v_store.is_active, false) = false then
    return jsonb_build_object(
      'success', true,
      'processed', false,
      'message', 'Magaza aktif degil.'
    );
  end if;

  for v_slot in
    select
      ss.id,
      ss.slot_index,
      ss.product_id,
      ss.quantity,
      ss.quality_level,
      ss.price,
      ss.cost,
      ss.boost_multiplier,
      ss.pending_sale,
      ss.last_sale_processed_at,
      p.urun_adi,
      p.baz_satis_fiyati,
      p.satis_adedi
    from store_slots ss
    join products p on p.id = ss.product_id
    where ss.store_id = p_store_id
      and ss.is_active = true
      and ss.product_id is not null
      and ss.quality_level between 1 and 5
      and coalesce(ss.price, 0) > 0
    order by ss.slot_index
    for update of ss
  loop
    v_elapsed_minutes := extract(epoch from (v_now - v_slot.last_sale_processed_at)) / 60.0;

    if v_elapsed_minutes < 10 then
      continue;
    end if;

    v_processed := true;
    v_elapsed_minutes_max := greatest(v_elapsed_minutes_max, floor(v_elapsed_minutes)::int);

    v_quality_multiplier := 1 + (greatest(v_slot.quality_level, 1) - 1) * 0.10;

    if coalesce(v_slot.baz_satis_fiyati, 0) <= 0 then
      v_price_multiplier := 1.0;
    else
      v_price_ratio := v_slot.price / v_slot.baz_satis_fiyati;

      if v_price_ratio <= 1 then
        v_price_multiplier := least(1.75, 1 + ((1 - v_price_ratio) * 0.75));
      else
        v_price_multiplier := greatest(0.05, 1 - ((v_price_ratio - 1) * 0.95));
      end if;
    end if;

    v_base_demand := greatest(0, coalesce(v_slot.satis_adedi, 0)::numeric * v_elapsed_minutes / 60.0);
    v_generated_demand := v_base_demand
      * coalesce(v_slot.boost_multiplier, 1)
      * v_quality_multiplier
      * v_price_multiplier;

    v_available_demand := greatest(0, coalesce(v_slot.pending_sale, 0) + v_generated_demand);
    v_sold_qty := least(coalesce(v_slot.quantity, 0), floor(v_available_demand)::int);
    v_revenue := v_sold_qty * coalesce(v_slot.price, 0);
    v_profit := v_sold_qty * (coalesce(v_slot.price, 0) - coalesce(v_slot.cost, 0));
    v_pending_after := greatest(0, v_available_demand - v_sold_qty);

    update store_slots
    set
      quantity = quantity - v_sold_qty,
      pending_sale = v_pending_after,
      last_sale_processed_at = v_now,
      updated_at = v_now
    where id = v_slot.id;

    if v_sold_qty > 0 then
      v_total_revenue := v_total_revenue + v_revenue;
      v_total_profit := v_total_profit + v_profit;
      v_total_sold_quantity := v_total_sold_quantity + v_sold_qty;

      insert into public.store_daily_performance (
        performance_date,
        player_id,
        store_id,
        store_slot_id,
        slot_index,
        product_id,
        product_name,
        quality_level,
        sold_quantity,
        revenue,
        profit,
        sale_event_count,
        last_sale_at,
        updated_at
      ) values (
        v_performance_date,
        p_player_id,
        p_store_id,
        v_slot.id,
        v_slot.slot_index,
        v_slot.product_id,
        v_slot.urun_adi,
        v_slot.quality_level,
        v_sold_qty,
        v_revenue,
        v_profit,
        1,
        v_now,
        v_now
      )
      on conflict (performance_date, store_id, store_slot_id)
      do update set
        slot_index = excluded.slot_index,
        product_id = excluded.product_id,
        product_name = excluded.product_name,
        quality_level = excluded.quality_level,
        sold_quantity = public.store_daily_performance.sold_quantity + excluded.sold_quantity,
        revenue = public.store_daily_performance.revenue + excluded.revenue,
        profit = public.store_daily_performance.profit + excluded.profit,
        sale_event_count = public.store_daily_performance.sale_event_count + 1,
        last_sale_at = excluded.last_sale_at,
        updated_at = excluded.updated_at;

      v_items := v_items || jsonb_build_array(
        jsonb_build_object(
          'slot_id', v_slot.id,
          'slot_index', v_slot.slot_index,
          'product_id', v_slot.product_id,
          'product_name', v_slot.urun_adi,
          'quality_level', v_slot.quality_level,
          'elapsed_minutes', round(v_elapsed_minutes),
          'sold_quantity', v_sold_qty,
          'unit_price', coalesce(v_slot.price, 0),
          'unit_cost', coalesce(v_slot.cost, 0),
          'revenue', v_revenue,
          'profit', v_profit,
          'remaining_quantity', greatest(coalesce(v_slot.quantity, 0) - v_sold_qty, 0),
          'pending_sale_after', v_pending_after,
          'price_multiplier', round(v_price_multiplier::numeric, 4),
          'quality_multiplier', round(v_quality_multiplier::numeric, 4)
        )
      );
    end if;
  end loop;

  if v_processed = false then
    return jsonb_build_object(
      'success', true,
      'processed', false,
      'message', 'Satis hesabi icin henuz 10 dakika gecmedi.'
    );
  end if;

  if v_total_revenue > 0 then
    update players
    set cash = cash + v_total_revenue
    where id = p_player_id;
  end if;

  update stores
  set updated_at = v_now
  where id = p_store_id;

  return jsonb_build_object(
    'success', true,
    'processed', true,
    'processed_at', v_now,
    'elapsed_minutes', v_elapsed_minutes_max,
    'total_revenue', v_total_revenue,
    'total_profit', v_total_profit,
    'total_sold_quantity', v_total_sold_quantity,
    'items', v_items
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.purchase_logistics_vehicle(p_player_id uuid, p_logistics_company_id uuid, p_logistics_vehicle_type_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player_cash numeric;
  v_company record;
  v_type record;
  v_vehicle_id uuid;
begin
  select cash
  into v_player_cash
  from public.players
  where id = p_player_id
  for update;

  if not found then
    raise exception 'Oyuncu bulunamadı.';
  end if;

  select *
  into v_company
  from public.logistics_companies
  where id = p_logistics_company_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'Nakliye firması bulunamadı.';
  end if;

  if v_company.current_vehicle_count >= v_company.max_vehicle_count then
    raise exception 'Filo kapasitesi dolu.';
  end if;

  select *
  into v_type
  from public.logistics_vehicle_types
  where id = p_logistics_vehicle_type_id;

  if not found then
    raise exception 'Araç tipi bulunamadı.';
  end if;

  if v_player_cash < coalesce(v_type.purchase_price, 0) then
    raise exception 'Oyuncunun parası yetersiz. Gerekli: %, mevcut: %', v_type.purchase_price, v_player_cash;
  end if;

  update public.players
  set cash = cash - coalesce(v_type.purchase_price, 0)
  where id = p_player_id;

  insert into public.logistics_vehicles (
    player_id,
    logistics_company_id,
    logistics_vehicle_type_id,
    capacity,
    speed_kmh,
    fuel_capacity,
    current_fuel,
    fuel_rate,
    condition,
    status,
    is_available_for_rent,
    rental_price
  ) values (
    p_player_id,
    p_logistics_company_id,
    p_logistics_vehicle_type_id,
    coalesce(v_type.capacity, 0),
    coalesce(v_type.speed_kmh, 0),
    coalesce(v_type.fuel_capacity, 0),
    coalesce(v_type.fuel_capacity, 0),
    coalesce(v_type.fuel_rate, 0),
    100,
    'idle',
    false,
    0
  )
  returning id into v_vehicle_id;

  update public.logistics_companies
  set current_vehicle_count = current_vehicle_count + 1,
      updated_at = timezone('utc'::text, now())
  where id = p_logistics_company_id;

  return jsonb_build_object(
    'success', true,
    'vehicle_id', v_vehicle_id,
    'purchase_price', coalesce(v_type.purchase_price, 0),
    'remaining_cash', v_player_cash - coalesce(v_type.purchase_price, 0),
    'current_vehicle_count', v_company.current_vehicle_count + 1,
    'max_vehicle_count', v_company.max_vehicle_count
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.refuel_logistics_vehicle(p_player_id uuid, p_vehicle_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_vehicle record;
  v_company record;
  v_player_cash numeric;
  v_missing_fuel integer;
  v_total_cost numeric;
begin
  select *
  into v_vehicle
  from public.logistics_vehicles
  where id = p_vehicle_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'Araç bulunamadı.';
  end if;

  select *
  into v_company
  from public.logistics_companies
  where id = v_vehicle.logistics_company_id
    and player_id = p_player_id;

  if not found then
    raise exception 'Nakliye firması bulunamadı.';
  end if;

  select cash
  into v_player_cash
  from public.players
  where id = p_player_id
  for update;

  v_missing_fuel := greatest(v_vehicle.fuel_capacity - v_vehicle.current_fuel, 0);
  v_total_cost := coalesce(v_missing_fuel, 0) * coalesce(v_company.fuel_cost, 0);

  if v_total_cost > v_player_cash then
    raise exception 'Yetersiz nakit. Gerekli: %, mevcut: %', v_total_cost, v_player_cash;
  end if;

  update public.players
  set cash = cash - v_total_cost
  where id = p_player_id;

  update public.logistics_vehicles
  set current_fuel = fuel_capacity,
      updated_at = timezone('utc'::text, now())
  where id = p_vehicle_id;

  return jsonb_build_object(
    'success', true,
    'vehicle_id', p_vehicle_id,
    'fuel_added', v_missing_fuel,
    'total_cost', v_total_cost,
    'current_fuel', v_vehicle.fuel_capacity,
    'remaining_cash', v_player_cash - v_total_cost
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.repair_logistics_vehicle(p_player_id uuid, p_vehicle_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_vehicle record;
  v_player_cash numeric;
  v_missing_condition integer;
  v_total_cost numeric;
begin
  select *
  into v_vehicle
  from public.logistics_vehicles
  where id = p_vehicle_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'Araç bulunamadı.';
  end if;

  select cash
  into v_player_cash
  from public.players
  where id = p_player_id
  for update;

  v_missing_condition := greatest(100 - v_vehicle.condition, 0);
  v_total_cost := v_missing_condition * 100;

  if v_total_cost > v_player_cash then
    raise exception 'Yetersiz nakit. Gerekli: %, mevcut: %', v_total_cost, v_player_cash;
  end if;

  update public.players
  set cash = cash - v_total_cost
  where id = p_player_id;

  update public.logistics_vehicles
  set condition = 100,
      updated_at = timezone('utc'::text, now())
  where id = p_vehicle_id;

  return jsonb_build_object(
    'success', true,
    'vehicle_id', p_vehicle_id,
    'repair_cost', v_total_cost,
    'condition', 100,
    'remaining_cash', v_player_cash - v_total_cost
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.reserve_warehouse_capacity(p_player_id uuid, p_warehouse_id uuid, p_product_id text, p_quantity integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_warehouse record;
  v_product record;

  v_used_capacity numeric := 0;
  v_reserved_before numeric := 0;
  v_reserved_after numeric := 0;
  v_required_capacity numeric := 0;
  v_available_capacity numeric := 0;
begin
  if p_product_id is null or length(trim(p_product_id)) = 0 then
    raise exception 'Ürün id boş olamaz.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Rezerve edilecek miktar 0''dan büyük olmalıdır.';
  end if;

  -- Depoyu kilitle
  select *
  into v_warehouse
  from public.warehouses
  where id = p_warehouse_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'Depo bulunamadı veya oyuncuya ait değil.';
  end if;

  -- Ürünü kontrol et
  select *
  into v_product
  from public.products
  where id = p_product_id;

  if not found then
    raise exception 'Ürün bulunamadı.';
  end if;

  if v_product.birim_hacim is null or v_product.birim_hacim <= 0 then
    raise exception 'Ürünün birim_hacim değeri geçerli değil.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_reserved_before := coalesce(v_warehouse.reserved_capacity, 0);

  -- Depoda kullanılan gerçek kapasite
  select coalesce(sum(ws.quantity * p.birim_hacim), 0)
  into v_used_capacity
  from public.warehouse_slots ws
  join public.products p on p.id = ws.product_id
  where ws.warehouse_id = p_warehouse_id;

  v_available_capacity :=
    coalesce(v_warehouse.capacity, 0)
    - v_used_capacity
    - v_reserved_before;

  if v_required_capacity > v_available_capacity then
    raise exception 'Depoda yeterli boş kapasite yok. Boş kapasite: %, Gerekli kapasite: %',
      v_available_capacity,
      v_required_capacity;
  end if;

  v_reserved_after := v_reserved_before + v_required_capacity;

  update public.warehouses
  set
    reserved_capacity = v_reserved_after,
    updated_at = timezone('utc'::text, now())
  where id = p_warehouse_id;

  return jsonb_build_object(
    'success', true,
    'warehouse_id', p_warehouse_id,
    'product_id', p_product_id,
    'quantity', p_quantity,
    'unit_volume', v_product.birim_hacim,
    'reserved_added', v_required_capacity,
    'used_capacity', v_used_capacity,
    'reserved_capacity_before', v_reserved_before,
    'reserved_capacity_after', v_reserved_after,
    'available_capacity_before', v_available_capacity,
    'available_capacity_after', v_available_capacity - v_required_capacity
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.set_factory_active(p_factory_id uuid, p_is_active boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_factory public.factories%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Oturum acilmamis.';
  end if;

  update public.factories
  set is_active = p_is_active,
      updated_at = now()
  where id = p_factory_id
    and player_id = auth.uid()
  returning *
  into v_factory;

  if not found then
    raise exception 'Fabrika bulunamadi.';
  end if;

  return jsonb_build_object(
    'success', true,
    'factory', to_jsonb(v_factory)
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_factory_product(p_player_id uuid, p_factory_id uuid, p_product_id text, p_quality_level integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_factory record;
  v_product products%rowtype;
  v_max_quality integer;
  v_effective_quality integer;
  v_existing_quantity integer := 0;
  v_cleared_pending numeric := 0;
  v_is_same_setting boolean;
  v_created_input_count integer := 0;
  v_created_output_count integer := 0;
  v_deleted_obsolete_count integer := 0;
  v_output_inventory_id uuid;
  v_hammadde_1_id text;
  v_hammadde_2_id text;
  v_hammadde_3_id text;
  v_hammadde_1_miktar numeric;
  v_hammadde_2_miktar numeric;
  v_hammadde_3_miktar numeric;
  v_input_inventory_id uuid;
begin
  perform pg_advisory_xact_lock(hashtext('factory_production_lock'));

  select
    f.*,
    ft.accepted_product_ids
  into v_factory
  from factories f
  join factory_types ft on ft.id = f.factory_type_id
  where f.id = p_factory_id
  for update;

  if not found then
    raise exception 'Fabrika bulunamadi.';
  end if;

  if v_factory.player_id <> p_player_id then
    raise exception 'Bu fabrika oyuncuya ait degil.';
  end if;

  select *
  into v_product
  from products
  where id = p_product_id;

  if not found then
    raise exception 'Urun bulunamadi: %', p_product_id;
  end if;

  if lower(trim(coalesce(v_product.uretim_birimi, ''))) not in ('factory', 'fabrika') then
    raise exception 'Bu urun fabrika urunu degil: %', p_product_id;
  end if;

  if v_factory.accepted_product_ids is null
     or not (
       p_product_id = any(regexp_split_to_array(v_factory.accepted_product_ids, '\s*,\s*'))
     ) then
    raise exception 'Bu fabrika turu bu urunu uretemez: %', p_product_id;
  end if;

  select coalesce(max(max_quality_level), 1)
  into v_max_quality
  from player_product_quality_levels
  where player_id = p_player_id
    and product_id = p_product_id;

  if v_max_quality is null then
    v_max_quality := 1;
  end if;

  v_effective_quality := greatest(1, least(v_max_quality, 5));

  v_is_same_setting :=
    v_factory.product_id = p_product_id
    and v_factory.quality_level = v_effective_quality;

  if not v_is_same_setting then
    select
      coalesce(sum(quantity), 0),
      coalesce(sum(pending_quantity), 0)
    into
      v_existing_quantity,
      v_cleared_pending
    from production_inventory
    where owner_kind = 'factory'
      and owner_id = p_factory_id
      and inventory_type in ('input', 'output');

    if v_existing_quantity > 0 then
      raise exception 'Bu fabrikada input/output stogu var. Urun degistirmeden once stoklari depoya aktar.';
    end if;

    if coalesce(v_cleared_pending, 0) > 0 then
      update production_inventory
      set pending_quantity = 0
      where owner_kind = 'factory'
        and owner_id = p_factory_id
        and inventory_type in ('input', 'output');
    end if;
  else
    v_existing_quantity := 0;
    v_cleared_pending := 0;
  end if;

  update factories
  set
    product_id = p_product_id,
    quality_level = v_effective_quality,
    updated_at = timezone('utc'::text, now())
  where id = p_factory_id;

  v_hammadde_1_id := nullif(v_product.hammadde_1_id, '');
  v_hammadde_2_id := nullif(v_product.hammadde_2_id, '');
  v_hammadde_3_id := nullif(v_product.hammadde_3_id, '');

  v_hammadde_1_miktar := coalesce(v_product.hammadde_1_miktar, 0);
  v_hammadde_2_miktar := coalesce(v_product.hammadde_2_miktar, 0);
  v_hammadde_3_miktar := coalesce(v_product.hammadde_3_miktar, 0);

  if v_hammadde_1_id is not null and v_hammadde_1_miktar > 0 then
    select id
    into v_input_inventory_id
    from production_inventory
    where owner_kind = 'factory'
      and owner_id = p_factory_id
      and inventory_type = 'input'
      and product_id = v_hammadde_1_id
      and quality_level = v_effective_quality;

    if not found then
      insert into production_inventory (
        owner_kind,
        owner_id,
        inventory_type,
        product_id,
        quality_level,
        quantity,
        pending_quantity,
        cost
      )
      values (
        'factory',
        p_factory_id,
        'input',
        v_hammadde_1_id,
        v_effective_quality,
        0,
        0,
        0
      );

      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  if v_hammadde_2_id is not null and v_hammadde_2_miktar > 0 then
    select id
    into v_input_inventory_id
    from production_inventory
    where owner_kind = 'factory'
      and owner_id = p_factory_id
      and inventory_type = 'input'
      and product_id = v_hammadde_2_id
      and quality_level = v_effective_quality;

    if not found then
      insert into production_inventory (
        owner_kind,
        owner_id,
        inventory_type,
        product_id,
        quality_level,
        quantity,
        pending_quantity,
        cost
      )
      values (
        'factory',
        p_factory_id,
        'input',
        v_hammadde_2_id,
        v_effective_quality,
        0,
        0,
        0
      );

      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  if v_hammadde_3_id is not null and v_hammadde_3_miktar > 0 then
    select id
    into v_input_inventory_id
    from production_inventory
    where owner_kind = 'factory'
      and owner_id = p_factory_id
      and inventory_type = 'input'
      and product_id = v_hammadde_3_id
      and quality_level = v_effective_quality;

    if not found then
      insert into production_inventory (
        owner_kind,
        owner_id,
        inventory_type,
        product_id,
        quality_level,
        quantity,
        pending_quantity,
        cost
      )
      values (
        'factory',
        p_factory_id,
        'input',
        v_hammadde_3_id,
        v_effective_quality,
        0,
        0,
        0
      );

      v_created_input_count := v_created_input_count + 1;
    end if;
  end if;

  select id
  into v_output_inventory_id
  from production_inventory
  where owner_kind = 'factory'
    and owner_id = p_factory_id
    and inventory_type = 'output'
    and product_id = p_product_id
    and quality_level = v_effective_quality;

  if not found then
    insert into production_inventory (
      owner_kind,
      owner_id,
      inventory_type,
      product_id,
      quality_level,
      quantity,
      pending_quantity,
      cost
    )
    values (
      'factory',
      p_factory_id,
      'output',
      p_product_id,
      v_effective_quality,
      0,
      0,
      0
    )
    returning id into v_output_inventory_id;

    v_created_output_count := 1;
  end if;

  if not v_is_same_setting then
    delete from production_inventory pi
    where pi.owner_kind = 'factory'
      and pi.owner_id = p_factory_id
      and coalesce(pi.quantity, 0) = 0
      and coalesce(pi.pending_quantity, 0) = 0
      and not (
        pi.inventory_type = 'output'
        and pi.product_id = p_product_id
        and pi.quality_level = v_effective_quality
      )
      and not (
        pi.inventory_type = 'input'
        and pi.quality_level = v_effective_quality
        and (
          (v_hammadde_1_id is not null and pi.product_id = v_hammadde_1_id and v_hammadde_1_miktar > 0)
          or (v_hammadde_2_id is not null and pi.product_id = v_hammadde_2_id and v_hammadde_2_miktar > 0)
          or (v_hammadde_3_id is not null and pi.product_id = v_hammadde_3_id and v_hammadde_3_miktar > 0)
        )
      )
      and not exists (
        select 1
        from logistics_transfers lt
        where lt.seller_production_inventory_id = pi.id
           or lt.buyer_production_inventory_id = pi.id
      );

    get diagnostics v_deleted_obsolete_count = row_count;
  end if;

  return jsonb_build_object(
    'success', true,
    'factory_id', p_factory_id,
    'factory_type_id', v_factory.factory_type_id,
    'product_id', p_product_id,
    'product_name', v_product.urun_adi,
    'quality_level', v_effective_quality,
    'player_max_quality_level', v_max_quality,
    'same_setting', v_is_same_setting,
    'cleared_pending_quantity', coalesce(v_cleared_pending, 0),
    'created_input_count', v_created_input_count,
    'created_output_count', v_created_output_count,
    'deleted_obsolete_inventory_count', v_deleted_obsolete_count,
    'output_inventory_id', v_output_inventory_id
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_logistics_vehicle_active(p_player_id uuid, p_vehicle_id uuid, p_is_active boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_vehicle record;
  v_new_status text;
begin
  select *
  into v_vehicle
  from public.logistics_vehicles
  where id = p_vehicle_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'Araç bulunamadı.';
  end if;

  if v_vehicle.status = 'on_route' then
    raise exception 'Seferdeki araç durumu değiştirilemez.';
  end if;

  v_new_status := case when p_is_active then 'idle' else 'inactive' end;

  update public.logistics_vehicles
  set status = v_new_status,
      updated_at = timezone('utc'::text, now())
  where id = p_vehicle_id;

  return jsonb_build_object(
    'success', true,
    'vehicle_id', p_vehicle_id,
    'status', v_new_status
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_logistics_vehicle_rental(p_player_id uuid, p_vehicle_id uuid, p_is_available_for_rent boolean, p_rental_price numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_vehicle record;
begin
  select *
  into v_vehicle
  from public.logistics_vehicles
  where id = p_vehicle_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'Araç bulunamadı.';
  end if;

  if p_rental_price < 0 then
    raise exception 'Kira fiyatı negatif olamaz.';
  end if;

  update public.logistics_vehicles
  set is_available_for_rent = p_is_available_for_rent,
      rental_price = case when p_is_available_for_rent then p_rental_price else 0 end,
      updated_at = timezone('utc'::text, now())
  where id = p_vehicle_id;

  return jsonb_build_object(
    'success', true,
    'vehicle_id', p_vehicle_id,
    'is_available_for_rent', p_is_available_for_rent,
    'rental_price', case when p_is_available_for_rent then p_rental_price else 0 end
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_logistics_vehicle_route(p_player_id uuid, p_vehicle_id uuid, p_route_city_a_id uuid, p_route_city_b_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_vehicle record;
  v_city_a_exists boolean;
  v_city_b_exists boolean;
begin
  if p_player_id is null then
    raise exception 'Oyuncu bulunamadi.';
  end if;

  if p_route_city_a_id is null or p_route_city_b_id is null then
    raise exception 'Iki sehir secilmelidir.';
  end if;

  if p_route_city_a_id = p_route_city_b_id then
    raise exception 'Rota icin iki farkli sehir secilmelidir.';
  end if;

  select exists(select 1 from public.cities where id = p_route_city_a_id)
  into v_city_a_exists;
  if v_city_a_exists is not true then
    raise exception 'Birinci sehir bulunamadi.';
  end if;

  select exists(select 1 from public.cities where id = p_route_city_b_id)
  into v_city_b_exists;
  if v_city_b_exists is not true then
    raise exception 'Ikinci sehir bulunamadi.';
  end if;

  select lv.*, lc.is_active as company_is_active
  into v_vehicle
  from public.logistics_vehicles lv
  join public.logistics_companies lc on lc.id = lv.logistics_company_id
  where lv.id = p_vehicle_id
    and lv.player_id = p_player_id
  for update;

  if not found then
    raise exception 'Arac bulunamadi.';
  end if;

  if v_vehicle.status = 'on_route' then
    raise exception 'Seferdeki aracin rotasi degistirilemez.';
  end if;

  update public.logistics_vehicles
  set
    route_city_a_id = p_route_city_a_id,
    route_city_b_id = p_route_city_b_id,
    updated_at = timezone('utc'::text, now())
  where id = p_vehicle_id;

  return jsonb_build_object(
    'success', true,
    'vehicle_id', p_vehicle_id,
    'route_city_a_id', p_route_city_a_id,
    'route_city_b_id', p_route_city_b_id,
    'message', 'Arac rotasi guncellendi.'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_mine_active(p_mine_id uuid, p_is_active boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_mine public.mines%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Oturum acilmamis.';
  end if;

  update public.mines
  set is_active = p_is_active,
      updated_at = now()
  where id = p_mine_id
    and player_id = auth.uid()
  returning *
  into v_mine;

  if not found then
    raise exception 'Maden bulunamadi.';
  end if;

  return jsonb_build_object(
    'success', true,
    'mine', to_jsonb(v_mine)
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_mine_product(p_player_id uuid, p_mine_id uuid, p_product_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_mine record;
  v_product record;
  v_accepted_product_ids text;
  v_player_quality integer := 1;
  v_same_setting boolean := false;
  v_old_product_id text;
  v_old_quality_level integer;
  v_existing_output_quantity integer := 0;
  v_cleared_pending_quantity numeric := 0;
  v_deleted_obsolete_count integer := 0;
  v_output_inventory_id uuid;
  v_output_cost numeric := 0;
  v_output_row_count integer := 0;
begin
  if p_product_id is null or length(trim(p_product_id)) = 0 then
    raise exception 'Ürün id boş olamaz.';
  end if;

  select
    m.*,
    mt.accepted_product_ids
  into v_mine
  from public.mines m
  join public.mine_types mt on mt.id = m.mine_type_id
  where m.id = p_mine_id
  for update;

  if not found then
    raise exception 'Maden bulunamadı.';
  end if;

  if v_mine.player_id <> p_player_id then
    raise exception 'Bu maden oyuncuya ait değil.';
  end if;

  select *
  into v_product
  from public.products
  where id = p_product_id;

  if not found then
    raise exception 'Ürün bulunamadı.';
  end if;

  if lower(trim(coalesce(v_product.uretim_birimi, ''))) not in ('mine', 'maden') then
    raise exception 'Bu ürün maden ürünü değil. Üretim birimi: %', v_product.uretim_birimi;
  end if;

  if v_product.baz_satis_fiyati is null or v_product.baz_satis_fiyati < 0 then
    raise exception 'Ürünün baz_satis_fiyati değeri geçerli değil.';
  end if;

  v_output_cost := v_product.baz_satis_fiyati * 0.10;
  v_accepted_product_ids := coalesce(v_mine.accepted_product_ids, '');

  if not (
    p_product_id = any (
      string_to_array(
        replace(v_accepted_product_ids, ' ', ''),
        ','
      )
    )
  ) then
    raise exception 'Bu maden türü seçilen ürünü üretemez.';
  end if;

  select coalesce(max_quality_level, 1)
  into v_player_quality
  from public.player_product_quality_levels
  where player_id = p_player_id
    and product_id = p_product_id;

  if not found then
    v_player_quality := 1;
  end if;

  v_old_product_id := v_mine.product_id;
  v_old_quality_level := v_mine.quality_level;
  v_same_setting :=
    coalesce(v_old_product_id, '') = p_product_id
    and coalesce(v_old_quality_level, 0) = v_player_quality;

  if not v_same_setting and coalesce(v_old_product_id, '') <> '' and coalesce(v_old_quality_level, 0) > 0 then
    select coalesce(quantity, 0), coalesce(pending_quantity, 0)
    into v_existing_output_quantity, v_cleared_pending_quantity
    from public.production_inventory pi
    where pi.owner_kind = 'mine'
      and pi.owner_id = p_mine_id
      and pi.inventory_type = 'output'
      and pi.product_id = v_old_product_id
      and pi.quality_level = v_old_quality_level
    for update;

    if v_existing_output_quantity > 0 then
      raise exception 'Bu madende output stogu var. Urun degistirmeden once stoklari depoya aktar.';
    end if;

    if coalesce(v_cleared_pending_quantity, 0) > 0 then
      update public.production_inventory
      set pending_quantity = 0
      where owner_kind = 'mine'
        and owner_id = p_mine_id
        and inventory_type = 'output'
        and product_id = v_old_product_id
        and quality_level = v_old_quality_level;
    end if;
  end if;

  update public.mines
  set
    product_id = p_product_id,
    quality_level = v_player_quality,
    updated_at = timezone('utc'::text, now())
  where id = p_mine_id;

  insert into public.production_inventory (
    owner_kind,
    owner_id,
    inventory_type,
    product_id,
    quality_level,
    quantity,
    pending_quantity,
    cost
  )
  values (
    'mine',
    p_mine_id,
    'output',
    p_product_id,
    v_player_quality,
    0,
    0,
    v_output_cost
  )
  on conflict (owner_kind, owner_id, inventory_type, product_id, quality_level)
  do update set
    cost = case
      when public.production_inventory.quantity = 0
        then excluded.cost
      else public.production_inventory.cost
    end
  returning id into v_output_inventory_id;

  get diagnostics v_output_row_count = row_count;

  if not v_same_setting then
    delete from public.production_inventory pi
    where pi.owner_kind = 'mine'
      and pi.owner_id = p_mine_id
      and pi.inventory_type = 'output'
      and coalesce(pi.quantity, 0) = 0
      and coalesce(pi.pending_quantity, 0) = 0
      and not (
        pi.product_id = p_product_id
        and pi.quality_level = v_player_quality
      )
      and not exists (
        select 1
        from public.logistics_transfers lt
        where lt.seller_production_inventory_id = pi.id
           or lt.buyer_production_inventory_id = pi.id
      );

    get diagnostics v_deleted_obsolete_count = row_count;
  end if;

  return jsonb_build_object(
    'success', true,
    'mine_id', p_mine_id,
    'mine_type_id', v_mine.mine_type_id,
    'product_id', p_product_id,
    'product_name', v_product.urun_adi,
    'quality_level', v_player_quality,
    'player_max_quality_level', v_player_quality,
    'same_setting', v_same_setting,
    'cleared_pending_quantity', coalesce(v_cleared_pending_quantity, 0),
    'deleted_obsolete_inventory_count', v_deleted_obsolete_count,
    'baz_satis_fiyati', v_product.baz_satis_fiyati,
    'output_cost', v_output_cost,
    'output_inventory_id', v_output_inventory_id,
    'output_row_count', v_output_row_count
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_player_avatar(p_avatar_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player public.players%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Oturum acilmamis.';
  end if;

  update public.players
  set avatar_id = p_avatar_id,
      updated_at = now()
  where id = auth.uid()
  returning *
  into v_player;

  if not found then
    raise exception 'Oyuncu kaydi bulunamadi.';
  end if;

  return jsonb_build_object(
    'success', true,
    'message', 'Avatar guncellendi.',
    'player', to_jsonb(v_player)
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_store_slot_active(p_player_id uuid, p_store_slot_id uuid, p_is_active boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_slot record;
begin
  -- Slotu ve bağlı mağazayı kilitleyerek al
  select
    ss.*,
    s.player_id
  into v_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  where ss.id = p_store_slot_id
  for update;

  if not found then
    raise exception 'Mağaza slotu bulunamadı.';
  end if;

  if v_slot.player_id <> p_player_id then
    raise exception 'Bu slot oyuncuya ait değil.';
  end if;

  update public.store_slots
  set
    is_active = p_is_active,
    updated_at = timezone('utc'::text, now())
  where id = p_store_slot_id;

  return jsonb_build_object(
    'success', true,
    'store_slot_id', p_store_slot_id,
    'store_id', v_slot.store_id,
    'is_active', p_is_active
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_store_slot_price(p_player_id uuid, p_store_slot_id uuid, p_price numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_slot record;
begin
  -- Slotu ve bağlı mağazayı kilitleyerek al
  select
    ss.*,
    s.player_id
  into v_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  where ss.id = p_store_slot_id
  for update;

  if not found then
    raise exception 'Mağaza slotu bulunamadı.';
  end if;

  if v_slot.player_id <> p_player_id then
    raise exception 'Bu slot oyuncuya ait değil.';
  end if;

  if v_slot.product_id is null or v_slot.quality_level = 0 then
    raise exception 'Fiyat belirlemek için önce slotta ürün ve kalite seçilmelidir.';
  end if;

  if p_price is null or p_price <= 0 then
    raise exception 'Satış fiyatı 0''dan büyük olmalıdır.';
  end if;

  update public.store_slots
  set
    price = p_price,
    updated_at = timezone('utc'::text, now())
  where id = p_store_slot_id;

  return jsonb_build_object(
    'success', true,
    'store_slot_id', p_store_slot_id,
    'store_id', v_slot.store_id,
    'product_id', v_slot.product_id,
    'quality_level', v_slot.quality_level,
    'price', p_price
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_store_slot_product(p_player_id uuid, p_store_slot_id uuid, p_product_id text, p_quality_level integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_slot record;
begin
  select ss.*, s.player_id
  into v_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  where ss.id = p_store_slot_id
  for update;

  if not found then
    raise exception 'Magaza slotu bulunamadi.';
  end if;

  if v_slot.player_id <> p_player_id then
    raise exception 'Bu slot oyuncuya ait degil.';
  end if;

  if p_product_id is null or length(trim(p_product_id)) = 0 then
    raise exception 'Urun id bos olamaz.';
  end if;

  if not exists (
    select 1 from public.products where id = p_product_id
  ) then
    raise exception 'Urun bulunamadi.';
  end if;

  if p_quality_level < 1 or p_quality_level > 5 then
    raise exception 'Kalite seviyesi 1 ile 5 arasinda olmalidir.';
  end if;

  if v_slot.quantity > 0 or coalesce(v_slot.pending_quantity, 0) > 0 then
    raise exception 'Stok veya yoldaki urun bulunan slotta urun veya kalite degistirilemez.';
  end if;

  update public.store_slots
  set
    product_id = p_product_id,
    quality_level = p_quality_level,
    updated_at = timezone('utc'::text, now())
  where id = p_store_slot_id;

  return jsonb_build_object(
    'success', true,
    'store_slot_id', p_store_slot_id,
    'store_id', v_slot.store_id,
    'product_id', p_product_id,
    'quality_level', p_quality_level
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.set_warehouse_slot_price(p_player_id uuid, p_warehouse_slot_id uuid, p_price numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_warehouse_id UUID;
    v_owner_id UUID;
BEGIN
    SELECT warehouse_id INTO v_warehouse_id
    FROM public.warehouse_slots
    WHERE id = p_warehouse_slot_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Slot bulunamadı.');
    END IF;

    SELECT player_id INTO v_owner_id
    FROM public.warehouses
    WHERE id = v_warehouse_id;

    IF v_owner_id IS NULL OR v_owner_id != p_player_id THEN
        RETURN jsonb_build_object('success', false, 'message', 'Bu depoda yetkiniz yok.');
    END IF;

    IF p_price <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Fiyat 0 dan büyük olmalıdır.');
    END IF;

    UPDATE public.warehouse_slots
    SET price = p_price
    WHERE id = p_warehouse_slot_id;

    RETURN jsonb_build_object('success', true, 'message', 'Satış fiyatı başarıyla güncellendi.');
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.set_warehouse_slot_sale_status(p_player_id uuid, p_warehouse_slot_id uuid, p_is_available_for_sale boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_slot record;
begin
  -- Depo slotunu ve depo sahipliğini kilitleyerek al
  select
    ws.*,
    w.player_id
  into v_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  where ws.id = p_warehouse_slot_id
  for update;

  if not found then
    raise exception 'Depo slotu bulunamadı.';
  end if;

  if v_slot.player_id <> p_player_id then
    raise exception 'Bu depo slotu oyuncuya ait değil.';
  end if;

  if p_is_available_for_sale = true then
    if v_slot.product_id is null or length(trim(v_slot.product_id)) = 0 then
      raise exception 'Ürün seçilmemiş depo slotu satışa açılamaz.';
    end if;

    if v_slot.quality_level < 1 or v_slot.quality_level > 5 then
      raise exception 'Geçerli kalite seviyesi olmayan depo slotu satışa açılamaz.';
    end if;
  end if;

  update public.warehouse_slots
  set
    is_available_for_sale = p_is_available_for_sale,
    updated_at = timezone('utc'::text, now())
  where id = p_warehouse_slot_id;

  return jsonb_build_object(
    'success', true,
    'warehouse_slot_id', p_warehouse_slot_id,
    'warehouse_id', v_slot.warehouse_id,
    'product_id', v_slot.product_id,
    'quality_level', v_slot.quality_level,
    'quantity', v_slot.quantity,
    'is_available_for_sale', p_is_available_for_sale
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.start_arge_research(p_player_id uuid, p_product_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player players%rowtype;
  v_product products%rowtype;
  v_quality_row player_product_quality_levels%rowtype;
  v_current_quality integer;
  v_target_quality integer;
  v_required_level integer;
  v_cost numeric;
  v_duration_hours integer;
  v_finish_at timestamptz;
  v_new_id uuid;
  v_multipliers integer[] := array[10, 25, 60, 150];
  v_minimum_costs numeric[] := array[2500, 15000, 75000, 300000];
  v_durations integer[] := array[2, 5, 10, 24];
begin
  select * into v_player from players where id = p_player_id;
  if not found then
    return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.');
  end if;

  select * into v_product from products where id = p_product_id;
  if not found then
    return jsonb_build_object('success', false, 'message', 'Urun bulunamadi.');
  end if;

  select * into v_quality_row
  from player_product_quality_levels
  where player_id = p_player_id and product_id = p_product_id;

  v_current_quality := case when found then v_quality_row.max_quality_level else 1 end;

  if v_current_quality >= 5 then
    return jsonb_build_object('success', false, 'message', 'Bu urun zaten maksimum kalite seviyesinde (5).');
  end if;

  v_target_quality := v_current_quality + 1;
  v_required_level := v_target_quality * 10;

  if v_player.level < v_required_level then
    return jsonb_build_object(
      'success', false,
      'message', format('Bu gelistirme icin seviye %s gerekli. Mevcut seviyeniz: %s.', v_required_level, v_player.level)
    );
  end if;

  v_cost := greatest(
    v_product.baz_satis_fiyati * v_multipliers[v_current_quality],
    v_minimum_costs[v_current_quality]
  );

  if v_player.cash < v_cost then
    return jsonb_build_object(
      'success', false,
      'message', format('Yetersiz bakiye. Gerekli: %s₺, Mevcut: %s₺.', v_cost::bigint, v_player.cash::bigint)
    );
  end if;

  if exists (
    select 1 from arge_researches
    where player_id = p_player_id and status = 'in_progress'
  ) then
    return jsonb_build_object('success', false, 'message', 'Zaten devam eden bir AR-GE arastirmaniz var.');
  end if;

  v_duration_hours := v_durations[v_current_quality];
  v_finish_at := timezone('utc', now()) + (v_duration_hours || ' hours')::interval;

  update players
  set cash = cash - v_cost
  where id = p_player_id;

  insert into arge_researches (
    player_id, product_id, product_name,
    current_quality, target_quality,
    cost_paid, status, finish_at
  ) values (
    p_player_id, p_product_id, v_product.urun_adi,
    v_current_quality, v_target_quality,
    v_cost, 'in_progress', v_finish_at
  ) returning id into v_new_id;

  return jsonb_build_object(
    'success', true,
    'research_id', v_new_id,
    'product_name', v_product.urun_adi,
    'current_quality', v_current_quality,
    'target_quality', v_target_quality,
    'cost_paid', v_cost,
    'finish_at', v_finish_at,
    'duration_hours', v_duration_hours
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.start_building_construction(p_player_id uuid, p_building_kind text, p_type_id uuid, p_city_id uuid, p_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_player public.players%rowtype;
  v_cost integer;
  v_required_level integer;
  v_construction_time_minutes integer;
  v_construction_id uuid;
  v_finish_at timestamptz;
  v_params jsonb;
  v_clean_name text;
begin
  select * into v_player
  from public.players
  where id = p_player_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.');
  end if;

  if not exists (
    select 1 from public.cities where id = p_city_id and is_active = true
  ) then
    return jsonb_build_object('success', false, 'message', 'Sehir bulunamadi.');
  end if;

  if exists (
    select 1
    from public.building_constructions
    where player_id = p_player_id and status = 'in_progress'
  ) then
    return jsonb_build_object('success', false, 'message', 'Devam eden bir insaat zaten var.');
  end if;

  v_clean_name := nullif(trim(p_name), '');

  if p_building_kind = 'store' then
    select
      coalesce(cost, 0),
      coalesce(required_level, 1),
      coalesce(construction_time_minutes, 0),
      jsonb_build_object(
        'store_type_id', id,
        'city_id', p_city_id,
        'name', v_clean_name,
        'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1),
        'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1,
        'current_slot_count', 0,
        'max_slot_count', coalesce(max_slot_count, 0),
        'slot_capacity', coalesce(slot_capacity, 0)
      )
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.store_types
    where id = p_type_id;

  elsif p_building_kind = 'warehouse' then
    select
      coalesce(cost, 0),
      coalesce(required_level, 1),
      coalesce(construction_time_minutes, 0),
      jsonb_build_object(
        'warehouse_type_id', id,
        'city_id', p_city_id,
        'name', v_clean_name,
        'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1),
        'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1,
        'capacity', coalesce(base_capacity, 0),
        'reserved_capacity', 0
      )
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.warehouse_types
    where id = p_type_id;

  elsif p_building_kind = 'factory' then
    select
      coalesce(cost, 0),
      coalesce(required_level, 1),
      coalesce(construction_time_minutes, 0),
      jsonb_build_object(
        'factory_type_id', id,
        'city_id', p_city_id,
        'name', v_clean_name,
        'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1),
        'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1,
        'quality_level', 0,
        'boost_multiplier', 1.00,
        'input_capacity', coalesce(input_capacity, 0),
        'output_capacity', coalesce(output_capacity, 0)
      )
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.factory_types
    where id = p_type_id;

  elsif p_building_kind = 'field' then
    select
      coalesce(cost, 0),
      coalesce(required_level, 1),
      coalesce(construction_time_minutes, 0),
      jsonb_build_object(
        'field_type_id', id,
        'city_id', p_city_id,
        'name', v_clean_name,
        'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1),
        'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1,
        'current_slot_count', 0,
        'max_slot_count', coalesce(max_slot_count, 5),
        'input_capacity', coalesce(input_capacity, 0),
        'output_capacity', coalesce(output_capacity, 0)
      )
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.field_types
    where id = p_type_id;

  elsif p_building_kind = 'farm' then
    select
      coalesce(cost, 0),
      coalesce(required_level, 1),
      coalesce(construction_time_minutes, 0),
      jsonb_build_object(
        'farm_type_id', id,
        'city_id', p_city_id,
        'name', v_clean_name,
        'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1),
        'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1,
        'current_slot_count', 0,
        'max_slot_count', coalesce(max_slot_count, 5),
        'input_capacity', coalesce(input_capacity, 0),
        'output_capacity', coalesce(output_capacity, 0)
      )
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.farm_types
    where id = p_type_id;

  elsif p_building_kind = 'mine' then
    select
      coalesce(cost, 0),
      coalesce(required_level, 1),
      coalesce(construction_time_minutes, 0),
      jsonb_build_object(
        'mine_type_id', id,
        'city_id', p_city_id,
        'name', v_clean_name,
        'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1),
        'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1,
        'output_capacity', coalesce(output_capacity, 0)
      )
    into v_cost, v_required_level, v_construction_time_minutes, v_params
    from public.mine_types
    where id = p_type_id;

  else
    return jsonb_build_object('success', false, 'message', 'Desteklenmeyen yapi tipi.');
  end if;

  if v_cost is null then
    return jsonb_build_object('success', false, 'message', 'Yapi tipi bulunamadi.');
  end if;

  if coalesce(v_player.level, 1) < v_required_level then
    return jsonb_build_object('success', false, 'message', 'Seviye yetersiz.');
  end if;

  if coalesce(v_player.cash, 0) < v_cost then
    return jsonb_build_object('success', false, 'message', 'Yetersiz nakit.');
  end if;

  update public.players
  set cash = cash - v_cost
  where id = p_player_id;

  v_finish_at := timezone('utc', now()) + make_interval(mins => v_construction_time_minutes);

  insert into public.building_constructions (
    player_id,
    building_kind,
    params,
    status,
    started_at,
    finish_at,
    completed_at
  )
  values (
    p_player_id,
    p_building_kind,
    v_params,
    'in_progress',
    timezone('utc', now()),
    v_finish_at,
    null
  )
  returning id into v_construction_id;

  return jsonb_build_object(
    'success', true,
    'construction_id', v_construction_id,
    'building_kind', p_building_kind,
    'status', 'in_progress',
    'started_at', timezone('utc', now()),
    'finish_at', v_finish_at,
    'cost', v_cost,
    'remaining_cash', coalesce(v_player.cash, 0) - v_cost,
    'params', v_params
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.start_logistics_company_construction(p_player_id uuid, p_type_id uuid, p_name text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player_level integer;
  v_player_cash numeric;
  v_cost integer;
  v_required_level integer;
  v_construction_time_minutes integer;
  v_params jsonb;
  v_construction_id uuid;
  v_started_at timestamptz := timezone('utc'::text, now());
  v_finish_at timestamptz;
  v_clean_name text := trim(p_name);
begin
  if v_clean_name is null or length(v_clean_name) = 0 then
    raise exception 'Yapı adı boş olamaz.';
  end if;

  if p_type_id is null then
    raise exception 'p_type_id boş olamaz.';
  end if;

  select level, cash
  into v_player_level, v_player_cash
  from public.players
  where id = p_player_id
  for update;

  if not found then
    raise exception 'Oyuncu bulunamadı.';
  end if;

  if exists (
    select 1
    from public.building_constructions
    where player_id = p_player_id
      and status = 'in_progress'
  ) then
    raise exception 'Oyuncunun zaten aktif bir inşaatı var.';
  end if;

  select
    coalesce(cost, 0),
    coalesce(required_level, 1),
    coalesce(construction_time_minutes, 0),
    jsonb_build_object(
      'logistics_company_type_id', id,
      'name', v_clean_name,
      'cost', coalesce(cost, 0),
      'required_level', coalesce(required_level, 1),
      'construction_time_minutes', coalesce(construction_time_minutes, 0),
      'level', 1,
      'current_vehicle_count', 0,
      'max_vehicle_count', coalesce(max_vehicle_count, 0),
      'fuel_capacity', coalesce(fuel_capacity, 0),
      'current_fuel', 0,
      'fuel_cost', 0
    )
  into v_cost, v_required_level, v_construction_time_minutes, v_params
  from public.logistics_company_types
  where id = p_type_id;

  if v_params is null then
    raise exception 'Geçerli type kaydı bulunamadı.';
  end if;

  if v_player_level < v_required_level then
    raise exception 'Oyuncu seviyesi yetersiz. Gerekli seviye: %, oyuncu seviyesi: %',
      v_required_level,
      v_player_level;
  end if;

  if v_player_cash < v_cost then
    raise exception 'Oyuncunun parası yetersiz. Gerekli: %, mevcut: %',
      v_cost,
      v_player_cash;
  end if;

  v_finish_at := v_started_at + make_interval(mins => v_construction_time_minutes);

  update public.players
  set cash = cash - v_cost
  where id = p_player_id;

  insert into public.building_constructions (
    player_id,
    building_kind,
    params,
    status,
    started_at,
    finish_at,
    completed_at
  ) values (
    p_player_id,
    'logistics_company',
    v_params,
    'in_progress',
    v_started_at,
    v_finish_at,
    null
  )
  returning id into v_construction_id;

  return jsonb_build_object(
    'success', true,
    'construction_id', v_construction_id,
    'building_kind', 'logistics_company',
    'status', 'in_progress',
    'started_at', v_started_at,
    'finish_at', v_finish_at,
    'cost', v_cost,
    'remaining_cash', v_player_cash - v_cost,
    'params', v_params
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.start_market_to_store_transfer(p_store_slot_id uuid, p_seller_slot_id uuid, p_quantity integer, p_vehicle_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_buyer_id uuid := auth.uid();
  v_buyer_player record;
  v_seller_player record;
  v_store_slot record;
  v_seller_slot record;
  v_product record;
  v_vehicle record;
  v_transfer_id uuid;
  v_distance_km numeric := 0;
  v_required_capacity numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_rental_cost numeric := 0;
  v_transport_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz;
  v_total_price numeric := 0;
  v_unit_price numeric := 0;
  v_incoming_unit_cost numeric := 0;
  v_new_cost numeric := 0;
  v_now timestamptz := timezone('utc'::text, now());
begin
  if v_buyer_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select * into v_buyer_player
  from public.players
  where id = v_buyer_id
  for update;

  if not found then
    raise exception 'Alici oyuncu bulunamadi.';
  end if;

  select ss.*, s.player_id, s.id as buyer_store_id, s.is_active as store_is_active,
         s.city_id as store_city_id,
         c.map_position_x as city_x, c.map_position_y as city_y
  into v_store_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  join public.cities c on c.id = s.city_id
  where ss.id = p_store_slot_id
  for update;

  if not found or v_store_slot.player_id <> v_buyer_id then
    raise exception 'Magaza slotu bulunamadi veya size ait degil.';
  end if;

  if v_store_slot.store_is_active is not true then
    raise exception 'Magaza aktif degil.';
  end if;

  select ws.*, w.player_id as seller_player_id, w.id as seller_warehouse_id,
         w.city_id as seller_city_id,
         c.map_position_x as city_x, c.map_position_y as city_y
  into v_seller_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  join public.cities c on c.id = w.city_id
  where ws.id = p_seller_slot_id
  for update;

  if not found then
    raise exception 'Satici slotu bulunamadi.';
  end if;

  if v_seller_slot.is_available_for_sale is not true then
    raise exception 'Bu slot su anda satisa acik degil.';
  end if;

  if p_quantity > v_seller_slot.quantity then
    raise exception 'Istenen miktar mevcut stoktan fazla.';
  end if;

  if v_seller_slot.seller_player_id = v_buyer_id then
    raise exception 'Kendi ilaninizi satin alamazsiniz.';
  end if;

  if v_store_slot.product_id is null or v_store_slot.quality_level = 0 then
    if coalesce(v_store_slot.quantity, 0) > 0 or coalesce(v_store_slot.pending_quantity, 0) > 0 then
      raise exception 'Slotta aktif stok veya rezerve varken urun atanamaz.';
    end if;

    update public.store_slots
    set
      product_id = v_seller_slot.product_id,
      quality_level = v_seller_slot.quality_level,
      updated_at = v_now
    where id = p_store_slot_id;

    v_store_slot.product_id := v_seller_slot.product_id;
    v_store_slot.quality_level := v_seller_slot.quality_level;
  elsif v_store_slot.product_id <> v_seller_slot.product_id
     or v_store_slot.quality_level <> v_seller_slot.quality_level then
    raise exception 'Magaza slotu urun veya kalite uyusmazligi.';
  end if;

  if (coalesce(v_store_slot.quantity, 0) + coalesce(v_store_slot.pending_quantity, 0) + p_quantity) > v_store_slot.capacity then
    raise exception 'Magaza slot kapasitesi yetersiz.';
  end if;

  select * into v_seller_player
  from public.players
  where id = v_seller_slot.seller_player_id
  for update;

  if not found then
    raise exception 'Satici oyuncu bulunamadi.';
  end if;

  select * into v_product
  from public.products
  where id = v_seller_slot.product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_unit_price := coalesce(v_seller_slot.price, 0);
  if v_unit_price <= 0 then
    raise exception 'Bu ilan icin gecerli satis fiyati yok.';
  end if;
  v_total_price := p_quantity * v_unit_price;

  if coalesce(v_buyer_player.cash, 0) < v_total_price then
    raise exception 'Yeterli nakit yok.';
  end if;

  if v_store_slot.store_city_id = v_seller_slot.seller_city_id then
    v_incoming_unit_cost := v_unit_price;
    v_new_cost := case
      when coalesce(v_store_slot.quantity, 0) + p_quantity > 0 then
        (
          coalesce(v_store_slot.quantity, 0) * coalesce(v_store_slot.cost, 0)
          + p_quantity * v_incoming_unit_cost
        ) / (coalesce(v_store_slot.quantity, 0) + p_quantity)
      else coalesce(v_store_slot.cost, 0)
    end;

    update public.warehouse_slots
    set
      quantity = quantity - p_quantity,
      is_available_for_sale = case when quantity - p_quantity > 0 then is_available_for_sale else false end,
      updated_at = v_now
    where id = p_seller_slot_id;

    update public.players
    set cash = cash - v_total_price
    where id = v_buyer_id;

    update public.players
    set cash = cash + v_total_price
    where id = v_seller_slot.seller_player_id;

    update public.store_slots
    set
      quantity = quantity + p_quantity,
      cost = v_new_cost,
      updated_at = v_now
    where id = p_store_slot_id;

    insert into public.logistics_transfers (
      buyer_player_id,
      seller_player_id,
      buyer_store_id,
      buyer_store_slot_id,
      seller_warehouse_id,
      seller_warehouse_slot_id,
      logistics_vehicle_id,
      vehicle_owner_player_id,
      is_rental,
      product_id,
      quality_level,
      quantity,
      unit_price,
      total_price,
      product_unit_volume,
      reserved_capacity_amount,
      distance_km,
      fuel_used,
      condition_loss,
      rental_cost,
      transport_cost,
      transfer_type,
      started_at,
      finish_at,
      completed_at,
      status,
      updated_at
    )
    values (
      v_buyer_id,
      v_seller_slot.seller_player_id,
      v_store_slot.buyer_store_id,
      p_store_slot_id,
      v_seller_slot.seller_warehouse_id,
      p_seller_slot_id,
      null,
      null,
      false,
      v_seller_slot.product_id,
      v_seller_slot.quality_level,
      p_quantity,
      v_unit_price,
      v_total_price,
      v_product.birim_hacim,
      0,
      0,
      0,
      0,
      0,
      0,
      'market_to_store',
      v_now,
      v_now,
      v_now,
      'completed',
      v_now
    )
    returning id into v_transfer_id;

    return jsonb_build_object(
      'success', true,
      'mode', 'instant',
      'transfer_id', v_transfer_id,
      'store_slot_id', p_store_slot_id,
      'seller_slot_id', p_seller_slot_id,
      'product_id', v_seller_slot.product_id,
      'quality_level', v_seller_slot.quality_level,
      'quantity', p_quantity,
      'unit_price', v_unit_price,
      'total_price', v_total_price,
      'transport_cost', 0,
      'rental_cost', 0,
      'new_cost', v_new_cost
    );
  end if;

  if p_vehicle_id is null then
    raise exception 'Farkli sehir transferi icin arac secilmelidir.';
  end if;

  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_seller_slot.city_x - v_store_slot.city_x) / 2)), 2) +
      cos(radians(v_store_slot.city_x)) *
      cos(radians(v_seller_slot.city_x)) *
      power(sin(radians((v_seller_slot.city_y - v_store_slot.city_y) / 2)), 2)
    )
  );

  select lv.*, lc.is_active as company_is_active
  into v_vehicle
  from public.logistics_vehicles lv
  join public.logistics_companies lc on lc.id = lv.logistics_company_id
  where lv.id = p_vehicle_id
  for update;

  if not found then
    raise exception 'Arac bulunamadi.';
  end if;

  if v_vehicle.status <> 'idle' then
    raise exception 'Arac su anda uygun degil.';
  end if;

  if v_vehicle.company_is_active is not true then
    raise exception 'Aracin firmasi aktif degil.';
  end if;

  if v_vehicle.player_id <> v_buyer_id and v_vehicle.is_available_for_rent is not true then
    raise exception 'Kiralik arac uygun degil.';
  end if;

  if public.logistics_vehicle_matches_route(v_vehicle.route_city_a_id, v_vehicle.route_city_b_id, v_seller_slot.seller_city_id, v_store_slot.store_city_id) is not true then
    raise exception 'Bu arac secilen sehir cifti icin atanmis degil.';
  end if;

  v_fuel_used := ceil(v_distance_km * v_vehicle.fuel_rate);
  v_condition_loss := ceil(v_distance_km * 0.02);

  if v_vehicle.capacity < v_required_capacity then
    raise exception 'Arac kapasitesi yetersiz.';
  end if;

  if v_vehicle.current_fuel < v_fuel_used then
    raise exception 'Aracin yakiti yetersiz.';
  end if;

  if v_vehicle.condition <= v_condition_loss then
    raise exception 'Aracin kondisyonu yetersiz.';
  end if;

  v_rental_cost := case
    when v_vehicle.player_id <> v_buyer_id then ceil(v_distance_km * coalesce(v_vehicle.rental_price, 0))
    else 0
  end;
  v_transport_cost := v_rental_cost;
  v_duration_seconds := greatest(1, ceil(((v_distance_km / greatest(v_vehicle.speed_kmh, 1)) / 4.0) * 3600));
  v_finish_at := timezone('utc'::text, now()) + make_interval(secs => v_duration_seconds);

  if coalesce(v_buyer_player.cash, 0) < (v_total_price + v_rental_cost) then
    raise exception 'Yeterli nakit yok.';
  end if;

  update public.warehouse_slots
  set
    quantity = quantity - p_quantity,
    is_available_for_sale = case when quantity - p_quantity > 0 then is_available_for_sale else false end,
    updated_at = timezone('utc'::text, now())
  where id = p_seller_slot_id;

  update public.players
  set cash = cash - v_total_price - v_rental_cost
  where id = v_buyer_id;

  update public.players
  set cash = cash + v_total_price
  where id = v_seller_slot.seller_player_id;

  if v_rental_cost > 0 then
    update public.players
    set cash = cash + v_rental_cost
    where id = v_vehicle.player_id;
  end if;

  update public.logistics_vehicles
  set
    current_fuel = greatest(current_fuel - v_fuel_used::integer, 0),
    condition = greatest(condition - v_condition_loss::integer, 0),
    status = 'on_route',
    updated_at = timezone('utc'::text, now())
  where id = p_vehicle_id;

  update public.store_slots
  set
    pending_quantity = coalesce(pending_quantity, 0) + p_quantity,
    updated_at = timezone('utc'::text, now())
  where id = p_store_slot_id;

  insert into public.logistics_transfers (
    buyer_player_id,
    seller_player_id,
    buyer_warehouse_id,
    buyer_store_id,
    buyer_store_slot_id,
    seller_warehouse_id,
    seller_warehouse_slot_id,
    logistics_vehicle_id,
    vehicle_owner_player_id,
    is_rental,
    product_id,
    quality_level,
    quantity,
    unit_price,
    total_price,
    product_unit_volume,
    reserved_capacity_amount,
    distance_km,
    fuel_used,
    condition_loss,
    rental_cost,
    transport_cost,
    transfer_type,
    started_at,
    finish_at,
    status,
    updated_at
  )
  values (
    v_buyer_id,
    v_seller_slot.seller_player_id,
    null,
    v_store_slot.buyer_store_id,
    p_store_slot_id,
    v_seller_slot.seller_warehouse_id,
    p_seller_slot_id,
    p_vehicle_id,
    v_vehicle.player_id,
    (v_vehicle.player_id <> v_buyer_id),
    v_seller_slot.product_id,
    v_seller_slot.quality_level,
    p_quantity,
    v_unit_price,
    v_total_price,
    v_product.birim_hacim,
    p_quantity,
    v_distance_km,
    v_fuel_used,
    v_condition_loss,
    v_rental_cost,
    v_transport_cost,
    'market_to_store',
    timezone('utc'::text, now()),
    v_finish_at,
    'in_transit',
    timezone('utc'::text, now())
  )
  returning id into v_transfer_id;

  return jsonb_build_object(
    'success', true,
    'mode', 'transfer',
    'transfer_id', v_transfer_id,
    'vehicle_id', p_vehicle_id,
    'seller_slot_id', p_seller_slot_id,
    'store_slot_id', p_store_slot_id,
    'product_id', v_seller_slot.product_id,
    'quality_level', v_seller_slot.quality_level,
    'quantity', p_quantity,
    'unit_price', v_unit_price,
    'total_price', v_total_price,
    'rental_cost', v_rental_cost,
    'transport_cost', v_transport_cost,
    'distance_km', round(v_distance_km, 2),
    'fuel_used', v_fuel_used,
    'condition_loss', v_condition_loss,
    'duration_seconds', v_duration_seconds,
    'finish_at', v_finish_at
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.start_market_transfer(p_buyer_warehouse_id uuid, p_seller_slot_id uuid, p_quantity integer, p_vehicle_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_buyer_id uuid := auth.uid();
  v_buyer_player record;
  v_seller_player record;
  v_buyer_warehouse record;
  v_seller_slot record;
  v_product record;
  v_vehicle record;
  v_reserve_result jsonb;
  v_add_result jsonb;
  v_transfer_id uuid;
  v_distance_km numeric := 0;
  v_required_capacity numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_rental_cost numeric := 0;
  v_transport_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz;
  v_total_price numeric := 0;
  v_unit_price numeric := 0;
  v_now timestamptz := timezone('utc'::text, now());
begin
  if v_buyer_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select * into v_buyer_player
  from public.players
  where id = v_buyer_id
  for update;

  if not found then
    raise exception 'Alici oyuncu bulunamadi.';
  end if;

  select w.*, c.map_position_x as city_x, c.map_position_y as city_y
  into v_buyer_warehouse
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id
    and w.player_id = v_buyer_id
  for update;

  if not found then
    raise exception 'Alici deposu bulunamadi veya size ait degil.';
  end if;

  if v_buyer_warehouse.is_active is not true then
    raise exception 'Alici deposu aktif degil.';
  end if;

  select ws.*, w.player_id as seller_player_id, w.id as seller_warehouse_id,
         w.city_id as seller_city_id,
         c.map_position_x as city_x, c.map_position_y as city_y
  into v_seller_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  join public.cities c on c.id = w.city_id
  where ws.id = p_seller_slot_id
  for update;

  if not found then
    raise exception 'Satici slotu bulunamadi.';
  end if;

  if v_seller_slot.is_available_for_sale is not true then
    raise exception 'Bu slot su anda satisa acik degil.';
  end if;

  if p_quantity > v_seller_slot.quantity then
    raise exception 'Istenen miktar mevcut stoktan fazla.';
  end if;

  if v_seller_slot.seller_player_id = v_buyer_id then
    raise exception 'Kendi ilaninizi satin alamazsiniz.';
  end if;

  select * into v_seller_player
  from public.players
  where id = v_seller_slot.seller_player_id
  for update;

  if not found then
    raise exception 'Satici oyuncu bulunamadi.';
  end if;

  select * into v_product
  from public.products
  where id = v_seller_slot.product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_unit_price := coalesce(v_seller_slot.price, 0);

  if v_unit_price <= 0 then
    raise exception 'Bu ilan icin gecerli satis fiyati yok.';
  end if;

  v_total_price := p_quantity * v_unit_price;

  if v_seller_slot.seller_city_id = v_buyer_warehouse.city_id then
    if coalesce(v_buyer_player.cash, 0) < v_total_price then
      raise exception 'Yeterli nakit yok.';
    end if;

    update public.warehouse_slots
    set
      quantity = quantity - p_quantity,
      is_available_for_sale = case when quantity - p_quantity > 0 then is_available_for_sale else false end,
      updated_at = v_now
    where id = p_seller_slot_id;

    update public.players
    set cash = cash - v_total_price
    where id = v_buyer_id;

    update public.players
    set cash = cash + v_total_price
    where id = v_seller_slot.seller_player_id;

    v_add_result := public.add_product_to_warehouse(
      v_buyer_id,
      p_buyer_warehouse_id,
      v_seller_slot.product_id,
      v_seller_slot.quality_level,
      p_quantity,
      v_unit_price,
      0,
      false
    );

    insert into public.logistics_transfers (
      buyer_player_id,
      seller_player_id,
      buyer_warehouse_id,
      seller_warehouse_id,
      seller_warehouse_slot_id,
      logistics_vehicle_id,
      vehicle_owner_player_id,
      is_rental,
      product_id,
      quality_level,
      quantity,
      unit_price,
      total_price,
      product_unit_volume,
      reserved_capacity_amount,
      distance_km,
      fuel_used,
      condition_loss,
      rental_cost,
      transport_cost,
      started_at,
      finish_at,
      completed_at,
      status,
      updated_at
    )
    values (
      v_buyer_id,
      v_seller_slot.seller_player_id,
      p_buyer_warehouse_id,
      v_seller_slot.seller_warehouse_id,
      p_seller_slot_id,
      null,
      null,
      false,
      v_seller_slot.product_id,
      v_seller_slot.quality_level,
      p_quantity,
      v_unit_price,
      v_total_price,
      v_product.birim_hacim,
      0,
      0,
      0,
      0,
      0,
      0,
      v_now,
      v_now,
      v_now,
      'completed',
      v_now
    )
    returning id into v_transfer_id;

    return jsonb_build_object(
      'success', true,
      'mode', 'instant',
      'transfer_id', v_transfer_id,
      'warehouse_result', v_add_result,
      'seller_slot_id', p_seller_slot_id,
      'product_id', v_seller_slot.product_id,
      'quality_level', v_seller_slot.quality_level,
      'quantity', p_quantity,
      'unit_price', v_unit_price,
      'total_price', v_total_price
    );
  end if;

  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_seller_slot.city_x - v_buyer_warehouse.city_x) / 2)), 2) +
      cos(radians(v_buyer_warehouse.city_x)) *
      cos(radians(v_seller_slot.city_x)) *
      power(sin(radians((v_seller_slot.city_y - v_buyer_warehouse.city_y) / 2)), 2)
    )
  );

  select lv.*, lc.is_active as company_is_active
  into v_vehicle
  from public.logistics_vehicles lv
  join public.logistics_companies lc on lc.id = lv.logistics_company_id
  where lv.id = p_vehicle_id
  for update;

  if not found then
    raise exception 'Arac bulunamadi.';
  end if;

  if v_vehicle.player_id = v_seller_slot.seller_player_id then
    raise exception 'Saticinin araci kullanilamaz.';
  end if;

  if v_vehicle.player_id <> v_buyer_id and v_vehicle.is_available_for_rent is not true then
    raise exception 'Kiralik arac uygun degil.';
  end if;

  if v_vehicle.status <> 'idle' then
    raise exception 'Arac su anda uygun degil.';
  end if;

  if v_vehicle.company_is_active is not true then
    raise exception 'Aracin firmasi aktif degil.';
  end if;

  if public.logistics_vehicle_matches_route(v_vehicle.route_city_a_id, v_vehicle.route_city_b_id, v_seller_slot.seller_city_id, v_buyer_warehouse.city_id) is not true then
    raise exception 'Bu arac secilen sehir cifti icin atanmis degil.';
  end if;

  v_fuel_used := ceil(v_distance_km * v_vehicle.fuel_rate);
  v_condition_loss := ceil(v_distance_km * 0.02);

  if v_vehicle.capacity < v_required_capacity then
    raise exception 'Arac kapasitesi yetersiz.';
  end if;

  if v_vehicle.current_fuel < v_fuel_used then
    raise exception 'Aracin yakiti yetersiz.';
  end if;

  if v_vehicle.condition <= v_condition_loss then
    raise exception 'Aracin kondisyonu yetersiz.';
  end if;

  v_rental_cost := case
    when v_vehicle.player_id <> v_buyer_id then ceil(v_distance_km * coalesce(v_vehicle.rental_price, 0))
    else 0
  end;
  v_transport_cost := v_rental_cost;
  v_duration_seconds := greatest(1, ceil(((v_distance_km / greatest(v_vehicle.speed_kmh, 1)) / 4.0) * 3600));
  v_finish_at := timezone('utc'::text, now()) + make_interval(secs => v_duration_seconds);

  if coalesce(v_buyer_player.cash, 0) < (v_total_price + v_rental_cost) then
    raise exception 'Yeterli nakit yok.';
  end if;

  v_reserve_result := public.reserve_warehouse_capacity(
    v_buyer_id,
    p_buyer_warehouse_id,
    v_seller_slot.product_id,
    p_quantity
  );

  update public.warehouse_slots
  set
    quantity = quantity - p_quantity,
    is_available_for_sale = case when quantity - p_quantity > 0 then is_available_for_sale else false end,
    updated_at = timezone('utc'::text, now())
  where id = p_seller_slot_id;

  update public.players
  set cash = cash - (v_total_price + v_rental_cost)
  where id = v_buyer_id;

  update public.players
  set cash = cash + v_total_price
  where id = v_seller_slot.seller_player_id;

  if v_rental_cost > 0 then
    update public.players
    set cash = cash + v_rental_cost
    where id = v_vehicle.player_id;
  end if;

  update public.logistics_vehicles
  set
    current_fuel = greatest(current_fuel - v_fuel_used::integer, 0),
    condition = greatest(condition - v_condition_loss::integer, 0),
    status = 'on_route',
    updated_at = timezone('utc'::text, now())
  where id = p_vehicle_id;

  insert into public.logistics_transfers (
    buyer_player_id,
    seller_player_id,
    buyer_warehouse_id,
    seller_warehouse_id,
    seller_warehouse_slot_id,
    logistics_vehicle_id,
    vehicle_owner_player_id,
    is_rental,
    product_id,
    quality_level,
    quantity,
    unit_price,
    total_price,
    product_unit_volume,
    reserved_capacity_amount,
    distance_km,
    fuel_used,
    condition_loss,
    rental_cost,
    transport_cost,
    started_at,
    finish_at,
    status,
    updated_at
  )
  values (
    v_buyer_id,
    v_seller_slot.seller_player_id,
    p_buyer_warehouse_id,
    v_seller_slot.seller_warehouse_id,
    p_seller_slot_id,
    p_vehicle_id,
    v_vehicle.player_id,
    (v_vehicle.player_id <> v_buyer_id),
    v_seller_slot.product_id,
    v_seller_slot.quality_level,
    p_quantity,
    v_unit_price,
    v_total_price,
    v_product.birim_hacim,
    v_required_capacity,
    v_distance_km,
    v_fuel_used,
    v_condition_loss,
    v_rental_cost,
    v_transport_cost,
    timezone('utc'::text, now()),
    v_finish_at,
    'in_transit',
    timezone('utc'::text, now())
  )
  returning id into v_transfer_id;

  return jsonb_build_object(
    'success', true,
    'transfer_id', v_transfer_id,
    'vehicle_id', p_vehicle_id,
    'seller_slot_id', p_seller_slot_id,
    'product_id', v_seller_slot.product_id,
    'quality_level', v_seller_slot.quality_level,
    'quantity', p_quantity,
    'unit_price', v_unit_price,
    'total_price', v_total_price,
    'rental_cost', v_rental_cost,
    'transport_cost', v_transport_cost,
    'distance_km', round(v_distance_km, 2),
    'fuel_used', v_fuel_used,
    'condition_loss', v_condition_loss,
    'reserved_capacity_amount', v_required_capacity,
    'duration_seconds', v_duration_seconds,
    'finish_at', v_finish_at,
    'reserve_result', v_reserve_result
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.start_production_to_warehouse_transfer(p_production_inventory_id uuid, p_buyer_warehouse_id uuid, p_quantity integer, p_vehicle_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_player record;
  v_inventory record;
  v_owner_city_id uuid;
  v_owner_player_id uuid;
  v_source_city record;
  v_buyer_warehouse record;
  v_vehicle record;
  v_product record;
  v_reserve_result jsonb;
  v_transfer_id uuid;
  v_distance_km numeric := 0;
  v_required_capacity numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_rental_cost numeric := 0;
  v_transport_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz;
  v_now timestamptz := timezone('utc'::text, now());
  v_instant_result jsonb;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select * into v_player
  from public.players
  where id = v_player_id
  for update;

  if not found then
    raise exception 'Oyuncu bulunamadi.';
  end if;

  select *
  into v_inventory
  from public.production_inventory
  where id = p_production_inventory_id
  for update;

  if not found then
    raise exception 'Production inventory bulunamadi.';
  end if;

  if v_inventory.inventory_type <> 'output' then
    raise exception 'Sadece output inventory icin output lojistigi desteklenir.';
  end if;

  if v_inventory.owner_kind not in ('factory', 'field', 'farm', 'mine') then
    raise exception 'Bu owner_kind icin output lojistigi desteklenmiyor: %', v_inventory.owner_kind;
  end if;

  if coalesce(v_inventory.quantity, 0) < p_quantity then
    raise exception 'Istenen miktar mevcut output stoktan fazla.';
  end if;

  if v_inventory.owner_kind = 'factory' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.factories
    where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'field' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.fields
    where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'farm' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.farms
    where id = v_inventory.owner_id;
  else
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.mines
    where id = v_inventory.owner_id;
  end if;

  if v_owner_player_id is null then
    raise exception 'Kaynak uretim birimi bulunamadi.';
  end if;

  if v_owner_player_id <> v_player_id then
    raise exception 'Kaynak uretim birimi size ait degil.';
  end if;

  select
    w.*,
    c.map_position_x as city_x,
    c.map_position_y as city_y
  into v_buyer_warehouse
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id
    and w.player_id = v_player_id
  for update;

  if not found then
    raise exception 'Hedef depo bulunamadi veya size ait degil.';
  end if;

  if v_buyer_warehouse.is_active is not true then
    raise exception 'Hedef depo aktif degil.';
  end if;

  select *
  into v_product
  from public.products
  where id = v_inventory.product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  if v_buyer_warehouse.city_id = v_owner_city_id then
    v_instant_result := public.transfer_production_inventory_to_warehouse(
      v_player_id,
      p_production_inventory_id,
      p_buyer_warehouse_id,
      p_quantity
    );

    return jsonb_build_object(
      'success', true,
      'message', 'Ayni sehir transferi aninda tamamlandi.',
      'transfer_id', null,
      'mode', 'instant',
      'result', v_instant_result
    );
  end if;

  if p_vehicle_id is null then
    raise exception 'Farkli sehir transferi icin arac secilmelidir.';
  end if;

  select *
  into v_source_city
  from public.cities
  where id = v_owner_city_id;

  if not found then
    raise exception 'Kaynak sehir bulunamadi.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_source_city.map_position_x - v_buyer_warehouse.city_x) / 2)), 2)
      +
      cos(radians(v_buyer_warehouse.city_x)) *
      cos(radians(v_source_city.map_position_x)) *
      power(sin(radians((v_source_city.map_position_y - v_buyer_warehouse.city_y) / 2)), 2)
    )
  );

  select
    lv.*,
    lc.is_active as company_is_active
  into v_vehicle
  from public.logistics_vehicles lv
  join public.logistics_companies lc on lc.id = lv.logistics_company_id
  where lv.id = p_vehicle_id
  for update;

  if not found then
    raise exception 'Arac bulunamadi.';
  end if;

  if v_vehicle.status <> 'idle' then
    raise exception 'Arac su anda uygun degil.';
  end if;

  if v_vehicle.company_is_active is not true then
    raise exception 'Aracin firmasi aktif degil.';
  end if;

  if v_vehicle.player_id <> v_player_id and v_vehicle.is_available_for_rent is not true then
    raise exception 'Kiralik arac uygun degil.';
  end if;

  if public.logistics_vehicle_matches_route(v_vehicle.route_city_a_id, v_vehicle.route_city_b_id, v_owner_city_id, v_buyer_warehouse.city_id) is not true then
    raise exception 'Bu arac secilen sehir cifti icin atanmis degil.';
  end if;

  v_fuel_used := ceil(v_distance_km * v_vehicle.fuel_rate);
  v_condition_loss := ceil(v_distance_km * 0.02);

  if v_vehicle.capacity < v_required_capacity then
    raise exception 'Arac kapasitesi yetersiz.';
  end if;

  if v_vehicle.current_fuel < v_fuel_used then
    raise exception 'Aracin yakiti yetersiz.';
  end if;

  if v_vehicle.condition <= v_condition_loss then
    raise exception 'Aracin kondisyonu yetersiz.';
  end if;

  v_rental_cost := case
    when v_vehicle.player_id <> v_player_id then ceil(v_distance_km * coalesce(v_vehicle.rental_price, 0))
    else 0
  end;
  v_transport_cost := v_rental_cost;
  v_duration_seconds := greatest(1, ceil(((v_distance_km / greatest(v_vehicle.speed_kmh, 1)) / 4.0) * 3600));
  v_finish_at := v_now + make_interval(secs => v_duration_seconds);

  if coalesce(v_player.cash, 0) < v_rental_cost then
    raise exception 'Kiralik arac icin yeterli nakit yok.';
  end if;

  v_reserve_result := public.reserve_warehouse_capacity(
    v_player_id,
    p_buyer_warehouse_id,
    v_inventory.product_id,
    p_quantity
  );

  update public.production_inventory
  set quantity = quantity - p_quantity
  where id = p_production_inventory_id;

  if v_rental_cost > 0 then
    update public.players
    set cash = cash - v_rental_cost
    where id = v_player_id;

    update public.players
    set cash = cash + v_rental_cost
    where id = v_vehicle.player_id;
  end if;

  update public.logistics_vehicles
  set
    current_fuel = greatest(current_fuel - v_fuel_used::integer, 0),
    condition = greatest(condition - v_condition_loss::integer, 0),
    status = 'on_route',
    updated_at = v_now
  where id = p_vehicle_id;

  insert into public.logistics_transfers (
    buyer_player_id,
    seller_player_id,
    buyer_warehouse_id,
    seller_production_inventory_id,
    logistics_vehicle_id,
    vehicle_owner_player_id,
    is_rental,
    product_id,
    quality_level,
    quantity,
    unit_price,
    total_price,
    product_unit_volume,
    reserved_capacity_amount,
    distance_km,
    fuel_used,
    condition_loss,
    rental_cost,
    transport_cost,
    transfer_type,
    seller_entity_kind,
    buyer_entity_kind,
    started_at,
    finish_at,
    status,
    updated_at
  )
  values (
    v_player_id,
    v_player_id,
    p_buyer_warehouse_id,
    p_production_inventory_id,
    p_vehicle_id,
    v_vehicle.player_id,
    (v_vehicle.player_id <> v_player_id),
    v_inventory.product_id,
    v_inventory.quality_level,
    p_quantity,
    coalesce(v_inventory.cost, 0),
    0,
    v_product.birim_hacim,
    coalesce((v_reserve_result ->> 'reserved_added')::numeric, 0),
    v_distance_km,
    v_fuel_used,
    v_condition_loss,
    v_rental_cost,
    v_transport_cost,
    'production_to_warehouse',
    'production_inventory',
    'warehouse',
    v_now,
    v_finish_at,
    'in_transit',
    v_now
  )
  returning id into v_transfer_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Output lojistigi transferi baslatildi.',
    'transfer_id', v_transfer_id,
    'mode', 'transfer'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.start_store_to_warehouse_transfer(p_store_slot_id uuid, p_buyer_warehouse_id uuid, p_quantity integer, p_vehicle_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_player record;
  v_store_slot record;
  v_buyer_warehouse record;
  v_product record;
  v_vehicle record;
  v_reserve_result jsonb;
  v_transfer_id uuid;
  v_distance_km numeric := 0;
  v_required_capacity numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_rental_cost numeric := 0;
  v_transport_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz;
  v_unit_cost numeric := 0;
  v_add_result jsonb;
  v_now timestamptz := timezone('utc'::text, now());
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select * into v_player
  from public.players
  where id = v_player_id
  for update;

  if not found then
    raise exception 'Oyuncu bulunamadi.';
  end if;

  select ss.*, s.player_id, s.id as seller_store_id, s.is_active as store_is_active,
         s.city_id as store_city_id,
         c.map_position_x as city_x, c.map_position_y as city_y
  into v_store_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  join public.cities c on c.id = s.city_id
  where ss.id = p_store_slot_id
  for update;

  if not found or v_store_slot.player_id <> v_player_id then
    raise exception 'Magaza slotu bulunamadi veya size ait degil.';
  end if;

  if v_store_slot.store_is_active is not true then
    raise exception 'Magaza aktif degil.';
  end if;

  if coalesce(v_store_slot.product_id, '') = '' or coalesce(v_store_slot.quality_level, 0) = 0 then
    raise exception 'Magaza slotunda gecerli urun veya kalite yok.';
  end if;

  if p_quantity > coalesce(v_store_slot.quantity, 0) then
    raise exception 'Istenen miktar mevcut stoktan fazla.';
  end if;

  select w.*, c.map_position_x as city_x, c.map_position_y as city_y
  into v_buyer_warehouse
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id
    and w.player_id = v_player_id
  for update;

  if not found then
    raise exception 'Hedef depo bulunamadi veya size ait degil.';
  end if;

  if v_buyer_warehouse.is_active is not true then
    raise exception 'Hedef depo aktif degil.';
  end if;

  select * into v_product
  from public.products
  where id = v_store_slot.product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_unit_cost := coalesce(v_store_slot.cost, 0);

  if v_store_slot.store_city_id = v_buyer_warehouse.city_id then
    update public.store_slots
    set quantity = quantity - p_quantity,
        updated_at = v_now
    where id = p_store_slot_id;

    v_add_result := public.add_product_to_warehouse(
      v_player_id,
      p_buyer_warehouse_id,
      v_store_slot.product_id,
      v_store_slot.quality_level,
      p_quantity,
      v_unit_cost,
      0,
      false
    );

    insert into public.logistics_transfers (
      buyer_player_id,
      seller_player_id,
      buyer_warehouse_id,
      seller_store_id,
      seller_store_slot_id,
      logistics_vehicle_id,
      vehicle_owner_player_id,
      is_rental,
      product_id,
      quality_level,
      quantity,
      unit_price,
      total_price,
      product_unit_volume,
      reserved_capacity_amount,
      distance_km,
      fuel_used,
      condition_loss,
      rental_cost,
      transport_cost,
      transfer_type,
      started_at,
      finish_at,
      completed_at,
      status,
      updated_at
    )
    values (
      v_player_id,
      v_player_id,
      p_buyer_warehouse_id,
      v_store_slot.seller_store_id,
      p_store_slot_id,
      null,
      null,
      false,
      v_store_slot.product_id,
      v_store_slot.quality_level,
      p_quantity,
      v_unit_cost,
      p_quantity * v_unit_cost,
      v_product.birim_hacim,
      0,
      0,
      0,
      0,
      0,
      0,
      'store_to_warehouse',
      v_now,
      v_now,
      v_now,
      'completed',
      v_now
    )
    returning id into v_transfer_id;

    return jsonb_build_object(
      'success', true,
      'mode', 'instant',
      'transfer_id', v_transfer_id,
      'warehouse_result', v_add_result,
      'warehouse_id', p_buyer_warehouse_id,
      'store_slot_id', p_store_slot_id,
      'product_id', v_store_slot.product_id,
      'quality_level', v_store_slot.quality_level,
      'quantity', p_quantity
    );
  end if;

  if p_vehicle_id is null then
    raise exception 'Farkli sehir transferi icin arac secilmelidir.';
  end if;

  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_store_slot.city_x - v_buyer_warehouse.city_x) / 2)), 2) +
      cos(radians(v_buyer_warehouse.city_x)) *
      cos(radians(v_store_slot.city_x)) *
      power(sin(radians((v_store_slot.city_y - v_buyer_warehouse.city_y) / 2)), 2)
    )
  );

  select lv.*, lc.is_active as company_is_active
  into v_vehicle
  from public.logistics_vehicles lv
  join public.logistics_companies lc on lc.id = lv.logistics_company_id
  where lv.id = p_vehicle_id
  for update;

  if not found then
    raise exception 'Arac bulunamadi.';
  end if;

  if v_vehicle.status <> 'idle' then
    raise exception 'Arac su anda uygun degil.';
  end if;

  if v_vehicle.company_is_active is not true then
    raise exception 'Aracin firmasi aktif degil.';
  end if;

  if v_vehicle.player_id <> v_player_id and v_vehicle.is_available_for_rent is not true then
    raise exception 'Kiralik arac uygun degil.';
  end if;

  if public.logistics_vehicle_matches_route(v_vehicle.route_city_a_id, v_vehicle.route_city_b_id, v_store_slot.store_city_id, v_buyer_warehouse.city_id) is not true then
    raise exception 'Bu arac secilen sehir cifti icin atanmis degil.';
  end if;

  v_fuel_used := ceil(v_distance_km * v_vehicle.fuel_rate);
  v_condition_loss := ceil(v_distance_km * 0.02);

  if v_vehicle.capacity < v_required_capacity then
    raise exception 'Arac kapasitesi yetersiz.';
  end if;

  if v_vehicle.current_fuel < v_fuel_used then
    raise exception 'Aracin yakiti yetersiz.';
  end if;

  if v_vehicle.condition <= v_condition_loss then
    raise exception 'Aracin kondisyonu yetersiz.';
  end if;

  v_rental_cost := case
    when v_vehicle.player_id <> v_player_id then ceil(v_distance_km * coalesce(v_vehicle.rental_price, 0))
    else 0
  end;
  v_transport_cost := v_rental_cost;
  v_duration_seconds := greatest(1, ceil(((v_distance_km / greatest(v_vehicle.speed_kmh, 1)) / 4.0) * 3600));
  v_finish_at := timezone('utc'::text, now()) + make_interval(secs => v_duration_seconds);

  if coalesce(v_player.cash, 0) < v_rental_cost then
    raise exception 'Kiralik arac icin yeterli nakit yok.';
  end if;

  v_reserve_result := public.reserve_warehouse_capacity(
    v_player_id,
    p_buyer_warehouse_id,
    v_store_slot.product_id,
    p_quantity
  );

  update public.store_slots
  set quantity = quantity - p_quantity,
      updated_at = timezone('utc'::text, now())
  where id = p_store_slot_id;

  if v_rental_cost > 0 then
    update public.players
    set cash = cash - v_rental_cost
    where id = v_player_id;

    update public.players
    set cash = cash + v_rental_cost
    where id = v_vehicle.player_id;
  end if;

  update public.logistics_vehicles
  set
    current_fuel = greatest(current_fuel - v_fuel_used::integer, 0),
    condition = greatest(condition - v_condition_loss::integer, 0),
    status = 'on_route',
    updated_at = timezone('utc'::text, now())
  where id = p_vehicle_id;

  insert into public.logistics_transfers (
    buyer_player_id,
    seller_player_id,
    buyer_warehouse_id,
    seller_store_id,
    seller_store_slot_id,
    logistics_vehicle_id,
    vehicle_owner_player_id,
    is_rental,
    product_id,
    quality_level,
    quantity,
    unit_price,
    total_price,
    product_unit_volume,
    reserved_capacity_amount,
    distance_km,
    fuel_used,
    condition_loss,
    rental_cost,
    transport_cost,
    transfer_type,
    started_at,
    finish_at,
    status,
    updated_at
  )
  values (
    v_player_id,
    v_player_id,
    p_buyer_warehouse_id,
    v_store_slot.seller_store_id,
    p_store_slot_id,
    p_vehicle_id,
    v_vehicle.player_id,
    (v_vehicle.player_id <> v_player_id),
    v_store_slot.product_id,
    v_store_slot.quality_level,
    p_quantity,
    v_unit_cost,
    0,
    v_product.birim_hacim,
    p_quantity,
    v_distance_km,
    v_fuel_used,
    v_condition_loss,
    v_rental_cost,
    v_transport_cost,
    'store_to_warehouse',
    timezone('utc'::text, now()),
    v_finish_at,
    'in_transit',
    timezone('utc'::text, now())
  )
  returning id into v_transfer_id;

  return jsonb_build_object(
    'success', true,
    'mode', 'transfer',
    'transfer_id', v_transfer_id,
    'vehicle_id', p_vehicle_id,
    'warehouse_id', p_buyer_warehouse_id,
    'store_slot_id', p_store_slot_id,
    'product_id', v_store_slot.product_id,
    'quality_level', v_store_slot.quality_level,
    'quantity', p_quantity,
    'rental_cost', v_rental_cost,
    'transport_cost', v_transport_cost,
    'distance_km', round(v_distance_km, 2),
    'fuel_used', v_fuel_used,
    'condition_loss', v_condition_loss,
    'duration_seconds', v_duration_seconds,
    'finish_at', v_finish_at,
    'reserve_result', v_reserve_result
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.start_warehouse_to_production_transfer(p_warehouse_slot_id uuid, p_production_inventory_id uuid, p_quantity integer, p_vehicle_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_player record;
  v_warehouse_slot record;
  v_inventory record;
  v_owner_city_id uuid;
  v_owner_player_id uuid;
  v_target_city record;
  v_vehicle record;
  v_product record;
  v_transfer_id uuid;
  v_distance_km numeric := 0;
  v_required_capacity numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_rental_cost numeric := 0;
  v_transport_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz;
  v_now timestamptz := timezone('utc'::text, now());
  v_instant_result jsonb;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select * into v_player
  from public.players
  where id = v_player_id
  for update;

  if not found then
    raise exception 'Oyuncu bulunamadi.';
  end if;

  select
    ws.*,
    w.player_id,
    w.id as warehouse_id,
    w.city_id,
    w.is_active as warehouse_is_active,
    c.map_position_x as city_x,
    c.map_position_y as city_y
  into v_warehouse_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  join public.cities c on c.id = w.city_id
  where ws.id = p_warehouse_slot_id
  for update;

  if not found or v_warehouse_slot.player_id <> v_player_id then
    raise exception 'Depo slotu bulunamadi veya size ait degil.';
  end if;

  if v_warehouse_slot.warehouse_is_active is not true then
    raise exception 'Kaynak depo aktif degil.';
  end if;

  if p_quantity > coalesce(v_warehouse_slot.quantity, 0) then
    raise exception 'Istenen miktar mevcut stoktan fazla.';
  end if;

  select *
  into v_inventory
  from public.production_inventory
  where id = p_production_inventory_id
  for update;

  if not found then
    raise exception 'Production inventory bulunamadi.';
  end if;

  if v_inventory.inventory_type <> 'input' then
    raise exception 'Sadece input inventory icin hammadde lojistigi desteklenir.';
  end if;

  if v_inventory.owner_kind not in ('factory', 'field', 'farm') then
    raise exception 'Bu owner_kind icin input lojistigi desteklenmiyor: %', v_inventory.owner_kind;
  end if;

  if v_inventory.owner_kind = 'factory' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.factories
    where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'field' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.fields
    where id = v_inventory.owner_id;
  else
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.farms
    where id = v_inventory.owner_id;
  end if;

  if v_owner_player_id is null then
    raise exception 'Hedef uretim birimi bulunamadi.';
  end if;

  if v_owner_player_id <> v_player_id then
    raise exception 'Hedef uretim birimi size ait degil.';
  end if;

  if v_inventory.product_id <> v_warehouse_slot.product_id then
    raise exception 'Depo slotundaki urun ile input inventory urunu ayni olmalidir.';
  end if;

  if v_inventory.quality_level <> v_warehouse_slot.quality_level then
    raise exception 'Depo slotundaki kalite ile input inventory kalitesi ayni olmalidir.';
  end if;

  select *
  into v_product
  from public.products
  where id = v_warehouse_slot.product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  if v_owner_city_id = v_warehouse_slot.city_id then
    v_instant_result := public.transfer_warehouse_slot_to_production_inventory(
      v_player_id,
      p_warehouse_slot_id,
      p_production_inventory_id,
      p_quantity
    );

    return jsonb_build_object(
      'success', true,
      'message', 'Ayni sehir transferi aninda tamamlandi.',
      'transfer_id', null,
      'mode', 'instant',
      'result', v_instant_result
    );
  end if;

  if p_vehicle_id is null then
    raise exception 'Farkli sehir transferi icin arac secilmelidir.';
  end if;

  select *
  into v_target_city
  from public.cities
  where id = v_owner_city_id;

  if not found then
    raise exception 'Hedef sehir bulunamadi.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_warehouse_slot.city_x - v_target_city.map_position_x) / 2)), 2)
      +
      cos(radians(v_target_city.map_position_x)) *
      cos(radians(v_warehouse_slot.city_x)) *
      power(sin(radians((v_warehouse_slot.city_y - v_target_city.map_position_y) / 2)), 2)
    )
  );

  select
    lv.*,
    lc.is_active as company_is_active
  into v_vehicle
  from public.logistics_vehicles lv
  join public.logistics_companies lc on lc.id = lv.logistics_company_id
  where lv.id = p_vehicle_id
  for update;

  if not found then
    raise exception 'Arac bulunamadi.';
  end if;

  if v_vehicle.status <> 'idle' then
    raise exception 'Arac su anda uygun degil.';
  end if;

  if v_vehicle.company_is_active is not true then
    raise exception 'Aracin firmasi aktif degil.';
  end if;

  if v_vehicle.player_id <> v_player_id and v_vehicle.is_available_for_rent is not true then
    raise exception 'Kiralik arac uygun degil.';
  end if;

  if public.logistics_vehicle_matches_route(v_vehicle.route_city_a_id, v_vehicle.route_city_b_id, v_warehouse_slot.city_id, v_owner_city_id) is not true then
    raise exception 'Bu arac secilen sehir cifti icin atanmis degil.';
  end if;

  v_fuel_used := ceil(v_distance_km * v_vehicle.fuel_rate);
  v_condition_loss := ceil(v_distance_km * 0.02);

  if v_vehicle.capacity < v_required_capacity then
    raise exception 'Arac kapasitesi yetersiz.';
  end if;

  if v_vehicle.current_fuel < v_fuel_used then
    raise exception 'Aracin yakiti yetersiz.';
  end if;

  if v_vehicle.condition <= v_condition_loss then
    raise exception 'Aracin kondisyonu yetersiz.';
  end if;

  v_rental_cost := case
    when v_vehicle.player_id <> v_player_id then ceil(v_distance_km * coalesce(v_vehicle.rental_price, 0))
    else 0
  end;
  v_transport_cost := v_rental_cost;
  v_duration_seconds := greatest(1, ceil(((v_distance_km / greatest(v_vehicle.speed_kmh, 1)) / 4.0) * 3600));
  v_finish_at := v_now + make_interval(secs => v_duration_seconds);

  if coalesce(v_player.cash, 0) < v_rental_cost then
    raise exception 'Kiralik arac icin yeterli nakit yok.';
  end if;

  update public.warehouse_slots
  set
    quantity = quantity - p_quantity,
    updated_at = v_now
  where id = p_warehouse_slot_id;

  update public.production_inventory
  set
    pending_quantity = coalesce(pending_quantity, 0) + p_quantity
  where id = p_production_inventory_id;

  if v_rental_cost > 0 then
    update public.players
    set cash = cash - v_rental_cost
    where id = v_player_id;

    update public.players
    set cash = cash + v_rental_cost
    where id = v_vehicle.player_id;
  end if;

  update public.logistics_vehicles
  set
    current_fuel = greatest(current_fuel - v_fuel_used::integer, 0),
    condition = greatest(condition - v_condition_loss::integer, 0),
    status = 'on_route',
    updated_at = v_now
  where id = p_vehicle_id;

  insert into public.logistics_transfers (
    buyer_player_id,
    seller_player_id,
    buyer_production_inventory_id,
    seller_warehouse_id,
    seller_warehouse_slot_id,
    logistics_vehicle_id,
    vehicle_owner_player_id,
    is_rental,
    product_id,
    quality_level,
    quantity,
    unit_price,
    total_price,
    product_unit_volume,
    reserved_capacity_amount,
    distance_km,
    fuel_used,
    condition_loss,
    rental_cost,
    transport_cost,
    transfer_type,
    seller_entity_kind,
    buyer_entity_kind,
    started_at,
    finish_at,
    status,
    updated_at
  )
  values (
    v_player_id,
    v_player_id,
    p_production_inventory_id,
    v_warehouse_slot.warehouse_id,
    p_warehouse_slot_id,
    p_vehicle_id,
    v_vehicle.player_id,
    (v_vehicle.player_id <> v_player_id),
    v_warehouse_slot.product_id,
    v_warehouse_slot.quality_level,
    p_quantity,
    coalesce(v_warehouse_slot.cost, 0),
    0,
    v_product.birim_hacim,
    0,
    v_distance_km,
    v_fuel_used,
    v_condition_loss,
    v_rental_cost,
    v_transport_cost,
    'warehouse_to_production',
    'warehouse',
    'production_inventory',
    v_now,
    v_finish_at,
    'in_transit',
    v_now
  )
  returning id into v_transfer_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Uretim lojistigi transferi baslatildi.',
    'transfer_id', v_transfer_id,
    'mode', 'transfer'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.start_warehouse_to_store_transfer(p_store_slot_id uuid, p_warehouse_slot_id uuid, p_quantity integer, p_vehicle_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_player record;
  v_store_slot record;
  v_warehouse_slot record;
  v_product record;
  v_vehicle record;
  v_transfer_id uuid;
  v_distance_km numeric := 0;
  v_required_capacity numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_rental_cost numeric := 0;
  v_transport_cost numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz;
  v_unit_cost numeric := 0;
  v_new_cost numeric := 0;
  v_now timestamptz := timezone('utc'::text, now());
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select * into v_player
  from public.players
  where id = v_player_id
  for update;

  if not found then
    raise exception 'Oyuncu bulunamadi.';
  end if;

  select ss.*, s.player_id, s.id as buyer_store_id, s.is_active as store_is_active,
         s.city_id as store_city_id, c.map_position_x as city_x, c.map_position_y as city_y
  into v_store_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  join public.cities c on c.id = s.city_id
  where ss.id = p_store_slot_id
  for update;

  if not found or v_store_slot.player_id <> v_player_id then
    raise exception 'Magaza slotu bulunamadi veya size ait degil.';
  end if;

  if v_store_slot.store_is_active is not true then
    raise exception 'Magaza aktif degil.';
  end if;

  select ws.*, w.player_id as warehouse_player_id, w.id as seller_warehouse_id,
         w.city_id as warehouse_city_id,
         c.map_position_x as city_x, c.map_position_y as city_y
  into v_warehouse_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  join public.cities c on c.id = w.city_id
  where ws.id = p_warehouse_slot_id
  for update;

  if not found or v_warehouse_slot.warehouse_player_id <> v_player_id then
    raise exception 'Depo slotu bulunamadi veya size ait degil.';
  end if;

  if p_quantity > v_warehouse_slot.quantity then
    raise exception 'Istenen miktar mevcut stoktan fazla.';
  end if;

  if v_store_slot.product_id is null or v_store_slot.quality_level = 0 then
    if coalesce(v_store_slot.quantity, 0) > 0 or coalesce(v_store_slot.pending_quantity, 0) > 0 then
      raise exception 'Slotta aktif stok veya rezerve varken urun atanamaz.';
    end if;

    update public.store_slots
    set
      product_id = v_warehouse_slot.product_id,
      quality_level = v_warehouse_slot.quality_level,
      updated_at = v_now
    where id = p_store_slot_id;

    v_store_slot.product_id := v_warehouse_slot.product_id;
    v_store_slot.quality_level := v_warehouse_slot.quality_level;
  elsif v_store_slot.product_id <> v_warehouse_slot.product_id
     or v_store_slot.quality_level <> v_warehouse_slot.quality_level then
    raise exception 'Magaza slotu urun veya kalite uyusmazligi.';
  end if;

  if (coalesce(v_store_slot.quantity, 0) + coalesce(v_store_slot.pending_quantity, 0) + p_quantity) > v_store_slot.capacity then
    raise exception 'Magaza slot kapasitesi yetersiz.';
  end if;

  select * into v_product
  from public.products
  where id = v_warehouse_slot.product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_unit_cost := coalesce(v_warehouse_slot.cost, 0);

  if v_store_slot.store_city_id = v_warehouse_slot.warehouse_city_id then
    v_new_cost := case
      when coalesce(v_store_slot.quantity, 0) + p_quantity > 0 then
        (
          coalesce(v_store_slot.quantity, 0) * coalesce(v_store_slot.cost, 0)
          + p_quantity * v_unit_cost
        ) / (coalesce(v_store_slot.quantity, 0) + p_quantity)
      else coalesce(v_store_slot.cost, 0)
    end;

    update public.warehouse_slots
    set quantity = quantity - p_quantity,
        updated_at = v_now
    where id = p_warehouse_slot_id;

    update public.store_slots
    set
      quantity = quantity + p_quantity,
      cost = v_new_cost,
      updated_at = v_now
    where id = p_store_slot_id;

    insert into public.logistics_transfers (
      buyer_player_id,
      seller_player_id,
      buyer_store_id,
      buyer_store_slot_id,
      seller_warehouse_id,
      seller_warehouse_slot_id,
      logistics_vehicle_id,
      vehicle_owner_player_id,
      is_rental,
      product_id,
      quality_level,
      quantity,
      unit_price,
      total_price,
      product_unit_volume,
      reserved_capacity_amount,
      distance_km,
      fuel_used,
      condition_loss,
      rental_cost,
      transport_cost,
      transfer_type,
      started_at,
      finish_at,
      completed_at,
      status,
      updated_at
    )
    values (
      v_player_id,
      v_player_id,
      v_store_slot.buyer_store_id,
      p_store_slot_id,
      v_warehouse_slot.seller_warehouse_id,
      p_warehouse_slot_id,
      null,
      null,
      false,
      v_warehouse_slot.product_id,
      v_warehouse_slot.quality_level,
      p_quantity,
      v_unit_cost,
      p_quantity * v_unit_cost,
      v_product.birim_hacim,
      0,
      0,
      0,
      0,
      0,
      0,
      'warehouse_to_store',
      v_now,
      v_now,
      v_now,
      'completed',
      v_now
    )
    returning id into v_transfer_id;

    return jsonb_build_object(
      'success', true,
      'mode', 'instant',
      'transfer_id', v_transfer_id,
      'store_slot_id', p_store_slot_id,
      'warehouse_slot_id', p_warehouse_slot_id,
      'product_id', v_warehouse_slot.product_id,
      'quality_level', v_warehouse_slot.quality_level,
      'quantity', p_quantity,
      'transport_cost', 0,
      'rental_cost', 0,
      'new_cost', v_new_cost
    );
  end if;

  if p_vehicle_id is null then
    raise exception 'Farkli sehir transferi icin arac secilmelidir.';
  end if;

  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_warehouse_slot.city_x - v_store_slot.city_x) / 2)), 2) +
      cos(radians(v_store_slot.city_x)) *
      cos(radians(v_warehouse_slot.city_x)) *
      power(sin(radians((v_warehouse_slot.city_y - v_store_slot.city_y) / 2)), 2)
    )
  );

  select lv.*, lc.is_active as company_is_active
  into v_vehicle
  from public.logistics_vehicles lv
  join public.logistics_companies lc on lc.id = lv.logistics_company_id
  where lv.id = p_vehicle_id
  for update;

  if not found then
    raise exception 'Arac bulunamadi.';
  end if;

  if v_vehicle.status <> 'idle' then
    raise exception 'Arac su anda uygun degil.';
  end if;

  if v_vehicle.company_is_active is not true then
    raise exception 'Aracin firmasi aktif degil.';
  end if;

  if v_vehicle.player_id <> v_player_id and v_vehicle.is_available_for_rent is not true then
    raise exception 'Kiralik arac uygun degil.';
  end if;

  if public.logistics_vehicle_matches_route(v_vehicle.route_city_a_id, v_vehicle.route_city_b_id, v_warehouse_slot.warehouse_city_id, v_store_slot.store_city_id) is not true then
    raise exception 'Bu arac secilen sehir cifti icin atanmis degil.';
  end if;

  v_fuel_used := ceil(v_distance_km * v_vehicle.fuel_rate);
  v_condition_loss := ceil(v_distance_km * 0.02);

  if v_vehicle.capacity < v_required_capacity then
    raise exception 'Arac kapasitesi yetersiz.';
  end if;

  if v_vehicle.current_fuel < v_fuel_used then
    raise exception 'Aracin yakiti yetersiz.';
  end if;

  if v_vehicle.condition <= v_condition_loss then
    raise exception 'Aracin kondisyonu yetersiz.';
  end if;

  v_rental_cost := case
    when v_vehicle.player_id <> v_player_id then ceil(v_distance_km * coalesce(v_vehicle.rental_price, 0))
    else 0
  end;
  v_transport_cost := v_rental_cost;
  v_duration_seconds := greatest(1, ceil(((v_distance_km / greatest(v_vehicle.speed_kmh, 1)) / 4.0) * 3600));
  v_finish_at := timezone('utc'::text, now()) + make_interval(secs => v_duration_seconds);

  if coalesce(v_player.cash, 0) < v_rental_cost then
    raise exception 'Kiralik arac icin yeterli nakit yok.';
  end if;

  update public.warehouse_slots
  set quantity = quantity - p_quantity,
      updated_at = timezone('utc'::text, now())
  where id = p_warehouse_slot_id;

  if v_rental_cost > 0 then
    update public.players
    set cash = cash - v_rental_cost
    where id = v_player_id;

    update public.players
    set cash = cash + v_rental_cost
    where id = v_vehicle.player_id;
  end if;

  update public.logistics_vehicles
  set
    current_fuel = greatest(current_fuel - v_fuel_used::integer, 0),
    condition = greatest(condition - v_condition_loss::integer, 0),
    status = 'on_route',
    updated_at = timezone('utc'::text, now())
  where id = p_vehicle_id;

  update public.store_slots
  set
    pending_quantity = coalesce(pending_quantity, 0) + p_quantity,
    updated_at = timezone('utc'::text, now())
  where id = p_store_slot_id;

  insert into public.logistics_transfers (
    buyer_player_id,
    seller_player_id,
    buyer_warehouse_id,
    buyer_store_id,
    buyer_store_slot_id,
    seller_warehouse_id,
    seller_warehouse_slot_id,
    logistics_vehicle_id,
    vehicle_owner_player_id,
    is_rental,
    product_id,
    quality_level,
    quantity,
    unit_price,
    total_price,
    product_unit_volume,
    reserved_capacity_amount,
    distance_km,
    fuel_used,
    condition_loss,
    rental_cost,
    transport_cost,
    transfer_type,
    started_at,
    finish_at,
    status,
    updated_at
  )
  values (
    v_player_id,
    v_player_id,
    null,
    v_store_slot.buyer_store_id,
    p_store_slot_id,
    v_warehouse_slot.seller_warehouse_id,
    p_warehouse_slot_id,
    p_vehicle_id,
    v_vehicle.player_id,
    (v_vehicle.player_id <> v_player_id),
    v_warehouse_slot.product_id,
    v_warehouse_slot.quality_level,
    p_quantity,
    v_unit_cost,
    0,
    v_product.birim_hacim,
    p_quantity,
    v_distance_km,
    v_fuel_used,
    v_condition_loss,
    v_rental_cost,
    v_transport_cost,
    'warehouse_to_store',
    timezone('utc'::text, now()),
    v_finish_at,
    'in_transit',
    timezone('utc'::text, now())
  )
  returning id into v_transfer_id;

  return jsonb_build_object(
    'success', true,
    'mode', 'transfer',
    'transfer_id', v_transfer_id,
    'vehicle_id', p_vehicle_id,
    'store_slot_id', p_store_slot_id,
    'warehouse_slot_id', p_warehouse_slot_id,
    'product_id', v_warehouse_slot.product_id,
    'quality_level', v_warehouse_slot.quality_level,
    'quantity', p_quantity,
    'rental_cost', v_rental_cost,
    'transport_cost', v_transport_cost,
    'distance_km', round(v_distance_km, 2),
    'fuel_used', v_fuel_used,
    'condition_loss', v_condition_loss,
    'duration_seconds', v_duration_seconds,
    'finish_at', v_finish_at
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.to_turkey_time(p_value timestamp with time zone)
 RETURNS timestamp without time zone
 LANGUAGE sql
 STABLE
AS $function$
  select timezone('Europe/Istanbul', p_value);
$function$
;

CREATE OR REPLACE FUNCTION public.transfer_production_inventory_to_warehouse(p_player_id uuid, p_production_inventory_id uuid, p_warehouse_id uuid, p_quantity integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_inventory production_inventory%rowtype;
  v_warehouse warehouses%rowtype;
  v_product products%rowtype;

  v_owner_city_id uuid;
  v_owner_player_id uuid;

  v_unit_volume numeric;
  v_required_capacity numeric;
  v_used_capacity numeric;
  v_available_capacity numeric;

  v_existing_slot warehouse_slots%rowtype;
  v_warehouse_slot_id uuid;

  v_new_slot_index integer;
  v_quantity_after integer;
  v_cost_after numeric;

  v_inventory_quantity_after integer;
begin
  /*
    1. Temel miktar kontrolü
  */
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Aktarılacak miktar 0’dan büyük olmalıdır.';
  end if;

  /*
    2. Production inventory kaydını kilitle
  */
  select *
  into v_inventory
  from production_inventory
  where id = p_production_inventory_id
  for update;

  if not found then
    raise exception 'Production inventory kaydı bulunamadı.';
  end if;

  if v_inventory.owner_kind not in ('factory', 'field', 'farm', 'mine') then
    raise exception 'Geçersiz production inventory owner_kind: %', v_inventory.owner_kind;
  end if;

  if v_inventory.inventory_type not in ('input', 'output') then
    raise exception 'Geçersiz inventory_type: %', v_inventory.inventory_type;
  end if;

  if v_inventory.quantity < p_quantity then
    raise exception 'Production inventory içinde yeterli ürün yok. Mevcut: %, İstenen: %',
      v_inventory.quantity,
      p_quantity;
  end if;

  /*
    3. Üretim birimi sahiplik ve şehir kontrolü
  */
  if v_inventory.owner_kind = 'factory' then
    select player_id, city_id
    into v_owner_player_id, v_owner_city_id
    from factories
    where id = v_inventory.owner_id;

  elsif v_inventory.owner_kind = 'field' then
    select player_id, city_id
    into v_owner_player_id, v_owner_city_id
    from fields
    where id = v_inventory.owner_id;

  elsif v_inventory.owner_kind = 'farm' then
    select player_id, city_id
    into v_owner_player_id, v_owner_city_id
    from farms
    where id = v_inventory.owner_id;

  elsif v_inventory.owner_kind = 'mine' then
    select player_id, city_id
    into v_owner_player_id, v_owner_city_id
    from mines
    where id = v_inventory.owner_id;
  end if;

  if v_owner_player_id is null then
    raise exception 'Production inventory sahibi olan üretim birimi bulunamadı.';
  end if;

  if v_owner_player_id <> p_player_id then
    raise exception 'Bu production inventory kaydı oyuncuya ait değil.';
  end if;

  /*
    4. Depoyu kilitle ve sahiplik kontrolü yap
  */
  select *
  into v_warehouse
  from warehouses
  where id = p_warehouse_id
  for update;

  if not found then
    raise exception 'Depo bulunamadı.';
  end if;

  if v_warehouse.player_id <> p_player_id then
    raise exception 'Hedef depo oyuncuya ait değil.';
  end if;

  if v_warehouse.city_id <> v_owner_city_id then
    raise exception 'Üretim birimi ve hedef depo aynı şehirde olmalıdır.';
  end if;

  /*
    5. Ürün ve hacim kontrolü
  */
  select *
  into v_product
  from products
  where id = v_inventory.product_id;

  if not found then
    raise exception 'Ürün bulunamadı: %', v_inventory.product_id;
  end if;

  v_unit_volume := coalesce(v_product.birim_hacim, 0);

  if v_unit_volume <= 0 then
    raise exception 'Ürünün birim_hacim değeri geçersiz: %', v_inventory.product_id;
  end if;

  v_required_capacity := p_quantity * v_unit_volume;

  /*
    6. Depo kapasitesi hesapla
       used_capacity = warehouse_slots.quantity * products.birim_hacim
       available = capacity - used_capacity - reserved_capacity
  */
  select coalesce(sum(ws.quantity * coalesce(p.birim_hacim, 0)), 0)
  into v_used_capacity
  from warehouse_slots ws
  join products p on p.id = ws.product_id
  where ws.warehouse_id = p_warehouse_id
    and ws.product_id is not null
    and ws.quantity > 0;

  v_available_capacity :=
    v_warehouse.capacity
    - v_used_capacity
    - coalesce(v_warehouse.reserved_capacity, 0);

  if v_available_capacity < v_required_capacity then
    raise exception 'Depoda yeterli boş kapasite yok. Gerekli: %, Uygun: %',
      v_required_capacity,
      v_available_capacity;
  end if;

  /*
    7. Hedef warehouse_slot var mı?
       Aynı warehouse + product + quality varsa ona ekle.
       Yoksa yeni slot oluştur.
  */
  select *
  into v_existing_slot
  from warehouse_slots
  where warehouse_id = p_warehouse_id
    and product_id = v_inventory.product_id
    and quality_level = v_inventory.quality_level
  for update;

  if found then
    v_warehouse_slot_id := v_existing_slot.id;

    v_quantity_after := v_existing_slot.quantity + p_quantity;

    v_cost_after :=
      (
        (v_existing_slot.quantity * v_existing_slot.cost)
        +
        (p_quantity * v_inventory.cost)
      )
      / v_quantity_after;

    update warehouse_slots
    set
      quantity = v_quantity_after,
      cost = v_cost_after,
      updated_at = timezone('utc'::text, now())
    where id = v_existing_slot.id;

  else
    select coalesce(max(slot_index), 0) + 1
    into v_new_slot_index
    from warehouse_slots
    where warehouse_id = p_warehouse_id;

    insert into warehouse_slots (
      warehouse_id,
      slot_index,
      product_id,
      quality_level,
      quantity,
      cost,
      is_available_for_sale,
      created_at,
      updated_at
    )
    values (
      p_warehouse_id,
      v_new_slot_index,
      v_inventory.product_id,
      v_inventory.quality_level,
      p_quantity,
      v_inventory.cost,
      false,
      timezone('utc'::text, now()),
      timezone('utc'::text, now())
    )
    returning id into v_warehouse_slot_id;

    v_quantity_after := p_quantity;
    v_cost_after := v_inventory.cost;
  end if;

  /*
    8. Production inventory'den miktarı düş.
       Satır silinmez.
       pending_quantity korunur.
  */
  v_inventory_quantity_after := v_inventory.quantity - p_quantity;

  update production_inventory
  set quantity = v_inventory_quantity_after
  where id = p_production_inventory_id;

  /*
    9. Warehouse updated_at güncelle
  */
  update warehouses
  set updated_at = timezone('utc'::text, now())
  where id = p_warehouse_id;

  return jsonb_build_object(
    'success', true,
    'production_inventory_id', p_production_inventory_id,
    'warehouse_id', p_warehouse_id,
    'warehouse_slot_id', v_warehouse_slot_id,
    'owner_kind', v_inventory.owner_kind,
    'owner_id', v_inventory.owner_id,
    'inventory_type', v_inventory.inventory_type,
    'city_id', v_owner_city_id,
    'product_id', v_inventory.product_id,
    'quality_level', v_inventory.quality_level,
    'transferred_quantity', p_quantity,
    'unit_volume', v_unit_volume,
    'transferred_capacity', v_required_capacity,
    'warehouse_used_capacity_before', v_used_capacity,
    'warehouse_reserved_capacity', coalesce(v_warehouse.reserved_capacity, 0),
    'warehouse_available_capacity_before', v_available_capacity,
    'inventory_quantity_after', v_inventory_quantity_after,
    'inventory_pending_quantity', v_inventory.pending_quantity,
    'warehouse_slot_quantity_after', v_quantity_after,
    'warehouse_slot_cost_after', v_cost_after
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.transfer_store_slot_to_warehouse(p_player_id uuid, p_store_slot_id uuid, p_warehouse_id uuid, p_quantity integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_store_slot record;
  v_warehouse record;
  v_product record;
  v_existing_warehouse_slot record;

  v_used_capacity numeric := 0;
  v_incoming_capacity numeric := 0;
  v_available_capacity numeric := 0;

  v_new_warehouse_slot_index integer;
  v_warehouse_slot_id uuid;

  v_new_warehouse_quantity integer;
  v_new_warehouse_cost numeric;

  v_new_store_quantity integer;
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Aktarılacak miktar 0''dan büyük olmalıdır.';
  end if;

  -- Mağaza slotunu, mağaza sahipliğini ve şehir bilgisini al
  select
    ss.*,
    s.player_id,
    s.city_id
  into v_store_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  where ss.id = p_store_slot_id
  for update;

  if not found then
    raise exception 'Mağaza slotu bulunamadı.';
  end if;

  if v_store_slot.player_id <> p_player_id then
    raise exception 'Bu mağaza slotu oyuncuya ait değil.';
  end if;

  if v_store_slot.product_id is null
     or v_store_slot.quality_level < 1
     or v_store_slot.quality_level > 5 then
    raise exception 'Mağaza slotunda geçerli ürün ve kalite seçili olmalıdır.';
  end if;

  if v_store_slot.quantity < p_quantity then
    raise exception 'Mağaza slotunda yeterli ürün yok. Mevcut: %, İstenen: %',
      v_store_slot.quantity,
      p_quantity;
  end if;

  -- Depoyu kilitle
  select *
  into v_warehouse
  from public.warehouses
  where id = p_warehouse_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'Depo bulunamadı veya oyuncuya ait değil.';
  end if;

  -- Aynı şehir kontrolü
  if v_store_slot.city_id <> v_warehouse.city_id then
    raise exception 'Mağaza ve depo aynı şehirde olmalıdır.';
  end if;

  -- Ürün hacmini al
  select *
  into v_product
  from public.products
  where id = v_store_slot.product_id;

  if not found then
    raise exception 'Ürün bulunamadı.';
  end if;

  if v_product.birim_hacim is null or v_product.birim_hacim <= 0 then
    raise exception 'Ürünün birim_hacim değeri geçerli değil.';
  end if;

  v_incoming_capacity := p_quantity * v_product.birim_hacim;

  -- Depoda kullanılan kapasite
  select coalesce(sum(ws.quantity * p.birim_hacim), 0)
  into v_used_capacity
  from public.warehouse_slots ws
  join public.products p on p.id = ws.product_id
  where ws.warehouse_id = p_warehouse_id;

  v_available_capacity :=
    coalesce(v_warehouse.capacity, 0)
    - v_used_capacity
    - coalesce(v_warehouse.reserved_capacity, 0);

  if v_incoming_capacity > v_available_capacity then
    raise exception 'Depo kapasitesi yetersiz. Boş kapasite: %, Eklenecek hacim: %',
      v_available_capacity,
      v_incoming_capacity;
  end if;

  -- Depoda aynı ürün + kalite slotu var mı?
  select *
  into v_existing_warehouse_slot
  from public.warehouse_slots
  where warehouse_id = p_warehouse_id
    and product_id = v_store_slot.product_id
    and quality_level = v_store_slot.quality_level
  for update;

  if found then
    v_warehouse_slot_id := v_existing_warehouse_slot.id;
    v_new_warehouse_quantity := v_existing_warehouse_slot.quantity + p_quantity;

    v_new_warehouse_cost :=
      (
        (v_existing_warehouse_slot.quantity * v_existing_warehouse_slot.cost)
        +
        (p_quantity * v_store_slot.cost)
      )
      / v_new_warehouse_quantity;

    update public.warehouse_slots
    set
      quantity = v_new_warehouse_quantity,
      cost = v_new_warehouse_cost,
      updated_at = timezone('utc'::text, now())
    where id = v_existing_warehouse_slot.id;

  else
    select coalesce(max(slot_index), 0) + 1
    into v_new_warehouse_slot_index
    from public.warehouse_slots
    where warehouse_id = p_warehouse_id;

    insert into public.warehouse_slots (
      warehouse_id,
      slot_index,
      product_id,
      quality_level,
      quantity,
      cost,
      is_available_for_sale
    )
    values (
      p_warehouse_id,
      v_new_warehouse_slot_index,
      v_store_slot.product_id,
      v_store_slot.quality_level,
      p_quantity,
      v_store_slot.cost,
      false
    )
    returning id into v_warehouse_slot_id;

    v_new_warehouse_quantity := p_quantity;
    v_new_warehouse_cost := v_store_slot.cost;
  end if;

  v_new_store_quantity := v_store_slot.quantity - p_quantity;

  -- Mağaza slotundan düş
  -- Quantity 0 olsa bile ürün, kalite, fiyat ve cost korunur.
  update public.store_slots
  set
    quantity = v_new_store_quantity,
    updated_at = timezone('utc'::text, now())
  where id = p_store_slot_id;

  update public.warehouses
  set updated_at = timezone('utc'::text, now())
  where id = p_warehouse_id;

  return jsonb_build_object(
    'success', true,
    'store_slot_id', p_store_slot_id,
    'warehouse_id', p_warehouse_id,
    'warehouse_slot_id', v_warehouse_slot_id,
    'city_id', v_warehouse.city_id,
    'product_id', v_store_slot.product_id,
    'quality_level', v_store_slot.quality_level,
    'transferred_quantity', p_quantity,
    'store_quantity_after', v_new_store_quantity,
    'warehouse_quantity_after', v_new_warehouse_quantity,
    'warehouse_cost_after', v_new_warehouse_cost,
    'transferred_capacity', v_incoming_capacity,
    'warehouse_available_capacity_before', v_available_capacity
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.transfer_warehouse_slot_to_production_inventory(p_player_id uuid, p_warehouse_slot_id uuid, p_production_inventory_id uuid, p_quantity integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_warehouse_slot record;
  v_inventory record;

  v_owner_city_id uuid;
  v_owner_player_id uuid;

  v_new_inventory_quantity integer;
  v_new_inventory_cost numeric;
  v_remaining_warehouse_quantity integer;
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Aktarılacak miktar 0''dan büyük olmalıdır.';
  end if;

  -- Depo slotunu ve depo sahipliğini al
  select
    ws.*,
    w.player_id,
    w.city_id
  into v_warehouse_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  where ws.id = p_warehouse_slot_id
  for update;

  if not found then
    raise exception 'Depo slotu bulunamadı.';
  end if;

  if v_warehouse_slot.player_id <> p_player_id then
    raise exception 'Bu depo slotu oyuncuya ait değil.';
  end if;

  if v_warehouse_slot.product_id is null
     or v_warehouse_slot.quality_level < 1
     or v_warehouse_slot.quality_level > 5 then
    raise exception 'Depo slotunda geçerli ürün ve kalite bulunmuyor.';
  end if;

  if v_warehouse_slot.quantity < p_quantity then
    raise exception 'Depo slotunda yeterli ürün yok. Mevcut: %, İstenen: %',
      v_warehouse_slot.quantity,
      p_quantity;
  end if;

  -- Production inventory kaydını al
  select *
  into v_inventory
  from public.production_inventory
  where id = p_production_inventory_id
  for update;

  if not found then
    raise exception 'Production inventory kaydı bulunamadı.';
  end if;

  if v_inventory.inventory_type <> 'input' then
    raise exception 'Sadece input inventory kayıtlarına ürün aktarılabilir.';
  end if;

  if v_inventory.owner_kind not in ('factory', 'field', 'farm') then
    raise exception 'Bu owner_kind için input aktarımı desteklenmiyor: %',
      v_inventory.owner_kind;
  end if;

  -- Owner sahiplik ve şehir kontrolü
  if v_inventory.owner_kind = 'factory' then

    select player_id, city_id
    into v_owner_player_id, v_owner_city_id
    from public.factories
    where id = v_inventory.owner_id;

    if not found then
      raise exception 'Fabrika bulunamadı.';
    end if;

  elsif v_inventory.owner_kind = 'field' then

    select player_id, city_id
    into v_owner_player_id, v_owner_city_id
    from public.fields
    where id = v_inventory.owner_id;

    if not found then
      raise exception 'Tarla bulunamadı.';
    end if;

  elsif v_inventory.owner_kind = 'farm' then

    select player_id, city_id
    into v_owner_player_id, v_owner_city_id
    from public.farms
    where id = v_inventory.owner_id;

    if not found then
      raise exception 'Çiftlik bulunamadı.';
    end if;

  end if;

  if v_owner_player_id <> p_player_id then
    raise exception 'Hedef üretim birimi oyuncuya ait değil.';
  end if;

  if v_owner_city_id <> v_warehouse_slot.city_id then
    raise exception 'Depo ve üretim birimi aynı şehirde olmalıdır.';
  end if;

  -- Ürün ve kalite eşleşmesi
  if v_inventory.product_id <> v_warehouse_slot.product_id then
    raise exception 'Depo slotundaki ürün ile input inventory ürünü aynı olmalıdır.';
  end if;

  if v_inventory.quality_level <> v_warehouse_slot.quality_level then
    raise exception 'Depo slotundaki kalite ile input inventory kalitesi aynı olmalıdır.';
  end if;

  v_new_inventory_quantity := v_inventory.quantity + p_quantity;

  -- Ağırlıklı ortalama maliyet
  v_new_inventory_cost :=
    (
      (v_inventory.quantity * v_inventory.cost)
      +
      (p_quantity * v_warehouse_slot.cost)
    )
    / v_new_inventory_quantity;

  v_remaining_warehouse_quantity := v_warehouse_slot.quantity - p_quantity;

  -- Depodan düş
  -- Quantity 0 olsa bile depo slotu silinmez, ürün bilgisi korunur.
  update public.warehouse_slots
  set
    quantity = v_remaining_warehouse_quantity,
    updated_at = timezone('utc'::text, now())
  where id = p_warehouse_slot_id;

  -- Input inventory'ye ekle
  update public.production_inventory
  set
    quantity = v_new_inventory_quantity,
    cost = v_new_inventory_cost
  where id = p_production_inventory_id;

  return jsonb_build_object(
    'success', true,
    'warehouse_slot_id', p_warehouse_slot_id,
    'production_inventory_id', p_production_inventory_id,
    'owner_kind', v_inventory.owner_kind,
    'owner_id', v_inventory.owner_id,
    'city_id', v_owner_city_id,
    'product_id', v_inventory.product_id,
    'quality_level', v_inventory.quality_level,
    'transferred_quantity', p_quantity,
    'warehouse_quantity_after', v_remaining_warehouse_quantity,
    'inventory_quantity_after', v_new_inventory_quantity,
    'inventory_cost_after', v_new_inventory_cost
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.transfer_warehouse_slot_to_store_slot(p_player_id uuid, p_warehouse_slot_id uuid, p_store_slot_id uuid, p_quantity integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_warehouse_slot record;
  v_store_slot record;

  v_new_store_quantity integer;
  v_new_store_cost numeric;
  v_remaining_warehouse_quantity integer;
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Aktarılacak miktar 0''dan büyük olmalıdır.';
  end if;

  -- Depo slotunu, depo sahipliğini ve şehir bilgisini al
  select
    ws.*,
    w.player_id,
    w.city_id
  into v_warehouse_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  where ws.id = p_warehouse_slot_id
  for update;

  if not found then
    raise exception 'Depo slotu bulunamadı.';
  end if;

  if v_warehouse_slot.player_id <> p_player_id then
    raise exception 'Bu depo slotu oyuncuya ait değil.';
  end if;

  -- Mağaza slotunu, mağaza sahipliğini ve şehir bilgisini al
  select
    ss.*,
    s.player_id,
    s.city_id
  into v_store_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  where ss.id = p_store_slot_id
  for update;

  if not found then
    raise exception 'Mağaza slotu bulunamadı.';
  end if;

  if v_store_slot.player_id <> p_player_id then
    raise exception 'Bu mağaza slotu oyuncuya ait değil.';
  end if;

  -- Depo ve mağaza aynı şehirde olmalı
  if v_warehouse_slot.city_id <> v_store_slot.city_id then
    raise exception 'Depo ve mağaza aynı şehirde olmalıdır.';
  end if;

  -- Depo slotunda ürün olmalı
  if v_warehouse_slot.product_id is null
     or v_warehouse_slot.quality_level = 0 then
    raise exception 'Depo slotunda ürün seçili değil.';
  end if;

  -- Depoda yeterli stok olmalı
  if v_warehouse_slot.quantity < p_quantity then
    raise exception 'Depoda yeterli ürün yok. Mevcut: %, İstenen: %',
      v_warehouse_slot.quantity,
      p_quantity;
  end if;

  -- Mağaza slotunda ürün seçilmiş olmalı
  if v_store_slot.product_id is null
     or v_store_slot.quality_level = 0 then
    raise exception 'Mağaza slotunda önce ürün ve kalite seçilmelidir.';
  end if;

  -- Ürün ve kalite aynı olmalı
  if v_store_slot.product_id <> v_warehouse_slot.product_id
     or v_store_slot.quality_level <> v_warehouse_slot.quality_level then
    raise exception 'Depo slotundaki ürün/kalite ile mağaza slotundaki ürün/kalite aynı olmalıdır.';
  end if;

  -- Mağaza slot kapasitesi yeterli olmalı
  if v_store_slot.quantity + p_quantity > v_store_slot.capacity then
    raise exception 'Mağaza slot kapasitesi yetersiz. Mevcut: %, Kapasite: %, Eklenmek istenen: %',
      v_store_slot.quantity,
      v_store_slot.capacity,
      p_quantity;
  end if;

  v_new_store_quantity := v_store_slot.quantity + p_quantity;

  -- Mağaza slotu için ağırlıklı ortalama maliyet
  v_new_store_cost :=
    (
      (v_store_slot.quantity * v_store_slot.cost)
      +
      (p_quantity * v_warehouse_slot.cost)
    )
    / v_new_store_quantity;

  v_remaining_warehouse_quantity := v_warehouse_slot.quantity - p_quantity;

  -- Depodan miktar düş
  -- Stok 0 olsa bile ürün bilgileri korunur.
  update public.warehouse_slots
  set
    quantity = v_remaining_warehouse_quantity,
    updated_at = timezone('utc'::text, now())
  where id = p_warehouse_slot_id;

  -- Mağaza slotuna miktar ekle
  update public.store_slots
  set
    quantity = v_new_store_quantity,
    cost = v_new_store_cost,
    updated_at = timezone('utc'::text, now())
  where id = p_store_slot_id;

  return jsonb_build_object(
    'success', true,
    'warehouse_slot_id', p_warehouse_slot_id,
    'store_slot_id', p_store_slot_id,
    'city_id', v_store_slot.city_id,
    'product_id', v_store_slot.product_id,
    'quality_level', v_store_slot.quality_level,
    'transferred_quantity', p_quantity,
    'store_quantity', v_new_store_quantity,
    'store_capacity', v_store_slot.capacity,
    'store_cost', v_new_store_cost,
    'warehouse_remaining_quantity', v_remaining_warehouse_quantity
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.upgrade_player_product_quality(p_player_id uuid, p_product_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  v_product products%rowtype;
  v_quality_row player_product_quality_levels%rowtype;
  v_player players%rowtype;
  v_previous_quality integer;
  v_new_quality integer;
  v_required_level integer;
  v_cost numeric;
  -- Maliyet katsayıları: kalite 1->2: x2, 2->3: x4, 3->4: x7, 4->5: x12
  v_multipliers integer[] := array[2, 4, 7, 12];
begin
  select * into v_player
  from players
  where id = p_player_id;

  if not found then
    raise exception 'Oyuncu bulunamadı.';
  end if;

  select * into v_product
  from products
  where id = p_product_id;

  if not found then
    raise exception 'Ürün bulunamadı: %', p_product_id;
  end if;

  select * into v_quality_row
  from player_product_quality_levels
  where player_id = p_player_id
    and product_id = p_product_id
  for update;

  if found then
    v_previous_quality := v_quality_row.max_quality_level;
  else
    v_previous_quality := 1;
  end if;

  if v_previous_quality >= 5 then
    return jsonb_build_object(
      'success', false,
      'message', 'Bu ürün zaten maksimum kalite seviyesinde (5).'
    );
  end if;

  v_new_quality := v_previous_quality + 1;

  -- Seviye şartı: hedef kalite * 10
  v_required_level := v_new_quality * 10;

  if v_player.level < v_required_level then
    return jsonb_build_object(
      'success', false,
      'message', format('Bu geliştirme için seviye %s gerekli. Mevcut seviyeniz: %s.', v_required_level, v_player.level)
    );
  end if;

  -- Maliyet: baz_satis_fiyati * katsayi[previous_quality]
  v_cost := v_product.baz_satis_fiyati * v_multipliers[v_previous_quality];

  if v_player.cash < v_cost then
    return jsonb_build_object(
      'success', false,
      'message', format('Yetersiz bakiye. Gerekli: %s, Mevcut: %s.', v_cost::text, v_player.cash::text)
    );
  end if;

  -- Parayı düş
  update players
  set
    cash = cash - v_cost,
    updated_at = timezone('utc'::text, now())
  where id = p_player_id;

  -- Kalite güncelle
  if found then
    update player_product_quality_levels
    set
      max_quality_level = v_new_quality,
      updated_at = timezone('utc'::text, now())
    where id = v_quality_row.id;
  else
    insert into player_product_quality_levels (
      player_id,
      product_id,
      max_quality_level,
      created_at,
      updated_at
    ) values (
      p_player_id,
      p_product_id,
      v_new_quality,
      timezone('utc'::text, now()),
      timezone('utc'::text, now())
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'product_id', p_product_id,
    'product_name', v_product.urun_adi,
    'previous_quality_level', v_previous_quality,
    'new_quality_level', v_new_quality,
    'cost_paid', v_cost,
    'production_settings_updated', false
  );
end;
$function$
;


-- ============================================================
-- 7. RLS POLİTİKALARI (Toplam: 28 adet)
-- ============================================================

CREATE POLICY "Players can view their own arge researches" ON public.arge_researches AS PERMISSIVE FOR SELECT TO {public} USING ((auth.uid() = player_id));
CREATE POLICY "Users can insert their own building constructions" ON public.building_constructions AS PERMISSIVE FOR INSERT TO {public} WITH CHECK ((auth.uid() = player_id));
CREATE POLICY "Users can update their own building constructions" ON public.building_constructions AS PERMISSIVE FOR UPDATE TO {public} USING ((auth.uid() = player_id));
CREATE POLICY "Users can view their own building constructions" ON public.building_constructions AS PERMISSIVE FOR SELECT TO {public} USING ((auth.uid() = player_id));
CREATE POLICY "Allow everyone to read cities" ON public.cities AS PERMISSIVE FOR SELECT TO {public} USING (true);
CREATE POLICY "Users can view their own factories" ON public.factories AS PERMISSIVE FOR SELECT TO {authenticated} USING ((auth.uid() = player_id));
CREATE POLICY "Allow everyone to read factory_types" ON public.factory_types AS PERMISSIVE FOR SELECT TO {public} USING (true);
CREATE POLICY "Allow everyone to read farm_types" ON public.farm_types AS PERMISSIVE FOR SELECT TO {public} USING (true);
CREATE POLICY "Users can view their own farms" ON public.farms AS PERMISSIVE FOR SELECT TO {authenticated} USING ((auth.uid() = player_id));
CREATE POLICY "Allow everyone to read field_types" ON public.field_types AS PERMISSIVE FOR SELECT TO {public} USING (true);
CREATE POLICY "Users can view their own fields" ON public.fields AS PERMISSIVE FOR SELECT TO {authenticated} USING ((auth.uid() = player_id));
CREATE POLICY "Players can view their own logistics companies" ON public.logistics_companies AS PERMISSIVE FOR SELECT TO {authenticated} USING ((player_id = auth.uid()));
CREATE POLICY "Enable read access for all users" ON public.logistics_company_types AS PERMISSIVE FOR SELECT TO {public} USING (true);
CREATE POLICY "Players can view related logistics transfers" ON public.logistics_transfers AS PERMISSIVE FOR SELECT TO {authenticated} USING (((buyer_player_id = auth.uid()) OR (seller_player_id = auth.uid()) OR (vehicle_owner_player_id = auth.uid())));
CREATE POLICY "Allow everyone to read logistics_vehicle_types" ON public.logistics_vehicle_types AS PERMISSIVE FOR SELECT TO {public} USING (true);
CREATE POLICY "Players can view their own logistics vehicles" ON public.logistics_vehicles AS PERMISSIVE FOR SELECT TO {authenticated} USING ((player_id = auth.uid()));
CREATE POLICY "Allow everyone to read mine_types" ON public.mine_types AS PERMISSIVE FOR SELECT TO {public} USING (true);
CREATE POLICY "Users can view their own mines" ON public.mines AS PERMISSIVE FOR SELECT TO {authenticated} USING ((auth.uid() = player_id));
CREATE POLICY "Users can insert their own player data" ON public.players AS PERMISSIVE FOR INSERT TO {public} WITH CHECK ((auth.uid() = id));
CREATE POLICY "Users can update their own player data" ON public.players AS PERMISSIVE FOR UPDATE TO {public} USING ((auth.uid() = id));
CREATE POLICY "Users can view their own player data" ON public.players AS PERMISSIVE FOR SELECT TO {public} USING ((auth.uid() = id));
CREATE POLICY "Players can view owned production inventory" ON public.production_inventory AS PERMISSIVE FOR SELECT TO {public} USING ((((owner_kind = 'field'::text) AND (EXISTS ( SELECT 1
   FROM fields f
  WHERE ((f.id = production_inventory.owner_id) AND (f.player_id = auth.uid()))))) OR ((owner_kind = 'farm'::text) AND (EXISTS ( SELECT 1
   FROM farms fa
  WHERE ((fa.id = production_inventory.owner_id) AND (fa.player_id = auth.uid()))))) OR ((owner_kind = 'factory'::text) AND (EXISTS ( SELECT 1
   FROM factories fx
  WHERE ((fx.id = production_inventory.owner_id) AND (fx.player_id = auth.uid()))))) OR ((owner_kind = 'mine'::text) AND (EXISTS ( SELECT 1
   FROM mines m
  WHERE ((m.id = production_inventory.owner_id) AND (m.player_id = auth.uid())))))));
CREATE POLICY "Players can view owned production slots" ON public.production_slots AS PERMISSIVE FOR SELECT TO {public} USING ((((owner_kind = 'field'::text) AND (EXISTS ( SELECT 1
   FROM fields f
  WHERE ((f.id = production_slots.owner_id) AND (f.player_id = auth.uid()))))) OR ((owner_kind = 'farm'::text) AND (EXISTS ( SELECT 1
   FROM farms fa
  WHERE ((fa.id = production_slots.owner_id) AND (fa.player_id = auth.uid()))))) OR ((owner_kind = 'factory'::text) AND (EXISTS ( SELECT 1
   FROM factories fx
  WHERE ((fx.id = production_slots.owner_id) AND (fx.player_id = auth.uid()))))) OR ((owner_kind = 'mine'::text) AND (EXISTS ( SELECT 1
   FROM mines m
  WHERE ((m.id = production_slots.owner_id) AND (m.player_id = auth.uid())))))));
CREATE POLICY "Enable read access for all users" ON public.products AS PERMISSIVE FOR SELECT TO {public} USING (true);
CREATE POLICY "Allow everyone to read store_types" ON public.store_types AS PERMISSIVE FOR SELECT TO {public} USING (true);
CREATE POLICY "Players can view their own warehouse slots" ON public.warehouse_slots AS PERMISSIVE FOR SELECT TO {authenticated} USING ((warehouse_id IN ( SELECT warehouses.id
   FROM warehouses
  WHERE (warehouses.player_id = auth.uid()))));
CREATE POLICY "Enable read access for all users" ON public.warehouse_types AS PERMISSIVE FOR SELECT TO {public} USING (true);
CREATE POLICY "Players can view their own warehouses" ON public.warehouses AS PERMISSIVE FOR SELECT TO {authenticated} USING ((player_id = auth.uid()));

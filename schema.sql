-- Auto-generated Supabase Schema from OpenAPI spec

-- TABLES

CREATE TABLE brand_company_products (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    brand_company_id uuid NOT NULL REFERENCES brand_companies(id),
    player_id uuid NOT NULL REFERENCES players(id),
    product_id text NOT NULL REFERENCES products(id),
    watermark_asset_id text,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE brand_companies (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    brand_name text NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    brand_level integer NOT NULL DEFAULT 1,
    brand_xp bigint NOT NULL,
    logo_id text NOT NULL DEFAULT 'logo1.webp',
    theme_color text NOT NULL DEFAULT '#E5C05C'
);

CREATE TABLE store_daily_performance (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    performance_date date NOT NULL,
    player_id uuid NOT NULL REFERENCES players(id),
    store_id uuid NOT NULL REFERENCES stores(id),
    store_slot_id uuid NOT NULL REFERENCES store_slots(id),
    slot_index integer NOT NULL,
    product_id text,
    product_name text,
    quality_level integer NOT NULL,
    sold_quantity integer NOT NULL,
    revenue numeric NOT NULL,
    profit numeric NOT NULL,
    sale_event_count integer NOT NULL,
    last_sale_at timestamp with time zone NOT NULL DEFAULT now(),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE logistics_transfers (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    buyer_player_id uuid NOT NULL REFERENCES players(id),
    seller_player_id uuid NOT NULL REFERENCES players(id),
    buyer_warehouse_id uuid REFERENCES warehouses(id),
    seller_warehouse_id uuid REFERENCES warehouses(id),
    seller_warehouse_slot_id uuid REFERENCES warehouse_slots(id),
    logistics_vehicle_id uuid REFERENCES logistics_vehicles(id),
    vehicle_owner_player_id uuid REFERENCES players(id),
    is_rental boolean NOT NULL,
    product_id text NOT NULL REFERENCES products(id),
    quality_level integer NOT NULL,
    quantity integer NOT NULL,
    unit_price numeric NOT NULL,
    total_price numeric NOT NULL,
    product_unit_volume numeric NOT NULL,
    reserved_capacity_amount numeric NOT NULL,
    distance_km numeric NOT NULL,
    fuel_used numeric NOT NULL,
    condition_loss numeric NOT NULL,
    rental_cost numeric NOT NULL,
    transport_cost numeric NOT NULL,
    started_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    finish_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone,
    status text NOT NULL DEFAULT 'in_transit',
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    buyer_store_id uuid REFERENCES stores(id),
    buyer_store_slot_id uuid REFERENCES store_slots(id),
    transfer_type text NOT NULL DEFAULT 'market_to_warehouse',
    seller_store_id uuid REFERENCES stores(id),
    seller_store_slot_id uuid REFERENCES store_slots(id),
    seller_entity_kind text,
    buyer_entity_kind text,
    seller_production_inventory_id uuid REFERENCES production_inventory(id),
    buyer_production_inventory_id uuid REFERENCES production_inventory(id),
    item_count integer NOT NULL DEFAULT 1,
    total_quantity integer NOT NULL,
    brand_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'
);

CREATE TABLE game_settings (
    key text NOT NULL,
    value_text text NOT NULL,
    description text,
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE player_missions (
    player_id uuid NOT NULL REFERENCES players(id),
    mission_id text NOT NULL REFERENCES mission_definitions(id),
    progress_count integer NOT NULL,
    is_completed boolean NOT NULL,
    completed_at timestamp with time zone,
    is_claimed boolean NOT NULL,
    claimed_at timestamp with time zone,
    last_progress_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    last_reset_on date DEFAULT (timezone('Europe/Istanbul'::text, now()))
);

CREATE TABLE player_product_brands (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    product_id text NOT NULL REFERENCES products(id),
    brand_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000',
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE logistics_companies (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    city_id uuid REFERENCES cities(id),
    name text NOT NULL,
    level integer NOT NULL DEFAULT 1,
    current_vehicle_count integer NOT NULL,
    max_vehicle_count integer NOT NULL,
    fuel_capacity integer NOT NULL,
    current_fuel integer NOT NULL,
    fuel_cost numeric NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE logistics_transfer_items (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    transfer_id uuid NOT NULL REFERENCES logistics_transfers(id),
    source_warehouse_slot_id uuid REFERENCES warehouse_slots(id),
    target_warehouse_slot_id uuid REFERENCES warehouse_slots(id),
    product_id text NOT NULL REFERENCES products(id),
    quality_level integer NOT NULL,
    brand_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000',
    quantity integer NOT NULL,
    unit_cost numeric NOT NULL,
    unit_price numeric NOT NULL,
    total_cost numeric NOT NULL,
    total_price numeric NOT NULL,
    product_unit_volume numeric NOT NULL,
    reserved_capacity_amount numeric NOT NULL,
    status text NOT NULL DEFAULT 'in_transit',
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    completed_at timestamp with time zone,
    target_production_inventory_id uuid REFERENCES production_inventory(id)
);

CREATE TABLE store_types (
    id uuid NOT NULL PRIMARY KEY,
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

CREATE TABLE factories (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    factory_type_id uuid NOT NULL REFERENCES factory_types(id),
    city_id uuid NOT NULL REFERENCES cities(id),
    name text NOT NULL,
    level integer NOT NULL DEFAULT 1,
    product_id text REFERENCES products(id),
    quality_level integer NOT NULL,
    input_capacity integer NOT NULL,
    output_capacity integer NOT NULL,
    boost_multiplier numeric NOT NULL DEFAULT 1,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    last_production_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    brand_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'
);

CREATE TABLE arge_researches (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    product_id text NOT NULL,
    product_name text NOT NULL,
    current_quality integer NOT NULL,
    target_quality integer NOT NULL,
    cost_paid numeric NOT NULL,
    status text NOT NULL DEFAULT 'in_progress',
    started_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    finish_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE building_constructions (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    building_kind text NOT NULL,
    params jsonb NOT NULL,
    status text NOT NULL DEFAULT 'in_progress',
    started_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    finish_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone,
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE player_experience_logs (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    reason text NOT NULL,
    amount integer NOT NULL,
    old_level integer NOT NULL,
    new_level integer NOT NULL,
    old_experience integer NOT NULL,
    new_experience integer NOT NULL,
    meta jsonb NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE warehouse_types (
    id uuid NOT NULL PRIMARY KEY,
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

CREATE TABLE players (
    id uuid NOT NULL PRIMARY KEY,
    company_name text NOT NULL DEFAULT 'Yeni Holding',
    avatar_id text NOT NULL DEFAULT 'avatar_1.webp',
    level integer NOT NULL DEFAULT 1,
    experience integer NOT NULL,
    cash numeric NOT NULL DEFAULT 100000,
    gold numeric NOT NULL DEFAULT 100,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    player_name text NOT NULL DEFAULT 'Oyuncu',
    google_email text,
    google_avatar_url text
);

CREATE TABLE logistics_vehicle_types (
    id uuid NOT NULL PRIMARY KEY,
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

CREATE TABLE player_leaderboard_stats (
    player_id uuid NOT NULL REFERENCES players(id),
    player_name text NOT NULL,
    company_name text NOT NULL,
    avatar_id text,
    level integer NOT NULL DEFAULT 1,
    experience integer NOT NULL,
    cash numeric NOT NULL,
    gold numeric NOT NULL,
    company_value numeric NOT NULL,
    business_value numeric NOT NULL,
    inventory_value numeric NOT NULL,
    vehicle_value numeric NOT NULL,
    building_base_value numeric NOT NULL,
    building_upgrade_value numeric NOT NULL,
    warehouse_inventory_value numeric NOT NULL,
    store_inventory_value numeric NOT NULL,
    production_inventory_value numeric NOT NULL,
    achievement_unlocked_count integer NOT NULL,
    achievement_total_count integer NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE products (
    id text NOT NULL PRIMARY KEY,
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

CREATE TABLE farm_types (
    id uuid NOT NULL PRIMARY KEY,
    name text,
    icon text,
    accepted_product_ids text,
    cost integer,
    required_level integer,
    construction_time_minutes integer,
    input_capacity integer,
    output_capacity integer,
    max_slot_count integer DEFAULT 5
);

CREATE TABLE production_inventory (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    owner_kind text NOT NULL,
    owner_id uuid NOT NULL,
    inventory_type text NOT NULL,
    product_id text NOT NULL REFERENCES products(id),
    quality_level integer NOT NULL,
    quantity integer NOT NULL,
    pending_quantity numeric NOT NULL,
    cost numeric NOT NULL,
    brand_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'
);

CREATE TABLE mine_types (
    id uuid NOT NULL PRIMARY KEY,
    name text,
    icon text,
    accepted_product_ids text,
    cost integer,
    required_level integer,
    construction_time_minutes integer,
    created_at timestamp with time zone,
    output_capacity integer
);

CREATE TABLE warehouse_slots (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    warehouse_id uuid NOT NULL REFERENCES warehouses(id),
    slot_index integer NOT NULL,
    product_id text REFERENCES products(id),
    quality_level integer NOT NULL,
    quantity integer NOT NULL,
    cost numeric NOT NULL,
    is_available_for_sale boolean NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    price numeric NOT NULL,
    brand_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000',
    pending_quantity integer NOT NULL
);

CREATE TABLE warehouses (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    warehouse_type_id uuid NOT NULL REFERENCES warehouse_types(id),
    city_id uuid NOT NULL REFERENCES cities(id),
    name text NOT NULL,
    level integer NOT NULL DEFAULT 1,
    capacity numeric NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    reserved_capacity numeric NOT NULL,
    store_id uuid,
    warehouse_kind text NOT NULL DEFAULT 'normal'
);

CREATE TABLE field_types (
    id uuid NOT NULL PRIMARY KEY,
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

CREATE TABLE farms (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    farm_type_id uuid NOT NULL REFERENCES farm_types(id),
    city_id uuid NOT NULL REFERENCES cities(id),
    name text NOT NULL,
    level integer NOT NULL DEFAULT 1,
    current_slot_count integer NOT NULL,
    max_slot_count integer NOT NULL,
    input_capacity integer NOT NULL,
    output_capacity integer NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE player_product_quality_levels (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    product_id text NOT NULL REFERENCES products(id),
    max_quality_level integer NOT NULL DEFAULT 1,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE arge_centers (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    name text NOT NULL DEFAULT 'AR-GE Merkezi',
    level integer NOT NULL DEFAULT 1,
    max_concurrent_researches integer NOT NULL DEFAULT 1,
    duration_reduction_pct numeric NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE achievement_definitions (
    id text NOT NULL PRIMARY KEY,
    category text NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    event_key text NOT NULL,
    target_count integer NOT NULL,
    badge_key text,
    badge_color text NOT NULL DEFAULT 'gold',
    reward_xp integer NOT NULL,
    reward_cash numeric NOT NULL,
    reward_gold integer NOT NULL,
    display_order integer NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE cities (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    population integer NOT NULL,
    tax_rate numeric NOT NULL,
    map_position_x numeric NOT NULL,
    map_position_y numeric NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE mission_definitions (
    id text NOT NULL PRIMARY KEY,
    mission_type text NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    event_key text NOT NULL,
    target_count integer NOT NULL,
    reward_xp integer NOT NULL,
    reward_cash numeric NOT NULL,
    reward_gold integer NOT NULL,
    icon_key text,
    display_order integer NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE fields (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    field_type_id uuid NOT NULL REFERENCES field_types(id),
    city_id uuid NOT NULL REFERENCES cities(id),
    name text NOT NULL,
    level integer NOT NULL DEFAULT 1,
    current_slot_count integer NOT NULL,
    max_slot_count integer NOT NULL,
    input_capacity integer NOT NULL,
    output_capacity integer NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE brand_marketing_campaigns (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid REFERENCES players(id),
    campaign_type text NOT NULL,
    cost_paid numeric NOT NULL,
    active_until timestamp with time zone NOT NULL,
    sales_speed_multiplier numeric NOT NULL DEFAULT 1,
    price_premium_multiplier numeric NOT NULL DEFAULT 1,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE logistics_vehicles (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    logistics_company_id uuid NOT NULL REFERENCES logistics_companies(id),
    logistics_vehicle_type_id uuid NOT NULL REFERENCES logistics_vehicle_types(id),
    capacity integer NOT NULL,
    speed_kmh integer NOT NULL,
    fuel_capacity integer NOT NULL,
    current_fuel integer NOT NULL,
    fuel_rate numeric NOT NULL,
    condition integer NOT NULL DEFAULT 100,
    status text NOT NULL DEFAULT 'idle',
    is_available_for_rent boolean NOT NULL,
    rental_price numeric NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    route_city_a_id uuid REFERENCES cities(id),
    route_city_b_id uuid REFERENCES cities(id),
    fuel_cost numeric NOT NULL
);

CREATE TABLE building_boosts (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    building_kind text NOT NULL,
    entity_id uuid NOT NULL,
    duration_hours integer NOT NULL,
    star_cost integer NOT NULL,
    multiplier numeric NOT NULL DEFAULT 2,
    params jsonb NOT NULL,
    status text NOT NULL DEFAULT 'in_progress',
    started_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    finish_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE player_daily_production_stats (
    production_date date NOT NULL,
    player_id uuid NOT NULL,
    owner_kind text NOT NULL,
    owner_id uuid NOT NULL,
    product_id text NOT NULL,
    produced_quantity bigint NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    total_cost numeric NOT NULL
);

CREATE TABLE building_upgrades (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    building_kind text NOT NULL,
    entity_id uuid NOT NULL,
    current_level integer NOT NULL,
    target_level integer NOT NULL,
    params jsonb NOT NULL,
    status text NOT NULL DEFAULT 'in_progress',
    started_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    finish_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE mines (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    mine_type_id uuid NOT NULL REFERENCES mine_types(id),
    city_id uuid NOT NULL REFERENCES cities(id),
    name text NOT NULL,
    level integer NOT NULL DEFAULT 1,
    product_id text REFERENCES products(id),
    quality_level integer NOT NULL,
    output_capacity integer NOT NULL,
    boost_multiplier numeric NOT NULL DEFAULT 1,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    last_production_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    brand_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'
);

CREATE TABLE player_achievements (
    player_id uuid NOT NULL REFERENCES players(id),
    achievement_id text NOT NULL REFERENCES achievement_definitions(id),
    progress_count integer NOT NULL,
    is_unlocked boolean NOT NULL,
    unlocked_at timestamp with time zone,
    reward_granted_at timestamp with time zone,
    last_progress_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE factory_types (
    id uuid NOT NULL PRIMARY KEY,
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

CREATE TABLE player_cash_ledger (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    amount numeric NOT NULL,
    balance_before numeric NOT NULL,
    balance_after numeric NOT NULL,
    category text NOT NULL,
    note text,
    ref_id uuid,
    ref_kind text
);

CREATE TABLE store_slots (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    store_id uuid NOT NULL REFERENCES stores(id),
    slot_index integer NOT NULL,
    product_id text REFERENCES products(id),
    quantity integer NOT NULL,
    quality_level integer NOT NULL,
    price numeric NOT NULL,
    cost numeric NOT NULL,
    boost_multiplier numeric NOT NULL DEFAULT 1,
    pending_sale numeric NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    capacity integer NOT NULL,
    last_sale_processed_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    pending_quantity integer NOT NULL,
    brand_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'
);

CREATE TABLE logistics_finance_entries (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    logistics_company_id uuid REFERENCES logistics_companies(id),
    vehicle_id uuid REFERENCES logistics_vehicles(id),
    entry_type text NOT NULL,
    category text NOT NULL,
    amount numeric NOT NULL,
    quantity numeric,
    unit_cost numeric,
    related_transfer_id uuid REFERENCES logistics_transfers(id),
    related_warehouse_slot_id uuid REFERENCES warehouse_slots(id),
    related_market_listing_id uuid,
    description text,
    metadata jsonb NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE stores (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    store_type_id uuid NOT NULL REFERENCES store_types(id),
    city_id uuid NOT NULL REFERENCES cities(id),
    name text NOT NULL,
    level integer NOT NULL DEFAULT 1,
    current_slot_count integer NOT NULL,
    max_slot_count integer NOT NULL,
    slot_capacity integer NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE logistics_company_types (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    cost integer NOT NULL,
    required_level integer NOT NULL DEFAULT 1,
    construction_time_minutes integer NOT NULL,
    max_vehicle_count integer NOT NULL,
    fuel_capacity integer NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE player_notifications (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES players(id),
    kind text NOT NULL,
    category text NOT NULL,
    title text NOT NULL,
    message text NOT NULL,
    entity_kind text,
    entity_id uuid,
    severity text NOT NULL DEFAULT 'info',
    status text NOT NULL DEFAULT 'unread',
    meta jsonb NOT NULL,
    dedupe_key text,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    read_at timestamp with time zone,
    resolved_at timestamp with time zone,
    expires_at timestamp with time zone
);

CREATE TABLE production_slots (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    owner_kind text NOT NULL,
    owner_id uuid NOT NULL,
    slot_index integer NOT NULL,
    product_id text REFERENCES products(id),
    quality_level integer NOT NULL,
    boost_multiplier numeric NOT NULL DEFAULT 1,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    last_production_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    brand_id uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'
);

-- FUNCTIONS

CREATE OR REPLACE FUNCTION create_player_notification(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_cities_catalog(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rls_auto_enable(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION build_level_progress_payload(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION logistics_vehicle_matches_route(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_warehouse_history_items(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_active_warehouses_basic(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_logistics_vehicle_performance(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION open_store_detail_page(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calculate_experience_reward(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_player_mission_snapshot(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION build_player_achievement_payload(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_active_building_upgrade(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_npc_rental_vehicle_option(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_production_slot_active(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION start_building_construction(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION start_logistics_company_construction(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_store_slot_product_from_warehouse_slot(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_store_slot_active(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_available_products_for_store(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_production_slot(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_experience_required_for_level(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION complete_building_upgrade(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION repair_logistics_vehicle(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION start_warehouse_to_production_transfer(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION start_marketing_campaign(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION claim_player_mission_reward(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_logistics_vehicles(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_daily_production_stats(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_producible_products_for_owner_type(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION build_player_mission_payload(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_arge_center(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_achievement_dashboard(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_mine_detail_data(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_field_detail_data(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_mine_list_items(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION complete_due_building_upgrades(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_factory_list_items(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_logistics_vehicle_route(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_factory_types_catalog(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_logistics_vehicle_types_catalog(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_mine_types_catalog(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION increment_player_achievement_progress(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_logistics_vehicle_rental(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION refuel_logistics_vehicle(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION transfer_warehouse_fuel_to_logistics_company(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION start_building_boost(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION refresh_player_leaderboard_stats(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_warehouse_capacity_status(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_all_products_catalog(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_homepage_dashboard(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION start_building_upgrade(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION assign_production_slot_product(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ensure_player_record_exists(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION start_arge_center_construction(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_arge_products_with_quality(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION clear_store_slot_product(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION start_warehouse_upgrade(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_product_to_warehouse_with_brand(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION process_field_farm_production_entry(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_active_arge_researches(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION process_mine_production_entry(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION start_warehouse_to_warehouse_transfer(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ensure_npc_rental_vehicle(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_npc_logistics_player_id(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION start_production_to_warehouse_transfer(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_warehouse_list_page_data(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_player_achievement_snapshot(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_logistics_vehicle_active(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_logistics_company_types_catalog(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION refresh_player_attention_notifications(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION upsert_player_daily_production_stat(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_warehouses_raw(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION complete_due_arge_researches(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_profile(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sell_store(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calculate_player_company_value(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_transfer_vehicle_options(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION bootstrap_game_session(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION reset_player_daily_missions(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grant_player_experience(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_store_list_page_data(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION finish_construction_with_gold(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_warehouse_slot_price(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ensure_player_mission_rows(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_factory_detail_data(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION grant_player_achievement_reward(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_warehouse_slot_sale_status(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_brand_company_products(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_brand_company_product_watermark(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION refresh_all_leaderboard_stats(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION finish_arge_with_gold(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_mine_product(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION complete_building_construction(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_active_cities(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION transfer_store_warehouse_slot_to_store_slot(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION change_production_slot_product(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_building_constructions(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_player_avatar(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_product_to_warehouse(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION complete_due_warehouse_upgrades(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION start_arge_research(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_store_active(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_player_google_profile(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_active_building_boost(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_any_active_building_upgrade(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_logistics_entry_state(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_buyer_transfer_map_items(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_route_transfer_vehicle_options(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_cash_ledger(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_farm_detail(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_store_slot(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_warehouse_detail(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION log_player_cash_change(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_market_product_detail(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_farm_list_items(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_buyer_transfer_history_items(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION purchase_logistics_vehicle(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION start_multi_warehouse_to_production_transfer(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_field_types_catalog(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION resolve_production_inventory_brand(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_farm_types_catalog(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_warehouse_types_catalog(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_warehouse_slot(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION process_factory_production_entry(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ensure_player_achievement_rows(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION patent_brand_company_product(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION start_multi_market_transfer(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mark_all_notifications_read(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_logistics_company(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION process_player_production_entry(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION store_quality_price_multiplier(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_active_warehouse_upgrade(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_field_list_items(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_brand_company(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_mine_active(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_logistics_finance_summary(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_factory_product(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_mission_dashboard(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION resolve_player_product_brand(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_warehouse_type_detail(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION transfer_store_slot_to_store_warehouse(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION build_player_attention_notifications(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_store_daily_performance(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_factory_active(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calculate_brand_level(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION increment_player_mission_progress(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION complete_due_building_constructions(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION finish_building_boost(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_active_warehouses_with_slots(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_market_listings_for_product(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION complete_due_building_boosts(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION complete_logistics_transfer(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION mark_notification_read(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_market_listings_for_city(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION complete_arge_research(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_notifications(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_store_types_catalog(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION start_multi_logistics_transfer(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION start_multi_production_to_warehouse_transfer(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_city_map_detail(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_logistics_finance_entries(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION finish_building_upgrade_with_gold(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_market_buyer_warehouse_detail(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION finish_warehouse_upgrade_with_gold(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_player_brand_company(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_store_slot_price(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_store_history_items(
    
) RETURNS void AS $$
BEGIN
    -- Implementation details not available in OpenAPI spec
END;
$$ LANGUAGE plpgsql;

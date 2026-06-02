


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."add_product_to_warehouse"("p_player_id" "uuid", "p_warehouse_id" "uuid", "p_product_id" "text", "p_quality_level" integer, "p_quantity" integer, "p_cost" numeric, "p_transport_cost" numeric DEFAULT 0, "p_release_reserved_capacity" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."add_product_to_warehouse"("p_player_id" "uuid", "p_warehouse_id" "uuid", "p_product_id" "text", "p_quality_level" integer, "p_quantity" integer, "p_cost" numeric, "p_transport_cost" numeric, "p_release_reserved_capacity" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_production_slot"("p_player_id" "uuid", "p_owner_kind" "text", "p_owner_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_owner record;
  v_new_slot_index integer;
  v_slot_id uuid;
  v_current_slot_count integer;
  v_max_slot_count integer;
  v_input_capacity_gain integer := 0;
  v_output_capacity_gain integer := 0;
  v_capacity_multiplier numeric := 1;
begin
  if p_owner_kind not in ('field', 'farm') then
    raise exception 'Invalid owner_kind. Only field or farm is allowed: %', p_owner_kind;
  end if;

  if p_owner_kind = 'field' then
    select *
    into v_owner
    from public.fields
    where id = p_owner_id
      and player_id = p_player_id
    for update;

    if not found then
      raise exception 'Field not found or does not belong to player.';
    end if;

    v_current_slot_count := v_owner.current_slot_count;
    v_max_slot_count := v_owner.max_slot_count;

    if v_current_slot_count >= v_max_slot_count then
      raise exception 'Maximum production slot count reached for field. Current: %, Max: %',
        v_current_slot_count,
        v_max_slot_count;
    end if;

  elsif p_owner_kind = 'farm' then
    select
      f.*,
      ft.input_capacity as base_input_capacity,
      ft.output_capacity as base_output_capacity
    into v_owner
    from public.farms f
    join public.farm_types ft on ft.id = f.farm_type_id
    where f.id = p_owner_id
      and f.player_id = p_player_id
    for update;

    if not found then
      raise exception 'Farm not found or does not belong to player.';
    end if;

    v_current_slot_count := v_owner.current_slot_count;
    v_max_slot_count := v_owner.max_slot_count;

    if v_current_slot_count >= v_max_slot_count then
      raise exception 'Maximum production slot count reached for farm. Current: %, Max: %',
        v_current_slot_count,
        v_max_slot_count;
    end if;

    v_capacity_multiplier := power(2::numeric, greatest(coalesce(v_owner.level, 1) - 1, 0));
    v_input_capacity_gain := ceil(((coalesce(v_owner.base_input_capacity, 0)::numeric / greatest(coalesce(v_owner.max_slot_count, 1), 1)) * v_capacity_multiplier))::integer;
    v_output_capacity_gain := ceil(((coalesce(v_owner.base_output_capacity, 0)::numeric / greatest(coalesce(v_owner.max_slot_count, 1), 1)) * v_capacity_multiplier))::integer;
  end if;

  select coalesce(max(slot_index), 0) + 1
  into v_new_slot_index
  from public.production_slots
  where owner_kind = p_owner_kind
    and owner_id = p_owner_id;

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
      input_capacity = input_capacity + v_input_capacity_gain,
      output_capacity = output_capacity + v_output_capacity_gain,
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
    'max_slot_count', v_max_slot_count,
    'input_capacity_gain', v_input_capacity_gain,
    'output_capacity_gain', v_output_capacity_gain
  );
end;
$$;


ALTER FUNCTION "public"."add_production_slot"("p_player_id" "uuid", "p_owner_kind" "text", "p_owner_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_store_slot"("p_player_id" "uuid", "p_store_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_store record;
  v_new_slot_index integer;
  v_slot_id uuid;
  v_boost_multiplier numeric := 1.00;
begin
  select *
  into v_store
  from public.stores
  where id = p_store_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'Magaza bulunamadi veya oyuncuya ait degil.';
  end if;

  if v_store.current_slot_count >= v_store.max_slot_count then
    raise exception 'Magazada acilabilecek maksimum slot sayisina ulasildi. Mevcut: %, Maksimum: %',
      v_store.current_slot_count,
      v_store.max_slot_count;
  end if;

  select coalesce(max(slot_index), 0) + 1
  into v_new_slot_index
  from public.store_slots
  where store_id = p_store_id;

  select coalesce(bb.multiplier, 1.00)
  into v_boost_multiplier
  from public.building_boosts bb
  where bb.player_id = p_player_id
    and bb.building_kind = 'store'
    and bb.entity_id = p_store_id
    and bb.status = 'in_progress'
    and coalesce(bb.finish_at, timezone('utc', now())) > timezone('utc', now())
  order by bb.created_at desc
  limit 1;

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
    coalesce(v_boost_multiplier, 1.00),
    0,
    true
  )
  returning id into v_slot_id;

  update public.stores
  set
    current_slot_count = current_slot_count + 1,
    updated_at = timezone('utc', now())
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
$$;


ALTER FUNCTION "public"."add_store_slot"("p_player_id" "uuid", "p_store_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assign_production_slot_product"("p_player_id" "uuid", "p_production_slot_id" "uuid", "p_product_id" "text", "p_quality_level" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
      updated_at = timezone('utc'::text, now()),
      last_production_at = timezone('utc'::text, now())
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
$$;


ALTER FUNCTION "public"."assign_production_slot_product"("p_player_id" "uuid", "p_production_slot_id" "uuid", "p_product_id" "text", "p_quality_level" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bootstrap_game_session"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player_id uuid := auth.uid();
  v_player jsonb;
  v_logistics_state jsonb;
  v_production_result jsonb;
  v_transfers_result jsonb;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  perform public.ensure_player_record_exists(v_player_id);

  v_production_result := public.process_player_production_entry(v_player_id);
  v_transfers_result := public.complete_due_market_transfers(v_player_id, 100);
  v_player := public.get_player_profile(v_player_id);
  v_logistics_state := public.get_logistics_entry_state();

  return jsonb_build_object(
    'success', true,
    'player', v_player,
    'logistics_entry_state', v_logistics_state,
    'completed_due_building_boosts', v_production_result -> 'completed_due_building_boosts',
    'completed_due_building_upgrades', v_production_result -> 'completed_due_building_upgrades',
    'processed_production', v_production_result,
    'completed_due_market_transfers', v_transfers_result
  );
end;
$$;


ALTER FUNCTION "public"."bootstrap_game_session"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."build_experience_progress_payload"("p_total_experience" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
declare
  v_total_experience integer := greatest(coalesce(p_total_experience, 0), 0);
  v_level integer;
  v_current_level_start integer;
  v_next_level_total integer;
  v_current_level_experience integer;
  v_next_level_required integer;
  v_remaining integer;
  v_ratio numeric;
begin
  v_level := public.get_player_level_from_experience(v_total_experience);
  v_current_level_start := public.get_total_experience_for_level(v_level);
  v_next_level_total := public.get_total_experience_for_level(v_level + 1);
  v_current_level_experience := greatest(v_total_experience - v_current_level_start, 0);
  v_next_level_required := greatest(v_next_level_total - v_current_level_start, 1);
  v_remaining := greatest(v_next_level_total - v_total_experience, 0);

  if v_next_level_required <= 0 then
    v_ratio := 1;
  else
    v_ratio := least(
      1,
      greatest(v_current_level_experience::numeric / v_next_level_required::numeric, 0)
    );
  end if;

  return jsonb_build_object(
    'level', v_level,
    'total_experience', v_total_experience,
    'current_level_start_experience', v_current_level_start,
    'next_level_total_experience', v_next_level_total,
    'current_level_experience', v_current_level_experience,
    'next_level_required_experience', v_next_level_required,
    'remaining_experience_to_next_level', v_remaining,
    'progress_ratio', round(v_ratio, 4)
  );
end;
$$;


ALTER FUNCTION "public"."build_experience_progress_payload"("p_total_experience" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."build_level_progress_payload"("p_level" integer, "p_current_experience" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
declare
  v_level integer := greatest(coalesce(p_level, 1), 1);
  v_current_experience integer := greatest(coalesce(p_current_experience, 0), 0);
  v_required integer := public.get_experience_required_for_level(v_level);
  v_remaining integer;
  v_ratio numeric;
begin
  v_remaining := greatest(v_required - v_current_experience, 0);

  if v_required <= 0 then
    v_ratio := 1;
  else
    v_ratio := least(
      1,
      greatest(v_current_experience::numeric / v_required::numeric, 0)
    );
  end if;

  return jsonb_build_object(
    'level', v_level,
    'current_level_start_experience', 0,
    'next_level_total_experience', v_required,
    'current_level_experience', v_current_experience,
    'next_level_required_experience', v_required,
    'remaining_experience_to_next_level', v_remaining,
    'progress_ratio', round(v_ratio, 4)
  );
end;
$$;


ALTER FUNCTION "public"."build_level_progress_payload"("p_level" integer, "p_current_experience" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."build_player_mission_payload"("p_player_id" "uuid", "p_mission_id" "text") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select jsonb_build_object(
    'id', md.id,
    'mission_type', md.mission_type,
    'title', md.title,
    'description', md.description,
    'event_key', md.event_key,
    'icon_key', md.icon_key,
    'target_count', md.target_count,
    'progress_count', coalesce(pm.progress_count, 0),
    'is_completed', coalesce(pm.is_completed, false),
    'is_claimed', coalesce(pm.is_claimed, false),
    'claimable', coalesce(pm.is_completed, false) and coalesce(pm.is_claimed, false) = false,
    'completed_at', pm.completed_at,
    'claimed_at', pm.claimed_at,
    'reward', jsonb_build_object(
      'xp', md.reward_xp,
      'cash', md.reward_cash,
      'gold', md.reward_gold
    ),
    'display_order', md.display_order,
    'progress_ratio',
      case
        when md.target_count > 0 then
          round(least(coalesce(pm.progress_count, 0), md.target_count)::numeric / md.target_count::numeric, 4)
        else 0
      end
  )
  from public.mission_definitions md
  left join public.player_missions pm
    on pm.mission_id = md.id
   and pm.player_id = p_player_id
  where md.id = p_mission_id;
$$;


ALTER FUNCTION "public"."build_player_mission_payload"("p_player_id" "uuid", "p_mission_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."buy_market_fuel_for_logistics_company"("p_logistics_company_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player_id uuid := auth.uid();
  v_company record;
  v_seller_slot record;
  v_player_cash numeric;
  v_available_capacity integer;
  v_unit_price numeric;
  v_total_price numeric;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select *
  into v_company
  from public.logistics_companies
  where id = p_logistics_company_id
    and player_id = v_player_id
  for update;

  if not found then
    raise exception 'Lojistik merkezi bulunamadi.';
  end if;

  select
    ws.*,
    w.player_id as seller_player_id,
    w.is_active as warehouse_is_active
  into v_seller_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  where ws.id = p_seller_slot_id
  for update;

  if not found then
    raise exception 'Satici slotu bulunamadi.';
  end if;

  if v_seller_slot.seller_player_id = v_player_id then
    raise exception 'Kendi deponuzdan alim icin depo aktarimini kullanin.';
  end if;

  if v_seller_slot.warehouse_is_active is not true then
    raise exception 'Satici depo aktif degil.';
  end if;

  if coalesce(v_seller_slot.product_id, '') <> 'YAKIT' then
    raise exception 'Bu ilanda yakit bulunmuyor.';
  end if;

  if coalesce(v_seller_slot.is_available_for_sale, false) is not true then
    raise exception 'Bu yakit ilani satisa kapali.';
  end if;

  if coalesce(v_seller_slot.quantity, 0) < p_quantity then
    raise exception 'Ilan miktari yetersiz.';
  end if;

  v_available_capacity := greatest(coalesce(v_company.fuel_capacity, 0) - coalesce(v_company.current_fuel, 0), 0);

  if v_available_capacity <= 0 then
    raise exception 'Merkez yakit deposu dolu.';
  end if;

  if p_quantity > v_available_capacity then
    raise exception 'Merkez yakit kapasitesi yetersiz. Bos kapasite: %', v_available_capacity;
  end if;

  v_unit_price := coalesce(v_seller_slot.price, 0);
  v_total_price := v_unit_price * p_quantity;

  select cash
  into v_player_cash
  from public.players
  where id = v_player_id
  for update;

  if coalesce(v_player_cash, 0) < v_total_price then
    raise exception 'Yeterli nakit yok.';
  end if;

  update public.warehouse_slots
  set
    quantity = quantity - p_quantity,
    is_available_for_sale = case when quantity - p_quantity > 0 then is_available_for_sale else false end,
    updated_at = timezone('utc'::text, now())
  where id = p_seller_slot_id;

  update public.players
  set cash = cash - v_total_price
  where id = v_player_id;

  update public.players
  set cash = cash + v_total_price
  where id = v_seller_slot.seller_player_id;

  update public.logistics_companies
  set
    current_fuel = current_fuel + p_quantity,
    updated_at = timezone('utc'::text, now())
  where id = p_logistics_company_id;

  return jsonb_build_object(
    'success', true,
    'company_id', p_logistics_company_id,
    'seller_slot_id', p_seller_slot_id,
    'fuel_added', p_quantity,
    'unit_price', v_unit_price,
    'total_price', v_total_price,
    'company_current_fuel', coalesce(v_company.current_fuel, 0) + p_quantity
  );
end;
$$;


ALTER FUNCTION "public"."buy_market_fuel_for_logistics_company"("p_logistics_company_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_experience_reward"("p_reason" "text", "p_meta" "jsonb" DEFAULT '{}'::"jsonb") RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
declare
  v_building_kind text := coalesce(p_meta ->> 'building_kind', '');
  v_target_level integer := greatest(coalesce((p_meta ->> 'target_level')::integer, 1), 1);
  v_target_quality integer := greatest(coalesce((p_meta ->> 'target_quality')::integer, 1), 1);
  v_quantity integer := greatest(coalesce((p_meta ->> 'quantity')::integer, 0), 0);
  v_sold_quantity integer := greatest(coalesce((p_meta ->> 'sold_quantity')::integer, 0), 0);
  v_profit numeric := greatest(coalesce((p_meta ->> 'profit')::numeric, 0), 0);
begin
  case p_reason
    when 'building_construction_completed' then
      return case v_building_kind
        when 'store' then 90
        when 'warehouse' then 80
        when 'factory' then 110
        when 'field' then 95
        when 'farm' then 95
        when 'mine' then 105
        when 'logistics_company' then 120
        when 'arge_center' then 130
        else 75
      end;
    when 'building_upgrade_completed' then
      return greatest(30, least(220, 30 + (v_target_level * 15)));
    when 'arge_research_completed' then
      return greatest(100, least(320, 80 + (v_target_quality * 40)));
    when 'market_transfer_completed' then
      return greatest(8, least(60, 8 + floor(v_quantity::numeric / 10)::integer));
    when 'production_transfer_completed' then
      return greatest(10, least(70, 10 + floor(v_quantity::numeric / 8)::integer));
    when 'store_sales_processed' then
      return greatest(
        0,
        least(
          60,
          floor(v_sold_quantity::numeric / 2)::integer
          + floor(v_profit / 1000)::integer
        )
      );
    else
      return greatest(coalesce((p_meta ->> 'exp_amount')::integer, 0), 0);
  end case;
end;
$$;


ALTER FUNCTION "public"."calculate_experience_reward"("p_reason" "text", "p_meta" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_building_construction"("p_player_id" "uuid", "p_construction_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."cancel_building_construction"("p_player_id" "uuid", "p_construction_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."change_production_slot_product"("p_player_id" "uuid", "p_production_slot_id" "uuid", "p_product_id" "text", "p_quality_level" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_slot public.production_slots%rowtype;
  v_product public.products%rowtype;
  v_old_product public.products%rowtype;

  v_owner_player_id uuid;
  v_owner_type_id uuid;
  v_accepted_product_ids text;
  v_product_unit text;

  v_old_product_id text;
  v_old_quality_level integer;
  v_same_setting boolean;

  v_max_quality integer;
  v_existing_input_quantity integer := 0;
  v_existing_input_pending numeric := 0;
  v_existing_output_quantity integer := 0;
  v_existing_output_pending numeric := 0;

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

  select *
  into v_old_product
  from public.products
  where id = v_old_product_id;

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

  v_same_setting :=
    v_old_product_id = p_product_id
    and v_old_qualityLevel = p_quality_level;

  if not v_same_setting then
    select coalesce(sum(quantity), 0), coalesce(sum(pending_quantity), 0)
    into v_existing_output_quantity, v_existing_output_pending
    from public.production_inventory
    where owner_kind = v_slot.owner_kind
      and owner_id = v_slot.owner_id
      and inventory_type = 'output'
      and product_id = v_old_product_id
      and quality_level = v_old_quality_level;

    if v_existing_output_quantity > 0 then
      raise exception 'Bu slotun mevcut output stogu var. Urun degistirmeden once stoklari depoya aktar.';
    end if;

    if coalesce(v_existing_output_pending, 0) > 0 then
      raise exception 'Bu slotta yoldaki output urunler var. Urun degistirmeden once transferlerin tamamlanmasini bekleyin.';
    end if;

    select coalesce(sum(quantity), 0), coalesce(sum(pending_quantity), 0)
    into v_existing_input_quantity, v_existing_input_pending
    from public.production_inventory
    where owner_kind = v_slot.owner_kind
      and owner_id = v_slot.owner_id
      and inventory_type = 'input'
      and quality_level = v_input_quality_level
      and product_id in (
        select x.product_id
        from (
          values
            (nullif(v_old_product.hammadde_1_id, '')),
            (nullif(v_old_product.hammadde_2_id, '')),
            (nullif(v_old_product.hammadde_3_id, ''))
        ) as x(product_id)
        where x.product_id is not null
      );

    if v_existing_input_quantity > 0 then
      raise exception 'Bu slotun kullandigi input stoklari var. Urun degistirmeden once stoklari depoya aktar.';
    end if;

    if coalesce(v_existing_input_pending, 0) > 0 then
      raise exception 'Bu slotun kullandigi inputlar icin yoldaki urunler var. Urun degistirmeden once transferlerin tamamlanmasini bekleyin.';
    end if;
  end if;

  update public.production_slots
  set product_id = p_product_id,
      quality_level = p_quality_level,
      updated_at = timezone('utc'::text, now()),
      last_production_at = timezone('utc'::text, now())
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
    'cleared_output_pending_quantity', coalesce(v_existing_output_pending, 0),
    'created_input_count', v_created_input_count,
    'created_output_count', v_created_output_count,
    'deleted_obsolete_inventory_count', v_deleted_obsolete_count,
    'output_inventory_id', v_output_inventory_id
  );
end;
$$;


ALTER FUNCTION "public"."change_production_slot_product"("p_player_id" "uuid", "p_production_slot_id" "uuid", "p_product_id" "text", "p_quality_level" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."claim_player_mission_reward"("p_mission_id" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player_id uuid := auth.uid();
  v_now timestamptz := timezone('utc', now());
  v_mission record;
  v_exp_result jsonb := null;
  v_player jsonb;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  perform public.ensure_player_mission_rows(v_player_id);
  perform public.sync_player_mission_snapshot(v_player_id);

  select
    pm.player_id,
    pm.mission_id,
    pm.progress_count,
    pm.is_completed,
    pm.is_claimed,
    md.title,
    md.reward_xp,
    md.reward_cash,
    md.reward_gold
  into v_mission
  from public.player_missions pm
  join public.mission_definitions md on md.id = pm.mission_id
  where pm.player_id = v_player_id
    and pm.mission_id = p_mission_id
    and md.is_active = true
  for update of pm;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Gorev bulunamadi.');
  end if;

  if v_mission.is_claimed then
    return jsonb_build_object('success', false, 'message', 'Bu gorevin odulu zaten alindi.');
  end if;

  if v_mission.is_completed = false then
    return jsonb_build_object('success', false, 'message', 'Bu gorev henuz tamamlanmadi.');
  end if;

  update public.player_missions
  set
    is_claimed = true,
    claimed_at = v_now,
    updated_at = v_now
  where player_id = v_player_id
    and mission_id = p_mission_id;

  if coalesce(v_mission.reward_cash, 0) > 0 or coalesce(v_mission.reward_gold, 0) > 0 then
    update public.players
    set
      cash = cash + coalesce(v_mission.reward_cash, 0),
      gold = gold + coalesce(v_mission.reward_gold, 0)
    where id = v_player_id;
  end if;

  if coalesce(v_mission.reward_xp, 0) > 0 then
    v_exp_result := public.grant_player_experience(
      v_player_id,
      v_mission.reward_xp,
      'mission_reward_claimed',
      jsonb_build_object(
        'mission_id', p_mission_id,
        'mission_title', v_mission.title
      )
    );
  end if;

  v_player := public.get_player_profile(v_player_id);

  return jsonb_build_object(
    'success', true,
    'message', 'Gorev odulu alindi.',
    'mission', public.build_player_mission_payload(v_player_id, p_mission_id),
    'reward', jsonb_build_object(
      'xp', coalesce(v_mission.reward_xp, 0),
      'cash', coalesce(v_mission.reward_cash, 0),
      'gold', coalesce(v_mission.reward_gold, 0)
    ),
    'experience', v_exp_result,
    'player', v_player
  );
end;
$$;


ALTER FUNCTION "public"."claim_player_mission_reward"("p_mission_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."clear_store_slot_product"("p_player_id" "uuid", "p_store_slot_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."clear_store_slot_product"("p_player_id" "uuid", "p_store_slot_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_arge_research"("p_research_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_research arge_researches%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_exp_result jsonb;
begin
  select * into v_research
  from arge_researches
  where id = p_research_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Arastirma bulunamadi.');
  end if;

  if v_research.status <> 'in_progress' then
    return jsonb_build_object('success', false, 'message', 'Bu arastirma zaten tamamlanmis.');
  end if;

  if v_research.finish_at > v_now then
    return jsonb_build_object('success', false, 'message', 'Arastirma henuz tamamlanmadi.');
  end if;

  insert into player_product_quality_levels (player_id, product_id, max_quality_level, created_at, updated_at)
  values (v_research.player_id, v_research.product_id, v_research.target_quality, v_now, v_now)
  on conflict (player_id, product_id) do update
    set max_quality_level = excluded.max_quality_level, updated_at = v_now;

  update arge_researches
  set status = 'completed', completed_at = v_now
  where id = p_research_id;

  v_exp_result := public.grant_player_experience(
    v_research.player_id,
    public.calculate_experience_reward(
      'arge_research_completed',
      jsonb_build_object(
        'product_id', v_research.product_id,
        'target_quality', v_research.target_quality
      )
    ),
    'arge_research_completed',
    jsonb_build_object(
      'research_id', p_research_id,
      'product_id', v_research.product_id,
      'product_name', v_research.product_name,
      'target_quality', v_research.target_quality
    )
  );

  return jsonb_build_object(
    'success', true,
    'product_id', v_research.product_id,
    'product_name', v_research.product_name,
    'new_quality_level', v_research.target_quality,
    'experience', v_exp_result
  );
end;
$$;


ALTER FUNCTION "public"."complete_arge_research"("p_research_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_building_construction"("p_player_id" "uuid", "p_construction_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_construction record;
  v_now timestamptz := timezone('utc'::text, now());
  v_created_id uuid;
  v_exp_result jsonb;
begin
  select *
  into v_construction
  from public.building_constructions
  where id = p_construction_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'Insaat kaydi bulunamadi.';
  end if;

  if v_construction.status <> 'in_progress' then
    raise exception 'Bu insaat tamamlanabilir durumda degil. Mevcut durum: %', v_construction.status;
  end if;

  if v_construction.finish_at > v_now then
    raise exception 'Insaat henuz bitmedi. Bitis zamani: %', v_construction.finish_at;
  end if;

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
  elsif v_construction.building_kind = 'arge_center' then
    insert into public.arge_centers (
      player_id,
      name,
      level,
      max_concurrent_researches,
      duration_reduction_pct,
      is_active
    )
    values (
      p_player_id,
      coalesce(v_construction.params->>'name', 'AR-GE Merkezi'),
      coalesce((v_construction.params->>'level')::integer, 1),
      coalesce((v_construction.params->>'max_concurrent_researches')::integer, 1),
      coalesce((v_construction.params->>'duration_reduction_pct')::numeric, 0),
      true
    )
    returning id into v_created_id;
  else
    raise exception 'Gecersiz building_kind: %', v_construction.building_kind;
  end if;

  update public.building_constructions
  set
    status = 'complete',
    completed_at = v_now
  where id = p_construction_id;

  v_exp_result := public.grant_player_experience(
    p_player_id,
    public.calculate_experience_reward(
      'building_construction_completed',
      jsonb_build_object('building_kind', v_construction.building_kind)
    ),
    'building_construction_completed',
    jsonb_build_object(
      'construction_id', p_construction_id,
      'building_kind', v_construction.building_kind,
      'created_id', v_created_id
    )
  );

  return jsonb_build_object(
    'success', true,
    'construction_id', p_construction_id,
    'building_kind', v_construction.building_kind,
    'created_id', v_created_id,
    'status', 'complete',
    'completed_at', v_now,
    'experience', v_exp_result
  );
end;
$$;


ALTER FUNCTION "public"."complete_building_construction"("p_player_id" "uuid", "p_construction_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_building_upgrade"("p_player_id" "uuid", "p_upgrade_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_now timestamptz := timezone('utc', now());
  v_upgrade public.building_upgrades%rowtype;
  v_slot_capacity_increase integer := 0;
  v_max_slot_increase integer := 0;
  v_input_capacity_increase integer := 0;
  v_output_capacity_increase integer := 0;
  v_exp_result jsonb;
begin
  select *
  into v_upgrade
  from public.building_upgrades
  where id = p_upgrade_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'Yukseltme bulunamadi.';
  end if;

  if v_upgrade.status <> 'in_progress' then
    raise exception 'Bu yukseltme tamamlanabilir durumda degil. Mevcut durum: %', v_upgrade.status;
  end if;

  if v_upgrade.finish_at > v_now then
    raise exception 'Yukseltme henuz bitmedi. Bitis zamani: %', v_upgrade.finish_at;
  end if;

  if v_upgrade.building_kind = 'store' then
    v_slot_capacity_increase := coalesce((v_upgrade.params->>'slot_capacity_increase')::integer, 0);
    v_max_slot_increase := coalesce((v_upgrade.params->>'max_slot_increase')::integer, 0);

    update public.stores
    set
      level = v_upgrade.target_level,
      slot_capacity = slot_capacity + v_slot_capacity_increase,
      max_slot_count = max_slot_count + v_max_slot_increase,
      updated_at = v_now
    where id = v_upgrade.entity_id
      and player_id = p_player_id;

    update public.store_slots
    set
      capacity = capacity + v_slot_capacity_increase,
      updated_at = v_now
    where store_id = v_upgrade.entity_id;
  elsif v_upgrade.building_kind = 'field' then
    v_input_capacity_increase := coalesce((v_upgrade.params->>'input_capacity_increase')::integer, 0);
    v_output_capacity_increase := coalesce((v_upgrade.params->>'output_capacity_increase')::integer, 0);

    update public.fields
    set
      level = v_upgrade.target_level,
      input_capacity = input_capacity + v_input_capacity_increase,
      output_capacity = output_capacity + v_output_capacity_increase,
      updated_at = v_now
    where id = v_upgrade.entity_id
      and player_id = p_player_id;
  elsif v_upgrade.building_kind = 'farm' then
    v_input_capacity_increase := coalesce((v_upgrade.params->>'input_capacity_increase')::integer, 0);
    v_output_capacity_increase := coalesce((v_upgrade.params->>'output_capacity_increase')::integer, 0);

    update public.farms
    set
      level = v_upgrade.target_level,
      input_capacity = input_capacity + v_input_capacity_increase,
      output_capacity = output_capacity + v_output_capacity_increase,
      updated_at = v_now
    where id = v_upgrade.entity_id
      and player_id = p_player_id;
  elsif v_upgrade.building_kind = 'factory' then
    v_input_capacity_increase := coalesce((v_upgrade.params->>'input_capacity_increase')::integer, 0);
    v_output_capacity_increase := coalesce((v_upgrade.params->>'output_capacity_increase')::integer, 0);

    update public.factories
    set
      level = v_upgrade.target_level,
      input_capacity = input_capacity + v_input_capacity_increase,
      output_capacity = output_capacity + v_output_capacity_increase,
      updated_at = v_now
    where id = v_upgrade.entity_id
      and player_id = p_player_id;
  elsif v_upgrade.building_kind = 'mine' then
    v_output_capacity_increase := coalesce((v_upgrade.params->>'output_capacity_increase')::integer, 0);

    update public.mines
    set
      level = v_upgrade.target_level,
      output_capacity = output_capacity + v_output_capacity_increase,
      updated_at = v_now
    where id = v_upgrade.entity_id
      and player_id = p_player_id;
  elsif v_upgrade.building_kind = 'arge_center' then
    update public.arge_centers
    set
      level = v_upgrade.target_level,
      max_concurrent_researches = coalesce(
        (v_upgrade.params->>'next_concurrent_researches')::integer,
        max_concurrent_researches
      ),
      duration_reduction_pct = coalesce(
        (v_upgrade.params->>'next_duration_reduction_pct')::numeric,
        duration_reduction_pct
      ),
      updated_at = v_now
    where id = v_upgrade.entity_id
      and player_id = p_player_id;
  else
    raise exception 'Bu building_kind icin tamamlama destegi henuz yok: %', v_upgrade.building_kind;
  end if;

  update public.building_upgrades
  set
    status = 'completed',
    completed_at = v_now,
    updated_at = v_now
  where id = p_upgrade_id;

  v_exp_result := public.grant_player_experience(
    p_player_id,
    public.calculate_experience_reward(
      'building_upgrade_completed',
      jsonb_build_object(
        'building_kind', v_upgrade.building_kind,
        'target_level', v_upgrade.target_level
      )
    ),
    'building_upgrade_completed',
    jsonb_build_object(
      'upgrade_id', p_upgrade_id,
      'building_kind', v_upgrade.building_kind,
      'entity_id', v_upgrade.entity_id,
      'target_level', v_upgrade.target_level
    )
  );

  return jsonb_build_object(
    'success', true,
    'upgrade_id', p_upgrade_id,
    'building_kind', v_upgrade.building_kind,
    'entity_id', v_upgrade.entity_id,
    'target_level', v_upgrade.target_level,
    'slot_capacity_increase', v_slot_capacity_increase,
    'max_slot_increase', v_max_slot_increase,
    'input_capacity_increase', v_input_capacity_increase,
    'output_capacity_increase', v_output_capacity_increase,
    'completed_at', v_now,
    'experience', v_exp_result
  );
end;
$$;


ALTER FUNCTION "public"."complete_building_upgrade"("p_player_id" "uuid", "p_upgrade_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_due_arge_researches"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."complete_due_arge_researches"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_due_building_boosts"("p_limit" integer DEFAULT 100) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row record;
  v_completed_count integer := 0;
  v_failed_count integer := 0;
  v_result jsonb;
begin
  for v_row in
    select id, player_id
    from public.building_boosts
    where status = 'in_progress'
      and finish_at <= timezone('utc'::text, now())
    order by finish_at asc
    limit p_limit
    for update skip locked
  loop
    begin
      select public.finish_building_boost(v_row.player_id, v_row.id)
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
$$;


ALTER FUNCTION "public"."complete_due_building_boosts"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_due_building_constructions"("p_limit" integer DEFAULT 100) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."complete_due_building_constructions"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_due_building_upgrades"("p_limit" integer DEFAULT 100) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row record;
  v_completed_count integer := 0;
  v_failed_count integer := 0;
  v_result jsonb;
begin
  for v_row in
    select id, player_id
    from public.building_upgrades
    where status = 'in_progress'
      and finish_at <= timezone('utc'::text, now())
    order by finish_at asc
    limit p_limit
    for update skip locked
  loop
    begin
      select public.complete_building_upgrade(v_row.player_id, v_row.id)
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
$$;


ALTER FUNCTION "public"."complete_due_building_upgrades"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_due_market_transfers"("p_buyer_player_id" "uuid" DEFAULT "auth"."uid"(), "p_limit" integer DEFAULT 100) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_completed_count integer := 0;
  v_transfer record;
  v_result jsonb;
  v_ids uuid[] := '{}';
  v_uuid uuid;
  v_warehouse_ids uuid[] := '{}';
  v_store_ids uuid[] := '{}';
  v_factory_ids uuid[] := '{}';
  v_farm_ids uuid[] := '{}';
  v_field_ids uuid[] := '{}';
  v_mine_ids uuid[] := '{}';
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

      for v_uuid in
        select value::uuid
        from jsonb_array_elements_text(coalesce(v_result -> 'affected' -> 'warehouse_ids', '[]'::jsonb))
      loop
        if not (v_uuid = any(v_warehouse_ids)) then
          v_warehouse_ids := array_append(v_warehouse_ids, v_uuid);
        end if;
      end loop;

      for v_uuid in
        select value::uuid
        from jsonb_array_elements_text(coalesce(v_result -> 'affected' -> 'store_ids', '[]'::jsonb))
      loop
        if not (v_uuid = any(v_store_ids)) then
          v_store_ids := array_append(v_store_ids, v_uuid);
        end if;
      end loop;

      for v_uuid in
        select value::uuid
        from jsonb_array_elements_text(coalesce(v_result -> 'affected' -> 'factory_ids', '[]'::jsonb))
      loop
        if not (v_uuid = any(v_factory_ids)) then
          v_factory_ids := array_append(v_factory_ids, v_uuid);
        end if;
      end loop;

      for v_uuid in
        select value::uuid
        from jsonb_array_elements_text(coalesce(v_result -> 'affected' -> 'farm_ids', '[]'::jsonb))
      loop
        if not (v_uuid = any(v_farm_ids)) then
          v_farm_ids := array_append(v_farm_ids, v_uuid);
        end if;
      end loop;

      for v_uuid in
        select value::uuid
        from jsonb_array_elements_text(coalesce(v_result -> 'affected' -> 'field_ids', '[]'::jsonb))
      loop
        if not (v_uuid = any(v_field_ids)) then
          v_field_ids := array_append(v_field_ids, v_uuid);
        end if;
      end loop;

      for v_uuid in
        select value::uuid
        from jsonb_array_elements_text(coalesce(v_result -> 'affected' -> 'mine_ids', '[]'::jsonb))
      loop
        if not (v_uuid = any(v_mine_ids)) then
          v_mine_ids := array_append(v_mine_ids, v_uuid);
        end if;
      end loop;
    end if;
  end loop;

  return jsonb_build_object(
    'success', true,
    'completed_count', v_completed_count,
    'transfer_ids', v_ids,
    'affected', jsonb_build_object(
      'warehouse_ids', to_jsonb(v_warehouse_ids),
      'store_ids', to_jsonb(v_store_ids),
      'factory_ids', to_jsonb(v_factory_ids),
      'farm_ids', to_jsonb(v_farm_ids),
      'field_ids', to_jsonb(v_field_ids),
      'mine_ids', to_jsonb(v_mine_ids)
    )
  );
end;
$$;


ALTER FUNCTION "public"."complete_due_market_transfers"("p_buyer_player_id" "uuid", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_market_transfer"("p_transfer_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."complete_market_transfer"("p_transfer_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_market_transfer_system"("p_transfer_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_transfer record;
  v_add_result jsonb;
  v_store_slot record;
  v_incoming_unit_cost numeric := 0;
  v_new_cost numeric := 0;
  v_affected jsonb;
  v_exp_result jsonb;
begin
  select *
  into v_transfer
  from public.logistics_transfers
  where id = p_transfer_id
  for update;

  if not found then
    raise exception 'Transfer bulunamadi.';
  end if;

  v_affected := public.get_transfer_affected_targets(p_transfer_id);

  if v_transfer.status <> 'in_transit' then
    return jsonb_build_object(
      'success', true,
      'transfer_id', p_transfer_id,
      'status', v_transfer.status,
      'skipped', true,
      'affected', v_affected
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

  v_exp_result := public.grant_player_experience(
    v_transfer.buyer_player_id,
    public.calculate_experience_reward(
      'market_transfer_completed',
      jsonb_build_object(
        'transfer_type', v_transfer.transfer_type,
        'quantity', v_transfer.quantity
      )
    ),
    'market_transfer_completed',
    jsonb_build_object(
      'transfer_id', p_transfer_id,
      'transfer_type', v_transfer.transfer_type,
      'quantity', v_transfer.quantity,
      'product_id', v_transfer.product_id,
      'quality_level', v_transfer.quality_level
    )
  );

  return jsonb_build_object(
    'success', true,
    'transfer_id', p_transfer_id,
    'status', 'completed',
    'warehouse_result', v_add_result,
    'affected', v_affected,
    'experience', v_exp_result
  );
end;
$$;


ALTER FUNCTION "public"."complete_market_transfer_system"("p_transfer_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."complete_production_logistics_transfer"("p_transfer_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_transfer record;
  v_inventory record;
  v_incoming_unit_cost numeric := 0;
  v_new_cost numeric := 0;
  v_add_result jsonb;
  v_affected jsonb;
  v_exp_result jsonb;
begin
  select *
  into v_transfer
  from public.logistics_transfers
  where id = p_transfer_id
  for update;

  if not found then
    raise exception 'Transfer bulunamadi.';
  end if;

  v_affected := public.get_transfer_affected_targets(p_transfer_id);

  if v_transfer.status <> 'in_transit' then
    return jsonb_build_object(
      'success', true,
      'transfer_id', p_transfer_id,
      'status', v_transfer.status,
      'skipped', true,
      'affected', v_affected
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

  v_exp_result := public.grant_player_experience(
    v_transfer.buyer_player_id,
    public.calculate_experience_reward(
      'production_transfer_completed',
      jsonb_build_object(
        'transfer_type', v_transfer.transfer_type,
        'quantity', v_transfer.quantity
      )
    ),
    'production_transfer_completed',
    jsonb_build_object(
      'transfer_id', p_transfer_id,
      'transfer_type', v_transfer.transfer_type,
      'quantity', v_transfer.quantity,
      'product_id', v_transfer.product_id,
      'quality_level', v_transfer.quality_level
    )
  );

  return jsonb_build_object(
    'success', true,
    'transfer_id', p_transfer_id,
    'status', 'completed',
    'warehouse_result', v_add_result,
    'affected', v_affected,
    'experience', v_exp_result
  );
end;
$$;


ALTER FUNCTION "public"."complete_production_logistics_transfer"("p_transfer_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_warehouse_slot"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_slot record;
begin
  select
    ws.*,
    w.player_id
  into v_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  where ws.id = p_warehouse_slot_id
  for update;

  if not found then
    raise exception 'Depo slotu bulunamadi.';
  end if;

  if v_slot.player_id <> p_player_id then
    raise exception 'Bu depo slotu oyuncuya ait degil.';
  end if;

  if coalesce(v_slot.quantity, 0) > 0 then
    raise exception 'Sadece bos slotlar silinebilir.';
  end if;

  delete from public.warehouse_slots
  where id = p_warehouse_slot_id;

  return jsonb_build_object(
    'success', true,
    'warehouse_id', v_slot.warehouse_id,
    'warehouse_slot_id', p_warehouse_slot_id,
    'message', 'Slot basariyla silindi.'
  );
end;
$$;


ALTER FUNCTION "public"."delete_warehouse_slot"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."logistics_vehicles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "player_id" "uuid" NOT NULL,
    "logistics_company_id" "uuid" NOT NULL,
    "logistics_vehicle_type_id" "uuid" NOT NULL,
    "capacity" integer DEFAULT 0 NOT NULL,
    "speed_kmh" integer DEFAULT 0 NOT NULL,
    "fuel_capacity" integer DEFAULT 0 NOT NULL,
    "current_fuel" integer DEFAULT 0 NOT NULL,
    "fuel_rate" numeric DEFAULT 0 NOT NULL,
    "condition" integer DEFAULT 100 NOT NULL,
    "status" "text" DEFAULT 'idle'::"text" NOT NULL,
    "is_available_for_rent" boolean DEFAULT false NOT NULL,
    "rental_price" numeric DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "route_city_a_id" "uuid",
    "route_city_b_id" "uuid",
    CONSTRAINT "logistics_vehicles_capacity_check" CHECK (("capacity" >= 0)),
    CONSTRAINT "logistics_vehicles_condition_check" CHECK ((("condition" >= 0) AND ("condition" <= 100))),
    CONSTRAINT "logistics_vehicles_current_fuel_check" CHECK ((("current_fuel" >= 0) AND ("current_fuel" <= "fuel_capacity"))),
    CONSTRAINT "logistics_vehicles_fuel_capacity_check" CHECK (("fuel_capacity" >= 0)),
    CONSTRAINT "logistics_vehicles_fuel_rate_check" CHECK (("fuel_rate" >= (0)::numeric)),
    CONSTRAINT "logistics_vehicles_rental_price_check" CHECK (("rental_price" >= (0)::numeric)),
    CONSTRAINT "logistics_vehicles_route_city_pair_check" CHECK (((("route_city_a_id" IS NULL) AND ("route_city_b_id" IS NULL)) OR (("route_city_a_id" IS NOT NULL) AND ("route_city_b_id" IS NOT NULL) AND ("route_city_a_id" <> "route_city_b_id")))),
    CONSTRAINT "logistics_vehicles_speed_check" CHECK (("speed_kmh" >= 0)),
    CONSTRAINT "logistics_vehicles_status_check" CHECK (("status" = ANY (ARRAY['idle'::"text", 'on_route'::"text", 'inactive'::"text"])))
);


ALTER TABLE "public"."logistics_vehicles" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_npc_rental_vehicle"("p_from_city_id" "uuid", "p_to_city_id" "uuid") RETURNS "public"."logistics_vehicles"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_npc_player_id uuid;
  v_company_id uuid;
  v_vehicle_type record;
  v_vehicle public.logistics_vehicles%rowtype;
  v_city_a uuid;
  v_city_b uuid;
  v_now timestamptz := timezone('utc'::text, now());
begin
  if p_from_city_id is null or p_to_city_id is null or p_from_city_id = p_to_city_id then
    raise exception 'NPC fallback araci icin gecersiz rota sehirleri.';
  end if;

  if p_from_city_id::text <= p_to_city_id::text then
    v_city_a := p_from_city_id;
    v_city_b := p_to_city_id;
  else
    v_city_a := p_to_city_id;
    v_city_b := p_from_city_id;
  end if;

  v_npc_player_id := public.get_npc_logistics_player_id();

  select lc.id
  into v_company_id
  from public.logistics_companies lc
  where lc.player_id = v_npc_player_id
  order by lc.created_at asc
  limit 1;

  if v_company_id is null then
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
      is_active,
      created_at,
      updated_at
    )
    values (
      v_npc_player_id,
      v_city_a,
      'Atlas Lojistik',
      99,
      0,
      9999,
      999999,
      999999,
      0,
      true,
      v_now,
      v_now
    )
    returning id into v_company_id;
  else
    update public.logistics_companies
    set
      city_id = coalesce(city_id, v_city_a),
      level = greatest(coalesce(level, 1), 99),
      max_vehicle_count = greatest(coalesce(max_vehicle_count, 0), 9999),
      fuel_capacity = greatest(coalesce(fuel_capacity, 0), 999999),
      current_fuel = greatest(coalesce(current_fuel, 0), 999999),
      fuel_cost = 0,
      is_active = true,
      updated_at = v_now
    where id = v_company_id;
  end if;

  select
    lvt.id,
    coalesce(lvt.capacity, 250) as capacity,
    coalesce(lvt.speed_kmh, 60) as speed_kmh,
    coalesce(lvt.fuel_capacity, 60) as fuel_capacity,
    coalesce(lvt.fuel_rate, 0.02) as fuel_rate,
    coalesce(lvt.name, 'Kiralik Arac') as vehicle_type_name
  into v_vehicle_type
  from public.logistics_vehicle_types lvt
  order by coalesce(lvt.capacity, 999999) asc,
           coalesce(lvt.speed_kmh, 999999) asc,
           lvt.created_at asc
  limit 1;

  if v_vehicle_type.id is null then
    raise exception 'NPC fallback araci icin vehicle type bulunamadi.';
  end if;

  select lv.*
  into v_vehicle
  from public.logistics_vehicles lv
  where lv.player_id = v_npc_player_id
    and lv.logistics_company_id = v_company_id
    and lv.is_available_for_rent = true
    and lv.status = 'idle'
    and (
      (lv.route_city_a_id = v_city_a and lv.route_city_b_id = v_city_b)
      or (lv.route_city_a_id = v_city_b and lv.route_city_b_id = v_city_a)
    )
  order by lv.created_at asc
  limit 1
  for update;

  if found then
    update public.logistics_vehicles
    set
      logistics_vehicle_type_id = v_vehicle_type.id,
      capacity = v_vehicle_type.capacity,
      speed_kmh = v_vehicle_type.speed_kmh,
      fuel_capacity = v_vehicle_type.fuel_capacity,
      current_fuel = v_vehicle_type.fuel_capacity,
      fuel_rate = v_vehicle_type.fuel_rate,
      condition = 100,
      status = 'idle',
      is_available_for_rent = true,
      rental_price = greatest(coalesce(rental_price, 0), 2),
      route_city_a_id = v_city_a,
      route_city_b_id = v_city_b,
      updated_at = v_now
    where id = v_vehicle.id
    returning * into v_vehicle;

    return v_vehicle;
  end if;

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
    rental_price,
    route_city_a_id,
    route_city_b_id,
    created_at,
    updated_at
  )
  values (
    v_npc_player_id,
    v_company_id,
    v_vehicle_type.id,
    v_vehicle_type.capacity,
    v_vehicle_type.speed_kmh,
    v_vehicle_type.fuel_capacity,
    v_vehicle_type.fuel_capacity,
    v_vehicle_type.fuel_rate,
    100,
    'idle',
    true,
    2,
    v_city_a,
    v_city_b,
    v_now,
    v_now
  )
  returning * into v_vehicle;

  update public.logistics_companies
  set
    current_vehicle_count = coalesce(current_vehicle_count, 0) + 1,
    updated_at = v_now
  where id = v_company_id;

  return v_vehicle;
end;
$$;


ALTER FUNCTION "public"."ensure_npc_rental_vehicle"("p_from_city_id" "uuid", "p_to_city_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_player_mission_rows"("p_player_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if p_player_id is null then
    return;
  end if;

  insert into public.player_missions (player_id, mission_id)
  select p_player_id, md.id
  from public.mission_definitions md
  where md.is_active = true
  on conflict (player_id, mission_id) do nothing;
end;
$$;


ALTER FUNCTION "public"."ensure_player_mission_rows"("p_player_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_player_record_exists"("p_user_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."ensure_player_record_exists"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."finish_arge_with_gold"("p_player_id" "uuid", "p_research_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."finish_arge_with_gold"("p_player_id" "uuid", "p_research_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."finish_building_boost"("p_player_id" "uuid", "p_boost_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_now timestamptz := timezone('utc', now());
  v_boost public.building_boosts%rowtype;
begin
  select *
  into v_boost
  from public.building_boosts
  where id = p_boost_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'Boost bulunamadi.';
  end if;

  if v_boost.status <> 'in_progress' then
    raise exception 'Bu boost bitirilemez. Mevcut durum: %', v_boost.status;
  end if;

  if v_boost.building_kind = 'store' then
    update public.store_slots
    set boost_multiplier = 1.00,
        updated_at = v_now
    where store_id = v_boost.entity_id;
  elsif v_boost.building_kind in ('field', 'farm') then
    update public.production_slots
    set boost_multiplier = 1.00,
        updated_at = v_now
    where owner_kind = v_boost.building_kind
      and owner_id = v_boost.entity_id;
  elsif v_boost.building_kind = 'factory' then
    update public.factories
    set boost_multiplier = 1.00,
        updated_at = v_now
    where id = v_boost.entity_id
      and player_id = p_player_id;
  elsif v_boost.building_kind = 'mine' then
    update public.mines
    set boost_multiplier = 1.00,
        updated_at = v_now
    where id = v_boost.entity_id
      and player_id = p_player_id;
  else
    raise exception 'Bu building_kind icin boost bitirme destegi henuz yok: %', v_boost.building_kind;
  end if;

  update public.building_boosts
  set status = 'completed',
      completed_at = v_now,
      updated_at = v_now
  where id = p_boost_id;

  return jsonb_build_object(
    'success', true,
    'boost_id', p_boost_id,
    'building_kind', v_boost.building_kind,
    'entity_id', v_boost.entity_id,
    'completed_at', v_now
  );
end;
$$;


ALTER FUNCTION "public"."finish_building_boost"("p_player_id" "uuid", "p_boost_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."finish_building_upgrade_with_gold"("p_player_id" "uuid", "p_upgrade_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_upgrade record;
  v_player_gold numeric;
  v_gold_cost integer;
  v_remaining_minutes numeric;
  v_result jsonb;
begin
  if p_player_id is null or p_player_id <> auth.uid() then
    raise exception 'Gecersiz oyuncu.';
  end if;

  select *
  into v_upgrade
  from public.building_upgrades
  where id = p_upgrade_id
    and player_id = p_player_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Yukseltme bulunamadi.');
  end if;

  if v_upgrade.status <> 'in_progress' then
    return jsonb_build_object(
      'success', false,
      'message', 'Bu yukseltme zaten tamamlanmis veya gecersiz.'
    );
  end if;

  v_remaining_minutes := extract(epoch from (v_upgrade.finish_at - timezone('utc'::text, now()))) / 60.0;

  if v_remaining_minutes <= 0 then
    return public.complete_building_upgrade(p_player_id, p_upgrade_id) || jsonb_build_object('gold_spent', 0);
  end if;

  v_gold_cost := ceil(v_remaining_minutes / 10.0);

  select gold
  into v_player_gold
  from public.players
  where id = p_player_id
  for update;

  if coalesce(v_player_gold, 0) < v_gold_cost then
    return jsonb_build_object(
      'success', false,
      'message', format('Yetersiz yildiz. Gerekli: %s, Mevcut: %s.', v_gold_cost, coalesce(v_player_gold, 0)::integer)
    );
  end if;

  update public.players
  set gold = gold - v_gold_cost
  where id = p_player_id;

  update public.building_upgrades
  set
    finish_at = timezone('utc'::text, now()),
    updated_at = timezone('utc'::text, now())
  where id = p_upgrade_id;

  v_result := public.complete_building_upgrade(p_player_id, p_upgrade_id);

  return v_result || jsonb_build_object('gold_spent', v_gold_cost);
end;
$$;


ALTER FUNCTION "public"."finish_building_upgrade_with_gold"("p_player_id" "uuid", "p_upgrade_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."finish_construction_with_gold"("p_player_id" "uuid", "p_construction_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."finish_construction_with_gold"("p_player_id" "uuid", "p_construction_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."finish_market_transfer_with_stars"("p_transfer_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player_id uuid := auth.uid();
  v_transfer record;
  v_player_gold numeric;
  v_gold_cost integer;
  v_remaining_minutes numeric;
  v_result jsonb;
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
    return jsonb_build_object('success', false, 'message', 'Transfer bulunamadi veya size ait degil.');
  end if;

  if v_transfer.status <> 'in_transit' then
    return jsonb_build_object(
      'success', false,
      'message', 'Bu transfer yolda degil veya zaten tamamlanmis.'
    );
  end if;

  v_remaining_minutes := extract(epoch from (v_transfer.finish_at - timezone('utc'::text, now()))) / 60.0;

  if v_remaining_minutes <= 0 then
    v_result := public.complete_market_transfer_system(p_transfer_id);
    return v_result || jsonb_build_object('gold_spent', 0);
  end if;

  v_gold_cost := ceil(v_remaining_minutes / 10.0);

  select gold
  into v_player_gold
  from public.players
  where id = v_player_id
  for update;

  if coalesce(v_player_gold, 0) < v_gold_cost then
    return jsonb_build_object(
      'success', false,
      'message', format('Yetersiz yildiz. Gerekli: %s, Mevcut: %s.', v_gold_cost, coalesce(v_player_gold, 0)::integer)
    );
  end if;

  update public.players
  set gold = gold - v_gold_cost
  where id = v_player_id;

  update public.logistics_transfers
  set
    finish_at = timezone('utc'::text, now()),
    updated_at = timezone('utc'::text, now())
  where id = p_transfer_id;

  v_result := public.complete_market_transfer_system(p_transfer_id);

  return v_result || jsonb_build_object('gold_spent', v_gold_cost);
end;
$$;


ALTER FUNCTION "public"."finish_market_transfer_with_stars"("p_transfer_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_active_arge_researches"("p_player_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_result jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', id,
    'player_id', player_id,
    'product_id', product_id,
    'status', status,
    'started_at', started_at,
    'finish_at', finish_at,
    'completed_at', completed_at,
    'created_at', created_at,
    'updated_at', updated_at
  ) order by started_at desc), '[]'::jsonb)
  into v_result
  from public.arge_researches
  where player_id = p_player_id
    and status = 'in_progress';
  return v_result;
end;
$$;


ALTER FUNCTION "public"."get_active_arge_researches"("p_player_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_active_cities"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.get_cities_catalog(true);
$$;


ALTER FUNCTION "public"."get_active_cities"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_all_products_catalog"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    jsonb_agg(to_jsonb(p) order by p.urun_adi),
    '[]'::jsonb
  )
  from public.products p;
$$;


ALTER FUNCTION "public"."get_all_products_catalog"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_arge_products_with_quality"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_arge_products_with_quality"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_available_products_for_store"("p_store_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."get_available_products_for_store"("p_store_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_buyer_active_market_transfers"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', lt.id,
        'product_id', lt.product_id,
        'buyer_warehouse_id', lt.buyer_warehouse_id,
        'buyer_store_slot_id', lt.buyer_store_slot_id,
        'transfer_type', lt.transfer_type,
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
$$;


ALTER FUNCTION "public"."get_buyer_active_market_transfers"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_buyer_transfer_history_items"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
                'inventory_type', pi.inventory_type,
                'city',
                (
                  select jsonb_build_object('id', c.id, 'name', c.name)
                  from public.cities c
                  where c.id = coalesce(sf.city_id, sfi.city_id, sfa.city_id, sm.city_id)
                )
              )
              from public.production_inventory pi
              left join public.farms sf
                on pi.owner_kind = 'farm'
               and sf.id = pi.owner_id
              left join public.fields sfi
                on pi.owner_kind = 'field'
               and sfi.id = pi.owner_id
              left join public.factories sfa
                on pi.owner_kind = 'factory'
               and sfa.id = pi.owner_id
              left join public.mines sm
                on pi.owner_kind = 'mine'
               and sm.id = pi.owner_id
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
                'inventory_type', pi.inventory_type,
                'city',
                (
                  select jsonb_build_object('id', c.id, 'name', c.name)
                  from public.cities c
                  where c.id = coalesce(bf.city_id, bfi.city_id, bfa.city_id, bm.city_id)
                )
              )
              from public.production_inventory pi
              left join public.farms bf
                on pi.owner_kind = 'farm'
               and bf.id = pi.owner_id
              left join public.fields bfi
                on pi.owner_kind = 'field'
               and bfi.id = pi.owner_id
              left join public.factories bfa
                on pi.owner_kind = 'factory'
               and bfa.id = pi.owner_id
              left join public.mines bm
                on pi.owner_kind = 'mine'
               and bm.id = pi.owner_id
              where pi.id = lt.buyer_production_inventory_id
            )
          end
        )
      ) as item
    from public.logistics_transfers lt
    where lt.buyer_player_id = auth.uid()
      and lt.status <> 'in_transit'
    order by lt.completed_at desc nulls last
  ) history_rows;
$$;


ALTER FUNCTION "public"."get_buyer_transfer_history_items"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_buyer_transfer_map_items"() RETURNS TABLE("id" "uuid", "quantity" integer, "status" "text", "is_rental" boolean, "total_price" numeric, "rental_cost" numeric, "started_at" timestamp with time zone, "finish_at" timestamp with time zone, "product_id" "text", "product_name" "text", "product_icon" "text", "seller_entity_kind" "text", "buyer_entity_kind" "text", "seller_warehouse_id" "uuid", "seller_warehouse_name" "text", "seller_city_id" "uuid", "seller_city_name" "text", "seller_city_x" numeric, "seller_city_y" numeric, "buyer_warehouse_id" "uuid", "buyer_warehouse_name" "text", "buyer_city_id" "uuid", "buyer_city_name" "text", "buyer_city_x" numeric, "buyer_city_y" numeric)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_buyer_transfer_map_items"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_cities_catalog"("p_only_active" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    jsonb_agg(to_jsonb(c) order by c.name),
    '[]'::jsonb
  )
  from public.cities c
  where (not p_only_active) or c.is_active = true;
$$;


ALTER FUNCTION "public"."get_cities_catalog"("p_only_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_city_map_detail"("p_city_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select jsonb_build_object(
    'id', c.id,
    'name', c.name,
    'map_position_x', c.map_position_x,
    'map_position_y', c.map_position_y
  )
  from public.cities c
  where c.id = p_city_id;
$$;


ALTER FUNCTION "public"."get_city_map_detail"("p_city_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_experience_required_for_level"("p_level" integer) RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
begin
  return greatest(250, 250 * greatest(coalesce(p_level, 1), 1));
end;
$$;


ALTER FUNCTION "public"."get_experience_required_for_level"("p_level" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_factory_detail_data"("p_factory_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select jsonb_build_object(
    'factory',
      to_jsonb(f) || jsonb_build_object(
        'boost_multiplier',
        coalesce((
          select bb.multiplier
          from public.building_boosts bb
          where bb.player_id = auth.uid()
            and bb.building_kind = 'factory'
            and bb.entity_id = f.id
            and bb.status = 'in_progress'
            and coalesce(bb.finish_at, timezone('utc'::text, now())) > timezone('utc'::text, now())
          order by bb.started_at desc
          limit 1
        ), 1.00)
      ),
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
$$;


ALTER FUNCTION "public"."get_factory_detail_data"("p_factory_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_factory_list_items"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'factory',
          to_jsonb(f) || jsonb_build_object(
            'boost_multiplier',
            coalesce((
              select bb.multiplier
              from public.building_boosts bb
              where bb.player_id = auth.uid()
                and bb.building_kind = 'factory'
                and bb.entity_id = f.id
                and bb.status = 'in_progress'
                and coalesce(bb.finish_at, timezone('utc'::text, now())) > timezone('utc'::text, now())
              order by bb.started_at desc
              limit 1
            ), 1.00)
          ),
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
$$;


ALTER FUNCTION "public"."get_factory_list_items"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_factory_types_catalog"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    jsonb_agg(to_jsonb(ft) order by ft.required_level, ft.cost),
    '[]'::jsonb
  )
  from public.factory_types ft;
$$;


ALTER FUNCTION "public"."get_factory_types_catalog"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_farm_detail"("p_player_id" "uuid", "p_farm_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_auth_user uuid := auth.uid();
  v_farm record;
  v_farm_type record;
  v_city_name text;
  v_slots jsonb := '[]'::jsonb;
  v_inventories jsonb := '[]'::jsonb;
  v_active_boost_multiplier numeric := 1.00;
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

  select coalesce(bb.multiplier, 1.00)
  into v_active_boost_multiplier
  from public.building_boosts bb
  where bb.player_id = p_player_id
    and bb.building_kind = 'farm'
    and bb.entity_id = p_farm_id
    and bb.status = 'in_progress'
    and coalesce(bb.finish_at, timezone('utc'::text, now())) > timezone('utc'::text, now())
  order by bb.started_at desc
  limit 1;

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
        'boost_multiplier', coalesce(v_active_boost_multiplier, 1.00),
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
$$;


ALTER FUNCTION "public"."get_farm_detail"("p_player_id" "uuid", "p_farm_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_farm_list_items"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
              (to_jsonb(ps) - 'boost_multiplier') || jsonb_build_object(
                'boost_multiplier',
                coalesce((
                  select bb.multiplier
                  from public.building_boosts bb
                  where bb.player_id = auth.uid()
                    and bb.building_kind = 'farm'
                    and bb.entity_id = f.id
                    and bb.status = 'in_progress'
                    and coalesce(bb.finish_at, timezone('utc'::text, now())) > timezone('utc'::text, now())
                  order by bb.started_at desc
                  limit 1
                ), 1.00),
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
$$;


ALTER FUNCTION "public"."get_farm_list_items"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_farm_types_catalog"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    jsonb_agg(to_jsonb(ft) order by ft.required_level, ft.cost),
    '[]'::jsonb
  )
  from public.farm_types ft;
$$;


ALTER FUNCTION "public"."get_farm_types_catalog"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_field_detail_data"("p_field_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select jsonb_build_object(
    'field', to_jsonb(f),
    'field_type', to_jsonb(ft),
    'city_name', coalesce(c.name, 'Bilinmeyen Sehir'),
    'slots',
      coalesce((
        select jsonb_agg(
          (to_jsonb(ps) - 'boost_multiplier') || jsonb_build_object(
            'boost_multiplier',
            coalesce((
              select bb.multiplier
              from public.building_boosts bb
              where bb.player_id = auth.uid()
                and bb.building_kind = 'field'
                and bb.entity_id = f.id
                and bb.status = 'in_progress'
                and coalesce(bb.finish_at, timezone('utc'::text, now())) > timezone('utc'::text, now())
              order by bb.started_at desc
              limit 1
            ), 1.00),
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
$$;


ALTER FUNCTION "public"."get_field_detail_data"("p_field_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_field_list_items"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
              (to_jsonb(ps) - 'boost_multiplier') || jsonb_build_object(
                'boost_multiplier',
                coalesce((
                  select bb.multiplier
                  from public.building_boosts bb
                  where bb.player_id = auth.uid()
                    and bb.building_kind = 'field'
                    and bb.entity_id = f.id
                    and bb.status = 'in_progress'
                    and coalesce(bb.finish_at, timezone('utc'::text, now())) > timezone('utc'::text, now())
                  order by bb.started_at desc
                  limit 1
                ), 1.00),
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
$$;


ALTER FUNCTION "public"."get_field_list_items"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_field_types_catalog"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    jsonb_agg(to_jsonb(ft) order by ft.required_level, ft.cost),
    '[]'::jsonb
  )
  from public.field_types ft;
$$;


ALTER FUNCTION "public"."get_field_types_catalog"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_logistics_company_types_catalog"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    jsonb_agg(to_jsonb(lct) order by lct.required_level, lct.cost),
    '[]'::jsonb
  )
  from public.logistics_company_types lct;
$$;


ALTER FUNCTION "public"."get_logistics_company_types_catalog"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_logistics_entry_state"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with company as (
    select to_jsonb(lc) as data
    from public.logistics_companies lc
    where lc.player_id = auth.uid()
    order by lc.created_at
    limit 1
  ),
  construction as (
    select jsonb_build_object(
      'id', bc.id,
      'player_id', bc.player_id,
      'building_kind', bc.building_kind,
      'status', bc.status,
      'params', bc.params,
      'started_at', bc.started_at,
      'finish_at', bc.finish_at,
      'completed_at', bc.completed_at
    ) as data
    from public.building_constructions bc
    where bc.player_id = auth.uid()
      and bc.building_kind = 'logistics_company'
      and bc.status = 'in_progress'
    order by bc.started_at desc
    limit 1
  )
  select jsonb_build_object(
    'success', true,
    'has_company', exists(select 1 from company),
    'has_construction', exists(select 1 from construction),
    'company', (select data from company),
    'construction', (select data from construction),
    'route', case
      when exists(select 1 from company) or exists(select 1 from construction)
        then '/logistics'
      else '/logistics/setup'
    end
  );
$$;


ALTER FUNCTION "public"."get_logistics_entry_state"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_logistics_vehicle_types_catalog"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    jsonb_agg(to_jsonb(lvt) order by lvt.purchase_price),
    '[]'::jsonb
  )
  from public.logistics_vehicle_types lvt;
$$;


ALTER FUNCTION "public"."get_logistics_vehicle_types_catalog"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_market_buyer_store_slot_detail"("p_store_slot_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_market_buyer_store_slot_detail"("p_store_slot_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_market_buyer_warehouse_detail"("p_warehouse_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_market_buyer_warehouse_detail"("p_warehouse_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_market_listings_for_product"("p_product_id" "text") RETURNS TABLE("slot_id" "uuid", "warehouse_id" "uuid", "warehouse_name" "text", "warehouse_icon" "text", "city_id" "uuid", "city_name" "text", "city_x" numeric, "city_y" numeric, "seller_player_id" "uuid", "seller_player_name" "text", "seller_avatar_id" "text", "quantity" integer, "quality_level" integer, "price" numeric, "cost" numeric, "is_available_for_sale" boolean)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
    coalesce(p.player_name, 'Oyuncu') as seller_player_name,
    coalesce(p.avatar_id, 'ae1.webp') as seller_avatar_id,
    ws.quantity,
    ws.quality_level,
    ws.price,
    ws.cost,
    ws.is_available_for_sale
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  join public.players p on p.id = w.player_id
  left join public.warehouse_types wt on wt.id = w.warehouse_type_id
  left join public.cities c on c.id = w.city_id
  where ws.product_id = p_product_id
    and ws.is_available_for_sale = true
    and ws.quantity > 0
    and coalesce(ws.price, 0) > 0
    and w.is_active = true
    and w.player_id <> auth.uid()
  order by ws.price asc, ws.quality_level desc, ws.quantity desc, ws.updated_at desc;
$$;


ALTER FUNCTION "public"."get_market_listings_for_product"("p_product_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_market_product_detail"("p_product_id" "text") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select to_jsonb(p)
  from public.products p
  where p.id = p_product_id;
$$;


ALTER FUNCTION "public"."get_market_product_detail"("p_product_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_market_transfer_vehicle_options"("p_buyer_warehouse_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer) RETURNS TABLE("vehicle_id" "uuid", "vehicle_owner_player_id" "uuid", "vehicle_name" "text", "is_rental" boolean, "capacity" integer, "speed_kmh" integer, "current_fuel" integer, "fuel_capacity" integer, "fuel_rate" numeric, "condition" integer, "rental_price" numeric, "distance_km" numeric, "fuel_needed" numeric, "condition_needed" numeric, "rental_cost" numeric, "estimated_duration_seconds" integer, "can_select" boolean, "disabled_reason" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_buyer_id uuid := auth.uid();
  v_buyer_warehouse record;
  v_seller_slot record;
  v_product record;
  v_distance_km numeric := 0;
  v_required_capacity numeric := 0;
  v_available_capacity numeric := 0;
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
  select greatest(
    coalesce(v_buyer_warehouse.capacity, 0)::numeric
    - coalesce(sum(ws.quantity::numeric * coalesce(p.birim_hacim, 0)), 0)
    - coalesce(v_buyer_warehouse.reserved_capacity, 0)::numeric,
    0
  )
  into v_available_capacity
  from public.warehouse_slots ws
  left join public.products p on p.id = ws.product_id
  where ws.warehouse_id = p_buyer_warehouse_id;

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
      lv.id as v_id,
      lv.player_id as v_owner_player_id,
      lvt.name as v_name,
      (lv.player_id <> v_buyer_id) as v_is_rental,
      lv.capacity as v_capacity,
      lv.speed_kmh as v_speed_kmh,
      lv.current_fuel as v_current_fuel,
      lv.fuel_capacity as v_fuel_capacity,
      lv.fuel_rate as v_fuel_rate,
      lv.condition as v_condition,
      lv.rental_price as v_rental_price,
      v_distance_km as v_distance_km_val,
      ceil(v_distance_km * lv.fuel_rate) as v_fuel_needed,
      ceil(v_distance_km * 0.02) as v_condition_needed,
      case
        when lv.player_id <> v_buyer_id then ceil(v_distance_km * lv.rental_price)
        else 0
      end as v_rental_cost,
      greatest(1, ceil(((v_distance_km / greatest(lv.speed_kmh, 1)) / 4.0) * 3600))::integer as v_estimated_duration_seconds,
      lv.status as v_status,
      lv.is_available_for_rent as v_is_available_for_rent,
      lc.is_active as v_company_is_active,
      public.logistics_vehicle_matches_route(lv.route_city_a_id, lv.route_city_b_id, v_seller_slot.seller_city_id, v_buyer_warehouse.city_id) as v_route_matches
    from public.logistics_vehicles lv
    join public.logistics_vehicle_types lvt on lvt.id = lv.logistics_vehicle_type_id
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where lv.player_id <> v_seller_slot.seller_player_id
      and (
        lv.player_id = v_buyer_id
        or (lv.player_id <> v_buyer_id and lv.is_available_for_rent = true)
      )

    union all

    select
      '00000000-0000-0000-0000-000000000000'::uuid as v_id,
      '00000000-0000-0000-0000-000000000000'::uuid as v_owner_player_id,
      'Sistem Nakliye Araci' as v_name,
      true as v_is_rental,
      999999 as v_capacity,
      60 as v_speed_kmh,
      999999 as v_current_fuel,
      999999 as v_fuel_capacity,
      0::numeric as v_fuel_rate,
      100 as v_condition,
      5.0::numeric as v_rental_price,
      v_distance_km as v_distance_km_val,
      0::numeric as v_fuel_needed,
      0::numeric as v_condition_needed,
      ceil(v_distance_km * 5.0) as v_rental_cost,
      greatest(1, ceil(((v_distance_km / 60.0) / 4.0) * 3600))::integer as v_estimated_duration_seconds,
      'idle' as v_status,
      true as v_is_available_for_rent,
      true as v_company_is_active,
      true as v_route_matches
  ),
  final_res as (
      select
        c.v_id as out_vehicle_id,
        c.v_owner_player_id as out_vehicle_owner_player_id,
        c.v_name as out_vehicle_name,
        c.v_is_rental as out_is_rental,
        c.v_capacity as out_capacity,
        c.v_speed_kmh as out_speed_kmh,
        c.v_current_fuel as out_current_fuel,
        c.v_fuel_capacity as out_fuel_capacity,
        c.v_fuel_rate as out_fuel_rate,
        c.v_condition as out_condition,
        c.v_rental_price as out_rental_price,
        c.v_distance_km_val as out_distance_km,
        c.v_fuel_needed as out_fuel_needed,
        c.v_condition_needed as out_condition_needed,
        c.v_rental_cost as out_rental_cost,
        c.v_estimated_duration_seconds as out_estimated_duration_seconds,
        (
          c.v_route_matches = true
          and c.v_status = 'idle'
          and c.v_company_is_active = true
          and v_available_capacity >= v_required_capacity
          and c.v_capacity >= v_required_capacity
          and c.v_current_fuel >= c.v_fuel_needed
          and c.v_condition > c.v_condition_needed
        ) as out_can_select,
        case
          when c.v_route_matches is not true then 'Aracin rotasi bu sehir ciftini desteklemiyor.'
          when c.v_status <> 'idle' then 'Arac su anda uygun degil.'
          when c.v_company_is_active = false then 'Nakliye firmasi aktif degil.'
          when v_available_capacity < v_required_capacity then 'Hedef depoda bos kapasite yetersiz.'
          when c.v_capacity < v_required_capacity then 'Kapasite yetersiz.'
          when c.v_current_fuel < c.v_fuel_needed then 'Yakit yetersiz.'
          when c.v_condition <= c.v_condition_needed then 'Kondisyon yetersiz.'
          else null
        end as out_disabled_reason
      from candidates c
  )
  select * from final_res fr
  order by fr.out_is_rental asc, fr.out_can_select desc, fr.out_capacity asc, fr.out_rental_price asc, fr.out_vehicle_name asc nulls last;
end;
$$;


ALTER FUNCTION "public"."get_market_transfer_vehicle_options"("p_buyer_warehouse_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_market_transfer_vehicle_options_for_store"("p_store_slot_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer) RETURNS TABLE("vehicle_id" "uuid", "vehicle_owner_player_id" "uuid", "vehicle_name" "text", "is_rental" boolean, "capacity" integer, "speed_kmh" integer, "current_fuel" integer, "fuel_capacity" integer, "fuel_rate" numeric, "condition" integer, "rental_price" numeric, "distance_km" numeric, "fuel_needed" numeric, "condition_needed" numeric, "rental_cost" numeric, "estimated_duration_seconds" integer, "can_select" boolean, "disabled_reason" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
      lv.id as v_id,
      lv.player_id as v_owner_player_id,
      lvt.name as v_name,
      (lv.player_id <> v_buyer_id) as v_is_rental,
      lv.capacity as v_capacity,
      lv.speed_kmh as v_speed_kmh,
      lv.current_fuel as v_current_fuel,
      lv.fuel_capacity as v_fuel_capacity,
      lv.fuel_rate as v_fuel_rate,
      lv.condition as v_condition,
      lv.rental_price as v_rental_price,
      v_distance_km as v_distance_km_val,
      ceil(v_distance_km * lv.fuel_rate) as v_fuel_needed,
      ceil(v_distance_km * 0.02) as v_condition_needed,
      case when lv.player_id <> v_buyer_id then ceil(v_distance_km * lv.rental_price) else 0 end as v_rental_cost,
      greatest(1, ceil(((v_distance_km / greatest(lv.speed_kmh, 1)) / 4.0) * 3600))::integer as v_estimated_duration_seconds,
      lv.status as v_status,
      lv.is_available_for_rent as v_is_available_for_rent,
      lc.is_active as v_company_is_active,
      public.logistics_vehicle_matches_route(lv.route_city_a_id, lv.route_city_b_id, v_seller_slot.seller_city_id, v_store_slot.store_city_id) as v_route_matches
    from public.logistics_vehicles lv
    join public.logistics_vehicle_types lvt on lvt.id = lv.logistics_vehicle_type_id
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where lv.player_id <> v_seller_slot.seller_player_id
      and (
        lv.player_id = v_buyer_id
        or (lv.player_id <> v_buyer_id and lv.is_available_for_rent = true)
      )

    union all

    select
      '00000000-0000-0000-0000-000000000000'::uuid as v_id,
      '00000000-0000-0000-0000-000000000000'::uuid as v_owner_player_id,
      'Sistem Nakliye Araci' as v_name,
      true as v_is_rental,
      999999 as v_capacity,
      60 as v_speed_kmh,
      999999 as v_current_fuel,
      999999 as v_fuel_capacity,
      0::numeric as v_fuel_rate,
      100 as v_condition,
      5.0::numeric as v_rental_price,
      v_distance_km as v_distance_km_val,
      0::numeric as v_fuel_needed,
      0::numeric as v_condition_needed,
      ceil(v_distance_km * 5.0) as v_rental_cost,
      greatest(1, ceil(((v_distance_km / 60.0) / 4.0) * 3600))::integer as v_estimated_duration_seconds,
      'idle' as v_status,
      true as v_is_available_for_rent,
      true as v_company_is_active,
      true as v_route_matches
  ),
  final_res as (
      select
        c.v_id as out_vehicle_id,
        c.v_owner_player_id as out_vehicle_owner_player_id,
        c.v_name as out_vehicle_name,
        c.v_is_rental as out_is_rental,
        c.v_capacity as out_capacity,
        c.v_speed_kmh as out_speed_kmh,
        c.v_current_fuel as out_current_fuel,
        c.v_fuel_capacity as out_fuel_capacity,
        c.v_fuel_rate as out_fuel_rate,
        c.v_condition as out_condition,
        c.v_rental_price as out_rental_price,
        c.v_distance_km_val as out_distance_km,
        c.v_fuel_needed as out_fuel_needed,
        c.v_condition_needed as out_condition_needed,
        c.v_rental_cost as out_rental_cost,
        c.v_estimated_duration_seconds as out_estimated_duration_seconds,
        (
          c.v_route_matches = true
          and c.v_status = 'idle'
          and c.v_company_is_active = true
          and c.v_capacity >= v_required_capacity
          and c.v_current_fuel >= c.v_fuel_needed
          and c.v_condition > c.v_condition_needed
        ) as out_can_select,
        case
          when c.v_route_matches is not true then 'Aracin rotasi bu sehir ciftini desteklemiyor.'
          when c.v_status <> 'idle' then 'Arac su anda uygun degil.'
          when c.v_company_is_active = false then 'Nakliye firmasi aktif degil.'
          when c.v_capacity < v_required_capacity then 'Kapasite yetersiz.'
          when c.v_current_fuel < c.v_fuel_needed then 'Yakit yetersiz.'
          when c.v_condition <= c.v_condition_needed then 'Kondisyon yetersiz.'
          else null
        end as out_disabled_reason
      from candidates c
  )
  select * from final_res fr
  order by fr.out_is_rental asc, fr.out_can_select desc, fr.out_capacity asc, fr.out_rental_price asc, fr.out_vehicle_name asc nulls last;
end;
$$;


ALTER FUNCTION "public"."get_market_transfer_vehicle_options_for_store"("p_store_slot_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_mine_detail_data"("p_mine_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select jsonb_build_object(
    'mine',
      to_jsonb(m) || jsonb_build_object(
        'boost_multiplier',
        coalesce((
          select bb.multiplier
          from public.building_boosts bb
          where bb.player_id = auth.uid()
            and bb.building_kind = 'mine'
            and bb.entity_id = m.id
            and bb.status = 'in_progress'
            and coalesce(bb.finish_at, timezone('utc'::text, now())) > timezone('utc'::text, now())
          order by bb.started_at desc
          limit 1
        ), 1.00)
      ),
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
$$;


ALTER FUNCTION "public"."get_mine_detail_data"("p_mine_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_mine_list_items"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'mine',
          to_jsonb(m) || jsonb_build_object(
            'boost_multiplier',
            coalesce((
              select bb.multiplier
              from public.building_boosts bb
              where bb.player_id = auth.uid()
                and bb.building_kind = 'mine'
                and bb.entity_id = m.id
                and bb.status = 'in_progress'
                and coalesce(bb.finish_at, timezone('utc'::text, now())) > timezone('utc'::text, now())
              order by bb.started_at desc
              limit 1
            ), 1.00)
          ),
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
$$;


ALTER FUNCTION "public"."get_mine_list_items"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_mine_types_catalog"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    jsonb_agg(to_jsonb(mt) order by mt.required_level, mt.cost),
    '[]'::jsonb
  )
  from public.mine_types mt;
$$;


ALTER FUNCTION "public"."get_mine_types_catalog"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_npc_logistics_player_id"() RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player_id uuid;
begin
  select value_text::uuid
  into v_player_id
  from public.game_settings
  where key = 'npc_logistics_player_id';

  if v_player_id is null then
    raise exception 'npc_logistics_player_id ayari bulunamadi.';
  end if;

  if not exists (
    select 1 from public.players p where p.id = v_player_id
  ) then
    raise exception 'npc_logistics_player_id gecersiz veya players tablosunda yok.';
  end if;

  return v_player_id;
end;
$$;


ALTER FUNCTION "public"."get_npc_logistics_player_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_npc_rental_vehicle_option"("p_from_city_id" "uuid", "p_to_city_id" "uuid", "p_distance_km" numeric) RETURNS TABLE("vehicle_id" "uuid", "vehicle_owner_player_id" "uuid", "vehicle_name" "text", "is_rental" boolean, "capacity" integer, "speed_kmh" integer, "current_fuel" integer, "fuel_capacity" integer, "fuel_rate" numeric, "condition" integer, "rental_price" numeric, "distance_km" numeric, "fuel_needed" numeric, "condition_needed" numeric, "rental_cost" numeric, "estimated_duration_seconds" integer, "can_select" boolean, "disabled_reason" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_vehicle public.logistics_vehicles%rowtype;
  v_distance numeric := coalesce(p_distance_km, 0);
  v_vehicle_type_name text;
begin
  if p_from_city_id is null or p_to_city_id is null or p_from_city_id = p_to_city_id then
    return;
  end if;

  v_vehicle := public.ensure_npc_rental_vehicle(p_from_city_id, p_to_city_id);

  select coalesce(lvt.name, 'Kiralik Arac')
  into v_vehicle_type_name
  from public.logistics_vehicle_types lvt
  where lvt.id = v_vehicle.logistics_vehicle_type_id;

  return query
  select
    v_vehicle.id,
    v_vehicle.player_id,
    v_vehicle_type_name,
    true,
    v_vehicle.capacity,
    v_vehicle.speed_kmh,
    v_vehicle.current_fuel,
    v_vehicle.fuel_capacity,
    v_vehicle.fuel_rate,
    v_vehicle.condition,
    v_vehicle.rental_price,
    v_distance,
    ceil(v_distance * coalesce(v_vehicle.fuel_rate, 0))::numeric,
    ceil(v_distance * 0.02)::numeric,
    ceil(v_distance * coalesce(v_vehicle.rental_price, 0))::numeric,
    greatest(1, ceil(((v_distance / greatest(v_vehicle.speed_kmh, 1)) / 4.0) * 3600))::integer,
    true,
    null::text;
end;
$$;


ALTER FUNCTION "public"."get_npc_rental_vehicle_option"("p_from_city_id" "uuid", "p_to_city_id" "uuid", "p_distance_km" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_player_active_building_boost"("p_building_kind" "text", "p_entity_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select to_jsonb(bb)
  from public.building_boosts bb
  where bb.player_id = auth.uid()
    and bb.building_kind = p_building_kind
    and bb.entity_id = p_entity_id
    and bb.status = 'in_progress'
    and coalesce(bb.finish_at, timezone('utc', now())) > timezone('utc', now())
  order by bb.started_at desc
  limit 1;
$$;


ALTER FUNCTION "public"."get_player_active_building_boost"("p_building_kind" "text", "p_entity_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_player_active_building_upgrade"("p_building_kind" "text", "p_entity_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select to_jsonb(bu)
  from public.building_upgrades bu
  where bu.player_id = auth.uid()
    and bu.building_kind = p_building_kind
    and bu.entity_id = p_entity_id
    and bu.status = 'in_progress'
    and coalesce(bu.finish_at, timezone('utc', now())) > timezone('utc', now())
  order by bu.started_at desc
  limit 1;
$$;


ALTER FUNCTION "public"."get_player_active_building_upgrade"("p_building_kind" "text", "p_entity_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_player_active_warehouses_basic"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_player_active_warehouses_basic"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_player_active_warehouses_with_slots"("p_city_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_player_active_warehouses_with_slots"("p_city_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_player_arge_center"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select to_jsonb(ac)
  from public.arge_centers ac
  where ac.player_id = auth.uid()
  order by ac.created_at
  limit 1;
$$;


ALTER FUNCTION "public"."get_player_arge_center"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_player_building_constructions"("p_building_kind" "text", "p_status" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    jsonb_agg(to_jsonb(bc) order by bc.started_at),
    '[]'::jsonb
  )
  from public.building_constructions bc
  where bc.player_id = auth.uid()
    and bc.building_kind = p_building_kind
    and (p_status is null or bc.status = p_status);
$$;


ALTER FUNCTION "public"."get_player_building_constructions"("p_building_kind" "text", "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_player_level_from_experience"("p_experience" integer) RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
declare
  v_level integer := 1;
begin
  while v_level < 250
    and public.get_total_experience_for_level(v_level + 1) <= greatest(coalesce(p_experience, 0), 0)
  loop
    v_level := v_level + 1;
  end loop;

  return v_level;
end;
$$;


ALTER FUNCTION "public"."get_player_level_from_experience"("p_experience" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_player_level_progress"("p_player_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_level integer;
  v_current_experience integer;
begin
  select coalesce(level, 1), coalesce(experience, 0)
  into v_level, v_current_experience
  from public.players
  where id = p_player_id;

  if not found then
    return null;
  end if;

  return public.build_level_progress_payload(v_level, v_current_experience);
end;
$$;


ALTER FUNCTION "public"."get_player_level_progress"("p_player_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_player_logistics_company"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select to_jsonb(lc)
  from public.logistics_companies lc
  where lc.player_id = auth.uid()
  order by lc.created_at
  limit 1;
$$;


ALTER FUNCTION "public"."get_player_logistics_company"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_player_logistics_vehicle_performance"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_player_logistics_vehicle_performance"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_player_logistics_vehicles"("p_player_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_result jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', id,
    'player_id', player_id,
    'logistics_company_id', logistics_company_id,
    'logistics_vehicle_type_id', logistics_vehicle_type_id,
    'capacity', capacity,
    'speed_kmh', speed_kmh,
    'fuel_capacity', fuel_capacity,
    'current_fuel', current_fuel,
    'fuel_rate', fuel_rate,
    'condition', condition,
    'status', status,
    'is_available_for_rent', is_available_for_rent,
    'rental_price', rental_price,
    'created_at', created_at,
    'updated_at', updated_at,
    'route_city_a_id', route_city_a_id,
    'route_city_b_id', route_city_b_id
  ) order by created_at asc), '[]'::jsonb)
  into v_result
  from public.logistics_vehicles
  where player_id = p_player_id;
  return v_result;
end;
$$;


ALTER FUNCTION "public"."get_player_logistics_vehicles"("p_player_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_player_mission_dashboard"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player_id uuid := auth.uid();
  v_main_mission jsonb;
  v_side_missions jsonb := '[]'::jsonb;
  v_claimable_count integer := 0;
  v_completed_count integer := 0;
  v_total_count integer := 0;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  perform public.ensure_player_mission_rows(v_player_id);
  perform public.sync_player_mission_snapshot(v_player_id);

  select public.build_player_mission_payload(v_player_id, mission_id)
  into v_main_mission
  from (
    select pm.mission_id, md.display_order
    from public.player_missions pm
    join public.mission_definitions md on md.id = pm.mission_id
    where pm.player_id = v_player_id
      and md.is_active = true
      and md.mission_type = 'main'
      and pm.is_claimed = false
    order by pm.is_completed desc, md.display_order asc
    limit 1
  ) main_pick;

  select coalesce(
    jsonb_agg(public.build_player_mission_payload(v_player_id, mission_id) order by sort_completed desc, display_order asc),
    '[]'::jsonb
  )
  into v_side_missions
  from (
    select
      pm.mission_id,
      md.display_order,
      case when pm.is_completed then 1 else 0 end as sort_completed
    from public.player_missions pm
    join public.mission_definitions md on md.id = pm.mission_id
    where pm.player_id = v_player_id
      and md.is_active = true
      and md.mission_type in ('side', 'achievement')
      and pm.is_claimed = false
    order by sort_completed desc, md.display_order asc
    limit 2
  ) side_pick;

  select
    count(*) filter (where pm.is_completed = true and pm.is_claimed = false),
    count(*) filter (where pm.is_completed = true),
    count(*)
  into v_claimable_count, v_completed_count, v_total_count
  from public.player_missions pm
  join public.mission_definitions md on md.id = pm.mission_id
  where pm.player_id = v_player_id
    and md.is_active = true;

  return jsonb_build_object(
    'success', true,
    'main_mission', v_main_mission,
    'side_missions', v_side_missions,
    'claimable_count', coalesce(v_claimable_count, 0),
    'summary', jsonb_build_object(
      'completed_count', coalesce(v_completed_count, 0),
      'total_count', coalesce(v_total_count, 0)
    )
  );
end;
$$;


ALTER FUNCTION "public"."get_player_mission_dashboard"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_player_profile"("p_player_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player record;
  v_progress jsonb;
begin
  select * into v_player from public.players where id = p_player_id;
  if not found then
    return null;
  end if;

  v_progress := public.build_level_progress_payload(
    coalesce(v_player.level, 1),
    coalesce(v_player.experience, 0)
  );

  return jsonb_build_object(
    'id', v_player.id,
    'player_name', v_player.player_name,
    'company_name', v_player.company_name,
    'avatar_id', v_player.avatar_id,
    'level', coalesce(v_player.level, 1),
    'experience', v_player.experience,
    'cash', v_player.cash,
    'gold', v_player.gold,
    'created_at', v_player.created_at,
    'current_level_start_experience', coalesce((v_progress ->> 'current_level_start_experience')::integer, 0),
    'next_level_total_experience', coalesce((v_progress ->> 'next_level_total_experience')::integer, 0),
    'current_level_experience', coalesce((v_progress ->> 'current_level_experience')::integer, 0),
    'next_level_required_experience', coalesce((v_progress ->> 'next_level_required_experience')::integer, 1),
    'remaining_experience_to_next_level', coalesce((v_progress ->> 'remaining_experience_to_next_level')::integer, 0),
    'exp_progress_ratio', coalesce((v_progress ->> 'progress_ratio')::numeric, 0)
  );
end;
$$;


ALTER FUNCTION "public"."get_player_profile"("p_player_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_player_warehouse_detail"("p_warehouse_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_player_warehouse_detail"("p_warehouse_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_player_warehouses_raw"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_player_warehouses_raw"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_producible_products_for_owner_type"("p_player_id" "uuid", "p_owner_kind" "text", "p_type_id" "uuid") RETURNS TABLE("id" "text", "urun_adi" "text", "urun_iconu" "text", "birim_hacim" numeric, "birim_agirlik" numeric, "hammadde_1_id" "text", "hammadde_1_miktar" numeric, "hammadde_2_id" "text", "hammadde_2_miktar" numeric, "hammadde_3_id" "text", "hammadde_3_miktar" numeric, "uretim_birimi" "text", "baz_satis_fiyati" numeric, "uretim_adedi" integer, "satis_adedi" integer, "en_dusuk_fiyat" numeric, "en_yuksek_fiyat" numeric, "ortalama_fiyat" numeric, "satici_sayisi" integer, "piyasadaki_stok" integer, "created_at" timestamp with time zone, "max_quality_level" integer)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_producible_products_for_owner_type"("p_player_id" "uuid", "p_owner_kind" "text", "p_type_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_production_input_transfer_vehicle_options"("p_warehouse_slot_id" "uuid", "p_production_inventory_id" "uuid", "p_quantity" integer) RETURNS TABLE("vehicle_id" "uuid", "vehicle_owner_player_id" "uuid", "vehicle_name" "text", "is_rental" boolean, "capacity" integer, "speed_kmh" integer, "current_fuel" integer, "fuel_capacity" integer, "fuel_rate" numeric, "condition" integer, "rental_price" numeric, "distance_km" numeric, "fuel_needed" numeric, "condition_needed" numeric, "rental_cost" numeric, "estimated_duration_seconds" integer, "can_select" boolean, "disabled_reason" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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

  select ws.*, w.player_id, w.id as warehouse_id, w.city_id, w.is_active as warehouse_is_active, c.map_position_x as city_x, c.map_position_y as city_y
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

  select * into v_inventory from public.production_inventory where id = p_production_inventory_id;
  if not found then raise exception 'Production inventory bulunamadi.'; end if;
  if v_inventory.inventory_type <> 'input' then raise exception 'Sadece input inventory icin hammadde lojistigi desteklenir.'; end if;
  if v_inventory.owner_kind not in ('factory', 'field', 'farm') then raise exception 'Bu owner_kind icin input lojistigi desteklenmiyor: %', v_inventory.owner_kind; end if;

  if v_inventory.owner_kind = 'factory' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id from public.factories where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'field' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id from public.fields where id = v_inventory.owner_id;
  else
    select player_id, city_id into v_owner_player_id, v_owner_city_id from public.farms where id = v_inventory.owner_id;
  end if;

  if v_owner_player_id is null then raise exception 'Hedef uretim birimi bulunamadi.'; end if;
  if v_owner_player_id <> v_player_id then raise exception 'Hedef uretim birimi size ait degil.'; end if;
  if v_inventory.product_id <> v_warehouse_slot.product_id then raise exception 'Depo slotundaki urun ile input inventory urunu ayni olmalidir.'; end if;
  if v_inventory.quality_level <> v_warehouse_slot.quality_level then raise exception 'Depo slotundaki kalite ile input inventory kalitesi ayni olmalidir.'; end if;

  select * into v_product from public.products where id = v_warehouse_slot.product_id;
  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then raise exception 'Urun hacim bilgisi gecersiz.'; end if;

  select * into v_target_city from public.cities where id = v_owner_city_id;
  if not found then raise exception 'Hedef sehir bulunamadi.'; end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_warehouse_slot.city_x - v_target_city.map_position_x) / 2)), 2)
      + cos(radians(v_target_city.map_position_x)) * cos(radians(v_warehouse_slot.city_x))
      * power(sin(radians((v_warehouse_slot.city_y - v_target_city.map_position_y) / 2)), 2)
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
    where lv.player_id = v_player_id or (lv.player_id <> v_player_id and lv.is_available_for_rent = true)
  ), real_options as (
    select
      c.vehicle_id, c.vehicle_owner_player_id, c.vehicle_name, c.is_rental, c.capacity, c.speed_kmh,
      c.current_fuel, c.fuel_capacity, c.fuel_rate, c.condition, c.rental_price, c.distance_km,
      c.fuel_needed, c.condition_needed, c.rental_cost, c.estimated_duration_seconds,
      (
        c.route_matches = true and c.status = 'idle' and c.company_is_active = true and c.capacity >= v_required_capacity
        and c.current_fuel >= c.fuel_needed and c.condition > c.condition_needed
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
  )
  select * from real_options
  union all
  select * from public.get_npc_rental_vehicle_option(v_warehouse_slot.city_id, v_owner_city_id, v_distance_km)
  where not exists (select 1 from real_options ro where ro.can_select)
  order by 4 asc, 17 desc, 5 asc, 11 asc, 3 asc;
end;
$$;


ALTER FUNCTION "public"."get_production_input_transfer_vehicle_options"("p_warehouse_slot_id" "uuid", "p_production_inventory_id" "uuid", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_production_output_transfer_vehicle_options"("p_production_inventory_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer) RETURNS TABLE("vehicle_id" "uuid", "vehicle_owner_player_id" "uuid", "vehicle_name" "text", "is_rental" boolean, "capacity" integer, "speed_kmh" integer, "current_fuel" integer, "fuel_capacity" integer, "fuel_rate" numeric, "condition" integer, "rental_price" numeric, "distance_km" numeric, "fuel_needed" numeric, "condition_needed" numeric, "rental_cost" numeric, "estimated_duration_seconds" integer, "can_select" boolean, "disabled_reason" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
  if v_player_id is null then raise exception 'Oturum acilmamis.'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Miktar 0''dan buyuk olmalidir.'; end if;

  select * into v_inventory from public.production_inventory where id = p_production_inventory_id;
  if not found then raise exception 'Production inventory bulunamadi.'; end if;
  if v_inventory.inventory_type <> 'output' then raise exception 'Sadece output inventory icin output lojistigi desteklenir.'; end if;
  if v_inventory.owner_kind not in ('factory', 'field', 'farm', 'mine') then raise exception 'Bu owner_kind icin output lojistigi desteklenmiyor: %', v_inventory.owner_kind; end if;
  if coalesce(v_inventory.quantity, 0) < p_quantity then raise exception 'Istenen miktar mevcut output stoktan fazla.'; end if;

  if v_inventory.owner_kind = 'factory' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id from public.factories where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'field' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id from public.fields where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'farm' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id from public.farms where id = v_inventory.owner_id;
  else
    select player_id, city_id into v_owner_player_id, v_owner_city_id from public.mines where id = v_inventory.owner_id;
  end if;

  if v_owner_player_id is null then raise exception 'Kaynak uretim birimi bulunamadi.'; end if;
  if v_owner_player_id <> v_player_id then raise exception 'Kaynak uretim birimi size ait degil.'; end if;

  select w.*, c.map_position_x as city_x, c.map_position_y as city_y
  into v_buyer_warehouse
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id and w.player_id = v_player_id;
  if not found then raise exception 'Hedef depo bulunamadi veya size ait degil.'; end if;
  if v_buyer_warehouse.is_active is not true then raise exception 'Hedef depo aktif degil.'; end if;

  select * into v_product from public.products where id = v_inventory.product_id;
  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then raise exception 'Urun hacim bilgisi gecersiz.'; end if;

  select * into v_source_city from public.cities where id = v_owner_city_id;
  if not found then raise exception 'Kaynak sehir bulunamadi.'; end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_source_city.map_position_x - v_buyer_warehouse.city_x) / 2)), 2)
      + cos(radians(v_buyer_warehouse.city_x)) * cos(radians(v_source_city.map_position_x))
      * power(sin(radians((v_source_city.map_position_y - v_buyer_warehouse.city_y) / 2)), 2)
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
    where lv.player_id = v_player_id or (lv.player_id <> v_player_id and lv.is_available_for_rent = true)
  ), real_options as (
    select
      c.vehicle_id, c.vehicle_owner_player_id, c.vehicle_name, c.is_rental, c.capacity, c.speed_kmh,
      c.current_fuel, c.fuel_capacity, c.fuel_rate, c.condition, c.rental_price, c.distance_km,
      c.fuel_needed, c.condition_needed, c.rental_cost, c.estimated_duration_seconds,
      (
        c.route_matches = true and c.status = 'idle' and c.company_is_active = true and c.capacity >= v_required_capacity
        and c.current_fuel >= c.fuel_needed and c.condition > c.condition_needed
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
  )
  select * from real_options
  union all
  select * from public.get_npc_rental_vehicle_option(v_owner_city_id, v_buyer_warehouse.city_id, v_distance_km)
  where not exists (select 1 from real_options ro where ro.can_select)
  order by 4 asc, 17 desc, 5 asc, 11 asc, 3 asc;
end;
$$;


ALTER FUNCTION "public"."get_production_output_transfer_vehicle_options"("p_production_inventory_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_store_daily_performance"("p_player_id" "uuid", "p_store_id" "uuid", "p_days" integer DEFAULT 14) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_store_daily_performance"("p_player_id" "uuid", "p_store_id" "uuid", "p_days" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_store_history_items"("p_store_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with transfer_items as (
    select jsonb_build_object(
      'id', 'transfer_' || lt.id::text,
      'type',
        case when lt.buyer_store_id = p_store_id then 'incoming_transfer' else 'outgoing_transfer' end,
      'happened_at', coalesce(lt.completed_at, lt.finish_at, lt.started_at),
      'title',
        case
          when lt.buyer_store_id = p_store_id then
            case
              when lt.status = 'in_transit' then
                case when coalesce(lt.total_price, 0) > 0 then 'Pazardan Geliyor' else 'Depodan Geliyor' end
              else
                case when coalesce(lt.total_price, 0) > 0 then 'Pazardan Geldi' else 'Depodan Geldi' end
            end
          else
            case
              when lt.status = 'in_transit' then 'Depoya Gonderiliyor'
              else 'Depoya Gonderildi'
            end
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
$$;


ALTER FUNCTION "public"."get_store_history_items"("p_store_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_store_list_page_data"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with live_rows as (
    select
      s.id,
      s.created_at as sort_time,
      s.name as sort_name,
      false as is_under_construction,
      s.is_active,
      coalesce(slot_summary.total_capacity, 0) as total_capacity,
      jsonb_build_object(
        'id', s.id,
        'name', s.name,
        'city_id', s.city_id,
        'city_name', c.name,
        'level', s.level,
        'is_active', s.is_active,
        'current_slot_count', s.current_slot_count,
        'max_slot_count', s.max_slot_count,
        'slot_capacity', s.slot_capacity,
        'store_type', jsonb_build_object(
          'id', st.id,
          'name', st.name,
          'icon', st.icon,
          'cost', st.cost,
          'required_level', st.required_level,
          'construction_time_minutes', st.construction_time_minutes
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
          end,
          'pending_sale_total', coalesce(slot_summary.pending_sale_total, 0),
          'total_stock_cost_value', coalesce(slot_summary.total_stock_cost_value, 0),
          'total_stock_sale_value', coalesce(slot_summary.total_stock_sale_value, 0)
        ),
        'slots', coalesce(slot_summary.slots, '[]'::jsonb),
        'is_under_construction', false
      ) as payload
    from public.stores s
    join public.cities c on c.id = s.city_id
    join public.store_types st on st.id = s.store_type_id
    left join lateral (
      select
        coalesce(sum(ss.quantity), 0) as total_quantity,
        coalesce(sum(ss.capacity), 0) as total_capacity,
        coalesce(sum(ss.pending_quantity), 0) as pending_quantity,
        coalesce(sum(ss.pending_sale), 0) as pending_sale_total,
        coalesce(sum(ss.quantity * ss.cost), 0) as total_stock_cost_value,
        coalesce(sum(ss.quantity * ss.price), 0) as total_stock_sale_value,
        coalesce(
          jsonb_agg(
            jsonb_build_object(
              'slot_id', ss.id,
              'id', ss.id,
              'store_id', ss.store_id,
              'slot_index', ss.slot_index,
              'product_id', ss.product_id,
              'product_name', p.urun_adi,
              'product_icon', p.urun_iconu,
              'quality_level', ss.quality_level,
              'quantity', ss.quantity,
              'capacity', ss.capacity,
              'pending_quantity', ss.pending_quantity,
              'price', ss.price,
              'cost', ss.cost,
              'pending_sale', ss.pending_sale,
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
      from public.store_slots ss
      left join public.products p on p.id = ss.product_id
      where ss.store_id = s.id
    ) slot_summary on true
    where s.player_id = auth.uid()
  ),
  construction_rows as (
    select
      bc.id,
      bc.started_at as sort_time,
      coalesce(nullif(bc.params ->> 'name', ''), st.name, 'Magaza') as sort_name,
      true as is_under_construction,
      false as is_active,
      coalesce((bc.params ->> 'slot_capacity')::integer, 0) as total_capacity,
      jsonb_build_object(
        'id', bc.id,
        'name', coalesce(nullif(bc.params ->> 'name', ''), st.name, 'Magaza'),
        'city_id', bc.params ->> 'city_id',
        'city_name', c.name,
        'level', coalesce((bc.params ->> 'level')::integer, 1),
        'is_active', false,
        'current_slot_count', coalesce((bc.params ->> 'current_slot_count')::integer, 0),
        'max_slot_count', coalesce((bc.params ->> 'max_slot_count')::integer, 0),
        'slot_capacity', coalesce((bc.params ->> 'slot_capacity')::integer, 0),
        'store_type', jsonb_build_object(
          'id', st.id,
          'name', st.name,
          'icon', st.icon,
          'cost', st.cost,
          'required_level', st.required_level,
          'construction_time_minutes', st.construction_time_minutes
        ),
        'summary', jsonb_build_object(
          'total_quantity', 0,
          'total_capacity', coalesce((bc.params ->> 'slot_capacity')::integer, 0),
          'pending_quantity', 0,
          'available_capacity', coalesce((bc.params ->> 'slot_capacity')::integer, 0),
          'used_capacity_ratio', 0
        ),
        'slots', '[]'::jsonb,
        'is_under_construction', true,
        'started_at', bc.started_at,
        'finish_at', bc.finish_at,
        'construction_progress', case
          when bc.finish_at <= bc.started_at then 0
          else least(
            greatest(
              extract(epoch from (timezone('utc', now()) - bc.started_at))
              / nullif(extract(epoch from (bc.finish_at - bc.started_at)), 0),
              0
            ),
            1
          )
        end
      ) as payload
    from public.building_constructions bc
    left join public.store_types st
      on st.id = nullif(bc.params ->> 'store_type_id', '')::uuid
    left join public.cities c
      on c.id = nullif(bc.params ->> 'city_id', '')::uuid
    where bc.player_id = auth.uid()
      and bc.building_kind = 'store'
      and bc.status = 'in_progress'
  ),
  combined as (
    select * from live_rows
    union all
    select * from construction_rows
  )
  select jsonb_build_object(
    'success', true,
    'stores', coalesce(
      (
        select jsonb_agg(payload order by sort_time asc, sort_name asc)
        from combined
      ),
      '[]'::jsonb
    ),
    'summary', jsonb_build_object(
      'total_count', coalesce((select count(*) from combined), 0),
      'active_count', coalesce((select count(*) from live_rows where is_active is true), 0),
      'construction_count', coalesce((select count(*) from construction_rows), 0),
      'total_capacity', coalesce((select sum(total_capacity) from live_rows), 0)
    )
  );
$$;


ALTER FUNCTION "public"."get_store_list_page_data"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_store_to_warehouse_vehicle_options"("p_store_slot_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer) RETURNS TABLE("vehicle_id" "uuid", "vehicle_owner_player_id" "uuid", "vehicle_name" "text", "is_rental" boolean, "capacity" integer, "speed_kmh" integer, "current_fuel" integer, "fuel_capacity" integer, "fuel_rate" numeric, "condition" integer, "rental_price" numeric, "distance_km" numeric, "fuel_needed" numeric, "condition_needed" numeric, "rental_cost" numeric, "estimated_duration_seconds" integer, "can_select" boolean, "disabled_reason" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player_id uuid := auth.uid();
  v_store_slot record;
  v_buyer_warehouse record;
  v_product record;
  v_required_capacity numeric := 0;
  v_distance_km numeric := 0;
begin
  if v_player_id is null then raise exception 'Oturum acilmamis.'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Miktar 0''dan buyuk olmalidir.'; end if;

  select ss.*, s.player_id, s.is_active as store_is_active, s.city_id as store_city_id, c.map_position_x as city_x, c.map_position_y as city_y
  into v_store_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  join public.cities c on c.id = s.city_id
  where ss.id = p_store_slot_id;
  if not found or v_store_slot.player_id <> v_player_id then raise exception 'Magaza slotu bulunamadi veya size ait degil.'; end if;
  if v_store_slot.store_is_active is not true then raise exception 'Magaza aktif degil.'; end if;
  if coalesce(v_store_slot.product_id, '') = '' or coalesce(v_store_slot.quality_level, 0) = 0 then raise exception 'Magaza slotunda gecerli urun veya kalite yok.'; end if;
  if p_quantity > coalesce(v_store_slot.quantity, 0) then raise exception 'Istenen miktar mevcut stoktan fazla.'; end if;

  select w.*, c.map_position_x as city_x, c.map_position_y as city_y
  into v_buyer_warehouse
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id and w.player_id = v_player_id;
  if not found then raise exception 'Hedef depo bulunamadi veya size ait degil.'; end if;
  if v_buyer_warehouse.is_active is not true then raise exception 'Hedef depo aktif degil.'; end if;

  select * into v_product from public.products where id = v_store_slot.product_id;
  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then raise exception 'Urun hacim bilgisi gecersiz.'; end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_store_slot.city_x - v_buyer_warehouse.city_x) / 2)), 2)
      + cos(radians(v_buyer_warehouse.city_x)) * cos(radians(v_store_slot.city_x))
      * power(sin(radians((v_store_slot.city_y - v_buyer_warehouse.city_y) / 2)), 2)
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
    where lv.player_id = v_player_id or (lv.player_id <> v_player_id and lv.is_available_for_rent = true)
  ), real_options as (
    select
      c.vehicle_id, c.vehicle_owner_player_id, c.vehicle_name, c.is_rental, c.capacity, c.speed_kmh,
      c.current_fuel, c.fuel_capacity, c.fuel_rate, c.condition, c.rental_price, c.distance_km,
      c.fuel_needed, c.condition_needed, c.rental_cost, c.estimated_duration_seconds,
      (
        c.route_matches = true and c.status = 'idle' and c.company_is_active = true and c.capacity >= v_required_capacity
        and c.current_fuel >= c.fuel_needed and c.condition > c.condition_needed
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
  )
  select * from real_options
  union all
  select * from public.get_npc_rental_vehicle_option(v_store_slot.store_city_id, v_buyer_warehouse.city_id, v_distance_km)
  where not exists (select 1 from real_options ro where ro.can_select)
  order by 4 asc, 17 desc, 5 asc, 11 asc, 3 asc;
end;
$$;


ALTER FUNCTION "public"."get_store_to_warehouse_vehicle_options"("p_store_slot_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_store_transfer_vehicle_options"("p_store_slot_id" "uuid", "p_warehouse_slot_id" "uuid", "p_quantity" integer) RETURNS TABLE("vehicle_id" "uuid", "vehicle_owner_player_id" "uuid", "vehicle_name" "text", "is_rental" boolean, "capacity" integer, "speed_kmh" integer, "current_fuel" integer, "fuel_capacity" integer, "fuel_rate" numeric, "condition" integer, "rental_price" numeric, "distance_km" numeric, "fuel_needed" numeric, "condition_needed" numeric, "rental_cost" numeric, "estimated_duration_seconds" integer, "can_select" boolean, "disabled_reason" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player_id uuid := auth.uid();
  v_store_slot record;
  v_warehouse_slot record;
  v_product record;
  v_required_capacity numeric := 0;
  v_distance_km numeric := 0;
begin
  if v_player_id is null then raise exception 'Oturum acilmamis.'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Miktar 0''dan buyuk olmalidir.'; end if;

  select ss.*, s.player_id, s.is_active as store_is_active, s.city_id as store_city_id, c.map_position_x as city_x, c.map_position_y as city_y
  into v_store_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  join public.cities c on c.id = s.city_id
  where ss.id = p_store_slot_id;
  if not found or v_store_slot.player_id <> v_player_id then raise exception 'Magaza slotu bulunamadi veya size ait degil.'; end if;
  if v_store_slot.store_is_active is not true then raise exception 'Magaza aktif degil.'; end if;

  select ws.*, w.player_id as warehouse_player_id, w.city_id as warehouse_city_id, c.map_position_x as city_x, c.map_position_y as city_y
  into v_warehouse_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  join public.cities c on c.id = w.city_id
  where ws.id = p_warehouse_slot_id;
  if not found or v_warehouse_slot.warehouse_player_id <> v_player_id then raise exception 'Depo slotu bulunamadi veya size ait degil.'; end if;
  if p_quantity > v_warehouse_slot.quantity then raise exception 'Istenen miktar mevcut stoktan fazla.'; end if;
  if v_store_slot.product_id is not null and v_store_slot.quality_level > 0 and (
    v_store_slot.product_id <> v_warehouse_slot.product_id or v_store_slot.quality_level <> v_warehouse_slot.quality_level
  ) and (v_store_slot.quantity > 0 or coalesce(v_store_slot.pending_quantity, 0) > 0) then raise exception 'Slotta farkli urun veya kalite icin aktif stok/rezerve var.'; end if;
  if (coalesce(v_store_slot.quantity, 0) + coalesce(v_store_slot.pending_quantity, 0) + p_quantity) > v_store_slot.capacity then raise exception 'Magaza slot kapasitesi yetersiz.'; end if;

  select * into v_product from public.products where id = v_warehouse_slot.product_id;
  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then raise exception 'Urun hacim bilgisi gecersiz.'; end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_warehouse_slot.city_x - v_store_slot.city_x) / 2)), 2)
      + cos(radians(v_store_slot.city_x)) * cos(radians(v_warehouse_slot.city_x))
      * power(sin(radians((v_warehouse_slot.city_y - v_store_slot.city_y) / 2)), 2)
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
    where lv.player_id = v_player_id or (lv.player_id <> v_player_id and lv.is_available_for_rent = true)
  ), real_options as (
    select
      c.vehicle_id, c.vehicle_owner_player_id, c.vehicle_name, c.is_rental, c.capacity, c.speed_kmh,
      c.current_fuel, c.fuel_capacity, c.fuel_rate, c.condition, c.rental_price, c.distance_km,
      c.fuel_needed, c.condition_needed, c.rental_cost, c.estimated_duration_seconds,
      (
        c.route_matches = true and c.status = 'idle' and c.company_is_active = true and c.capacity >= v_required_capacity
        and c.current_fuel >= c.fuel_needed and c.condition > c.condition_needed
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
  )
  select * from real_options
  union all
  select * from public.get_npc_rental_vehicle_option(v_warehouse_slot.warehouse_city_id, v_store_slot.store_city_id, v_distance_km)
  where not exists (select 1 from real_options ro where ro.can_select)
  order by 4 asc, 17 desc, 5 asc, 11 asc, 3 asc;
end;
$$;


ALTER FUNCTION "public"."get_store_transfer_vehicle_options"("p_store_slot_id" "uuid", "p_warehouse_slot_id" "uuid", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_store_types_catalog"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    jsonb_agg(to_jsonb(st) order by st.required_level, st.cost),
    '[]'::jsonb
  )
  from public.store_types st;
$$;


ALTER FUNCTION "public"."get_store_types_catalog"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_stores_list"("p_player_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
          'current_slot_count', s.current_slot_count,
          'max_slot_count', s.max_slot_count,
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
            end,
            'pending_sale_total', coalesce(slot_summary.pending_sale_total, 0),
            'total_stock_cost_value', coalesce(slot_summary.total_stock_cost_value, 0),
            'total_stock_sale_value', coalesce(slot_summary.total_stock_sale_value, 0)
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
      coalesce(sum(ss.pending_sale), 0) as pending_sale_total,
      coalesce(sum(ss.quantity * ss.cost), 0) as total_stock_cost_value,
      coalesce(sum(ss.quantity * ss.price), 0) as total_stock_sale_value,
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
            'price', ss.price,
            'cost', ss.cost,
            'pending_sale', ss.pending_sale,
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
$$;


ALTER FUNCTION "public"."get_stores_list"("p_player_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_total_experience_for_level"("p_level" integer) RETURNS integer
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
begin
  if coalesce(p_level, 1) <= 1 then
    return 0;
  end if;

  return greatest(0, 125 * (p_level - 1) * p_level);
end;
$$;


ALTER FUNCTION "public"."get_total_experience_for_level"("p_level" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_transfer_affected_targets"("p_transfer_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_transfer record;
  v_inventory record;
  v_warehouse_ids uuid[] := '{}';
  v_store_ids uuid[] := '{}';
  v_factory_ids uuid[] := '{}';
  v_farm_ids uuid[] := '{}';
  v_field_ids uuid[] := '{}';
  v_mine_ids uuid[] := '{}';
begin
  select
    seller_warehouse_id,
    buyer_warehouse_id,
    seller_store_id,
    buyer_store_id,
    seller_production_inventory_id,
    buyer_production_inventory_id
  into v_transfer
  from public.logistics_transfers
  where id = p_transfer_id;

  if not found then
    return jsonb_build_object(
      'warehouse_ids', jsonb_build_array(),
      'store_ids', jsonb_build_array(),
      'factory_ids', jsonb_build_array(),
      'farm_ids', jsonb_build_array(),
      'field_ids', jsonb_build_array(),
      'mine_ids', jsonb_build_array()
    );
  end if;

  if v_transfer.seller_warehouse_id is not null then
    v_warehouse_ids := array_append(v_warehouse_ids, v_transfer.seller_warehouse_id);
  end if;
  if v_transfer.buyer_warehouse_id is not null
     and not (v_transfer.buyer_warehouse_id = any(v_warehouse_ids)) then
    v_warehouse_ids := array_append(v_warehouse_ids, v_transfer.buyer_warehouse_id);
  end if;

  if v_transfer.seller_store_id is not null then
    v_store_ids := array_append(v_store_ids, v_transfer.seller_store_id);
  end if;
  if v_transfer.buyer_store_id is not null
     and not (v_transfer.buyer_store_id = any(v_store_ids)) then
    v_store_ids := array_append(v_store_ids, v_transfer.buyer_store_id);
  end if;

  for v_inventory in
    select owner_kind, owner_id
    from public.production_inventory
    where id in (
      v_transfer.seller_production_inventory_id,
      v_transfer.buyer_production_inventory_id
    )
  loop
    case v_inventory.owner_kind
      when 'factory' then
        if not (v_inventory.owner_id = any(v_factory_ids)) then
          v_factory_ids := array_append(v_factory_ids, v_inventory.owner_id);
        end if;
      when 'farm' then
        if not (v_inventory.owner_id = any(v_farm_ids)) then
          v_farm_ids := array_append(v_farm_ids, v_inventory.owner_id);
        end if;
      when 'field' then
        if not (v_inventory.owner_id = any(v_field_ids)) then
          v_field_ids := array_append(v_field_ids, v_inventory.owner_id);
        end if;
      when 'mine' then
        if not (v_inventory.owner_id = any(v_mine_ids)) then
          v_mine_ids := array_append(v_mine_ids, v_inventory.owner_id);
        end if;
    end case;
  end loop;

  return jsonb_build_object(
    'warehouse_ids', to_jsonb(v_warehouse_ids),
    'store_ids', to_jsonb(v_store_ids),
    'factory_ids', to_jsonb(v_factory_ids),
    'farm_ids', to_jsonb(v_farm_ids),
    'field_ids', to_jsonb(v_field_ids),
    'mine_ids', to_jsonb(v_mine_ids)
  );
end;
$$;


ALTER FUNCTION "public"."get_transfer_affected_targets"("p_transfer_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_transfer_vehicle_options"("p_source_kind" "text", "p_source_id" "uuid", "p_target_kind" "text", "p_target_id" "uuid", "p_quantity" integer) RETURNS TABLE("vehicle_id" "uuid", "vehicle_owner_player_id" "uuid", "vehicle_name" "text", "is_rental" boolean, "capacity" integer, "speed_kmh" integer, "current_fuel" integer, "fuel_capacity" integer, "fuel_rate" numeric, "condition" integer, "rental_price" numeric, "distance_km" numeric, "fuel_needed" numeric, "condition_needed" numeric, "rental_cost" numeric, "estimated_duration_seconds" integer, "can_select" boolean, "disabled_reason" "text", "fuel_cost" numeric, "total_price" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player_id uuid := auth.uid();
  v_source_city_id uuid;
  v_source_city_x numeric;
  v_source_city_y numeric;
  v_target_city_id uuid;
  v_target_city_x numeric;
  v_target_city_y numeric;
  v_source_product_id text;
  v_source_quality_level integer;
  v_required_capacity numeric := 0;
  v_distance_km numeric := 0;
  v_available_target_capacity numeric := 0;
  v_check_target_capacity boolean := false;
  v_excluded_vehicle_owner_player_id uuid;
  v_source_warehouse_id uuid;
  v_owner_player_id uuid;
  v_owner_city_id uuid;
  v_product record;
  v_warehouse_slot record;
  v_store_slot record;
  v_warehouse record;
  v_inventory record;
  v_city record;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  case p_source_kind
    when 'market_slot' then
      select
        ws.*,
        w.player_id as seller_player_id,
        w.city_id as seller_city_id,
        c.map_position_x as city_x,
        c.map_position_y as city_y
      into v_warehouse_slot
      from public.warehouse_slots ws
      join public.warehouses w on w.id = ws.warehouse_id
      join public.cities c on c.id = w.city_id
      where ws.id = p_source_id
        and ws.is_available_for_sale = true;

      if not found then
        raise exception 'Satici slotu bulunamadi.';
      end if;

      if v_warehouse_slot.seller_player_id = v_player_id then
        raise exception 'Kendi ilaninizi satin alamazsiniz.';
      end if;

      if p_quantity > coalesce(v_warehouse_slot.quantity, 0) then
        raise exception 'Istenen miktar mevcut stoktan fazla.';
      end if;

      v_source_city_id := v_warehouse_slot.seller_city_id;
      v_source_city_x := v_warehouse_slot.city_x;
      v_source_city_y := v_warehouse_slot.city_y;
      v_source_product_id := v_warehouse_slot.product_id;
      v_source_quality_level := coalesce(v_warehouse_slot.quality_level, 0);
      v_excluded_vehicle_owner_player_id := v_warehouse_slot.seller_player_id;

    when 'warehouse_slot' then
      select
        ws.*,
        w.player_id,
        w.id as warehouse_id,
        w.city_id as warehouse_city_id,
        w.is_active as warehouse_is_active,
        c.map_position_x as city_x,
        c.map_position_y as city_y
      into v_warehouse_slot
      from public.warehouse_slots ws
      join public.warehouses w on w.id = ws.warehouse_id
      join public.cities c on c.id = w.city_id
      where ws.id = p_source_id;

      if not found or v_warehouse_slot.player_id <> v_player_id then
        raise exception 'Depo slotu bulunamadi veya size ait degil.';
      end if;

      if p_quantity > coalesce(v_warehouse_slot.quantity, 0) then
        raise exception 'Istenen miktar mevcut stoktan fazla.';
      end if;

      v_source_city_id := v_warehouse_slot.warehouse_city_id;
      v_source_city_x := v_warehouse_slot.city_x;
      v_source_city_y := v_warehouse_slot.city_y;
      v_source_product_id := v_warehouse_slot.product_id;
      v_source_quality_level := coalesce(v_warehouse_slot.quality_level, 0);
      v_source_warehouse_id := v_warehouse_slot.warehouse_id;

    when 'store_slot' then
      select
        ss.*,
        s.player_id,
        s.is_active as store_is_active,
        s.city_id as store_city_id,
        c.map_position_x as city_x,
        c.map_position_y as city_y
      into v_store_slot
      from public.store_slots ss
      join public.stores s on s.id = ss.store_id
      join public.cities c on c.id = s.city_id
      where ss.id = p_source_id;

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

      v_source_city_id := v_store_slot.store_city_id;
      v_source_city_x := v_store_slot.city_x;
      v_source_city_y := v_store_slot.city_y;
      v_source_product_id := v_store_slot.product_id;
      v_source_quality_level := coalesce(v_store_slot.quality_level, 0);

    when 'production_inventory' then
      if p_target_kind <> 'warehouse' then
        raise exception 'Production inventory kaynagi sadece depoya transfer icin desteklenir.';
      end if;

      select *
      into v_inventory
      from public.production_inventory
      where id = p_source_id;

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

      select * into v_city
      from public.cities
      where id = v_owner_city_id;

      if not found then
        raise exception 'Kaynak sehir bulunamadi.';
      end if;

      v_source_city_id := v_owner_city_id;
      v_source_city_x := v_city.map_position_x;
      v_source_city_y := v_city.map_position_y;
      v_source_product_id := v_inventory.product_id;
      v_source_quality_level := coalesce(v_inventory.quality_level, 0);

    else
      raise exception 'Desteklenmeyen kaynak tipi: %', p_source_kind;
  end case;

  case p_target_kind
    when 'warehouse' then
      select
        w.*,
        c.map_position_x as city_x,
        c.map_position_y as city_y
      into v_warehouse
      from public.warehouses w
      join public.cities c on c.id = w.city_id
      where w.id = p_target_id
        and w.player_id = v_player_id;

      if not found then
        raise exception 'Hedef depo bulunamadi veya size ait degil.';
      end if;

      if v_warehouse.is_active is not true then
        raise exception 'Hedef depo aktif degil.';
      end if;

      if p_source_kind = 'warehouse_slot' and v_warehouse.id = v_source_warehouse_id then
        raise exception 'Kaynak ve hedef depo ayni olamaz.';
      end if;

      v_target_city_id := v_warehouse.city_id;
      v_target_city_x := v_warehouse.city_x;
      v_target_city_y := v_warehouse.city_y;
      v_check_target_capacity := p_source_kind = any (
        array['market_slot', 'warehouse_slot']
      );

    when 'store_slot' then
      if p_source_kind not in ('market_slot', 'warehouse_slot') then
        raise exception 'Hedef magaza slotu bu transfer tipi icin desteklenmiyor.';
      end if;

      select
        ss.*,
        s.player_id,
        s.is_active as store_is_active,
        s.city_id as store_city_id,
        c.map_position_x as city_x,
        c.map_position_y as city_y
      into v_store_slot
      from public.store_slots ss
      join public.stores s on s.id = ss.store_id
      join public.cities c on c.id = s.city_id
      where ss.id = p_target_id;

      if not found or v_store_slot.player_id <> v_player_id then
        raise exception 'Magaza slotu bulunamadi veya size ait degil.';
      end if;

      if v_store_slot.store_is_active is not true then
        raise exception 'Magaza aktif degil.';
      end if;

      if v_store_slot.product_id is not null
         and v_store_slot.quality_level > 0
         and (
           v_store_slot.product_id <> v_source_product_id
           or v_store_slot.quality_level <> v_source_quality_level
         )
         and (
           coalesce(v_store_slot.quantity, 0) > 0
           or coalesce(v_store_slot.pending_quantity, 0) > 0
         ) then
        raise exception 'Slotta farkli urun veya kalite icin aktif stok/rezerve var.';
      end if;

      if (
        coalesce(v_store_slot.quantity, 0)
        + coalesce(v_store_slot.pending_quantity, 0)
        + p_quantity
      ) > coalesce(v_store_slot.capacity, 0) then
        raise exception 'Magaza slot kapasitesi yetersiz.';
      end if;

      v_target_city_id := v_store_slot.store_city_id;
      v_target_city_x := v_store_slot.city_x;
      v_target_city_y := v_store_slot.city_y;

    when 'production_inventory' then
      if p_source_kind <> 'warehouse_slot' then
        raise exception 'Hedef production inventory bu transfer tipi icin desteklenmiyor.';
      end if;

      if coalesce(v_warehouse_slot.warehouse_is_active, false) is not true then
        raise exception 'Kaynak depo aktif degil.';
      end if;

      select *
      into v_inventory
      from public.production_inventory
      where id = p_target_id;

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

      if v_inventory.product_id <> v_source_product_id then
        raise exception 'Depo slotundaki urun ile input inventory urunu ayni olmalidir.';
      end if;

      if coalesce(v_inventory.quality_level, 0) <> v_source_quality_level then
        raise exception 'Depo slotundaki kalite ile input inventory kalitesi ayni olmalidir.';
      end if;

      select * into v_city
      from public.cities
      where id = v_owner_city_id;

      if not found then
        raise exception 'Hedef sehir bulunamadi.';
      end if;

      v_target_city_id := v_owner_city_id;
      v_target_city_x := v_city.map_position_x;
      v_target_city_y := v_city.map_position_y;

    else
      raise exception 'Desteklenmeyen hedef tipi: %', p_target_kind;
  end case;

  select *
  into v_product
  from public.products
  where id = v_source_product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;

  if v_check_target_capacity then
    select greatest(
      coalesce(v_warehouse.capacity, 0)::numeric
      - coalesce(sum(ws.quantity::numeric * coalesce(p.birim_hacim, 0)), 0)
      - coalesce(v_warehouse.reserved_capacity, 0)::numeric,
      0
    )
    into v_available_target_capacity
    from public.warehouse_slots ws
    left join public.products p on p.id = ws.product_id
    where ws.warehouse_id = v_warehouse.id;
  end if;

  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_source_city_x - v_target_city_x) / 2)), 2) +
      cos(radians(v_target_city_x)) *
      cos(radians(v_source_city_x)) *
      power(sin(radians((v_source_city_y - v_target_city_y) / 2)), 2)
    )
  );

  return query
  with candidates as (
    select
      lv.id as v_id,
      lv.player_id as v_owner_player_id,
      lvt.name as v_name,
      (lv.player_id <> v_player_id) as v_is_rental,
      lv.capacity as v_capacity,
      lv.speed_kmh as v_speed_kmh,
      lv.current_fuel as v_current_fuel,
      lv.fuel_capacity as v_fuel_capacity,
      lv.fuel_rate as v_fuel_rate,
      lv.condition as v_condition,
      lv.rental_price as v_rental_price,
      v_distance_km as v_distance_km_val,
      ceil(v_distance_km * lv.fuel_rate) as v_fuel_needed,
      ceil(v_distance_km * 0.02) as v_condition_needed,
      case
        when lv.player_id <> v_player_id then ceil(v_distance_km * lv.rental_price)
        else 0
      end as v_rental_cost,
      greatest(1, ceil(((v_distance_km / greatest(lv.speed_kmh, 1)) / 4.0) * 3600))::integer as v_estimated_duration_seconds,
      lv.status as v_status,
      lc.is_active as v_company_is_active,
      public.logistics_vehicle_matches_route(
        lv.route_city_a_id,
        lv.route_city_b_id,
        v_source_city_id,
        v_target_city_id
      ) as v_route_matches
    from public.logistics_vehicles lv
    join public.logistics_vehicle_types lvt on lvt.id = lv.logistics_vehicle_type_id
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where (
        lv.player_id = v_player_id
        or (lv.player_id <> v_player_id and lv.is_available_for_rent = true)
      )
      and (
        v_excluded_vehicle_owner_player_id is null
        or lv.player_id <> v_excluded_vehicle_owner_player_id
      )

    union all

    select
      '00000000-0000-0000-0000-000000000000'::uuid as v_id,
      '00000000-0000-0000-0000-000000000000'::uuid as v_owner_player_id,
      'Sistem Nakliye Araci' as v_name,
      true as v_is_rental,
      999999 as v_capacity,
      60 as v_speed_kmh,
      999999 as v_current_fuel,
      999999 as v_fuel_capacity,
      0::numeric as v_fuel_rate,
      100 as v_condition,
      5.0::numeric as v_rental_price,
      v_distance_km as v_distance_km_val,
      0::numeric as v_fuel_needed,
      0::numeric as v_condition_needed,
      ceil(v_distance_km * 5.0) as v_rental_cost,
      greatest(1, ceil(((v_distance_km / 60.0) / 4.0) * 3600))::integer as v_estimated_duration_seconds,
      'idle' as v_status,
      true as v_company_is_active,
      true as v_route_matches
  ),
  evaluated as (
    select
      c.v_id,
      c.v_owner_player_id,
      c.v_name,
      c.v_is_rental,
      c.v_capacity,
      c.v_speed_kmh,
      c.v_current_fuel,
      c.v_fuel_capacity,
      c.v_fuel_rate,
      c.v_condition,
      c.v_rental_price,
      c.v_distance_km_val,
      c.v_fuel_needed,
      c.v_condition_needed,
      c.v_rental_cost,
      c.v_estimated_duration_seconds,
      (
        c.v_route_matches = true
        and c.v_status = 'idle'
        and c.v_company_is_active = true
        and (v_check_target_capacity = false or v_available_target_capacity >= v_required_capacity)
        and c.v_capacity >= v_required_capacity
        and c.v_current_fuel >= c.v_fuel_needed
        and c.v_condition > c.v_condition_needed
      ) as v_can_select,
      case
        when c.v_route_matches is not true then 'Aracin rotasi bu sehir ciftini desteklemiyor.'
        when c.v_status <> 'idle' then 'Arac su anda uygun degil.'
        when c.v_company_is_active = false then 'Nakliye firmasi aktif degil.'
        when v_check_target_capacity = true and v_available_target_capacity < v_required_capacity then 'Hedef depoda bos kapasite yetersiz.'
        when c.v_capacity < v_required_capacity then 'Kapasite yetersiz.'
        when c.v_current_fuel < c.v_fuel_needed then 'Yakit yetersiz.'
        when c.v_condition <= c.v_condition_needed then 'Kondisyon yetersiz.'
        else null
      end as v_disabled_reason,
      0::numeric as v_fuel_cost,
      c.v_rental_cost as v_total_price
    from candidates c
  ),
  selectable_exists as (
    select exists(select 1 from evaluated e2 where e2.v_can_select = true) as has_selectable
  ),
  no_option_reason as (
    select
      case
        when v_check_target_capacity = true and v_available_target_capacity < v_required_capacity then 'Hedef depoda bos kapasite yetersiz.'
        when exists(select 1 from evaluated e2 where e2.v_disabled_reason = 'Hedef depoda bos kapasite yetersiz.') then 'Hedef depoda bos kapasite yetersiz.'
        when exists(select 1 from evaluated e2 where e2.v_disabled_reason = 'Kapasite yetersiz.') then 'Bu miktar icin yeterli kapasiteye sahip arac yok.'
        when exists(select 1 from evaluated e2 where e2.v_disabled_reason = 'Yakit yetersiz.') then 'Yeterli yakiti olan uygun arac yok.'
        when exists(select 1 from evaluated e2 where e2.v_disabled_reason = 'Kondisyon yetersiz.') then 'Kondisyonu yeterli uygun arac yok.'
        when exists(select 1 from evaluated e2 where e2.v_disabled_reason = 'Arac su anda uygun degil.') then 'Tum uygun araclar su anda mesgul veya kullanilamaz durumda.'
        when exists(select 1 from evaluated e2 where e2.v_disabled_reason = 'Nakliye firmasi aktif degil.') then 'Uygun araclarin bagli oldugu nakliye firmalari aktif degil.'
        when exists(select 1 from evaluated e2 where e2.v_disabled_reason = 'Aracin rotasi bu sehir ciftini desteklemiyor.') then 'Bu rota icin uygun arac yok.'
        else 'Bu transfer icin uygun veya kiralanabilir arac bulunamadi.'
      end as nr_disabled_reason
  ),
  final_res as (
      select
        e.v_id as out_vehicle_id,
        e.v_owner_player_id as out_vehicle_owner_player_id,
        e.v_name as out_vehicle_name,
        e.v_is_rental as out_is_rental,
        e.v_capacity as out_capacity,
        e.v_speed_kmh as out_speed_kmh,
        e.v_current_fuel as out_current_fuel,
        e.v_fuel_capacity as out_fuel_capacity,
        e.v_fuel_rate as out_fuel_rate,
        e.v_condition as out_condition,
        e.v_rental_price as out_rental_price,
        e.v_distance_km_val as out_distance_km,
        e.v_fuel_needed as out_fuel_needed,
        e.v_condition_needed as out_condition_needed,
        e.v_rental_cost as out_rental_cost,
        e.v_estimated_duration_seconds as out_estimated_duration_seconds,
        e.v_can_select as out_can_select,
        e.v_disabled_reason as out_disabled_reason,
        e.v_fuel_cost as out_fuel_cost,
        e.v_total_price as out_total_price
      from evaluated e
      where e.v_can_select = true

      union all

      select
        null::uuid as out_vehicle_id,
        null::uuid as out_vehicle_owner_player_id,
        null::text as out_vehicle_name,
        false as out_is_rental,
        0 as out_capacity,
        0 as out_speed_kmh,
        0 as out_current_fuel,
        0 as out_fuel_capacity,
        0::numeric as out_fuel_rate,
        0 as out_condition,
        0::numeric as out_rental_price,
        0::numeric as out_distance_km,
        0::numeric as out_fuel_needed,
        0::numeric as out_condition_needed,
        0::numeric as out_rental_cost,
        0 as out_estimated_duration_seconds,
        false as out_can_select,
        nr.nr_disabled_reason as out_disabled_reason,
        0::numeric as out_fuel_cost,
        0::numeric as out_total_price
      from no_option_reason nr
      where not (select has_selectable from selectable_exists)
  )
  select * from final_res fr
  order by fr.out_is_rental asc, fr.out_can_select desc, fr.out_capacity asc, fr.out_rental_price asc, fr.out_vehicle_name asc nulls last;
end;
$$;


ALTER FUNCTION "public"."get_transfer_vehicle_options"("p_source_kind" "text", "p_source_id" "uuid", "p_target_kind" "text", "p_target_id" "uuid", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_warehouse_capacity_status"("p_warehouse_id" "uuid") RETURNS TABLE("warehouse_id" "uuid", "total_capacity" numeric, "used_capacity" numeric, "reserved_capacity" numeric, "available_capacity" numeric)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."get_warehouse_capacity_status"("p_warehouse_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_warehouse_list_page_data"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with live_rows as (
    select
      w.id,
      w.created_at as sort_time,
      w.name as sort_name,
      false as is_under_construction,
      w.is_active,
      coalesce(w.capacity, 0) as total_capacity,
      jsonb_build_object(
        'id', w.id,
        'player_id', w.player_id,
        'warehouse_type_id', w.warehouse_type_id,
        'city_id', w.city_id,
        'name', w.name,
        'level', w.level,
        'capacity', w.capacity,
        'reserved_capacity', w.reserved_capacity,
        'is_active', w.is_active,
        'created_at', w.created_at,
        'updated_at', w.updated_at,
        'city', jsonb_build_object('name', c.name),
        'warehouse_type', jsonb_build_object(
          'id', wt.id,
          'name', wt.name,
          'icon', wt.icon,
          'base_capacity', wt.base_capacity,
          'cost', wt.cost,
          'required_level', wt.required_level,
          'construction_time_minutes', wt.construction_time_minutes
        ),
        'warehouse_slots', coalesce(slot_rows.slots, '[]'::jsonb),
        'is_under_construction', false
      ) as payload
    from public.warehouses w
    join public.cities c on c.id = w.city_id
    left join public.warehouse_types wt on wt.id = w.warehouse_type_id
    left join lateral (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id', ws.id,
            'product_id', ws.product_id,
            'product_name', p.urun_adi,
            'quantity', ws.quantity,
            'quality_level', ws.quality_level,
            'price', ws.price,
            'cost', ws.cost,
            'is_available_for_sale', ws.is_available_for_sale,
            'product', case
              when p.id is null then null
              else jsonb_build_object(
                'id', p.id,
                'urun_adi', p.urun_adi,
                'urun_iconu', p.urun_iconu,
                'birim_hacim', p.birim_hacim
              )
            end
          )
          order by ws.created_at
        ),
        '[]'::jsonb
      ) as slots
      from public.warehouse_slots ws
      left join public.products p on p.id = ws.product_id
      where ws.warehouse_id = w.id
    ) slot_rows on true
    where w.player_id = auth.uid()
  ),
  construction_rows as (
    select
      bc.id,
      bc.started_at as sort_time,
      coalesce(nullif(bc.params ->> 'name', ''), wt.name, 'Depo') as sort_name,
      true as is_under_construction,
      false as is_active,
      coalesce((bc.params ->> 'capacity')::numeric, 0) as total_capacity,
      jsonb_build_object(
        'id', bc.id,
        'player_id', bc.player_id,
        'warehouse_type_id', bc.params ->> 'warehouse_type_id',
        'city_id', bc.params ->> 'city_id',
        'name', coalesce(nullif(bc.params ->> 'name', ''), wt.name, 'Depo'),
        'level', coalesce((bc.params ->> 'level')::integer, 1),
        'capacity', coalesce((bc.params ->> 'capacity')::numeric, 0),
        'reserved_capacity', coalesce((bc.params ->> 'reserved_capacity')::numeric, 0),
        'is_active', false,
        'created_at', bc.started_at,
        'updated_at', bc.started_at,
        'city', jsonb_build_object('name', c.name),
        'warehouse_type', jsonb_build_object(
          'id', wt.id,
          'name', wt.name,
          'icon', wt.icon,
          'base_capacity', wt.base_capacity,
          'cost', wt.cost,
          'required_level', wt.required_level,
          'construction_time_minutes', wt.construction_time_minutes
        ),
        'warehouse_slots', '[]'::jsonb,
        'is_under_construction', true,
        'finish_at', bc.finish_at
      ) as payload
    from public.building_constructions bc
    left join public.warehouse_types wt
      on wt.id = nullif(bc.params ->> 'warehouse_type_id', '')::uuid
    left join public.cities c
      on c.id = nullif(bc.params ->> 'city_id', '')::uuid
    where bc.player_id = auth.uid()
      and bc.building_kind = 'warehouse'
      and bc.status = 'in_progress'
  ),
  combined as (
    select * from live_rows
    union all
    select * from construction_rows
  )
  select jsonb_build_object(
    'success', true,
    'warehouses', coalesce(
      (
        select jsonb_agg(payload order by sort_time asc, sort_name asc)
        from combined
      ),
      '[]'::jsonb
    ),
    'summary', jsonb_build_object(
      'total_count', coalesce((select count(*) from combined), 0),
      'active_count', coalesce((select count(*) from live_rows where is_active is true), 0),
      'construction_count', coalesce((select count(*) from construction_rows), 0),
      'total_capacity', coalesce((select sum(total_capacity) from live_rows), 0)
    )
  );
$$;


ALTER FUNCTION "public"."get_warehouse_list_page_data"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_warehouse_type_detail"("p_type_id" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select to_jsonb(wt)
  from public.warehouse_types wt
  where wt.id = p_type_id;
$$;


ALTER FUNCTION "public"."get_warehouse_type_detail"("p_type_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_warehouse_types_catalog"() RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce(
    jsonb_agg(to_jsonb(wt) order by wt.required_level, wt.cost),
    '[]'::jsonb
  )
  from public.warehouse_types wt;
$$;


ALTER FUNCTION "public"."get_warehouse_types_catalog"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."grant_player_experience"("p_player_id" "uuid", "p_amount" integer, "p_reason" "text", "p_meta" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player public.players%rowtype;
  v_old_experience integer;
  v_new_experience integer;
  v_old_level integer;
  v_new_level integer;
  v_remaining_amount integer;
  v_required_for_level integer;
  v_progress jsonb;
begin
  if p_player_id is null then
    raise exception 'Gecersiz oyuncu.';
  end if;

  if auth.uid() is not null and auth.uid() <> p_player_id then
    raise exception 'Yetkisiz istek.';
  end if;

  select *
  into v_player
  from public.players
  where id = p_player_id
  for update;

  if not found then
    raise exception 'Oyuncu bulunamadi.';
  end if;

  v_old_experience := greatest(coalesce(v_player.experience, 0), 0);
  v_old_level := greatest(coalesce(v_player.level, 1), 1);
  v_new_experience := v_old_experience;
  v_new_level := v_old_level;

  if coalesce(p_amount, 0) <= 0 then
    v_progress := public.build_level_progress_payload(v_old_level, v_old_experience);

    return jsonb_build_object(
      'success', true,
      'amount', 0,
      'reason', p_reason,
      'old_level', v_old_level,
      'new_level', v_old_level,
      'old_experience', v_old_experience,
      'new_experience', v_old_experience,
      'leveled_up', false,
      'progress', v_progress
    );
  end if;

  v_remaining_amount := p_amount;

  while v_remaining_amount > 0 loop
    v_required_for_level := public.get_experience_required_for_level(v_new_level);

    if v_new_experience + v_remaining_amount < v_required_for_level then
      v_new_experience := v_new_experience + v_remaining_amount;
      v_remaining_amount := 0;
    else
      v_remaining_amount := v_remaining_amount - greatest(v_required_for_level - v_new_experience, 0);
      v_new_level := v_new_level + 1;
      v_new_experience := 0;
    end if;
  end loop;

  update public.players
  set
    experience = v_new_experience,
    level = v_new_level
  where id = p_player_id;

  insert into public.player_experience_logs (
    player_id,
    reason,
    amount,
    old_level,
    new_level,
    old_experience,
    new_experience,
    meta
  )
  values (
    p_player_id,
    p_reason,
    p_amount,
    v_old_level,
    v_new_level,
    v_old_experience,
    v_new_experience,
    coalesce(p_meta, '{}'::jsonb)
  );

  v_progress := public.build_level_progress_payload(v_new_level, v_new_experience);

  return jsonb_build_object(
    'success', true,
    'amount', p_amount,
    'reason', p_reason,
    'old_level', v_old_level,
    'new_level', v_new_level,
    'old_experience', v_old_experience,
    'new_experience', v_new_experience,
    'leveled_up', v_new_level > v_old_level,
    'levels_gained', greatest(v_new_level - v_old_level, 0),
    'progress', v_progress
  );
end;
$$;


ALTER FUNCTION "public"."grant_player_experience"("p_player_id" "uuid", "p_amount" integer, "p_reason" "text", "p_meta" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_arge_research_mission_progress"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if tg_op = 'UPDATE'
     and new.status = 'completed'
     and coalesce(old.status, '') <> 'completed' then
    perform public.increment_player_mission_progress(new.player_id, 'arge_research_completed', 1);
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."handle_arge_research_mission_progress"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_building_construction_mission_progress"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if tg_op = 'UPDATE'
     and new.status = 'complete'
     and coalesce(old.status, '') <> 'complete' then
    perform public.increment_player_mission_progress(new.player_id, 'building_construction_completed', 1);
    perform public.increment_player_mission_progress(new.player_id, 'building_construction_completed_' || new.building_kind, 1);
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."handle_building_construction_mission_progress"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_building_upgrade_mission_progress"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if tg_op = 'UPDATE'
     and new.status = 'completed'
     and coalesce(old.status, '') <> 'completed' then
    perform public.increment_player_mission_progress(new.player_id, 'building_upgrade_completed', 1);
    perform public.increment_player_mission_progress(new.player_id, 'building_upgrade_completed_' || new.building_kind, 1);
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."handle_building_upgrade_mission_progress"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_logistics_transfer_mission_progress"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player_id uuid;
begin
  if tg_op = 'UPDATE'
     and new.status = 'completed'
     and coalesce(old.status, '') <> 'completed' then
    v_player_id := coalesce(new.buyer_player_id, new.seller_player_id);
    if v_player_id is not null then
      perform public.increment_player_mission_progress(v_player_id, 'logistics_transfer_completed', 1);
      perform public.increment_player_mission_progress(v_player_id, 'logistics_transfer_completed_' || coalesce(new.transfer_type, 'unknown'), 1);
    end if;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."handle_logistics_transfer_mission_progress"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_store_sales_mission_progress"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_delta integer := 0;
begin
  if tg_op = 'INSERT' then
    v_delta := coalesce(new.sold_quantity, 0);
  elsif tg_op = 'UPDATE' then
    v_delta := greatest(coalesce(new.sold_quantity, 0) - coalesce(old.sold_quantity, 0), 0);
  end if;

  if v_delta > 0 then
    perform public.increment_player_mission_progress(new.player_id, 'store_sale_completed', v_delta);
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."handle_store_sales_mission_progress"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_player_mission_progress"("p_player_id" "uuid", "p_event_key" "text", "p_amount" integer DEFAULT 1, "p_meta" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_now timestamptz := timezone('utc', now());
begin
  if p_player_id is null or coalesce(p_event_key, '') = '' or coalesce(p_amount, 0) <= 0 then
    return;
  end if;

  perform public.ensure_player_mission_rows(p_player_id);

  update public.player_missions pm
  set
    progress_count = least(md.target_count, pm.progress_count + p_amount),
    is_completed = (pm.progress_count + p_amount) >= md.target_count,
    completed_at = case
      when (pm.progress_count + p_amount) >= md.target_count and pm.completed_at is null then v_now
      else pm.completed_at
    end,
    last_progress_at = v_now,
    updated_at = v_now
  from public.mission_definitions md
  where pm.player_id = p_player_id
    and pm.mission_id = md.id
    and md.is_active = true
    and md.event_key = p_event_key
    and pm.is_claimed = false
    and pm.is_completed = false;
end;
$$;


ALTER FUNCTION "public"."increment_player_mission_progress"("p_player_id" "uuid", "p_event_key" "text", "p_amount" integer, "p_meta" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."logistics_vehicle_matches_route"("p_route_city_a_id" "uuid", "p_route_city_b_id" "uuid", "p_from_city_id" "uuid", "p_to_city_id" "uuid") RETURNS boolean
    LANGUAGE "sql" IMMUTABLE
    AS $$
  select
    p_route_city_a_id is not null
    and p_route_city_b_id is not null
    and (
      (p_route_city_a_id = p_from_city_id and p_route_city_b_id = p_to_city_id)
      or
      (p_route_city_a_id = p_to_city_id and p_route_city_b_id = p_from_city_id)
    );
$$;


ALTER FUNCTION "public"."logistics_vehicle_matches_route"("p_route_city_a_id" "uuid", "p_route_city_b_id" "uuid", "p_from_city_id" "uuid", "p_to_city_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."now_turkey"() RETURNS timestamp without time zone
    LANGUAGE "sql" STABLE
    AS $$
  select timezone('Europe/Istanbul', now());
$$;


ALTER FUNCTION "public"."now_turkey"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."open_store_detail_page"("p_store_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player_id uuid := auth.uid();
  v_store stores%rowtype;
  v_store_json jsonb;
  v_sale_result jsonb;
  v_active_boost jsonb;
  v_active_upgrade jsonb;
  v_player jsonb;
  v_has_expired_upgrade boolean := false;
  v_processed boolean := false;
  v_completed_boost_count integer := 0;
  v_total_revenue numeric := 0;
  v_total_profit numeric := 0;
  v_total_sold_quantity integer := 0;
  v_elapsed_minutes_max integer := 0;
  v_items jsonb := '[]'::jsonb;
  v_now timestamptz := now();
  v_slot record;
  v_elapsed_minutes numeric;
  v_boost_bonus_minutes numeric;
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
  v_exp_result jsonb := null;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  select *
  into v_store
  from public.stores
  where id = p_store_id
    and player_id = v_player_id
  for update;

  if not found then
    return jsonb_build_object(
      'success', false,
      'message', 'Magaza bulunamadi veya oyuncuya ait degil.'
    );
  end if;

  select exists (
    select 1
    from public.building_upgrades bu
    where bu.player_id = v_player_id
      and bu.building_kind = 'store'
      and bu.entity_id = p_store_id
      and bu.status = 'in_progress'
      and bu.finish_at <= timezone('utc'::text, now())
  )
  into v_has_expired_upgrade;

  if v_has_expired_upgrade then
    perform public.complete_due_building_upgrades(100);

    select *
    into v_store
    from public.stores
    where id = p_store_id
      and player_id = v_player_id
    for update;
  end if;

  if coalesce(v_store.is_active, false) = false then
    v_sale_result := jsonb_build_object(
      'success', true,
      'processed', false,
      'message', 'Magaza aktif degil.',
      'completed_boost_count', 0
    );
  else
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
      from public.store_slots ss
      join public.products p on p.id = ss.product_id
      where ss.store_id = p_store_id
        and ss.is_active = true
        and ss.product_id is not null
        and ss.quality_level between 1 and 5
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

      if coalesce(v_slot.price, 0) <= 0 then
        update public.store_slots
        set
          pending_sale = 0,
          last_sale_processed_at = v_now,
          updated_at = v_now
        where id = v_slot.id;

        continue;
      end if;

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

      select coalesce(
        sum(
          greatest(
            extract(
              epoch from least(coalesce(bb.finish_at, v_now), v_now)
              - greatest(bb.started_at, v_slot.last_sale_processed_at)
            ) / 60.0,
            0
          ) * greatest(coalesce(bb.multiplier, 1) - 1, 0)
        ),
        0
      )
      into v_boost_bonus_minutes
      from public.building_boosts bb
      where bb.player_id = v_player_id
        and bb.building_kind = 'store'
        and bb.entity_id = p_store_id
        and bb.started_at < v_now
        and coalesce(bb.finish_at, v_now) > v_slot.last_sale_processed_at;

      v_generated_demand := v_base_demand
        * greatest(
            0,
            (v_elapsed_minutes + coalesce(v_boost_bonus_minutes, 0))
            / greatest(v_elapsed_minutes, 1)
          )
        * v_quality_multiplier
        * v_price_multiplier;

      if coalesce(v_slot.quantity, 0) <= 0 then
        update public.store_slots
        set
          pending_sale = 0,
          last_sale_processed_at = v_now,
          updated_at = v_now
        where id = v_slot.id;

        continue;
      end if;

      v_available_demand := greatest(0, coalesce(v_slot.pending_sale, 0) + v_generated_demand);
      v_sold_qty := least(coalesce(v_slot.quantity, 0), floor(v_available_demand)::int);
      v_revenue := v_sold_qty * coalesce(v_slot.price, 0);
      v_profit := v_sold_qty * (coalesce(v_slot.price, 0) - coalesce(v_slot.cost, 0));
      v_pending_after := greatest(0, v_available_demand - v_sold_qty);

      update public.store_slots
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
          v_player_id,
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

    with due_boosts as (
      update public.building_boosts
      set
        status = 'completed',
        completed_at = coalesce(completed_at, v_now),
        updated_at = v_now
      where player_id = v_player_id
        and building_kind = 'store'
        and entity_id = p_store_id
        and status = 'in_progress'
        and finish_at <= v_now
      returning id
    ), reset_slots as (
      update public.store_slots
      set
        boost_multiplier = 1.00,
        updated_at = v_now
      where store_id = p_store_id
        and exists (select 1 from due_boosts)
      returning id
    )
    select count(*) into v_completed_boost_count
    from due_boosts;

    if v_total_sold_quantity > 0 or v_total_profit > 0 then
      v_exp_result := public.grant_player_experience(
        v_player_id,
        public.calculate_experience_reward(
          'store_sales_processed',
          jsonb_build_object(
            'sold_quantity', v_total_sold_quantity,
            'profit', v_total_profit
          )
        ),
        'store_sales_processed',
        jsonb_build_object(
          'store_id', p_store_id,
          'sold_quantity', v_total_sold_quantity,
          'total_revenue', round(v_total_revenue, 2),
          'total_profit', round(v_total_profit, 2),
          'elapsed_minutes', v_elapsed_minutes_max
        )
      );
    end if;

    if v_processed = false then
      v_sale_result := jsonb_build_object(
        'success', true,
        'processed', false,
        'message', 'Satis hesabi icin henuz 10 dakika gecmedi.',
        'completed_boost_count', v_completed_boost_count
      );
    else
      v_sale_result := jsonb_build_object(
        'success', true,
        'processed', true,
        'message', 'Satislar hesaplandi.',
        'processed_at', v_now,
        'elapsed_minutes', v_elapsed_minutes_max,
        'total_revenue', round(v_total_revenue, 2),
        'total_profit', round(v_total_profit, 2),
        'total_sold_quantity', v_total_sold_quantity,
        'completed_boost_count', v_completed_boost_count,
        'experience', v_exp_result,
        'items', v_items
      );
    end if;
  end if;

  select jsonb_build_object(
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
      'icon', st.icon,
      'cost', st.cost,
      'required_level', st.required_level,
      'construction_time_minutes', st.construction_time_minutes
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
  into v_store_json
  from public.stores s
  join public.cities c on c.id = s.city_id
  join public.store_types st on st.id = s.store_type_id
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
    from public.store_slots ss
    left join public.products p on p.id = ss.product_id
    where ss.store_id = s.id
  ) slot_data on true
  where s.player_id = v_player_id
    and s.id = p_store_id;

  v_active_boost := public.get_player_active_building_boost('store', p_store_id);
  v_active_upgrade := public.get_player_active_building_upgrade('store', p_store_id);
  v_player := public.get_player_profile(v_player_id);

  return jsonb_build_object(
    'success', true,
    'store', v_store_json,
    'active_boost', v_active_boost,
    'active_upgrade', v_active_upgrade,
    'sale_result', v_sale_result,
    'changed', jsonb_build_object(
      'player', v_player,
      'history_dirty', coalesce((v_sale_result ->> 'processed')::boolean, false),
      'performance_dirty',
        coalesce((v_sale_result ->> 'processed')::boolean, false)
        or coalesce((v_sale_result ->> 'completed_boost_count')::integer, 0) > 0
    )
  );
end;
$$;


ALTER FUNCTION "public"."open_store_detail_page"("p_store_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_factory_production_entry"("p_player_id" "uuid" DEFAULT "auth"."uid"(), "p_factory_id" "uuid" DEFAULT NULL::"uuid", "p_tick_minutes" integer DEFAULT 10, "p_max_ticks" integer DEFAULT 144) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_now timestamptz := timezone('utc'::text, now());
  v_processed_count integer := 0;
  v_produced_count integer := 0;
  v_pending_only_count integer := 0;
  v_skipped_count integer := 0;
  v_total_produced integer := 0;
  v_ticks integer;
  v_processed_until timestamptz;
  v_rate_per_tick numeric;
  v_raw_output numeric;
  v_whole_output integer;
  v_available_output_capacity integer;
  v_output_to_produce integer;
  v_pending_after numeric;
  v_h1_required integer;
  v_h2_required integer;
  v_h3_required integer;
  v_h1_quantity integer;
  v_h2_quantity integer;
  v_h3_quantity integer;
  v_h1_cost numeric;
  v_h2_cost numeric;
  v_h3_cost numeric;
  v_total_input_cost numeric;
  v_output_cost_after numeric;
  v_output_quantity_after integer;
  v_boost_bonus_minutes numeric;
  v_effective_ticks numeric;
  v_row record;
begin
  if p_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  perform pg_advisory_xact_lock(hashtext('factory_production_entry:' || p_player_id::text));

  for v_row in
    select
      f.id as factory_id,
      f.product_id,
      f.quality_level,
      f.output_capacity,
      f.last_production_at,
      p.uretim_adedi,
      nullif(p.hammadde_1_id, '') as h1_id,
      coalesce(p.hammadde_1_miktar, 0) as h1_per_unit,
      nullif(p.hammadde_2_id, '') as h2_id,
      coalesce(p.hammadde_2_miktar, 0) as h2_per_unit,
      nullif(p.hammadde_3_id, '') as h3_id,
      coalesce(p.hammadde_3_miktar, 0) as h3_per_unit,
      out_pi.id as output_inventory_id,
      out_pi.quantity as output_quantity,
      coalesce(out_pi.pending_quantity, 0) as output_pending_quantity,
      coalesce(out_pi.cost, 0) as output_cost
    from public.factories f
    join public.products p
      on p.id = f.product_id
    join public.production_inventory out_pi
      on out_pi.owner_kind = 'factory'
     and out_pi.owner_id = f.id
     and out_pi.inventory_type = 'output'
     and out_pi.product_id = f.product_id
     and out_pi.quality_level = f.quality_level
    where f.player_id = p_player_id
      and (p_factory_id is null or f.id = p_factory_id)
      and f.is_active = true
      and f.product_id is not null
      and f.quality_level between 1 and 5
      and coalesce(p.uretim_adedi, 0) > 0
    order by f.created_at, f.id
  loop
    v_ticks := floor(extract(epoch from (v_now - coalesce(v_row.last_production_at, v_now))) / greatest(p_tick_minutes * 60, 60))::integer;
    v_ticks := greatest(least(v_ticks, p_max_ticks), 0);

    if v_ticks <= 0 then
      continue;
    end if;

    v_processed_count := v_processed_count + 1;
    v_processed_until := coalesce(v_row.last_production_at, v_now) + make_interval(mins => p_tick_minutes * v_ticks);
    v_available_output_capacity := greatest(v_row.output_capacity - v_row.output_quantity, 0);

    if v_available_output_capacity <= 0 then
      update public.factories
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.factory_id;

      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;

    select coalesce(
      sum(
        greatest(
          extract(
            epoch from least(coalesce(bb.completed_at, bb.finish_at, v_processed_until), v_processed_until)
            - greatest(bb.started_at, v_row.last_production_at)
          ) / 60.0,
          0
        ) * greatest(coalesce(bb.multiplier, 1) - 1, 0)
      ),
      0
    )
    into v_boost_bonus_minutes
    from public.building_boosts bb
    where bb.player_id = p_player_id
      and bb.building_kind = 'factory'
      and bb.entity_id = v_row.factory_id
      and bb.started_at < v_processed_until
      and coalesce(bb.completed_at, bb.finish_at, v_processed_until) > v_row.last_production_at;

    v_effective_ticks := greatest(
      0,
      (
        (p_tick_minutes * v_ticks)::numeric + coalesce(v_boost_bonus_minutes, 0)
      ) / greatest(p_tick_minutes, 1)::numeric
    );

    v_rate_per_tick := coalesce(v_row.uretim_adedi, 0)::numeric / 6;
    v_raw_output := coalesce(v_row.output_pending_quantity, 0) + (v_rate_per_tick * v_effective_ticks);
    v_whole_output := floor(v_raw_output)::integer;

    if v_whole_output <= 0 then
      update public.production_inventory
      set pending_quantity = v_raw_output
      where id = v_row.output_inventory_id;

      update public.factories
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.factory_id;

      v_pending_only_count := v_pending_only_count + 1;
      continue;
    end if;

    v_output_to_produce := least(v_whole_output, v_available_output_capacity);

    if v_output_to_produce <= 0 then
      update public.factories
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.factory_id;

      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;

    v_h1_required := case when v_row.h1_id is not null and v_row.h1_per_unit > 0 then ceil(v_output_to_produce * v_row.h1_per_unit)::integer else 0 end;
    v_h2_required := case when v_row.h2_id is not null and v_row.h2_per_unit > 0 then ceil(v_output_to_produce * v_row.h2_per_unit)::integer else 0 end;
    v_h3_required := case when v_row.h3_id is not null and v_row.h3_per_unit > 0 then ceil(v_output_to_produce * v_row.h3_per_unit)::integer else 0 end;

    select coalesce(quantity, 0), coalesce(cost, 0)
    into v_h1_quantity, v_h1_cost
    from public.production_inventory
    where owner_kind = 'factory'
      and owner_id = v_row.factory_id
      and inventory_type = 'input'
      and product_id = v_row.h1_id
      and quality_level = v_row.quality_level
    for update;

    select coalesce(quantity, 0), coalesce(cost, 0)
    into v_h2_quantity, v_h2_cost
    from public.production_inventory
    where owner_kind = 'factory'
      and owner_id = v_row.factory_id
      and inventory_type = 'input'
      and product_id = v_row.h2_id
      and quality_level = v_row.quality_level
    for update;

    select coalesce(quantity, 0), coalesce(cost, 0)
    into v_h3_quantity, v_h3_cost
    from public.production_inventory
    where owner_kind = 'factory'
      and owner_id = v_row.factory_id
      and inventory_type = 'input'
      and product_id = v_row.h3_id
      and quality_level = v_row.quality_level
    for update;

    if (v_h1_required > 0 and coalesce(v_h1_quantity, 0) < v_h1_required)
       or (v_h2_required > 0 and coalesce(v_h2_quantity, 0) < v_h2_required)
       or (v_h3_required > 0 and coalesce(v_h3_quantity, 0) < v_h3_required) then
      update public.factories
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.factory_id;

      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;

    if v_h1_required > 0 then
      update public.production_inventory
      set quantity = quantity - v_h1_required
      where owner_kind = 'factory'
        and owner_id = v_row.factory_id
        and inventory_type = 'input'
        and product_id = v_row.h1_id
        and quality_level = v_row.quality_level;
    end if;

    if v_h2_required > 0 then
      update public.production_inventory
      set quantity = quantity - v_h2_required
      where owner_kind = 'factory'
        and owner_id = v_row.factory_id
        and inventory_type = 'input'
        and product_id = v_row.h2_id
        and quality_level = v_row.quality_level;
    end if;

    if v_h3_required > 0 then
      update public.production_inventory
      set quantity = quantity - v_h3_required
      where owner_kind = 'factory'
        and owner_id = v_row.factory_id
        and inventory_type = 'input'
        and product_id = v_row.h3_id
        and quality_level = v_row.quality_level;
    end if;

    v_total_input_cost := (v_h1_required * coalesce(v_h1_cost, 0))
      + (v_h2_required * coalesce(v_h2_cost, 0))
      + (v_h3_required * coalesce(v_h3_cost, 0));

    v_pending_after := case
      when v_output_to_produce < v_whole_output then 0
      else v_raw_output - v_whole_output
    end;

    v_output_quantity_after := v_row.output_quantity + v_output_to_produce;
    v_output_cost_after := case
      when v_output_quantity_after > 0 and v_output_to_produce > 0 then
        ((v_row.output_quantity * coalesce(v_row.output_cost, 0))
        + v_total_input_cost)
        / v_output_quantity_after
      else v_row.output_cost
    end;

    update public.production_inventory
    set quantity = v_output_quantity_after,
        pending_quantity = v_pending_after,
        cost = v_output_cost_after
    where id = v_row.output_inventory_id;

    update public.factories
    set last_production_at = v_processed_until,
        updated_at = timezone('utc'::text, now())
    where id = v_row.factory_id;

    v_produced_count := v_produced_count + 1;
    v_total_produced := v_total_produced + v_output_to_produce;
  end loop;

  return jsonb_build_object(
    'success', true,
    'processed_count', v_processed_count,
    'produced_count', v_produced_count,
    'pending_only_count', v_pending_only_count,
    'skipped_count', v_skipped_count,
    'total_produced', v_total_produced
  );
end;
$$;


ALTER FUNCTION "public"."process_factory_production_entry"("p_player_id" "uuid", "p_factory_id" "uuid", "p_tick_minutes" integer, "p_max_ticks" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_field_farm_production_entry"("p_player_id" "uuid" DEFAULT "auth"."uid"(), "p_owner_kind" "text" DEFAULT NULL::"text", "p_owner_id" "uuid" DEFAULT NULL::"uuid", "p_tick_minutes" integer DEFAULT 10, "p_max_ticks" integer DEFAULT 144) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_now timestamptz := timezone('utc'::text, now());
  v_processed_count integer := 0;
  v_produced_count integer := 0;
  v_pending_only_count integer := 0;
  v_skipped_count integer := 0;
  v_total_produced integer := 0;
  v_ticks integer;
  v_processed_until timestamptz;
  v_rate_per_tick numeric;
  v_raw_output numeric;
  v_whole_output integer;
  v_owner_total_output integer;
  v_available_output_capacity integer;
  v_tentative_output integer;
  v_actual_output integer;
  v_pending_after numeric;
  v_h1_max integer;
  v_h2_max integer;
  v_h3_max integer;
  v_h1_required integer;
  v_h2_required integer;
  v_h3_required integer;
  v_h1_cost numeric;
  v_h2_cost numeric;
  v_h3_cost numeric;
  v_total_input_cost numeric;
  v_total_production_cost numeric;
  v_output_cost_after numeric;
  v_output_quantity_after integer;
  v_boost_bonus_minutes numeric;
  v_effective_ticks numeric;
  v_row record;
begin
  if p_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  perform pg_advisory_xact_lock(hashtext('field_farm_production_entry:' || p_player_id::text));

  for v_row in
    select
      ps.id as production_slot_id,
      ps.owner_kind,
      ps.owner_id,
      ps.slot_index,
      ps.product_id,
      ps.quality_level,
      ps.last_production_at,
      case
        when ps.owner_kind = 'field' then f.output_capacity
        when ps.owner_kind = 'farm' then fa.output_capacity
      end as owner_output_capacity,
      p.uretim_adedi,
      nullif(p.hammadde_1_id, '') as h1_id,
      coalesce(p.hammadde_1_miktar, 0) as h1_per_unit,
      nullif(p.hammadde_2_id, '') as h2_id,
      coalesce(p.hammadde_2_miktar, 0) as h2_per_unit,
      nullif(p.hammadde_3_id, '') as h3_id,
      coalesce(p.hammadde_3_miktar, 0) as h3_per_unit,
      out_pi.id as output_inventory_id,
      out_pi.quantity as output_quantity,
      coalesce(out_pi.pending_quantity, 0) as output_pending_quantity,
      coalesce(out_pi.cost, 0) as output_cost
    from public.production_slots ps
    join public.products p on p.id = ps.product_id
    left join public.fields f on ps.owner_kind = 'field' and f.id = ps.owner_id
    left join public.farms fa on ps.owner_kind = 'farm' and fa.id = ps.owner_id
    join public.production_inventory out_pi
      on out_pi.owner_kind = ps.owner_kind
     and out_pi.owner_id = ps.owner_id
     and out_pi.inventory_type = 'output'
     and out_pi.product_id = ps.product_id
     and out_pi.quality_level = ps.quality_level
    where ps.is_active = true
      and ps.owner_kind in ('field', 'farm')
      and ps.product_id is not null
      and ps.quality_level between 1 and 5
      and coalesce(p.uretim_adedi, 0) > 0
      and (
        (ps.owner_kind = 'field' and f.player_id = p_player_id and f.is_active = true)
        or
        (ps.owner_kind = 'farm' and fa.player_id = p_player_id and fa.is_active = true)
      )
      and (p_owner_kind is null or ps.owner_kind = p_owner_kind)
      and (p_owner_id is null or ps.owner_id = p_owner_id)
    order by ps.owner_kind, ps.owner_id, ps.slot_index, ps.id
  loop
    v_ticks := floor(extract(epoch from (v_now - coalesce(v_row.last_production_at, v_now))) / greatest(p_tick_minutes * 60, 60))::integer;
    v_ticks := greatest(least(v_ticks, p_max_ticks), 0);

    if v_ticks <= 0 then
      continue;
    end if;

    v_processed_count := v_processed_count + 1;
    v_processed_until := coalesce(v_row.last_production_at, v_now) + make_interval(mins => p_tick_minutes * v_ticks);

    select coalesce(sum(quantity), 0)::integer
    into v_owner_total_output
    from public.production_inventory
    where owner_kind = v_row.owner_kind
      and owner_id = v_row.owner_id
      and inventory_type = 'output';

    v_available_output_capacity := greatest(coalesce(v_row.owner_output_capacity, 0) - coalesce(v_owner_total_output, 0), 0);

    if v_available_output_capacity <= 0 then
      update public.production_slots
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.production_slot_id;

      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;

    select coalesce(
      sum(
        greatest(
          extract(
            epoch from least(coalesce(bb.completed_at, bb.finish_at, v_processed_until), v_processed_until)
            - greatest(bb.started_at, v_row.last_production_at)
          ) / 60.0,
          0
        ) * greatest(coalesce(bb.multiplier, 1) - 1, 0)
      ),
      0
    )
    into v_boost_bonus_minutes
    from public.building_boosts bb
    where bb.player_id = p_player_id
      and bb.building_kind = v_row.owner_kind
      and bb.entity_id = v_row.owner_id
      and bb.started_at < v_processed_until
      and coalesce(bb.completed_at, bb.finish_at, v_processed_until) > v_row.last_production_at;

    v_effective_ticks := greatest(
      0,
      (
        (p_tick_minutes * v_ticks)::numeric + coalesce(v_boost_bonus_minutes, 0)
      ) / greatest(p_tick_minutes, 1)::numeric
    );

    v_rate_per_tick := coalesce(v_row.uretim_adedi, 0)::numeric / 6;
    v_raw_output := coalesce(v_row.output_pending_quantity, 0) + (v_rate_per_tick * v_effective_ticks);
    v_whole_output := floor(v_raw_output)::integer;

    if v_whole_output <= 0 then
      update public.production_inventory
      set pending_quantity = v_raw_output
      where id = v_row.output_inventory_id;

      update public.production_slots
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.production_slot_id;

      v_pending_only_count := v_pending_only_count + 1;
      continue;
    end if;

    v_tentative_output := least(v_whole_output, v_available_output_capacity);

    select coalesce(quantity, 0), coalesce(cost, 0)
    into v_h1_max, v_h1_cost
    from public.production_inventory
    where owner_kind = v_row.owner_kind
      and owner_id = v_row.owner_id
      and inventory_type = 'input'
      and product_id = v_row.h1_id
      and quality_level = 1
    for update;

    select coalesce(quantity, 0), coalesce(cost, 0)
    into v_h2_max, v_h2_cost
    from public.production_inventory
    where owner_kind = v_row.owner_kind
      and owner_id = v_row.owner_id
      and inventory_type = 'input'
      and product_id = v_row.h2_id
      and quality_level = 1
    for update;

    select coalesce(quantity, 0), coalesce(cost, 0)
    into v_h3_max, v_h3_cost
    from public.production_inventory
    where owner_kind = v_row.owner_kind
      and owner_id = v_row.owner_id
      and inventory_type = 'input'
      and product_id = v_row.h3_id
      and quality_level = 1
    for update;

    v_h1_max := case when v_row.h1_id is not null and v_row.h1_per_unit > 0 then floor(coalesce(v_h1_max, 0) / v_row.h1_per_unit)::integer else v_tentative_output end;
    v_h2_max := case when v_row.h2_id is not null and v_row.h2_per_unit > 0 then floor(coalesce(v_h2_max, 0) / v_row.h2_per_unit)::integer else v_tentative_output end;
    v_h3_max := case when v_row.h3_id is not null and v_row.h3_per_unit > 0 then floor(coalesce(v_h3_max, 0) / v_row.h3_per_unit)::integer else v_tentative_output end;

    v_actual_output := greatest(least(v_tentative_output, v_h1_max, v_h2_max, v_h3_max), 0);

    if v_actual_output <= 0 then
      update public.production_slots
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.production_slot_id;

      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;

    v_h1_required := case when v_row.h1_id is not null and v_row.h1_per_unit > 0 then ceil(v_actual_output * v_row.h1_per_unit)::integer else 0 end;
    v_h2_required := case when v_row.h2_id is not null and v_row.h2_per_unit > 0 then ceil(v_actual_output * v_row.h2_per_unit)::integer else 0 end;
    v_h3_required := case when v_row.h3_id is not null and v_row.h3_per_unit > 0 then ceil(v_actual_output * v_row.h3_per_unit)::integer else 0 end;

    if v_h1_required > 0 then
      update public.production_inventory
      set quantity = quantity - v_h1_required
      where owner_kind = v_row.owner_kind
        and owner_id = v_row.owner_id
        and inventory_type = 'input'
        and product_id = v_row.h1_id
        and quality_level = 1;
    end if;

    if v_h2_required > 0 then
      update public.production_inventory
      set quantity = quantity - v_h2_required
      where owner_kind = v_row.owner_kind
        and owner_id = v_row.owner_id
        and inventory_type = 'input'
        and product_id = v_row.h2_id
        and quality_level = 1;
    end if;

    if v_h3_required > 0 then
      update public.production_inventory
      set quantity = quantity - v_h3_required
      where owner_kind = v_row.owner_kind
        and owner_id = v_row.owner_id
        and inventory_type = 'input'
        and product_id = v_row.h3_id
        and quality_level = 1;
    end if;

    v_total_input_cost := (v_h1_required * coalesce(v_h1_cost, 0))
      + (v_h2_required * coalesce(v_h2_cost, 0))
      + (v_h3_required * coalesce(v_h3_cost, 0));
    v_total_production_cost := v_total_input_cost * 1.05;

    v_pending_after := case
      when v_actual_output < v_whole_output then 0
      else v_raw_output - v_whole_output
    end;

    v_output_quantity_after := v_row.output_quantity + v_actual_output;
    v_output_cost_after := case
      when v_output_quantity_after > 0 then
        (((v_row.output_quantity * coalesce(v_row.output_cost, 0)) + v_total_production_cost) / v_output_quantity_after)
      else v_row.output_cost
    end;

    update public.production_inventory
    set quantity = v_output_quantity_after,
        pending_quantity = v_pending_after,
        cost = v_output_cost_after
    where id = v_row.output_inventory_id;

    update public.production_slots
    set last_production_at = v_processed_until,
        updated_at = timezone('utc'::text, now())
    where id = v_row.production_slot_id;

    v_produced_count := v_produced_count + 1;
    v_total_produced := v_total_produced + v_actual_output;
  end loop;

  return jsonb_build_object(
    'success', true,
    'processed_count', v_processed_count,
    'produced_count', v_produced_count,
    'pending_only_count', v_pending_only_count,
    'skipped_count', v_skipped_count,
    'total_produced', v_total_produced
  );
end;
$$;


ALTER FUNCTION "public"."process_field_farm_production_entry"("p_player_id" "uuid", "p_owner_kind" "text", "p_owner_id" "uuid", "p_tick_minutes" integer, "p_max_ticks" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_mine_production_entry"("p_player_id" "uuid" DEFAULT "auth"."uid"(), "p_mine_id" "uuid" DEFAULT NULL::"uuid", "p_tick_minutes" integer DEFAULT 10, "p_max_ticks" integer DEFAULT 144) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_now timestamptz := timezone('utc'::text, now());
  v_processed_count integer := 0;
  v_produced_count integer := 0;
  v_pending_only_count integer := 0;
  v_skipped_count integer := 0;
  v_total_produced integer := 0;
  v_ticks integer;
  v_processed_until timestamptz;
  v_rate_per_tick numeric;
  v_raw_output numeric;
  v_whole_output integer;
  v_available_output_capacity integer;
  v_output_to_produce integer;
  v_pending_after numeric;
  v_boost_bonus_minutes numeric;
  v_effective_ticks numeric;
  v_row record;
begin
  if p_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  perform pg_advisory_xact_lock(hashtext('mine_production_entry:' || p_player_id::text));

  for v_row in
    select
      m.id as mine_id,
      m.output_capacity,
      m.last_production_at,
      p.uretim_adedi,
      out_pi.id as output_inventory_id,
      out_pi.quantity as output_quantity,
      coalesce(out_pi.pending_quantity, 0) as output_pending_quantity
    from public.mines m
    join public.products p on p.id = m.product_id
    join public.production_inventory out_pi
      on out_pi.owner_kind = 'mine'
     and out_pi.owner_id = m.id
     and out_pi.inventory_type = 'output'
     and out_pi.product_id = m.product_id
     and out_pi.quality_level = m.quality_level
    where m.player_id = p_player_id
      and (p_mine_id is null or m.id = p_mine_id)
      and m.is_active = true
      and m.product_id is not null
      and m.quality_level between 1 and 5
      and coalesce(p.uretim_adedi, 0) > 0
    order by m.created_at, m.id
  loop
    v_ticks := floor(extract(epoch from (v_now - coalesce(v_row.last_production_at, v_now))) / greatest(p_tick_minutes * 60, 60))::integer;
    v_ticks := greatest(least(v_ticks, p_max_ticks), 0);

    if v_ticks <= 0 then
      continue;
    end if;

    v_processed_count := v_processed_count + 1;
    v_processed_until := coalesce(v_row.last_production_at, v_now) + make_interval(mins => p_tick_minutes * v_ticks);
    v_available_output_capacity := greatest(v_row.output_capacity - v_row.output_quantity, 0);

    if v_available_output_capacity <= 0 then
      update public.mines
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.mine_id;

      v_skipped_count := v_skipped_count + 1;
      continue;
    end if;

    select coalesce(
      sum(
        greatest(
          extract(
            epoch from least(coalesce(bb.completed_at, bb.finish_at, v_processed_until), v_processed_until)
            - greatest(bb.started_at, v_row.last_production_at)
          ) / 60.0,
          0
        ) * greatest(coalesce(bb.multiplier, 1) - 1, 0)
      ),
      0
    )
    into v_boost_bonus_minutes
    from public.building_boosts bb
    where bb.player_id = p_player_id
      and bb.building_kind = 'mine'
      and bb.entity_id = v_row.mine_id
      and bb.started_at < v_processed_until
      and coalesce(bb.completed_at, bb.finish_at, v_processed_until) > v_row.last_production_at;

    v_effective_ticks := greatest(
      0,
      (
        (p_tick_minutes * v_ticks)::numeric + coalesce(v_boost_bonus_minutes, 0)
      ) / greatest(p_tick_minutes, 1)::numeric
    );

    v_rate_per_tick := coalesce(v_row.uretim_adedi, 0)::numeric / 6;
    v_raw_output := coalesce(v_row.output_pending_quantity, 0) + (v_rate_per_tick * v_effective_ticks);
    v_whole_output := floor(v_raw_output)::integer;

    if v_whole_output <= 0 then
      update public.production_inventory
      set pending_quantity = v_raw_output
      where id = v_row.output_inventory_id;

      update public.mines
      set last_production_at = v_processed_until,
          updated_at = timezone('utc'::text, now())
      where id = v_row.mine_id;

      v_pending_only_count := v_pending_only_count + 1;
      continue;
    end if;

    v_output_to_produce := least(v_whole_output, v_available_output_capacity);
    v_pending_after := case
      when v_output_to_produce < v_whole_output then 0
      else v_raw_output - v_whole_output
    end;

    update public.production_inventory
    set quantity = quantity + v_output_to_produce,
        pending_quantity = v_pending_after
    where id = v_row.output_inventory_id;

    update public.mines
    set last_production_at = v_processed_until,
        updated_at = timezone('utc'::text, now())
    where id = v_row.mine_id;

    if v_output_to_produce > 0 then
      v_produced_count := v_produced_count + 1;
      v_total_produced := v_total_produced + v_output_to_produce;
    else
      v_skipped_count := v_skipped_count + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'success', true,
    'processed_count', v_processed_count,
    'produced_count', v_produced_count,
    'pending_only_count', v_pending_only_count,
    'skipped_count', v_skipped_count,
    'total_produced', v_total_produced
  );
end;
$$;


ALTER FUNCTION "public"."process_mine_production_entry"("p_player_id" "uuid", "p_mine_id" "uuid", "p_tick_minutes" integer, "p_max_ticks" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_player_production_entry"("p_player_id" "uuid" DEFAULT "auth"."uid"(), "p_owner_kind" "text" DEFAULT NULL::"text", "p_owner_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_boosts_result jsonb := jsonb_build_object('success', true, 'completed_count', 0);
  v_upgrades_result jsonb := jsonb_build_object('success', true, 'completed_count', 0);
  v_factory_result jsonb := jsonb_build_object('success', true, 'processed_count', 0, 'produced_count', 0, 'pending_only_count', 0, 'skipped_count', 0, 'total_produced', 0);
  v_field_farm_result jsonb := jsonb_build_object('success', true, 'processed_count', 0, 'produced_count', 0, 'pending_only_count', 0, 'skipped_count', 0, 'total_produced', 0);
  v_mine_result jsonb := jsonb_build_object('success', true, 'processed_count', 0, 'produced_count', 0, 'pending_only_count', 0, 'skipped_count', 0, 'total_produced', 0);
begin
  if p_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_owner_kind is null then
    v_boosts_result := public.complete_due_building_boosts(100);
    v_upgrades_result := public.complete_due_building_upgrades(100);
  elsif p_owner_id is not null then
    if exists (
      select 1
      from public.building_upgrades bu
      where bu.player_id = p_player_id
        and bu.building_kind = p_owner_kind
        and bu.entity_id = p_owner_id
        and bu.status = 'in_progress'
        and bu.finish_at <= timezone('utc'::text, now())
    ) then
      v_upgrades_result := public.complete_due_building_upgrades(100);
    end if;
  end if;

  if p_owner_kind is null or p_owner_kind = 'factory' then
    v_factory_result := public.process_factory_production_entry(
      p_player_id,
      case when p_owner_kind = 'factory' then p_owner_id else null end
    );
  end if;

  if p_owner_kind is null or p_owner_kind in ('field', 'farm') then
    v_field_farm_result := public.process_field_farm_production_entry(
      p_player_id,
      case when p_owner_kind in ('field', 'farm') then p_owner_kind else null end,
      case when p_owner_kind in ('field', 'farm') then p_owner_id else null end
    );
  end if;

  if p_owner_kind is null or p_owner_kind = 'mine' then
    v_mine_result := public.process_mine_production_entry(
      p_player_id,
      case when p_owner_kind = 'mine' then p_owner_id else null end
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'completed_due_building_boosts', case
      when p_owner_kind is null then v_boosts_result
      else jsonb_build_object('success', true, 'completed_count', 0, 'skipped', true)
    end,
    'completed_due_building_upgrades', v_upgrades_result,
    'factory', v_factory_result,
    'field_farm', v_field_farm_result,
    'mine', v_mine_result
  );
end;
$$;


ALTER FUNCTION "public"."process_player_production_entry"("p_player_id" "uuid", "p_owner_kind" "text", "p_owner_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purchase_logistics_vehicle"("p_player_id" "uuid", "p_logistics_company_id" "uuid", "p_logistics_vehicle_type_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."purchase_logistics_vehicle"("p_player_id" "uuid", "p_logistics_company_id" "uuid", "p_logistics_vehicle_type_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refuel_logistics_vehicle"("p_player_id" "uuid", "p_vehicle_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_vehicle record;
  v_company record;
  v_missing_fuel integer;
  v_company_remaining_fuel numeric;
begin
  select *
  into v_vehicle
  from public.logistics_vehicles
  where id = p_vehicle_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'Arac bulunamadi.';
  end if;

  select *
  into v_company
  from public.logistics_companies
  where id = v_vehicle.logistics_company_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'Nakliye firmasi bulunamadi.';
  end if;

  v_missing_fuel := greatest(v_vehicle.fuel_capacity - v_vehicle.current_fuel, 0);
  v_company_remaining_fuel :=
    greatest(coalesce(v_company.current_fuel, 0) - v_missing_fuel, 0);

  if coalesce(v_company.current_fuel, 0) < v_missing_fuel then
    raise exception 'Merkez yakit rezervi yetersiz. Gerekli: %, mevcut: %',
      v_missing_fuel,
      coalesce(v_company.current_fuel, 0);
  end if;

  update public.logistics_companies
  set current_fuel = v_company_remaining_fuel,
      updated_at = timezone('utc'::text, now())
  where id = v_company.id;

  update public.logistics_vehicles
  set current_fuel = fuel_capacity,
      updated_at = timezone('utc'::text, now())
  where id = p_vehicle_id;

  return jsonb_build_object(
    'success', true,
    'vehicle_id', p_vehicle_id,
    'fuel_added', v_missing_fuel,
    'total_cost', 0,
    'current_fuel', v_vehicle.fuel_capacity,
    'company_remaining_fuel', v_company_remaining_fuel
  );
end;
$$;


ALTER FUNCTION "public"."refuel_logistics_vehicle"("p_player_id" "uuid", "p_vehicle_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."repair_logistics_vehicle"("p_player_id" "uuid", "p_vehicle_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_vehicle record;
  v_vehicle_type record;
  v_player_cash numeric;
  v_missing_condition integer;
  v_missing_condition_ratio numeric;
  v_total_cost numeric;
begin
  select *
  into v_vehicle
  from public.logistics_vehicles
  where id = p_vehicle_id
    and player_id = p_player_id
  for update;

  if not found then
    raise exception 'Arac bulunamadi.';
  end if;

  select *
  into v_vehicle_type
  from public.logistics_vehicle_types
  where id = v_vehicle.logistics_vehicle_type_id;

  if not found then
    raise exception 'Arac tipi bulunamadi.';
  end if;

  select cash
  into v_player_cash
  from public.players
  where id = p_player_id
  for update;

  v_missing_condition := greatest(100 - v_vehicle.condition, 0);
  v_missing_condition_ratio := v_missing_condition / 100.0;
  v_total_cost :=
    v_missing_condition_ratio * (coalesce(v_vehicle_type.purchase_price, 0) / 2.0);

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
$$;


ALTER FUNCTION "public"."repair_logistics_vehicle"("p_player_id" "uuid", "p_vehicle_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reserve_warehouse_capacity"("p_player_id" "uuid", "p_warehouse_id" "uuid", "p_product_id" "text", "p_quantity" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."reserve_warehouse_capacity"("p_player_id" "uuid", "p_warehouse_id" "uuid", "p_product_id" "text", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
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
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_factory_active"("p_factory_id" "uuid", "p_is_active" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_factory public.factories%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Oturum acilmamis.';
  end if;

  update public.factories
  set is_active = p_is_active,
      updated_at = now(),
      last_production_at = timezone('utc'::text, now())
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
$$;


ALTER FUNCTION "public"."set_factory_active"("p_factory_id" "uuid", "p_is_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_factory_product"("p_player_id" "uuid", "p_factory_id" "uuid", "p_product_id" "text", "p_quality_level" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
    updated_at = timezone('utc'::text, now()),
    last_production_at = timezone('utc'::text, now())
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
$$;


ALTER FUNCTION "public"."set_factory_product"("p_player_id" "uuid", "p_factory_id" "uuid", "p_product_id" "text", "p_quality_level" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_logistics_vehicle_active"("p_player_id" "uuid", "p_vehicle_id" "uuid", "p_is_active" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."set_logistics_vehicle_active"("p_player_id" "uuid", "p_vehicle_id" "uuid", "p_is_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_logistics_vehicle_rental"("p_player_id" "uuid", "p_vehicle_id" "uuid", "p_is_available_for_rent" boolean, "p_rental_price" numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."set_logistics_vehicle_rental"("p_player_id" "uuid", "p_vehicle_id" "uuid", "p_is_available_for_rent" boolean, "p_rental_price" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_logistics_vehicle_route"("p_player_id" "uuid", "p_vehicle_id" "uuid", "p_route_city_a_id" "uuid", "p_route_city_b_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."set_logistics_vehicle_route"("p_player_id" "uuid", "p_vehicle_id" "uuid", "p_route_city_a_id" "uuid", "p_route_city_b_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_mine_active"("p_mine_id" "uuid", "p_is_active" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_mine public.mines%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Oturum acilmamis.';
  end if;

  update public.mines
  set is_active = p_is_active,
      updated_at = now(),
      last_production_at = timezone('utc'::text, now())
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
$$;


ALTER FUNCTION "public"."set_mine_active"("p_mine_id" "uuid", "p_is_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_mine_product"("p_player_id" "uuid", "p_mine_id" "uuid", "p_product_id" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
    raise exception 'Urun id bos olamaz.';
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
    raise exception 'Maden bulunamadi.';
  end if;

  if v_mine.player_id <> p_player_id then
    raise exception 'Bu maden oyuncuya ait degil.';
  end if;

  select *
  into v_product
  from public.products
  where id = p_product_id;

  if not found then
    raise exception 'Urun bulunamadi.';
  end if;

  if lower(trim(coalesce(v_product.uretim_birimi, ''))) not in ('mine', 'maden') then
    raise exception 'Bu urun maden urunu degil. Uretim birimi: %', v_product.uretim_birimi;
  end if;

  if v_product.baz_satis_fiyati is null or v_product.baz_satis_fiyati < 0 then
    raise exception 'Urunun baz_satis_fiyati degeri gecerli degil.';
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
    raise exception 'Bu maden turu secilen urunu uretemez.';
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
      raise exception 'Bu madende yoldaki urunler var. Urun degistirmeden once transferlerin tamamlanmasini bekleyin.';
    end if;
  end if;

  update public.mines
  set
    product_id = p_product_id,
    quality_level = v_player_quality,
    updated_at = timezone('utc'::text, now()),
    last_production_at = timezone('utc'::text, now())
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
$$;


ALTER FUNCTION "public"."set_mine_product"("p_player_id" "uuid", "p_mine_id" "uuid", "p_product_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_player_avatar"("p_avatar_id" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."set_player_avatar"("p_avatar_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_production_slot_active"("p_player_id" "uuid", "p_production_slot_id" "uuid", "p_is_active" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_slot public.production_slots%rowtype;
  v_owner_player_id uuid;
begin
  select *
  into v_slot
  from public.production_slots
  where id = p_production_slot_id
  for update;

  if not found then
    raise exception 'Uretim slotu bulunamadi.';
  end if;

  if v_slot.owner_kind = 'field' then
    select player_id into v_owner_player_id
    from public.fields
    where id = v_slot.owner_id;
  elsif v_slot.owner_kind = 'farm' then
    select player_id into v_owner_player_id
    from public.farms
    where id = v_slot.owner_id;
  else
    raise exception 'Desteklenmeyen owner_kind: %', v_slot.owner_kind;
  end if;

  if v_owner_player_id is null or v_owner_player_id <> p_player_id then
    raise exception 'Bu slot oyuncuya ait degil.';
  end if;

  update public.production_slots
  set is_active = p_is_active,
      updated_at = timezone('utc'::text, now()),
      last_production_at = timezone('utc'::text, now())
  where id = p_production_slot_id
  returning *
  into v_slot;

  return jsonb_build_object(
    'success', true,
    'slot', to_jsonb(v_slot)
  );
end;
$$;


ALTER FUNCTION "public"."set_production_slot_active"("p_player_id" "uuid", "p_production_slot_id" "uuid", "p_is_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_store_slot_active"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_is_active" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."set_store_slot_active"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_is_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_store_slot_price"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_price" numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."set_store_slot_price"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_price" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_store_slot_product"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_product_id" "text", "p_quality_level" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."set_store_slot_product"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_product_id" "text", "p_quality_level" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_warehouse_slot_price"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_price" numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_slot record;
begin
  select
    ws.*,
    w.player_id,
    w.id as warehouse_id
  into v_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  where ws.id = p_warehouse_slot_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Slot bulunamadi.');
  end if;

  if v_slot.player_id is null or v_slot.player_id <> p_player_id then
    return jsonb_build_object('success', false, 'message', 'Bu depoda yetkiniz yok.');
  end if;

  if p_price <= 0 then
    return jsonb_build_object('success', false, 'message', 'Fiyat 0 dan buyuk olmalidir.');
  end if;

  update public.warehouse_slots
  set
    price = p_price,
    updated_at = timezone('utc'::text, now())
  where id = p_warehouse_slot_id;

  return jsonb_build_object(
    'success', true,
    'warehouse_id', v_slot.warehouse_id,
    'warehouse_slot_id', p_warehouse_slot_id,
    'price', p_price,
    'message', 'Satis fiyati basariyla guncellendi.'
  );
exception when others then
  return jsonb_build_object('success', false, 'message', sqlerrm);
end;
$$;


ALTER FUNCTION "public"."set_warehouse_slot_price"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_price" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_warehouse_slot_sale_status"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_is_available_for_sale" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."set_warehouse_slot_sale_status"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_is_available_for_sale" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_arge_center_construction"("p_player_id" "uuid", "p_name" "text" DEFAULT 'AR-GE Merkezi'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player players%rowtype;
  v_cost numeric := 25000;
  v_required_level integer := 1;
  v_construction_time_minutes integer := 60;
  v_started_at timestamptz := timezone('utc', now());
  v_finish_at timestamptz;
  v_construction_id uuid;
  v_name text := coalesce(nullif(trim(p_name), ''), 'AR-GE Merkezi');
begin
  select * into v_player from public.players where id = p_player_id;
  if not found then
    return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.');
  end if;

  if exists (select 1 from public.arge_centers ac where ac.player_id = p_player_id) then
    return jsonb_build_object('success', false, 'message', 'Zaten aktif bir AR-GE merkeziniz bulunuyor.');
  end if;

  if exists (
    select 1 from public.building_constructions bc
    where bc.player_id = p_player_id
      and bc.building_kind = 'arge_center'
      and bc.status = 'in_progress'
  ) then
    return jsonb_build_object('success', false, 'message', 'Devam eden bir AR-GE merkez kurulumu var.');
  end if;

  if v_player.level < v_required_level then
    return jsonb_build_object(
      'success', false,
      'message', format('Bu kurulum icin seviye %s gerekli. Mevcut seviyeniz: %s.', v_required_level, v_player.level)
    );
  end if;

  if v_player.cash < v_cost then
    return jsonb_build_object(
      'success', false,
      'message', format('Yetersiz bakiye. Gerekli: %s TL, Mevcut: %s TL.', v_cost::bigint, v_player.cash::bigint)
    );
  end if;

  v_finish_at := v_started_at + make_interval(mins => v_construction_time_minutes);

  update public.players
  set cash = cash - v_cost
  where id = p_player_id;

  insert into public.building_constructions (
    player_id, building_kind, params, status, started_at, finish_at
  ) values (
    p_player_id,
    'arge_center',
    jsonb_build_object(
      'name', v_name,
      'level', 1,
      'max_concurrent_researches', 1,
      'duration_reduction_pct', 0,
      'cost', v_cost,
      'construction_time_minutes', v_construction_time_minutes
    ),
    'in_progress',
    v_started_at,
    v_finish_at
  ) returning id into v_construction_id;

  return jsonb_build_object(
    'success', true,
    'construction_id', v_construction_id,
    'building_kind', 'arge_center',
    'name', v_name,
    'cost', v_cost,
    'finish_at', v_finish_at,
    'construction_time_minutes', v_construction_time_minutes
  );
end;
$$;


ALTER FUNCTION "public"."start_arge_center_construction"("p_player_id" "uuid", "p_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_arge_research"("p_player_id" "uuid", "p_product_id" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player players%rowtype;
  v_arge_center arge_centers%rowtype;
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

  select * into v_arge_center
  from public.arge_centers
  where player_id = p_player_id
    and is_active = true
  order by created_at
  limit 1;

  if not found then
    return jsonb_build_object(
      'success', false,
      'message', 'Arastirma baslatmak icin once AR-GE merkezinizi kurmaniz gerekiyor.'
    );
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
      'message', format('Yetersiz bakiye. Gerekli: %s TL, Mevcut: %s TL.', v_cost::bigint, v_player.cash::bigint)
    );
  end if;

  if exists (
    select 1
    from arge_researches
    where player_id = p_player_id
      and product_id = p_product_id
      and status = 'in_progress'
  ) then
    return jsonb_build_object(
      'success', false,
      'message', 'Bu urun icin zaten devam eden bir arastirmaniz var.'
    );
  end if;

  if (
    select count(*)
    from arge_researches
    where player_id = p_player_id
      and status = 'in_progress'
  ) >= v_arge_center.max_concurrent_researches then
    return jsonb_build_object(
      'success', false,
      'message', format(
        'AR-GE merkeziniz en fazla %s eszamanli arastirma destekliyor.',
        v_arge_center.max_concurrent_researches
      )
    );
  end if;

  v_duration_hours := v_durations[v_current_quality];
  v_finish_at := timezone('utc', now()) + make_interval(
    secs => greatest(
      60,
      floor(
        (v_duration_hours * 3600)::numeric *
        greatest(0, 1 - (coalesce(v_arge_center.duration_reduction_pct, 0) / 100.0))
      )::integer
    )
  );

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
$$;


ALTER FUNCTION "public"."start_arge_research"("p_player_id" "uuid", "p_product_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_building_boost"("p_player_id" "uuid", "p_building_kind" "text", "p_entity_id" "uuid", "p_duration_hours" integer, "p_star_cost" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_now timestamptz := timezone('utc', now());
  v_finish_at timestamptz;
  v_boost_id uuid;
  v_multiplier numeric := 2.00;
  v_player_gold numeric;
begin
  if p_player_id is null or p_player_id <> auth.uid() then
    raise exception 'Gecersiz oyuncu.';
  end if;

  if p_duration_hours not in (6, 12, 24) then
    raise exception 'Boost suresi yalnizca 6, 12 veya 24 saat olabilir.';
  end if;

  if coalesce(p_star_cost, 0) < 0 then
    raise exception 'Boost maliyeti gecersiz.';
  end if;

  if exists (
    select 1
    from public.building_boosts bb
    where bb.player_id = p_player_id
      and bb.building_kind = p_building_kind
      and bb.entity_id = p_entity_id
      and bb.status = 'in_progress'
      and coalesce(bb.finish_at, v_now) > v_now
  ) then
    raise exception 'Bu isletme icin zaten aktif bir boost var.';
  end if;

  select gold
  into v_player_gold
  from public.players
  where id = p_player_id
  for update;

  if not found then
    raise exception 'Oyuncu bulunamadi.';
  end if;

  if coalesce(v_player_gold, 0) < p_star_cost then
    raise exception 'Yetersiz yildiz. Gerekli: %, Mevcut: %', p_star_cost, coalesce(v_player_gold, 0);
  end if;

  if p_building_kind = 'store' then
    if not exists (
      select 1
      from public.stores s
      where s.id = p_entity_id
        and s.player_id = p_player_id
        and s.is_active = true
    ) then
      raise exception 'Magaza bulunamadi veya aktif degil.';
    end if;

    update public.store_slots
    set
      boost_multiplier = v_multiplier,
      updated_at = v_now
    where store_id = p_entity_id;
  elsif p_building_kind in ('field', 'farm') then
    if not exists (
      select 1
      from public.production_slots ps
      where ps.owner_kind = p_building_kind
        and ps.owner_id = p_entity_id
    ) then
      raise exception 'Uretim slotlari bulunamadi.';
    end if;

    update public.production_slots
    set
      boost_multiplier = v_multiplier,
      updated_at = v_now
    where owner_kind = p_building_kind
      and owner_id = p_entity_id;
  elsif p_building_kind = 'factory' then
    update public.factories
    set
      boost_multiplier = v_multiplier,
      updated_at = v_now
    where id = p_entity_id
      and player_id = p_player_id
      and is_active = true;

    if not found then
      raise exception 'Fabrika bulunamadi veya aktif degil.';
    end if;
  elsif p_building_kind = 'mine' then
    update public.mines
    set
      boost_multiplier = v_multiplier,
      updated_at = v_now
    where id = p_entity_id
      and player_id = p_player_id
      and is_active = true;

    if not found then
      raise exception 'Maden bulunamadi veya aktif degil.';
    end if;
  else
    raise exception 'Bu building_kind icin boost destegi henuz yok: %', p_building_kind;
  end if;

  update public.players
  set gold = gold - p_star_cost
  where id = p_player_id;

  v_finish_at := v_now + make_interval(hours => p_duration_hours);

  insert into public.building_boosts (
    player_id,
    building_kind,
    entity_id,
    duration_hours,
    star_cost,
    multiplier,
    params,
    status,
    started_at,
    finish_at,
    created_at,
    updated_at
  )
  values (
    p_player_id,
    p_building_kind,
    p_entity_id,
    p_duration_hours,
    p_star_cost,
    v_multiplier,
    jsonb_build_object(
      'duration_hours', p_duration_hours,
      'star_cost', p_star_cost,
      'multiplier', v_multiplier
    ),
    'in_progress',
    v_now,
    v_finish_at,
    v_now,
    v_now
  )
  returning id into v_boost_id;

  return jsonb_build_object(
    'success', true,
    'boost_id', v_boost_id,
    'building_kind', p_building_kind,
    'entity_id', p_entity_id,
    'duration_hours', p_duration_hours,
    'star_cost', p_star_cost,
    'multiplier', v_multiplier,
    'finish_at', v_finish_at
  );
end;
$$;


ALTER FUNCTION "public"."start_building_boost"("p_player_id" "uuid", "p_building_kind" "text", "p_entity_id" "uuid", "p_duration_hours" integer, "p_star_cost" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_building_construction"("p_player_id" "uuid", "p_building_kind" "text", "p_type_id" "uuid", "p_city_id" "uuid", "p_name" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."start_building_construction"("p_player_id" "uuid", "p_building_kind" "text", "p_type_id" "uuid", "p_city_id" "uuid", "p_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_building_upgrade"("p_player_id" "uuid", "p_building_kind" "text", "p_entity_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_now timestamptz := timezone('utc', now());
  v_player record;
  v_store record;
  v_arge_center record;
  v_field record;
  v_farm record;
  v_factory record;
  v_mine record;
  v_current_level integer;
  v_target_level integer;
  v_duration_minutes integer;
  v_slot_capacity_increase integer := 0;
  v_max_slot_increase integer := 2;
  v_input_capacity_increase integer := 0;
  v_output_capacity_increase integer := 0;
  v_upgrade_cost numeric := 0;
  v_upgrade_id uuid;
  v_finish_at timestamptz;
begin
  if p_player_id is null or p_player_id <> auth.uid() then
    raise exception 'Gecersiz oyuncu.';
  end if;

  select *
  into v_player
  from public.players
  where id = p_player_id
  for update;

  if not found then
    raise exception 'Oyuncu bulunamadi.';
  end if;

  if exists (
    select 1
    from public.building_upgrades bu
    where bu.player_id = p_player_id
      and bu.building_kind = p_building_kind
      and bu.entity_id = p_entity_id
      and bu.status = 'in_progress'
      and coalesce(bu.finish_at, v_now) > v_now
  ) then
    raise exception 'Bu isletme icin zaten devam eden bir yukseltme var.';
  end if;

  if p_building_kind = 'store' then
    select
      s.*,
      st.name as store_type_name,
      st.construction_time_minutes,
      st.cost as store_type_cost,
      st.slot_capacity as base_slot_capacity
    into v_store
    from public.stores s
    join public.store_types st on st.id = s.store_type_id
    where s.id = p_entity_id
      and s.player_id = p_player_id
    for update;

    if not found then
      raise exception 'Magaza bulunamadi veya size ait degil.';
    end if;

    if coalesce(v_store.is_active, false) = false then
      raise exception 'Pasif magazada yukseltme baslatilamaz.';
    end if;

    v_current_level := coalesce(v_store.level, 1);
    v_target_level := v_current_level + 1;
    v_slot_capacity_increase := greatest(0, coalesce(v_store.base_slot_capacity, 0));
    v_duration_minutes := greatest(
      1,
      coalesce(v_store.construction_time_minutes, 0) * v_target_level
    );
    v_upgrade_cost := greatest(
      0,
      coalesce(v_store.store_type_cost, 0) * v_target_level
    );
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);

    if coalesce(v_player.cash, 0) < v_upgrade_cost then
      raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %',
        v_upgrade_cost,
        coalesce(v_player.cash, 0);
    end if;

    update public.players
    set cash = cash - v_upgrade_cost
    where id = p_player_id;

    insert into public.building_upgrades (
      player_id,
      building_kind,
      entity_id,
      current_level,
      target_level,
      params,
      status,
      started_at,
      finish_at,
      created_at,
      updated_at
    )
    values (
      p_player_id,
      p_building_kind,
      p_entity_id,
      v_current_level,
      v_target_level,
      jsonb_build_object(
        'name', v_store.name,
        'store_type_id', v_store.store_type_id,
        'store_type_name', v_store.store_type_name,
        'base_duration_minutes', coalesce(v_store.construction_time_minutes, 0),
        'duration_minutes', v_duration_minutes,
        'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', v_slot_capacity_increase,
        'max_slot_increase', v_max_slot_increase,
        'previous_slot_capacity', coalesce(v_store.slot_capacity, 0),
        'next_slot_capacity', coalesce(v_store.slot_capacity, 0) + v_slot_capacity_increase,
        'previous_max_slot_count', coalesce(v_store.max_slot_count, 0),
        'next_max_slot_count', coalesce(v_store.max_slot_count, 0) + v_max_slot_increase
      ),
      'in_progress',
      v_now,
      v_finish_at,
      v_now,
      v_now
    )
    returning id into v_upgrade_id;

    return jsonb_build_object(
      'success', true,
      'upgrade_id', v_upgrade_id,
      'building_kind', p_building_kind,
      'entity_id', p_entity_id,
      'current_level', v_current_level,
      'target_level', v_target_level,
      'duration_minutes', v_duration_minutes,
      'upgrade_cost', v_upgrade_cost,
      'slot_capacity_increase', v_slot_capacity_increase,
      'max_slot_increase', v_max_slot_increase,
      'finish_at', v_finish_at
    );
  elsif p_building_kind = 'field' then
    select
      f.*,
      ft.name as field_type_name,
      ft.construction_time_minutes,
      ft.cost as field_type_cost
    into v_field
    from public.fields f
    join public.field_types ft on ft.id = f.field_type_id
    where f.id = p_entity_id
      and f.player_id = p_player_id
    for update;

    if not found then
      raise exception 'Ciftlik bulunamadi veya size ait degil.';
    end if;

    if coalesce(v_field.is_active, false) = false then
      raise exception 'Pasif ciftlikte yukseltme baslatilamaz.';
    end if;

    v_current_level := coalesce(v_field.level, 1);
    v_target_level := v_current_level + 1;
    v_input_capacity_increase := greatest(0, coalesce(v_field.input_capacity, 0));
    v_output_capacity_increase := greatest(0, coalesce(v_field.output_capacity, 0));
    v_duration_minutes := greatest(
      1,
      coalesce(v_field.construction_time_minutes, 0) * v_target_level
    );
    v_upgrade_cost := greatest(
      0,
      coalesce(v_field.field_type_cost, 0) * v_target_level
    );
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);

    if coalesce(v_player.cash, 0) < v_upgrade_cost then
      raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %',
        v_upgrade_cost,
        coalesce(v_player.cash, 0);
    end if;

    update public.players
    set cash = cash - v_upgrade_cost
    where id = p_player_id;

    insert into public.building_upgrades (
      player_id,
      building_kind,
      entity_id,
      current_level,
      target_level,
      params,
      status,
      started_at,
      finish_at,
      created_at,
      updated_at
    )
    values (
      p_player_id,
      p_building_kind,
      p_entity_id,
      v_current_level,
      v_target_level,
      jsonb_build_object(
        'name', v_field.name,
        'field_type_id', v_field.field_type_id,
        'field_type_name', v_field.field_type_name,
        'base_duration_minutes', coalesce(v_field.construction_time_minutes, 0),
        'duration_minutes', v_duration_minutes,
        'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', 0,
        'max_slot_increase', 0,
        'previous_slot_capacity', 0,
        'next_slot_capacity', 0,
        'previous_max_slot_count', coalesce(v_field.max_slot_count, 0),
        'next_max_slot_count', coalesce(v_field.max_slot_count, 0),
        'input_capacity_increase', v_input_capacity_increase,
        'output_capacity_increase', v_output_capacity_increase,
        'previous_input_capacity', coalesce(v_field.input_capacity, 0),
        'next_input_capacity', coalesce(v_field.input_capacity, 0) + v_input_capacity_increase,
        'previous_output_capacity', coalesce(v_field.output_capacity, 0),
        'next_output_capacity', coalesce(v_field.output_capacity, 0) + v_output_capacity_increase
      ),
      'in_progress',
      v_now,
      v_finish_at,
      v_now,
      v_now
    )
    returning id into v_upgrade_id;

    return jsonb_build_object(
      'success', true,
      'upgrade_id', v_upgrade_id,
      'building_kind', p_building_kind,
      'entity_id', p_entity_id,
      'current_level', v_current_level,
      'target_level', v_target_level,
      'duration_minutes', v_duration_minutes,
      'upgrade_cost', v_upgrade_cost,
      'input_capacity_increase', v_input_capacity_increase,
      'output_capacity_increase', v_output_capacity_increase,
      'finish_at', v_finish_at
    );
  elsif p_building_kind = 'farm' then
    select
      f.*,
      ft.name as farm_type_name,
      ft.construction_time_minutes,
      ft.cost as farm_type_cost
    into v_farm
    from public.farms f
    join public.farm_types ft on ft.id = f.farm_type_id
    where f.id = p_entity_id
      and f.player_id = p_player_id
    for update;

    if not found then
      raise exception 'Tarla bulunamadi veya size ait degil.';
    end if;

    if coalesce(v_farm.is_active, false) = false then
      raise exception 'Pasif tarlada yukseltme baslatilamaz.';
    end if;

    v_current_level := coalesce(v_farm.level, 1);
    v_target_level := v_current_level + 1;
    v_input_capacity_increase := greatest(0, coalesce(v_farm.input_capacity, 0));
    v_output_capacity_increase := greatest(0, coalesce(v_farm.output_capacity, 0));
    v_duration_minutes := greatest(
      1,
      coalesce(v_farm.construction_time_minutes, 0) * v_target_level
    );
    v_upgrade_cost := greatest(
      0,
      coalesce(v_farm.farm_type_cost, 0) * v_target_level
    );
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);

    if coalesce(v_player.cash, 0) < v_upgrade_cost then
      raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %',
        v_upgrade_cost,
        coalesce(v_player.cash, 0);
    end if;

    update public.players
    set cash = cash - v_upgrade_cost
    where id = p_player_id;

    insert into public.building_upgrades (
      player_id,
      building_kind,
      entity_id,
      current_level,
      target_level,
      params,
      status,
      started_at,
      finish_at,
      created_at,
      updated_at
    )
    values (
      p_player_id,
      p_building_kind,
      p_entity_id,
      v_current_level,
      v_target_level,
      jsonb_build_object(
        'name', v_farm.name,
        'farm_type_id', v_farm.farm_type_id,
        'farm_type_name', v_farm.farm_type_name,
        'base_duration_minutes', coalesce(v_farm.construction_time_minutes, 0),
        'duration_minutes', v_duration_minutes,
        'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', 0,
        'max_slot_increase', 0,
        'previous_slot_capacity', 0,
        'next_slot_capacity', 0,
        'previous_max_slot_count', coalesce(v_farm.max_slot_count, 0),
        'next_max_slot_count', coalesce(v_farm.max_slot_count, 0),
        'input_capacity_increase', v_input_capacity_increase,
        'output_capacity_increase', v_output_capacity_increase,
        'previous_input_capacity', coalesce(v_farm.input_capacity, 0),
        'next_input_capacity', coalesce(v_farm.input_capacity, 0) + v_input_capacity_increase,
        'previous_output_capacity', coalesce(v_farm.output_capacity, 0),
        'next_output_capacity', coalesce(v_farm.output_capacity, 0) + v_output_capacity_increase
      ),
      'in_progress',
      v_now,
      v_finish_at,
      v_now,
      v_now
    )
    returning id into v_upgrade_id;

    return jsonb_build_object(
      'success', true,
      'upgrade_id', v_upgrade_id,
      'building_kind', p_building_kind,
      'entity_id', p_entity_id,
      'current_level', v_current_level,
      'target_level', v_target_level,
      'duration_minutes', v_duration_minutes,
      'upgrade_cost', v_upgrade_cost,
      'input_capacity_increase', v_input_capacity_increase,
      'output_capacity_increase', v_output_capacity_increase,
      'finish_at', v_finish_at
    );
  elsif p_building_kind = 'factory' then
    select
      f.*,
      ft.name as factory_type_name,
      ft.construction_time_minutes,
      ft.cost as factory_type_cost
    into v_factory
    from public.factories f
    join public.factory_types ft on ft.id = f.factory_type_id
    where f.id = p_entity_id
      and f.player_id = p_player_id
    for update;

    if not found then
      raise exception 'Fabrika bulunamadi veya size ait degil.';
    end if;

    if coalesce(v_factory.is_active, false) = false then
      raise exception 'Pasif fabrikada yukseltme baslatilamaz.';
    end if;

    v_current_level := coalesce(v_factory.level, 1);
    v_target_level := v_current_level + 1;
    v_input_capacity_increase := greatest(
      0,
      coalesce(v_factory.input_capacity, 0)
    );
    v_output_capacity_increase := greatest(
      0,
      coalesce(v_factory.output_capacity, 0)
    );
    v_duration_minutes := greatest(
      1,
      coalesce(v_factory.construction_time_minutes, 0) * v_target_level
    );
    v_upgrade_cost := greatest(
      0,
      coalesce(v_factory.factory_type_cost, 0) * v_target_level
    );
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);

    if coalesce(v_player.cash, 0) < v_upgrade_cost then
      raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %',
        v_upgrade_cost,
        coalesce(v_player.cash, 0);
    end if;

    update public.players
    set cash = cash - v_upgrade_cost
    where id = p_player_id;

    insert into public.building_upgrades (
      player_id,
      building_kind,
      entity_id,
      current_level,
      target_level,
      params,
      status,
      started_at,
      finish_at,
      created_at,
      updated_at
    )
    values (
      p_player_id,
      p_building_kind,
      p_entity_id,
      v_current_level,
      v_target_level,
      jsonb_build_object(
        'name', v_factory.name,
        'factory_type_id', v_factory.factory_type_id,
        'factory_type_name', v_factory.factory_type_name,
        'base_duration_minutes', coalesce(v_factory.construction_time_minutes, 0),
        'duration_minutes', v_duration_minutes,
        'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', 0,
        'max_slot_increase', 0,
        'previous_slot_capacity', 0,
        'next_slot_capacity', 0,
        'previous_max_slot_count', 0,
        'next_max_slot_count', 0,
        'input_capacity_increase', v_input_capacity_increase,
        'output_capacity_increase', v_output_capacity_increase,
        'previous_input_capacity', coalesce(v_factory.input_capacity, 0),
        'next_input_capacity', coalesce(v_factory.input_capacity, 0) + v_input_capacity_increase,
        'previous_output_capacity', coalesce(v_factory.output_capacity, 0),
        'next_output_capacity', coalesce(v_factory.output_capacity, 0) + v_output_capacity_increase
      ),
      'in_progress',
      v_now,
      v_finish_at,
      v_now,
      v_now
    )
    returning id into v_upgrade_id;

    return jsonb_build_object(
      'success', true,
      'upgrade_id', v_upgrade_id,
      'building_kind', p_building_kind,
      'entity_id', p_entity_id,
      'current_level', v_current_level,
      'target_level', v_target_level,
      'duration_minutes', v_duration_minutes,
      'upgrade_cost', v_upgrade_cost,
      'input_capacity_increase', v_input_capacity_increase,
      'output_capacity_increase', v_output_capacity_increase,
      'finish_at', v_finish_at
    );
  elsif p_building_kind = 'mine' then
    select
      m.*,
      mt.name as mine_type_name,
      mt.construction_time_minutes,
      mt.cost as mine_type_cost
    into v_mine
    from public.mines m
    join public.mine_types mt on mt.id = m.mine_type_id
    where m.id = p_entity_id
      and m.player_id = p_player_id
    for update;

    if not found then
      raise exception 'Maden bulunamadi veya size ait degil.';
    end if;

    if coalesce(v_mine.is_active, false) = false then
      raise exception 'Pasif madende yukseltme baslatilamaz.';
    end if;

    v_current_level := coalesce(v_mine.level, 1);
    v_target_level := v_current_level + 1;
    v_output_capacity_increase := greatest(
      0,
      coalesce(v_mine.output_capacity, 0)
    );
    v_duration_minutes := greatest(
      1,
      coalesce(v_mine.construction_time_minutes, 0) * v_target_level
    );
    v_upgrade_cost := greatest(
      0,
      coalesce(v_mine.mine_type_cost, 0) * v_target_level
    );
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);

    if coalesce(v_player.cash, 0) < v_upgrade_cost then
      raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %',
        v_upgrade_cost,
        coalesce(v_player.cash, 0);
    end if;

    update public.players
    set cash = cash - v_upgrade_cost
    where id = p_player_id;

    insert into public.building_upgrades (
      player_id,
      building_kind,
      entity_id,
      current_level,
      target_level,
      params,
      status,
      started_at,
      finish_at,
      created_at,
      updated_at
    )
    values (
      p_player_id,
      p_building_kind,
      p_entity_id,
      v_current_level,
      v_target_level,
      jsonb_build_object(
        'name', v_mine.name,
        'mine_type_id', v_mine.mine_type_id,
        'mine_type_name', v_mine.mine_type_name,
        'base_duration_minutes', coalesce(v_mine.construction_time_minutes, 0),
        'duration_minutes', v_duration_minutes,
        'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', 0,
        'max_slot_increase', 0,
        'previous_slot_capacity', 0,
        'next_slot_capacity', 0,
        'previous_max_slot_count', 0,
        'next_max_slot_count', 0,
        'input_capacity_increase', 0,
        'output_capacity_increase', v_output_capacity_increase,
        'previous_input_capacity', 0,
        'next_input_capacity', 0,
        'previous_output_capacity', coalesce(v_mine.output_capacity, 0),
        'next_output_capacity', coalesce(v_mine.output_capacity, 0) + v_output_capacity_increase
      ),
      'in_progress',
      v_now,
      v_finish_at,
      v_now,
      v_now
    )
    returning id into v_upgrade_id;

    return jsonb_build_object(
      'success', true,
      'upgrade_id', v_upgrade_id,
      'building_kind', p_building_kind,
      'entity_id', p_entity_id,
      'current_level', v_current_level,
      'target_level', v_target_level,
      'duration_minutes', v_duration_minutes,
      'upgrade_cost', v_upgrade_cost,
      'output_capacity_increase', v_output_capacity_increase,
      'finish_at', v_finish_at
    );
  elsif p_building_kind = 'arge_center' then
    select *
    into v_arge_center
    from public.arge_centers ac
    where ac.id = p_entity_id
      and ac.player_id = p_player_id
    for update;

    if not found then
      raise exception 'AR-GE merkezi bulunamadi veya size ait degil.';
    end if;

    if coalesce(v_arge_center.is_active, false) = false then
      raise exception 'Pasif AR-GE merkezinde yukseltme baslatilamaz.';
    end if;

    v_current_level := coalesce(v_arge_center.level, 1);
    v_target_level := v_current_level + 1;
    v_duration_minutes := greatest(1, 60 * v_target_level);
    v_upgrade_cost := greatest(0, 25000 * v_target_level);
    v_finish_at := v_now + make_interval(mins => v_duration_minutes);

    if coalesce(v_player.cash, 0) < v_upgrade_cost then
      raise exception 'Yetersiz bakiye. Gerekli: %, Mevcut: %',
        v_upgrade_cost,
        coalesce(v_player.cash, 0);
    end if;

    update public.players
    set cash = cash - v_upgrade_cost
    where id = p_player_id;

    insert into public.building_upgrades (
      player_id,
      building_kind,
      entity_id,
      current_level,
      target_level,
      params,
      status,
      started_at,
      finish_at,
      created_at,
      updated_at
    )
    values (
      p_player_id,
      p_building_kind,
      p_entity_id,
      v_current_level,
      v_target_level,
      jsonb_build_object(
        'name', v_arge_center.name,
        'duration_minutes', v_duration_minutes,
        'upgrade_cost', v_upgrade_cost,
        'slot_capacity_increase', 0,
        'max_slot_increase', 0,
        'previous_slot_capacity', 0,
        'next_slot_capacity', 0,
        'previous_max_slot_count', 0,
        'next_max_slot_count', 0,
        'input_capacity_increase', 0,
        'output_capacity_increase', 0,
        'previous_input_capacity', 0,
        'next_input_capacity', 0,
        'previous_output_capacity', 0,
        'next_output_capacity', 0,
        'previous_concurrent_researches', coalesce(v_arge_center.max_concurrent_researches, 1),
        'next_concurrent_researches',
          case
            when v_target_level >= 6 then 4
            when v_target_level >= 4 then 3
            when v_target_level >= 2 then 2
            else 1
          end,
        'previous_duration_reduction_pct', coalesce(v_arge_center.duration_reduction_pct, 0),
        'next_duration_reduction_pct',
          case
            when v_target_level = 2 then 5
            when v_target_level = 3 then 10
            when v_target_level = 4 then 15
            when v_target_level = 5 then 20
            when v_target_level >= 6 then 25
            else 0
          end
      ),
      'in_progress',
      v_now,
      v_finish_at,
      v_now,
      v_now
    )
    returning id into v_upgrade_id;

    return jsonb_build_object(
      'success', true,
      'upgrade_id', v_upgrade_id,
      'building_kind', p_building_kind,
      'entity_id', p_entity_id,
      'current_level', v_current_level,
      'target_level', v_target_level,
      'duration_minutes', v_duration_minutes,
      'upgrade_cost', v_upgrade_cost,
      'finish_at', v_finish_at
    );
  end if;

  raise exception 'Bu building_kind icin yukseltme destegi henuz yok: %', p_building_kind;
end;
$$;


ALTER FUNCTION "public"."start_building_upgrade"("p_player_id" "uuid", "p_building_kind" "text", "p_entity_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_logistics_company_construction"("p_player_id" "uuid", "p_type_id" "uuid", "p_name" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."start_logistics_company_construction"("p_player_id" "uuid", "p_type_id" "uuid", "p_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_market_to_store_transfer"("p_market_listing_id" "uuid", "p_store_slot_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player_id uuid := auth.uid();
  v_player record;
  v_store_slot record;
  v_listing record;
  v_buyer_store record;
  v_product record;
  v_vehicle record;
  v_transfer_id uuid;
  v_distance_km numeric := 0;
  v_required_capacity numeric := 0;
  v_fuel_used numeric := 0;
  v_condition_loss numeric := 0;
  v_rental_cost numeric := 0;
  v_transport_cost numeric := 0;
  v_total_price numeric := 0;
  v_tax_amount numeric := 0;
  v_commission_amount numeric := 0;
  v_duration_seconds integer := 0;
  v_finish_at timestamptz;
  v_add_result jsonb;
  v_new_cost numeric := 0;
  v_now timestamptz := timezone('utc'::text, now());
begin
  if v_player_id is null then raise exception 'Oturum acilmamis.'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Miktar 0''dan buyuk olmalidir.'; end if;

  select * into v_player from public.players where id = v_player_id for update;
  if not found then raise exception 'Oyuncu bulunamadi.'; end if;

  select ss.*, s.player_id, s.id as buyer_store_id, s.is_active as store_is_active,
         s.city_id as store_city_id, c.map_position_x as city_x, c.map_position_y as city_y
  into v_store_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  join public.cities c on c.id = s.city_id
  where ss.id = p_store_slot_id for update;

  if not found or v_store_slot.player_id <> v_player_id then raise exception 'Magaza slotu bulunamadi veya size ait degil.'; end if;
  if v_store_slot.store_is_active is not true then raise exception 'Magaza aktif degil.'; end if;

  select ml.*, wm.city_id as market_city_id, c.map_position_x as market_x, c.map_position_y as market_y
  into v_listing
  from public.wholesale_market_listings ml
  join public.wholesale_markets wm on wm.id = ml.market_id
  join public.cities c on c.id = wm.city_id
  where ml.id = p_market_listing_id for update;

  if not found then raise exception 'Hal ilani bulunamadi.'; end if;
  if v_listing.status <> 'active' then raise exception 'Bu ilan aktif degil.'; end if;
  if p_quantity > v_listing.quantity then raise exception 'Istenen miktar ilandaki miktardan fazla.'; end if;

  if v_store_slot.product_id is null or v_store_slot.quality_level = 0 then
    if coalesce(v_store_slot.quantity, 0) > 0 or coalesce(v_store_slot.pending_quantity, 0) > 0 then
      raise exception 'Slotta aktif stok veya rezerve varken urun atanamaz.';
    end if;
    update public.store_slots set product_id = v_listing.product_id, quality_level = v_listing.quality_level, updated_at = v_now where id = p_store_slot_id;
    v_store_slot.product_id := v_listing.product_id;
    v_store_slot.quality_level := v_listing.quality_level;
  elsif v_store_slot.product_id <> v_listing.product_id or v_store_slot.quality_level <> v_listing.quality_level then
    raise exception 'Magaza slotu urun veya kalite uyusmazligi.';
  end if;

  if (coalesce(v_store_slot.quantity, 0) + coalesce(v_store_slot.pending_quantity, 0) + p_quantity) > v_store_slot.capacity then
    raise exception 'Magaza slot kapasitesi yetersiz.';
  end if;

  select * into v_product from public.products where id = v_listing.product_id;
  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then raise exception 'Urun hacim bilgisi gecersiz.'; end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_total_price := p_quantity * v_listing.unit_price;

  if v_store_slot.store_city_id = v_listing.market_city_id then
    v_new_cost := case
      when coalesce(v_store_slot.quantity, 0) + p_quantity > 0 then
        (coalesce(v_store_slot.quantity, 0) * coalesce(v_store_slot.cost, 0) + p_quantity * v_listing.unit_price)
        / (coalesce(v_store_slot.quantity, 0) + p_quantity)
      else v_listing.unit_price
    end;
    if coalesce(v_player.cash, 0) < v_total_price then raise exception 'Bu islem icin yeterli nakit yok.'; end if;
    update public.players set cash = cash - v_total_price where id = v_player_id;
    update public.players set cash = cash + v_total_price where id = v_listing.seller_player_id;
    update public.wholesale_market_listings set quantity = quantity - p_quantity,
      status = case when quantity - p_quantity <= 0 then 'completed' else status end, updated_at = v_now
    where id = p_market_listing_id;
    update public.store_slots set quantity = quantity + p_quantity, cost = v_new_cost, updated_at = v_now where id = p_store_slot_id;
    insert into public.logistics_transfers (
      buyer_player_id, seller_player_id, buyer_store_id, buyer_store_slot_id, market_listing_id,
      logistics_vehicle_id, vehicle_owner_player_id, is_rental,
      product_id, quality_level, quantity, unit_price, total_price, product_unit_volume,
      reserved_capacity_amount, distance_km, fuel_used, condition_loss, rental_cost, transport_cost,
      transfer_type, started_at, finish_at, completed_at, status, updated_at
    )
    values (
      v_player_id, v_listing.seller_player_id, v_store_slot.buyer_store_id, p_store_slot_id, p_market_listing_id,
      null, null, false,
      v_listing.product_id, v_listing.quality_level, p_quantity, v_listing.unit_price, v_total_price, v_product.birim_hacim,
      0, 0, 0, 0, 0, 0, 'market_to_store', v_now, v_now, v_now, 'completed', v_now
    )
    returning id into v_transfer_id;
    return jsonb_build_object(
      'success', true, 'mode', 'instant', 'transfer_id', v_transfer_id,
      'store_slot_id', p_store_slot_id, 'product_id', v_listing.product_id,
      'quality_level', v_listing.quality_level, 'quantity', p_quantity,
      'transport_cost', 0, 'rental_cost', 0, 'new_cost', v_new_cost
    );
  end if;

  if p_vehicle_id is null then raise exception 'Farkli sehir transferi icin arac secilmelidir.'; end if;

  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_listing.market_x - v_store_slot.city_x) / 2)), 2) +
      cos(radians(v_store_slot.city_x)) * cos(radians(v_listing.market_x)) *
      power(sin(radians((v_listing.market_y - v_store_slot.city_y) / 2)), 2)
    )
  );

  if p_vehicle_id = '00000000-0000-0000-0000-000000000000' then
    select '00000000-0000-0000-0000-000000000000'::uuid as player_id into v_vehicle;
    v_rental_cost := ceil(v_distance_km * 5.0);
    v_transport_cost := v_rental_cost;
    v_duration_seconds := greatest(1, ceil(((v_distance_km / 60.0) / 4.0) * 3600))::integer;
    v_finish_at := timezone('utc'::text, now()) + make_interval(secs => v_duration_seconds);
  else
    select lv.*, lc.is_active as company_is_active into v_vehicle
    from public.logistics_vehicles lv
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where lv.id = p_vehicle_id for update;
    if not found then raise exception 'Arac bulunamadi.'; end if;
    if v_vehicle.status <> 'idle' then raise exception 'Arac su anda uygun degil.'; end if;
    if v_vehicle.company_is_active is not true then raise exception 'Aracin firmasi aktif degil.'; end if;
    if v_vehicle.player_id <> v_player_id and v_vehicle.is_available_for_rent is not true then raise exception 'Kiralik arac uygun degil.'; end if;
    if public.logistics_vehicle_matches_route(v_vehicle.route_city_a_id, v_vehicle.route_city_b_id, v_listing.market_city_id, v_store_slot.store_city_id) is not true then
      raise exception 'Bu arac secilen sehir cifti icin atanmis degil.';
    end if;
    v_fuel_used := ceil(v_distance_km * v_vehicle.fuel_rate);
    v_condition_loss := ceil(v_distance_km * 0.02);
    if v_vehicle.capacity < v_required_capacity then raise exception 'Arac kapasitesi yetersiz.'; end if;
    if v_vehicle.current_fuel < v_fuel_used then raise exception 'Aracin yakiti yetersiz.'; end if;
    if v_vehicle.condition <= v_condition_loss then raise exception 'Aracin kondisyonu yetersiz.'; end if;
    v_rental_cost := case when v_vehicle.player_id <> v_player_id then ceil(v_distance_km * coalesce(v_vehicle.rental_price, 0)) else 0 end;
    v_transport_cost := v_rental_cost;
    v_duration_seconds := greatest(1, ceil(((v_distance_km / greatest(v_vehicle.speed_kmh, 1)) / 4.0) * 3600));
    v_finish_at := timezone('utc'::text, now()) + make_interval(secs => v_duration_seconds);
  end if;

  if coalesce(v_player.cash, 0) < (v_total_price + v_rental_cost) then
    raise exception 'Kiralik arac ve satin alma icin yeterli nakit yok.';
  end if;

  update public.wholesale_market_listings set quantity = quantity - p_quantity,
    status = case when quantity - p_quantity <= 0 then 'completed' else status end, updated_at = timezone('utc'::text, now())
  where id = p_market_listing_id;
  update public.players set cash = cash - v_total_price where id = v_player_id;
  update public.players set cash = cash + v_total_price where id = v_listing.seller_player_id;

  if v_rental_cost > 0 then
    update public.players set cash = cash - v_rental_cost where id = v_player_id;
    if p_vehicle_id <> '00000000-0000-0000-0000-000000000000' then
      update public.players set cash = cash + v_rental_cost where id = v_vehicle.player_id;
    end if;
  end if;

  if p_vehicle_id <> '00000000-0000-0000-0000-000000000000' then
    update public.logistics_vehicles
    set current_fuel = greatest(current_fuel - v_fuel_used::integer, 0),
        condition = greatest(condition - v_condition_loss::integer, 0),
        status = 'on_route', updated_at = timezone('utc'::text, now())
    where id = p_vehicle_id;
  end if;

  update public.store_slots set pending_quantity = coalesce(pending_quantity, 0) + p_quantity, updated_at = timezone('utc'::text, now())
  where id = p_store_slot_id;

  insert into public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_store_id, buyer_store_slot_id, market_listing_id,
    logistics_vehicle_id, vehicle_owner_player_id, is_rental,
    product_id, quality_level, quantity, unit_price, total_price, product_unit_volume,
    reserved_capacity_amount, distance_km, fuel_used, condition_loss, rental_cost, transport_cost,
    transfer_type, started_at, finish_at, status, updated_at
  )
  values (
    v_player_id, v_listing.seller_player_id, v_store_slot.buyer_store_id, p_store_slot_id, p_market_listing_id,
    case when p_vehicle_id = '00000000-0000-0000-0000-000000000000' then null else p_vehicle_id end,
    case when p_vehicle_id = '00000000-0000-0000-0000-000000000000' then null else v_vehicle.player_id end,
    (p_vehicle_id <> '00000000-0000-0000-0000-000000000000' and v_vehicle.player_id <> v_player_id),
    v_listing.product_id, v_listing.quality_level, p_quantity, v_listing.unit_price, v_total_price,
    v_product.birim_hacim, p_quantity, v_distance_km, v_fuel_used, v_condition_loss,
    v_rental_cost, v_transport_cost, 'market_to_store',
    timezone('utc'::text, now()), v_finish_at, 'in_transit', timezone('utc'::text, now())
  )
  returning id into v_transfer_id;

  return jsonb_build_object(
    'success', true, 'mode', 'transfer', 'transfer_id', v_transfer_id,
    'vehicle_id', p_vehicle_id, 'store_slot_id', p_store_slot_id,
    'product_id', v_listing.product_id, 'quality_level', v_listing.quality_level,
    'quantity', p_quantity, 'rental_cost', v_rental_cost, 'transport_cost', v_transport_cost,
    'distance_km', round(v_distance_km, 2), 'fuel_used', v_fuel_used,
    'condition_loss', v_condition_loss, 'duration_seconds', v_duration_seconds, 'finish_at', v_finish_at
  );
end;
$$;


ALTER FUNCTION "public"."start_market_to_store_transfer"("p_market_listing_id" "uuid", "p_store_slot_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_market_transfer"("p_buyer_warehouse_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
      buyer_player_id, seller_player_id, buyer_warehouse_id, seller_warehouse_id,
      seller_warehouse_slot_id, logistics_vehicle_id, vehicle_owner_player_id, is_rental,
      product_id, quality_level, quantity, unit_price, total_price, product_unit_volume,
      reserved_capacity_amount, distance_km, fuel_used, condition_loss, rental_cost,
      transport_cost, started_at, finish_at, completed_at, status, updated_at
    )
    values (
      v_buyer_id, v_seller_slot.seller_player_id, p_buyer_warehouse_id, v_seller_slot.seller_warehouse_id,
      p_seller_slot_id, null, null, false,
      v_seller_slot.product_id, v_seller_slot.quality_level, p_quantity, v_unit_price, v_total_price, v_product.birim_hacim,
      0, 0, 0, 0, 0,
      0, v_now, v_now, v_now, 'completed', v_now
    )
    returning id into v_transfer_id;

    return jsonb_build_object(
      'success', true, 'mode', 'instant', 'transfer_id', v_transfer_id,
      'warehouse_result', v_add_result, 'seller_slot_id', p_seller_slot_id,
      'product_id', v_seller_slot.product_id, 'quality_level', v_seller_slot.quality_level,
      'quantity', p_quantity, 'unit_price', v_unit_price, 'total_price', v_total_price
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

  if p_vehicle_id = '00000000-0000-0000-0000-000000000000' then
    select '00000000-0000-0000-0000-000000000000'::uuid as player_id into v_vehicle;
    v_rental_cost := ceil(v_distance_km * 5.0);
    v_transport_cost := v_rental_cost;
    v_duration_seconds := greatest(1, ceil(((v_distance_km / 60.0) / 4.0) * 3600))::integer;
    v_finish_at := timezone('utc'::text, now()) + make_interval(secs => v_duration_seconds);
  else
    select lv.*, lc.is_active as company_is_active
    into v_vehicle
    from public.logistics_vehicles lv
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where lv.id = p_vehicle_id
    for update;
    if not found then raise exception 'Arac bulunamadi.'; end if;
    if v_vehicle.player_id = v_seller_slot.seller_player_id then raise exception 'Saticinin araci kullanilamaz.'; end if;
    if v_vehicle.player_id <> v_buyer_id and v_vehicle.is_available_for_rent is not true then raise exception 'Kiralik arac uygun degil.'; end if;
    if v_vehicle.status <> 'idle' then raise exception 'Arac su anda uygun degil.'; end if;
    if v_vehicle.company_is_active is not true then raise exception 'Aracin firmasi aktif degil.'; end if;
    if public.logistics_vehicle_matches_route(v_vehicle.route_city_a_id, v_vehicle.route_city_b_id, v_seller_slot.seller_city_id, v_buyer_warehouse.city_id) is not true then
      raise exception 'Bu arac secilen sehir cifti icin atanmis degil.';
    end if;
    v_fuel_used := ceil(v_distance_km * v_vehicle.fuel_rate);
    v_condition_loss := ceil(v_distance_km * 0.02);
    if v_vehicle.capacity < v_required_capacity then raise exception 'Arac kapasitesi yetersiz.'; end if;
    if v_vehicle.current_fuel < v_fuel_used then raise exception 'Aracin yakiti yetersiz.'; end if;
    if v_vehicle.condition <= v_condition_loss then raise exception 'Aracin kondisyonu yetersiz.'; end if;
    v_rental_cost := case when v_vehicle.player_id <> v_buyer_id then ceil(v_distance_km * coalesce(v_vehicle.rental_price, 0)) else 0 end;
    v_transport_cost := v_rental_cost;
    v_duration_seconds := greatest(1, ceil(((v_distance_km / greatest(v_vehicle.speed_kmh, 1)) / 4.0) * 3600));
    v_finish_at := timezone('utc'::text, now()) + make_interval(secs => v_duration_seconds);
  end if;

  if coalesce(v_buyer_player.cash, 0) < (v_total_price + v_rental_cost) then
    raise exception 'Yeterli nakit yok.';
  end if;

  v_reserve_result := public.reserve_warehouse_capacity(v_buyer_id, p_buyer_warehouse_id, v_seller_slot.product_id, p_quantity);

  update public.warehouse_slots
  set quantity = quantity - p_quantity,
      is_available_for_sale = case when quantity - p_quantity > 0 then is_available_for_sale else false end,
      updated_at = timezone('utc'::text, now())
  where id = p_seller_slot_id;

  update public.players set cash = cash - (v_total_price + v_rental_cost) where id = v_buyer_id;
  update public.players set cash = cash + v_total_price where id = v_seller_slot.seller_player_id;

  if v_rental_cost > 0 and p_vehicle_id <> '00000000-0000-0000-0000-000000000000' then
    update public.players set cash = cash + v_rental_cost where id = v_vehicle.player_id;
  end if;

  if p_vehicle_id <> '00000000-0000-0000-0000-000000000000' then
    update public.logistics_vehicles
    set current_fuel = greatest(current_fuel - v_fuel_used::integer, 0),
        condition = greatest(condition - v_condition_loss::integer, 0),
        status = 'on_route',
        updated_at = timezone('utc'::text, now())
    where id = p_vehicle_id;
  end if;

  insert into public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_warehouse_id, seller_warehouse_id,
    seller_warehouse_slot_id, logistics_vehicle_id, vehicle_owner_player_id, is_rental,
    product_id, quality_level, quantity, unit_price, total_price, product_unit_volume,
    reserved_capacity_amount, distance_km, fuel_used, condition_loss, rental_cost,
    transport_cost, started_at, finish_at, status, updated_at
  )
  values (
    v_buyer_id, v_seller_slot.seller_player_id, p_buyer_warehouse_id, v_seller_slot.seller_warehouse_id,
    p_seller_slot_id,
    case when p_vehicle_id = '00000000-0000-0000-0000-000000000000' then null else p_vehicle_id end,
    case when p_vehicle_id = '00000000-0000-0000-0000-000000000000' then null else v_vehicle.player_id end,
    (p_vehicle_id <> '00000000-0000-0000-0000-000000000000' and v_vehicle.player_id <> v_buyer_id),
    v_seller_slot.product_id, v_seller_slot.quality_level, p_quantity, v_unit_price, v_total_price,
    v_product.birim_hacim, v_required_capacity, v_distance_km, v_fuel_used, v_condition_loss,
    v_rental_cost, v_transport_cost, timezone('utc'::text, now()), v_finish_at, 'in_transit', timezone('utc'::text, now())
  )
  returning id into v_transfer_id;

  return jsonb_build_object(
    'success', true, 'transfer_id', v_transfer_id, 'vehicle_id', p_vehicle_id,
    'seller_slot_id', p_seller_slot_id, 'product_id', v_seller_slot.product_id,
    'quality_level', v_seller_slot.quality_level, 'quantity', p_quantity,
    'unit_price', v_unit_price, 'total_price', v_total_price,
    'rental_cost', v_rental_cost, 'transport_cost', v_transport_cost,
    'distance_km', round(v_distance_km, 2), 'fuel_used', v_fuel_used,
    'condition_loss', v_condition_loss, 'reserved_capacity_amount', v_required_capacity,
    'duration_seconds', v_duration_seconds, 'finish_at', v_finish_at,
    'reserve_result', v_reserve_result
  );
end;
$$;


ALTER FUNCTION "public"."start_market_transfer"("p_buyer_warehouse_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_production_to_warehouse_transfer"("p_production_inventory_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
  if v_player_id is null then raise exception 'Oturum acilmamis.'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Miktar 0''dan buyuk olmalidir.'; end if;

  select * into v_player from public.players where id = v_player_id for update;
  if not found then raise exception 'Oyuncu bulunamadi.'; end if;

  select * into v_inventory from public.production_inventory where id = p_production_inventory_id for update;
  if not found then raise exception 'Production inventory bulunamadi.'; end if;
  if v_inventory.inventory_type <> 'output' then raise exception 'Sadece output inventory icin output lojistigi desteklenir.'; end if;
  if v_inventory.owner_kind not in ('factory', 'field', 'farm', 'mine') then
    raise exception 'Bu owner_kind icin output lojistigi desteklenmiyor: %', v_inventory.owner_kind;
  end if;
  if coalesce(v_inventory.quantity, 0) < p_quantity then raise exception 'Istenen miktar mevcut output stoktan fazla.'; end if;

  if v_inventory.owner_kind = 'factory' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id from public.factories where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'field' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id from public.fields where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'farm' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id from public.farms where id = v_inventory.owner_id;
  else
    select player_id, city_id into v_owner_player_id, v_owner_city_id from public.mines where id = v_inventory.owner_id;
  end if;

  if v_owner_player_id is null then raise exception 'Kaynak uretim birimi bulunamadi.'; end if;
  if v_owner_player_id <> v_player_id then raise exception 'Kaynak uretim birimi size ait degil.'; end if;

  select w.*, c.map_position_x as city_x, c.map_position_y as city_y
  into v_buyer_warehouse
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  where w.id = p_buyer_warehouse_id and w.player_id = v_player_id for update;

  if not found then raise exception 'Hedef depo bulunamadi veya size ait degil.'; end if;
  if v_buyer_warehouse.is_active is not true then raise exception 'Hedef depo aktif degil.'; end if;

  select * into v_product from public.products where id = v_inventory.product_id;
  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then raise exception 'Urun hacim bilgisi gecersiz.'; end if;

  if v_buyer_warehouse.city_id = v_owner_city_id then
    v_instant_result := public.transfer_production_inventory_to_warehouse(v_player_id, p_production_inventory_id, p_buyer_warehouse_id, p_quantity);
    return jsonb_build_object('success', true, 'message', 'Ayni sehir transferi aninda tamamlandi.', 'transfer_id', null, 'mode', 'instant', 'result', v_instant_result);
  end if;

  if p_vehicle_id is null then raise exception 'Farkli sehir transferi icin arac secilmelidir.'; end if;

  select * into v_source_city from public.cities where id = v_owner_city_id;
  if not found then raise exception 'Kaynak sehir bulunamadi.'; end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_source_city.map_position_x - v_buyer_warehouse.city_x) / 2)), 2)
      + cos(radians(v_buyer_warehouse.city_x)) * cos(radians(v_source_city.map_position_x))
      * power(sin(radians((v_source_city.map_position_y - v_buyer_warehouse.city_y) / 2)), 2)
    )
  );

  if p_vehicle_id = '00000000-0000-0000-0000-000000000000' then
    select '00000000-0000-0000-0000-000000000000'::uuid as player_id into v_vehicle;
    v_rental_cost := ceil(v_distance_km * 5.0);
    v_transport_cost := v_rental_cost;
    v_duration_seconds := greatest(1, ceil(((v_distance_km / 60.0) / 4.0) * 3600))::integer;
    v_finish_at := v_now + make_interval(secs => v_duration_seconds);
    v_fuel_used := 0;
    v_condition_loss := 0;
  else
    select lv.*, lc.is_active as company_is_active into v_vehicle
    from public.logistics_vehicles lv
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where lv.id = p_vehicle_id for update;
    if not found then raise exception 'Arac bulunamadi.'; end if;
    if v_vehicle.status <> 'idle' then raise exception 'Arac su anda uygun degil.'; end if;
    if v_vehicle.company_is_active is not true then raise exception 'Aracin firmasi aktif degil.'; end if;
    if v_vehicle.player_id <> v_player_id and v_vehicle.is_available_for_rent is not true then raise exception 'Kiralik arac uygun degil.'; end if;
    if public.logistics_vehicle_matches_route(v_vehicle.route_city_a_id, v_vehicle.route_city_b_id, v_owner_city_id, v_buyer_warehouse.city_id) is not true then
      raise exception 'Bu arac secilen sehir cifti icin atanmis degil.';
    end if;
    v_fuel_used := ceil(v_distance_km * v_vehicle.fuel_rate);
    v_condition_loss := ceil(v_distance_km * 0.02);
    if v_vehicle.capacity < v_required_capacity then raise exception 'Arac kapasitesi yetersiz.'; end if;
    if v_vehicle.current_fuel < v_fuel_used then raise exception 'Aracin yakiti yetersiz.'; end if;
    if v_vehicle.condition <= v_condition_loss then raise exception 'Aracin kondisyonu yetersiz.'; end if;
    v_rental_cost := case when v_vehicle.player_id <> v_player_id then ceil(v_distance_km * coalesce(v_vehicle.rental_price, 0)) else 0 end;
    v_transport_cost := v_rental_cost;
    v_duration_seconds := greatest(1, ceil(((v_distance_km / greatest(v_vehicle.speed_kmh, 1)) / 4.0) * 3600));
    v_finish_at := v_now + make_interval(secs => v_duration_seconds);
  end if;

  if coalesce(v_player.cash, 0) < v_rental_cost then raise exception 'Kiralik arac icin yeterli nakit yok.'; end if;

  v_reserve_result := public.reserve_warehouse_capacity(v_player_id, p_buyer_warehouse_id, v_inventory.product_id, p_quantity);

  update public.production_inventory set quantity = quantity - p_quantity where id = p_production_inventory_id;

  if v_rental_cost > 0 then
    update public.players set cash = cash - v_rental_cost where id = v_player_id;
    if p_vehicle_id <> '00000000-0000-0000-0000-000000000000' then
      update public.players set cash = cash + v_rental_cost where id = v_vehicle.player_id;
    end if;
  end if;

  if p_vehicle_id <> '00000000-0000-0000-0000-000000000000' then
    update public.logistics_vehicles
    set current_fuel = greatest(current_fuel - v_fuel_used::integer, 0),
        condition = greatest(condition - v_condition_loss::integer, 0),
        status = 'on_route', updated_at = v_now
    where id = p_vehicle_id;
  end if;

  insert into public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_warehouse_id, seller_production_inventory_id,
    logistics_vehicle_id, vehicle_owner_player_id, is_rental,
    product_id, quality_level, quantity, unit_price, total_price, product_unit_volume,
    reserved_capacity_amount, distance_km, fuel_used, condition_loss, rental_cost, transport_cost,
    transfer_type, seller_entity_kind, buyer_entity_kind, started_at, finish_at, status, updated_at
  )
  values (
    v_player_id, v_player_id, p_buyer_warehouse_id, p_production_inventory_id,
    case when p_vehicle_id = '00000000-0000-0000-0000-000000000000' then null else p_vehicle_id end,
    case when p_vehicle_id = '00000000-0000-0000-0000-000000000000' then null else v_vehicle.player_id end,
    (p_vehicle_id <> '00000000-0000-0000-0000-000000000000' and v_vehicle.player_id <> v_player_id),
    v_inventory.product_id, v_inventory.quality_level, p_quantity, coalesce(v_inventory.cost, 0), 0,
    v_product.birim_hacim, coalesce((v_reserve_result->>'reserved_added')::numeric, 0),
    v_distance_km, v_fuel_used, v_condition_loss, v_rental_cost, v_transport_cost,
    'production_to_warehouse', 'production_inventory', 'warehouse',
    v_now, v_finish_at, 'in_transit', v_now
  )
  returning id into v_transfer_id;

  return jsonb_build_object('success', true, 'message', 'Output lojistigi transferi baslatildi.', 'transfer_id', v_transfer_id, 'mode', 'transfer');
end;
$$;


ALTER FUNCTION "public"."start_production_to_warehouse_transfer"("p_production_inventory_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_store_to_warehouse_transfer"("p_store_slot_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
      v_player_id, p_buyer_warehouse_id, v_store_slot.product_id,
      v_store_slot.quality_level, p_quantity, v_unit_cost, 0, false
    );

    insert into public.logistics_transfers (
      buyer_player_id, seller_player_id, buyer_warehouse_id, seller_store_id,
      seller_store_slot_id, logistics_vehicle_id, vehicle_owner_player_id, is_rental,
      product_id, quality_level, quantity, unit_price, total_price, product_unit_volume,
      reserved_capacity_amount, distance_km, fuel_used, condition_loss, rental_cost,
      transport_cost, transfer_type, started_at, finish_at, completed_at, status, updated_at
    )
    values (
      v_player_id, v_player_id, p_buyer_warehouse_id, v_store_slot.seller_store_id,
      p_store_slot_id, null, null, false,
      v_store_slot.product_id, v_store_slot.quality_level, p_quantity, v_unit_cost,
      p_quantity * v_unit_cost, v_product.birim_hacim, 0, 0, 0, 0, 0, 0,
      'store_to_warehouse', v_now, v_now, v_now, 'completed', v_now
    )
    returning id into v_transfer_id;

    return jsonb_build_object(
      'success', true, 'mode', 'instant', 'transfer_id', v_transfer_id,
      'warehouse_result', v_add_result, 'warehouse_id', p_buyer_warehouse_id,
      'store_slot_id', p_store_slot_id, 'product_id', v_store_slot.product_id,
      'quality_level', v_store_slot.quality_level, 'quantity', p_quantity
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

  if p_vehicle_id = '00000000-0000-0000-0000-000000000000' then
    select '00000000-0000-0000-0000-000000000000'::uuid as player_id into v_vehicle;
    v_rental_cost := ceil(v_distance_km * 5.0);
    v_transport_cost := v_rental_cost;
    v_duration_seconds := greatest(1, ceil(((v_distance_km / 60.0) / 4.0) * 3600))::integer;
    v_finish_at := timezone('utc'::text, now()) + make_interval(secs => v_duration_seconds);
  else
    select lv.*, lc.is_active as company_is_active
    into v_vehicle
    from public.logistics_vehicles lv
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where lv.id = p_vehicle_id
    for update;
    if not found then raise exception 'Arac bulunamadi.'; end if;
    if v_vehicle.status <> 'idle' then raise exception 'Arac su anda uygun degil.'; end if;
    if v_vehicle.company_is_active is not true then raise exception 'Aracin firmasi aktif degil.'; end if;
    if v_vehicle.player_id <> v_player_id and v_vehicle.is_available_for_rent is not true then raise exception 'Kiralik arac uygun degil.'; end if;
    if public.logistics_vehicle_matches_route(v_vehicle.route_city_a_id, v_vehicle.route_city_b_id, v_store_slot.store_city_id, v_buyer_warehouse.city_id) is not true then
      raise exception 'Bu arac secilen sehir cifti icin atanmis degil.';
    end if;
    v_fuel_used := ceil(v_distance_km * v_vehicle.fuel_rate);
    v_condition_loss := ceil(v_distance_km * 0.02);
    if v_vehicle.capacity < v_required_capacity then raise exception 'Arac kapasitesi yetersiz.'; end if;
    if v_vehicle.current_fuel < v_fuel_used then raise exception 'Aracin yakiti yetersiz.'; end if;
    if v_vehicle.condition <= v_condition_loss then raise exception 'Aracin kondisyonu yetersiz.'; end if;
    v_rental_cost := case when v_vehicle.player_id <> v_player_id then ceil(v_distance_km * coalesce(v_vehicle.rental_price, 0)) else 0 end;
    v_transport_cost := v_rental_cost;
    v_duration_seconds := greatest(1, ceil(((v_distance_km / greatest(v_vehicle.speed_kmh, 1)) / 4.0) * 3600));
    v_finish_at := timezone('utc'::text, now()) + make_interval(secs => v_duration_seconds);
  end if;

  if coalesce(v_player.cash, 0) < v_rental_cost then
    raise exception 'Kiralik arac icin yeterli nakit yok.';
  end if;

  v_reserve_result := public.reserve_warehouse_capacity(v_player_id, p_buyer_warehouse_id, v_store_slot.product_id, p_quantity);

  update public.store_slots
  set quantity = quantity - p_quantity, updated_at = timezone('utc'::text, now())
  where id = p_store_slot_id;

  if v_rental_cost > 0 then
    update public.players set cash = cash - v_rental_cost where id = v_player_id;
    if p_vehicle_id <> '00000000-0000-0000-0000-000000000000' then
      update public.players set cash = cash + v_rental_cost where id = v_vehicle.player_id;
    end if;
  end if;

  if p_vehicle_id <> '00000000-0000-0000-0000-000000000000' then
    update public.logistics_vehicles
    set current_fuel = greatest(current_fuel - v_fuel_used::integer, 0),
        condition = greatest(condition - v_condition_loss::integer, 0),
        status = 'on_route',
        updated_at = timezone('utc'::text, now())
    where id = p_vehicle_id;
  end if;

  insert into public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_warehouse_id, seller_store_id,
    seller_store_slot_id, logistics_vehicle_id, vehicle_owner_player_id, is_rental,
    product_id, quality_level, quantity, unit_price, total_price, product_unit_volume,
    reserved_capacity_amount, distance_km, fuel_used, condition_loss, rental_cost,
    transport_cost, transfer_type, started_at, finish_at, status, updated_at
  )
  values (
    v_player_id, v_player_id, p_buyer_warehouse_id, v_store_slot.seller_store_id,
    p_store_slot_id,
    case when p_vehicle_id = '00000000-0000-0000-0000-000000000000' then null else p_vehicle_id end,
    case when p_vehicle_id = '00000000-0000-0000-0000-000000000000' then null else v_vehicle.player_id end,
    (p_vehicle_id <> '00000000-0000-0000-0000-000000000000' and v_vehicle.player_id <> v_player_id),
    v_store_slot.product_id, v_store_slot.quality_level, p_quantity, v_unit_cost, 0,
    v_product.birim_hacim, p_quantity, v_distance_km, v_fuel_used, v_condition_loss,
    v_rental_cost, v_transport_cost, 'store_to_warehouse',
    timezone('utc'::text, now()), v_finish_at, 'in_transit', timezone('utc'::text, now())
  )
  returning id into v_transfer_id;

  return jsonb_build_object(
    'success', true, 'mode', 'transfer', 'transfer_id', v_transfer_id,
    'vehicle_id', p_vehicle_id, 'warehouse_id', p_buyer_warehouse_id,
    'store_slot_id', p_store_slot_id, 'product_id', v_store_slot.product_id,
    'quality_level', v_store_slot.quality_level, 'quantity', p_quantity,
    'rental_cost', v_rental_cost, 'transport_cost', v_transport_cost,
    'distance_km', round(v_distance_km, 2), 'fuel_used', v_fuel_used,
    'condition_loss', v_condition_loss, 'duration_seconds', v_duration_seconds,
    'finish_at', v_finish_at, 'reserve_result', v_reserve_result
  );
end;
$$;


ALTER FUNCTION "public"."start_store_to_warehouse_transfer"("p_store_slot_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_warehouse_to_production_transfer"("p_warehouse_slot_id" "uuid", "p_production_inventory_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
  if v_player_id is null then raise exception 'Oturum acilmamis.'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Miktar 0''dan buyuk olmalidir.'; end if;

  select * into v_player from public.players where id = v_player_id for update;
  if not found then raise exception 'Oyuncu bulunamadi.'; end if;

  select ws.*, w.player_id, w.id as warehouse_id, w.city_id, w.is_active as warehouse_is_active,
         c.map_position_x as city_x, c.map_position_y as city_y
  into v_warehouse_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  join public.cities c on c.id = w.city_id
  where ws.id = p_warehouse_slot_id for update;

  if not found or v_warehouse_slot.player_id <> v_player_id then raise exception 'Depo slotu bulunamadi veya size ait degil.'; end if;
  if v_warehouse_slot.warehouse_is_active is not true then raise exception 'Kaynak depo aktif degil.'; end if;
  if p_quantity > coalesce(v_warehouse_slot.quantity, 0) then raise exception 'Istenen miktar mevcut stoktan fazla.'; end if;

  select * into v_inventory from public.production_inventory where id = p_production_inventory_id for update;
  if not found then raise exception 'Production inventory bulunamadi.'; end if;
  if v_inventory.inventory_type <> 'input' then raise exception 'Sadece input inventory icin hammadde lojistigi desteklenir.'; end if;
  if v_inventory.owner_kind not in ('factory', 'field', 'farm') then
    raise exception 'Bu owner_kind icin input lojistigi desteklenmiyor: %', v_inventory.owner_kind;
  end if;

  if v_inventory.owner_kind = 'factory' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id from public.factories where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'field' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id from public.fields where id = v_inventory.owner_id;
  else
    select player_id, city_id into v_owner_player_id, v_owner_city_id from public.farms where id = v_inventory.owner_id;
  end if;

  if v_owner_player_id is null then raise exception 'Hedef uretim birimi bulunamadi.'; end if;
  if v_owner_player_id <> v_player_id then raise exception 'Hedef uretim birimi size ait degil.'; end if;
  if v_inventory.product_id <> v_warehouse_slot.product_id then raise exception 'Depo slotundaki urun ile input inventory urunu ayni olmalidir.'; end if;
  if v_inventory.quality_level <> v_warehouse_slot.quality_level then raise exception 'Depo slotundaki kalite ile input inventory kalitesi ayni olmalidir.'; end if;

  select * into v_product from public.products where id = v_warehouse_slot.product_id;
  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then raise exception 'Urun hacim bilgisi gecersiz.'; end if;

  if v_owner_city_id = v_warehouse_slot.city_id then
    v_instant_result := public.transfer_warehouse_slot_to_production_inventory(v_player_id, p_warehouse_slot_id, p_production_inventory_id, p_quantity);
    return jsonb_build_object('success', true, 'message', 'Ayni sehir transferi aninda tamamlandi.', 'transfer_id', null, 'mode', 'instant', 'result', v_instant_result);
  end if;

  if p_vehicle_id is null then raise exception 'Farkli sehir transferi icin arac secilmelidir.'; end if;

  select * into v_target_city from public.cities where id = v_owner_city_id;
  if not found then raise exception 'Hedef sehir bulunamadi.'; end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_warehouse_slot.city_x - v_target_city.map_position_x) / 2)), 2)
      + cos(radians(v_target_city.map_position_x)) * cos(radians(v_warehouse_slot.city_x))
      * power(sin(radians((v_warehouse_slot.city_y - v_target_city.map_position_y) / 2)), 2)
    )
  );

  if p_vehicle_id = '00000000-0000-0000-0000-000000000000' then
    select '00000000-0000-0000-0000-000000000000'::uuid as player_id into v_vehicle;
    v_rental_cost := ceil(v_distance_km * 5.0);
    v_transport_cost := v_rental_cost;
    v_duration_seconds := greatest(1, ceil(((v_distance_km / 60.0) / 4.0) * 3600))::integer;
    v_finish_at := v_now + make_interval(secs => v_duration_seconds);
    v_fuel_used := 0;
    v_condition_loss := 0;
  else
    select lv.*, lc.is_active as company_is_active into v_vehicle
    from public.logistics_vehicles lv
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where lv.id = p_vehicle_id for update;
    if not found then raise exception 'Arac bulunamadi.'; end if;
    if v_vehicle.status <> 'idle' then raise exception 'Arac su anda uygun degil.'; end if;
    if v_vehicle.company_is_active is not true then raise exception 'Aracin firmasi aktif degil.'; end if;
    if v_vehicle.player_id <> v_player_id and v_vehicle.is_available_for_rent is not true then raise exception 'Kiralik arac uygun degil.'; end if;
    if public.logistics_vehicle_matches_route(v_vehicle.route_city_a_id, v_vehicle.route_city_b_id, v_warehouse_slot.city_id, v_owner_city_id) is not true then
      raise exception 'Bu arac secilen sehir cifti icin atanmis degil.';
    end if;
    v_fuel_used := ceil(v_distance_km * v_vehicle.fuel_rate);
    v_condition_loss := ceil(v_distance_km * 0.02);
    if v_vehicle.capacity < v_required_capacity then raise exception 'Arac kapasitesi yetersiz.'; end if;
    if v_vehicle.current_fuel < v_fuel_used then raise exception 'Aracin yakiti yetersiz.'; end if;
    if v_vehicle.condition <= v_condition_loss then raise exception 'Aracin kondisyonu yetersiz.'; end if;
    v_rental_cost := case when v_vehicle.player_id <> v_player_id then ceil(v_distance_km * coalesce(v_vehicle.rental_price, 0)) else 0 end;
    v_transport_cost := v_rental_cost;
    v_duration_seconds := greatest(1, ceil(((v_distance_km / greatest(v_vehicle.speed_kmh, 1)) / 4.0) * 3600));
    v_finish_at := v_now + make_interval(secs => v_duration_seconds);
  end if;

  if coalesce(v_player.cash, 0) < v_rental_cost then raise exception 'Kiralik arac icin yeterli nakit yok.'; end if;

  update public.warehouse_slots set quantity = quantity - p_quantity, updated_at = v_now where id = p_warehouse_slot_id;
  update public.production_inventory set pending_quantity = coalesce(pending_quantity, 0) + p_quantity where id = p_production_inventory_id;

  if v_rental_cost > 0 then
    update public.players set cash = cash - v_rental_cost where id = v_player_id;
    if p_vehicle_id <> '00000000-0000-0000-0000-000000000000' then
      update public.players set cash = cash + v_rental_cost where id = v_vehicle.player_id;
    end if;
  end if;

  if p_vehicle_id <> '00000000-0000-0000-0000-000000000000' then
    update public.logistics_vehicles
    set current_fuel = greatest(current_fuel - v_fuel_used::integer, 0),
        condition = greatest(condition - v_condition_loss::integer, 0),
        status = 'on_route', updated_at = v_now
    where id = p_vehicle_id;
  end if;

  insert into public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_production_inventory_id, seller_warehouse_id, seller_warehouse_slot_id,
    logistics_vehicle_id, vehicle_owner_player_id, is_rental,
    product_id, quality_level, quantity, unit_price, total_price, product_unit_volume,
    reserved_capacity_amount, distance_km, fuel_used, condition_loss, rental_cost, transport_cost,
    transfer_type, seller_entity_kind, buyer_entity_kind, started_at, finish_at, status, updated_at
  )
  values (
    v_player_id, v_player_id, p_production_inventory_id, v_warehouse_slot.warehouse_id, p_warehouse_slot_id,
    case when p_vehicle_id = '00000000-0000-0000-0000-000000000000' then null else p_vehicle_id end,
    case when p_vehicle_id = '00000000-0000-0000-0000-000000000000' then null else v_vehicle.player_id end,
    (p_vehicle_id <> '00000000-0000-0000-0000-000000000000' and v_vehicle.player_id <> v_player_id),
    v_warehouse_slot.product_id, v_warehouse_slot.quality_level, p_quantity, coalesce(v_warehouse_slot.cost, 0), 0,
    v_product.birim_hacim, 0, v_distance_km, v_fuel_used, v_condition_loss, v_rental_cost, v_transport_cost,
    'warehouse_to_production', 'warehouse', 'production_inventory',
    v_now, v_finish_at, 'in_transit', v_now
  )
  returning id into v_transfer_id;

  return jsonb_build_object('success', true, 'message', 'Uretim lojistigi transferi baslatildi.', 'transfer_id', v_transfer_id, 'mode', 'transfer');
end;
$$;


ALTER FUNCTION "public"."start_warehouse_to_production_transfer"("p_warehouse_slot_id" "uuid", "p_production_inventory_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_warehouse_to_store_transfer"("p_store_slot_id" "uuid", "p_warehouse_slot_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
  if v_player_id is null then raise exception 'Oturum acilmamis.'; end if;
  if p_quantity is null or p_quantity <= 0 then raise exception 'Miktar 0''dan buyuk olmalidir.'; end if;

  select * into v_player from public.players where id = v_player_id for update;
  if not found then raise exception 'Oyuncu bulunamadi.'; end if;

  select ss.*, s.player_id, s.id as buyer_store_id, s.is_active as store_is_active,
         s.city_id as store_city_id, c.map_position_x as city_x, c.map_position_y as city_y
  into v_store_slot
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  join public.cities c on c.id = s.city_id
  where ss.id = p_store_slot_id for update;

  if not found or v_store_slot.player_id <> v_player_id then raise exception 'Magaza slotu bulunamadi veya size ait degil.'; end if;
  if v_store_slot.store_is_active is not true then raise exception 'Magaza aktif degil.'; end if;

  select ws.*, w.player_id as warehouse_player_id, w.id as seller_warehouse_id,
         w.city_id as warehouse_city_id,
         c.map_position_x as city_x, c.map_position_y as city_y
  into v_warehouse_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  join public.cities c on c.id = w.city_id
  where ws.id = p_warehouse_slot_id for update;

  if not found or v_warehouse_slot.warehouse_player_id <> v_player_id then raise exception 'Depo slotu bulunamadi veya size ait degil.'; end if;
  if p_quantity > v_warehouse_slot.quantity then raise exception 'Istenen miktar mevcut stoktan fazla.'; end if;

  if v_store_slot.product_id is null or v_store_slot.quality_level = 0 then
    if coalesce(v_store_slot.quantity, 0) > 0 or coalesce(v_store_slot.pending_quantity, 0) > 0 then
      raise exception 'Slotta aktif stok veya rezerve varken urun atanamaz.';
    end if;
    update public.store_slots set product_id = v_warehouse_slot.product_id, quality_level = v_warehouse_slot.quality_level, updated_at = v_now where id = p_store_slot_id;
    v_store_slot.product_id := v_warehouse_slot.product_id;
    v_store_slot.quality_level := v_warehouse_slot.quality_level;
  elsif v_store_slot.product_id <> v_warehouse_slot.product_id or v_store_slot.quality_level <> v_warehouse_slot.quality_level then
    raise exception 'Magaza slotu urun veya kalite uyusmazligi.';
  end if;

  if (coalesce(v_store_slot.quantity, 0) + coalesce(v_store_slot.pending_quantity, 0) + p_quantity) > v_store_slot.capacity then
    raise exception 'Magaza slot kapasitesi yetersiz.';
  end if;

  select * into v_product from public.products where id = v_warehouse_slot.product_id;
  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then raise exception 'Urun hacim bilgisi gecersiz.'; end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_unit_cost := coalesce(v_warehouse_slot.cost, 0);

  if v_store_slot.store_city_id = v_warehouse_slot.warehouse_city_id then
    v_new_cost := case
      when coalesce(v_store_slot.quantity, 0) + p_quantity > 0 then
        (coalesce(v_store_slot.quantity, 0) * coalesce(v_store_slot.cost, 0) + p_quantity * v_unit_cost)
        / (coalesce(v_store_slot.quantity, 0) + p_quantity)
      else coalesce(v_store_slot.cost, 0)
    end;
    update public.warehouse_slots set quantity = quantity - p_quantity, updated_at = v_now where id = p_warehouse_slot_id;
    update public.store_slots set quantity = quantity + p_quantity, cost = v_new_cost, updated_at = v_now where id = p_store_slot_id;
    insert into public.logistics_transfers (
      buyer_player_id, seller_player_id, buyer_store_id, buyer_store_slot_id, seller_warehouse_id, seller_warehouse_slot_id,
      logistics_vehicle_id, vehicle_owner_player_id, is_rental,
      product_id, quality_level, quantity, unit_price, total_price, product_unit_volume,
      reserved_capacity_amount, distance_km, fuel_used, condition_loss, rental_cost, transport_cost,
      transfer_type, started_at, finish_at, completed_at, status, updated_at
    )
    values (
      v_player_id, v_player_id, v_store_slot.buyer_store_id, p_store_slot_id,
      v_warehouse_slot.seller_warehouse_id, p_warehouse_slot_id,
      null, null, false,
      v_warehouse_slot.product_id, v_warehouse_slot.quality_level, p_quantity, v_unit_cost,
      p_quantity * v_unit_cost, v_product.birim_hacim, 0, 0, 0, 0, 0, 0,
      'warehouse_to_store', v_now, v_now, v_now, 'completed', v_now
    )
    returning id into v_transfer_id;
    return jsonb_build_object(
      'success', true, 'mode', 'instant', 'transfer_id', v_transfer_id,
      'store_slot_id', p_store_slot_id, 'warehouse_slot_id', p_warehouse_slot_id,
      'product_id', v_warehouse_slot.product_id, 'quality_level', v_warehouse_slot.quality_level,
      'quantity', p_quantity, 'transport_cost', 0, 'rental_cost', 0, 'new_cost', v_new_cost
    );
  end if;

  if p_vehicle_id is null then raise exception 'Farkli sehir transferi icin arac secilmelidir.'; end if;

  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_warehouse_slot.city_x - v_store_slot.city_x) / 2)), 2) +
      cos(radians(v_store_slot.city_x)) * cos(radians(v_warehouse_slot.city_x)) *
      power(sin(radians((v_warehouse_slot.city_y - v_store_slot.city_y) / 2)), 2)
    )
  );

  if p_vehicle_id = '00000000-0000-0000-0000-000000000000' then
    select '00000000-0000-0000-0000-000000000000'::uuid as player_id into v_vehicle;
    v_rental_cost := ceil(v_distance_km * 5.0);
    v_transport_cost := v_rental_cost;
    v_duration_seconds := greatest(1, ceil(((v_distance_km / 60.0) / 4.0) * 3600))::integer;
    v_finish_at := timezone('utc'::text, now()) + make_interval(secs => v_duration_seconds);
  else
    select lv.*, lc.is_active as company_is_active into v_vehicle
    from public.logistics_vehicles lv
    join public.logistics_companies lc on lc.id = lv.logistics_company_id
    where lv.id = p_vehicle_id for update;
    if not found then raise exception 'Arac bulunamadi.'; end if;
    if v_vehicle.status <> 'idle' then raise exception 'Arac su anda uygun degil.'; end if;
    if v_vehicle.company_is_active is not true then raise exception 'Aracin firmasi aktif degil.'; end if;
    if v_vehicle.player_id <> v_player_id and v_vehicle.is_available_for_rent is not true then raise exception 'Kiralik arac uygun degil.'; end if;
    if public.logistics_vehicle_matches_route(v_vehicle.route_city_a_id, v_vehicle.route_city_b_id, v_warehouse_slot.warehouse_city_id, v_store_slot.store_city_id) is not true then
      raise exception 'Bu arac secilen sehir cifti icin atanmis degil.';
    end if;
    v_fuel_used := ceil(v_distance_km * v_vehicle.fuel_rate);
    v_condition_loss := ceil(v_distance_km * 0.02);
    if v_vehicle.capacity < v_required_capacity then raise exception 'Arac kapasitesi yetersiz.'; end if;
    if v_vehicle.current_fuel < v_fuel_used then raise exception 'Aracin yakiti yetersiz.'; end if;
    if v_vehicle.condition <= v_condition_loss then raise exception 'Aracin kondisyonu yetersiz.'; end if;
    v_rental_cost := case when v_vehicle.player_id <> v_player_id then ceil(v_distance_km * coalesce(v_vehicle.rental_price, 0)) else 0 end;
    v_transport_cost := v_rental_cost;
    v_duration_seconds := greatest(1, ceil(((v_distance_km / greatest(v_vehicle.speed_kmh, 1)) / 4.0) * 3600));
    v_finish_at := timezone('utc'::text, now()) + make_interval(secs => v_duration_seconds);
  end if;

  if coalesce(v_player.cash, 0) < v_rental_cost then raise exception 'Kiralik arac icin yeterli nakit yok.'; end if;

  update public.warehouse_slots set quantity = quantity - p_quantity, updated_at = timezone('utc'::text, now()) where id = p_warehouse_slot_id;

  if v_rental_cost > 0 then
    update public.players set cash = cash - v_rental_cost where id = v_player_id;
    if p_vehicle_id <> '00000000-0000-0000-0000-000000000000' then
      update public.players set cash = cash + v_rental_cost where id = v_vehicle.player_id;
    end if;
  end if;

  if p_vehicle_id <> '00000000-0000-0000-0000-000000000000' then
    update public.logistics_vehicles
    set current_fuel = greatest(current_fuel - v_fuel_used::integer, 0),
        condition = greatest(condition - v_condition_loss::integer, 0),
        status = 'on_route', updated_at = timezone('utc'::text, now())
    where id = p_vehicle_id;
  end if;

  update public.store_slots set pending_quantity = coalesce(pending_quantity, 0) + p_quantity, updated_at = timezone('utc'::text, now())
  where id = p_store_slot_id;

  insert into public.logistics_transfers (
    buyer_player_id, seller_player_id, buyer_warehouse_id, buyer_store_id, buyer_store_slot_id,
    seller_warehouse_id, seller_warehouse_slot_id,
    logistics_vehicle_id, vehicle_owner_player_id, is_rental,
    product_id, quality_level, quantity, unit_price, total_price, product_unit_volume,
    reserved_capacity_amount, distance_km, fuel_used, condition_loss, rental_cost, transport_cost,
    transfer_type, started_at, finish_at, status, updated_at
  )
  values (
    v_player_id, v_player_id, null, v_store_slot.buyer_store_id, p_store_slot_id,
    v_warehouse_slot.seller_warehouse_id, p_warehouse_slot_id,
    case when p_vehicle_id = '00000000-0000-0000-0000-000000000000' then null else p_vehicle_id end,
    case when p_vehicle_id = '00000000-0000-0000-0000-000000000000' then null else v_vehicle.player_id end,
    (p_vehicle_id <> '00000000-0000-0000-0000-000000000000' and v_vehicle.player_id <> v_player_id),
    v_warehouse_slot.product_id, v_warehouse_slot.quality_level, p_quantity, v_unit_cost, 0,
    v_product.birim_hacim, p_quantity, v_distance_km, v_fuel_used, v_condition_loss,
    v_rental_cost, v_transport_cost, 'warehouse_to_store',
    timezone('utc'::text, now()), v_finish_at, 'in_transit', timezone('utc'::text, now())
  )
  returning id into v_transfer_id;

  return jsonb_build_object(
    'success', true, 'mode', 'transfer', 'transfer_id', v_transfer_id,
    'vehicle_id', p_vehicle_id, 'store_slot_id', p_store_slot_id, 'warehouse_slot_id', p_warehouse_slot_id,
    'product_id', v_warehouse_slot.product_id, 'quality_level', v_warehouse_slot.quality_level,
    'quantity', p_quantity, 'rental_cost', v_rental_cost, 'transport_cost', v_transport_cost,
    'distance_km', round(v_distance_km, 2), 'fuel_used', v_fuel_used,
    'condition_loss', v_condition_loss, 'duration_seconds', v_duration_seconds, 'finish_at', v_finish_at
  );
end;
$$;


ALTER FUNCTION "public"."start_warehouse_to_store_transfer"("p_store_slot_id" "uuid", "p_warehouse_slot_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_warehouse_to_warehouse_transfer"("p_warehouse_slot_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player_id uuid := auth.uid();
  v_player record;
  v_seller_slot record;
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
  v_source_quantity_after integer := 0;
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

  select ws.*, w.player_id, w.id as seller_warehouse_id, w.is_active as warehouse_is_active,
         w.city_id as warehouse_city_id,
         c.map_position_x as city_x, c.map_position_y as city_y
  into v_seller_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  join public.cities c on c.id = w.city_id
  where ws.id = p_warehouse_slot_id
  for update;

  if not found or v_seller_slot.player_id <> v_player_id then
    raise exception 'Kaynak depo slotu bulunamadi veya size ait degil.';
  end if;

  if v_seller_slot.warehouse_is_active is not true then
    raise exception 'Kaynak depo aktif degil.';
  end if;

  if coalesce(v_seller_slot.product_id, '') = '' or coalesce(v_seller_slot.quality_level, 0) = 0 then
    raise exception 'Depo slotunda gecerli urun veya kalite yok.';
  end if;

  if p_quantity > coalesce(v_seller_slot.quantity, 0) then
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

  if v_buyer_warehouse.id = v_seller_slot.seller_warehouse_id then
    raise exception 'Kaynak ve hedef depo ayni olamaz.';
  end if;

  if v_buyer_warehouse.is_active is not true then
    raise exception 'Hedef depo aktif degil.';
  end if;

  select * into v_product
  from public.products
  where id = v_seller_slot.product_id;

  if not found or coalesce(v_product.birim_hacim, 0) <= 0 then
    raise exception 'Urun hacim bilgisi gecersiz.';
  end if;

  v_required_capacity := p_quantity * v_product.birim_hacim;
  v_unit_cost := coalesce(v_seller_slot.cost, 0);
  v_source_quantity_after := greatest(coalesce(v_seller_slot.quantity, 0) - p_quantity, 0);

  if v_seller_slot.warehouse_city_id = v_buyer_warehouse.city_id then
    update public.warehouse_slots
    set quantity = v_source_quantity_after,
        updated_at = v_now
    where id = p_warehouse_slot_id;

    v_add_result := public.add_product_to_warehouse(
      v_player_id,
      p_buyer_warehouse_id,
      v_seller_slot.product_id,
      v_seller_slot.quality_level,
      p_quantity,
      v_unit_cost,
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
      v_seller_slot.seller_warehouse_id,
      p_warehouse_slot_id,
      null,
      null,
      false,
      v_seller_slot.product_id,
      v_seller_slot.quality_level,
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
      'warehouse_to_warehouse',
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
      'source_warehouse_id', v_seller_slot.seller_warehouse_id,
      'source_warehouse_slot_id', p_warehouse_slot_id,
      'source_quantity_after', v_source_quantity_after,
      'buyer_warehouse_id', p_buyer_warehouse_id,
      'product_id', v_seller_slot.product_id,
      'quality_level', v_seller_slot.quality_level,
      'quantity', p_quantity
    );
  end if;

  if p_vehicle_id is null then
    raise exception 'Farkli sehir transferi icin arac secilmelidir.';
  end if;

  v_distance_km := 6371 * 2 * asin(
    sqrt(
      power(sin(radians((v_seller_slot.city_x - v_buyer_warehouse.city_x) / 2)), 2) +
      cos(radians(v_buyer_warehouse.city_x)) *
      cos(radians(v_seller_slot.city_x)) *
      power(sin(radians((v_seller_slot.city_y - v_buyer_warehouse.city_y) / 2)), 2)
    )
  );

  if p_vehicle_id = '00000000-0000-0000-0000-000000000000' then
    select '00000000-0000-0000-0000-000000000000'::uuid as player_id
    into v_vehicle;
    v_rental_cost := ceil(v_distance_km * 5.0);
    v_transport_cost := v_rental_cost;
    v_duration_seconds := greatest(1, ceil(((v_distance_km / 60.0) / 4.0) * 3600))::integer;
    v_finish_at := timezone('utc'::text, now()) + make_interval(secs => v_duration_seconds);
  else
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

    if public.logistics_vehicle_matches_route(
      v_vehicle.route_city_a_id,
      v_vehicle.route_city_b_id,
      v_seller_slot.warehouse_city_id,
      v_buyer_warehouse.city_id
    ) is not true then
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
  end if;

  if coalesce(v_player.cash, 0) < v_rental_cost then
    raise exception 'Kiralik arac icin yeterli nakit yok.';
  end if;

  v_reserve_result := public.reserve_warehouse_capacity(
    v_player_id,
    p_buyer_warehouse_id,
    v_seller_slot.product_id,
    p_quantity
  );

  update public.warehouse_slots
  set quantity = v_source_quantity_after,
      updated_at = timezone('utc'::text, now())
  where id = p_warehouse_slot_id;

  if v_rental_cost > 0 then
    update public.players
    set cash = cash - v_rental_cost
    where id = v_player_id;

    if p_vehicle_id <> '00000000-0000-0000-0000-000000000000' then
      update public.players
      set cash = cash + v_rental_cost
      where id = v_vehicle.player_id;
    end if;
  end if;

  if p_vehicle_id <> '00000000-0000-0000-0000-000000000000' then
    update public.logistics_vehicles
    set
      current_fuel = greatest(current_fuel - v_fuel_used::integer, 0),
      condition = greatest(condition - v_condition_loss::integer, 0),
      status = 'on_route',
      updated_at = timezone('utc'::text, now())
    where id = p_vehicle_id;
  end if;

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
    v_seller_slot.seller_warehouse_id,
    p_warehouse_slot_id,
    case when p_vehicle_id = '00000000-0000-0000-0000-000000000000' then null else p_vehicle_id end,
    case when p_vehicle_id = '00000000-0000-0000-0000-000000000000' then null else v_vehicle.player_id end,
    (p_vehicle_id <> '00000000-0000-0000-0000-000000000000' and v_vehicle.player_id <> v_player_id),
    v_seller_slot.product_id,
    v_seller_slot.quality_level,
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
    'warehouse_to_warehouse',
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
    'source_warehouse_id', v_seller_slot.seller_warehouse_id,
    'source_warehouse_slot_id', p_warehouse_slot_id,
    'source_quantity_after', v_source_quantity_after,
    'buyer_warehouse_id', p_buyer_warehouse_id,
    'product_id', v_seller_slot.product_id,
    'quality_level', v_seller_slot.quality_level,
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
$$;


ALTER FUNCTION "public"."start_warehouse_to_warehouse_transfer"("p_warehouse_slot_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_player_mission_snapshot"("p_player_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_now timestamptz := timezone('utc', now());
begin
  if p_player_id is null then
    return;
  end if;

  perform public.ensure_player_mission_rows(p_player_id);

  with mission_counts as (
    select 'building_construction_completed_store'::text as event_key, count(*)::int as current_count
    from public.stores
    where player_id = p_player_id

    union all

    select 'building_construction_completed_warehouse'::text, count(*)::int
    from public.warehouses
    where player_id = p_player_id

    union all

    select 'building_construction_completed_factory'::text, count(*)::int
    from public.factories
    where player_id = p_player_id

    union all

    select 'building_upgrade_completed'::text, count(*)::int
    from public.building_upgrades
    where player_id = p_player_id
      and status = 'completed'

    union all

    select 'store_sale_completed'::text, coalesce(sum(sold_quantity), 0)::int
    from public.store_daily_performance
    where player_id = p_player_id

    union all

    select 'logistics_transfer_completed'::text, count(*)::int
    from public.logistics_transfers
    where status = 'completed'
      and p_player_id in (buyer_player_id, seller_player_id)

    union all

    select 'arge_research_completed'::text, count(*)::int
    from public.arge_researches
    where player_id = p_player_id
      and status = 'completed'
  )
  update public.player_missions pm
  set
    progress_count = greatest(pm.progress_count, least(md.target_count, mc.current_count)),
    is_completed = pm.is_completed or mc.current_count >= md.target_count,
    completed_at = case
      when (pm.is_completed = false and mc.current_count >= md.target_count and pm.completed_at is null) then v_now
      else pm.completed_at
    end,
    updated_at = case
      when greatest(pm.progress_count, least(md.target_count, mc.current_count)) <> pm.progress_count
        or (pm.is_completed = false and mc.current_count >= md.target_count)
      then v_now
      else pm.updated_at
    end
  from public.mission_definitions md
  join mission_counts mc on mc.event_key = md.event_key
  where pm.player_id = p_player_id
    and pm.mission_id = md.id
    and pm.is_claimed = false;
end;
$$;


ALTER FUNCTION "public"."sync_player_mission_snapshot"("p_player_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."to_turkey_time"("p_value" timestamp with time zone) RETURNS timestamp without time zone
    LANGUAGE "sql" STABLE
    AS $$
  select timezone('Europe/Istanbul', p_value);
$$;


ALTER FUNCTION "public"."to_turkey_time"("p_value" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."transfer_production_inventory_to_warehouse"("p_player_id" "uuid", "p_production_inventory_id" "uuid", "p_warehouse_id" "uuid", "p_quantity" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."transfer_production_inventory_to_warehouse"("p_player_id" "uuid", "p_production_inventory_id" "uuid", "p_warehouse_id" "uuid", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."transfer_store_slot_to_warehouse"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_warehouse_id" "uuid", "p_quantity" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."transfer_store_slot_to_warehouse"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_warehouse_id" "uuid", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."transfer_warehouse_fuel_to_logistics_company"("p_logistics_company_id" "uuid", "p_warehouse_slot_id" "uuid", "p_quantity" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_player_id uuid := auth.uid();
  v_company record;
  v_slot record;
  v_available_capacity integer;
begin
  if v_player_id is null then
    raise exception 'Oturum acilmamis.';
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Miktar 0''dan buyuk olmalidir.';
  end if;

  select *
  into v_company
  from public.logistics_companies
  where id = p_logistics_company_id
    and player_id = v_player_id
  for update;

  if not found then
    raise exception 'Lojistik merkezi bulunamadi.';
  end if;

  select
    ws.*,
    w.player_id,
    w.is_active as warehouse_is_active
  into v_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  where ws.id = p_warehouse_slot_id
  for update;

  if not found or v_slot.player_id <> v_player_id then
    raise exception 'Depo slotu bulunamadi veya size ait degil.';
  end if;

  if v_slot.warehouse_is_active is not true then
    raise exception 'Kaynak depo aktif degil.';
  end if;

  if coalesce(v_slot.product_id, '') <> 'YAKIT' then
    raise exception 'Bu slotta yakit bulunmuyor.';
  end if;

  if coalesce(v_slot.quantity, 0) < p_quantity then
    raise exception 'Depoda yeterli yakit yok.';
  end if;

  v_available_capacity := greatest(coalesce(v_company.fuel_capacity, 0) - coalesce(v_company.current_fuel, 0), 0);

  if v_available_capacity <= 0 then
    raise exception 'Merkez yakit deposu dolu.';
  end if;

  if p_quantity > v_available_capacity then
    raise exception 'Merkez yakit kapasitesi yetersiz. Bos kapasite: %', v_available_capacity;
  end if;

  update public.warehouse_slots
  set
    quantity = quantity - p_quantity,
    is_available_for_sale = case when quantity - p_quantity > 0 then is_available_for_sale else false end,
    updated_at = timezone('utc'::text, now())
  where id = p_warehouse_slot_id;

  update public.logistics_companies
  set
    current_fuel = current_fuel + p_quantity,
    updated_at = timezone('utc'::text, now())
  where id = p_logistics_company_id;

  return jsonb_build_object(
    'success', true,
    'company_id', p_logistics_company_id,
    'warehouse_slot_id', p_warehouse_slot_id,
    'fuel_added', p_quantity,
    'company_current_fuel', coalesce(v_company.current_fuel, 0) + p_quantity
  );
end;
$$;


ALTER FUNCTION "public"."transfer_warehouse_fuel_to_logistics_company"("p_logistics_company_id" "uuid", "p_warehouse_slot_id" "uuid", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."transfer_warehouse_slot_to_production_inventory"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_production_inventory_id" "uuid", "p_quantity" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_warehouse_slot record;
  v_inventory record;
  v_owner_city_id uuid;
  v_owner_player_id uuid;
  v_input_capacity integer := 0;
  v_used_input_quantity integer := 0;
  v_new_inventory_quantity integer;
  v_new_inventory_cost numeric;
  v_remaining_warehouse_quantity integer;
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Transfer quantity must be greater than 0.';
  end if;

  select ws.*, w.player_id, w.city_id
  into v_warehouse_slot
  from public.warehouse_slots ws
  join public.warehouses w on w.id = ws.warehouse_id
  where ws.id = p_warehouse_slot_id
  for update;

  if not found then
    raise exception 'Warehouse slot not found.';
  end if;

  if v_warehouse_slot.player_id <> p_player_id then
    raise exception 'Warehouse slot does not belong to player.';
  end if;

  if v_warehouse_slot.product_id is null
     or v_warehouse_slot.quality_level < 1
     or v_warehouse_slot.quality_level > 5 then
    raise exception 'Warehouse slot does not contain a valid product and quality.';
  end if;

  if v_warehouse_slot.quantity < p_quantity then
    raise exception 'Not enough quantity in warehouse slot. Current: %, Requested: %',
      v_warehouse_slot.quantity,
      p_quantity;
  end if;

  select *
  into v_inventory
  from public.production_inventory
  where id = p_production_inventory_id
  for update;

  if not found then
    raise exception 'Production inventory record not found.';
  end if;

  if v_inventory.inventory_type <> 'input' then
    raise exception 'Only input inventories can receive products.';
  end if;

  if v_inventory.owner_kind not in ('factory', 'field', 'farm') then
    raise exception 'Input transfer is not supported for owner_kind: %', v_inventory.owner_kind;
  end if;

  if v_inventory.owner_kind = 'factory' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.factories where id = v_inventory.owner_id;
    if not found then
      raise exception 'Factory not found.';
    end if;
  elsif v_inventory.owner_kind = 'field' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.fields where id = v_inventory.owner_id;
    if not found then
      raise exception 'Field not found.';
    end if;
  elsif v_inventory.owner_kind = 'farm' then
    select player_id, city_id into v_owner_player_id, v_owner_city_id
    from public.farms where id = v_inventory.owner_id;
    if not found then
      raise exception 'Farm not found.';
    end if;
  end if;

  if v_owner_player_id <> p_player_id then
    raise exception 'Target production owner does not belong to player.';
  end if;

  if v_owner_city_id <> v_warehouse_slot.city_id then
    raise exception 'Warehouse and production owner must be in the same city.';
  end if;

  if v_inventory.product_id <> v_warehouse_slot.product_id then
    raise exception 'Product mismatch between warehouse slot and input inventory.';
  end if;

  if v_inventory.quality_level <> v_warehouse_slot.quality_level then
    raise exception 'Quality mismatch between warehouse slot and input inventory.';
  end if;

  perform pg_advisory_xact_lock(
    hashtext('production_input_capacity:' || v_inventory.owner_kind || ':' || v_inventory.owner_id::text)
  );

  if v_inventory.owner_kind = 'factory' then
    select coalesce(input_capacity, 0) into v_input_capacity
    from public.factories where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'field' then
    select coalesce(input_capacity, 0) into v_input_capacity
    from public.fields where id = v_inventory.owner_id;
  elsif v_inventory.owner_kind = 'farm' then
    select coalesce(input_capacity, 0) into v_input_capacity
    from public.farms where id = v_inventory.owner_id;
  end if;

  select coalesce(sum(pi.quantity), 0)::integer
  into v_used_input_quantity
  from public.production_inventory pi
  where pi.owner_kind = v_inventory.owner_kind
    and pi.owner_id = v_inventory.owner_id
    and pi.inventory_type = 'input';

  if v_used_input_quantity + p_quantity > v_input_capacity then
    raise exception 'Input capacity exceeded. Current: %, Capacity: %, Requested add: %',
      v_used_input_quantity,
      v_input_capacity,
      p_quantity;
  end if;

  v_new_inventory_quantity := v_inventory.quantity + p_quantity;
  v_new_inventory_cost := (((v_inventory.quantity * v_inventory.cost) + (p_quantity * v_warehouse_slot.cost)) / v_new_inventory_quantity);
  v_remaining_warehouse_quantity := v_warehouse_slot.quantity - p_quantity;

  update public.warehouse_slots
  set quantity = v_remaining_warehouse_quantity,
      updated_at = timezone('utc'::text, now())
  where id = p_warehouse_slot_id;

  update public.production_inventory
  set quantity = v_new_inventory_quantity,
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
$$;


ALTER FUNCTION "public"."transfer_warehouse_slot_to_production_inventory"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_production_inventory_id" "uuid", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."transfer_warehouse_slot_to_store_slot"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_store_slot_id" "uuid", "p_quantity" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
$$;


ALTER FUNCTION "public"."transfer_warehouse_slot_to_store_slot"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_store_slot_id" "uuid", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upgrade_player_product_quality"("p_player_id" "uuid", "p_product_id" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."upgrade_player_product_quality"("p_player_id" "uuid", "p_product_id" "text") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."arge_centers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "player_id" "uuid" NOT NULL,
    "name" "text" DEFAULT 'AR-GE Merkezi'::"text" NOT NULL,
    "level" integer DEFAULT 1 NOT NULL,
    "max_concurrent_researches" integer DEFAULT 1 NOT NULL,
    "duration_reduction_pct" numeric DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."arge_centers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."arge_researches" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "player_id" "uuid" NOT NULL,
    "product_id" "text" NOT NULL,
    "product_name" "text" NOT NULL,
    "current_quality" integer NOT NULL,
    "target_quality" integer NOT NULL,
    "cost_paid" numeric DEFAULT 0 NOT NULL,
    "status" "text" DEFAULT 'in_progress'::"text" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "finish_at" timestamp with time zone NOT NULL,
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."arge_researches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."building_boosts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "player_id" "uuid" NOT NULL,
    "building_kind" "text" NOT NULL,
    "entity_id" "uuid" NOT NULL,
    "duration_hours" integer NOT NULL,
    "star_cost" integer DEFAULT 0 NOT NULL,
    "multiplier" numeric DEFAULT 2.00 NOT NULL,
    "params" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "status" "text" DEFAULT 'in_progress'::"text" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "finish_at" timestamp with time zone NOT NULL,
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."building_boosts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."building_constructions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "player_id" "uuid" NOT NULL,
    "building_kind" "text" NOT NULL,
    "params" "jsonb" NOT NULL,
    "status" "text" DEFAULT 'in_progress'::"text" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "finish_at" timestamp with time zone NOT NULL,
    "completed_at" timestamp with time zone,
    CONSTRAINT "building_constructions_completed_at_check" CHECK (((("status" = 'in_progress'::"text") AND ("completed_at" IS NULL)) OR (("status" = ANY (ARRAY['complete'::"text", 'cancelled'::"text"])) AND ("completed_at" IS NOT NULL)))),
    CONSTRAINT "building_constructions_kind_check" CHECK (("building_kind" = ANY (ARRAY['store'::"text", 'warehouse'::"text", 'factory'::"text", 'field'::"text", 'farm'::"text", 'mine'::"text", 'logistics_company'::"text", 'arge_center'::"text"]))),
    CONSTRAINT "building_constructions_params_check" CHECK ((("jsonb_typeof"("params") = 'object'::"text") AND ("params" <> '{}'::"jsonb"))),
    CONSTRAINT "building_constructions_status_check" CHECK (("status" = ANY (ARRAY['in_progress'::"text", 'complete'::"text", 'cancelled'::"text"]))),
    CONSTRAINT "building_constructions_time_check" CHECK (("finish_at" > "started_at"))
);


ALTER TABLE "public"."building_constructions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."building_upgrades" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "player_id" "uuid" NOT NULL,
    "building_kind" "text" NOT NULL,
    "entity_id" "uuid" NOT NULL,
    "current_level" integer NOT NULL,
    "target_level" integer NOT NULL,
    "params" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "status" "text" DEFAULT 'in_progress'::"text" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "finish_at" timestamp with time zone NOT NULL,
    "completed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."building_upgrades" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cities" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "population" integer DEFAULT 0 NOT NULL,
    "tax_rate" numeric(6,4) DEFAULT 0 NOT NULL,
    "map_position_x" numeric(10,2) DEFAULT 0 NOT NULL,
    "map_position_y" numeric(10,2) DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "cities_name_not_empty_check" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "cities_population_check" CHECK (("population" >= 0)),
    CONSTRAINT "cities_tax_rate_check" CHECK (("tax_rate" >= (0)::numeric))
);


ALTER TABLE "public"."cities" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."factories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "player_id" "uuid" NOT NULL,
    "factory_type_id" "uuid" NOT NULL,
    "city_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "level" integer DEFAULT 1 NOT NULL,
    "product_id" "text",
    "quality_level" integer DEFAULT 0 NOT NULL,
    "input_capacity" integer DEFAULT 0 NOT NULL,
    "output_capacity" integer DEFAULT 0 NOT NULL,
    "boost_multiplier" numeric(4,2) DEFAULT 1.00 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "last_production_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "factories_boost_multiplier_check" CHECK ((("boost_multiplier" >= 1.00) AND ("boost_multiplier" <= 2.00))),
    CONSTRAINT "factories_input_capacity_check" CHECK (("input_capacity" >= 0)),
    CONSTRAINT "factories_level_check" CHECK (("level" >= 1)),
    CONSTRAINT "factories_name_not_empty_check" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "factories_output_capacity_check" CHECK (("output_capacity" >= 0)),
    CONSTRAINT "factories_product_quality_check" CHECK (((("product_id" IS NULL) AND ("quality_level" = 0)) OR (("product_id" IS NOT NULL) AND (("quality_level" >= 1) AND ("quality_level" <= 5))))),
    CONSTRAINT "factories_quality_level_check" CHECK ((("quality_level" >= 0) AND ("quality_level" <= 5)))
);


ALTER TABLE "public"."factories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."factory_types" (
    "id" "uuid" NOT NULL,
    "name" "text",
    "icon" "text",
    "accepted_product_ids" "text",
    "cost" integer,
    "required_level" integer,
    "construction_time_minutes" integer,
    "created_at" timestamp with time zone,
    "input_capacity" integer,
    "output_capacity" integer
);


ALTER TABLE "public"."factory_types" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."farm_types" (
    "id" "uuid" NOT NULL,
    "name" "text",
    "icon" "text",
    "accepted_product_ids" "text",
    "cost" integer,
    "required_level" integer,
    "construction_time_minutes" integer,
    "input_capacity" integer,
    "output_capacity" integer DEFAULT 0,
    "max_slot_count" integer DEFAULT 5,
    CONSTRAINT "farm_types_output_capacity_check" CHECK (("output_capacity" >= 0))
);


ALTER TABLE "public"."farm_types" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."farms" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "player_id" "uuid" NOT NULL,
    "farm_type_id" "uuid" NOT NULL,
    "city_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "level" integer DEFAULT 1 NOT NULL,
    "current_slot_count" integer DEFAULT 0 NOT NULL,
    "max_slot_count" integer DEFAULT 0 NOT NULL,
    "input_capacity" integer DEFAULT 0 NOT NULL,
    "output_capacity" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "farms_input_capacity_check" CHECK (("input_capacity" >= 0)),
    CONSTRAINT "farms_level_check" CHECK (("level" >= 1)),
    CONSTRAINT "farms_name_not_empty_check" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "farms_output_capacity_check" CHECK (("output_capacity" >= 0)),
    CONSTRAINT "farms_slot_count_check" CHECK ((("current_slot_count" >= 0) AND ("max_slot_count" >= 0) AND ("current_slot_count" <= "max_slot_count")))
);


ALTER TABLE "public"."farms" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."field_types" (
    "id" "uuid" NOT NULL,
    "name" "text",
    "icon" "text",
    "accepted_product_ids" "text",
    "cost" integer,
    "required_level" integer,
    "construction_time_minutes" integer,
    "created_at" timestamp with time zone,
    "input_capacity" integer,
    "output_capacity" integer,
    "slot_capacity" integer,
    "max_slot_count" integer DEFAULT 5
);


ALTER TABLE "public"."field_types" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."fields" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "player_id" "uuid" NOT NULL,
    "field_type_id" "uuid" NOT NULL,
    "city_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "level" integer DEFAULT 1 NOT NULL,
    "current_slot_count" integer DEFAULT 0 NOT NULL,
    "max_slot_count" integer DEFAULT 0 NOT NULL,
    "input_capacity" integer DEFAULT 0 NOT NULL,
    "output_capacity" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "fields_input_capacity_check" CHECK (("input_capacity" >= 0)),
    CONSTRAINT "fields_level_check" CHECK (("level" >= 1)),
    CONSTRAINT "fields_name_not_empty_check" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "fields_output_capacity_check" CHECK (("output_capacity" >= 0)),
    CONSTRAINT "fields_slot_count_check" CHECK ((("current_slot_count" >= 0) AND ("max_slot_count" >= 0) AND ("current_slot_count" <= "max_slot_count")))
);


ALTER TABLE "public"."fields" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."game_settings" (
    "key" "text" NOT NULL,
    "value_text" "text" NOT NULL,
    "description" "text",
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."game_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."logistics_companies" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "player_id" "uuid" NOT NULL,
    "city_id" "uuid",
    "name" "text" NOT NULL,
    "level" integer DEFAULT 1 NOT NULL,
    "current_vehicle_count" integer DEFAULT 0 NOT NULL,
    "max_vehicle_count" integer DEFAULT 0 NOT NULL,
    "fuel_capacity" integer DEFAULT 0 NOT NULL,
    "current_fuel" integer DEFAULT 0 NOT NULL,
    "fuel_cost" numeric DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "logistics_companies_current_fuel_check" CHECK ((("current_fuel" >= 0) AND ("current_fuel" <= "fuel_capacity"))),
    CONSTRAINT "logistics_companies_fuel_capacity_check" CHECK (("fuel_capacity" >= 0)),
    CONSTRAINT "logistics_companies_fuel_cost_check" CHECK (("fuel_cost" >= (0)::numeric)),
    CONSTRAINT "logistics_companies_level_check" CHECK (("level" >= 1)),
    CONSTRAINT "logistics_companies_name_not_empty_check" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "logistics_companies_vehicle_count_check" CHECK ((("current_vehicle_count" >= 0) AND ("max_vehicle_count" >= 0) AND ("current_vehicle_count" <= "max_vehicle_count")))
);


ALTER TABLE "public"."logistics_companies" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."logistics_company_types" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "cost" integer DEFAULT 0 NOT NULL,
    "required_level" integer DEFAULT 1 NOT NULL,
    "construction_time_minutes" integer DEFAULT 0 NOT NULL,
    "max_vehicle_count" integer DEFAULT 0 NOT NULL,
    "fuel_capacity" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "logistics_company_types_construction_time_minutes_check" CHECK (("construction_time_minutes" >= 0)),
    CONSTRAINT "logistics_company_types_cost_check" CHECK (("cost" >= 0)),
    CONSTRAINT "logistics_company_types_fuel_capacity_check" CHECK (("fuel_capacity" >= 0)),
    CONSTRAINT "logistics_company_types_max_vehicle_count_check" CHECK (("max_vehicle_count" >= 0)),
    CONSTRAINT "logistics_company_types_name_not_empty_check" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "logistics_company_types_required_level_check" CHECK (("required_level" >= 1))
);


ALTER TABLE "public"."logistics_company_types" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."logistics_transfers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "buyer_player_id" "uuid" NOT NULL,
    "seller_player_id" "uuid" NOT NULL,
    "buyer_warehouse_id" "uuid",
    "seller_warehouse_id" "uuid",
    "seller_warehouse_slot_id" "uuid",
    "logistics_vehicle_id" "uuid",
    "vehicle_owner_player_id" "uuid",
    "is_rental" boolean DEFAULT false NOT NULL,
    "product_id" "text" NOT NULL,
    "quality_level" integer NOT NULL,
    "quantity" integer NOT NULL,
    "unit_price" numeric NOT NULL,
    "total_price" numeric NOT NULL,
    "product_unit_volume" numeric NOT NULL,
    "reserved_capacity_amount" numeric NOT NULL,
    "distance_km" numeric NOT NULL,
    "fuel_used" numeric NOT NULL,
    "condition_loss" numeric NOT NULL,
    "rental_cost" numeric DEFAULT 0 NOT NULL,
    "transport_cost" numeric DEFAULT 0 NOT NULL,
    "started_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "finish_at" timestamp with time zone NOT NULL,
    "completed_at" timestamp with time zone,
    "status" "text" DEFAULT 'in_transit'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "buyer_store_id" "uuid",
    "buyer_store_slot_id" "uuid",
    "transfer_type" "text" DEFAULT 'market_to_warehouse'::"text" NOT NULL,
    "seller_store_id" "uuid",
    "seller_store_slot_id" "uuid",
    "seller_entity_kind" "text",
    "buyer_entity_kind" "text",
    "seller_production_inventory_id" "uuid",
    "buyer_production_inventory_id" "uuid",
    CONSTRAINT "logistics_transfers_condition_loss_check" CHECK (("condition_loss" >= (0)::numeric)),
    CONSTRAINT "logistics_transfers_distance_km_check" CHECK (("distance_km" >= (0)::numeric)),
    CONSTRAINT "logistics_transfers_fuel_used_check" CHECK (("fuel_used" >= (0)::numeric)),
    CONSTRAINT "logistics_transfers_product_unit_volume_check" CHECK (("product_unit_volume" > (0)::numeric)),
    CONSTRAINT "logistics_transfers_quality_level_check" CHECK ((("quality_level" >= 1) AND ("quality_level" <= 5))),
    CONSTRAINT "logistics_transfers_quantity_check" CHECK (("quantity" > 0)),
    CONSTRAINT "logistics_transfers_rental_cost_check" CHECK (("rental_cost" >= (0)::numeric)),
    CONSTRAINT "logistics_transfers_reserved_capacity_amount_check" CHECK (("reserved_capacity_amount" >= (0)::numeric)),
    CONSTRAINT "logistics_transfers_status_check" CHECK (("status" = ANY (ARRAY['in_transit'::"text", 'completed'::"text"]))),
    CONSTRAINT "logistics_transfers_total_price_check" CHECK (("total_price" >= (0)::numeric)),
    CONSTRAINT "logistics_transfers_transport_cost_check" CHECK (("transport_cost" >= (0)::numeric)),
    CONSTRAINT "logistics_transfers_unit_price_check" CHECK (("unit_price" >= (0)::numeric))
);


ALTER TABLE "public"."logistics_transfers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."logistics_vehicle_types" (
    "id" "uuid" NOT NULL,
    "name" "text",
    "type" "text",
    "description" "text",
    "capacity" integer,
    "speed_kmh" integer,
    "fuel_capacity" integer,
    "fuel_rate" numeric,
    "purchase_price" integer,
    "icon" "text",
    "created_at" timestamp with time zone
);


ALTER TABLE "public"."logistics_vehicle_types" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."mine_types" (
    "id" "uuid" NOT NULL,
    "name" "text",
    "icon" "text",
    "accepted_product_ids" "text",
    "cost" integer,
    "required_level" integer,
    "construction_time_minutes" integer,
    "created_at" timestamp with time zone,
    "output_capacity" integer
);


ALTER TABLE "public"."mine_types" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."mines" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "player_id" "uuid" NOT NULL,
    "mine_type_id" "uuid" NOT NULL,
    "city_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "level" integer DEFAULT 1 NOT NULL,
    "product_id" "text",
    "quality_level" integer DEFAULT 0 NOT NULL,
    "output_capacity" integer DEFAULT 0 NOT NULL,
    "boost_multiplier" numeric(4,2) DEFAULT 1.00 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "last_production_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "mines_boost_multiplier_check" CHECK ((("boost_multiplier" >= 1.00) AND ("boost_multiplier" <= 2.00))),
    CONSTRAINT "mines_level_check" CHECK (("level" >= 1)),
    CONSTRAINT "mines_name_not_empty_check" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "mines_output_capacity_check" CHECK (("output_capacity" >= 0)),
    CONSTRAINT "mines_product_quality_check" CHECK (((("product_id" IS NULL) AND ("quality_level" = 0)) OR (("product_id" IS NOT NULL) AND (("quality_level" >= 1) AND ("quality_level" <= 5))))),
    CONSTRAINT "mines_quality_level_check" CHECK ((("quality_level" >= 0) AND ("quality_level" <= 5)))
);


ALTER TABLE "public"."mines" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."mission_definitions" (
    "id" "text" NOT NULL,
    "mission_type" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text" NOT NULL,
    "event_key" "text" NOT NULL,
    "target_count" integer NOT NULL,
    "reward_xp" integer DEFAULT 0 NOT NULL,
    "reward_cash" numeric(15,2) DEFAULT 0 NOT NULL,
    "reward_gold" integer DEFAULT 0 NOT NULL,
    "icon_key" "text",
    "display_order" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "mission_definitions_mission_type_check" CHECK (("mission_type" = ANY (ARRAY['main'::"text", 'side'::"text", 'achievement'::"text"]))),
    CONSTRAINT "mission_definitions_reward_gold_check" CHECK (("reward_gold" >= 0)),
    CONSTRAINT "mission_definitions_reward_xp_check" CHECK (("reward_xp" >= 0)),
    CONSTRAINT "mission_definitions_target_count_check" CHECK (("target_count" > 0))
);


ALTER TABLE "public"."mission_definitions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."player_experience_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "player_id" "uuid" NOT NULL,
    "reason" "text" NOT NULL,
    "amount" integer NOT NULL,
    "old_level" integer NOT NULL,
    "new_level" integer NOT NULL,
    "old_experience" integer NOT NULL,
    "new_experience" integer NOT NULL,
    "meta" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."player_experience_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."player_missions" (
    "player_id" "uuid" NOT NULL,
    "mission_id" "text" NOT NULL,
    "progress_count" integer DEFAULT 0 NOT NULL,
    "is_completed" boolean DEFAULT false NOT NULL,
    "completed_at" timestamp with time zone,
    "is_claimed" boolean DEFAULT false NOT NULL,
    "claimed_at" timestamp with time zone,
    "last_progress_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "player_missions_progress_count_check" CHECK (("progress_count" >= 0))
);


ALTER TABLE "public"."player_missions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."player_product_quality_levels" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "player_id" "uuid" NOT NULL,
    "product_id" "text" NOT NULL,
    "max_quality_level" integer DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "player_product_quality_levels_quality_check" CHECK ((("max_quality_level" >= 1) AND ("max_quality_level" <= 5)))
);


ALTER TABLE "public"."player_product_quality_levels" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."players" (
    "id" "uuid" NOT NULL,
    "company_name" "text" DEFAULT 'Yeni Holding'::"text" NOT NULL,
    "avatar_id" "text" DEFAULT 'avatar_1.webp'::"text" NOT NULL,
    "level" integer DEFAULT 1 NOT NULL,
    "experience" integer DEFAULT 0 NOT NULL,
    "cash" numeric DEFAULT 100000 NOT NULL,
    "gold" numeric DEFAULT 100 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "player_name" "text" DEFAULT 'Oyuncu'::"text" NOT NULL
);


ALTER TABLE "public"."players" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."production_inventory" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_kind" "text" NOT NULL,
    "owner_id" "uuid" NOT NULL,
    "inventory_type" "text" NOT NULL,
    "product_id" "text" NOT NULL,
    "quality_level" integer NOT NULL,
    "quantity" integer DEFAULT 0 NOT NULL,
    "pending_quantity" numeric DEFAULT 0 NOT NULL,
    "cost" numeric DEFAULT 0 NOT NULL,
    CONSTRAINT "production_inventory_cost_check" CHECK (("cost" >= (0)::numeric)),
    CONSTRAINT "production_inventory_inventory_type_check" CHECK (("inventory_type" = ANY (ARRAY['input'::"text", 'output'::"text"]))),
    CONSTRAINT "production_inventory_owner_kind_check" CHECK (("owner_kind" = ANY (ARRAY['factory'::"text", 'field'::"text", 'farm'::"text", 'mine'::"text"]))),
    CONSTRAINT "production_inventory_pending_quantity_check" CHECK (("pending_quantity" >= (0)::numeric)),
    CONSTRAINT "production_inventory_quality_level_check" CHECK ((("quality_level" >= 1) AND ("quality_level" <= 5))),
    CONSTRAINT "production_inventory_quantity_check" CHECK (("quantity" >= 0))
);


ALTER TABLE "public"."production_inventory" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."production_slots" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "owner_kind" "text" NOT NULL,
    "owner_id" "uuid" NOT NULL,
    "slot_index" integer NOT NULL,
    "product_id" "text",
    "quality_level" integer DEFAULT 0 NOT NULL,
    "boost_multiplier" numeric(4,2) DEFAULT 1.00 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "last_production_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "production_slots_boost_multiplier_check" CHECK ((("boost_multiplier" >= 1.00) AND ("boost_multiplier" <= 2.00))),
    CONSTRAINT "production_slots_owner_kind_check" CHECK (("owner_kind" = ANY (ARRAY['field'::"text", 'farm'::"text"]))),
    CONSTRAINT "production_slots_product_quality_check" CHECK (((("product_id" IS NULL) AND ("quality_level" = 0)) OR (("product_id" IS NOT NULL) AND (("quality_level" >= 1) AND ("quality_level" <= 5))))),
    CONSTRAINT "production_slots_quality_level_check" CHECK ((("quality_level" >= 0) AND ("quality_level" <= 5))),
    CONSTRAINT "production_slots_slot_index_check" CHECK (("slot_index" > 0))
);


ALTER TABLE "public"."production_slots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" "text" NOT NULL,
    "urun_adi" "text",
    "urun_iconu" "text",
    "birim_hacim" numeric,
    "birim_agirlik" numeric,
    "hammadde_1_id" "text",
    "hammadde_1_miktar" numeric,
    "hammadde_2_id" "text",
    "hammadde_2_miktar" numeric,
    "hammadde_3_id" "text",
    "hammadde_3_miktar" numeric,
    "uretim_birimi" "text",
    "baz_satis_fiyati" numeric,
    "uretim_adedi" integer,
    "satis_adedi" integer,
    "en_dusuk_fiyat" numeric,
    "en_yuksek_fiyat" numeric,
    "ortalama_fiyat" numeric,
    "satici_sayisi" integer,
    "created_at" timestamp with time zone,
    "piyasadaki_stok" integer
);


ALTER TABLE "public"."products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."store_daily_performance" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "performance_date" "date" NOT NULL,
    "player_id" "uuid" NOT NULL,
    "store_id" "uuid" NOT NULL,
    "store_slot_id" "uuid" NOT NULL,
    "slot_index" integer NOT NULL,
    "product_id" "text",
    "product_name" "text",
    "quality_level" integer DEFAULT 0 NOT NULL,
    "sold_quantity" integer DEFAULT 0 NOT NULL,
    "revenue" numeric DEFAULT 0 NOT NULL,
    "profit" numeric DEFAULT 0 NOT NULL,
    "sale_event_count" integer DEFAULT 0 NOT NULL,
    "last_sale_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."store_daily_performance" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."store_slots" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "store_id" "uuid" NOT NULL,
    "slot_index" integer NOT NULL,
    "product_id" "text",
    "quantity" integer DEFAULT 0 NOT NULL,
    "quality_level" integer DEFAULT 0 NOT NULL,
    "price" numeric DEFAULT 0 NOT NULL,
    "cost" numeric DEFAULT 0 NOT NULL,
    "boost_multiplier" numeric(4,2) DEFAULT 1.00 NOT NULL,
    "pending_sale" numeric DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "capacity" integer DEFAULT 0 NOT NULL,
    "last_sale_processed_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "pending_quantity" integer DEFAULT 0 NOT NULL,
    CONSTRAINT "store_slots_boost_multiplier_check" CHECK ((("boost_multiplier" >= 1.00) AND ("boost_multiplier" <= 2.00))),
    CONSTRAINT "store_slots_capacity_check" CHECK (("capacity" >= 0)),
    CONSTRAINT "store_slots_cost_check" CHECK (("cost" >= (0)::numeric)),
    CONSTRAINT "store_slots_empty_or_filled_check" CHECK (((("product_id" IS NULL) AND ("quantity" = 0) AND ("quality_level" = 0)) OR (("product_id" IS NOT NULL) AND (("quality_level" >= 1) AND ("quality_level" <= 5))))),
    CONSTRAINT "store_slots_pending_sale_check" CHECK (("pending_sale" >= (0)::numeric)),
    CONSTRAINT "store_slots_price_check" CHECK (("price" >= (0)::numeric)),
    CONSTRAINT "store_slots_quality_level_check" CHECK ((("quality_level" >= 0) AND ("quality_level" <= 5))),
    CONSTRAINT "store_slots_quantity_check" CHECK (("quantity" >= 0)),
    CONSTRAINT "store_slots_slot_index_check" CHECK (("slot_index" > 0))
);


ALTER TABLE "public"."store_slots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."store_types" (
    "id" "uuid" NOT NULL,
    "name" "text",
    "icon" "text",
    "accepted_product_ids" "text",
    "cost" integer,
    "required_level" integer,
    "created_at" timestamp with time zone,
    "base_slot_count" integer,
    "construction_time_minutes" integer,
    "max_slot_count" integer,
    "slot_capacity" integer
);


ALTER TABLE "public"."store_types" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "player_id" "uuid" NOT NULL,
    "store_type_id" "uuid" NOT NULL,
    "city_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "level" integer DEFAULT 1 NOT NULL,
    "current_slot_count" integer DEFAULT 0 NOT NULL,
    "max_slot_count" integer DEFAULT 0 NOT NULL,
    "slot_capacity" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    CONSTRAINT "stores_level_check" CHECK (("level" >= 1)),
    CONSTRAINT "stores_name_not_empty_check" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "stores_slot_capacity_check" CHECK (("slot_capacity" >= 0)),
    CONSTRAINT "stores_slot_count_check" CHECK ((("current_slot_count" >= 0) AND ("max_slot_count" >= 0) AND ("current_slot_count" <= "max_slot_count")))
);


ALTER TABLE "public"."stores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."warehouse_slots" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "warehouse_id" "uuid" NOT NULL,
    "slot_index" integer NOT NULL,
    "product_id" "text",
    "quality_level" integer DEFAULT 0 NOT NULL,
    "quantity" integer DEFAULT 0 NOT NULL,
    "cost" numeric DEFAULT 0 NOT NULL,
    "is_available_for_sale" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "price" numeric DEFAULT 0 NOT NULL,
    CONSTRAINT "warehouse_slots_cost_check" CHECK (("cost" >= (0)::numeric)),
    CONSTRAINT "warehouse_slots_empty_or_filled_check" CHECK (((("product_id" IS NULL) AND ("quantity" = 0) AND ("quality_level" = 0)) OR (("product_id" IS NOT NULL) AND (("quality_level" >= 1) AND ("quality_level" <= 5))))),
    CONSTRAINT "warehouse_slots_price_check" CHECK (("price" >= (0)::numeric)),
    CONSTRAINT "warehouse_slots_quality_level_check" CHECK ((("quality_level" >= 0) AND ("quality_level" <= 5))),
    CONSTRAINT "warehouse_slots_quantity_check" CHECK (("quantity" >= 0)),
    CONSTRAINT "warehouse_slots_slot_index_check" CHECK (("slot_index" > 0))
);


ALTER TABLE "public"."warehouse_slots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."warehouse_types" (
    "id" "uuid" NOT NULL,
    "name" "text",
    "icon" "text",
    "accepted_production_units" "text",
    "base_capacity" integer,
    "cost" integer,
    "required_level" integer,
    "construction_time_minutes" integer,
    "accepted_product_ids" "text",
    "max_slot_count" integer,
    CONSTRAINT "warehouse_types_construction_time_minutes_check" CHECK (("construction_time_minutes" >= 0)),
    CONSTRAINT "warehouse_types_cost_check" CHECK (("cost" >= 0)),
    CONSTRAINT "warehouse_types_required_level_check" CHECK (("required_level" >= 1))
);


ALTER TABLE "public"."warehouse_types" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."warehouses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "player_id" "uuid" NOT NULL,
    "warehouse_type_id" "uuid" NOT NULL,
    "city_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "level" integer DEFAULT 1 NOT NULL,
    "capacity" numeric DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "reserved_capacity" numeric DEFAULT 0 NOT NULL,
    CONSTRAINT "warehouses_capacity_check" CHECK (("capacity" >= (0)::numeric)),
    CONSTRAINT "warehouses_level_check" CHECK (("level" >= 1)),
    CONSTRAINT "warehouses_name_not_empty_check" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "warehouses_reserved_capacity_check" CHECK (("reserved_capacity" >= (0)::numeric))
);


ALTER TABLE "public"."warehouses" OWNER TO "postgres";


ALTER TABLE ONLY "public"."arge_centers"
    ADD CONSTRAINT "arge_centers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."arge_researches"
    ADD CONSTRAINT "arge_researches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."building_boosts"
    ADD CONSTRAINT "building_boosts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."building_constructions"
    ADD CONSTRAINT "building_constructions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."building_upgrades"
    ADD CONSTRAINT "building_upgrades_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."field_types"
    ADD CONSTRAINT "ciftlik_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cities"
    ADD CONSTRAINT "cities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."factory_types"
    ADD CONSTRAINT "fabrika_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."factories"
    ADD CONSTRAINT "factories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."farm_types"
    ADD CONSTRAINT "farm_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."farms"
    ADD CONSTRAINT "farms_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."fields"
    ADD CONSTRAINT "fields_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."game_settings"
    ADD CONSTRAINT "game_settings_pkey" PRIMARY KEY ("key");



ALTER TABLE ONLY "public"."logistics_companies"
    ADD CONSTRAINT "logistics_companies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."logistics_company_types"
    ADD CONSTRAINT "logistics_company_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."logistics_transfers"
    ADD CONSTRAINT "logistics_transfers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."logistics_vehicle_types"
    ADD CONSTRAINT "logistics_vehicle_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."logistics_vehicles"
    ADD CONSTRAINT "logistics_vehicles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."mine_types"
    ADD CONSTRAINT "maden_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."mines"
    ADD CONSTRAINT "mines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."mission_definitions"
    ADD CONSTRAINT "mission_definitions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."player_experience_logs"
    ADD CONSTRAINT "player_experience_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."player_missions"
    ADD CONSTRAINT "player_missions_pkey" PRIMARY KEY ("player_id", "mission_id");



ALTER TABLE ONLY "public"."player_product_quality_levels"
    ADD CONSTRAINT "player_product_quality_levels_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."player_product_quality_levels"
    ADD CONSTRAINT "player_product_quality_levels_unique" UNIQUE ("player_id", "product_id");



ALTER TABLE ONLY "public"."players"
    ADD CONSTRAINT "players_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."production_inventory"
    ADD CONSTRAINT "production_inventory_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."production_inventory"
    ADD CONSTRAINT "production_inventory_unique_item" UNIQUE ("owner_kind", "owner_id", "inventory_type", "product_id", "quality_level");



ALTER TABLE ONLY "public"."production_slots"
    ADD CONSTRAINT "production_slots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."production_slots"
    ADD CONSTRAINT "production_slots_unique_slot_index" UNIQUE ("owner_kind", "owner_id", "slot_index");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."store_daily_performance"
    ADD CONSTRAINT "store_daily_performance_performance_date_store_id_store_slo_key" UNIQUE ("performance_date", "store_id", "store_slot_id");



ALTER TABLE ONLY "public"."store_daily_performance"
    ADD CONSTRAINT "store_daily_performance_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."store_slots"
    ADD CONSTRAINT "store_slots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."store_slots"
    ADD CONSTRAINT "store_slots_unique_slot_index" UNIQUE ("store_id", "slot_index");



ALTER TABLE ONLY "public"."store_types"
    ADD CONSTRAINT "store_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stores"
    ADD CONSTRAINT "stores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."warehouse_slots"
    ADD CONSTRAINT "warehouse_slots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."warehouse_slots"
    ADD CONSTRAINT "warehouse_slots_unique_slot_index" UNIQUE ("warehouse_id", "slot_index");



ALTER TABLE ONLY "public"."warehouse_types"
    ADD CONSTRAINT "warehouse_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."warehouses"
    ADD CONSTRAINT "warehouses_pkey" PRIMARY KEY ("id");



CREATE UNIQUE INDEX "idx_arge_centers_player_id" ON "public"."arge_centers" USING "btree" ("player_id");



CREATE INDEX "idx_arge_researches_player_id" ON "public"."arge_researches" USING "btree" ("player_id");



CREATE INDEX "idx_arge_researches_status_finish" ON "public"."arge_researches" USING "btree" ("status", "finish_at");



CREATE INDEX "idx_building_boosts_entity" ON "public"."building_boosts" USING "btree" ("building_kind", "entity_id");



CREATE INDEX "idx_building_boosts_finish_at" ON "public"."building_boosts" USING "btree" ("finish_at");



CREATE INDEX "idx_building_boosts_player_id" ON "public"."building_boosts" USING "btree" ("player_id");



CREATE INDEX "idx_building_boosts_status" ON "public"."building_boosts" USING "btree" ("status");



CREATE INDEX "idx_building_upgrades_entity" ON "public"."building_upgrades" USING "btree" ("building_kind", "entity_id");



CREATE INDEX "idx_building_upgrades_finish_at" ON "public"."building_upgrades" USING "btree" ("finish_at");



CREATE INDEX "idx_building_upgrades_player_id" ON "public"."building_upgrades" USING "btree" ("player_id");



CREATE INDEX "idx_building_upgrades_status" ON "public"."building_upgrades" USING "btree" ("status");



CREATE INDEX "idx_factories_city_id" ON "public"."factories" USING "btree" ("city_id");



CREATE INDEX "idx_factories_factory_type_id" ON "public"."factories" USING "btree" ("factory_type_id");



CREATE INDEX "idx_factories_player_id" ON "public"."factories" USING "btree" ("player_id");



CREATE INDEX "idx_factories_product_id" ON "public"."factories" USING "btree" ("product_id");



CREATE INDEX "idx_farms_active_output_capacity" ON "public"."farms" USING "btree" ("id", "output_capacity") WHERE ("is_active" = true);



CREATE INDEX "idx_farms_city_id" ON "public"."farms" USING "btree" ("city_id");



CREATE INDEX "idx_farms_farm_type_id" ON "public"."farms" USING "btree" ("farm_type_id");



CREATE INDEX "idx_farms_player_id" ON "public"."farms" USING "btree" ("player_id");



CREATE INDEX "idx_fields_active_output_capacity" ON "public"."fields" USING "btree" ("id", "output_capacity") WHERE ("is_active" = true);



CREATE INDEX "idx_fields_city_id" ON "public"."fields" USING "btree" ("city_id");



CREATE INDEX "idx_fields_field_type_id" ON "public"."fields" USING "btree" ("field_type_id");



CREATE INDEX "idx_fields_player_id" ON "public"."fields" USING "btree" ("player_id");



CREATE INDEX "idx_logistics_companies_city_id" ON "public"."logistics_companies" USING "btree" ("city_id");



CREATE INDEX "idx_logistics_companies_player_id" ON "public"."logistics_companies" USING "btree" ("player_id");



CREATE INDEX "idx_logistics_transfers_buyer_player_id" ON "public"."logistics_transfers" USING "btree" ("buyer_player_id");



CREATE INDEX "idx_logistics_transfers_status_finish_at" ON "public"."logistics_transfers" USING "btree" ("status", "finish_at");



CREATE INDEX "idx_logistics_transfers_vehicle_id" ON "public"."logistics_transfers" USING "btree" ("logistics_vehicle_id");



CREATE INDEX "idx_logistics_vehicles_company_id" ON "public"."logistics_vehicles" USING "btree" ("logistics_company_id");



CREATE INDEX "idx_logistics_vehicles_player_id" ON "public"."logistics_vehicles" USING "btree" ("player_id");



CREATE INDEX "idx_logistics_vehicles_route_city_a_id" ON "public"."logistics_vehicles" USING "btree" ("route_city_a_id");



CREATE INDEX "idx_logistics_vehicles_route_city_b_id" ON "public"."logistics_vehicles" USING "btree" ("route_city_b_id");



CREATE INDEX "idx_logistics_vehicles_status" ON "public"."logistics_vehicles" USING "btree" ("status");



CREATE INDEX "idx_logistics_vehicles_vehicle_type_id" ON "public"."logistics_vehicles" USING "btree" ("logistics_vehicle_type_id");



CREATE INDEX "idx_mines_active_product" ON "public"."mines" USING "btree" ("id", "product_id", "quality_level") WHERE (("is_active" = true) AND ("product_id" IS NOT NULL));



CREATE INDEX "idx_mines_city_id" ON "public"."mines" USING "btree" ("city_id");



CREATE INDEX "idx_mines_mine_type_id" ON "public"."mines" USING "btree" ("mine_type_id");



CREATE INDEX "idx_mines_player_id" ON "public"."mines" USING "btree" ("player_id");



CREATE INDEX "idx_mines_product_id" ON "public"."mines" USING "btree" ("product_id");



CREATE INDEX "idx_mission_definitions_active_order" ON "public"."mission_definitions" USING "btree" ("is_active", "mission_type", "display_order");



CREATE INDEX "idx_player_experience_logs_player_created_at" ON "public"."player_experience_logs" USING "btree" ("player_id", "created_at" DESC);



CREATE INDEX "idx_player_missions_player_claim" ON "public"."player_missions" USING "btree" ("player_id", "is_claimed", "is_completed");



CREATE INDEX "idx_production_inventory_field_farm_input" ON "public"."production_inventory" USING "btree" ("owner_kind", "owner_id", "product_id", "quality_level") WHERE (("owner_kind" = ANY (ARRAY['field'::"text", 'farm'::"text"])) AND ("inventory_type" = 'input'::"text"));



CREATE INDEX "idx_production_inventory_field_farm_output" ON "public"."production_inventory" USING "btree" ("owner_kind", "owner_id", "product_id", "quality_level") WHERE (("owner_kind" = ANY (ARRAY['field'::"text", 'farm'::"text"])) AND ("inventory_type" = 'output'::"text"));



CREATE INDEX "idx_production_inventory_mine_output_active" ON "public"."production_inventory" USING "btree" ("owner_id", "product_id", "quality_level") WHERE (("owner_kind" = 'mine'::"text") AND ("inventory_type" = 'output'::"text"));



CREATE INDEX "idx_production_inventory_owner" ON "public"."production_inventory" USING "btree" ("owner_kind", "owner_id");



CREATE INDEX "idx_production_inventory_owner_inventory_type" ON "public"."production_inventory" USING "btree" ("owner_kind", "owner_id", "inventory_type");



CREATE INDEX "idx_production_inventory_product_id" ON "public"."production_inventory" USING "btree" ("product_id");



CREATE INDEX "idx_production_slots_field_farm_active" ON "public"."production_slots" USING "btree" ("owner_kind", "owner_id", "product_id", "quality_level", "slot_index") WHERE (("owner_kind" = ANY (ARRAY['field'::"text", 'farm'::"text"])) AND ("is_active" = true) AND ("product_id" IS NOT NULL));



CREATE INDEX "idx_production_slots_owner" ON "public"."production_slots" USING "btree" ("owner_kind", "owner_id");



CREATE INDEX "idx_production_slots_product_id" ON "public"."production_slots" USING "btree" ("product_id");



CREATE INDEX "idx_store_daily_performance_player_date" ON "public"."store_daily_performance" USING "btree" ("player_id", "performance_date" DESC);



CREATE INDEX "idx_store_daily_performance_store_date" ON "public"."store_daily_performance" USING "btree" ("store_id", "performance_date" DESC);



CREATE INDEX "idx_store_slots_product_id" ON "public"."store_slots" USING "btree" ("product_id");



CREATE INDEX "idx_store_slots_store_id" ON "public"."store_slots" USING "btree" ("store_id");



CREATE INDEX "idx_stores_city_id" ON "public"."stores" USING "btree" ("city_id");



CREATE INDEX "idx_stores_player_id" ON "public"."stores" USING "btree" ("player_id");



CREATE INDEX "idx_stores_store_type_id" ON "public"."stores" USING "btree" ("store_type_id");



CREATE INDEX "idx_warehouse_slots_product_id" ON "public"."warehouse_slots" USING "btree" ("product_id");



CREATE INDEX "idx_warehouse_slots_warehouse_id" ON "public"."warehouse_slots" USING "btree" ("warehouse_id");



CREATE INDEX "idx_warehouses_city_id" ON "public"."warehouses" USING "btree" ("city_id");



CREATE INDEX "idx_warehouses_player_id" ON "public"."warehouses" USING "btree" ("player_id");



CREATE INDEX "idx_warehouses_warehouse_type_id" ON "public"."warehouses" USING "btree" ("warehouse_type_id");



CREATE INDEX "logistics_transfers_buyer_production_inventory_idx" ON "public"."logistics_transfers" USING "btree" ("buyer_production_inventory_id");



CREATE INDEX "logistics_transfers_seller_production_inventory_idx" ON "public"."logistics_transfers" USING "btree" ("seller_production_inventory_id");



CREATE UNIQUE INDEX "uq_arge_researches_one_active_per_player_product" ON "public"."arge_researches" USING "btree" ("player_id", "product_id") WHERE ("status" = 'in_progress'::"text");



CREATE UNIQUE INDEX "uq_building_constructions_one_active_per_player" ON "public"."building_constructions" USING "btree" ("player_id") WHERE ("status" = 'in_progress'::"text");



CREATE OR REPLACE TRIGGER "trg_arge_researches_mission_progress" AFTER UPDATE OF "status" ON "public"."arge_researches" FOR EACH ROW EXECUTE FUNCTION "public"."handle_arge_research_mission_progress"();



CREATE OR REPLACE TRIGGER "trg_building_constructions_mission_progress" AFTER UPDATE OF "status" ON "public"."building_constructions" FOR EACH ROW EXECUTE FUNCTION "public"."handle_building_construction_mission_progress"();



CREATE OR REPLACE TRIGGER "trg_building_upgrades_mission_progress" AFTER UPDATE OF "status" ON "public"."building_upgrades" FOR EACH ROW EXECUTE FUNCTION "public"."handle_building_upgrade_mission_progress"();



CREATE OR REPLACE TRIGGER "trg_logistics_transfers_mission_progress" AFTER UPDATE OF "status" ON "public"."logistics_transfers" FOR EACH ROW EXECUTE FUNCTION "public"."handle_logistics_transfer_mission_progress"();



CREATE OR REPLACE TRIGGER "trg_store_daily_performance_mission_progress" AFTER INSERT OR UPDATE OF "sold_quantity" ON "public"."store_daily_performance" FOR EACH ROW EXECUTE FUNCTION "public"."handle_store_sales_mission_progress"();



ALTER TABLE ONLY "public"."arge_centers"
    ADD CONSTRAINT "arge_centers_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."players"("id");



ALTER TABLE ONLY "public"."arge_researches"
    ADD CONSTRAINT "arge_researches_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."building_boosts"
    ADD CONSTRAINT "building_boosts_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."players"("id");



ALTER TABLE ONLY "public"."building_constructions"
    ADD CONSTRAINT "building_constructions_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."building_upgrades"
    ADD CONSTRAINT "building_upgrades_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."players"("id");



ALTER TABLE ONLY "public"."factories"
    ADD CONSTRAINT "factories_city_id_fkey" FOREIGN KEY ("city_id") REFERENCES "public"."cities"("id");



ALTER TABLE ONLY "public"."factories"
    ADD CONSTRAINT "factories_factory_type_id_fkey" FOREIGN KEY ("factory_type_id") REFERENCES "public"."factory_types"("id");



ALTER TABLE ONLY "public"."factories"
    ADD CONSTRAINT "factories_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."factories"
    ADD CONSTRAINT "factories_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."farms"
    ADD CONSTRAINT "farms_city_id_fkey" FOREIGN KEY ("city_id") REFERENCES "public"."cities"("id");



ALTER TABLE ONLY "public"."farms"
    ADD CONSTRAINT "farms_farm_type_id_fkey" FOREIGN KEY ("farm_type_id") REFERENCES "public"."farm_types"("id");



ALTER TABLE ONLY "public"."farms"
    ADD CONSTRAINT "farms_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."fields"
    ADD CONSTRAINT "fields_city_id_fkey" FOREIGN KEY ("city_id") REFERENCES "public"."cities"("id");



ALTER TABLE ONLY "public"."fields"
    ADD CONSTRAINT "fields_field_type_id_fkey" FOREIGN KEY ("field_type_id") REFERENCES "public"."field_types"("id");



ALTER TABLE ONLY "public"."fields"
    ADD CONSTRAINT "fields_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."logistics_companies"
    ADD CONSTRAINT "logistics_companies_city_id_fkey" FOREIGN KEY ("city_id") REFERENCES "public"."cities"("id");



ALTER TABLE ONLY "public"."logistics_companies"
    ADD CONSTRAINT "logistics_companies_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."logistics_transfers"
    ADD CONSTRAINT "logistics_transfers_buyer_player_id_fkey" FOREIGN KEY ("buyer_player_id") REFERENCES "public"."players"("id");



ALTER TABLE ONLY "public"."logistics_transfers"
    ADD CONSTRAINT "logistics_transfers_buyer_production_inventory_fk" FOREIGN KEY ("buyer_production_inventory_id") REFERENCES "public"."production_inventory"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."logistics_transfers"
    ADD CONSTRAINT "logistics_transfers_buyer_store_id_fkey" FOREIGN KEY ("buyer_store_id") REFERENCES "public"."stores"("id");



ALTER TABLE ONLY "public"."logistics_transfers"
    ADD CONSTRAINT "logistics_transfers_buyer_store_slot_id_fkey" FOREIGN KEY ("buyer_store_slot_id") REFERENCES "public"."store_slots"("id");



ALTER TABLE ONLY "public"."logistics_transfers"
    ADD CONSTRAINT "logistics_transfers_buyer_warehouse_id_fkey" FOREIGN KEY ("buyer_warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."logistics_transfers"
    ADD CONSTRAINT "logistics_transfers_logistics_vehicle_id_fkey" FOREIGN KEY ("logistics_vehicle_id") REFERENCES "public"."logistics_vehicles"("id");



ALTER TABLE ONLY "public"."logistics_transfers"
    ADD CONSTRAINT "logistics_transfers_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."logistics_transfers"
    ADD CONSTRAINT "logistics_transfers_seller_player_id_fkey" FOREIGN KEY ("seller_player_id") REFERENCES "public"."players"("id");



ALTER TABLE ONLY "public"."logistics_transfers"
    ADD CONSTRAINT "logistics_transfers_seller_production_inventory_fk" FOREIGN KEY ("seller_production_inventory_id") REFERENCES "public"."production_inventory"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."logistics_transfers"
    ADD CONSTRAINT "logistics_transfers_seller_store_id_fkey" FOREIGN KEY ("seller_store_id") REFERENCES "public"."stores"("id");



ALTER TABLE ONLY "public"."logistics_transfers"
    ADD CONSTRAINT "logistics_transfers_seller_store_slot_id_fkey" FOREIGN KEY ("seller_store_slot_id") REFERENCES "public"."store_slots"("id");



ALTER TABLE ONLY "public"."logistics_transfers"
    ADD CONSTRAINT "logistics_transfers_seller_warehouse_id_fkey" FOREIGN KEY ("seller_warehouse_id") REFERENCES "public"."warehouses"("id");



ALTER TABLE ONLY "public"."logistics_transfers"
    ADD CONSTRAINT "logistics_transfers_seller_warehouse_slot_id_fkey" FOREIGN KEY ("seller_warehouse_slot_id") REFERENCES "public"."warehouse_slots"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."logistics_transfers"
    ADD CONSTRAINT "logistics_transfers_vehicle_owner_player_id_fkey" FOREIGN KEY ("vehicle_owner_player_id") REFERENCES "public"."players"("id");



ALTER TABLE ONLY "public"."logistics_vehicles"
    ADD CONSTRAINT "logistics_vehicles_logistics_company_id_fkey" FOREIGN KEY ("logistics_company_id") REFERENCES "public"."logistics_companies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."logistics_vehicles"
    ADD CONSTRAINT "logistics_vehicles_logistics_vehicle_type_id_fkey" FOREIGN KEY ("logistics_vehicle_type_id") REFERENCES "public"."logistics_vehicle_types"("id");



ALTER TABLE ONLY "public"."logistics_vehicles"
    ADD CONSTRAINT "logistics_vehicles_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."logistics_vehicles"
    ADD CONSTRAINT "logistics_vehicles_route_city_a_id_fkey" FOREIGN KEY ("route_city_a_id") REFERENCES "public"."cities"("id");



ALTER TABLE ONLY "public"."logistics_vehicles"
    ADD CONSTRAINT "logistics_vehicles_route_city_b_id_fkey" FOREIGN KEY ("route_city_b_id") REFERENCES "public"."cities"("id");



ALTER TABLE ONLY "public"."mines"
    ADD CONSTRAINT "mines_city_id_fkey" FOREIGN KEY ("city_id") REFERENCES "public"."cities"("id");



ALTER TABLE ONLY "public"."mines"
    ADD CONSTRAINT "mines_mine_type_id_fkey" FOREIGN KEY ("mine_type_id") REFERENCES "public"."mine_types"("id");



ALTER TABLE ONLY "public"."mines"
    ADD CONSTRAINT "mines_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."mines"
    ADD CONSTRAINT "mines_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."player_experience_logs"
    ADD CONSTRAINT "player_experience_logs_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."player_missions"
    ADD CONSTRAINT "player_missions_mission_id_fkey" FOREIGN KEY ("mission_id") REFERENCES "public"."mission_definitions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."player_missions"
    ADD CONSTRAINT "player_missions_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."player_product_quality_levels"
    ADD CONSTRAINT "player_product_quality_levels_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."player_product_quality_levels"
    ADD CONSTRAINT "player_product_quality_levels_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."players"
    ADD CONSTRAINT "players_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."production_inventory"
    ADD CONSTRAINT "production_inventory_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."production_slots"
    ADD CONSTRAINT "production_slots_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."store_daily_performance"
    ADD CONSTRAINT "store_daily_performance_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."store_daily_performance"
    ADD CONSTRAINT "store_daily_performance_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."store_daily_performance"
    ADD CONSTRAINT "store_daily_performance_store_slot_id_fkey" FOREIGN KEY ("store_slot_id") REFERENCES "public"."store_slots"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."store_slots"
    ADD CONSTRAINT "store_slots_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."store_slots"
    ADD CONSTRAINT "store_slots_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stores"
    ADD CONSTRAINT "stores_city_id_fkey" FOREIGN KEY ("city_id") REFERENCES "public"."cities"("id");



ALTER TABLE ONLY "public"."stores"
    ADD CONSTRAINT "stores_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stores"
    ADD CONSTRAINT "stores_store_type_id_fkey" FOREIGN KEY ("store_type_id") REFERENCES "public"."store_types"("id");



ALTER TABLE ONLY "public"."warehouse_slots"
    ADD CONSTRAINT "warehouse_slots_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."warehouse_slots"
    ADD CONSTRAINT "warehouse_slots_warehouse_id_fkey" FOREIGN KEY ("warehouse_id") REFERENCES "public"."warehouses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."warehouses"
    ADD CONSTRAINT "warehouses_city_id_fkey" FOREIGN KEY ("city_id") REFERENCES "public"."cities"("id");



ALTER TABLE ONLY "public"."warehouses"
    ADD CONSTRAINT "warehouses_player_id_fkey" FOREIGN KEY ("player_id") REFERENCES "public"."players"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."warehouses"
    ADD CONSTRAINT "warehouses_warehouse_type_id_fkey" FOREIGN KEY ("warehouse_type_id") REFERENCES "public"."warehouse_types"("id");



CREATE POLICY "Allow everyone to read cities" ON "public"."cities" FOR SELECT USING (true);



CREATE POLICY "Allow everyone to read factory_types" ON "public"."factory_types" FOR SELECT USING (true);



CREATE POLICY "Allow everyone to read farm_types" ON "public"."farm_types" FOR SELECT USING (true);



CREATE POLICY "Allow everyone to read field_types" ON "public"."field_types" FOR SELECT USING (true);



CREATE POLICY "Allow everyone to read logistics_vehicle_types" ON "public"."logistics_vehicle_types" FOR SELECT USING (true);



CREATE POLICY "Allow everyone to read mine_types" ON "public"."mine_types" FOR SELECT USING (true);



CREATE POLICY "Allow everyone to read store_types" ON "public"."store_types" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."logistics_company_types" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."products" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."warehouse_types" FOR SELECT USING (true);



CREATE POLICY "Players can view owned production inventory" ON "public"."production_inventory" FOR SELECT USING (((("owner_kind" = 'field'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."fields" "f"
  WHERE (("f"."id" = "production_inventory"."owner_id") AND ("f"."player_id" = "auth"."uid"()))))) OR (("owner_kind" = 'farm'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."farms" "fa"
  WHERE (("fa"."id" = "production_inventory"."owner_id") AND ("fa"."player_id" = "auth"."uid"()))))) OR (("owner_kind" = 'factory'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."factories" "fx"
  WHERE (("fx"."id" = "production_inventory"."owner_id") AND ("fx"."player_id" = "auth"."uid"()))))) OR (("owner_kind" = 'mine'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."mines" "m"
  WHERE (("m"."id" = "production_inventory"."owner_id") AND ("m"."player_id" = "auth"."uid"())))))));



CREATE POLICY "Players can view owned production slots" ON "public"."production_slots" FOR SELECT USING (((("owner_kind" = 'field'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."fields" "f"
  WHERE (("f"."id" = "production_slots"."owner_id") AND ("f"."player_id" = "auth"."uid"()))))) OR (("owner_kind" = 'farm'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."farms" "fa"
  WHERE (("fa"."id" = "production_slots"."owner_id") AND ("fa"."player_id" = "auth"."uid"()))))) OR (("owner_kind" = 'factory'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."factories" "fx"
  WHERE (("fx"."id" = "production_slots"."owner_id") AND ("fx"."player_id" = "auth"."uid"()))))) OR (("owner_kind" = 'mine'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."mines" "m"
  WHERE (("m"."id" = "production_slots"."owner_id") AND ("m"."player_id" = "auth"."uid"())))))));



CREATE POLICY "Players can view related logistics transfers" ON "public"."logistics_transfers" FOR SELECT TO "authenticated" USING ((("buyer_player_id" = "auth"."uid"()) OR ("seller_player_id" = "auth"."uid"()) OR ("vehicle_owner_player_id" = "auth"."uid"())));



CREATE POLICY "Players can view their own arge centers" ON "public"."arge_centers" FOR SELECT USING (("auth"."uid"() = "player_id"));



CREATE POLICY "Players can view their own arge researches" ON "public"."arge_researches" FOR SELECT USING (("auth"."uid"() = "player_id"));



CREATE POLICY "Players can view their own logistics companies" ON "public"."logistics_companies" FOR SELECT TO "authenticated" USING (("player_id" = "auth"."uid"()));



CREATE POLICY "Players can view their own logistics vehicles" ON "public"."logistics_vehicles" FOR SELECT TO "authenticated" USING (("player_id" = "auth"."uid"()));



CREATE POLICY "Players can view their own warehouse slots" ON "public"."warehouse_slots" FOR SELECT TO "authenticated" USING (("warehouse_id" IN ( SELECT "warehouses"."id"
   FROM "public"."warehouses"
  WHERE ("warehouses"."player_id" = "auth"."uid"()))));



CREATE POLICY "Players can view their own warehouses" ON "public"."warehouses" FOR SELECT TO "authenticated" USING (("player_id" = "auth"."uid"()));



CREATE POLICY "Users can insert their own building boosts" ON "public"."building_boosts" FOR INSERT WITH CHECK (("auth"."uid"() = "player_id"));



CREATE POLICY "Users can insert their own building constructions" ON "public"."building_constructions" FOR INSERT WITH CHECK (("auth"."uid"() = "player_id"));



CREATE POLICY "Users can insert their own building upgrades" ON "public"."building_upgrades" FOR INSERT WITH CHECK (("auth"."uid"() = "player_id"));



CREATE POLICY "Users can insert their own player data" ON "public"."players" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users can update their own building boosts" ON "public"."building_boosts" FOR UPDATE USING (("auth"."uid"() = "player_id"));



CREATE POLICY "Users can update their own building constructions" ON "public"."building_constructions" FOR UPDATE USING (("auth"."uid"() = "player_id"));



CREATE POLICY "Users can update their own building upgrades" ON "public"."building_upgrades" FOR UPDATE USING (("auth"."uid"() = "player_id"));



CREATE POLICY "Users can update their own player data" ON "public"."players" FOR UPDATE USING (("auth"."uid"() = "id"));



CREATE POLICY "Users can view their own building boosts" ON "public"."building_boosts" FOR SELECT USING (("auth"."uid"() = "player_id"));



CREATE POLICY "Users can view their own building constructions" ON "public"."building_constructions" FOR SELECT USING (("auth"."uid"() = "player_id"));



CREATE POLICY "Users can view their own building upgrades" ON "public"."building_upgrades" FOR SELECT USING (("auth"."uid"() = "player_id"));



CREATE POLICY "Users can view their own factories" ON "public"."factories" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "player_id"));



CREATE POLICY "Users can view their own farms" ON "public"."farms" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "player_id"));



CREATE POLICY "Users can view their own fields" ON "public"."fields" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "player_id"));



CREATE POLICY "Users can view their own mines" ON "public"."mines" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "player_id"));



CREATE POLICY "Users can view their own player data" ON "public"."players" FOR SELECT USING (("auth"."uid"() = "id"));



ALTER TABLE "public"."arge_centers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."arge_researches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."building_boosts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."building_constructions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."building_upgrades" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."cities" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."factories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."factory_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."farm_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."farms" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."field_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."fields" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."game_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."logistics_companies" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."logistics_company_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."logistics_transfers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."logistics_vehicle_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."logistics_vehicles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."mine_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."mines" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."mission_definitions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "mission_definitions_read_authenticated" ON "public"."mission_definitions" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."player_experience_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "player_experience_logs_select_own" ON "public"."player_experience_logs" FOR SELECT USING (("auth"."uid"() = "player_id"));



ALTER TABLE "public"."player_missions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "player_missions_insert_own" ON "public"."player_missions" FOR INSERT TO "authenticated" WITH CHECK (("player_id" = "auth"."uid"()));



CREATE POLICY "player_missions_read_own" ON "public"."player_missions" FOR SELECT TO "authenticated" USING (("player_id" = "auth"."uid"()));



CREATE POLICY "player_missions_update_own" ON "public"."player_missions" FOR UPDATE TO "authenticated" USING (("player_id" = "auth"."uid"())) WITH CHECK (("player_id" = "auth"."uid"()));



ALTER TABLE "public"."player_product_quality_levels" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."players" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."production_inventory" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."production_slots" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."store_daily_performance" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."store_slots" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."store_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."stores" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."warehouse_slots" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."warehouse_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."warehouses" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."players";






GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";











































































































































































GRANT ALL ON FUNCTION "public"."add_product_to_warehouse"("p_player_id" "uuid", "p_warehouse_id" "uuid", "p_product_id" "text", "p_quality_level" integer, "p_quantity" integer, "p_cost" numeric, "p_transport_cost" numeric, "p_release_reserved_capacity" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."add_product_to_warehouse"("p_player_id" "uuid", "p_warehouse_id" "uuid", "p_product_id" "text", "p_quality_level" integer, "p_quantity" integer, "p_cost" numeric, "p_transport_cost" numeric, "p_release_reserved_capacity" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_product_to_warehouse"("p_player_id" "uuid", "p_warehouse_id" "uuid", "p_product_id" "text", "p_quality_level" integer, "p_quantity" integer, "p_cost" numeric, "p_transport_cost" numeric, "p_release_reserved_capacity" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."add_production_slot"("p_player_id" "uuid", "p_owner_kind" "text", "p_owner_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."add_production_slot"("p_player_id" "uuid", "p_owner_kind" "text", "p_owner_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_production_slot"("p_player_id" "uuid", "p_owner_kind" "text", "p_owner_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."add_store_slot"("p_player_id" "uuid", "p_store_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."add_store_slot"("p_player_id" "uuid", "p_store_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_store_slot"("p_player_id" "uuid", "p_store_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."assign_production_slot_product"("p_player_id" "uuid", "p_production_slot_id" "uuid", "p_product_id" "text", "p_quality_level" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."assign_production_slot_product"("p_player_id" "uuid", "p_production_slot_id" "uuid", "p_product_id" "text", "p_quality_level" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."assign_production_slot_product"("p_player_id" "uuid", "p_production_slot_id" "uuid", "p_product_id" "text", "p_quality_level" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."bootstrap_game_session"() TO "anon";
GRANT ALL ON FUNCTION "public"."bootstrap_game_session"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."bootstrap_game_session"() TO "service_role";



GRANT ALL ON FUNCTION "public"."build_experience_progress_payload"("p_total_experience" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."build_experience_progress_payload"("p_total_experience" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."build_experience_progress_payload"("p_total_experience" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."build_level_progress_payload"("p_level" integer, "p_current_experience" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."build_level_progress_payload"("p_level" integer, "p_current_experience" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."build_level_progress_payload"("p_level" integer, "p_current_experience" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."build_player_mission_payload"("p_player_id" "uuid", "p_mission_id" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."build_player_mission_payload"("p_player_id" "uuid", "p_mission_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."buy_market_fuel_for_logistics_company"("p_logistics_company_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."buy_market_fuel_for_logistics_company"("p_logistics_company_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."buy_market_fuel_for_logistics_company"("p_logistics_company_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_experience_reward"("p_reason" "text", "p_meta" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_experience_reward"("p_reason" "text", "p_meta" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_experience_reward"("p_reason" "text", "p_meta" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."cancel_building_construction"("p_player_id" "uuid", "p_construction_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."cancel_building_construction"("p_player_id" "uuid", "p_construction_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_building_construction"("p_player_id" "uuid", "p_construction_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."change_production_slot_product"("p_player_id" "uuid", "p_production_slot_id" "uuid", "p_product_id" "text", "p_quality_level" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."change_production_slot_product"("p_player_id" "uuid", "p_production_slot_id" "uuid", "p_product_id" "text", "p_quality_level" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."change_production_slot_product"("p_player_id" "uuid", "p_production_slot_id" "uuid", "p_product_id" "text", "p_quality_level" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."claim_player_mission_reward"("p_mission_id" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."claim_player_mission_reward"("p_mission_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."claim_player_mission_reward"("p_mission_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."clear_store_slot_product"("p_player_id" "uuid", "p_store_slot_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."clear_store_slot_product"("p_player_id" "uuid", "p_store_slot_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."clear_store_slot_product"("p_player_id" "uuid", "p_store_slot_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_arge_research"("p_research_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."complete_arge_research"("p_research_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_arge_research"("p_research_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_building_construction"("p_player_id" "uuid", "p_construction_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."complete_building_construction"("p_player_id" "uuid", "p_construction_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_building_construction"("p_player_id" "uuid", "p_construction_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_building_upgrade"("p_player_id" "uuid", "p_upgrade_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."complete_building_upgrade"("p_player_id" "uuid", "p_upgrade_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_building_upgrade"("p_player_id" "uuid", "p_upgrade_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_due_arge_researches"() TO "anon";
GRANT ALL ON FUNCTION "public"."complete_due_arge_researches"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_due_arge_researches"() TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_due_building_boosts"("p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."complete_due_building_boosts"("p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_due_building_boosts"("p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_due_building_constructions"("p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."complete_due_building_constructions"("p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_due_building_constructions"("p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_due_building_upgrades"("p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."complete_due_building_upgrades"("p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_due_building_upgrades"("p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_due_market_transfers"("p_buyer_player_id" "uuid", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."complete_due_market_transfers"("p_buyer_player_id" "uuid", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_due_market_transfers"("p_buyer_player_id" "uuid", "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_market_transfer"("p_transfer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."complete_market_transfer"("p_transfer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_market_transfer"("p_transfer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_market_transfer_system"("p_transfer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."complete_market_transfer_system"("p_transfer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_market_transfer_system"("p_transfer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."complete_production_logistics_transfer"("p_transfer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."complete_production_logistics_transfer"("p_transfer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."complete_production_logistics_transfer"("p_transfer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_warehouse_slot"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_warehouse_slot"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_warehouse_slot"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid") TO "service_role";



GRANT ALL ON TABLE "public"."logistics_vehicles" TO "anon";
GRANT ALL ON TABLE "public"."logistics_vehicles" TO "authenticated";
GRANT ALL ON TABLE "public"."logistics_vehicles" TO "service_role";



GRANT ALL ON FUNCTION "public"."ensure_npc_rental_vehicle"("p_from_city_id" "uuid", "p_to_city_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."ensure_npc_rental_vehicle"("p_from_city_id" "uuid", "p_to_city_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_npc_rental_vehicle"("p_from_city_id" "uuid", "p_to_city_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."ensure_player_mission_rows"("p_player_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ensure_player_mission_rows"("p_player_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."ensure_player_record_exists"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."ensure_player_record_exists"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_player_record_exists"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."finish_arge_with_gold"("p_player_id" "uuid", "p_research_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."finish_arge_with_gold"("p_player_id" "uuid", "p_research_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."finish_arge_with_gold"("p_player_id" "uuid", "p_research_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."finish_building_boost"("p_player_id" "uuid", "p_boost_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."finish_building_boost"("p_player_id" "uuid", "p_boost_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."finish_building_boost"("p_player_id" "uuid", "p_boost_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."finish_building_upgrade_with_gold"("p_player_id" "uuid", "p_upgrade_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."finish_building_upgrade_with_gold"("p_player_id" "uuid", "p_upgrade_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."finish_building_upgrade_with_gold"("p_player_id" "uuid", "p_upgrade_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."finish_construction_with_gold"("p_player_id" "uuid", "p_construction_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."finish_construction_with_gold"("p_player_id" "uuid", "p_construction_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."finish_construction_with_gold"("p_player_id" "uuid", "p_construction_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."finish_market_transfer_with_stars"("p_transfer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."finish_market_transfer_with_stars"("p_transfer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."finish_market_transfer_with_stars"("p_transfer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_active_arge_researches"("p_player_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_active_arge_researches"("p_player_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_active_arge_researches"("p_player_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_active_cities"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_active_cities"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_active_cities"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_all_products_catalog"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_all_products_catalog"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_all_products_catalog"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_arge_products_with_quality"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_arge_products_with_quality"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_arge_products_with_quality"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_available_products_for_store"("p_store_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_available_products_for_store"("p_store_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_available_products_for_store"("p_store_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_buyer_active_market_transfers"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_buyer_active_market_transfers"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_buyer_active_market_transfers"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_buyer_transfer_history_items"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_buyer_transfer_history_items"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_buyer_transfer_history_items"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_buyer_transfer_map_items"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_buyer_transfer_map_items"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_buyer_transfer_map_items"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_cities_catalog"("p_only_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."get_cities_catalog"("p_only_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_cities_catalog"("p_only_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_city_map_detail"("p_city_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_city_map_detail"("p_city_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_city_map_detail"("p_city_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_experience_required_for_level"("p_level" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_experience_required_for_level"("p_level" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_experience_required_for_level"("p_level" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_factory_detail_data"("p_factory_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_factory_detail_data"("p_factory_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_factory_detail_data"("p_factory_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_factory_list_items"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_factory_list_items"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_factory_list_items"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_factory_types_catalog"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_factory_types_catalog"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_factory_types_catalog"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_farm_detail"("p_player_id" "uuid", "p_farm_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_farm_detail"("p_player_id" "uuid", "p_farm_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_farm_detail"("p_player_id" "uuid", "p_farm_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_farm_detail"("p_player_id" "uuid", "p_farm_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_farm_list_items"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_farm_list_items"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_farm_list_items"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_farm_types_catalog"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_farm_types_catalog"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_farm_types_catalog"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_field_detail_data"("p_field_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_field_detail_data"("p_field_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_field_detail_data"("p_field_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_field_list_items"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_field_list_items"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_field_list_items"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_field_types_catalog"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_field_types_catalog"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_field_types_catalog"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_logistics_company_types_catalog"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_logistics_company_types_catalog"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_logistics_company_types_catalog"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_logistics_entry_state"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_logistics_entry_state"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_logistics_entry_state"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_logistics_vehicle_types_catalog"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_logistics_vehicle_types_catalog"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_logistics_vehicle_types_catalog"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_market_buyer_store_slot_detail"("p_store_slot_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_market_buyer_store_slot_detail"("p_store_slot_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_market_buyer_store_slot_detail"("p_store_slot_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_market_buyer_warehouse_detail"("p_warehouse_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_market_buyer_warehouse_detail"("p_warehouse_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_market_buyer_warehouse_detail"("p_warehouse_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_market_listings_for_product"("p_product_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_market_listings_for_product"("p_product_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_market_listings_for_product"("p_product_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_market_product_detail"("p_product_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_market_product_detail"("p_product_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_market_product_detail"("p_product_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_market_transfer_vehicle_options"("p_buyer_warehouse_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_market_transfer_vehicle_options"("p_buyer_warehouse_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_market_transfer_vehicle_options"("p_buyer_warehouse_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_market_transfer_vehicle_options_for_store"("p_store_slot_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_market_transfer_vehicle_options_for_store"("p_store_slot_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_market_transfer_vehicle_options_for_store"("p_store_slot_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_mine_detail_data"("p_mine_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_mine_detail_data"("p_mine_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_mine_detail_data"("p_mine_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_mine_list_items"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_mine_list_items"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_mine_list_items"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_mine_types_catalog"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_mine_types_catalog"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_mine_types_catalog"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_npc_logistics_player_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_npc_logistics_player_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_npc_logistics_player_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_npc_rental_vehicle_option"("p_from_city_id" "uuid", "p_to_city_id" "uuid", "p_distance_km" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."get_npc_rental_vehicle_option"("p_from_city_id" "uuid", "p_to_city_id" "uuid", "p_distance_km" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_npc_rental_vehicle_option"("p_from_city_id" "uuid", "p_to_city_id" "uuid", "p_distance_km" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_player_active_building_boost"("p_building_kind" "text", "p_entity_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_player_active_building_boost"("p_building_kind" "text", "p_entity_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_player_active_building_boost"("p_building_kind" "text", "p_entity_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_player_active_building_upgrade"("p_building_kind" "text", "p_entity_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_player_active_building_upgrade"("p_building_kind" "text", "p_entity_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_player_active_building_upgrade"("p_building_kind" "text", "p_entity_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_player_active_warehouses_basic"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_player_active_warehouses_basic"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_player_active_warehouses_basic"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_player_active_warehouses_with_slots"("p_city_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_player_active_warehouses_with_slots"("p_city_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_player_active_warehouses_with_slots"("p_city_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_player_arge_center"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_player_arge_center"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_player_arge_center"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_player_building_constructions"("p_building_kind" "text", "p_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_player_building_constructions"("p_building_kind" "text", "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_player_building_constructions"("p_building_kind" "text", "p_status" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_player_level_from_experience"("p_experience" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_player_level_from_experience"("p_experience" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_player_level_from_experience"("p_experience" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_player_level_progress"("p_player_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_player_level_progress"("p_player_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_player_level_progress"("p_player_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_player_logistics_company"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_player_logistics_company"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_player_logistics_company"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_player_logistics_vehicle_performance"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_player_logistics_vehicle_performance"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_player_logistics_vehicle_performance"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_player_logistics_vehicles"("p_player_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_player_logistics_vehicles"("p_player_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_player_logistics_vehicles"("p_player_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_player_mission_dashboard"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_player_mission_dashboard"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_player_mission_dashboard"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_player_profile"("p_player_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_player_profile"("p_player_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_player_profile"("p_player_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_player_warehouse_detail"("p_warehouse_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_player_warehouse_detail"("p_warehouse_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_player_warehouse_detail"("p_warehouse_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_player_warehouses_raw"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_player_warehouses_raw"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_player_warehouses_raw"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_producible_products_for_owner_type"("p_player_id" "uuid", "p_owner_kind" "text", "p_type_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_producible_products_for_owner_type"("p_player_id" "uuid", "p_owner_kind" "text", "p_type_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_producible_products_for_owner_type"("p_player_id" "uuid", "p_owner_kind" "text", "p_type_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_production_input_transfer_vehicle_options"("p_warehouse_slot_id" "uuid", "p_production_inventory_id" "uuid", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_production_input_transfer_vehicle_options"("p_warehouse_slot_id" "uuid", "p_production_inventory_id" "uuid", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_production_input_transfer_vehicle_options"("p_warehouse_slot_id" "uuid", "p_production_inventory_id" "uuid", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_production_output_transfer_vehicle_options"("p_production_inventory_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_production_output_transfer_vehicle_options"("p_production_inventory_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_production_output_transfer_vehicle_options"("p_production_inventory_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_store_daily_performance"("p_player_id" "uuid", "p_store_id" "uuid", "p_days" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_store_daily_performance"("p_player_id" "uuid", "p_store_id" "uuid", "p_days" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_store_daily_performance"("p_player_id" "uuid", "p_store_id" "uuid", "p_days" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_store_history_items"("p_store_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_store_history_items"("p_store_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_store_history_items"("p_store_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_store_list_page_data"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_store_list_page_data"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_store_list_page_data"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_store_to_warehouse_vehicle_options"("p_store_slot_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_store_to_warehouse_vehicle_options"("p_store_slot_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_store_to_warehouse_vehicle_options"("p_store_slot_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_store_transfer_vehicle_options"("p_store_slot_id" "uuid", "p_warehouse_slot_id" "uuid", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_store_transfer_vehicle_options"("p_store_slot_id" "uuid", "p_warehouse_slot_id" "uuid", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_store_transfer_vehicle_options"("p_store_slot_id" "uuid", "p_warehouse_slot_id" "uuid", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_store_types_catalog"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_store_types_catalog"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_store_types_catalog"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_stores_list"("p_player_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_stores_list"("p_player_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_stores_list"("p_player_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_total_experience_for_level"("p_level" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_total_experience_for_level"("p_level" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_total_experience_for_level"("p_level" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_transfer_affected_targets"("p_transfer_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_transfer_affected_targets"("p_transfer_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_transfer_affected_targets"("p_transfer_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_transfer_vehicle_options"("p_source_kind" "text", "p_source_id" "uuid", "p_target_kind" "text", "p_target_id" "uuid", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_transfer_vehicle_options"("p_source_kind" "text", "p_source_id" "uuid", "p_target_kind" "text", "p_target_id" "uuid", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_transfer_vehicle_options"("p_source_kind" "text", "p_source_id" "uuid", "p_target_kind" "text", "p_target_id" "uuid", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_warehouse_capacity_status"("p_warehouse_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_warehouse_capacity_status"("p_warehouse_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_warehouse_capacity_status"("p_warehouse_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_warehouse_list_page_data"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_warehouse_list_page_data"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_warehouse_list_page_data"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_warehouse_type_detail"("p_type_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_warehouse_type_detail"("p_type_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_warehouse_type_detail"("p_type_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_warehouse_types_catalog"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_warehouse_types_catalog"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_warehouse_types_catalog"() TO "service_role";



GRANT ALL ON FUNCTION "public"."grant_player_experience"("p_player_id" "uuid", "p_amount" integer, "p_reason" "text", "p_meta" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."grant_player_experience"("p_player_id" "uuid", "p_amount" integer, "p_reason" "text", "p_meta" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."grant_player_experience"("p_player_id" "uuid", "p_amount" integer, "p_reason" "text", "p_meta" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."handle_arge_research_mission_progress"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."handle_arge_research_mission_progress"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."handle_building_construction_mission_progress"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."handle_building_construction_mission_progress"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."handle_building_upgrade_mission_progress"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."handle_building_upgrade_mission_progress"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."handle_logistics_transfer_mission_progress"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."handle_logistics_transfer_mission_progress"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."handle_store_sales_mission_progress"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."handle_store_sales_mission_progress"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."increment_player_mission_progress"("p_player_id" "uuid", "p_event_key" "text", "p_amount" integer, "p_meta" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."increment_player_mission_progress"("p_player_id" "uuid", "p_event_key" "text", "p_amount" integer, "p_meta" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."logistics_vehicle_matches_route"("p_route_city_a_id" "uuid", "p_route_city_b_id" "uuid", "p_from_city_id" "uuid", "p_to_city_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."logistics_vehicle_matches_route"("p_route_city_a_id" "uuid", "p_route_city_b_id" "uuid", "p_from_city_id" "uuid", "p_to_city_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."logistics_vehicle_matches_route"("p_route_city_a_id" "uuid", "p_route_city_b_id" "uuid", "p_from_city_id" "uuid", "p_to_city_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."now_turkey"() TO "anon";
GRANT ALL ON FUNCTION "public"."now_turkey"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."now_turkey"() TO "service_role";



GRANT ALL ON FUNCTION "public"."open_store_detail_page"("p_store_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."open_store_detail_page"("p_store_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."open_store_detail_page"("p_store_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."process_factory_production_entry"("p_player_id" "uuid", "p_factory_id" "uuid", "p_tick_minutes" integer, "p_max_ticks" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."process_factory_production_entry"("p_player_id" "uuid", "p_factory_id" "uuid", "p_tick_minutes" integer, "p_max_ticks" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_factory_production_entry"("p_player_id" "uuid", "p_factory_id" "uuid", "p_tick_minutes" integer, "p_max_ticks" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."process_field_farm_production_entry"("p_player_id" "uuid", "p_owner_kind" "text", "p_owner_id" "uuid", "p_tick_minutes" integer, "p_max_ticks" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."process_field_farm_production_entry"("p_player_id" "uuid", "p_owner_kind" "text", "p_owner_id" "uuid", "p_tick_minutes" integer, "p_max_ticks" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_field_farm_production_entry"("p_player_id" "uuid", "p_owner_kind" "text", "p_owner_id" "uuid", "p_tick_minutes" integer, "p_max_ticks" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."process_mine_production_entry"("p_player_id" "uuid", "p_mine_id" "uuid", "p_tick_minutes" integer, "p_max_ticks" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."process_mine_production_entry"("p_player_id" "uuid", "p_mine_id" "uuid", "p_tick_minutes" integer, "p_max_ticks" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_mine_production_entry"("p_player_id" "uuid", "p_mine_id" "uuid", "p_tick_minutes" integer, "p_max_ticks" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."process_player_production_entry"("p_player_id" "uuid", "p_owner_kind" "text", "p_owner_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."process_player_production_entry"("p_player_id" "uuid", "p_owner_kind" "text", "p_owner_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_player_production_entry"("p_player_id" "uuid", "p_owner_kind" "text", "p_owner_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."purchase_logistics_vehicle"("p_player_id" "uuid", "p_logistics_company_id" "uuid", "p_logistics_vehicle_type_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."purchase_logistics_vehicle"("p_player_id" "uuid", "p_logistics_company_id" "uuid", "p_logistics_vehicle_type_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."purchase_logistics_vehicle"("p_player_id" "uuid", "p_logistics_company_id" "uuid", "p_logistics_vehicle_type_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."refuel_logistics_vehicle"("p_player_id" "uuid", "p_vehicle_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."refuel_logistics_vehicle"("p_player_id" "uuid", "p_vehicle_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."refuel_logistics_vehicle"("p_player_id" "uuid", "p_vehicle_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."repair_logistics_vehicle"("p_player_id" "uuid", "p_vehicle_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."repair_logistics_vehicle"("p_player_id" "uuid", "p_vehicle_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."repair_logistics_vehicle"("p_player_id" "uuid", "p_vehicle_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."reserve_warehouse_capacity"("p_player_id" "uuid", "p_warehouse_id" "uuid", "p_product_id" "text", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."reserve_warehouse_capacity"("p_player_id" "uuid", "p_warehouse_id" "uuid", "p_product_id" "text", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."reserve_warehouse_capacity"("p_player_id" "uuid", "p_warehouse_id" "uuid", "p_product_id" "text", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "anon";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_factory_active"("p_factory_id" "uuid", "p_is_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."set_factory_active"("p_factory_id" "uuid", "p_is_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_factory_active"("p_factory_id" "uuid", "p_is_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_factory_product"("p_player_id" "uuid", "p_factory_id" "uuid", "p_product_id" "text", "p_quality_level" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."set_factory_product"("p_player_id" "uuid", "p_factory_id" "uuid", "p_product_id" "text", "p_quality_level" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_factory_product"("p_player_id" "uuid", "p_factory_id" "uuid", "p_product_id" "text", "p_quality_level" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_logistics_vehicle_active"("p_player_id" "uuid", "p_vehicle_id" "uuid", "p_is_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."set_logistics_vehicle_active"("p_player_id" "uuid", "p_vehicle_id" "uuid", "p_is_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_logistics_vehicle_active"("p_player_id" "uuid", "p_vehicle_id" "uuid", "p_is_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_logistics_vehicle_rental"("p_player_id" "uuid", "p_vehicle_id" "uuid", "p_is_available_for_rent" boolean, "p_rental_price" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."set_logistics_vehicle_rental"("p_player_id" "uuid", "p_vehicle_id" "uuid", "p_is_available_for_rent" boolean, "p_rental_price" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_logistics_vehicle_rental"("p_player_id" "uuid", "p_vehicle_id" "uuid", "p_is_available_for_rent" boolean, "p_rental_price" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_logistics_vehicle_route"("p_player_id" "uuid", "p_vehicle_id" "uuid", "p_route_city_a_id" "uuid", "p_route_city_b_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."set_logistics_vehicle_route"("p_player_id" "uuid", "p_vehicle_id" "uuid", "p_route_city_a_id" "uuid", "p_route_city_b_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_logistics_vehicle_route"("p_player_id" "uuid", "p_vehicle_id" "uuid", "p_route_city_a_id" "uuid", "p_route_city_b_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_mine_active"("p_mine_id" "uuid", "p_is_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."set_mine_active"("p_mine_id" "uuid", "p_is_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_mine_active"("p_mine_id" "uuid", "p_is_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_mine_product"("p_player_id" "uuid", "p_mine_id" "uuid", "p_product_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."set_mine_product"("p_player_id" "uuid", "p_mine_id" "uuid", "p_product_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_mine_product"("p_player_id" "uuid", "p_mine_id" "uuid", "p_product_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_player_avatar"("p_avatar_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."set_player_avatar"("p_avatar_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_player_avatar"("p_avatar_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_production_slot_active"("p_player_id" "uuid", "p_production_slot_id" "uuid", "p_is_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."set_production_slot_active"("p_player_id" "uuid", "p_production_slot_id" "uuid", "p_is_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_production_slot_active"("p_player_id" "uuid", "p_production_slot_id" "uuid", "p_is_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_store_slot_active"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_is_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."set_store_slot_active"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_is_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_store_slot_active"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_is_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_store_slot_price"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_price" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."set_store_slot_price"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_price" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_store_slot_price"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_price" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_store_slot_product"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_product_id" "text", "p_quality_level" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."set_store_slot_product"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_product_id" "text", "p_quality_level" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_store_slot_product"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_product_id" "text", "p_quality_level" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_warehouse_slot_price"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_price" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."set_warehouse_slot_price"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_price" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_warehouse_slot_price"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_price" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_warehouse_slot_sale_status"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_is_available_for_sale" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."set_warehouse_slot_sale_status"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_is_available_for_sale" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_warehouse_slot_sale_status"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_is_available_for_sale" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."start_arge_center_construction"("p_player_id" "uuid", "p_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."start_arge_center_construction"("p_player_id" "uuid", "p_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_arge_center_construction"("p_player_id" "uuid", "p_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."start_arge_research"("p_player_id" "uuid", "p_product_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."start_arge_research"("p_player_id" "uuid", "p_product_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_arge_research"("p_player_id" "uuid", "p_product_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."start_building_boost"("p_player_id" "uuid", "p_building_kind" "text", "p_entity_id" "uuid", "p_duration_hours" integer, "p_star_cost" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."start_building_boost"("p_player_id" "uuid", "p_building_kind" "text", "p_entity_id" "uuid", "p_duration_hours" integer, "p_star_cost" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_building_boost"("p_player_id" "uuid", "p_building_kind" "text", "p_entity_id" "uuid", "p_duration_hours" integer, "p_star_cost" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."start_building_construction"("p_player_id" "uuid", "p_building_kind" "text", "p_type_id" "uuid", "p_city_id" "uuid", "p_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."start_building_construction"("p_player_id" "uuid", "p_building_kind" "text", "p_type_id" "uuid", "p_city_id" "uuid", "p_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_building_construction"("p_player_id" "uuid", "p_building_kind" "text", "p_type_id" "uuid", "p_city_id" "uuid", "p_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."start_building_upgrade"("p_player_id" "uuid", "p_building_kind" "text", "p_entity_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."start_building_upgrade"("p_player_id" "uuid", "p_building_kind" "text", "p_entity_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_building_upgrade"("p_player_id" "uuid", "p_building_kind" "text", "p_entity_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."start_logistics_company_construction"("p_player_id" "uuid", "p_type_id" "uuid", "p_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."start_logistics_company_construction"("p_player_id" "uuid", "p_type_id" "uuid", "p_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_logistics_company_construction"("p_player_id" "uuid", "p_type_id" "uuid", "p_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."start_market_to_store_transfer"("p_market_listing_id" "uuid", "p_store_slot_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."start_market_to_store_transfer"("p_market_listing_id" "uuid", "p_store_slot_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_market_to_store_transfer"("p_market_listing_id" "uuid", "p_store_slot_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."start_market_transfer"("p_buyer_warehouse_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."start_market_transfer"("p_buyer_warehouse_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_market_transfer"("p_buyer_warehouse_id" "uuid", "p_seller_slot_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."start_production_to_warehouse_transfer"("p_production_inventory_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."start_production_to_warehouse_transfer"("p_production_inventory_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_production_to_warehouse_transfer"("p_production_inventory_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."start_store_to_warehouse_transfer"("p_store_slot_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."start_store_to_warehouse_transfer"("p_store_slot_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_store_to_warehouse_transfer"("p_store_slot_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."start_warehouse_to_production_transfer"("p_warehouse_slot_id" "uuid", "p_production_inventory_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."start_warehouse_to_production_transfer"("p_warehouse_slot_id" "uuid", "p_production_inventory_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_warehouse_to_production_transfer"("p_warehouse_slot_id" "uuid", "p_production_inventory_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."start_warehouse_to_store_transfer"("p_store_slot_id" "uuid", "p_warehouse_slot_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."start_warehouse_to_store_transfer"("p_store_slot_id" "uuid", "p_warehouse_slot_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_warehouse_to_store_transfer"("p_store_slot_id" "uuid", "p_warehouse_slot_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."start_warehouse_to_warehouse_transfer"("p_warehouse_slot_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."start_warehouse_to_warehouse_transfer"("p_warehouse_slot_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_warehouse_to_warehouse_transfer"("p_warehouse_slot_id" "uuid", "p_buyer_warehouse_id" "uuid", "p_quantity" integer, "p_vehicle_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."sync_player_mission_snapshot"("p_player_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sync_player_mission_snapshot"("p_player_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."to_turkey_time"("p_value" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."to_turkey_time"("p_value" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."to_turkey_time"("p_value" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."transfer_production_inventory_to_warehouse"("p_player_id" "uuid", "p_production_inventory_id" "uuid", "p_warehouse_id" "uuid", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."transfer_production_inventory_to_warehouse"("p_player_id" "uuid", "p_production_inventory_id" "uuid", "p_warehouse_id" "uuid", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."transfer_production_inventory_to_warehouse"("p_player_id" "uuid", "p_production_inventory_id" "uuid", "p_warehouse_id" "uuid", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."transfer_store_slot_to_warehouse"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_warehouse_id" "uuid", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."transfer_store_slot_to_warehouse"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_warehouse_id" "uuid", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."transfer_store_slot_to_warehouse"("p_player_id" "uuid", "p_store_slot_id" "uuid", "p_warehouse_id" "uuid", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."transfer_warehouse_fuel_to_logistics_company"("p_logistics_company_id" "uuid", "p_warehouse_slot_id" "uuid", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."transfer_warehouse_fuel_to_logistics_company"("p_logistics_company_id" "uuid", "p_warehouse_slot_id" "uuid", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."transfer_warehouse_fuel_to_logistics_company"("p_logistics_company_id" "uuid", "p_warehouse_slot_id" "uuid", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."transfer_warehouse_slot_to_production_inventory"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_production_inventory_id" "uuid", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."transfer_warehouse_slot_to_production_inventory"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_production_inventory_id" "uuid", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."transfer_warehouse_slot_to_production_inventory"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_production_inventory_id" "uuid", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."transfer_warehouse_slot_to_store_slot"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_store_slot_id" "uuid", "p_quantity" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."transfer_warehouse_slot_to_store_slot"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_store_slot_id" "uuid", "p_quantity" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."transfer_warehouse_slot_to_store_slot"("p_player_id" "uuid", "p_warehouse_slot_id" "uuid", "p_store_slot_id" "uuid", "p_quantity" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."upgrade_player_product_quality"("p_player_id" "uuid", "p_product_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."upgrade_player_product_quality"("p_player_id" "uuid", "p_product_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."upgrade_player_product_quality"("p_player_id" "uuid", "p_product_id" "text") TO "service_role";
























GRANT ALL ON TABLE "public"."arge_centers" TO "anon";
GRANT ALL ON TABLE "public"."arge_centers" TO "authenticated";
GRANT ALL ON TABLE "public"."arge_centers" TO "service_role";



GRANT ALL ON TABLE "public"."arge_researches" TO "anon";
GRANT ALL ON TABLE "public"."arge_researches" TO "authenticated";
GRANT ALL ON TABLE "public"."arge_researches" TO "service_role";



GRANT ALL ON TABLE "public"."building_boosts" TO "anon";
GRANT ALL ON TABLE "public"."building_boosts" TO "authenticated";
GRANT ALL ON TABLE "public"."building_boosts" TO "service_role";



GRANT ALL ON TABLE "public"."building_constructions" TO "anon";
GRANT ALL ON TABLE "public"."building_constructions" TO "authenticated";
GRANT ALL ON TABLE "public"."building_constructions" TO "service_role";



GRANT ALL ON TABLE "public"."building_upgrades" TO "anon";
GRANT ALL ON TABLE "public"."building_upgrades" TO "authenticated";
GRANT ALL ON TABLE "public"."building_upgrades" TO "service_role";



GRANT ALL ON TABLE "public"."cities" TO "anon";
GRANT ALL ON TABLE "public"."cities" TO "authenticated";
GRANT ALL ON TABLE "public"."cities" TO "service_role";



GRANT ALL ON TABLE "public"."factories" TO "anon";
GRANT ALL ON TABLE "public"."factories" TO "authenticated";
GRANT ALL ON TABLE "public"."factories" TO "service_role";



GRANT ALL ON TABLE "public"."factory_types" TO "anon";
GRANT ALL ON TABLE "public"."factory_types" TO "authenticated";
GRANT ALL ON TABLE "public"."factory_types" TO "service_role";



GRANT ALL ON TABLE "public"."farm_types" TO "anon";
GRANT ALL ON TABLE "public"."farm_types" TO "authenticated";
GRANT ALL ON TABLE "public"."farm_types" TO "service_role";



GRANT ALL ON TABLE "public"."farms" TO "anon";
GRANT ALL ON TABLE "public"."farms" TO "authenticated";
GRANT ALL ON TABLE "public"."farms" TO "service_role";



GRANT ALL ON TABLE "public"."field_types" TO "anon";
GRANT ALL ON TABLE "public"."field_types" TO "authenticated";
GRANT ALL ON TABLE "public"."field_types" TO "service_role";



GRANT ALL ON TABLE "public"."fields" TO "anon";
GRANT ALL ON TABLE "public"."fields" TO "authenticated";
GRANT ALL ON TABLE "public"."fields" TO "service_role";



GRANT ALL ON TABLE "public"."game_settings" TO "anon";
GRANT ALL ON TABLE "public"."game_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."game_settings" TO "service_role";



GRANT ALL ON TABLE "public"."logistics_companies" TO "anon";
GRANT ALL ON TABLE "public"."logistics_companies" TO "authenticated";
GRANT ALL ON TABLE "public"."logistics_companies" TO "service_role";



GRANT ALL ON TABLE "public"."logistics_company_types" TO "anon";
GRANT ALL ON TABLE "public"."logistics_company_types" TO "authenticated";
GRANT ALL ON TABLE "public"."logistics_company_types" TO "service_role";



GRANT ALL ON TABLE "public"."logistics_transfers" TO "anon";
GRANT ALL ON TABLE "public"."logistics_transfers" TO "authenticated";
GRANT ALL ON TABLE "public"."logistics_transfers" TO "service_role";



GRANT ALL ON TABLE "public"."logistics_vehicle_types" TO "anon";
GRANT ALL ON TABLE "public"."logistics_vehicle_types" TO "authenticated";
GRANT ALL ON TABLE "public"."logistics_vehicle_types" TO "service_role";



GRANT ALL ON TABLE "public"."mine_types" TO "anon";
GRANT ALL ON TABLE "public"."mine_types" TO "authenticated";
GRANT ALL ON TABLE "public"."mine_types" TO "service_role";



GRANT ALL ON TABLE "public"."mines" TO "anon";
GRANT ALL ON TABLE "public"."mines" TO "authenticated";
GRANT ALL ON TABLE "public"."mines" TO "service_role";



GRANT ALL ON TABLE "public"."mission_definitions" TO "anon";
GRANT ALL ON TABLE "public"."mission_definitions" TO "authenticated";
GRANT ALL ON TABLE "public"."mission_definitions" TO "service_role";



GRANT ALL ON TABLE "public"."player_experience_logs" TO "anon";
GRANT ALL ON TABLE "public"."player_experience_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."player_experience_logs" TO "service_role";



GRANT ALL ON TABLE "public"."player_missions" TO "anon";
GRANT ALL ON TABLE "public"."player_missions" TO "authenticated";
GRANT ALL ON TABLE "public"."player_missions" TO "service_role";



GRANT ALL ON TABLE "public"."player_product_quality_levels" TO "anon";
GRANT ALL ON TABLE "public"."player_product_quality_levels" TO "authenticated";
GRANT ALL ON TABLE "public"."player_product_quality_levels" TO "service_role";



GRANT ALL ON TABLE "public"."players" TO "anon";
GRANT ALL ON TABLE "public"."players" TO "authenticated";
GRANT ALL ON TABLE "public"."players" TO "service_role";



GRANT ALL ON TABLE "public"."production_inventory" TO "anon";
GRANT ALL ON TABLE "public"."production_inventory" TO "authenticated";
GRANT ALL ON TABLE "public"."production_inventory" TO "service_role";



GRANT ALL ON TABLE "public"."production_slots" TO "anon";
GRANT ALL ON TABLE "public"."production_slots" TO "authenticated";
GRANT ALL ON TABLE "public"."production_slots" TO "service_role";



GRANT ALL ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT ALL ON TABLE "public"."products" TO "service_role";



GRANT ALL ON TABLE "public"."store_daily_performance" TO "anon";
GRANT ALL ON TABLE "public"."store_daily_performance" TO "authenticated";
GRANT ALL ON TABLE "public"."store_daily_performance" TO "service_role";



GRANT ALL ON TABLE "public"."store_slots" TO "anon";
GRANT ALL ON TABLE "public"."store_slots" TO "authenticated";
GRANT ALL ON TABLE "public"."store_slots" TO "service_role";



GRANT ALL ON TABLE "public"."store_types" TO "anon";
GRANT ALL ON TABLE "public"."store_types" TO "authenticated";
GRANT ALL ON TABLE "public"."store_types" TO "service_role";



GRANT ALL ON TABLE "public"."stores" TO "anon";
GRANT ALL ON TABLE "public"."stores" TO "authenticated";
GRANT ALL ON TABLE "public"."stores" TO "service_role";



GRANT ALL ON TABLE "public"."warehouse_slots" TO "anon";
GRANT ALL ON TABLE "public"."warehouse_slots" TO "authenticated";
GRANT ALL ON TABLE "public"."warehouse_slots" TO "service_role";



GRANT ALL ON TABLE "public"."warehouse_types" TO "anon";
GRANT ALL ON TABLE "public"."warehouse_types" TO "authenticated";
GRANT ALL ON TABLE "public"."warehouse_types" TO "service_role";



GRANT ALL ON TABLE "public"."warehouses" TO "anon";
GRANT ALL ON TABLE "public"."warehouses" TO "authenticated";
GRANT ALL ON TABLE "public"."warehouses" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";




































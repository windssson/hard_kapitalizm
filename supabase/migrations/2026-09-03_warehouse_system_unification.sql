-- ============================================================================
-- MIGRATION: 2026-09-03_warehouse_system_unification.sql
-- Depo Sisteminin Şehir Genel Depo Mimarisine Tam Uyumlanması:
-- 1. Katalogda sadece Genel Depo listelenir (eski 0 TL mağaza tipleri filtrelendi).
-- 2. Depo listelerinde sadece aktif Genel Depolar listelenir (deprecated depolar gizlendi).
-- 3. Şehirde 2. Genel Depo kurulması engellendi (tek Genel Depo kuralı).
-- 4. Şehirde aktif işletmesi (mağaza, fabrika, tarla vb.) olan oyuncunun son Genel Depoyu satması engellendi.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. get_warehouse_types_catalog: Sadece Genel Depo (cost > 0 veya name = 'Genel Depo')
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_warehouse_types_catalog()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT coalesce(
    jsonb_agg(to_jsonb(wt) ORDER BY wt.required_level, wt.cost),
    '[]'::jsonb
  )
  FROM public.warehouse_types wt
  WHERE wt.name = 'Genel Depo' OR wt.cost > 0;
$function$;

-- ----------------------------------------------------------------------------
-- 2. get_warehouse_list_page_data: Sadece aktif Genel Depolar listelenir
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_warehouse_list_page_data()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  WITH live_rows AS (
    SELECT
      w.id,
      w.created_at AS sort_time,
      w.name AS sort_name,
      false AS is_under_construction,
      w.is_active,
      coalesce(w.capacity, 0) AS total_capacity,
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
        'warehouse_kind', w.warehouse_kind,
        'store_id', w.store_id,
        'city', jsonb_build_object('name', c.name),
        'warehouse_type', jsonb_build_object(
          'id', wt.id,
          'name', wt.name,
          'icon', wt.icon,
          'base_capacity', wt.base_capacity,
          'cost', wt.cost,
          'required_level', wt.required_level,
          'construction_time_minutes', wt.construction_time_minutes,
          'accepted_product_ids', wt.accepted_product_ids
        ),
        'warehouse_slots', coalesce(slot_rows.slots, '[]'::jsonb),
        'is_under_construction', false
      ) AS payload
    FROM public.warehouses w
    JOIN public.cities c ON c.id = w.city_id
    LEFT JOIN public.warehouse_types wt ON wt.id = w.warehouse_type_id
    LEFT JOIN LATERAL (
      SELECT coalesce(
        jsonb_agg(
          jsonb_build_object(
            'id', ws.id,
            'product_id', ws.product_id,
            'product_name', p.urun_adi,
            'quantity', ws.quantity,
            'quality_level', ws.quality_level,
            'brand_id', ws.brand_id,
            'price', ws.price,
            'cost', ws.cost,
            'is_available_for_sale', ws.is_available_for_sale,
            'product', CASE
              WHEN p.id IS NULL THEN NULL
              ELSE jsonb_build_object(
                'id', p.id,
                'urun_adi', p.urun_adi,
                'urun_iconu', p.urun_iconu,
                'birim_hacim', p.birim_hacim
              )
            END
          )
          ORDER BY ws.created_at
        ),
        '[]'::jsonb
      ) AS slots
      FROM public.warehouse_slots ws
      LEFT JOIN public.products p ON p.id = ws.product_id
      WHERE ws.warehouse_id = w.id
    ) slot_rows ON true
    WHERE w.player_id = auth.uid()
      AND w.is_active = true
      AND (w.warehouse_kind IS NULL OR w.warehouse_kind IN ('general', 'normal'))
  ),
  construction_rows AS (
    SELECT
      bc.id,
      bc.started_at AS sort_time,
      coalesce(nullif(bc.params ->> 'name', ''), wt.name, 'Genel Depo') AS sort_name,
      true AS is_under_construction,
      false AS is_active,
      coalesce((bc.params ->> 'capacity')::numeric, 0) AS total_capacity,
      jsonb_build_object(
        'id', bc.id,
        'player_id', bc.player_id,
        'warehouse_type_id', bc.params ->> 'warehouse_type_id',
        'city_id', bc.params ->> 'city_id',
        'name', coalesce(nullif(bc.params ->> 'name', ''), wt.name, 'Genel Depo'),
        'level', coalesce((bc.params ->> 'level')::integer, 1),
        'capacity', coalesce((bc.params ->> 'capacity')::numeric, 0),
        'reserved_capacity', coalesce((bc.params ->> 'reserved_capacity')::numeric, 0),
        'is_active', false,
        'created_at', bc.started_at,
        'updated_at', bc.started_at,
        'warehouse_kind', coalesce(bc.params ->> 'warehouse_kind', 'general'),
        'store_id', bc.params ->> 'store_id',
        'city', jsonb_build_object('name', c.name),
        'warehouse_type', jsonb_build_object(
          'id', wt.id,
          'name', wt.name,
          'icon', wt.icon,
          'base_capacity', wt.base_capacity,
          'cost', wt.cost,
          'required_level', wt.required_level,
          'construction_time_minutes', wt.construction_time_minutes,
          'accepted_product_ids', wt.accepted_product_ids
        ),
        'warehouse_slots', '[]'::jsonb,
        'is_under_construction', true,
        'finish_at', bc.finish_at
      ) AS payload
    FROM public.building_constructions bc
    LEFT JOIN public.warehouse_types wt
      ON wt.id = nullif(bc.params ->> 'warehouse_type_id', '')::uuid
    LEFT JOIN public.cities c
      ON c.id = nullif(bc.params ->> 'city_id', '')::uuid
    WHERE bc.player_id = auth.uid()
      AND bc.building_kind = 'warehouse'
      AND bc.status = 'in_progress'
  ),
  combined AS (
    SELECT * FROM live_rows
    UNION ALL
    SELECT * FROM construction_rows
  )
  SELECT jsonb_build_object(
    'success', true,
    'warehouses', coalesce(
      (
        SELECT jsonb_agg(payload ORDER BY sort_time ASC, sort_name ASC)
        FROM combined
      ),
      '[]'::jsonb
    ),
    'summary', jsonb_build_object(
      'total_count', coalesce((SELECT count(*) FROM combined), 0),
      'active_count', coalesce((SELECT count(*) FROM live_rows WHERE is_active IS true), 0),
      'construction_count', coalesce((SELECT count(*) FROM construction_rows), 0),
      'total_capacity', coalesce((SELECT sum(total_capacity) FROM live_rows), 0)
    )
  );
$function$;

-- ----------------------------------------------------------------------------
-- 3. get_player_active_warehouses_basic: Deprecated depoları filtrele
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_player_active_warehouses_basic()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT coalesce(
    jsonb_agg(
      (
        to_jsonb(w) ||
        jsonb_build_object(
          'reserved_capacity', w.reserved_capacity + coalesce(
            (
              SELECT sum(coalesce(ws.quantity, 0) * coalesce(p.birim_hacim, 0))
              FROM public.warehouse_slots ws
              JOIN public.products p ON p.id = ws.product_id
              WHERE ws.warehouse_id = w.id
            ),
            0
          ),
          'warehouse_slots',
          coalesce(
            (
              SELECT jsonb_agg(
                to_jsonb(ws) ||
                jsonb_build_object('product', to_jsonb(p))
                ORDER BY ws.id
              )
              FROM public.warehouse_slots ws
              LEFT JOIN public.products p ON p.id = ws.product_id
              WHERE ws.warehouse_id = w.id
            ),
            '[]'::jsonb
          ),
          'city',
          (
            SELECT jsonb_build_object('name', c.name)
            FROM public.cities c
            WHERE c.id = w.city_id
          )
        )
      )
      ORDER BY w.created_at
    ),
    '[]'::jsonb
  )
  FROM public.warehouses w
  WHERE w.player_id = auth.uid()
    AND w.is_active = true
    AND (w.warehouse_kind IS NULL OR w.warehouse_kind IN ('general', 'normal'));
$function$;

-- ----------------------------------------------------------------------------
-- 4. get_player_warehouses_raw: Deprecated depoları filtrele
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_player_warehouses_raw()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT coalesce(
    jsonb_agg(
      (
        to_jsonb(w) ||
        jsonb_build_object(
          'reserved_capacity', w.reserved_capacity + coalesce(
            (
              SELECT sum(coalesce(ws.quantity, 0) * coalesce(p.birim_hacim, 0))
              FROM public.warehouse_slots ws
              JOIN public.products p ON p.id = ws.product_id
              WHERE ws.warehouse_id = w.id
            ),
            0
          ),
          'warehouse_slots',
          coalesce(
            (
              SELECT jsonb_agg(
                to_jsonb(ws) ||
                jsonb_build_object('product', to_jsonb(p))
                ORDER BY ws.id
              )
              FROM public.warehouse_slots ws
              LEFT JOIN public.products p ON p.id = ws.product_id
              WHERE ws.warehouse_id = w.id
            ),
            '[]'::jsonb
          ),
          'city',
          (
            SELECT to_jsonb(c)
            FROM public.cities c
            WHERE c.id = w.city_id
          ),
          'warehouse_type',
          (
            SELECT to_jsonb(wt)
            FROM public.warehouse_types wt
            WHERE wt.id = w.warehouse_type_id
          )
        )
      )
      ORDER BY w.created_at
    ),
    '[]'::jsonb
  )
  FROM public.warehouses w
  WHERE w.player_id = auth.uid()
    AND w.is_active = true
    AND (w.warehouse_kind IS NULL OR w.warehouse_kind IN ('general', 'normal'));
$function$;

-- ----------------------------------------------------------------------------
-- 5. start_building_construction: Aynı şehirde 2. Genel Depo kurulamaz kuralı
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.start_building_construction(
  p_player_id uuid,
  p_city_id uuid,
  p_building_kind text,
  p_type_id uuid,
  p_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_player public.players%rowtype;
  v_cost integer;
  v_required_level integer;
  v_construction_time_minutes integer;
  v_construction_id uuid;
  v_finish_at timestamptz;
  v_params jsonb;
  v_clean_name text;
BEGIN
  -- Vergi Bloğu Kontrolü
  IF public.is_player_tax_blocked(p_player_id) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Vergi borcu limiti asildigi icin insaat baslatilamaz.');
  END IF;

  SELECT * INTO v_player FROM public.players WHERE id = p_player_id FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.'); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cities WHERE id = p_city_id AND is_active = true) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Sehir bulunamadi.');
  END IF;
  IF EXISTS (SELECT 1 FROM public.building_constructions WHERE player_id = p_player_id AND status = 'in_progress') THEN
    RETURN jsonb_build_object('success', false, 'message', 'Devam eden bir insaat zaten var.');
  END IF;

  v_clean_name := nullif(trim(p_name), '');

  -- KURAL 1: Depo haricindeki tüm binalar (store, factory, field, farm, mine) için o şehirde Genel Depo bulunması zorunludur!
  IF p_building_kind <> 'warehouse' THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.warehouses
      WHERE player_id = p_player_id
        AND city_id = p_city_id
        AND is_active = true
        AND (warehouse_kind IS NULL OR warehouse_kind IN ('general', 'normal'))
    ) THEN
      RETURN jsonb_build_object(
        'success', false,
        'code', 'GENEL_DEPO_GEREKLI',
        'message', 'Bu şehirde ticari faaliyet başlatabilmek için önce bir Genel Depo kurmalısınız.'
      );
    END IF;
  END IF;

  -- KURAL 2: Aynı şehirde en fazla 1 adet Genel Depo bulunabilir!
  IF p_building_kind = 'warehouse' THEN
    IF EXISTS (
      SELECT 1 FROM public.warehouses
      WHERE player_id = p_player_id
        AND city_id = p_city_id
        AND is_active = true
        AND (warehouse_kind IS NULL OR warehouse_kind IN ('general', 'normal'))
    ) OR EXISTS (
      SELECT 1 FROM public.building_constructions
      WHERE player_id = p_player_id
        AND building_kind = 'warehouse'
        AND status = 'in_progress'
        AND (params ->> 'city_id')::uuid = p_city_id
    ) THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Bu şehirde zaten aktif veya inşaatı süren bir Genel Deponuz bulunmaktadır. Her şehirde en fazla 1 adet Genel Depo bulunabilir. Kapasiteyi artırmak için mevcut deponuzu yükseltebilirsiniz.'
      );
    END IF;
  END IF;

  IF p_building_kind = 'store' THEN
    SELECT coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object(
        'store_type_id', id,
        'city_id', p_city_id,
        'name', coalesce(v_clean_name, name),
        'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1),
        'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1,
        'current_slot_count', 0,
        'max_slot_count', coalesce(max_slot_count, 0),
        'slot_capacity', coalesce(slot_capacity, 0)
      )
    INTO v_cost, v_required_level, v_construction_time_minutes, v_params
    FROM public.store_types WHERE id = p_type_id;
  ELSIF p_building_kind = 'warehouse' THEN
    SELECT coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('warehouse_type_id', id, 'city_id', p_city_id, 'name', coalesce(v_clean_name, 'Genel Depo'), 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'capacity', coalesce(base_capacity, 15000), 'reserved_capacity', 0)
    INTO v_cost, v_required_level, v_construction_time_minutes, v_params
    FROM public.warehouse_types WHERE id = p_type_id;
  ELSIF p_building_kind = 'factory' THEN
    SELECT coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('factory_type_id', id, 'city_id', p_city_id, 'name', coalesce(v_clean_name, name), 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'quality_level', 0, 'boost_multiplier', 1.00, 'input_capacity', coalesce(input_capacity, 0), 'output_capacity', coalesce(output_capacity, 0))
    INTO v_cost, v_required_level, v_construction_time_minutes, v_params
    FROM public.factory_types WHERE id = p_type_id;
  ELSIF p_building_kind = 'field' THEN
    SELECT coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('field_type_id', id, 'city_id', p_city_id, 'name', coalesce(v_clean_name, name), 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'current_slot_count', 0, 'max_slot_count', coalesce(max_slot_count, 5),
        'input_capacity', coalesce(input_capacity, 0), 'output_capacity', coalesce(output_capacity, 0))
    INTO v_cost, v_required_level, v_construction_time_minutes, v_params
    FROM public.field_types WHERE id = p_type_id;
  ELSIF p_building_kind = 'farm' THEN
    SELECT coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('farm_type_id', id, 'city_id', p_city_id, 'name', coalesce(v_clean_name, name), 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'current_slot_count', 0, 'max_slot_count', coalesce(max_slot_count, 5),
        'input_capacity', coalesce(input_capacity, 0), 'output_capacity', coalesce(output_capacity, 0))
    INTO v_cost, v_required_level, v_construction_time_minutes, v_params
    FROM public.farm_types WHERE id = p_type_id;
  ELSIF p_building_kind = 'mine' THEN
    SELECT coalesce(cost, 0), coalesce(required_level, 1), coalesce(construction_time_minutes, 0),
      jsonb_build_object('mine_type_id', id, 'city_id', p_city_id, 'name', coalesce(v_clean_name, name), 'cost', coalesce(cost, 0),
        'required_level', coalesce(required_level, 1), 'construction_time_minutes', coalesce(construction_time_minutes, 0),
        'level', 1, 'output_capacity', coalesce(output_capacity, 0))
    INTO v_cost, v_required_level, v_construction_time_minutes, v_params
    FROM public.mine_types WHERE id = p_type_id;
  ELSE
    RETURN jsonb_build_object('success', false, 'message', 'Desteklenmeyen yapi tipi.');
  END IF;

  IF v_cost IS NULL THEN RETURN jsonb_build_object('success', false, 'message', 'Yapi tipi bulunamadi.'); END IF;
  IF coalesce(v_player.level, 1) < v_required_level THEN RETURN jsonb_build_object('success', false, 'message', 'Seviye yetersiz.'); END IF;
  IF coalesce(v_player.cash, 0) < v_cost THEN RETURN jsonb_build_object('success', false, 'message', 'Yetersiz nakit.'); END IF;

  UPDATE public.players SET cash = cash - v_cost WHERE id = p_player_id;
  PERFORM public.log_player_cash_change(
    p_player_id, -v_cost, v_player.cash,
    'building_construction',
    format('Bina insaati: %s (%s)', coalesce(v_clean_name, p_building_kind), p_building_kind),
    p_city_id, 'city'
  );

  v_finish_at := timezone('utc', now()) + make_interval(mins => v_construction_time_minutes);
  INSERT INTO public.building_constructions (player_id, building_kind, params, status, started_at, finish_at, completed_at)
  VALUES (p_player_id, p_building_kind, v_params, 'in_progress', timezone('utc', now()), v_finish_at, null)
  RETURNING id INTO v_construction_id;

  RETURN jsonb_build_object(
    'success', true, 'construction_id', v_construction_id, 'building_kind', p_building_kind,
    'status', 'in_progress', 'started_at', timezone('utc', now()), 'finish_at', v_finish_at,
    'duration_minutes', v_construction_time_minutes, 'cost', v_cost
  );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 6. sell_building: Şehirde aktif işletmeler varsa son Genel Depo satılamaz!
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sell_building(p_building_id uuid, p_building_kind text, p_confirm boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_player_id uuid := auth.uid();
  v_now timestamptz := timezone('utc', now());
  v_base_cost numeric := 0;
  v_upgrades_cost numeric := 0;
  v_stock_refund numeric := 0;
  v_total_refund numeric := 0;
  v_building_name text := '';
  v_warehouse_slot_ids uuid[] := '{}'::uuid[];
  v_production_inventory_ids uuid[] := '{}'::uuid[];
  v_warehouse public.warehouses%rowtype;
BEGIN
  IF v_player_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  END IF;

  IF p_building_kind = 'store' THEN
    RETURN public.sell_store(p_building_id, p_confirm);
  END IF;

  -- 1. Depo Satışı
  IF p_building_kind = 'warehouse' THEN
    SELECT w.*
    INTO v_warehouse
    FROM public.warehouses w
    WHERE w.id = p_building_id
      AND w.player_id = v_player_id
    FOR UPDATE OF w;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'message', 'Depo bulunamadi veya size ait degil.');
    END IF;

    -- KURAL: Eğer şehirde başka aktif depo yoksa ve şehirde aktif işletmeler varsa depo satılamaz!
    IF (
      SELECT count(*)
      FROM public.warehouses
      WHERE player_id = v_player_id
        AND city_id = v_warehouse.city_id
        AND id <> p_building_id
        AND is_active = true
        AND (warehouse_kind IS NULL OR warehouse_kind IN ('general', 'normal'))
    ) = 0 THEN
      IF EXISTS (
        SELECT 1 FROM public.stores WHERE player_id = v_player_id AND city_id = v_warehouse.city_id AND is_active = true
        UNION ALL
        SELECT 1 FROM public.factories WHERE player_id = v_player_id AND city_id = v_warehouse.city_id AND is_active = true
        UNION ALL
        SELECT 1 FROM public.farms WHERE player_id = v_player_id AND city_id = v_warehouse.city_id AND is_active = true
        UNION ALL
        SELECT 1 FROM public.fields WHERE player_id = v_player_id AND city_id = v_warehouse.city_id AND is_active = true
        UNION ALL
        SELECT 1 FROM public.mines WHERE player_id = v_player_id AND city_id = v_warehouse.city_id AND is_active = true
      ) THEN
        RETURN jsonb_build_object(
          'success', false,
          'message', 'Bu şehirde aktif işletmeleriniz (mağaza, fabrika, tarla vb.) bulunmaktadır. İşletmeler satılmadan şehrin son Genel Deposu satılamaz.'
        );
      END IF;
    END IF;

    v_building_name := v_warehouse.name;

    SELECT coalesce(array_agg(ws.id), '{}'::uuid[])
    INTO v_warehouse_slot_ids
    FROM public.warehouse_slots ws
    WHERE ws.warehouse_id = p_building_id;

    IF EXISTS (
      SELECT 1
      FROM public.logistics_transfers lt
      WHERE lt.status = 'in_transit'
        AND (
          lt.buyer_warehouse_id = p_building_id
          OR lt.seller_warehouse_id = p_building_id
          OR lt.seller_warehouse_slot_id = ANY(v_warehouse_slot_ids)
        )
    ) THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Depoya bagli aktif transferler tamamlanmadan satis yapilamaz.'
      );
    END IF;

    IF EXISTS (
      SELECT 1
      FROM public.building_upgrades bu
      WHERE bu.player_id = v_player_id
        AND bu.status = 'in_progress'
        AND bu.building_kind = 'warehouse'
        AND bu.entity_id = p_building_id
    ) THEN
      RETURN jsonb_build_object(
        'success', false,
        'message', 'Depo icin devam eden bir yukseltme var.'
      );
    END IF;

    SELECT coalesce(wt.cost, 20000)
    INTO v_base_cost
    FROM public.warehouse_types wt
    WHERE wt.id = v_warehouse.warehouse_type_id;

    IF v_base_cost = 0 THEN
      v_base_cost := 20000;
    END IF;

    SELECT coalesce(sum(coalesce((bu.params ->> 'upgrade_cost')::numeric, 0)), 0)
    INTO v_upgrades_cost
    FROM public.building_upgrades bu
    WHERE bu.player_id = v_player_id
      AND bu.building_kind = 'warehouse'
      AND bu.entity_id = p_building_id
      AND bu.status = 'completed';

    SELECT coalesce(sum(ws.quantity * ws.cost), 0)
    INTO v_stock_refund
    FROM public.warehouse_slots ws
    WHERE ws.warehouse_id = p_building_id;

    v_total_refund := v_base_cost + v_upgrades_cost + v_stock_refund;

    IF p_confirm = false THEN
      RETURN jsonb_build_object(
        'success', true,
        'construction_refund', round(v_base_cost + v_upgrades_cost, 2),
        'stock_refund', round(v_stock_refund, 2),
        'total_refund', round(v_total_refund, 2),
        'message', 'Depo satis teklifi hazirlandi.'
      );
    END IF;

    -- İlişkileri temizle ve sil
    UPDATE public.logistics_transfer_items
    SET source_warehouse_slot_id = NULL,
        target_warehouse_slot_id = NULL,
        updated_at = v_now
    WHERE source_warehouse_slot_id = ANY(v_warehouse_slot_ids)
       OR target_warehouse_slot_id = ANY(v_warehouse_slot_ids);

    UPDATE public.logistics_finance_entries
    SET related_warehouse_slot_id = NULL
    WHERE related_warehouse_slot_id = ANY(v_warehouse_slot_ids);

    UPDATE public.logistics_transfers
    SET buyer_warehouse_id = CASE WHEN buyer_warehouse_id = p_building_id THEN NULL ELSE buyer_warehouse_id END,
        seller_warehouse_id = CASE WHEN seller_warehouse_id = p_building_id THEN NULL ELSE seller_warehouse_id END,
        seller_warehouse_slot_id = CASE WHEN seller_warehouse_slot_id = ANY(v_warehouse_slot_ids) THEN NULL ELSE seller_warehouse_slot_id END,
        updated_at = v_now
    WHERE buyer_warehouse_id = p_building_id
       OR seller_warehouse_id = p_building_id
       OR seller_warehouse_slot_id = ANY(v_warehouse_slot_ids);

    DELETE FROM public.building_boosts
    WHERE building_kind = 'warehouse' AND entity_id = p_building_id;

    DELETE FROM public.building_upgrades
    WHERE building_kind = 'warehouse' AND entity_id = p_building_id;

    DELETE FROM public.warehouse_slots
    WHERE warehouse_id = p_building_id;

    DELETE FROM public.warehouses
    WHERE id = p_building_id;

  -- 2. Fabrika, Tarla, Çiftlik veya Maden Satışı
  ELSIF p_building_kind IN ('factory', 'field', 'farm', 'mine') THEN
    IF p_building_kind = 'factory' THEN
      SELECT f.name, coalesce(ft.cost, 0)
      INTO v_building_name, v_base_cost
      FROM public.factories f
      JOIN public.factory_types ft ON ft.id = f.factory_type_id
      WHERE f.id = p_building_id AND f.player_id = v_player_id;
    ELSIF p_building_kind = 'field' THEN
      SELECT f.name, coalesce(ft.cost, 0)
      INTO v_building_name, v_base_cost
      FROM public.fields f
      JOIN public.field_types ft ON ft.id = f.field_type_id
      WHERE f.id = p_building_id AND f.player_id = v_player_id;
    ELSIF p_building_kind = 'farm' THEN
      SELECT f.name, coalesce(ft.cost, 0)
      INTO v_building_name, v_base_cost
      FROM public.farms f
      JOIN public.farm_types ft ON ft.id = f.farm_type_id
      WHERE f.id = p_building_id AND f.player_id = v_player_id;
    ELSIF p_building_kind = 'mine' THEN
      SELECT m.name, coalesce(mt.cost, 0)
      INTO v_building_name, v_base_cost
      FROM public.mines m
      JOIN public.mine_types mt ON mt.id = m.mine_type_id
      WHERE m.id = p_building_id AND m.player_id = v_player_id;
    END IF;

    IF v_building_name IS NULL OR v_building_name = '' THEN
      RETURN jsonb_build_object('success', false, 'message', 'Uretim birimi bulunamadi veya size ait degil.');
    END IF;

    SELECT coalesce(array_agg(pi.id), '{}'::uuid[])
    INTO v_production_inventory_ids
    FROM public.production_inventory pi
    WHERE pi.owner_id = p_building_id
      AND pi.owner_kind = p_building_kind;

    IF EXISTS (
      SELECT 1
      FROM public.logistics_transfers lt
      WHERE lt.status = 'in_transit'
        AND (
          lt.seller_production_inventory_id = ANY(v_production_inventory_ids)
          OR lt.buyer_production_inventory_id = ANY(v_production_inventory_ids)
        )
    ) THEN
      RETURN jsonb_build_object('success', false, 'message', 'Uretim birimine bagli aktif transferler tamamlanmadan satis yapilamaz.');
    END IF;

    IF EXISTS (
      SELECT 1
      FROM public.building_upgrades bu
      WHERE bu.player_id = v_player_id
        AND bu.status = 'in_progress'
        AND bu.building_kind = p_building_kind
        AND bu.entity_id = p_building_id
    ) THEN
      RETURN jsonb_build_object('success', false, 'message', 'Uretim birimi icin devam eden bir yukseltme var.');
    END IF;

    -- Check active production
    IF p_building_kind IN ('farm', 'field') AND EXISTS (
      SELECT 1
      FROM public.production_slots ps
      WHERE ps.owner_id = p_building_id
        AND ps.owner_kind = p_building_kind
        AND ps.is_active = true
        AND ps.product_id IS NOT NULL
    ) THEN
      RETURN jsonb_build_object('success', false, 'message', 'Uretim biriminde aktif uretim devam ediyor.');
    ELSIF p_building_kind = 'factory' AND EXISTS (
      SELECT 1
      FROM public.factories f
      WHERE f.id = p_building_id
        AND f.is_active = true
        AND f.product_id IS NOT NULL
    ) THEN
      RETURN jsonb_build_object('success', false, 'message', 'Fabrikada aktif uretim devam ediyor.');
    ELSIF p_building_kind = 'mine' AND EXISTS (
      SELECT 1
      FROM public.mines m
      WHERE m.id = p_building_id
        AND m.is_active = true
        AND m.product_id IS NOT NULL
    ) THEN
      RETURN jsonb_build_object('success', false, 'message', 'Madende aktif uretim devam ediyor.');
    END IF;

    SELECT coalesce(sum(coalesce((bu.params ->> 'upgrade_cost')::numeric, 0)), 0)
    INTO v_upgrades_cost
    FROM public.building_upgrades bu
    WHERE bu.player_id = v_player_id
      AND bu.building_kind = p_building_kind
      AND bu.entity_id = p_building_id
      AND bu.status = 'completed';

    SELECT coalesce(sum(pi.quantity * pi.cost), 0)
    INTO v_stock_refund
    FROM public.production_inventory pi
    WHERE pi.owner_id = p_building_id
      AND pi.owner_kind = p_building_kind;

    v_total_refund := v_base_cost + v_upgrades_cost + v_stock_refund;

    IF p_confirm = false THEN
      RETURN jsonb_build_object(
        'success', true,
        'construction_refund', round(v_base_cost + v_upgrades_cost, 2),
        'stock_refund', round(v_stock_refund, 2),
        'total_refund', round(v_total_refund, 2),
        'message', 'Uretim birimi satis teklifi hazirlandi.'
      );
    END IF;

    -- İlişkileri temizle ve sil
    UPDATE public.logistics_transfer_items
    SET target_production_inventory_id = NULL,
        updated_at = v_now
    WHERE target_production_inventory_id = ANY(v_production_inventory_ids);

    UPDATE public.logistics_transfers
    SET seller_production_inventory_id = CASE WHEN seller_production_inventory_id = ANY(v_production_inventory_ids) THEN NULL ELSE seller_production_inventory_id END,
        buyer_production_inventory_id = CASE WHEN buyer_production_inventory_id = ANY(v_production_inventory_ids) THEN NULL ELSE buyer_production_inventory_id END,
        updated_at = v_now
    WHERE seller_production_inventory_id = ANY(v_production_inventory_ids)
       OR buyer_production_inventory_id = ANY(v_production_inventory_ids);

    DELETE FROM public.production_inventory
    WHERE owner_id = p_building_id AND owner_kind = p_building_kind;

    DELETE FROM public.production_slots
    WHERE owner_id = p_building_id AND owner_kind = p_building_kind;

    DELETE FROM public.building_boosts
    WHERE building_kind = 'warehouse' AND entity_id = p_building_id;

    DELETE FROM public.building_upgrades
    WHERE building_kind = p_building_kind AND entity_id = p_building_id;

    IF p_building_kind = 'factory' THEN
      DELETE FROM public.factories WHERE id = p_building_id;
    ELSIF p_building_kind = 'field' THEN
      DELETE FROM public.fields WHERE id = p_building_id;
    ELSIF p_building_kind = 'farm' THEN
      DELETE FROM public.farms WHERE id = p_building_id;
    ELSIF p_building_kind = 'mine' THEN
      DELETE FROM public.mines WHERE id = p_building_id;
    END IF;

  ELSE
    RETURN jsonb_build_object('success', false, 'message', 'Gecersiz bina turu.');
  END IF;

  -- Para iadesini oyuncuya aktar
  UPDATE public.players
  SET cash = cash + v_total_refund
  WHERE id = v_player_id;

  PERFORM public.log_player_cash_change(
    v_player_id,
    v_total_refund,
    (SELECT cash - v_total_refund FROM public.players WHERE id = v_player_id),
    p_building_kind || '_sale',
    format('%s satildi: %s | Toplam iade %s TL', p_building_kind, v_building_name, round(v_total_refund, 2)),
    p_building_id,
    p_building_kind
  );

  RETURN jsonb_build_object(
    'success', true,
    'construction_refund', round(v_base_cost + v_upgrades_cost, 2),
    'stock_refund', round(v_stock_refund, 2),
    'total_refund', round(v_total_refund, 2),
    'message', format('%s satildi.', v_building_name),
    'changed', jsonb_build_object('player', public.get_player_profile(v_player_id))
  );
END;
$function$;

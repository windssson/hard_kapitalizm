-- Create player_taxes table
CREATE TABLE IF NOT EXISTS public.player_taxes (
    player_id uuid NOT NULL PRIMARY KEY REFERENCES public.players(id) ON DELETE CASCADE,
    tax_debt numeric NOT NULL DEFAULT 0,
    created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Enable RLS for player_taxes
ALTER TABLE public.player_taxes ENABLE ROW LEVEL SECURITY;

-- Drop policy if exists and create
DROP POLICY IF EXISTS "Allow individual read access" ON public.player_taxes;
CREATE POLICY "Allow individual read access" ON public.player_taxes
    FOR SELECT USING (auth.uid() = player_id);

-- Create get_player_tax_debt function
CREATE OR REPLACE FUNCTION public.get_player_tax_debt()
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_tax numeric;
BEGIN
  if v_player_id is null then
    return 0;
  end if;
  select tax_debt into v_tax from public.player_taxes where player_id = v_player_id;
  return coalesce(v_tax, 0);
END;
$$;

-- Create pay_tax_debt function
CREATE OR REPLACE FUNCTION public.pay_tax_debt(p_amount numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_player_id uuid := auth.uid();
  v_current_cash numeric;
  v_current_tax numeric;
  v_paid_amount numeric;
BEGIN
  if v_player_id is null then
    return jsonb_build_object('success', false, 'message', 'Oturum acilmamis.');
  end if;

  if p_amount <= 0 then
    return jsonb_build_object('success', false, 'message', 'Gecersiz odeme tutari.');
  end if;

  -- Lock player and tax records
  select cash into v_current_cash from public.players where id = v_player_id for update;
  if v_current_cash is null then
    return jsonb_build_object('success', false, 'message', 'Oyuncu bulunamadi.');
  end if;

  select tax_debt into v_current_tax from public.player_taxes where player_id = v_player_id for update;
  if v_current_tax is null or v_current_tax <= 0 then
    return jsonb_build_object('success', false, 'message', 'Vergi borcunuz bulunmamaktadir.');
  end if;

  v_paid_amount := p_amount;
  if v_paid_amount > v_current_tax then
    v_paid_amount := v_current_tax;
  end if;

  if v_current_cash < v_paid_amount then
    return jsonb_build_object('success', false, 'message', 'Yetersiz nakit bakiye.');
  end if;

  update public.players
  set cash = cash - v_paid_amount
  where id = v_player_id;

  update public.player_taxes
  set tax_debt = tax_debt - v_paid_amount,
      updated_at = now()
  where player_id = v_player_id;

  perform public.log_player_cash_change(
    v_player_id,
    -v_paid_amount,
    v_current_cash,
    'tax_payment',
    format('Vergi odemesi: %s TL', round(v_paid_amount, 2)),
    null,
    'tax'
  );

  return jsonb_build_object(
    'success', true,
    'message', format('%s TL vergi borcu odendi.', round(v_paid_amount, 2)),
    'paid_amount', v_paid_amount,
    'remaining_tax_debt', v_current_tax - v_paid_amount,
    'remaining_cash', v_current_cash - v_paid_amount
  );
END;
$$;

-- Update open_store_detail_page to calculate and upsert tax
CREATE OR REPLACE FUNCTION public.open_store_detail_page(p_store_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = 'public'
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
  v_brand_level integer := 1;
  v_mkt_speed_mult numeric := 1.0;
  v_mkt_price_mult numeric := 1.0;
  v_mkt_speed_contrib numeric := 0.0;
  v_mkt_price_contrib numeric := 0.0;
  v_elapsed_minutes numeric;
  v_boost_bonus_minutes numeric;
  v_base_demand numeric;
  v_generated_demand numeric;
  v_available_demand numeric;
  v_price_ratio numeric;
  v_price_multiplier numeric;
  v_quality_multiplier numeric;
  v_brand_multiplier numeric;
  v_sold_qty integer;
  v_revenue numeric;
  v_profit numeric;
  v_pending_after numeric;
  v_performance_date date := timezone('Europe/Istanbul', v_now)::date;
  v_exp_result jsonb := null;
  
  -- Tax variables
  v_tax_rate numeric := 0.0;
  v_tax_amount numeric := 0.0;
  v_total_tax_amount numeric := 0.0;
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

  -- Get store's city tax rate
  select coalesce(tax_rate, 0.0)
  into v_tax_rate
  from public.cities
  where id = v_store.city_id;

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
        ss.brand_id,
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

      -- Fetch marketing campaign overlap contributions
      select
        coalesce(
          sum(
            greatest(
              extract(
                epoch from least(c.active_until, v_now)
                - greatest(c.created_at, v_slot.last_sale_processed_at)
              ) / 60.0,
              0
            ) * case c.campaign_type
              when 'local' then 0.15
              when 'regional' then 0.30
              when 'global' then 0.50
              else 0.0
            end
          ),
          0
        ),
        coalesce(
          sum(
            greatest(
              extract(
                epoch from least(c.active_until, v_now)
                - greatest(c.created_at, v_slot.last_sale_processed_at)
              ) / 60.0,
              0
            ) * case c.campaign_type
              when 'local' then 0.05
              when 'regional' then 0.10
              when 'global' then 0.20
              else 0.0
            end
          ),
          0
        )
      into v_mkt_speed_contrib, v_mkt_price_contrib
      from public.brand_marketing_campaigns c
      where c.player_id = v_player_id
        and c.created_at < v_now
        and c.active_until > v_slot.last_sale_processed_at;

      if v_elapsed_minutes > 0 then
        v_mkt_speed_mult := 1.0 + (v_mkt_speed_contrib / v_elapsed_minutes);
        v_mkt_price_mult := 1.0 + (v_mkt_price_contrib / v_elapsed_minutes);
      else
        v_mkt_speed_mult := 1.0;
        v_mkt_price_mult := 1.0;
      end if;

      v_processed := true;
      v_elapsed_minutes_max := greatest(v_elapsed_minutes_max, floor(v_elapsed_minutes)::int);
      v_quality_multiplier := 1 + (greatest(v_slot.quality_level, 1) - 1) * 0.10;
      
      v_brand_level := 1;
      if v_slot.brand_id is not null and v_slot.brand_id <> '00000000-0000-0000-0000-000000000000'::uuid then
        select coalesce(brand_level, 1)
        into v_brand_level
        from public.brand_companies
        where id = v_slot.brand_id;
      end if;

      v_brand_multiplier := case
        when coalesce(v_slot.brand_id, '00000000-0000-0000-0000-000000000000'::uuid)
          = '00000000-0000-0000-0000-000000000000'::uuid then 1.0
        else case v_brand_level
          when 1 then 1.10
          when 2 then 1.15
          when 3 then 1.20
          when 4 then 1.25
          else 1.35
        end
      end;

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
        v_price_ratio := v_slot.price / (v_slot.baz_satis_fiyati * public.store_quality_price_multiplier(v_slot.quality_level) * v_mkt_price_mult);

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
        * v_brand_multiplier
        * v_price_multiplier
        * v_mkt_speed_mult;

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

        -- Calculate tax for this sale
        v_tax_amount := v_revenue * v_tax_rate;
        v_total_tax_amount := v_total_tax_amount + v_tax_amount;

        -- Update Brand XP & Brand Level
        if v_slot.brand_id is not null and v_slot.brand_id <> '00000000-0000-0000-0000-000000000000'::uuid then
          update public.brand_companies
          set brand_xp = brand_xp + v_sold_qty,
              brand_level = public.calculate_brand_level(brand_xp + v_sold_qty),
              updated_at = v_now
          where id = v_slot.brand_id;
        end if;

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

    -- Add sale revenue to player balance
    if v_total_revenue > 0 then
      update public.players
      set cash = cash + v_total_revenue
      where id = v_player_id;
      perform public.log_player_cash_change(
        v_player_id,
        v_total_revenue,
        (select cash - v_total_revenue from public.players where id = v_player_id),
        'store_sale',
        format('Magaza satisi: %s adet, %s TL gelir', v_total_sold_quantity, round(v_total_revenue, 2)),
        p_store_id,
        'store'
      );
    end if;

    -- Add sales tax to player's tax debt via upsert
    if v_total_tax_amount > 0 then
      insert into public.player_taxes (player_id, tax_debt, updated_at)
      values (v_player_id, v_total_tax_amount, v_now)
      on conflict (player_id)
      do update set
        tax_debt = public.player_taxes.tax_debt + excluded.tax_debt,
        updated_at = excluded.updated_at;
    end if;

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
    'slots', coalesce(slot_data.slots, '[]'::jsonb),
    'store_warehouse', store_warehouse_data.payload,
    'store_warehouse_id', store_warehouse_data.store_warehouse_id,
    'store_warehouse_name', store_warehouse_data.store_warehouse_name,
    'store_warehouse_capacity', store_warehouse_data.store_warehouse_capacity,
    'store_warehouse_used_capacity', store_warehouse_data.store_warehouse_used_capacity,
    'store_warehouse_slots', coalesce(store_warehouse_data.store_warehouse_slots, '[]'::jsonb)
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
            'brand_id', ss.brand_id,
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
  left join lateral (
    select
      w.id as store_warehouse_id,
      w.name as store_warehouse_name,
      coalesce(w.capacity, 0) as store_warehouse_capacity,
      coalesce(warehouse_summary.used_capacity, 0) as store_warehouse_used_capacity,
      coalesce(warehouse_summary.slots, '[]'::jsonb) as store_warehouse_slots,
      jsonb_build_object(
        'id', w.id,
        'name', w.name,
        'capacity', coalesce(w.capacity, 0),
        'used_capacity', coalesce(warehouse_summary.used_capacity, 0),
        'slots', coalesce(warehouse_summary.slots, '[]'::jsonb)
      ) as payload
    from public.warehouses w
    left join lateral (
      select
        coalesce(sum(ws.quantity * coalesce(p.birim_hacim, 0)), 0) as used_capacity,
        coalesce(
          jsonb_agg(
            jsonb_build_object(
              'id', ws.id,
              'product_id', ws.product_id,
              'product_name', p.urun_adi,
              'product_icon', p.urun_iconu,
              'quality_level', ws.quality_level,
              'brand_id', ws.brand_id,
              'quantity', ws.quantity,
              'cost', ws.cost
            )
            order by ws.created_at asc
          ),
          '[]'::jsonb
        ) as slots
      from public.warehouse_slots ws
      left join public.products p on p.id = ws.product_id
      where ws.warehouse_id = w.id
    ) warehouse_summary on true
    where w.store_id = s.id
      and w.warehouse_kind = 'store'
      and w.is_active = true
    order by w.created_at desc
    limit 1
  ) store_warehouse_data on true
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
      'history_dirty', coalesce((v_sale_result ->>'processed')::boolean, false),
      'performance_dirty',
        coalesce((v_sale_result ->>'processed')::boolean, false)
        or coalesce((v_sale_result ->>'completed_boost_count')::integer, 0) > 0
    )
  );
end;
$$;

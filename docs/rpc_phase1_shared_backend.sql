create or replace function public.get_active_cities()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(row_to_json(c) order by c.name),
    '[]'::jsonb
  )
  from public.cities c
  where c.is_active is true;
$$;

create or replace function public.get_player_building_constructions(
  p_building_kind text
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(row_to_json(bc) order by bc.started_at),
    '[]'::jsonb
  )
  from public.building_constructions bc
  where bc.player_id = auth.uid()
    and bc.building_kind = p_building_kind
    and bc.status = 'in_progress';
$$;

create or replace function public.get_warehouse_types_catalog()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(row_to_json(wt) order by wt.required_level, wt.cost),
    '[]'::jsonb
  )
  from public.warehouse_types wt;
$$;

create or replace function public.get_store_types_catalog()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(row_to_json(st) order by st.required_level, st.cost),
    '[]'::jsonb
  )
  from public.store_types st;
$$;

create or replace function public.get_all_products_catalog()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(row_to_json(p) order by p.urun_adi),
    '[]'::jsonb
  )
  from public.products p;
$$;

create or replace function public.get_market_product_detail(
  p_product_id text
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select to_jsonb(p)
  from public.products p
  where p.id = p_product_id;
$$;

create or replace function public.get_city_map_detail(
  p_city_id uuid
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', c.id,
    'name', c.name,
    'map_position_x', c.map_position_x,
    'map_position_y', c.map_position_y
  )
  from public.cities c
  where c.id = p_city_id;
$$;

create or replace function public.get_player_active_warehouses_basic()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', w.id,
        'name', w.name,
        'city_id', w.city_id,
        'is_active', w.is_active,
        'city', jsonb_build_object('name', c.name)
      )
      order by w.created_at
    ),
    '[]'::jsonb
  )
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  where w.player_id = auth.uid()
    and w.is_active is true;
$$;

create or replace function public.get_player_warehouses_raw()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
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
        'warehouse_type', jsonb_build_object('icon', wt.icon),
        'warehouse_slots', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', ws.id,
              'product_id', ws.product_id,
              'product_name', ws.product_name,
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
                  'urun_iconu', p.urun_iconu
                )
              end
            )
            order by ws.created_at
          )
          from public.warehouse_slots ws
          left join public.products p on p.id = ws.product_id
          where ws.warehouse_id = w.id
        ), '[]'::jsonb)
      )
      order by w.created_at
    ),
    '[]'::jsonb
  )
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  left join public.warehouse_types wt on wt.id = w.warehouse_type_id
  where w.player_id = auth.uid();
$$;

create or replace function public.get_player_warehouse_detail(
  p_warehouse_id uuid
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
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
    'warehouse_type', to_jsonb(wt),
    'warehouse_slots', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', ws.id,
          'product_id', ws.product_id,
          'product_name', ws.product_name,
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
              'urun_iconu', p.urun_iconu
            )
          end
        )
        order by ws.created_at
      )
      from public.warehouse_slots ws
      left join public.products p on p.id = ws.product_id
      where ws.warehouse_id = w.id
    ), '[]'::jsonb)
  )
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  left join public.warehouse_types wt on wt.id = w.warehouse_type_id
  where w.id = p_warehouse_id
    and w.player_id = auth.uid();
$$;

create or replace function public.get_warehouse_type_detail(
  p_type_id uuid
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select to_jsonb(wt)
  from public.warehouse_types wt
  where wt.id = p_type_id;
$$;

create or replace function public.get_market_buyer_warehouse_detail(
  p_warehouse_id uuid
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', w.id,
    'name', w.name,
    'city_id', w.city_id,
    'is_active', w.is_active,
    'city', jsonb_build_object(
      'name', c.name,
      'map_position_x', c.map_position_x,
      'map_position_y', c.map_position_y
    ),
    'warehouse_type', jsonb_build_object('icon', wt.icon)
  )
  from public.warehouses w
  join public.cities c on c.id = w.city_id
  left join public.warehouse_types wt on wt.id = w.warehouse_type_id
  where w.id = p_warehouse_id
    and w.player_id = auth.uid();
$$;

create or replace function public.get_market_buyer_store_slot_detail(
  p_store_slot_id uuid
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'id', ss.id,
    'store_id', ss.store_id,
    'product_id', ss.product_id,
    'quality_level', ss.quality_level,
    'quantity', ss.quantity,
    'pending_quantity', ss.pending_quantity,
    'capacity', ss.capacity,
    'store', jsonb_build_object(
      'id', s.id,
      'name', s.name,
      'city_id', s.city_id,
      'is_active', s.is_active,
      'city', jsonb_build_object(
        'id', c.id,
        'name', c.name,
        'map_position_x', c.map_position_x,
        'map_position_y', c.map_position_y
      )
    )
  )
  from public.store_slots ss
  join public.stores s on s.id = ss.store_id
  join public.cities c on c.id = s.city_id
  where ss.id = p_store_slot_id
    and s.player_id = auth.uid();
$$;

create or replace function public.get_buyer_active_market_transfers()
returns jsonb
language sql
security definer
set search_path = public
as $$
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
      order by lt.finish_at asc
    ),
    '[]'::jsonb
  )
  from public.logistics_transfers lt
  where lt.buyer_player_id = auth.uid()
    and lt.status = 'in_transit';
$$;

create or replace function public.get_logistics_company_types_catalog()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(row_to_json(lct) order by lct.required_level, lct.cost),
    '[]'::jsonb
  )
  from public.logistics_company_types lct;
$$;

create or replace function public.get_logistics_vehicle_types_catalog()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(row_to_json(lvt) order by lvt.purchase_price),
    '[]'::jsonb
  )
  from public.logistics_vehicle_types lvt;
$$;

create or replace function public.get_player_logistics_company()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select to_jsonb(lc)
  from public.logistics_companies lc
  where lc.player_id = auth.uid()
  order by lc.created_at
  limit 1;
$$;

create or replace function public.get_player_logistics_vehicle_performance()
returns jsonb
language sql
security definer
set search_path = public
as $$
  with stats as (
    select
      lt.logistics_vehicle_id as vehicle_id,
      count(*)::int as total_trips,
      count(*) filter (where lt.status = 'completed')::int as completed_trips,
      count(*) filter (where lt.status = 'in_transit')::int as active_trips,
      count(*) filter (where lt.is_rental is true)::int as rental_trips,
      coalesce(sum(case when lt.is_rental is true then lt.rental_cost else 0 end), 0) as rental_revenue,
      max(coalesce(lt.completed_at, lt.finish_at, lt.started_at)) as last_activity_at
    from public.logistics_transfers lt
    where lt.vehicle_owner_player_id = auth.uid()
      and lt.logistics_vehicle_id is not null
    group by lt.logistics_vehicle_id
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'vehicle_id', s.vehicle_id,
        'total_trips', s.total_trips,
        'completed_trips', s.completed_trips,
        'active_trips', s.active_trips,
        'rental_trips', s.rental_trips,
        'rental_revenue', s.rental_revenue,
        'last_activity_at', s.last_activity_at
      )
      order by s.last_activity_at desc nulls last
    ),
    '[]'::jsonb
  )
  from stats s;
$$;

create or replace function public.get_buyer_transfer_history_items()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
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
        'product', jsonb_build_object(
          'id', p.id,
          'urun_adi', p.urun_adi,
          'urun_iconu', p.urun_iconu
        ),
        'seller_warehouse', case
          when sw.id is null then null
          else jsonb_build_object(
            'id', sw.id,
            'name', sw.name,
            'city', jsonb_build_object('id', scw.id, 'name', scw.name)
          )
        end,
        'seller_store', case
          when ss.id is null then null
          else jsonb_build_object(
            'id', ss.id,
            'name', ss.name,
            'city', jsonb_build_object('id', scs.id, 'name', scs.name)
          )
        end,
        'seller_production_inventory', case
          when spi.id is null then null
          else jsonb_build_object(
            'id', spi.id,
            'inventory_type', spi.inventory_type
          )
        end,
        'buyer_warehouse', case
          when bw.id is null then null
          else jsonb_build_object(
            'id', bw.id,
            'name', bw.name,
            'city', jsonb_build_object('id', bcw.id, 'name', bcw.name)
          )
        end,
        'buyer_store', case
          when bs.id is null then null
          else jsonb_build_object(
            'id', bs.id,
            'name', bs.name,
            'city', jsonb_build_object('id', bcs.id, 'name', bcs.name)
          )
        end,
        'buyer_production_inventory', case
          when bpi.id is null then null
          else jsonb_build_object(
            'id', bpi.id,
            'inventory_type', bpi.inventory_type
          )
        end
      )
      order by lt.completed_at desc
    ),
    '[]'::jsonb
  )
  from public.logistics_transfers lt
  join public.products p on p.id = lt.product_id
  left join public.warehouses sw on sw.id = lt.seller_warehouse_id
  left join public.cities scw on scw.id = sw.city_id
  left join public.stores ss on ss.id = lt.seller_store_id
  left join public.cities scs on scs.id = ss.city_id
  left join public.production_inventory spi on spi.id = lt.seller_production_inventory_id
  left join public.warehouses bw on bw.id = lt.buyer_warehouse_id
  left join public.cities bcw on bcw.id = bw.city_id
  left join public.stores bs on bs.id = lt.buyer_store_id
  left join public.cities bcs on bcs.id = bs.city_id
  left join public.production_inventory bpi on bpi.id = lt.buyer_production_inventory_id
  where lt.buyer_player_id = auth.uid()
    and lt.status <> 'in_transit';
$$;

create or replace function public.ensure_player_record_exists(
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.players where id = p_user_id) then
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
      'Oyuncu_' || substring(p_user_id::text from 1 for 4),
      'Yeni Holding',
      'ae1.webp',
      1,
      0,
      100000,
      100
    );
  end if;

  return jsonb_build_object('success', true);
end;
$$;

create or replace function public.set_player_avatar(
  p_avatar_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.players
  set avatar_id = p_avatar_id
  where id = auth.uid();

  return jsonb_build_object('success', true, 'avatar_id', p_avatar_id);
end;
$$;

create or replace function public.get_arge_products_with_quality()
returns jsonb
language sql
security definer
set search_path = public
as $$
  with quality_map as (
    select
      ppql.product_id,
      ppql.max_quality_level
    from public.player_product_quality_levels ppql
    where ppql.player_id = auth.uid()
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'urun_adi', p.urun_adi,
        'urun_iconu', p.urun_iconu,
        'baz_satis_fiyati', p.baz_satis_fiyati,
        'uretim_birimi', p.uretim_birimi,
        'current_quality_level', coalesce(q.max_quality_level, 1)
      )
      order by p.urun_adi
    ),
    '[]'::jsonb
  )
  from public.products p
  left join quality_map q on q.product_id = p.id;
$$;

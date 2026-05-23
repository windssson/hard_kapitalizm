create or replace function public.ensure_player_record_exists(
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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

create or replace function public.set_player_avatar(
  p_avatar_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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

create or replace function public.get_cities_catalog(
  p_only_active boolean default false
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(to_jsonb(c) order by c.name),
    '[]'::jsonb
  )
  from public.cities c
  where (not p_only_active) or c.is_active = true;
$$;

create or replace function public.get_active_cities()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select public.get_cities_catalog(true);
$$;

create or replace function public.get_warehouse_types_catalog()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(to_jsonb(wt) order by wt.required_level, wt.cost),
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
    jsonb_agg(to_jsonb(st) order by st.required_level, st.cost),
    '[]'::jsonb
  )
  from public.store_types st;
$$;

create or replace function public.get_factory_types_catalog()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(to_jsonb(ft) order by ft.required_level, ft.cost),
    '[]'::jsonb
  )
  from public.factory_types ft;
$$;

create or replace function public.get_farm_types_catalog()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(to_jsonb(ft) order by ft.required_level, ft.cost),
    '[]'::jsonb
  )
  from public.farm_types ft;
$$;

create or replace function public.get_field_types_catalog()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(to_jsonb(ft) order by ft.required_level, ft.cost),
    '[]'::jsonb
  )
  from public.field_types ft;
$$;

create or replace function public.get_mine_types_catalog()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(to_jsonb(mt) order by mt.required_level, mt.cost),
    '[]'::jsonb
  )
  from public.mine_types mt;
$$;

create or replace function public.get_all_products_catalog()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(to_jsonb(p) order by p.urun_adi),
    '[]'::jsonb
  )
  from public.products p;
$$;

create or replace function public.get_player_building_constructions(
  p_building_kind text,
  p_status text default null
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(to_jsonb(bc) order by bc.started_at),
    '[]'::jsonb
  )
  from public.building_constructions bc
  where bc.player_id = auth.uid()
    and bc.building_kind = p_building_kind
    and (p_status is null or bc.status = p_status);
$$;

create or replace function public.get_player_warehouses_raw()
returns jsonb
language sql
security definer
set search_path = public
as $$
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

create or replace function public.get_player_warehouse_detail(
  p_warehouse_id uuid
)
returns jsonb
language sql
security definer
set search_path = public
as $$
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

create or replace function public.get_player_active_warehouses_basic()
returns jsonb
language sql
security definer
set search_path = public
as $$
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

create or replace function public.get_player_active_warehouses_with_slots(
  p_city_id uuid default null
)
returns jsonb
language sql
security definer
set search_path = public
as $$
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

create or replace function public.set_factory_active(
  p_factory_id uuid,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
$$;

create or replace function public.set_mine_active(
  p_mine_id uuid,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
$$;

create or replace function public.get_factory_list_items()
returns jsonb
language sql
security definer
set search_path = public
as $$
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
$$;

create or replace function public.get_factory_detail_data(
  p_factory_id uuid
)
returns jsonb
language sql
security definer
set search_path = public
as $$
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
$$;

create or replace function public.get_farm_list_items()
returns jsonb
language sql
security definer
set search_path = public
as $$
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
$$;

create or replace function public.get_field_list_items()
returns jsonb
language sql
security definer
set search_path = public
as $$
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
$$;

create or replace function public.get_field_detail_data(
  p_field_id uuid
)
returns jsonb
language sql
security definer
set search_path = public
as $$
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
$$;

create or replace function public.get_mine_list_items()
returns jsonb
language sql
security definer
set search_path = public
as $$
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
$$;

create or replace function public.get_mine_detail_data(
  p_mine_id uuid
)
returns jsonb
language sql
security definer
set search_path = public
as $$
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
$$;

create or replace function public.get_store_history_items(
  p_store_id uuid
)
returns jsonb
language sql
security definer
set search_path = public
as $$
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

create or replace function public.get_market_buyer_warehouse_detail(
  p_warehouse_id uuid
)
returns jsonb
language sql
security definer
set search_path = public
as $$
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

create or replace function public.get_market_buyer_store_slot_detail(
  p_store_slot_id uuid
)
returns jsonb
language sql
security definer
set search_path = public
as $$
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
      order by lt.finish_at
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
    jsonb_agg(to_jsonb(lct) order by lct.required_level, lct.cost),
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
    jsonb_agg(to_jsonb(lvt) order by lvt.purchase_price),
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

create or replace function public.get_buyer_transfer_history_items()
returns jsonb
language sql
security definer
set search_path = public
as $$
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
$$;

create or replace function public.get_arge_products_with_quality()
returns jsonb
language sql
security definer
set search_path = public
as $$
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

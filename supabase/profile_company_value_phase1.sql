create or replace function public.calculate_player_company_value(
  p_player_id uuid
)
returns jsonb
language sql
stable
set search_path to 'public'
as $$
  with building_base_assets as (
    select coalesce(sum(asset_value), 0)::numeric as total_value
    from (
      select coalesce(st.cost, 0)::numeric as asset_value
      from public.stores s
      join public.store_types st on st.id = s.store_type_id
      where s.player_id = p_player_id

      union all

      select coalesce(wt.cost, 0)::numeric
      from public.warehouses w
      join public.warehouse_types wt on wt.id = w.warehouse_type_id
      where w.player_id = p_player_id

      union all

      select coalesce(ft.cost, 0)::numeric
      from public.factories f
      join public.factory_types ft on ft.id = f.factory_type_id
      where f.player_id = p_player_id

      union all

      select coalesce(ft.cost, 0)::numeric
      from public.fields f
      join public.field_types ft on ft.id = f.field_type_id
      where f.player_id = p_player_id

      union all

      select coalesce(ft.cost, 0)::numeric
      from public.farms f
      join public.farm_types ft on ft.id = f.farm_type_id
      where f.player_id = p_player_id

      union all

      select coalesce(mt.cost, 0)::numeric
      from public.mines m
      join public.mine_types mt on mt.id = m.mine_type_id
      where m.player_id = p_player_id

      union all

      select coalesce(lct.cost, 0)::numeric
      from public.logistics_companies lc
      cross join lateral (
        select cost
        from public.logistics_company_types
        order by cost desc, created_at asc
        limit 1
      ) lct
      where lc.player_id = p_player_id

      union all

      select 25000::numeric
      from public.arge_centers ac
      where ac.player_id = p_player_id
    ) assets
  ),
  building_upgrade_assets as (
    select coalesce(sum(coalesce((bu.params ->> 'upgrade_cost')::numeric, 0)), 0)::numeric as total_value
    from public.building_upgrades bu
    where bu.player_id = p_player_id
      and bu.status = 'completed'
      and (
        (bu.building_kind = 'store' and exists (
          select 1 from public.stores s where s.id = bu.entity_id and s.player_id = p_player_id
        ))
        or (bu.building_kind = 'warehouse' and exists (
          select 1 from public.warehouses w where w.id = bu.entity_id and w.player_id = p_player_id
        ))
        or (bu.building_kind = 'factory' and exists (
          select 1 from public.factories f where f.id = bu.entity_id and f.player_id = p_player_id
        ))
        or (bu.building_kind = 'field' and exists (
          select 1 from public.fields f where f.id = bu.entity_id and f.player_id = p_player_id
        ))
        or (bu.building_kind = 'farm' and exists (
          select 1 from public.farms f where f.id = bu.entity_id and f.player_id = p_player_id
        ))
        or (bu.building_kind = 'mine' and exists (
          select 1 from public.mines m where m.id = bu.entity_id and m.player_id = p_player_id
        ))
        or (bu.building_kind = 'logistics_company' and exists (
          select 1 from public.logistics_companies lc where lc.id = bu.entity_id and lc.player_id = p_player_id
        ))
        or (bu.building_kind = 'arge_center' and exists (
          select 1 from public.arge_centers ac where ac.id = bu.entity_id and ac.player_id = p_player_id
        ))
      )
  ),
  vehicle_assets as (
    select coalesce(
      sum(
        coalesce(lvt.purchase_price, 0)::numeric
        * greatest(least(coalesce(lv.condition, 100), 100), 0)::numeric
        / 100.0
      ),
      0
    )::numeric as total_value
    from public.logistics_vehicles lv
    join public.logistics_vehicle_types lvt
      on lvt.id = lv.logistics_vehicle_type_id
    where lv.player_id = p_player_id
  ),
  warehouse_inventory_assets as (
    select coalesce(
      sum(
        greatest(coalesce(ws.quantity, 0), 0)::numeric
        * coalesce(
            p.baz_satis_fiyati * public.store_quality_price_multiplier(ws.quality_level),
            0
          )
      ),
      0
    )::numeric as total_value
    from public.warehouse_slots ws
    join public.warehouses w on w.id = ws.warehouse_id
    left join public.products p on p.id = ws.product_id
    where w.player_id = p_player_id
  ),
  store_inventory_assets as (
    select coalesce(
      sum(
        greatest(coalesce(ss.quantity, 0), 0)::numeric
        * coalesce(
            p.baz_satis_fiyati * public.store_quality_price_multiplier(ss.quality_level),
            0
          )
      ),
      0
    )::numeric as total_value
    from public.store_slots ss
    join public.stores s on s.id = ss.store_id
    left join public.products p on p.id = ss.product_id
    where s.player_id = p_player_id
  ),
  production_inventory_assets as (
    select coalesce(
      sum(
        greatest(coalesce(pi.quantity, 0), 0)::numeric
        * coalesce(
            p.baz_satis_fiyati * public.store_quality_price_multiplier(pi.quality_level),
            0
          )
      ),
      0
    )::numeric as total_value
    from public.production_inventory pi
    left join public.products p on p.id = pi.product_id
    where pi.owner_id in (
      select id from public.factories where player_id = p_player_id
      union
      select id from public.fields where player_id = p_player_id
      union
      select id from public.farms where player_id = p_player_id
      union
      select id from public.mines where player_id = p_player_id
    )
  ),
  player_assets as (
    select
      coalesce(pl.cash, 0)::numeric as cash_value,
      coalesce(pl.gold, 0)::numeric as gold_value
    from public.players pl
    where pl.id = p_player_id
  )
  select jsonb_build_object(
    'cash_value', pa.cash_value,
    'gold_value', pa.gold_value,
    'building_base_value', bba.total_value,
    'building_upgrade_value', bua.total_value,
    'vehicle_value', va.total_value,
    'warehouse_inventory_value', wia.total_value,
    'store_inventory_value', sia.total_value,
    'production_inventory_value', pia.total_value,
    'inventory_value', wia.total_value + sia.total_value + pia.total_value,
    'business_value', bba.total_value + bua.total_value + va.total_value,
    'total_company_value',
      pa.cash_value
      + bba.total_value
      + bua.total_value
      + va.total_value
      + wia.total_value
      + sia.total_value
      + pia.total_value
  )
  from building_base_assets bba
  cross join building_upgrade_assets bua
  cross join vehicle_assets va
  cross join warehouse_inventory_assets wia
  cross join store_inventory_assets sia
  cross join production_inventory_assets pia
  cross join player_assets pa;
$$;

grant execute on function public.calculate_player_company_value(uuid)
to authenticated;

grant execute on function public.calculate_player_company_value(uuid)
to service_role;

create or replace function public.get_player_profile(p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_player record;
  v_progress jsonb;
  v_featured_badges jsonb := '[]'::jsonb;
  v_unlocked_count integer := 0;
  v_total_count integer := 0;
  v_company_value jsonb := '{}'::jsonb;
begin
  select * into v_player from public.players where id = p_player_id;
  if not found then
    return null;
  end if;

  v_progress := public.build_level_progress_payload(
    coalesce(v_player.level, 1),
    coalesce(v_player.experience, 0)
  );

  perform public.ensure_player_achievement_rows(p_player_id);
  perform public.sync_player_achievement_snapshot(p_player_id);

  v_company_value := public.calculate_player_company_value(p_player_id);
  perform public.refresh_player_leaderboard_stats(p_player_id);

  select
    coalesce(
      jsonb_agg(public.build_player_achievement_payload(p_player_id, achievement_id) order by unlocked_at desc nulls last, display_order asc),
      '[]'::jsonb
    )
  into v_featured_badges
  from (
    select pa.achievement_id, pa.unlocked_at, ad.display_order
    from public.player_achievements pa
    join public.achievement_definitions ad on ad.id = pa.achievement_id
    where pa.player_id = p_player_id
      and ad.is_active = true
      and pa.is_unlocked = true
    order by pa.unlocked_at desc nulls last, ad.display_order asc
    limit 4
  ) featured_pick;

  select
    count(*) filter (where pa.is_unlocked = true),
    count(*)
  into v_unlocked_count, v_total_count
  from public.player_achievements pa
  join public.achievement_definitions ad on ad.id = pa.achievement_id
  where pa.player_id = p_player_id
    and ad.is_active = true;

  return jsonb_build_object(
    'id', v_player.id,
    'player_name', v_player.player_name,
    'company_name', v_player.company_name,
    'avatar_id', v_player.avatar_id,
    'level', coalesce(v_player.level, 1),
    'experience', v_player.experience,
    'cash', v_player.cash,
    'gold', v_player.gold,
    'company_value', coalesce((v_company_value ->> 'total_company_value')::numeric, 0),
    'company_value_breakdown', v_company_value,
    'created_at', v_player.created_at,
    'current_level_start_experience', coalesce((v_progress ->> 'current_level_start_experience')::integer, 0),
    'next_level_total_experience', coalesce((v_progress ->> 'next_level_total_experience')::integer, 0),
    'current_level_experience', coalesce((v_progress ->> 'current_level_experience')::integer, 0),
    'next_level_required_experience', coalesce((v_progress ->> 'next_level_required_experience')::integer, 1),
    'remaining_experience_to_next_level', coalesce((v_progress ->> 'remaining_experience_to_next_level')::integer, 0),
    'exp_progress_ratio', coalesce((v_progress ->> 'progress_ratio')::numeric, 0),
    'achievement_unlocked_count', coalesce(v_unlocked_count, 0),
    'achievement_total_count', coalesce(v_total_count, 0),
    'featured_badges', v_featured_badges
  );
end;
$$;

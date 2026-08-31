-- Migration: Fix farm/field owner_kind and product unit check in slot assignment/change RPCs
-- Date: 2026-08-31
-- In Hard Kapitalizm:
-- 'farm' is Tarla (Tahıl Tarlası, Sebze Tarlası vb. where uretim_birimi = 'TARLA')
-- 'field' is Çiftlik (Hayvan Çiftliği, Mandıra vb. where uretim_birimi = 'CIFTLIK')

-- 1. assign_production_slot_product
CREATE OR REPLACE FUNCTION public.assign_production_slot_product(
  p_player_id uuid,
  p_production_slot_id uuid,
  p_product_id text,
  p_quality_level integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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

  v_input_quality_level integer;
  v_inventory_id uuid;
  v_output_inventory_id uuid;
begin
  perform pg_advisory_xact_lock(hashtext('field_farm_production_lock'));

  if p_quality_level is null or p_quality_level < 1 or p_quality_level > 5 then
    raise exception 'Kalite seviyesi 1 ile 5 arasinda olmalidir.';
  end if;

  v_input_quality_level := greatest(1, least(coalesce(p_quality_level, 1), 5) - 1);

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

  -- 'farm' is Tarla
  if v_slot.owner_kind = 'farm'
     and v_product_unit not in ('tarla', 'farm') then
    raise exception 'Bu urun tarla urunu degil: %', p_product_id;
  end if;

  -- 'field' is Çiftlik
  if v_slot.owner_kind = 'field'
     and v_product_unit not in ('ciftlik', 'çiftlik', 'field') then
    raise exception 'Bu urun ciftlik urunu degil: %', p_product_id;
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
      brand_id = public.resolve_player_product_brand(v_owner_player_id, p_product_id),
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
    and quality_level = p_quality_level
    and brand_id = public.resolve_player_product_brand(v_owner_player_id, p_product_id);

  if not found then
    insert into public.production_inventory (
      owner_kind, owner_id, inventory_type, product_id, quality_level, brand_id, quantity, pending_quantity, cost
    ) values (
      v_slot.owner_kind, v_slot.owner_id, 'output', p_product_id, p_quality_level, public.resolve_player_product_brand(v_owner_player_id, p_product_id), 0, 0, 0
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
    'output_inventory_id', v_output_inventory_id,
    'slots', coalesce((
      select jsonb_agg(
        (to_jsonb(ps) - 'boost_multiplier') || jsonb_build_object(
          'boost_multiplier',
          coalesce((
            select bb.multiplier
            from public.building_boosts bb
            where bb.player_id = auth.uid()
              and bb.building_kind = v_slot.owner_kind
              and bb.entity_id = v_slot.owner_id
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
      where ps.owner_kind = v_slot.owner_kind
        and ps.owner_id = v_slot.owner_id
    ), '[]'::jsonb),
    'inventories', coalesce((
      select jsonb_agg(
        to_jsonb(pi) || jsonb_build_object(
          'product',
          case when p.id is null then null else to_jsonb(p) end
        )
        order by pi.id
      )
      from public.production_inventory pi
      left join public.products p on p.id = pi.product_id
      where pi.owner_kind = v_slot.owner_kind
        and pi.owner_id = v_slot.owner_id
    ), '[]'::jsonb),
    'changed', jsonb_build_object(
      'player', public.get_player_profile(p_player_id)
    )
  );
end;
$$;

-- 2. change_production_slot_product
CREATE OR REPLACE FUNCTION public.change_production_slot_product(
  p_player_id uuid,
  p_production_slot_id uuid,
  p_product_id text,
  p_quality_level integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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
  v_old_brand_id uuid;
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
  v_old_hammadde_1_id text;
  v_old_hammadde_2_id text;
  v_old_hammadde_3_id text;

  v_hammadde_1_miktar numeric;
  v_hammadde_2_miktar numeric;
  v_hammadde_3_miktar numeric;
  v_old_hammadde_1_miktar numeric;
  v_old_hammadde_2_miktar numeric;
  v_old_hammadde_3_miktar numeric;

  v_input_quality_level integer;
  v_old_input_quality_level integer;
  v_inventory_id uuid;
  v_output_inventory_id uuid;
begin
  perform pg_advisory_xact_lock(hashtext('field_farm_production_lock'));

  if p_quality_level is null or p_quality_level < 1 or p_quality_level > 5 then
    raise exception 'Kalite seviyesi 1 ile 5 arasinda olmalidir.';
  end if;

  v_input_quality_level := greatest(1, least(coalesce(p_quality_level, 1), 5) - 1);

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
  v_old_brand_id := v_slot.brand_id;
  v_old_input_quality_level := greatest(1, coalesce(v_old_quality_level, 1) - 1);

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

  -- 'farm' is Tarla
  if v_slot.owner_kind = 'farm'
     and v_product_unit not in ('tarla', 'farm') then
    raise exception 'Bu urun tarla urunu degil: %', p_product_id;
  end if;

  -- 'field' is Çiftlik
  if v_slot.owner_kind = 'field'
     and v_product_unit not in ('ciftlik', 'çiftlik', 'field') then
    raise exception 'Bu urun ciftlik urunu degil: %', p_product_id;
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
    and v_old_quality_level = p_quality_level;

  v_hammadde_1_id := nullif(v_product.hammadde_1_id, '');
  v_hammadde_2_id := nullif(v_product.hammadde_2_id, '');
  v_hammadde_3_id := nullif(v_product.hammadde_3_id, '');
  v_hammadde_1_miktar := coalesce(v_product.hammadde_1_miktar, 0);
  v_hammadde_2_miktar := coalesce(v_product.hammadde_2_miktar, 0);
  v_hammadde_3_miktar := coalesce(v_product.hammadde_3_miktar, 0);

  v_old_hammadde_1_id := nullif(v_old_product.hammadde_1_id, '');
  v_old_hammadde_2_id := nullif(v_old_product.hammadde_2_id, '');
  v_old_hammadde_3_id := nullif(v_old_product.hammadde_3_id, '');
  v_old_hammadde_1_miktar := coalesce(v_old_product.hammadde_1_miktar, 0);
  v_old_hammadde_2_miktar := coalesce(v_old_product.hammadde_2_miktar, 0);
  v_old_hammadde_3_miktar := coalesce(v_old_product.hammadde_3_miktar, 0);

  if not v_same_setting then
    select coalesce(sum(quantity), 0), coalesce(sum(pending_quantity), 0)
    into v_existing_output_quantity, v_existing_output_pending
    from public.production_inventory
    where owner_kind = v_slot.owner_kind
      and owner_id = v_slot.owner_id
      and inventory_type = 'output'
      and product_id = v_old_product_id
      and quality_level = v_old_quality_level
      and brand_id = v_old_brand_id;

    if v_existing_output_quantity > 0 then
      raise exception 'Bu slotun mevcut output stogu var. Urun degistirmeden once stoklari depoya aktar.';
    end if;

    select coalesce(sum(pi.quantity), 0), coalesce(sum(pi.pending_quantity), 0)
    into v_existing_input_quantity, v_existing_input_pending
    from public.production_inventory pi
    where pi.owner_kind = v_slot.owner_kind
      and pi.owner_id = v_slot.owner_id
      and pi.inventory_type = 'input'
      and (
        (v_old_hammadde_1_id is not null and v_old_hammadde_1_miktar > 0 and pi.product_id = v_old_hammadde_1_id and pi.quality_level = v_old_input_quality_level)
        or (v_old_hammadde_2_id is not null and v_old_hammadde_2_miktar > 0 and pi.product_id = v_old_hammadde_2_id and pi.quality_level = v_old_input_quality_level)
        or (v_old_hammadde_3_id is not null and v_old_hammadde_3_miktar > 0 and pi.product_id = v_old_hammadde_3_id and pi.quality_level = v_old_input_quality_level)
      )
      and not (
        (v_hammadde_1_id is not null and v_hammadde_1_miktar > 0 and pi.product_id = v_hammadde_1_id and pi.quality_level = v_input_quality_level)
        or (v_hammadde_2_id is not null and v_hammadde_2_miktar > 0 and pi.product_id = v_hammadde_2_id and pi.quality_level = v_input_quality_level)
        or (v_hammadde_3_id is not null and v_hammadde_3_miktar > 0 and pi.product_id = v_hammadde_3_id and pi.quality_level = v_input_quality_level)
      )
      and not exists (
        select 1
        from public.production_slots ps
        join public.products pr on pr.id = ps.product_id
        where ps.owner_kind = pi.owner_kind
          and ps.owner_id = pi.owner_id
          and ps.id <> v_slot.id
          and coalesce(ps.product_id, '') <> ''
          and pi.quality_level = greatest(coalesce(ps.quality_level, 1) - 1, 1)
          and (
            (nullif(pr.hammadde_1_id, '') = pi.product_id and coalesce(pr.hammadde_1_miktar, 0) > 0)
            or (nullif(pr.hammadde_2_id, '') = pi.product_id and coalesce(pr.hammadde_2_miktar, 0) > 0)
            or (nullif(pr.hammadde_3_id, '') = pi.product_id and coalesce(pr.hammadde_3_miktar, 0) > 0)
          )
      );

    if v_existing_input_quantity > 0 then
      raise exception 'Bu slotun yeni urunde kullanilmayan input stoklari var. Urun degistirmeden once stoklari depoya aktar.';
    end if;

    if coalesce(v_existing_input_pending, 0) > 0 then
      raise exception 'Bu slotun yeni urunde kullanilmayan inputlari icin yoldaki urunler var. Urun degistirmeden once transferlerin tamamlanmasini bekleyin.';
    end if;

    if coalesce(v_existing_output_pending, 0) > 0 then
      update public.production_inventory
      set pending_quantity = 0
      where owner_kind = v_slot.owner_kind
        and owner_id = v_slot.owner_id
        and inventory_type = 'output'
        and product_id = v_old_product_id
        and quality_level = v_old_quality_level
        and brand_id = v_old_brand_id;
    end if;
  end if;

  update public.production_slots
  set product_id = p_product_id,
      quality_level = p_quality_level,
      brand_id = public.resolve_player_product_brand(v_owner_player_id, p_product_id),
      updated_at = timezone('utc'::text, now()),
      last_production_at = timezone('utc'::text, now())
  where id = p_production_slot_id;

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
    and quality_level = p_quality_level
    and brand_id = public.resolve_player_product_brand(v_owner_player_id, p_product_id);

  if not found then
    insert into public.production_inventory (
      owner_kind, owner_id, inventory_type, product_id, quality_level, brand_id, quantity, pending_quantity, cost
    ) values (
      v_slot.owner_kind, v_slot.owner_id, 'output', p_product_id, p_quality_level, public.resolve_player_product_brand(v_owner_player_id, p_product_id), 0, 0, 0
    ) returning id into v_output_inventory_id;
    v_created_output_count := 1;
  end if;

  if not v_same_setting then
    update public.logistics_transfer_items lti
    set target_production_inventory_id = null
    from public.logistics_transfers lt
    where lt.id = lti.transfer_id
      and lt.status = 'completed'
      and lti.status = 'completed'
      and exists (
        select 1
        from public.production_inventory pi
        where pi.id = lti.target_production_inventory_id
          and pi.owner_kind = v_slot.owner_kind
          and pi.owner_id = v_slot.owner_id
          and coalesce(pi.quantity, 0) = 0
          and coalesce(pi.pending_quantity, 0) = 0
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
                and ps.brand_id = pi.brand_id
            )
          )
          and not (
            pi.inventory_type = 'input'
            and exists (
              select 1
              from public.production_slots ps
              join public.products pr on pr.id = ps.product_id
              where ps.owner_kind = pi.owner_kind
                and ps.owner_id = pi.owner_id
                and coalesce(ps.product_id, '') <> ''
                and pi.quality_level = greatest(coalesce(ps.quality_level, 1) - 1, 1)
                and (
                  (nullif(pr.hammadde_1_id, '') = pi.product_id and coalesce(pr.hammadde_1_miktar, 0) > 0)
                  or (nullif(pr.hammadde_2_id, '') = pi.product_id and coalesce(pr.hammadde_2_miktar, 0) > 0)
                  or (nullif(pr.hammadde_3_id, '') = pi.product_id and coalesce(pr.hammadde_3_miktar, 0) > 0)
                )
            )
          )
      );

    update public.logistics_transfers lt
    set seller_production_inventory_id = null
    where lt.status = 'completed'
      and exists (
        select 1
        from public.production_inventory pi
        where pi.id = lt.seller_production_inventory_id
          and pi.owner_kind = v_slot.owner_kind
          and pi.owner_id = v_slot.owner_id
          and coalesce(pi.quantity, 0) = 0
          and coalesce(pi.pending_quantity, 0) = 0
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
                and ps.brand_id = pi.brand_id
            )
          )
          and not (
            pi.inventory_type = 'input'
            and exists (
              select 1
              from public.production_slots ps
              join public.products pr on pr.id = ps.product_id
              where ps.owner_kind = pi.owner_kind
                and ps.owner_id = pi.owner_id
                and coalesce(ps.product_id, '') <> ''
                and pi.quality_level = greatest(coalesce(ps.quality_level, 1) - 1, 1)
                and (
                  (nullif(pr.hammadde_1_id, '') = pi.product_id and coalesce(pr.hammadde_1_miktar, 0) > 0)
                  or (nullif(pr.hammadde_2_id, '') = pi.product_id and coalesce(pr.hammadde_2_miktar, 0) > 0)
                  or (nullif(pr.hammadde_3_id, '') = pi.product_id and coalesce(pr.hammadde_3_miktar, 0) > 0)
                )
            )
          )
      );

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
            and ps.brand_id = pi.brand_id
        )
      )
      and not (
        pi.inventory_type = 'input'
        and exists (
          select 1
          from public.production_slots ps
          join public.products pr on pr.id = ps.product_id
          where ps.owner_kind = pi.owner_kind
            and ps.owner_id = pi.owner_id
            and coalesce(ps.product_id, '') <> ''
            and pi.quality_level = greatest(coalesce(ps.quality_level, 1) - 1, 1)
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
    'output_inventory_id', v_output_inventory_id,
    'slots', coalesce((
      select jsonb_agg(
        (to_jsonb(ps) - 'boost_multiplier') || jsonb_build_object(
          'boost_multiplier',
          coalesce((
            select bb.multiplier
            from public.building_boosts bb
            where bb.player_id = auth.uid()
              and bb.building_kind = v_slot.owner_kind
              and bb.entity_id = v_slot.owner_id
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
      where ps.owner_kind = v_slot.owner_kind
        and ps.owner_id = v_slot.owner_id
    ), '[]'::jsonb),
    'inventories', coalesce((
      select jsonb_agg(
        to_jsonb(pi) || jsonb_build_object(
          'product',
          case when p.id is null then null else to_jsonb(p) end
        )
        order by pi.id
      )
      from public.production_inventory pi
      left join public.products p on p.id = pi.product_id
      where pi.owner_kind = v_slot.owner_kind
        and pi.owner_id = v_slot.owner_id
    ), '[]'::jsonb),
    'changed', jsonb_build_object(
      'player', public.get_player_profile(p_player_id)
    )
  );
end;
$$;

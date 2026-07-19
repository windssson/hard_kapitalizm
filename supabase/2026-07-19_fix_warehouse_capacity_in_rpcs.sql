-- Redefining SQL functions to return real-time warehouse occupied capacities (active inventory volume + reserved volume) in the 'reserved_capacity' field.

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
          'reserved_capacity', w.reserved_capacity + coalesce(
            (
              select sum(coalesce(ws.quantity, 0) * coalesce(p.birim_hacim, 0))
              from public.warehouse_slots ws
              join public.products p on p.id = ws.product_id
              where ws.warehouse_id = w.id
            ),
            0
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
          ),
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
$function$;

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
          'reserved_capacity', w.reserved_capacity + coalesce(
            (
              select sum(coalesce(ws.quantity, 0) * coalesce(p.birim_hacim, 0))
              from public.warehouse_slots ws
              join public.products p on p.id = ws.product_id
              where ws.warehouse_id = w.id
            ),
            0
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
$function$;

-- ============================================================================
-- Migration: Add discard_warehouse_slot RPC
-- Allows players to throw away / discard items from a warehouse slot
-- ============================================================================

CREATE OR REPLACE FUNCTION public.discard_warehouse_slot(
  p_player_id uuid,
  p_warehouse_slot_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
declare
  v_slot record;
begin
  if p_player_id is null or p_player_id <> auth.uid() then
    raise exception 'Gecersiz oyuncu.';
  end if;

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
    raise exception 'Depo slotu bulunamadi.';
  end if;

  if v_slot.player_id <> p_player_id then
    raise exception 'Bu depo slotu oyuncuya ait degil.';
  end if;

  if coalesce(v_slot.pending_quantity, 0) > 0 then
    raise exception 'Transfer asamasindaki urunler cope atilamaz.';
  end if;

  delete from public.warehouse_slots
  where id = p_warehouse_slot_id;

  return jsonb_build_object(
    'success', true,
    'warehouse_id', v_slot.warehouse_id,
    'warehouse_slot_id', p_warehouse_slot_id,
    'discarded_quantity', coalesce(v_slot.quantity, 0),
    'product_id', v_slot.product_id,
    'message', 'Urun basariyla cope atildi.'
  );
end;
$$;

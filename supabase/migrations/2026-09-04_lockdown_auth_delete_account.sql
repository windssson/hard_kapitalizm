-- ============================================================================
-- MIGRATION: 2026-09-04_lockdown_auth_delete_account.sql
-- Amaç: Hesap silme (delete_own_account) fonksiyonunun tam ve eksiksiz tasfiyesini
--       sağlamak:
--   1) Aktif pazarlama kampanyalarını (brand_marketing_campaigns) temizleme
--   2) Vergi kayıtlarını (player_taxes) temizleme
--   3) Sohbet mesajları ve raporlarını (chat_messages, chat_message_reports) temizleme
--   4) KVKK/GDPR tam uyumlu hesap tasfiyesi
-- ============================================================================

CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
DECLARE
  v_user_id uuid;
  v_npc_id uuid;
  v_now timestamptz := timezone('utc', now());
  v_in_transfer record;
BEGIN
  -- 1. Oturumu açık kullanıcı ID'sini al
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Oturum açılmamış.');
  END IF;

  -- 2. NPC Lojistik oyuncusunu bul
  v_npc_id := public.get_npc_logistics_player_id();

  -- 3. Kişisel bildirim ve push tokenlarını sil
  DELETE FROM public.player_push_tokens WHERE player_id = v_user_id;
  DELETE FROM public.player_alert_push_logs WHERE player_id = v_user_id;
  DELETE FROM public.player_notifications WHERE player_id = v_user_id;

  -- 4. Özel mesajları ve genel sohbet kayıtlarını temizle (Gizlilik / KVKK)
  DELETE FROM public.direct_messages WHERE sender_id = v_user_id OR receiver_id = v_user_id;
  DELETE FROM public.chat_messages WHERE player_id = v_user_id;
  DELETE FROM public.chat_message_reports WHERE reporter_player_id = v_user_id OR reported_player_id = v_user_id;

  -- 5. Yoldaki transferleri yönet
  -- A) Oyuncunun SATICI olduğu transferleri NPC'ye devret (alıcının mağdur olmaması için)
  UPDATE public.logistics_transfers
  SET seller_player_id = v_npc_id
  WHERE seller_player_id = v_user_id AND status = 'in_transit';

  -- B) Oyuncunun ALICI olduğu yoldaki transferleri iptal et ve araçlarını boşa çıkar
  FOR v_in_transfer IN
    SELECT id, logistics_vehicle_id
    FROM public.logistics_transfers
    WHERE buyer_player_id = v_user_id AND status = 'in_transit'
  LOOP
    IF v_in_transfer.logistics_vehicle_id IS NOT NULL THEN
      UPDATE public.logistics_vehicles
      SET status = 'idle', updated_at = v_now
      WHERE id = v_in_transfer.logistics_vehicle_id;
    END IF;
  END LOOP;

  UPDATE public.logistics_transfers
  SET status = 'cancelled', completed_at = v_now, updated_at = v_now
  WHERE buyer_player_id = v_user_id AND status = 'in_transit';

  -- C) Oyuncunun araçlarının kiralandığı aktif transferleri NPC'ye devret
  UPDATE public.logistics_transfers
  SET vehicle_owner_player_id = v_npc_id
  WHERE vehicle_owner_player_id = v_user_id AND status = 'in_transit';

  -- 6. Oyuncunun araçlarını yönet
  -- Başkası tarafından kiralanmış ve şu an yolda olan araçları geçici olarak NPC'ye aktar (sefer tamamlansın diye)
  UPDATE public.logistics_vehicles
  SET player_id = v_npc_id
  WHERE player_id = v_user_id AND status = 'on_route';

  -- Kendi bünyesindeki diğer araçları hizmet dışı bırak
  UPDATE public.logistics_vehicles
  SET status = 'decommissioned', is_available_for_rent = false, updated_at = v_now
  WHERE player_id = v_user_id AND status <> 'on_route';

  -- 7. Pazar ilanlarını kapat ve depo stoklarını sıfırla
  UPDATE public.warehouse_slots
  SET is_available_for_sale = false, price = 0, quantity = 0, pending_quantity = 0, updated_at = v_now
  WHERE warehouse_id IN (SELECT id FROM public.warehouses WHERE player_id = v_user_id);

  -- Üretim envanterlerini sıfırla
  UPDATE public.production_inventory
  SET quantity = 0, pending_quantity = 0, updated_at = v_now
  WHERE owner_id IN (
    SELECT id FROM public.factories WHERE player_id = v_user_id
    UNION ALL
    SELECT id FROM public.farms WHERE player_id = v_user_id
    UNION ALL
    SELECT id FROM public.fields WHERE player_id = v_user_id
    UNION ALL
    SELECT id FROM public.mines WHERE player_id = v_user_id
  );

  -- Mağaza raflarını sıfırla
  UPDATE public.store_slots
  SET quantity = 0, pending_quantity = 0, pending_sale = 0, is_active = false, updated_at = v_now
  WHERE store_id IN (SELECT id FROM public.stores WHERE player_id = v_user_id);

  -- 8. Tesisleri devre dışı bırak
  UPDATE public.factories SET is_active = false, updated_at = v_now WHERE player_id = v_user_id;
  UPDATE public.fields SET is_active = false, updated_at = v_now WHERE player_id = v_user_id;
  UPDATE public.farms SET is_active = false, updated_at = v_now WHERE player_id = v_user_id;
  UPDATE public.mines SET is_active = false, updated_at = v_now WHERE player_id = v_user_id;
  UPDATE public.warehouses SET is_active = false, updated_at = v_now WHERE player_id = v_user_id;
  UPDATE public.stores SET is_active = false, updated_at = v_now WHERE player_id = v_user_id;
  UPDATE public.logistics_companies SET is_active = false, updated_at = v_now WHERE player_id = v_user_id;
  UPDATE public.arge_centers SET is_active = false, updated_at = v_now WHERE player_id = v_user_id;
  UPDATE public.brand_companies SET is_active = false, updated_at = v_now WHERE player_id = v_user_id;

  -- Pazarlama kampanyalarını ve vergileri sil
  DELETE FROM public.brand_marketing_campaigns WHERE player_id = v_user_id;
  DELETE FROM public.player_taxes WHERE player_id = v_user_id;

  -- 9. Devam eden inşaat, geliştirme, takviye ve ihaleleri temizle
  DELETE FROM public.building_boosts WHERE player_id = v_user_id;
  DELETE FROM public.building_upgrades WHERE player_id = v_user_id;
  DELETE FROM public.building_constructions WHERE player_id = v_user_id;
  DELETE FROM public.tender_bids WHERE player_id = v_user_id;
  DELETE FROM public.tender_deliveries WHERE player_id = v_user_id;
  DELETE FROM public.player_tenders WHERE player_id = v_user_id;

  -- Banka ürünlerini tasfiye et
  UPDATE public.player_loans SET status = 'liquidated', updated_at = v_now WHERE player_id = v_user_id;
  UPDATE public.player_deposits SET status = 'liquidated', updated_at = v_now WHERE player_id = v_user_id;

  -- 10. Liderlik tablosu, geçmiş şirket değeri ve görev/başarım kayıtlarını temizle
  DELETE FROM public.player_leaderboard_stats WHERE player_id = v_user_id;
  DELETE FROM public.player_company_value_history WHERE player_id = v_user_id;
  DELETE FROM public.player_missions WHERE player_id = v_user_id;
  DELETE FROM public.player_achievements WHERE player_id = v_user_id;
  DELETE FROM public.player_rewarded_ad_usages WHERE player_id = v_user_id;

  -- 11. Oyuncu profilini tamamen anonimleştir
  UPDATE public.players
  SET
    player_name = 'Eski Oyuncu',
    company_name = 'Tasfiye Edilmiş Holding',
    google_email = NULL,
    google_avatar_url = NULL,
    avatar_id = 'ae1.webp',
    cash = 0,
    gold = 0,
    starter_pack_claimed = false,
    last_seen_at = NULL
  WHERE id = v_user_id;

  -- 12. auth.users tablosundaki kimlik kaydını kalıcı olarak sil
  DELETE FROM auth.users WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Hesabınız ve tüm kişisel verileriniz başarıyla silindi. Şirketiniz tasfiye edildi.'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'message', format('Hesap silinirken hata oluştu: %s', SQLERRM)
  );
END;
$function$;

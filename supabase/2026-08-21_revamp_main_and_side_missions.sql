-- 2026-08-21: Comprehensive Revamp of Main Missions & Scaled Tycoon Targets
-- 1. Main Missions: Restructured to perfectly match level unlock progression (Lv.1 to Lv.15+).
-- 2. Scaled Targets: Substantially increased sales and production counts to match tycoon volume.
-- 3. Generous Progression: Generous rewards in Cash, XP, and Gold.

-- Deactivate old deprecated mission keys if any
UPDATE public.mission_definitions
SET is_active = false
WHERE id IN (
  'main_first_store',
  'main_first_warehouse',
  'main_first_sale',
  'main_first_transfer',
  'main_first_research',
  'main_005_first_factory',
  'main_008_first_research',
  'main_009_sales_100',
  'main_010_transfer_network',
  'side_first_factory',
  'side_first_upgrade',
  'daily_store_sales_10',
  'daily_transfer_complete_1',
  'daily_building_complete_1',
  'weekly_produce_100',
  'weekly_produce_500',
  'weekly_sell_50',
  'weekly_transfer_10'
);

-- =========================================================================
-- 15 ANA GÖREV (MAIN MISSIONS)
-- =========================================================================

-- 1. İlk Dükkanını Aç (Lv.1 - Büfe/Manav)
INSERT INTO public.mission_definitions (id, mission_type, title, description, event_key, target_count, reward_xp, reward_cash, reward_gold, display_order, required_mission_id, is_active)
VALUES (
  'main_001_first_store', 'main', 'İlk Dükkanını Aç',
  'İlk mağazanı kurarak perakende ticaretine adım at.',
  'building_construction_completed_store', 1, 75, 50000.00, 0, 10, NULL, true
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title, description = EXCLUDED.description, event_key = EXCLUDED.event_key,
  target_count = EXCLUDED.target_count, reward_xp = EXCLUDED.reward_xp, reward_cash = EXCLUDED.reward_cash,
  reward_gold = EXCLUDED.reward_gold, display_order = EXCLUDED.display_order, required_mission_id = EXCLUDED.required_mission_id, is_active = true;

-- 2. Kasaya İlk Parayı Koy (Lv.1 - 1 Satış)
INSERT INTO public.mission_definitions (id, mission_type, title, description, event_key, target_count, reward_xp, reward_cash, reward_gold, display_order, required_mission_id, is_active)
VALUES (
  'main_002_first_sale', 'main', 'Kasaya İlk Parayı Koy',
  'Mağazanda ilk ürün satışını gerçekleştir.',
  'store_sale_completed', 1, 100, 75000.00, 0, 20, 'main_001_first_store', true
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title, description = EXCLUDED.description, event_key = EXCLUDED.event_key,
  target_count = EXCLUDED.target_count, reward_xp = EXCLUDED.reward_xp, reward_cash = EXCLUDED.reward_cash,
  reward_gold = EXCLUDED.reward_gold, display_order = EXCLUDED.display_order, required_mission_id = EXCLUDED.required_mission_id, is_active = true;

-- 3. Stok Kontrolünü Ele Al (Lv.1 - Genel Depo)
INSERT INTO public.mission_definitions (id, mission_type, title, description, event_key, target_count, reward_xp, reward_cash, reward_gold, display_order, required_mission_id, is_active)
VALUES (
  'main_003_first_warehouse', 'main', 'Stok Kontrolünü Ele Al',
  'İlk deponu kurarak lojistik altyapını hazırla.',
  'building_construction_completed_warehouse', 1, 120, 90000.00, 0, 30, 'main_002_first_sale', true
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title, description = EXCLUDED.description, event_key = EXCLUDED.event_key,
  target_count = EXCLUDED.target_count, reward_xp = EXCLUDED.reward_xp, reward_cash = EXCLUDED.reward_cash,
  reward_gold = EXCLUDED.reward_gold, display_order = EXCLUDED.display_order, required_mission_id = EXCLUDED.required_mission_id, is_active = true;

-- 4. Tedarik Zincirini Başlat (Lv.2 - 1 Transfer)
INSERT INTO public.mission_definitions (id, mission_type, title, description, event_key, target_count, reward_xp, reward_cash, reward_gold, display_order, required_mission_id, is_active)
VALUES (
  'main_004_first_transfer', 'main', 'Tedarik Zincirini Başlat',
  'Depodan mağazaya ilk lojistik transferini tamamla.',
  'logistics_transfer_completed', 1, 140, 100000.00, 0, 40, 'main_003_first_warehouse', true
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title, description = EXCLUDED.description, event_key = EXCLUDED.event_key,
  target_count = EXCLUDED.target_count, reward_xp = EXCLUDED.reward_xp, reward_cash = EXCLUDED.reward_cash,
  reward_gold = EXCLUDED.reward_gold, display_order = EXCLUDED.display_order, required_mission_id = EXCLUDED.required_mission_id, is_active = true;

-- 5. Bilim ve İnovasyon (Lv.2-3 - İlk AR-GE)
INSERT INTO public.mission_definitions (id, mission_type, title, description, event_key, target_count, reward_xp, reward_cash, reward_gold, display_order, required_mission_id, is_active)
VALUES (
  'main_005_first_research', 'main', 'Bilim ve İnovasyon',
  'AR-GE Merkezinde ilk ürün araştırmanı tamamlayarak kaliteni artır.',
  'arge_research_completed', 1, 180, 120000.00, 0, 50, 'main_004_first_transfer', true
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title, description = EXCLUDED.description, event_key = EXCLUDED.event_key,
  target_count = EXCLUDED.target_count, reward_xp = EXCLUDED.reward_xp, reward_cash = EXCLUDED.reward_cash,
  reward_gold = EXCLUDED.reward_gold, display_order = EXCLUDED.display_order, required_mission_id = EXCLUDED.required_mission_id, is_active = true;

-- 6. İlk Tarlanı Kur (Lv.3 - Sebze Tarlası)
INSERT INTO public.mission_definitions (id, mission_type, title, description, event_key, target_count, reward_xp, reward_cash, reward_gold, display_order, required_mission_id, is_active)
VALUES (
  'main_006_first_field', 'main', 'İlk Tarlanı Kur',
  'Sebze veya Tahıl Tarlası kurarak tarımsal hammadde üretimine başla.',
  'building_construction_completed_field', 1, 200, 150000.00, 0, 60, 'main_005_first_research', true
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title, description = EXCLUDED.description, event_key = EXCLUDED.event_key,
  target_count = EXCLUDED.target_count, reward_xp = EXCLUDED.reward_xp, reward_cash = EXCLUDED.reward_cash,
  reward_gold = EXCLUDED.reward_gold, display_order = EXCLUDED.display_order, required_mission_id = EXCLUDED.required_mission_id, is_active = true;

-- 7. Topraktan Gelen Bereket (Lv.3 - 100 Üretim)
INSERT INTO public.mission_definitions (id, mission_type, title, description, event_key, target_count, reward_xp, reward_cash, reward_gold, display_order, required_mission_id, is_active)
VALUES (
  'main_007_first_production', 'main', 'Topraktan Gelen Bereket',
  'Tarlalarında toplam 100 adet tarımsal hammadde üret.',
  'product_produced', 100, 250, 180000.00, 0, 70, 'main_006_first_field', true
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title, description = EXCLUDED.description, event_key = EXCLUDED.event_key,
  target_count = EXCLUDED.target_count, reward_xp = EXCLUDED.reward_xp, reward_cash = EXCLUDED.reward_cash,
  reward_gold = EXCLUDED.reward_gold, display_order = EXCLUDED.display_order, required_mission_id = EXCLUDED.required_mission_id, is_active = true;

-- 8. Tesislerini Modernize Et (Lv.4 - 1 Yükseltme)
INSERT INTO public.mission_definitions (id, mission_type, title, description, event_key, target_count, reward_xp, reward_cash, reward_gold, display_order, required_mission_id, is_active)
VALUES (
  'main_008_first_upgrade', 'main', 'Tesislerini Modernize Et',
  'Verim ve kapasiteyi artırmak için herhangi bir binanı 1 seviye yükselt.',
  'building_upgrade_completed', 1, 300, 200000.00, 0, 80, 'main_007_first_production', true
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title, description = EXCLUDED.description, event_key = EXCLUDED.event_key,
  target_count = EXCLUDED.target_count, reward_xp = EXCLUDED.reward_xp, reward_cash = EXCLUDED.reward_cash,
  reward_gold = EXCLUDED.reward_gold, display_order = EXCLUDED.display_order, required_mission_id = EXCLUDED.required_mission_id, is_active = true;

-- 9. Hayvancılık Atılımı (Lv.5 - Kümes Hayvancılığı / Çiftlik)
INSERT INTO public.mission_definitions (id, mission_type, title, description, event_key, target_count, reward_xp, reward_cash, reward_gold, display_order, required_mission_id, is_active)
VALUES (
  'main_009_first_farm', 'main', 'Hayvancılık Atılımı',
  'Kümes Hayvancılığı veya Çiftlik kurarak et ve süt sektörüne gir.',
  'building_construction_completed_farm', 1, 400, 250000.00, 1, 90, 'main_008_first_upgrade', true
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title, description = EXCLUDED.description, event_key = EXCLUDED.event_key,
  target_count = EXCLUDED.target_count, reward_xp = EXCLUDED.reward_xp, reward_cash = EXCLUDED.reward_cash,
  reward_gold = EXCLUDED.reward_gold, display_order = EXCLUDED.display_order, required_mission_id = EXCLUDED.required_mission_id, is_active = true;

-- 10. Hayvansal Üretim (Lv.5-6 - 500 Üretim)
INSERT INTO public.mission_definitions (id, mission_type, title, description, event_key, target_count, reward_xp, reward_cash, reward_gold, display_order, required_mission_id, is_active)
VALUES (
  'main_010_farm_production', 'main', 'Hayvansal Üretim',
  'Tesislerinde toplam 500 adet hayvansal ürün üret.',
  'product_produced', 500, 500, 350000.00, 0, 100, 'main_009_first_farm', true
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title, description = EXCLUDED.description, event_key = EXCLUDED.event_key,
  target_count = EXCLUDED.target_count, reward_xp = EXCLUDED.reward_xp, reward_cash = EXCLUDED.reward_cash,
  reward_gold = EXCLUDED.reward_gold, display_order = EXCLUDED.display_order, required_mission_id = EXCLUDED.required_mission_id, is_active = true;

-- 11. Perakende Ağı Genişliyor (Lv.6-8 - 1.000 Satış)
INSERT INTO public.mission_definitions (id, mission_type, title, description, event_key, target_count, reward_xp, reward_cash, reward_gold, display_order, required_mission_id, is_active)
VALUES (
  'main_011_retail_growth', 'main', 'Perakende Ağı Genişliyor',
  'Mağazalarında toplam 1.000 adet ürün satışı gerçekleştir.',
  'store_sale_completed', 1000, 650, 450000.00, 1, 110, 'main_010_farm_production', true
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title, description = EXCLUDED.description, event_key = EXCLUDED.event_key,
  target_count = EXCLUDED.target_count, reward_xp = EXCLUDED.reward_xp, reward_cash = EXCLUDED.reward_cash,
  reward_gold = EXCLUDED.reward_gold, display_order = EXCLUDED.display_order, required_mission_id = EXCLUDED.required_mission_id, is_active = true;

-- 12. Lojistik Filosu (Lv.8-9 - 15 Transfer)
INSERT INTO public.mission_definitions (id, mission_type, title, description, event_key, target_count, reward_xp, reward_cash, reward_gold, display_order, required_mission_id, is_active)
VALUES (
  'main_012_transfer_network', 'main', 'Lojistik Filosu',
  'Şirketine ait 15 lojistik transferini başarıyla tamamla.',
  'logistics_transfer_completed', 15, 800, 600000.00, 1, 120, 'main_011_retail_growth', true
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title, description = EXCLUDED.description, event_key = EXCLUDED.event_key,
  target_count = EXCLUDED.target_count, reward_xp = EXCLUDED.reward_xp, reward_cash = EXCLUDED.reward_cash,
  reward_gold = EXCLUDED.reward_gold, display_order = EXCLUDED.display_order, required_mission_id = EXCLUDED.required_mission_id, is_active = true;

-- 13. Sanayinin Devi (Lv.10 - İlk Fabrika)
INSERT INTO public.mission_definitions (id, mission_type, title, description, event_key, target_count, reward_xp, reward_cash, reward_gold, display_order, required_mission_id, is_active)
VALUES (
  'main_013_first_factory', 'main', 'Sanayinin Devi',
  'İlk fabrikanı inşa ederek katma değerli sanayi üretimine geç.',
  'building_construction_completed_factory', 1, 1200, 1000000.00, 2, 130, 'main_012_transfer_network', true
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title, description = EXCLUDED.description, event_key = EXCLUDED.event_key,
  target_count = EXCLUDED.target_count, reward_xp = EXCLUDED.reward_xp, reward_cash = EXCLUDED.reward_cash,
  reward_gold = EXCLUDED.reward_gold, display_order = EXCLUDED.display_order, required_mission_id = EXCLUDED.required_mission_id, is_active = true;

-- 14. Yeraltı İmparatorluğu (Lv.15 - İlk Maden)
INSERT INTO public.mission_definitions (id, mission_type, title, description, event_key, target_count, reward_xp, reward_cash, reward_gold, display_order, required_mission_id, is_active)
VALUES (
  'main_014_first_mine', 'main', 'Yeraltı İmparatorluğu',
  'İlk maden ocağını açarak stratejik hammadde ve cevher çıkar.',
  'building_construction_completed_mine', 1, 2000, 1500000.00, 3, 140, 'main_013_first_factory', true
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title, description = EXCLUDED.description, event_key = EXCLUDED.event_key,
  target_count = EXCLUDED.target_count, reward_xp = EXCLUDED.reward_xp, reward_cash = EXCLUDED.reward_cash,
  reward_gold = EXCLUDED.reward_gold, display_order = EXCLUDED.display_order, required_mission_id = EXCLUDED.required_mission_id, is_active = true;

-- 15. Sermaye Hükümdarı (Lv.15+ - 10.000 Satış)
INSERT INTO public.mission_definitions (id, mission_type, title, description, event_key, target_count, reward_xp, reward_cash, reward_gold, display_order, required_mission_id, is_active)
VALUES (
  'main_015_empire_growth', 'main', 'Sermaye Hükümdarı',
  'Mağazalarında toplam 10.000 adet ürün satışı gerçekleştirerek piyasaya hükmet.',
  'store_sale_completed', 10000, 3500, 2500000.00, 5, 150, 'main_014_first_mine', true
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title, description = EXCLUDED.description, event_key = EXCLUDED.event_key,
  target_count = EXCLUDED.target_count, reward_xp = EXCLUDED.reward_xp, reward_cash = EXCLUDED.reward_cash,
  reward_gold = EXCLUDED.reward_gold, display_order = EXCLUDED.display_order, required_mission_id = EXCLUDED.required_mission_id, is_active = true;

-- =========================================================================
-- YAN GÖREVLER (SIDE MISSIONS) - ÖLÇEKLENDİRİLMİŞ HEDEFLER
-- =========================================================================

UPDATE public.mission_definitions
SET
  title = 'Büyük Üretici',
  description = 'Tesislerinde toplam 1.000 adet ürün üret.',
  target_count = 1000,
  reward_xp = 350,
  reward_cash = 250000.00,
  reward_gold = 1,
  updated_at = timezone('utc', now())
WHERE id = 'side_007_produce_500';

UPDATE public.mission_definitions
SET
  title = 'Ticaret Akışı',
  description = 'Mağazalarında toplam 2.500 adet ürün satışı tamamla.',
  target_count = 2500,
  reward_xp = 500,
  reward_cash = 400000.00,
  reward_gold = 2,
  updated_at = timezone('utc', now())
WHERE id = 'side_008_revenue_flow';

-- =========================================================================
-- GÜNLÜK & HAFTALIK GÖREVLER (DAILY & WEEKLY) - GERÇEKÇİ SAYILAR
-- =========================================================================

-- Günlük Satış: 50 adet
UPDATE public.mission_definitions
SET
  title = 'Günlük Satış',
  description = 'Günün 50 adet mağaza satışını tamamla.',
  target_count = 50,
  reward_xp = 30,
  reward_cash = 8000.00,
  updated_at = timezone('utc', now())
WHERE id = 'daily_001_sales_25';

-- Günlük Üretim: 100 adet
UPDATE public.mission_definitions
SET
  title = 'Günlük Üretim',
  description = 'Günün 100 adet üretimini gerçekleştir.',
  target_count = 100,
  reward_xp = 35,
  reward_cash = 10000.00,
  updated_at = timezone('utc', now())
WHERE id = 'daily_003_produce_50';

-- Haftalık Satış: 1.000 adet
UPDATE public.mission_definitions
SET
  title = 'Haftalık Satış Performansı',
  description = 'Bu hafta mağazalarında toplam 1.000 adet ürün sat.',
  target_count = 1000,
  reward_xp = 250,
  reward_cash = 60000.00,
  reward_gold = 1,
  updated_at = timezone('utc', now())
WHERE id = 'weekly_001_sales_250';

-- Haftalık Üretim: 1.500 adet
UPDATE public.mission_definitions
SET
  title = 'Haftalık Büyük Üretim',
  description = 'Bu hafta tesislerinde toplam 1.500 adet ürün üret.',
  target_count = 1500,
  reward_xp = 300,
  reward_cash = 75000.00,
  reward_gold = 1,
  updated_at = timezone('utc', now())
WHERE id = 'weekly_003_produce_500';

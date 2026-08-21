-- 2026-08-21: Rebalance Missions & Achievements Economy and Fix Inconsistencies
-- 1. Fix daily_004_build_1 mission: Change daily requirement from building a brand new building (-20k loss) to upgrading a building.
-- 2. Fix achievement_definitions: Correct Tarla/Çiftlik title swap, align merchant_100/1000 targets & titles, rebalance rewards (XP, Cash, Gold).

-- 1. MISSION DEFINITIONS FIXES
UPDATE public.mission_definitions
SET
  title = 'Günlük Gelişim',
  description = 'Herhangi bir binanı 1 seviye yükselterek tesislerini modernize et.',
  event_key = 'building_upgrade_completed',
  target_count = 1,
  reward_xp = 35,
  reward_cash = 10000.00,
  reward_gold = 0,
  updated_at = timezone('utc', now())
WHERE id = 'daily_004_build_1';

-- 2. ACHIEVEMENT DEFINITIONS REBALANCING & CORRECTIONS
-- First Store
UPDATE public.achievement_definitions
SET
  title = 'İlk Dükkan',
  description = 'İlk mağazanı kurarak perakende sektörüne adım at.',
  reward_xp = 100,
  reward_cash = 25000.00,
  reward_gold = 1,
  updated_at = timezone('utc', now())
WHERE id = 'first_store';

-- First Warehouse
UPDATE public.achievement_definitions
SET
  title = 'Lojistik Üssü',
  description = 'İlk deponu kurarak ürün stoklamaya ve sevkiyata başla.',
  reward_xp = 120,
  reward_cash = 30000.00,
  reward_gold = 1,
  updated_at = timezone('utc', now())
WHERE id = 'first_warehouse';

-- First Field (Tarla)
UPDATE public.achievement_definitions
SET
  title = 'İlk Tarla',
  description = 'İlk tarlanı kurarak tarımsal hammadde üretimine başla.',
  reward_xp = 150,
  reward_cash = 35000.00,
  reward_gold = 1,
  updated_at = timezone('utc', now())
WHERE id = 'first_field';

-- First Farm (Çiftlik)
UPDATE public.achievement_definitions
SET
  title = 'İlk Çiftlik',
  description = 'İlk çiftliğini kurarak hayvansal üretime adım at.',
  reward_xp = 150,
  reward_cash = 35000.00,
  reward_gold = 1,
  updated_at = timezone('utc', now())
WHERE id = 'first_farm';

-- First Factory
UPDATE public.achievement_definitions
SET
  title = 'Sanayi Devrimi',
  description = 'İlk fabrikanı kurarak katma değerli mamul üretimine geç.',
  reward_xp = 250,
  reward_cash = 100000.00,
  reward_gold = 2,
  updated_at = timezone('utc', now())
WHERE id = 'first_factory';

-- First Mine
UPDATE public.achievement_definitions
SET
  title = 'Yeraltı Zenginliği',
  description = 'İlk maden ocağını açarak stratejik hammadde çıkarımına başla.',
  reward_xp = 350,
  reward_cash = 150000.00,
  reward_gold = 3,
  updated_at = timezone('utc', now())
WHERE id = 'first_mine';

-- Logistics 5
UPDATE public.achievement_definitions
SET
  title = 'Sevkiyat Ağı',
  description = '5 lojistik transferini başarıyla hedefine ulaştır.',
  reward_xp = 200,
  reward_cash = 50000.00,
  reward_gold = 1,
  updated_at = timezone('utc', now())
WHERE id = 'logistics_5';

-- Research 1
UPDATE public.achievement_definitions
SET
  title = 'Bilim ve İnovasyon',
  description = 'İlk AR-GE araştırmanı tamamlayarak kalite seviyeni yükselt.',
  reward_xp = 250,
  reward_cash = 75000.00,
  reward_gold = 2,
  updated_at = timezone('utc', now())
WHERE id = 'research_1';

-- Upgrader 5
UPDATE public.achievement_definitions
SET
  title = 'Modernizasyon Ustası',
  description = 'Toplam 5 bina yükseltmesi tamamlayarak kapasiteni artır.',
  reward_xp = 300,
  reward_cash = 100000.00,
  reward_gold = 2,
  updated_at = timezone('utc', now())
WHERE id = 'upgrader_5';

-- Builder 10
UPDATE public.achievement_definitions
SET
  title = 'Şirketler Topluluğu',
  description = 'Şirketine ait 10 aktif tesis inşa et.',
  reward_xp = 500,
  reward_cash = 250000.00,
  reward_gold = 5,
  updated_at = timezone('utc', now())
WHERE id = 'builder_10';

-- Merchant 100 (100 Sales)
UPDATE public.achievement_definitions
SET
  title = 'Tüccar',
  description = 'Mağazalarında toplam 100 adet ürün satışı gerçekleştir.',
  target_count = 100,
  reward_xp = 250,
  reward_cash = 75000.00,
  reward_gold = 2,
  updated_at = timezone('utc', now())
WHERE id = 'merchant_100';

-- Merchant 1000 (1000 Sales)
UPDATE public.achievement_definitions
SET
  title = 'Perakende Devi',
  description = 'Mağazalarında toplam 1.000 adet ürün satışı gerçekleştir.',
  target_count = 1000,
  reward_xp = 800,
  reward_cash = 500000.00,
  reward_gold = 5,
  updated_at = timezone('utc', now())
WHERE id = 'merchant_1000';

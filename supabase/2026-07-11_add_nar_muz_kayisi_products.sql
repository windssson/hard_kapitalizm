-- Nar, Muz ve Kayısı ürünlerini products tablosuna ekle
-- Meyve Bahçesi çiftlik tipine uygun şekilde, benzer meyveler (Şeftali, Kivi, Portakal) temel alınarak fiyatlandırıldı.

INSERT INTO products (id, urun_adi, urun_iconu, birim_hacim, birim_agirlik, hammadde_1_id, hammadde_1_miktar, hammadde_2_id, hammadde_2_miktar, hammadde_3_id, hammadde_3_miktar, uretim_birimi, baz_satis_fiyati, uretim_adedi, satis_adedi, en_dusuk_fiyat, en_yuksek_fiyat, ortalama_fiyat, satici_sayisi, piyasadaki_stok, iscilik_maliyeti)
VALUES
  -- Nar: Kiraz gibi küçük premium meyve, 156 TL baz fiyat
  ('NAR',    'Nar',    'nar.webp',    0.006, 1, 'GUBRE', 1.1835, NULL, 0, NULL, 0, 'TARLA', 156, 50, 30, 156, 156, 156, 0, 0, 2.00),
  -- Muz: Portakal/Kivi gibi orta meyve, 143 TL baz fiyat
  ('MUZ',    'Muz',    'muz.webp',    0.012, 1, 'GUBRE', 1.0830, NULL, 0, NULL, 0, 'TARLA', 143, 70, 42, 143, 143, 143, 0, 0, 2.00),
  -- Kayısı: Şeftali gibi yumuşak meyve, 156 TL baz fiyat
  ('KAYISI', 'Kayısı', 'kayisi.webp', 0.010, 1, 'GUBRE', 1.1835, NULL, 0, NULL, 0, 'TARLA', 156, 60, 36, 156, 156, 156, 0, 0, 2.00);

-- Meyve Bahçesi çiftlik tipine yeni ürünleri ekle
UPDATE farm_types
SET accepted_product_ids = accepted_product_ids || ',NAR,MUZ,KAYISI'
WHERE id = '95e06481-759f-47a3-a403-56734681c538';

-- Manav mağaza tipine yeni ürünleri ekle (satışa açılsın)
UPDATE store_types
SET accepted_product_ids = accepted_product_ids || ',NAR,MUZ,KAYISI'
WHERE id = 'cdca04a5-00b6-4e9c-bebf-7f2b8ee2c05a';


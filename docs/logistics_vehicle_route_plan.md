# Logistics Vehicle Route Pair Plan

Bu dokuman, lojistik araclarin global olmaktan cikarak tek bir sehir ciftine baglanmasi icin hazirlandi.

## Karar

- Her arac yalnizca tek bir rota ciftine sahip olur.
- Rota cift yonludur.
- Ayni sehir transferleri anlik kalir ve arac secimi gerektirmez.
- Rota atamasi arac bazlidir.
- Mevcut araclar icin otomatik migration/backfill zorunlu degildir.

## Veri Modeli

`public.logistics_vehicles` tablosuna iki alan eklenir:

- `route_city_a_id uuid null references public.cities(id)`
- `route_city_b_id uuid null references public.cities(id)`

Beklenen kurallar:

- Iki alan da doluysa arac sehirler arasi transfere aday olabilir.
- Iki alan da bos ise arac yalnizca beklemede gorunur, fakat sehirler arasi arac secimi listelerine girmez.
- `route_city_a_id <> route_city_b_id`

Opsiyonel ama onerilen kontrol:

```sql
alter table public.logistics_vehicles
add constraint logistics_vehicles_route_city_pair_check
check (
  (route_city_a_id is null and route_city_b_id is null) or
  (route_city_a_id is not null and route_city_b_id is not null and route_city_a_id <> route_city_b_id)
);
```

## Arac Secim Kurali

Sehirler arasi bir transfer icin arac secilirken yalnizca su araclar aday olabilir:

- arac durumu uygun olmali
- arac aktif olmali
- yakit ve kondisyon kurallarini saglamali
- rota ciftinin iki sehri, transferin cikis ve varis sehirleri ile eslesmeli

Eslesme mantigi sirasizdir:

```text
(route_city_a_id = from_city and route_city_b_id = to_city)
or
(route_city_a_id = to_city and route_city_b_id = from_city)
```

## Etkilenen RPC Aileleri

Asagidaki `vehicle options` fonksiyonlari rota ciftine gore filtreleme yapmali:

- `get_store_transfer_vehicle_options`
- `get_store_to_warehouse_vehicle_options`
- `get_market_transfer_vehicle_options`
- `get_production_input_transfer_vehicle_options`
- `get_production_output_transfer_vehicle_options`

Asagidaki `start transfer` fonksiyonlari da savunmaci kontrol yapmali:

- `start_warehouse_to_store_transfer`
- `start_store_to_warehouse_transfer`
- `start_market_to_buyer_transfer`
- `start_warehouse_to_production_transfer`
- `start_production_to_warehouse_transfer`

Neden: frontend arac listesini filtrelese bile backend tarafinda rota disi bir arac id gonderilmesini engellemek gerekir.

## UI Beklentisi

`Lojistik Yonetimi` ekraninda her arac kartinda:

- mevcut rota ozeti
- rota yoksa uyari metni
- `Rota` / `Rota Degistir` aksiyonu

Akis:

1. Oyuncu bir arac secer.
2. Iki farkli sehir secer.
3. Kaydedince `route_city_a_id` ve `route_city_b_id` guncellenir.
4. Bu rota, sehirler arasi tum arac secim ekranlarinda kullanilir.

## Gecis Stratejisi

1. Veri modeli eklenir.
2. Lojistik UI rota atamayi destekler.
3. Tum `vehicle options` RPC'leri rota ciftine gore filtrelenir.
4. Tum `start transfer` RPC'lerine backend dogrulamasi eklenir.
5. Transfer map ve history ekranlari bilgi amacli rota ozeti gosterebilir, ama zorunlu degildir.

## Riskler

- Rota alani bos kalan araclar artik sehirler arasi transferde kullanilamayacagi icin oyuncu akisi sessizce daralabilir. Bu nedenle UI'da acik uyari gosterilmeli.
- Eski SQL fonksiyonlari filtrelenmeden kalirsa yeni UI ile backend davranisi celisebilir.
- Ayni sehri iki kez secme engeli hem UI hem DB seviyesinde olmali.

# Hard Kapitalizm — Patch Sistemi 5. Parti Frontend Entegrasyon Raporu

**Tarih:** 2026-09-09  
**Kapsam:** Finans + Vergi + AR-GE + Marka + Ödüller + Tender + Bina Satışı + Bulk Lojistik Bakım  
**Backend durumu:** Canlı Supabase üzerinde patch-aware wrapper'lar uygulanmıştır.  
**Amaç:** Mutation sonrası broad `invalidate/refetch` yerine RPC response içindeki `changed.player` ve `changed.patches[]` verilerini doğrudan local state'e uygulamak.

---

## 1. Patch response standardı

5. partide de önceki partilerle aynı contract kullanılmaktadır:

```json
{
  "changed": {
    "player": {
      "cash": 123456,
      "gold": 88
    },
    "patches": [
      {
        "entity": "player_loan",
        "operation": "insert",
        "id": "uuid",
        "changes": {
          "...": "..."
        }
      }
    ]
  }
}
```

### Null semantiği

- key response içinde varsa ve değeri `null` ise → alan bilinçli olarak temizlenir.
- key response içinde yoksa → alan değişmemiştir.
- `changes['field'] ?? oldValue` yaklaşımı null temizlemeyi bozabilir.
- `containsKey('field')` kontrolü kullanılmalıdır.

---

# 2. 5. partide patch-aware hale gelen RPC'ler

## Finans / Vergi

```text
take_loan
pay_loan_installment
pay_full_loan
create_deposit
claim_deposit
withdraw_deposit_early
pay_tax_debt
```

## AR-GE / Marka

```text
start_arge_research
finish_arge_with_gold
create_brand_company
update_brand_company
patent_brand_company_product
set_brand_company_product_watermark
start_marketing_campaign
```

## Ödüller

```text
claim_daily_streak_reward
claim_player_mission_reward
claim_player_achievement_reward
```

## Tender

```text
accept_tender
cancel_player_tender
complete_player_tender
start_tender_delivery
submit_tender_bid
process_tender_deliveries
process_player_tenders
```

## Bina satışı

```text
sell_building
sell_store
```

## Bulk lojistik bakım

```text
refuel_all_logistics_vehicles
repair_all_logistics_vehicles
```

---

# 3. Yeni frontend patch entity'leri

Dispatcher'ın tanıması gereken yeni entity'ler:

```text
player_loan
player_deposit
player_tax
arge_research
player_product_quality
brand_company
brand_company_product
brand_marketing_campaign
player_mission
player_daily_streak
tender
tender_bid
player_tender
tender_delivery
logistics_finance_entry
store_daily_performance
```

Önceki partilerde zaten desteklenen entity'ler 5. parti response'larında tekrar gelebilir:

```text
store
store_slot
warehouse
warehouse_slot
factory
mine
field
farm
production_slot
production_inventory
logistics_company
logistics_vehicle
logistics_transfer
logistics_transfer_item
building_upgrade
building_boost
building_construction
arge_center
```

---

# 4. Dispatcher'a eklenecek case'ler

```dart
case 'player_loan':
  _applyPlayerLoanPatch(patch);
  break;
case 'player_deposit':
  _applyPlayerDepositPatch(patch);
  break;
case 'player_tax':
  _applyPlayerTaxPatch(patch);
  break;
case 'arge_research':
  _applyArgeResearchPatch(patch);
  break;
case 'player_product_quality':
  _applyPlayerProductQualityPatch(patch);
  break;
case 'brand_company':
  _applyBrandCompanyPatch(patch);
  break;
case 'brand_company_product':
  _applyBrandCompanyProductPatch(patch);
  break;
case 'brand_marketing_campaign':
  _applyBrandMarketingCampaignPatch(patch);
  break;
case 'player_mission':
  _applyPlayerMissionPatch(patch);
  break;
case 'player_daily_streak':
  _applyPlayerDailyStreakPatch(patch);
  break;
case 'tender':
  _applyTenderPatch(patch);
  break;
case 'tender_bid':
  _applyTenderBidPatch(patch);
  break;
case 'player_tender':
  _applyPlayerTenderPatch(patch);
  break;
case 'tender_delivery':
  _applyTenderDeliveryPatch(patch);
  break;
case 'logistics_finance_entry':
  _applyLogisticsFinanceEntryPatch(patch);
  break;
case 'store_daily_performance':
  _applyStoreDailyPerformancePatch(patch);
  break;
```

Unknown entity sessizce yutulmamalıdır.

---

# 5. Finans entegrasyonu

## `player_loan`

RPC'ler:

```text
take_loan
pay_loan_installment
pay_full_loan
```

Beklenen:

```text
take_loan            -> insert
pay_loan_installment -> update
pay_full_loan        -> update
```

Ayrıca `changed.player.cash` gelebilir.

Provider davranışı:

```text
insert -> listeye ekle
update -> id üzerinden merge
delete -> listeden çıkar
```

Mutation sonrası `playerProvider` ve `loansProvider` broad invalidate edilmemelidir.

## `player_deposit`

RPC'ler:

```text
create_deposit
claim_deposit
withdraw_deposit_early
```

Beklenen:

```text
create  -> insert
claim   -> update status=claimed
early   -> update status=withdrawn_early
```

Record'ı frontend tarafında keyfi olarak delete'e çevirmeyin; backend status değiştirir.

## `player_tax`

RPC:

```text
pay_tax_debt
```

Beklenen:

```text
player.cash ↓
player_tax.tax_debt ↓
```

Patch başarılıysa `tax_dirty` nedeniyle ayrıca invalidate etmeyin. Patch başarısızsa targeted tax refresh kullanılabilir.

---

# 6. AR-GE entegrasyonu

## `arge_research`

RPC'ler:

```text
start_arge_research
finish_arge_with_gold
```

Start:

```text
player.cash ↓
arge_research insert
```

Gold ile tamamlama:

```text
player.gold ↓
arge_research update
player_product_quality insert/update
```

## `player_product_quality`

AR-GE research tamamlanınca ürünün `max_quality_level` değeri değişebilir.

Öneri: frontend kalite cache'ini `product_id` bazlı hızlı erişime uygun tut, fakat patch identity olarak backend'den gelen `patch.id` değerini koru.

---

# 7. Marka sistemi

## `brand_company`

RPC'ler:

```text
create_brand_company
update_brand_company
```

Beklenen:

```text
create -> insert
update -> update
```

Brand header, logo ve theme color local patch ile yenilenmelidir.

## `brand_company_product`

RPC'ler:

```text
patent_brand_company_product
set_brand_company_product_watermark
```

Patent:

```text
player.cash ↓
brand_company_product insert/update
```

Watermark temizleme durumunda:

```json
{
  "watermark_asset_id": null
}
```

gelebilir. `containsKey()` zorunlu.

## `brand_marketing_campaign`

RPC:

```text
start_marketing_campaign
```

Beklenen:

```text
player.cash ↓
brand_marketing_campaign insert
```

---

# 8. Ödül sistemi

## `player_daily_streak`

RPC:

```text
claim_daily_streak_reward
```

Beklenen:

```text
player.cash/gold ↑
player_daily_streak insert/update
```

## `player_mission`

RPC'ler:

```text
claim_player_mission_reward
claim_player_achievement_reward
```

Beklenen alanlar:

```text
is_completed
is_claimed
claimed_at
progress_count
updated_at
```

Ayrıca player:

```text
cash
gold
experience
level
```

değişebilir.

Claim sonrası broad dashboard refresh yerine patch uygulanmalıdır.

---

# 9. Tender sistemi

Yeni entity'ler:

```text
tender
tender_bid
player_tender
tender_delivery
```

Aynı response'ta şu eski entity'ler de gelebilir:

```text
warehouse_slot
logistics_vehicle
player
```

## `accept_tender`

Beklenen:

```text
player.cash ↓
player_tender insert
tender update open -> closed
```

## `submit_tender_bid`

İlk teklif:

```text
player.cash ↓
tender_bid insert
```

Teklif güncelleme:

```text
tender_bid update
```

Frontend ikinci bid update'te kendi başına bond tekrar düşmemelidir.

## `start_tender_delivery`

Beklenebilecek patch'ler:

```text
player
warehouse_slot
logistics_vehicle
tender_delivery
player_tender
```

Aynı şehir delivery anında tamamlanabilir. Bu durumda frontend transient `in_transit` state üretmemeli; response'taki final state'i uygulamalıdır.

## `process_tender_deliveries`

Beklenebilir:

```text
tender_delivery update
logistics_vehicle idle
player_tender delivered_quantity ↑
player cash/xp update
```

## `cancel_player_tender`

Beklenen:

```text
player_tender status=cancelled
tender_delivery status=cancelled
logistics_vehicle status=idle
```

## `process_player_tenders`

Deadline geçmiş ihale:

```text
player_tender status=failed
failed_at
```

---

# 10. Bulk lojistik bakım

## `refuel_all_logistics_vehicles`

Bir mutation response'unda birden fazla:

```text
logistics_vehicle update
logistics_company update
```

patch'i gelebilir.

`patches[]` tamamı sırayla uygulanmalıdır.

## `repair_all_logistics_vehicles`

Beklenen:

```text
player.cash ↓
multiple logistics_vehicle update
```

Broad logistics refetch kaldırılabilir.

---

# 11. Bina satışları

## `sell_store`

`p_confirm=false` teklif aşamasıdır; DB mutation olmayabilir.

`p_confirm=true`:

```text
store delete
store_slot delete
building_upgrade delete
building_boost delete
store_daily_performance delete
player.cash ↑
logistics_transfer update
```

Store detail ekranı açıksa `store delete` sonrası detail state temizlenmeli ve active detail id registry'den çıkarılmalıdır.

## `sell_building`

Desteklenen türler:

```text
warehouse
factory
field
farm
mine
store
```

Warehouse satışında:

```text
warehouse delete
warehouse_slot delete
building_upgrade delete
building_boost delete
logistics_transfer update
logistics_transfer_item update
logistics_finance_entry update
player.cash ↑
```

Production building satışında:

```text
factory/field/farm/mine delete
production_slot delete
production_inventory delete
building_upgrade delete
building_boost delete
logistics_transfer update
logistics_transfer_item update
player.cash ↑
```

Delete handler'ları idempotent olmalıdır.

---

# 12. `store_daily_performance`

Store satışı sırasında geçmiş performans kayıtları silinebilir.

Provider local cache tutuyorsa delete patch uygulanmalı. Transient analytics provider kullanılıyorsa targeted refresh fallback kabul edilebilir.

Priority:

```text
1. local patch
2. targeted feature refresh
3. feature invalidate
```

---

# 13. `logistics_finance_entry`

Warehouse satışında geçmiş finans satırlarının:

```text
related_warehouse_slot_id
```

alanı `null` olabilir.

Bu null frontend'de gerçekten temizlenmelidir.

---

# 14. MutationSyncService

MutationSyncService'i feature manager'a çevirmeyin.

Görevi:

```text
changed.player uygula
changed.patches iterate et
EntityPatchDispatcher'a route et
fallback/dirty metadata değerlendir
unknown entity logla
```

Feature logic notifier katmanında kalmalıdır.

---

# 15. Invalidate temizleme politikası

Eski:

```dart
final result = await api.takeLoan(...);

ref.invalidate(playerProvider);
ref.invalidate(loansProvider);
ref.invalidate(homeDashboardProvider);
```

Yeni:

```dart
final result = await api.takeLoan(...);

await ref
    .read(mutationSyncServiceProvider)
    .applyRpcResponse(result);
```

Targeted fallback bırakılabilecek durumlar:

```text
unknown entity
insert parse error
active detail provider bulunamadı
derived feature state güvenli patch edilemiyor
partial patch apply exception
```

Her mutation sonunda otomatik invalidate bırakılmamalıdır.

---

# 16. Dashboard dirty

Bazı eski RPC'ler `dashboard_dirty=true` döndürebilir.

Öneri:

```text
changed.player + ilgili patches mevcutsa
    dashboard invalidate etme
else if dashboard_dirty == true
    targeted dashboard invalidate
```

---

# 17. Player patch

5. partide sık değişen alanlar:

```text
cash
gold
experience
level
```

Generic fakat kontrollü model merge tercih edilir.

Null semantiği yine `containsKey()` ile korunmalıdır.

---

# 18. Entity identity notları

## `tender_delivery`

Parent:

```text
player_tender_id
```

## `brand_company_product`

Parent:

```text
brand_company_id
player_id
```

## `arge_research`

Parent:

```text
player_id
product_id
```

## `player_mission`

Mantıksal identity composite olabilir:

```text
player_id + mission_id
```

Frontend kendi farklı ID'sini uydurmamalı; backend `patch.id` kullanılmalıdır.

## `player_daily_streak`

Current-player singleton state olarak tutulabilir.

---

# 19. Delete patch davranışı

Özellikle:

```text
sell_store
sell_building
```

için delete desteği zorunlu.

```dart
case PatchOperation.delete:
  notifier.removeById(patch.id);
```

Delete patch'te `changes` boş olabilir.

---

# 20. Multi-patch ordering

Bir RPC onlarca patch döndürebilir.

Örnek:

```text
production_inventory delete
production_slot delete
building_boost delete
building_upgrade delete
factory delete
player cash patch
```

Dispatcher response sırasıyla uygulasın; fakat handler'lar ordering'e bağımlı olmasın.

Child daha önce silindiyse parent delete hata vermemeli; parent daha önce silindiyse child delete de hata vermemeli.

---

# 21. Önerilen notifier API'leri

## Finance

```text
insertLoan
patchLoan
removeLoan
insertDeposit
patchDeposit
removeDeposit
patchTax
```

## AR-GE

```text
insertResearch
patchResearch
removeResearch
upsertProductQuality
```

## Brand

```text
setBrandCompany
patchBrandCompany
insertBrandProduct
patchBrandProduct
removeBrandProduct
insertCampaign
patchCampaign
removeCampaign
```

## Rewards

```text
patchMission
upsertDailyStreak
```

## Tender

```text
insertTender
patchTender
removeTender
insertBid
patchBid
removeBid
insertPlayerTender
patchPlayerTender
removePlayerTender
insertDelivery
patchDelivery
removeDelivery
```

---

# 22. Kod tabanında aranacak invalidation'lar

Şunları ara:

```text
invalidate(
invalidateSelf(
refresh(
refetch
reload
```

Özellikle:

```text
bank
loan
deposit
tax
arge
brand
marketing
mission
achievement
daily streak
tender
building sale
store sale
logistics bulk repair
logistics bulk refuel
```

Her invalidate için şu soru sorulmalı:

> RPC `changed` response'u bu state'i zaten eksiksiz patch ediyor mu?

Evet ise kaldır.

---

# 23. Manual test checklist

## Finans

- [ ] Kredi çek → cash artıyor
- [ ] loan insert
- [ ] taksit öde → cash azalıyor
- [ ] installments_paid artıyor
- [ ] full payoff → status paid
- [ ] mevduat aç → cash azalıyor
- [ ] deposit insert
- [ ] claim → cash artıyor + status claimed
- [ ] early withdrawal → status withdrawn_early
- [ ] vergi öde → cash azalıyor
- [ ] tax_debt azalıyor
- [ ] full tax payment → 0

## AR-GE

- [ ] research start → cash azalıyor
- [ ] research insert
- [ ] gold finish → gold azalıyor
- [ ] research completed
- [ ] product quality artıyor
- [ ] Q UI refetch olmadan güncelleniyor

## Marka

- [ ] brand create insert
- [ ] brand rename update
- [ ] logo update
- [ ] theme color update
- [ ] patent → cash azalıyor
- [ ] brand product insert/update
- [ ] watermark set
- [ ] watermark clear null
- [ ] campaign start → cash azalıyor
- [ ] campaign insert

## Ödüller

- [ ] daily streak claim
- [ ] streak_count update
- [ ] mission claimed
- [ ] achievement claimed
- [ ] cash/gold/xp/level doğru
- [ ] broad dashboard refetch yok

## Tender

- [ ] accept → bond cash düşer
- [ ] player_tender insert
- [ ] tender closed
- [ ] bid insert
- [ ] bid update
- [ ] bid update'te ikinci bond yok
- [ ] delivery start → warehouse stok azalır
- [ ] vehicle on_route
- [ ] fuel azalır
- [ ] condition azalır
- [ ] tender_delivery insert
- [ ] same-city final state doğru
- [ ] process delivery → vehicle idle
- [ ] delivered_quantity artar
- [ ] tender complete → payout + XP
- [ ] cancel → delivery cancelled + vehicle idle
- [ ] expired tender → failed

## Bulk lojistik

- [ ] refuel all → multiple vehicle patch
- [ ] logistics company fuel azalır
- [ ] repair all → multiple vehicle condition 100
- [ ] cash doğru azalır
- [ ] broad refetch yok

## Satış

- [ ] quote confirm=false state değiştirmez
- [ ] store confirm=true delete
- [ ] store detail temizlenir
- [ ] store slots delete
- [ ] boost/upgrade delete
- [ ] cash refund gelir
- [ ] warehouse delete
- [ ] warehouse slots delete
- [ ] production unit delete
- [ ] production slots delete
- [ ] production inventory delete
- [ ] historical transfer refs null
- [ ] logistics_finance_entry null merge doğru

---

# 24. Regression checklist

- [ ] store_slot metadata patch bozulmadı
- [ ] isEmpty product_id semantiği korunuyor
- [ ] production_inventory patch çalışıyor
- [ ] production detail parent resolution çalışıyor
- [ ] logistics transfer patch çalışıyor
- [ ] building_upgrade patch çalışıyor
- [ ] building_boost patch çalışıyor
- [ ] construction patch çalışıyor
- [ ] unknown entity loglanıyor
- [ ] null semantiği korunuyor
- [ ] patch failure sessizce yutulmuyor

---

# 25. Market invalidate'larına dokunmayın

6. parti henüz yapılmadı.

Kapsam dışı:

```text
start_multi_market_transfer
complete_due_market_transfers
market seller/buyer cross-player state
market listing quantity/removal
seller payout
seller notification
```

Market mutation'larında mevcut refresh/invalidate sistemi şimdilik korunmalıdır.

---

# 26. Uygulama sırası

```text
1. Dispatcher yeni entity case'leri
2. Feature notifier insert/update/delete API'leri
3. Finance mutation sync
4. AR-GE + brand sync
5. Reward sync
6. Tender sync
7. Bulk logistics sync
8. Building/store sale sync
9. Coverage tam invalidation'ları kaldır
10. Targeted fallback'leri bırak
11. Test ekle
12. Manual checklist'i çalıştır
```

---

# 27. Backend performans notu

İlk geniş snapshot tasarımı:

```text
tek snapshot ≈ 140 ms
before + after ≈ 280 ms
```

Bu kullanılmadı.

Scope bazlı canlı yapı:

```text
Finance             ≈ 1.3 ms
AR-GE / Brand       ≈ 4.3 ms
Rewards             ≈ 4.0 ms
Tender              ≈ 24 ms
Bulk Logistics      ≈ 3.7 ms
Building Sale       ≈ 46 ms
```

Normal mutation'larda patch ek maliyeti birkaç ms seviyesindedir.

---

# 28. Güvenlik notu

Internal helper/core pattern:

```text
_patch5_*
```

frontend tarafından doğrudan çağrılmamalıdır.

Frontend mevcut public RPC isimlerini kullanmaya devam eder.

RPC parametre imzaları korunmuştur.

---

# 29. 5. parti tamamlanma kriteri

```text
✓ 16 yeni entity dispatcher tarafından destekleniyor
✓ Player patch uygulanıyor
✓ Finance invalidate olmadan çalışıyor
✓ AR-GE research + quality patch çalışıyor
✓ Brand patch çalışıyor
✓ Reward patch çalışıyor
✓ Tender multi-entity state patch ile güncelleniyor
✓ Same-city tender final state doğru
✓ Bulk logistics multiple patch uyguluyor
✓ Building/store delete patch doğru temizleniyor
✓ Null semantics korunuyor
✓ Unknown entity fallback var
✓ Market invalidate'ları korunuyor
✓ Broad invalidate yalnız coverage tam olduğunda kaldırılıyor
```

---

# 30. Sonraki ve son ana bölüm

5. parti frontend entegrasyonu tamamlandıktan sonra ana olarak:

```text
6. Parti — Market / Multiplayer
```

kalacaktır.

Market ayrı tutulmalıdır çünkü tek purchase aynı anda buyer ve seller state'ini değiştirir.

Buyer response'una seller'ın private player state'i verilmemelidir.

---

## Sonuç

5. parti frontend prensibi:

```text
RPC
 ↓
changed.player
 ↓
changed.patches[]
 ↓
MutationSyncService
 ↓
EntityPatchDispatcher
 ↓
Feature Notifier
 ↓
UI
```

Mutation sonrası frontend “hangi provider değişmiş olabilir?” tahmini yapmak yerine backend'in döndürdüğü authoritative diff'i uygulamalıdır.

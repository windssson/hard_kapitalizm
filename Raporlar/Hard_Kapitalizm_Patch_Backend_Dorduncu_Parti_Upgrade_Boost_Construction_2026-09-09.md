# Hard Kapitalizm — Patch Sistemi Backend Değişiklik Raporu

**Tarih:** 2026-09-09  
**Kapsam:** Backend Dördüncü Parti — Upgrade + Boost + Construction Hızlandırma  
**Backend:** Supabase / PostgreSQL RPC

---

# 1. Amaç

Dördüncü partinin amacı bina yükseltme, boost ve construction hızlandırma işlemlerini:

```json
{
  "changed": {
    "player": {},
    "patches": []
  }
}
```

contract'ına geçirmek ve mutation sonrası broad invalidate / full refetch ihtiyacını azaltmaktır.

Bu gruptaki işlemler tek bir tabloyu değiştirmez.

Örneğin bir upgrade tamamlandığında aynı anda:

```text
building_upgrade
ilgili bina
store_slot / production_slot
player XP / level
```

değişebilir.

Bu nedenle outer BEFORE / AFTER snapshot + diff yaklaşımı kullanılmıştır.

---

# 2. Patch-Aware Hale Gelen RPC'ler

```text
start_building_upgrade
complete_building_upgrade
finish_building_upgrade_with_gold
reduce_building_upgrade_time_with_ad

start_building_boost
start_building_boost_with_ad_reward
finish_building_boost

finish_construction_with_gold
reduce_construction_time_with_ad
```

---

# 3. Bu Partide Yeni Entity Yok

Frontend dispatcher'a yeni entity adı eklemek gerekmez.

Kullanılan entity'ler zaten mevcut:

```text
building_upgrade
building_boost
building_construction

store
store_slot
warehouse
factory
mine
field
farm
arge_center
production_slot
```

Player değişiklikleri:

```text
changed.player
```

altında gelir.

---

# 4. Genel Patch Contract

Örnek:

```json
{
  "success": true,
  "changed": {
    "player": {
      "gold": 59
    },
    "patches": [
      {
        "entity": "building_boost",
        "operation": "insert",
        "id": "...",
        "changes": {}
      },
      {
        "entity": "factory",
        "operation": "update",
        "id": "...",
        "changes": {
          "boost_multiplier": 2
        }
      }
    ]
  }
}
```

Frontend uygulama sırası:

```text
changed.player
↓
changed.patches[]
```

---

# 5. `start_building_upgrade`

Upgrade başlangıcında temel değişiklikler:

```text
player.cash
building_upgrade insert
```

Bazı durumlarda `start_building_upgrade` çağrısı başlamadan önce:

```text
complete_due_player_building_upgrades
```

çalışabilir.

Dolayısıyla response aynı anda eski bir upgrade'in completion patch'lerini de içerebilir.

Bu sebeple frontend yalnız yeni `building_upgrade insert` beklememelidir.

---

# 6. Start Upgrade — Player Patch

Upgrade maliyeti:

```text
player.cash -= upgrade_cost
```

olarak backend tarafından hesaplanır.

Frontend cash'i yeniden hesaplamamalı.

Örnek:

```json
{
  "changed": {
    "player": {
      "cash": 925000
    }
  }
}
```

---

# 7. Start Upgrade — Building Upgrade Insert

Yeni upgrade:

```text
building_upgrade insert
```

olarak gelir.

Insert full row içerebilir:

```text
id
player_id
building_kind
entity_id
current_level
target_level
params
status
started_at
finish_at
created_at
updated_at
completed_at
```

Frontend active upgrade provider bunu local state'e set edebilmelidir.

---

# 8. `complete_building_upgrade`

Upgrade tamamlandığında:

```text
building_upgrade update
ilgili building update
player experience / level
```

oluşabilir.

Store upgrade için ek olarak:

```text
store_slot update
```

çünkü mevcut shelf capacity değerleri artırılır.

---

# 9. Store Upgrade Completion

Store tarafında değişebilen:

```text
store.level
store.slot_capacity
store.max_slot_count
store.updated_at
```

Ayrıca tüm mevcut slotlarda:

```text
store_slot.capacity
store_slot.updated_at
```

değişir.

Frontend:

```text
store list
store detail
store slots
active upgrade
```

state'lerini patch ile güncellemelidir.

---

# 10. Warehouse Upgrade Completion

Warehouse:

```text
level
capacity
updated_at
```

değişebilir.

Örnek patch:

```json
{
  "entity": "warehouse",
  "operation": "update",
  "id": "...",
  "changes": {
    "level": 3,
    "capacity": 45000
  }
}
```

---

# 11. Factory Upgrade Completion

Factory:

```text
level
input_capacity
output_capacity
updated_at
```

değişebilir.

Frontend list ve detail state'i aynı anda patch edilmelidir.

---

# 12. Mine Upgrade Completion

Mine:

```text
level
output_capacity
updated_at
```

değişebilir.

---

# 13. Tarla / Çiftlik Upgrade Completion

Backend isimleri:

```text
farm  = UI Tarla
field = UI Çiftlik
```

Değişebilen:

```text
level
input_capacity
output_capacity
updated_at
```

---

# 14. AR-GE Center Upgrade Completion

`arge_center`:

```text
level
max_concurrent_researches
duration_reduction_pct
updated_at
```

değişebilir.

Frontend AR-GE center provider bu alanları patch edebilmelidir.

---

# 15. Upgrade Completion — Building Upgrade Row

Upgrade final state:

```text
status = completed
completed_at
updated_at
```

Frontend active upgrade provider:

```text
status == completed
```

geldiğinde:

```text
activeUpgrade = null
```

yapabilir.

---

# 16. Upgrade Completion — XP / Level

Upgrade tamamlanınca:

```text
changed.player.experience
changed.player.level
```

gelebilir.

Frontend mevcut `MutationSyncService` player handler'ını kullanmalıdır.

Ek `get_player_profile()` çağrısı gerekmemelidir.

---

# 17. `finish_building_upgrade_with_gold`

İşlem zinciri:

```text
player.gold azalt
↓
building_upgrade.finish_at = now
↓
complete_building_upgrade
```

Outer wrapper tüm süreci final state olarak diff eder.

Response şu değişiklikleri tek seferde içerebilir:

```text
player.gold
player.experience
player.level

building_upgrade.finish_at
building_upgrade.status
building_upgrade.completed_at

ilgili building level/capacity
store_slot capacity
```

---

# 18. Gold Finish Frontend Kuralı

Frontend:

```text
goldSpent
```

gibi top-level metadata'yı UI mesajı için kullanabilir.

Ama authoritative state:

```text
changed.player.gold
```

olmalıdır.

Gold'u frontend manuel düşmemelidir.

---

# 19. `reduce_building_upgrade_time_with_ad`

Reklamla süre kısaltıldığında iki olası sonuç vardır.

## Durum A — Upgrade hâlâ devam ediyor

```text
building_upgrade update
```

özellikle:

```text
finish_at
updated_at
```

değişir.

## Durum B — Süre sıfırlandı ve upgrade tamamlandı

Aynı response içinde:

```text
building_upgrade completed
ilgili building update
player XP / level
slot updates
```

gelebilir.

Frontend iki durumu aynı contract ile karşılamalıdır.

---

# 20. Upgrade Ad Reward Metadata

Top-level response:

```text
time_reduced_minutes
reward_daily_usage
reward_daily_limit
message
```

alanlarını korur.

Bunlar UI için metadata'dır.

State patch'leri:

```text
changed
```

altından uygulanmalıdır.

---

# 21. `start_building_boost`

Boost başlangıcında:

```text
player.gold
building_boost insert
building/slot boost_multiplier update
```

oluşur.

Canlı rollback testinde factory için doğrulandı.

---

# 22. Boost Başlangıç — Factory

Örnek:

```text
building_boost insert
factory update
```

Factory patch:

```json
{
  "entity": "factory",
  "operation": "update",
  "id": "...",
  "changes": {
    "boost_multiplier": 2
  }
}
```

---

# 23. Boost Başlangıç — Mine

Mine:

```text
boost_multiplier = 2
updated_at
```

---

# 24. Boost Başlangıç — Store

Store boost doğrudan `stores` tablosunda tutulmaz.

Tüm store slotları:

```text
store_slot.boost_multiplier = 2
```

olur.

Dolayısıyla tek bir boost işlemi birden fazla:

```text
store_slot update
```

patch'i üretebilir.

Frontend tüm slot patch'lerini idempotent uygulamalıdır.

---

# 25. Boost Başlangıç — Tarla / Çiftlik

Backend:

```text
field
farm
```

için:

```text
production_slot.boost_multiplier = 2
```

değişir.

Birden fazla production slot varsa birden fazla patch gelir.

---

# 26. Boost Insert

Yeni boost:

```text
building_boost insert
```

full row olarak gelebilir:

```text
id
player_id
building_kind
entity_id
duration_hours
star_cost
multiplier
params
status
started_at
finish_at
created_at
updated_at
completed_at
```

Frontend active boost provider'a set edilmelidir.

---

# 27. `start_building_boost_with_ad_reward`

Gold harcanmaz.

Ama:

```text
building_boost insert
building/slot boost_multiplier update
```

oluşur.

Top-level metadata:

```text
reward_daily_usage
reward_daily_limit
duration_minutes
```

korunur.

---

# 28. `finish_building_boost`

Boost bittiğinde:

```text
building_boost update
building/slot boost_multiplier = 1
```

oluşur.

Factory:

```text
factory.boost_multiplier = 1
```

Mine:

```text
mine.boost_multiplier = 1
```

Store:

```text
store_slot.boost_multiplier = 1
```

Tarla / Çiftlik:

```text
production_slot.boost_multiplier = 1
```

---

# 29. Boost Completion Frontend Davranışı

`building_boost` patch:

```text
status = completed
```

ise:

```text
activeBoost = null
```

yapılabilir.

Aynı zamanda building/slot patch'leri de uygulanmalıdır.

Sadece active boost state'i temizleyip slot/building multiplier'ını eski bırakmak bug oluşturur.

---

# 30. `finish_construction_with_gold`

İşlem zinciri:

```text
player.gold azalt
↓
building_construction.finish_at geçmişe çek
↓
complete_building_construction
```

Mevcut `complete_building_construction` zaten patch-aware olduğu için outer wrapper final diff'i korur.

---

# 31. Gold Construction Completion

Olası değişiklikler:

```text
player.gold
player.experience
player.level

building_construction update

new building insert:
store
warehouse
factory
field
farm
mine
arge_center
logistics_company
```

Frontend construction screen + ilgili list provider patch ile güncellenebilmelidir.

---

# 32. `reduce_construction_time_with_ad`

İki durum:

## Devam ediyor

```text
building_construction.finish_at update
```

## Tamamlandı

```text
building_construction completed
new building insert
player XP / level
```

tek response'ta gelebilir.

---

# 33. Construction Ad Metadata

Top-level:

```text
time_reduced_minutes
reward_daily_usage
reward_daily_limit
message
```

korunur.

State için yine:

```text
changed
```

esas alınmalıdır.

---

# 34. Dispatcher — Mevcut Entity'leri Genişlet

Yeni case eklenmez.

Ama mevcut handler'lar aşağıdaki alanları desteklemelidir.

---

# 35. `building_upgrade` Handler

Desteklenecek:

```text
insert
update
delete
```

Pratik kullanım:

```text
insert
update
```

Update alanları:

```text
status
finish_at
completed_at
updated_at
current_level
target_level
params
```

Parent identity:

```text
building_kind
entity_id
```

korunmalıdır.

---

# 36. `building_boost` Handler

Desteklenecek:

```text
insert
update
delete
```

Alanlar:

```text
status
finish_at
completed_at
updated_at
multiplier
duration_hours
params
building_kind
entity_id
```

---

# 37. `building_construction` Handler

Mevcut handler:

```text
status
finish_at
completed_at
```

alanlarını merge etmelidir.

Gold/ad hızlandırmalarında özellikle `finish_at` patch'i önemlidir.

---

# 38. Store Handler Genişletme

Upgrade completion için:

```text
level
slot_capacity
max_slot_count
```

support edilmeli.

Boost store üzerinde değil slotlarda olduğu için store handler'a boost_multiplier gerekmez.

---

# 39. Store Slot Handler Genişletme

Support:

```text
capacity
boost_multiplier
updated_at
```

Özellikle:

```text
store upgrade completion
store boost start/finish
```

için gereklidir.

---

# 40. Factory Handler Genişletme

Support:

```text
level
input_capacity
output_capacity
boost_multiplier
updated_at
```

List ve detail provider aynı patch'i almalıdır.

---

# 41. Mine Handler Genişletme

Support:

```text
level
output_capacity
boost_multiplier
updated_at
```

---

# 42. Field / Farm Handler Genişletme

Support:

```text
level
input_capacity
output_capacity
updated_at
```

Boost multiplier unit row'da değil:

```text
production_slot
```

üzerindedir.

---

# 43. Production Slot Handler Genişletme

Support:

```text
boost_multiplier
updated_at
```

Üçüncü partiden zaten:

```text
last_production_at
```

support edilmeliydi.

---

# 44. Warehouse Handler Genişletme

Support:

```text
level
capacity
updated_at
```

---

# 45. AR-GE Center Handler

Support:

```text
level
max_concurrent_researches
duration_reduction_pct
updated_at
```

ARGE provider yüklü değilse targeted fallback kullanılabilir.

---

# 46. Active Upgrade Provider Stratejisi

Her feature'da mevcut active provider varsa:

```text
activeFactoryUpgradeProvider
activeMineUpgradeProvider
activeFarmUpgradeProvider
activeFieldUpgradeProvider
activeWarehouseUpgradeProvider
activeStoreUpgradeProvider
activeArgeUpgradeProvider
```

`building_upgrade insert` geldiğinde:

```text
setUpgrade(model)
```

`status=completed` geldiğinde:

```text
clear()
```

uygulanabilir.

---

# 47. Active Boost Provider Stratejisi

Benzer şekilde:

```text
activeFactoryBoostProvider
activeMineBoostProvider
activeFarmBoostProvider
activeFieldBoostProvider
activeStoreBoostProvider
```

Insert:

```text
setBoost(model)
```

Completed:

```text
clear()
```

---

# 48. Parent Lookup

`building_upgrade` ve `building_boost` patch'lerinde:

```text
building_kind
entity_id
```

parent resolution için kullanılmalıdır.

Örnek:

```text
building_kind = factory
entity_id = factory UUID
```

---

# 49. Null Semantiği

Genel kural devam eder:

```text
key present + null = clear
key absent = preserve
```

Özellikle:

```text
completed_at
```

için önemlidir.

Frontend:

```dart
changes.containsKey('completed_at')
```

ile kontrol etmelidir.

---

# 50. Upgrade Start Frontend Akışı

Eski:

```text
RPC
↓
invalidate player
invalidate building detail
invalidate upgrade provider
```

Yeni:

```text
RPC
↓
MutationSyncService.applyRaw(response)
↓
local state güncel
```

Yalnız patch parent bulunamazsa targeted fallback.

---

# 51. Upgrade Completion Frontend Akışı

Eski broad refresh yerine:

```text
building patch
slot patch
upgrade patch
player patch
```

uygulanır.

---

# 52. Boost Start Frontend Akışı

```text
RPC
↓
changed.player
building_boost insert
building/slot multiplier patch
```

Tam refresh gerekmemelidir.

---

# 53. Boost Finish Frontend Akışı

```text
building_boost completed
building/slot multiplier = 1
```

local uygulanır.

---

# 54. Gold Upgrade Finish — Refresh Temizliği

Aşağıdaki tür invalidation'lar patch-aware provider'lardan sonra kaldırılabilir:

```dart
ref.invalidate(activeFactoryUpgradeProvider(id));
ref.invalidate(factoryDetailProvider(id));
ref.invalidate(factoryListProvider);
ref.invalidate(playerProvider);
```

Benzerleri store/mine/farm/field/warehouse/arge için.

---

# 55. Ad Upgrade Reduce — Refresh Temizliği

Upgrade yalnız kısaldıysa:

```text
building_upgrade.finish_at
```

local state'e uygulanır.

Completion olduysa building patch'leri de gelir.

Bu nedenle:

```text
always refresh after rewarded ad
```

yaklaşımı gereksizdir.

---

# 56. Boost Refresh Temizliği

Kaldırılabilecek tipik invalidate'lar:

```text
active boost provider invalidate
building detail invalidate
production slot refresh
store detail refresh
```

Patch handler'lar hazır olduktan sonra.

---

# 57. Construction Gold/Ad Refresh Temizliği

Construction completion sonrası:

```text
building_construction
new building insert
player
```

gelir.

List provider insert destekliyorsa full building list invalidate gerekmemelidir.

---

# 58. Fallback Politikası

Standart sıra:

```text
1. local patch
2. targeted provider refresh
3. feature invalidate
4. global invalidate kullanma
```

---

# 59. Store Upgrade Test Checklist

- [ ] Upgrade başlat
- [ ] Player cash azalıyor
- [ ] building_upgrade insert geliyor
- [ ] Active upgrade UI anında görünüyor
- [ ] Gold ile bitir
- [ ] Player gold azalıyor
- [ ] Store level artıyor
- [ ] slot_capacity artıyor
- [ ] max_slot_count artıyor
- [ ] Existing store slots capacity artıyor
- [ ] Upgrade active state temizleniyor
- [ ] XP / level doğru
- [ ] Gereksiz refresh yok

---

# 60. Factory Upgrade Test Checklist

- [ ] Start upgrade
- [ ] Cash patch
- [ ] Upgrade insert
- [ ] finish_at doğru
- [ ] Completion
- [ ] Factory level artıyor
- [ ] input_capacity artıyor
- [ ] output_capacity artıyor
- [ ] active upgrade temizleniyor
- [ ] XP patch geliyor

---

# 61. Mine Upgrade Test Checklist

- [ ] Cash azalıyor
- [ ] upgrade active oluyor
- [ ] level artıyor
- [ ] output_capacity artıyor
- [ ] completion sonrası active upgrade yok

---

# 62. Tarla / Çiftlik Upgrade Checklist

- [ ] Correct backend kind mapping
- [ ] level artıyor
- [ ] input_capacity artıyor
- [ ] output_capacity artıyor
- [ ] list/detail birlikte güncelleniyor

---

# 63. Warehouse Upgrade Checklist

- [ ] Cash patch
- [ ] building_upgrade insert
- [ ] capacity artıyor
- [ ] level artıyor
- [ ] detail/list local update

---

# 64. AR-GE Upgrade Checklist

- [ ] Cash azalıyor
- [ ] upgrade insert
- [ ] level artıyor
- [ ] max_concurrent_researches doğru
- [ ] duration_reduction_pct doğru
- [ ] active upgrade temizleniyor

---

# 65. Factory Boost Checklist

- [ ] Gold boost başlat
- [ ] Player gold azalıyor
- [ ] building_boost insert
- [ ] factory.boost_multiplier = 2
- [ ] Active boost UI görünüyor
- [ ] Boost bitir
- [ ] factory.boost_multiplier = 1
- [ ] building_boost completed
- [ ] active boost temizleniyor

---

# 66. Mine Boost Checklist

- [ ] boost_multiplier 2
- [ ] timer doğru
- [ ] finish sonrası 1
- [ ] gereksiz refresh yok

---

# 67. Store Boost Checklist

- [ ] building_boost insert
- [ ] bütün mevcut slotlar multiplier 2
- [ ] yeni UI değerleri anında
- [ ] finish sonrası bütün slotlar 1
- [ ] active boost temizleniyor

---

# 68. Tarla / Çiftlik Boost Checklist

- [ ] production_slot multiplier 2
- [ ] her slot patch uygulanıyor
- [ ] finish sonrası 1
- [ ] active boost UI doğru

---

# 69. Ad Boost Checklist

- [ ] Gold değişmiyor
- [ ] Reward usage doğru
- [ ] building_boost insert
- [ ] multiplier 2
- [ ] duration 30 dakika
- [ ] active boost UI doğru

---

# 70. Upgrade Ad Reduce Checklist

- [ ] Reward daily usage artıyor
- [ ] 1-4 kullanımda 10 dk
- [ ] 5-6 kullanımda 7 dk
- [ ] 7-8 kullanımda 5 dk
- [ ] finish_at local güncelleniyor
- [ ] süre sıfırlandıysa completion patch'leri geliyor
- [ ] broad invalidate yok

---

# 71. Construction Gold Finish Checklist

- [ ] Gold cost doğru
- [ ] Player gold azalıyor
- [ ] construction completed
- [ ] new building insert
- [ ] XP doğru
- [ ] ilgili building list anında güncelleniyor

---

# 72. Construction Ad Reduce Checklist

- [ ] reward usage metadata
- [ ] finish_at update
- [ ] completion olduysa building insert
- [ ] construction state temizleniyor
- [ ] gereksiz refresh yok

---

# 73. Canlı Boost Rollback Testi

Gerçek factory üzerinde:

```text
start_building_boost
duration = 6h
```

transaction içinde çağrıldı.

Response:

```text
changed.player.gold
building_boost insert
factory update
```

Factory:

```text
boost_multiplier = 2
```

olarak doğrulandı.

Transaction rollback edildi.

Kalıcı kullanıcı state'i değişmedi.

---

# 74. Snapshot / Diff Performansı

Test hesabında state snapshot helper ölçümü yaklaşık:

```text
12.5 ms
```

çıktı.

Mutation başına BEFORE + AFTER snapshot maliyeti birkaç on milisaniye seviyesindedir.

Upgrade / boost / construction acceleration gibi seyrek mutation'lar için kabul edilebilir.

---

# 75. Güvenlik

Public client RPC'ler:

```text
authenticated
service_role
```

erişimine sahiptir.

Internal helper/core fonksiyonlarda:

```text
PUBLIC
anon
authenticated
```

execute kapatılmıştır.

Internal completion fonksiyonları mevcut server-side kullanım modeline göre korunmuştur.

---

# 76. Advisor Sonucu

Dördüncü parti migration nedeniyle yeni advisor problemi oluşmadı.

Mevcut teknik borçlar devam ediyor:

```text
logistics_companies_type_fk unindexed FK
6 auth RLS initplan
21 unused indexes
2 duplicate indexes
3 RLS enabled/no-policy
existing SECURITY DEFINER audit surface
leaked password protection disabled
```

---

# 77. Dördüncü Parti Frontend Tamamlanma Kriterleri

- [ ] building_upgrade insert/update handler tam
- [ ] building_boost insert/update handler tam
- [ ] building_construction finish_at patch tam
- [ ] store upgrade fields patch ediliyor
- [ ] store_slot capacity / boost_multiplier patch ediliyor
- [ ] warehouse level/capacity patch
- [ ] factory capacity/level/boost patch
- [ ] mine capacity/level/boost patch
- [ ] field/farm level/capacity patch
- [ ] production_slot boost_multiplier patch
- [ ] arge_center level/research capacity patch
- [ ] active upgrade insert/clear
- [ ] active boost insert/clear
- [ ] gold upgrade finish broad invalidates kaldırıldı
- [ ] ad upgrade reduce broad invalidates kaldırıldı
- [ ] boost start/finish broad invalidates kaldırıldı
- [ ] construction gold/ad broad invalidates kaldırıldı
- [ ] player cash/gold/XP local patch
- [ ] targeted fallback korunuyor
- [ ] manual tests tamamlandı

---

# 78. Bu Partide Bilerek Hariç Tutulanlar

Henüz sonraki partilere kalan gruplar:

```text
finance
tax
loan/deposit

ARGE research
brand/patent/marketing

missions
achievements
daily rewards

tender

sell building / sell store

market multiplayer transfer
```

---

# 79. Önerilen Sonraki Parti

Dördüncü parti frontend entegrasyonu kapandıktan sonra önerilen sıra:

```text
5. Parti — Finans + Vergi
```

Özellikle:

```text
take_loan
pay_loan_installment
pay_full_loan
create_deposit
claim_deposit
withdraw_deposit_early
pay_tax_debt
```

Bu grup ağırlıklı olarak:

```text
player.cash
loan/deposit/tax entity state
```

değiştirdiği için production/logistics kadar karmaşık değildir.

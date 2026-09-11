# Production Building Insert Patch Sync — 2026-09-11

Bu değişiklik production building construction completion sonrası frontend state güncellemesini patch-first hale getirir.

## Düzeltilen davranışlar

- `factory` insert patch artık `Şehir / Fabrika / factory.webp` placeholder'ı üretmez.
- `mine` insert patch artık `Şehir / Maden / mine.webp` placeholder'ı üretmez.
- `field` ve `farm` insert patch artık listeyi full-refetch etmek yerine local model ekler.
- `field` ve `farm` için ilk `production_slot` insert patch local list/detail state'e eklenir.
- Şehir, type adı ve ikon static catalog üzerinden enrich edilir; ek network çağrısı gerekmez.
- Static catalog henüz hazır değilse veya metadata bulunamazsa placeholder model basmak yerine targeted list refresh fallback'i kullanılır.
- Provider listesi henüz yüklenmemişse patch boş/tek kayıtlı sahte liste oluşturmaz; normal provider fetch'i authoritative state'i yükler.

## Patch kuralı

Construction completion için beklenen zincir:

`RPC response -> MutationSyncService -> production building insert enrichment -> local provider patch -> UI`

Normal durumda full-list refetch yoktur.

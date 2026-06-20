import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final assetManagerProvider = Provider(
  (ref) => AssetManager(Supabase.instance.client),
);

/// Supabase Storage kontrol sıklığı.
/// Görseller neredeyse hiç değişmediği için günde bir kontrol yeterli.
const _kCheckInterval = Duration(days: 1);

/// metadata.json'daki son kontrol zamanı için anahtar.
const _kLastCheckedKey = '__last_storage_check__';

class AssetManager {
  final SupabaseClient _supabase;

  AssetManager(this._supabase);

  /// Verilen dosya adını (örn: 'factory.png') kontrol eder.
  /// Eğer cihazda varsa lokal yolu, yoksa Supabase'den indirip kaydettikten sonra lokal yolu döndürür.
  /// [forceDownload] true ise lokalde olsa bile dosyayı tekrar indirip günceller.
  Future<File> getAsset(String fileName, {bool forceDownload = false}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final assetsDir = Directory('${directory.path}/game_assets');

      // Klasör yoksa oluştur
      if (!await assetsDir.exists()) {
        await assetsDir.create(recursive: true);
      }

      final file = File('${assetsDir.path}/$fileName');

      // Eğer dosya lokalde varsa ve zorla indirme istenmemişse direkt döndür
      if (!forceDownload && await file.exists()) {
        return file;
      }

      // Dosya yoksa Supabase 'assets' bucket'ından indir
      // download metodu indirdiği dosyanın byte listesini (Uint8List) döndürür
      final bytes = await _supabase.storage.from('assets').download(fileName);

      // Dosyayı lokal sisteme yaz
      await file.writeAsBytes(bytes);

      return file;
    } catch (e) {
      throw Exception('Asset indirme hatası ($fileName): $e');
    }
  }

  /// metadata.json içeriğini okur.
  Future<Map<String, String>> _readMetadata() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final metadataFile = File('${directory.path}/game_assets/metadata.json');
      if (await metadataFile.exists()) {
        final content = await metadataFile.readAsString();
        final Map<String, dynamic> json = jsonDecode(content);
        return json.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (e) {
      // Hata durumunda boş harita dön
    }
    return {};
  }

  /// metadata.json içeriğini yazar.
  Future<void> _writeMetadata(Map<String, String> metadata) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final assetsDir = Directory('${directory.path}/game_assets');
      if (!await assetsDir.exists()) {
        await assetsDir.create(recursive: true);
      }
      final metadataFile = File('${assetsDir.path}/metadata.json');
      await metadataFile.writeAsString(jsonEncode(metadata));
    } catch (e) {
      // Hata yok sayılabilir
    }
  }

  /// Son Supabase Storage kontrolünün üzerinden [_kCheckInterval] geçip geçmediğini döndürür.
  /// Geçmediyse Supabase'e hiç istek atılmaz.
  Future<bool> _shouldCheckRemote(Map<String, String> metadata) async {
    final lastCheckedStr = metadata[_kLastCheckedKey];
    if (lastCheckedStr == null) return true;

    final lastChecked = DateTime.tryParse(lastCheckedStr);
    if (lastChecked == null) return true;

    return DateTime.now().difference(lastChecked) >= _kCheckInterval;
  }

  /// Assets cache'ini tamamen temizler (Gerekirse ayarlar ekranında kullanmak için).
  /// clearCache sonrasında bir sonraki açılışta Storage'dan tekrar indirilir.
  Future<void> clearCache() async {
    final directory = await getApplicationDocumentsDirectory();
    final assetsDir = Directory('${directory.path}/game_assets');

    if (await assetsDir.exists()) {
      await assetsDir.delete(recursive: true);
    }
  }

  /// Tüm varlıkları kontrol eder; gerekirse indirir.
  ///
  /// **Optimizasyon:** Son Supabase Storage kontrolünün üzerinden [_kCheckInterval]
  /// geçmemişse ve tüm yerel dosyalar mevcutsa, Storage'a hiç istek atılmaz.
  /// Bu sayede görseller neredeyse hiç değişmediği senaryoda her açılışta
  /// gereksiz network isteği yapılmaz.
  Future<void> prefetchAssets(
    void Function(int current, int total, String fileName) onProgress,
  ) async {
    try {
      final localMetadata = await _readMetadata();

      // Son kontrolün üzerinden yeterli süre geçmediyse Supabase'e sorma.
      if (!await _shouldCheckRemote(localMetadata)) {
        // Yine de lokal dosyaların varlığını doğrula; eksik varsa tek tek indir.
        final directory = await getApplicationDocumentsDirectory();
        final assetsDir = Directory('${directory.path}/game_assets');
        final knownFiles = localMetadata.keys
            .where((k) => k != _kLastCheckedKey)
            .toList();

        final missingFiles = <String>[];
        for (final fileName in knownFiles) {
          final file = File('${assetsDir.path}/$fileName');
          if (!await file.exists()) {
            missingFiles.add(fileName);
          }
        }

        if (missingFiles.isEmpty) {
          // Her şey yerelde var, Supabase'e gerek yok — direkt bitir.
          onProgress(1, 1, '');
          return;
        }

        // Eksik dosyalar varsa sadece onları indir (Storage list'e gerek yok).
        int total = missingFiles.length;
        int current = 0;
        const int batchSize = 8;
        for (int i = 0; i < total; i += batchSize) {
          final batch = missingFiles.skip(i).take(batchSize).toList();
          await Future.wait(
            batch.map((fileName) async {
              await getAsset(fileName, forceDownload: true);
              current++;
              onProgress(current, total, fileName);
            }),
          );
        }
        return;
      }

      // Yeterli süre geçti: Supabase Storage'ı listele ve güncelleme kontrolü yap.
      final files = await _supabase.storage
          .from('assets')
          .list(searchOptions: const SearchOptions(limit: 1000));

      final validFiles = files
          .where((f) => f.name != '.emptyFolderPlaceholder' && f.name.isNotEmpty)
          .toList();

      bool metadataChanged = false;
      int total = validFiles.length;
      int current = 0;

      const int batchSize = 8;
      for (int i = 0; i < total; i += batchSize) {
        final batch = validFiles.skip(i).take(batchSize).toList();

        await Future.wait(
          batch.map((fileObj) async {
            final fileName = fileObj.name;
            final remoteUpdatedAt = fileObj.updatedAt ?? '';
            final localUpdatedAt = localMetadata[fileName];

            // Lokaldeki tarih sunucudakinden farklıysa güncelle.
            final forceDownload = localUpdatedAt != remoteUpdatedAt;

            await getAsset(fileName, forceDownload: forceDownload);

            if (forceDownload) {
              localMetadata[fileName] = remoteUpdatedAt;
              metadataChanged = true;
            }

            current++;
            onProgress(current, total, fileName);
          }),
        );
      }

      // Son kontrol zamanını güncelle ve metadata'yı kaydet.
      localMetadata[_kLastCheckedKey] = DateTime.now().toIso8601String();
      await _writeMetadata(localMetadata);
    } catch (e) {
      throw Exception('Asset prefetch hatası: $e');
    }
  }
}

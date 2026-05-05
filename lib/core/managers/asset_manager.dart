import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final assetManagerProvider = Provider(
  (ref) => AssetManager(Supabase.instance.client),
);

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

  /// İndirilen dosyaların güncellenme tarihlerini okur
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

  /// İndirilen dosyaların güncellenme tarihlerini kaydeder
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

  /// Assets cache'ini tamamen temizler (Gerekirse ayarlar ekranında kullanmak için)
  Future<void> clearCache() async {
    final directory = await getApplicationDocumentsDirectory();
    final assetsDir = Directory('${directory.path}/game_assets');

    if (await assetsDir.exists()) {
      await assetsDir.delete(recursive: true);
    }
  }

  /// Tüm varlıkları (assets) sırayla kontrol edip indirir.
  /// Splash screen üzerinde yükleme çubuğu göstermek için `onProgress` callback'i kullanır.
  Future<void> prefetchAssets(
    void Function(int current, int total, String fileName) onProgress,
  ) async {
    try {
      // Supabase'den listeleme yapmaya çalış (Varsayılan limit 100 olduğu için 1000'e çıkarıyoruz)
      final files = await _supabase.storage
          .from('assets')
          .list(searchOptions: const SearchOptions(limit: 1000));
          
      final validFiles = files
          .where((f) => f.name != '.emptyFolderPlaceholder' && f.name.isNotEmpty)
          .toList();

      final localMetadata = await _readMetadata();
      bool metadataChanged = false;

      int total = validFiles.length;
      int current = 0;

      // İndirmeleri 5'erli gruplar (batch) halinde eşzamanlı olarak yapıyoruz
      const int batchSize = 8;
      for (int i = 0; i < total; i += batchSize) {
        final batch = validFiles.skip(i).take(batchSize).toList();

        // Bu 5 dosyanın aynı anda inmesini bekle
        await Future.wait(
          batch.map((fileObj) async {
            final fileName = fileObj.name;
            final remoteUpdatedAt = fileObj.updatedAt ?? '';
            final localUpdatedAt = localMetadata[fileName];
            
            // Eğer lokaldeki kayıtlı tarih ile sunucudaki tarih farklıysa güncelleyeceğiz
            bool forceDownload = localUpdatedAt != remoteUpdatedAt;

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

      if (metadataChanged) {
        await _writeMetadata(localMetadata);
      }
    } catch (e) {
      throw Exception('Asset prefetch hatası: $e');
    }
  }
}

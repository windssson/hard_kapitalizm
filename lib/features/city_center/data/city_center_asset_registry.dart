import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:hard_kapitalizm/features/city_center/models/building_type.dart';

/// Şehir Merkezi Görsel Varlık Kayıt Defteri ve Önbelleği (Sprite Cache)
class CityCenterAssetRegistry {
  final Map<String, Sprite> _cache = {};

  /// Önbellekteki tüm sprite'lar
  Map<String, Sprite> get cache => Map.unmodifiable(_cache);

  /// Verilen asset yoluna ait sprite'ı döndürür
  Sprite? getSprite(String? assetPath) {
    if (assetPath == null) return null;
    return _cache[assetPath];
  }

  /// Verilen bina adına ait sprite'ı önbellekten bulur
  Sprite? getBuildingSprite(BuildingType type) {
    if (type.assetPath != null) {
      return _cache[type.assetPath!];
    }
    return type.sprite;
  }

  /// Verilen katalogtaki tüm bina görsellerini önceden yükler (preload)
  Future<void> preloadCatalog(Images images, List<BuildingType> catalog) async {
    images.prefix = 'assets/';

    for (final bType in catalog) {
      final path = bType.assetPath;
      if (path != null && !_cache.containsKey(path)) {
        try {
          final sprite = await Sprite.load(path, images: images);
          _cache[path] = sprite;
          debugPrint('[CityCenterAssetRegistry] Sprite yüklendi: $path (${sprite.srcSize})');
        } catch (e) {
          debugPrint('[CityCenterAssetRegistry] $path yüklenirken hata: $e');
        }
      }
    }
  }

  /// Önbelleği temizler
  void clear() {
    _cache.clear();
  }
}

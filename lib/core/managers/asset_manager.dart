import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final assetManagerProvider = Provider(
  (ref) => AssetManager(Supabase.instance.client),
);

/// Oyundaki tum gorsellerin statik listesi.
/// Bu sayede her acilista Supabase Storage'a "list" istegi atmak yerine
/// sadece eksik olan dosyalari tespit edip indiriyoruz.
const List<String> _kAllAssets = [
  'ae1.webp', 'ae2.webp', 'ae3.webp', 'ak1.webp', 'ak2.webp', 'ak3.webp', 'akolye.webp', 'altin.webp',
  'aluminyum.webp', 'ananas.webp', 'araba.webp', 'arge.webp', 'aricilik.webp', 'arpa.webp', 'asaat.webp',
  'automotive_factory.webp', 'ayakkabi.webp', 'aycicegi.webp', 'aycicekyagi.webp', 'ayna.webp', 'azot.webp',
  'bakery_factory.webp', 'bakir.webp', 'baklava.webp', 'bal.webp', 'balik.webp', 'balik_ciftligi.webp',
  'banka.webp', 'batarya.webp', 'battaniye.webp', 'bavul.webp', 'beton.webp', 'beyaz_esya.webp', 'bezelye.webp',
  'biber.webp', 'bilezik.webp', 'bisiklet.webp', 'biskuvi.webp', 'bitkiyagi.webp', 'boksit.webp', 'borek.webp',
  'boru.webp', 'boya.webp', 'bufe.webp', 'bugday.webp', 'buzdolabi.webp', 'cam.webp', 'camasirmakinasi.webp',
  'canta.webp', 'catim.webp', 'cay.webp', 'ceket.webp', 'celik.webp', 'chemical_factory.webp', 'ciftlikler.webp',
  'cikolata.webp', 'cilek.webp', 'cimento.webp', 'cips.webp', 'civi.webp', 'consol.webp', 'corap.webp',
  'cuzdan.webp', 'danaeti.webp', 'demir.webp', 'depolar.webp', 'deri.webp', 'deterjan.webp', 'devrekarti.webp',
  'dismacunu.webp', 'dolap.webp', 'domates.webp', 'dondurma.webp', 'drone.webp', 'ekmek.webp', 'elbise.webp',
  'electronics_factory.webp', 'elhalisi.webp', 'elma.webp', 'elmasyuzuk.webp', 'endustriyel_tarla.webp',
  'energy_mine.webp', 'esarp.webp', 'fabrikalar.webp', 'fasulye.webp', 'fayans.webp', 'filigran1.webp',
  'filigran10.webp', 'filigran2.webp', 'filigran3.webp', 'filigran4.webp', 'filigran5.webp', 'filigran6.webp',
  'filigran7.webp', 'filigran8.webp', 'filigran9.webp', 'findik.webp', 'findikezmesi.webp', 'firin.webp',
  'food_factory.webp', 'fosfat.webp', 'furniture_factory.webp', 'gazoz.webp', 'geneldepo.webp', 'gomlek.webp',
  'gubre.webp', 'gumus.webp', 'hali.webp', 'havuc.webp', 'heavy_factory.webp', 'heykel.webp', 'hindieti.webp',
  'home_appliances.webp', 'hoparlor.webp', 'ihale.webp', 'insaat_malzemeleri.webp', 'ipek.webp', 'iplik.webp',
  'islemci.webp', 'ispanak.webp', 'jenerator.webp', 'kablo.webp', 'kagit.webp', 'kamera.webp', 'kamyon.webp',
  'karpuz.webp', 'kasap.webp', 'kavun.webp', 'kayisi.webp', 'kemer.webp', 'kereste.webp', 'ketcap.webp',
  'kiraz.webp', 'kitap.webp', 'kitaplik.webp', 'kivi.webp', 'klima.webp', 'koltuk.webp', 'komur.webp',
  'konserve.webp', 'koyuneti.webp', 'kozmetik_magazasi.webp', 'krem.webp', 'krom.webp', 'kucukbas.webp',
  'kulaklik.webp', 'kum.webp', 'kumas.webp', 'kumes.webp', 'kuruyemisci.webp', 'kutu.webp', 'kuvars.webp',
  'kuyumcu.webp', 'lahana.webp', 'laptop.webp', 'lastik.webp', 'limon.webp', 'logo1.webp', 'logo2.webp',
  'logo3.webp', 'logo4.webp', 'logo5.webp', 'lokum.webp', 'losyon.webp', 'luxury_factory.webp', 'madenler.webp',
  'magazalar.webp', 'makarna.webp', 'manav.webp', 'mandira.webp', 'marka.webp', 'market.webp', 'markettest.webp',
  'marul.webp', 'masa.webp', 'mermer.webp', 'metal_mine.webp', 'meyve_bahcesi.webp', 'misir.webp',
  'mobilya_magazasi.webp', 'modem.webp', 'monitor.webp', 'mont.webp', 'motor.webp', 'motosiklet.webp',
  'msuyu.webp', 'mum.webp', 'muz.webp', 'nakliyeler.webp', 'nar.webp', 'oto_galeri.webp', 'paketcay.webp',
  'pamuk.webp', 'panel.webp', 'pantolon.webp', 'parfum.webp', 'pastirma.webp', 'patates.webp', 'pazar.webp',
  'pekmez.webp', 'perde.webp', 'peynir.webp', 'plastik.webp', 'portakal.webp', 'precious_mine.webp',
  'propolis.webp', 'quarry.webp', 'recel.webp', 'ruj.webp', 'saat.webp', 'sabun.webp', 'saksi.webp',
  'salatalik.webp', 'salca.webp', 'saman.webp', 'sampuan.webp', 'sandalye.webp', 'sasi.webp', 'sebze_tarlasi.webp',
  'seftali.webp', 'sehpa.webp', 'seker.webp', 'seramik.webp', 'simit.webp', 'sira.webp', 'sirke.webp',
  'sogan.webp', 'spancari.webp', 'sporcanta.webp', 'sucuk.webp', 'supermarket.webp', 'sut.webp', 'tablet.webp',
  'tahil_tarlasi.webp', 'tahin.webp', 'tarak.webp', 'tarlalar.webp', 'tavuk.webp', 'tekne.webp',
  'teknoloji_supermarket.webp', 'tekstil_magazasi.webp', 'telefon.webp', 'tereyag.webp', 'textile_factory.webp',
  'tisort.webp', 'traktor.webp', 'tugla.webp', 'tursu.webp', 'tv.webp', 'un.webp', 'uzum.webp', 'vazo.webp',
  'vergi.webp', 'vida.webp', 'yakit.webp', 'yastik.webp', 'yatak.webp', 'yazici.webp', 'yogurt.webp',
  'yumurta.webp', 'yun.webp', 'yuzuk.webp', 'zeytin.webp', 'zyagi.webp'
];

class AssetManager {
  final SupabaseClient _supabase;

  String? _assetsDirPath;
  final Map<String, File> _fileCache = {};
  final Map<String, Future<File>> _inFlightDownloads = {};

  AssetManager(this._supabase);

  Future<String> _getAssetsDirPath() async {
    if (_assetsDirPath != null) return _assetsDirPath!;
    final directory = await getApplicationDocumentsDirectory();
    _assetsDirPath = '${directory.path}/game_assets';
    return _assetsDirPath!;
  }

  Future<File> getAsset(String fileName, {bool forceDownload = false}) async {
    try {
      if (!forceDownload && _fileCache.containsKey(fileName)) {
        return _fileCache[fileName]!;
      }

      if (!forceDownload && _inFlightDownloads.containsKey(fileName)) {
        return _inFlightDownloads[fileName]!;
      }

      Future<File> loadAsset() async {
        final assetsPath = await _getAssetsDirPath();
        final file = File('$assetsPath/$fileName');

        if (!forceDownload && await file.exists()) {
          _fileCache[fileName] = file;
          return file;
        }

        final assetsDir = Directory(assetsPath);
        if (!await assetsDir.exists()) {
          await assetsDir.create(recursive: true);
        }

        final bytes = await _supabase.storage.from('assets').download(fileName);
        await file.writeAsBytes(bytes);

        _fileCache[fileName] = file;
        return file;
      }

      final future = loadAsset();
      if (!forceDownload) {
        _inFlightDownloads[fileName] = future;
      }

      try {
        return await future;
      } finally {
        if (!forceDownload) {
          _inFlightDownloads.remove(fileName);
        }
      }
    } catch (e) {
      throw Exception('Asset indirme hatasi ($fileName): $e');
    }
  }

  Future<void> prefetchAssetList(Iterable<String> fileNames) async {
    final uniqueNames = fileNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (uniqueNames.isEmpty) return;

    const batchSize = 8;
    for (int i = 0; i < uniqueNames.length; i += batchSize) {
      final batch = uniqueNames.skip(i).take(batchSize);
      await Future.wait(batch.map(getAsset));
    }
  }

  Future<void> clearCache() async {
    final assetsPath = await _getAssetsDirPath();
    final assetsDir = Directory(assetsPath);

    if (await assetsDir.exists()) {
      await assetsDir.delete(recursive: true);
    }
    _fileCache.clear();
    _inFlightDownloads.clear();
  }

  /// Ana ekran ve temel arayüz için anında gerekli kritik görseller
  static const List<String> criticalAssets = [
    'ae1.webp', 'ae2.webp', 'ae3.webp', 'ak1.webp', 'ak2.webp', 'ak3.webp',
    'magazalar.webp', 'depolar.webp', 'fabrikalar.webp', 'tarlalar.webp',
    'ciftlikler.webp', 'madenler.webp', 'nakliyeler.webp', 'arge.webp',
    'ihale.webp', 'banka.webp', 'vergi.webp', 'marka.webp', 'market.webp',
    'geneldepo.webp', 'altin.webp',
  ];

  /// Açılışta sadece anasayfa için elzem olan ~20 temel görseli hızlıca önbelleğe alır
  Future<void> prefetchCriticalAssets({
    void Function(int current, int total, String fileName)? onProgress,
  }) async {
    try {
      final assetsPath = await _getAssetsDirPath();
      final assetsDir = Directory(assetsPath);
      if (!await assetsDir.exists()) {
        await assetsDir.create(recursive: true);
      }

      final missing = <String>[];
      for (final fileName in criticalAssets) {
        final file = File('$assetsPath/$fileName');
        if (await file.exists()) {
          _fileCache[fileName] = file;
        } else {
          missing.add(fileName);
        }
      }

      if (missing.isEmpty) {
        onProgress?.call(criticalAssets.length, criticalAssets.length, '');
        return;
      }

      int total = missing.length;
      int current = 0;
      await Future.wait(
        missing.map((fileName) async {
          final file = await getAsset(fileName, forceDownload: true);
          _fileCache[fileName] = file;
          current++;
          onProgress?.call(current, total, fileName);
        }),
      );
    } catch (_) {
      // Kritik asset indirme hatası ana akışı engellemesin
    }
  }

  /// Kalan tüm ürün ve katalog görsellerini oyuncu ana ekrandayken sessizce arka planda indirir
  void prefetchRemainingAssetsInBackground() {
    Future.microtask(() async {
      try {
        final assetsPath = await _getAssetsDirPath();
        final remaining = _kAllAssets.where((f) => !criticalAssets.contains(f)).toList();
        
        final missing = <String>[];
        for (final fileName in remaining) {
          final file = File('$assetsPath/$fileName');
          if (await file.exists()) {
            _fileCache[fileName] = file;
          } else {
            missing.add(fileName);
          }
        }

        const batchSize = 10;
        for (int i = 0; i < missing.length; i += batchSize) {
          final batch = missing.skip(i).take(batchSize).toList();
          await Future.wait(
            batch.map((fileName) async {
              final file = await getAsset(fileName, forceDownload: true);
              _fileCache[fileName] = file;
            }),
          );
          // UI ve cihazı yormamak için batch aralarında kısa nefes
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      } catch (_) {}
    });
  }

  Future<void> prefetchAssets(
    void Function(int current, int total, String fileName) onProgress,
  ) async {
    try {
      final assetsPath = await _getAssetsDirPath();
      final assetsDir = Directory(assetsPath);

      if (!await assetsDir.exists()) {
        await assetsDir.create(recursive: true);
      }

      final missingFiles = <String>[];
      for (final fileName in _kAllAssets) {
        final file = File('$assetsPath/$fileName');
        if (await file.exists()) {
          _fileCache[fileName] = file;
        } else {
          missingFiles.add(fileName);
        }
      }

      if (missingFiles.isEmpty) {
        onProgress(1, 1, '');
        return;
      }

      int total = missingFiles.length;
      int current = 0;
      const int batchSize = 8;
      for (int i = 0; i < total; i += batchSize) {
        final batch = missingFiles.skip(i).take(batchSize).toList();
        await Future.wait(
          batch.map((fileName) async {
            final file = await getAsset(fileName, forceDownload: true);
            _fileCache[fileName] = file;
            current++;
            onProgress(current, total, fileName);
          }),
        );
      }
    } catch (e) {
      throw Exception('Asset prefetch hatasi: $e');
    }
  }
}

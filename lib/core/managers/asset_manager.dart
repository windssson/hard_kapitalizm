import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final assetManagerProvider = Provider(
  (ref) => AssetManager(Supabase.instance.client),
);

/// Oyundaki tüm görsellerin statik listesi.
/// Bu sayede her açılışta Supabase Storage'a "list" isteği atmak yerine
/// sadece eksik olan dosyaları tespit edip indiriyoruz.
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

  // Bellek içi önbellekleme
  String? _assetsDirPath;
  final Map<String, File> _fileCache = {};

  AssetManager(this._supabase);

  /// game_assets klasör yolunu bir kez çözümler ve önbelleğe alır.
  Future<String> _getAssetsDirPath() async {
    if (_assetsDirPath != null) return _assetsDirPath!;
    final directory = await getApplicationDocumentsDirectory();
    _assetsDirPath = '${directory.path}/game_assets';
    return _assetsDirPath!;
  }

  /// Verilen dosya adını kontrol eder.
  /// Eğer cihazda varsa lokal yolu, yoksa Supabase'den indirip kaydettikten sonra lokal yolu döndürür.
  Future<File> getAsset(String fileName, {bool forceDownload = false}) async {
    try {
      if (!forceDownload && _fileCache.containsKey(fileName)) {
        return _fileCache[fileName]!;
      }

      final assetsPath = await _getAssetsDirPath();
      final file = File('$assetsPath/$fileName');

      // Eğer dosya lokalde varsa ve zorla indirme istenmemişse direkt döndür
      if (!forceDownload && await file.exists()) {
        _fileCache[fileName] = file;
        return file;
      }

      // Klasör yoksa oluştur
      final assetsDir = Directory(assetsPath);
      if (!await assetsDir.exists()) {
        await assetsDir.create(recursive: true);
      }

      // Dosya yoksa Supabase 'assets' bucket'ından indir
      final bytes = await _supabase.storage.from('assets').download(fileName);

      // Dosyayı lokal sisteme yaz
      await file.writeAsBytes(bytes);

      _fileCache[fileName] = file;
      return file;
    } catch (e) {
      throw Exception('Asset indirme hatası ($fileName): $e');
    }
  }

  /// Assets cache'ini tamamen temizler.
  Future<void> clearCache() async {
    final assetsPath = await _getAssetsDirPath();
    final assetsDir = Directory(assetsPath);

    if (await assetsDir.exists()) {
      await assetsDir.delete(recursive: true);
    }
    _fileCache.clear();
  }

  /// Tüm statik varlıkları yerelde kontrol eder; eksik varsa indirir.
  /// Artık her seferinde Supabase listleme çağrısı yapılmadığından anında çalışır.
  Future<void> prefetchAssets(
    void Function(int current, int total, String fileName) onProgress,
  ) async {
    try {
      final assetsPath = await _getAssetsDirPath();
      final assetsDir = Directory(assetsPath);

      // Klasör yoksa oluştur
      if (!await assetsDir.exists()) {
        await assetsDir.create(recursive: true);
      }

      final missingFiles = <String>[];
      for (final fileName in _kAllAssets) {
        final file = File('$assetsPath/$fileName');
        if (await file.exists()) {
          _fileCache[fileName] = file; // Zaten mevcut olanları bellek cache'ine al
        } else {
          missingFiles.add(fileName);
        }
      }

      if (missingFiles.isEmpty) {
        // Her şey yerelde var, indirmeye gerek yok — direkt bitir.
        onProgress(1, 1, '');
        return;
      }

      // Eksik dosyaları indir (Paralel 8'li gruplar halinde)
      int total = missingFiles.length;
      int current = 0;
      const int batchSize = 8;
      for (int i = 0; i < total; i += batchSize) {
        final batch = missingFiles.skip(i).take(batchSize).toList();
        await Future.wait(
          batch.map((fileName) async {
            final file = await getAsset(fileName, forceDownload: true);
            _fileCache[fileName] = file; // Bellek cache'ine al
            current++;
            onProgress(current, total, fileName);
          }),
        );
      }
    } catch (e) {
      throw Exception('Asset prefetch hatası: $e');
    }
  }
}

class ProductModel {
  final String id;
  final String urunAdi;
  final String urunIconu;
  final double birimHacim;
  final double birimAgirlik;
  final String? hammadde1Id;
  final double? hammadde1Miktar;
  final String? hammadde2Id;
  final double? hammadde2Miktar;
  final String? hammadde3Id;
  final double? hammadde3Miktar;
  final String? uretimBirimi;
  final double bazSatisFiyati;
  final int uretimAdedi;
  final int satisAdedi;
  final double enDusukFiyat;
  final double enYuksekFiyat;
  final double ortalamaFiyat;
  final int saticiSayisi;
  final int piyasadakiStok;
  final double iscilikMaliyeti;
  final DateTime createdAt;

  ProductModel({
    required this.id,
    required this.urunAdi,
    required this.urunIconu,
    required this.birimHacim,
    required this.birimAgirlik,
    this.hammadde1Id,
    this.hammadde1Miktar,
    this.hammadde2Id,
    this.hammadde2Miktar,
    this.hammadde3Id,
    this.hammadde3Miktar,
    this.uretimBirimi,
    required this.bazSatisFiyati,
    required this.uretimAdedi,
    required this.satisAdedi,
    required this.enDusukFiyat,
    required this.enYuksekFiyat,
    required this.ortalamaFiyat,
    required this.saticiSayisi,
    required this.piyasadakiStok,
    this.iscilikMaliyeti = 0.0,
    required this.createdAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: (json['id'] ?? '').toString(),
      urunAdi: (json['urun_adi'] ?? '').toString(),
      urunIconu: (json['urun_iconu'] ?? '').toString(),
      birimHacim: (json['birim_hacim'] as num?)?.toDouble() ?? 0.0,
      birimAgirlik: (json['birim_agirlik'] as num?)?.toDouble() ?? 0.0,
      hammadde1Id: json['hammadde_1_id'] as String?,
      hammadde1Miktar: (json['hammadde_1_miktar'] as num?)?.toDouble(),
      hammadde2Id: json['hammadde_2_id'] as String?,
      hammadde2Miktar: (json['hammadde_2_miktar'] as num?)?.toDouble(),
      hammadde3Id: json['hammadde_3_id'] as String?,
      hammadde3Miktar: (json['hammadde_3_miktar'] as num?)?.toDouble(),
      uretimBirimi: json['uretim_birimi'] as String?,
      bazSatisFiyati: (json['baz_satis_fiyati'] as num?)?.toDouble() ?? 0.0,
      uretimAdedi: json['uretim_adedi'] as int? ?? 0,
      satisAdedi: json['satis_adedi'] as int? ?? 0,
      enDusukFiyat: (json['en_dusuk_fiyat'] as num?)?.toDouble() ?? 0.0,
      enYuksekFiyat: (json['en_yuksek_fiyat'] as num?)?.toDouble() ?? 0.0,
      ortalamaFiyat: (json['ortalama_fiyat'] as num?)?.toDouble() ?? 0.0,
      saticiSayisi: json['satici_sayisi'] as int? ?? 0,
      piyasadakiStok: json['piyasadaki_stok'] as int? ?? 0,
      iscilikMaliyeti: (json['iscilik_maliyeti'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'urun_adi': urunAdi,
      'urun_iconu': urunIconu,
      'birim_hacim': birimHacim,
      'birim_agirlik': birimAgirlik,
      'hammadde_1_id': hammadde1Id,
      'hammadde_1_miktar': hammadde1Miktar,
      'hammadde_2_id': hammadde2Id,
      'hammadde_2_miktar': hammadde2Miktar,
      'hammadde_3_id': hammadde3Id,
      'hammadde_3_miktar': hammadde3Miktar,
      'uretim_birimi': uretimBirimi,
      'baz_satis_fiyati': bazSatisFiyati,
      'uretim_adedi': uretimAdedi,
      'satis_adedi': satisAdedi,
      'en_dusuk_fiyat': enDusukFiyat,
      'en_yuksek_fiyat': enYuksekFiyat,
      'ortalama_fiyat': ortalamaFiyat,
      'satici_sayisi': saticiSayisi,
      'piyasadaki_stok': piyasadakiStok,
      'iscilik_maliyeti': iscilikMaliyeti,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Set<String> get inputProductIds => {
    if ((hammadde1Id ?? '').isNotEmpty) hammadde1Id!,
    if ((hammadde2Id ?? '').isNotEmpty) hammadde2Id!,
    if ((hammadde3Id ?? '').isNotEmpty) hammadde3Id!,
  };
}

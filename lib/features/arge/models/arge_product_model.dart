class ArgeProductModel {
  final String id;
  final String urunAdi;
  final String urunIconu;
  final double bazSatisFiyati;
  final String uretimBirimi;
  final int currentQualityLevel;
  final bool isProduced;
  final String? hammadde1Id;
  final String? hammadde2Id;
  final String? hammadde3Id;

  const ArgeProductModel({
    required this.id,
    required this.urunAdi,
    required this.urunIconu,
    required this.bazSatisFiyati,
    required this.uretimBirimi,
    required this.currentQualityLevel,
    required this.isProduced,
    this.hammadde1Id,
    this.hammadde2Id,
    this.hammadde3Id,
  });

  factory ArgeProductModel.fromJson(
    Map<String, dynamic> product,
    int qualityLevel,
  ) {
    return ArgeProductModel(
      id: product['id']?.toString() ?? '',
      urunAdi: product['urun_adi']?.toString() ?? '',
      urunIconu: product['urun_iconu']?.toString() ?? 'default.webp',
      bazSatisFiyati:
          double.tryParse(product['baz_satis_fiyati']?.toString() ?? '0') ?? 0,
      uretimBirimi: product['uretim_birimi']?.toString() ?? 'FABRIKA',
      currentQualityLevel: qualityLevel,
      isProduced: product['is_produced'] == true,
      hammadde1Id: product['hammadde_1_id']?.toString(),
      hammadde2Id: product['hammadde_2_id']?.toString(),
      hammadde3Id: product['hammadde_3_id']?.toString(),
    );
  }

  ArgeProductModel copyWith({
    String? id,
    String? urunAdi,
    String? urunIconu,
    double? bazSatisFiyati,
    String? uretimBirimi,
    int? currentQualityLevel,
    bool? isProduced,
    String? hammadde1Id,
    String? hammadde2Id,
    String? hammadde3Id,
  }) {
    return ArgeProductModel(
      id: id ?? this.id,
      urunAdi: urunAdi ?? this.urunAdi,
      urunIconu: urunIconu ?? this.urunIconu,
      bazSatisFiyati: bazSatisFiyati ?? this.bazSatisFiyati,
      uretimBirimi: uretimBirimi ?? this.uretimBirimi,
      currentQualityLevel: currentQualityLevel ?? this.currentQualityLevel,
      isProduced: isProduced ?? this.isProduced,
      hammadde1Id: hammadde1Id ?? this.hammadde1Id,
      hammadde2Id: hammadde2Id ?? this.hammadde2Id,
      hammadde3Id: hammadde3Id ?? this.hammadde3Id,
    );
  }

  static const int maxQualityLevel = 5;

  int get targetQuality => currentQualityLevel + 1;

  bool get isMaxQuality => currentQualityLevel >= maxQualityLevel;

  int get requiredPlayerLevel {
    if (isMaxQuality) return 0;
    return switch (targetQuality) {
      2 => 5,
      3 => 15,
      4 => 30,
      5 => 45,
      _ => 50,
    };
  }

  static const List<int> _multipliers = [0, 10, 25, 60, 150];
  static const List<double> _minimumCosts = [0, 2500, 15000, 75000, 300000];

  double get upgradeCost {
    if (isMaxQuality) return 0;
    final scaled = bazSatisFiyati * _multipliers[currentQualityLevel];
    final floor = _minimumCosts[currentQualityLevel];
    return scaled < floor ? floor : scaled;
  }

  static const List<int> _durationHours = [0, 2, 5, 10, 24];

  int get upgradeDurationHours {
    if (isMaxQuality) return 0;
    return _durationHours[currentQualityLevel];
  }

  bool canUpgrade({
    required int playerLevel,
    required double playerCash,
    required List<ArgeProductModel> allProducts,
  }) {
    if (isMaxQuality) return false;
    return playerLevel >= requiredPlayerLevel &&
        playerCash >= upgradeCost &&
        meetsRawMaterialQualityRequirements(allProducts);
  }

  bool meetsRawMaterialQualityRequirements(List<ArgeProductModel> allProducts) {
    if (isMaxQuality) return true;
    final reqQuality = targetQuality - 1;

    // Check hammadde 1
    if (hammadde1Id != null && hammadde1Id!.isNotEmpty) {
      final rm = allProducts.firstWhere(
        (p) => p.id == hammadde1Id,
        orElse: () => const ArgeProductModel(
          id: '',
          urunAdi: '',
          urunIconu: '',
          bazSatisFiyati: 0,
          uretimBirimi: '',
          currentQualityLevel: 1,
          isProduced: false,
        ),
      );
      if (rm.id.isNotEmpty && rm.currentQualityLevel < reqQuality) {
        return false;
      }
    }

    // Check hammadde 2
    if (hammadde2Id != null && hammadde2Id!.isNotEmpty) {
      final rm = allProducts.firstWhere(
        (p) => p.id == hammadde2Id,
        orElse: () => const ArgeProductModel(
          id: '',
          urunAdi: '',
          urunIconu: '',
          bazSatisFiyati: 0,
          uretimBirimi: '',
          currentQualityLevel: 1,
          isProduced: false,
        ),
      );
      if (rm.id.isNotEmpty && rm.currentQualityLevel < reqQuality) {
        return false;
      }
    }

    // Check hammadde 3
    if (hammadde3Id != null && hammadde3Id!.isNotEmpty) {
      final rm = allProducts.firstWhere(
        (p) => p.id == hammadde3Id,
        orElse: () => const ArgeProductModel(
          id: '',
          urunAdi: '',
          urunIconu: '',
          bazSatisFiyati: 0,
          uretimBirimi: '',
          currentQualityLevel: 1,
          isProduced: false,
        ),
      );
      if (rm.id.isNotEmpty && rm.currentQualityLevel < reqQuality) {
        return false;
      }
    }

    return true;
  }

  List<({String name, int current, int required})> getUnmetRawMaterials(
    List<ArgeProductModel> allProducts,
  ) {
    if (isMaxQuality) return [];
    final reqQuality = targetQuality - 1;
    final List<({String name, int current, int required})> unmet = [];

    void check(String? rmId) {
      if (rmId != null && rmId.isNotEmpty) {
        final rm = allProducts.firstWhere(
          (p) => p.id == rmId,
          orElse: () => const ArgeProductModel(
            id: '',
            urunAdi: '',
            urunIconu: '',
            bazSatisFiyati: 0,
            uretimBirimi: '',
            currentQualityLevel: 1,
            isProduced: false,
          ),
        );
        if (rm.id.isNotEmpty) {
          if (rm.currentQualityLevel < reqQuality) {
            unmet.add((
              name: rm.urunAdi,
              current: rm.currentQualityLevel,
              required: reqQuality,
            ));
          }
        }
      }
    }

    check(hammadde1Id);
    check(hammadde2Id);
    check(hammadde3Id);

    return unmet;
  }

  bool hasLevelRequirement({required int playerLevel}) {
    if (isMaxQuality) return true;
    return playerLevel >= requiredPlayerLevel;
  }

  bool hasCashRequirement({required double playerCash}) {
    if (isMaxQuality) return true;
    return playerCash >= upgradeCost;
  }
}

class ArgeResearchModel {
  final String id;
  final String playerId;
  final String productId;
  final String productName;
  final int currentQuality;
  final int targetQuality;
  final double costPaid;
  final String status;
  final DateTime startedAt;
  final DateTime finishAt;
  final DateTime? completedAt;

  const ArgeResearchModel({
    required this.id,
    required this.playerId,
    required this.productId,
    required this.productName,
    required this.currentQuality,
    required this.targetQuality,
    required this.costPaid,
    required this.status,
    required this.startedAt,
    required this.finishAt,
    this.completedAt,
  });

  factory ArgeResearchModel.fromJson(Map<String, dynamic> json) {
    return ArgeResearchModel(
      id: json['id']?.toString() ?? '',
      playerId: json['player_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      currentQuality: (json['current_quality'] as num?)?.toInt() ?? 1,
      targetQuality: (json['target_quality'] as num?)?.toInt() ?? 2,
      costPaid: double.tryParse(json['cost_paid']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'in_progress',
      startedAt: DateTime.parse(
        json['started_at']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      finishAt: DateTime.parse(
        json['finish_at']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
    );
  }

  bool get isInProgress => status == 'in_progress';

  bool get isDone => finishAt.isBefore(DateTime.now().toUtc());

  Duration get remaining {
    final diff = finishAt.toLocal().difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  int get goldCostToFinish {
    final mins = remaining.inMinutes;
    if (mins <= 0) return 0;
    return ((mins / 30).ceil()).clamp(1, 999999);
  }

  ArgeResearchModel copyWith({
    String? id,
    String? playerId,
    String? productId,
    String? productName,
    int? currentQuality,
    int? targetQuality,
    double? costPaid,
    String? status,
    DateTime? startedAt,
    DateTime? finishAt,
    DateTime? completedAt,
  }) {
    return ArgeResearchModel(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      currentQuality: currentQuality ?? this.currentQuality,
      targetQuality: targetQuality ?? this.targetQuality,
      costPaid: costPaid ?? this.costPaid,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      finishAt: finishAt ?? this.finishAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

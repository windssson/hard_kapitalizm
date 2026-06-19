class ArgeProductModel {
  final String id;
  final String urunAdi;
  final String urunIconu;
  final double bazSatisFiyati;
  final String uretimBirimi;
  final int currentQualityLevel;
  final bool isProduced;

  const ArgeProductModel({
    required this.id,
    required this.urunAdi,
    required this.urunIconu,
    required this.bazSatisFiyati,
    required this.uretimBirimi,
    required this.currentQualityLevel,
    required this.isProduced,
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
    );
  }

  static const int maxQualityLevel = 5;

  int get targetQuality => currentQualityLevel + 1;

  bool get isMaxQuality => currentQualityLevel >= maxQualityLevel;

  int get requiredPlayerLevel => isMaxQuality ? 0 : targetQuality * 10;

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

  bool canUpgrade({required int playerLevel, required double playerCash}) {
    if (isMaxQuality) return false;
    return playerLevel >= requiredPlayerLevel && playerCash >= upgradeCost;
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
}

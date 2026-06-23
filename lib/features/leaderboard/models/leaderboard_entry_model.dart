class LeaderboardEntryModel {
  final String playerId;
  final String playerName;
  final String companyName;
  final String avatarId;
  final int level;
  final int experience;
  final double cash;
  final double gold;
  final double companyValue;
  final double businessValue;
  final double inventoryValue;
  final double vehicleValue;
  final double buildingBaseValue;
  final double buildingUpgradeValue;
  final double warehouseInventoryValue;
  final double storeInventoryValue;
  final double productionInventoryValue;
  final int achievementUnlockedCount;
  final int achievementTotalCount;

  const LeaderboardEntryModel({
    required this.playerId,
    required this.playerName,
    required this.companyName,
    required this.avatarId,
    required this.level,
    required this.experience,
    required this.cash,
    required this.gold,
    required this.companyValue,
    required this.businessValue,
    required this.inventoryValue,
    required this.vehicleValue,
    required this.buildingBaseValue,
    required this.buildingUpgradeValue,
    required this.warehouseInventoryValue,
    required this.storeInventoryValue,
    required this.productionInventoryValue,
    required this.achievementUnlockedCount,
    required this.achievementTotalCount,
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      playerId: json['player_id'] as String? ?? '',
      playerName: json['player_name'] as String? ?? 'Oyuncu',
      companyName: json['company_name'] as String? ?? 'Yeni Holding',
      avatarId: json['avatar_id'] as String? ?? 'avatar_1.webp',
      level: json['level'] as int? ?? 1,
      experience: json['experience'] as int? ?? 0,
      cash: double.tryParse(json['cash']?.toString() ?? '0') ?? 0.0,
      gold: double.tryParse(json['gold']?.toString() ?? '0') ?? 0.0,
      companyValue: double.tryParse(json['company_value']?.toString() ?? '0') ?? 0.0,
      businessValue: double.tryParse(json['business_value']?.toString() ?? '0') ?? 0.0,
      inventoryValue: double.tryParse(json['inventory_value']?.toString() ?? '0') ?? 0.0,
      vehicleValue: double.tryParse(json['vehicle_value']?.toString() ?? '0') ?? 0.0,
      buildingBaseValue: double.tryParse(json['building_base_value']?.toString() ?? '0') ?? 0.0,
      buildingUpgradeValue: double.tryParse(json['building_upgrade_value']?.toString() ?? '0') ?? 0.0,
      warehouseInventoryValue: double.tryParse(json['warehouse_inventory_value']?.toString() ?? '0') ?? 0.0,
      storeInventoryValue: double.tryParse(json['store_inventory_value']?.toString() ?? '0') ?? 0.0,
      productionInventoryValue: double.tryParse(json['production_inventory_value']?.toString() ?? '0') ?? 0.0,
      achievementUnlockedCount: json['achievement_unlocked_count'] as int? ?? 0,
      achievementTotalCount: json['achievement_total_count'] as int? ?? 0,
    );
  }
}

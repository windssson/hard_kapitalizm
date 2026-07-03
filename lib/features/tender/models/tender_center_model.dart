class TenderCenterModel {
  final bool success;
  final List<TenderListItemModel> openTenders;
  final List<PlayerTenderSummaryModel> myActiveTenders;
  final List<TenderBidSummaryModel> myBidTenders;
  final List<PlayerTenderSummaryModel> myRecentTenders;
  final int deliveryCount;
  final DateTime? serverTime;

  const TenderCenterModel({
    required this.success,
    required this.openTenders,
    required this.myActiveTenders,
    required this.myBidTenders,
    required this.myRecentTenders,
    required this.deliveryCount,
    required this.serverTime,
  });

  factory TenderCenterModel.fromJson(Map<String, dynamic> json) {
    return TenderCenterModel(
      success: json['success'] as bool? ?? false,
      openTenders: _asList(json['open_tenders'])
          .whereType<Map>()
          .map((item) => TenderListItemModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      myActiveTenders: _asList(json['my_active_tenders'])
          .whereType<Map>()
          .map(
            (item) => PlayerTenderSummaryModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      myBidTenders: _asList(json['my_bid_tenders'])
          .whereType<Map>()
          .map(
            (item) => TenderBidSummaryModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      myRecentTenders: _asList(json['my_recent_tenders'])
          .whereType<Map>()
          .map(
            (item) => PlayerTenderSummaryModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      deliveryCount: (json['delivery_count'] as num?)?.toInt() ?? 0,
      serverTime: DateTime.tryParse((json['server_time'] ?? '').toString()),
    );
  }

  static List<dynamic> _asList(dynamic value) {
    if (value is List<dynamic>) return value;
    if (value is List) return List<dynamic>.from(value);
    return const <dynamic>[];
  }
}

class TenderListItemModel {
  final String tenderId;
  final String title;
  final String cityId;
  final String cityName;
  final String productId;
  final String productName;
  final String productIcon;
  final int qualityLevel;
  final int requiredQuantity;
  final double rewardCash;
  final double bondAmount;
  final String awardType;
  final int bidCount;
  final double? lowestBidAmount;
  final bool hasPlayerBid;
  final double? playerBidAmount;
  final DateTime? acceptUntil;
  final int deliveryDurationMinutes;
  final String status;
  final int minPlayerLevel;

  const TenderListItemModel({
    required this.tenderId,
    required this.title,
    required this.cityId,
    required this.cityName,
    required this.productId,
    required this.productName,
    required this.productIcon,
    required this.qualityLevel,
    required this.requiredQuantity,
    required this.rewardCash,
    required this.bondAmount,
    required this.awardType,
    required this.bidCount,
    required this.lowestBidAmount,
    required this.hasPlayerBid,
    required this.playerBidAmount,
    required this.acceptUntil,
    required this.deliveryDurationMinutes,
    required this.status,
    required this.minPlayerLevel,
  });

  factory TenderListItemModel.fromJson(Map<String, dynamic> json) {
    return TenderListItemModel(
      tenderId: (json['tender_id'] ?? '').toString(),
      title: (json['title'] ?? 'Ihale').toString(),
      cityId: (json['city_id'] ?? '').toString(),
      cityName: (json['city_name'] ?? '-').toString(),
      productId: (json['product_id'] ?? '').toString(),
      productName: (json['product_name'] ?? '-').toString(),
      productIcon: (json['product_icon'] ?? '').toString(),
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 1,
      requiredQuantity: (json['required_quantity'] as num?)?.toInt() ?? 0,
      rewardCash: (json['reward_cash'] as num?)?.toDouble() ?? 0,
      bondAmount: (json['bond_amount'] as num?)?.toDouble() ?? 0,
      awardType: (json['award_type'] ?? 'lowest_bid').toString(),
      bidCount: (json['bid_count'] as num?)?.toInt() ?? 0,
      lowestBidAmount: (json['lowest_bid_amount'] as num?)?.toDouble(),
      hasPlayerBid: json['has_player_bid'] as bool? ?? false,
      playerBidAmount: (json['player_bid_amount'] as num?)?.toDouble(),
      acceptUntil: DateTime.tryParse((json['accept_until'] ?? '').toString()),
      deliveryDurationMinutes:
          (json['delivery_duration_minutes'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'open').toString(),
      minPlayerLevel: (json['min_player_level'] as num?)?.toInt() ?? 1,
    );
  }
}

class TenderBidSummaryModel {
  final String tenderId;
  final String title;
  final String cityName;
  final String productName;
  final String productIcon;
  final int qualityLevel;
  final String awardType;
  final double bidAmount;
  final double bondPaid;
  final int bidCount;
  final double? lowestBidAmount;
  final DateTime? acceptUntil;
  final String status;

  const TenderBidSummaryModel({
    required this.tenderId,
    required this.title,
    required this.cityName,
    required this.productName,
    required this.productIcon,
    required this.qualityLevel,
    required this.awardType,
    required this.bidAmount,
    required this.bondPaid,
    required this.bidCount,
    required this.lowestBidAmount,
    required this.acceptUntil,
    required this.status,
  });

  factory TenderBidSummaryModel.fromJson(Map<String, dynamic> json) {
    return TenderBidSummaryModel(
      tenderId: (json['tender_id'] ?? '').toString(),
      title: (json['title'] ?? 'Ihale').toString(),
      cityName: (json['city_name'] ?? '-').toString(),
      productName: (json['product_name'] ?? '-').toString(),
      productIcon: (json['product_icon'] ?? '').toString(),
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 1,
      awardType: (json['award_type'] ?? 'lowest_bid').toString(),
      bidAmount: (json['bid_amount'] as num?)?.toDouble() ?? 0,
      bondPaid: (json['bond_paid'] as num?)?.toDouble() ?? 0,
      bidCount: (json['bid_count'] as num?)?.toInt() ?? 0,
      lowestBidAmount: (json['lowest_bid_amount'] as num?)?.toDouble(),
      acceptUntil: DateTime.tryParse((json['accept_until'] ?? '').toString()),
      status: (json['status'] ?? 'active').toString(),
    );
  }
}

class PlayerTenderSummaryModel {
  final String playerTenderId;
  final String tenderId;
  final String title;
  final String cityName;
  final String productId;
  final String productName;
  final String productIcon;
  final int qualityLevel;
  final int requiredQuantity;
  final int deliveredQuantity;
  final int remainingQuantity;
  final double rewardCash;
  final double bondPaid;
  final DateTime? deadlineAt;
  final DateTime? completedAt;
  final DateTime? failedAt;
  final String status;

  const PlayerTenderSummaryModel({
    required this.playerTenderId,
    required this.tenderId,
    required this.title,
    required this.cityName,
    required this.productId,
    required this.productName,
    required this.productIcon,
    required this.qualityLevel,
    required this.requiredQuantity,
    required this.deliveredQuantity,
    required this.remainingQuantity,
    required this.rewardCash,
    required this.bondPaid,
    required this.deadlineAt,
    required this.completedAt,
    required this.failedAt,
    required this.status,
  });

  factory PlayerTenderSummaryModel.fromJson(Map<String, dynamic> json) {
    return PlayerTenderSummaryModel(
      playerTenderId: (json['player_tender_id'] ?? '').toString(),
      tenderId: (json['tender_id'] ?? '').toString(),
      title: (json['title'] ?? 'Ihale').toString(),
      cityName: (json['city_name'] ?? '-').toString(),
      productId: (json['product_id'] ?? '').toString(),
      productName: (json['product_name'] ?? '-').toString(),
      productIcon: (json['product_icon'] ?? '').toString(),
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 1,
      requiredQuantity: (json['required_quantity'] as num?)?.toInt() ?? 0,
      deliveredQuantity: (json['delivered_quantity'] as num?)?.toInt() ?? 0,
      remainingQuantity: (json['remaining_quantity'] as num?)?.toInt() ?? 0,
      rewardCash: (json['reward_cash'] as num?)?.toDouble() ?? 0,
      bondPaid: (json['bond_paid'] as num?)?.toDouble() ?? 0,
      deadlineAt: DateTime.tryParse((json['deadline_at'] ?? '').toString()),
      completedAt: DateTime.tryParse((json['completed_at'] ?? '').toString()),
      failedAt: DateTime.tryParse((json['failed_at'] ?? '').toString()),
      status: (json['status'] ?? 'active').toString(),
    );
  }
}

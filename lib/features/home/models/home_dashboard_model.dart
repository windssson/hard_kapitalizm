import 'package:hard_kapitalizm/features/notification/models/player_notification_model.dart';

class HomeDashboardModel {
  final bool success;
  final HomePlayerSummary player;
  final HomeCompanySummary company;
  final HomeFinanceToday financeToday;
  final HomeModulesSummary modules;
  final HomeHourlyIncomeEstimate hourlyIncomeEstimate;
  final List<HomeOngoingActivity> ongoingActivities;
  final List<PlayerNotificationModel> notifications;
  final List<HomeActiveProduction> activeProductions;
  final int unreadNotificationCount;
  final int activeWarningCount;

  const HomeDashboardModel({
    required this.success,
    required this.player,
    required this.company,
    required this.financeToday,
    required this.modules,
    required this.hourlyIncomeEstimate,
    required this.ongoingActivities,
    required this.notifications,
    required this.activeProductions,
    required this.unreadNotificationCount,
    required this.activeWarningCount,
  });

  factory HomeDashboardModel.fromJson(Map<String, dynamic> json) {
    final playerMap = _asMap(json['player']);
    final companyMap = _asMap(json['company']);
    final financeMap = _asMap(json['finance_today']);
    final modulesMap = _asMap(json['modules']);
    final hourlyIncomeMap = _asMap(json['hourly_income_estimate']);
    final ongoingList = _asList(json['ongoing_activities']);
    final notificationList = _asList(json['notifications']);
    final summaryMap = _asMap(json['notification_summary']);
    final activeProdList = _asList(json['active_productions']);

    return HomeDashboardModel(
      success: json['success'] as bool? ?? false,
      player: HomePlayerSummary.fromJson(playerMap),
      company: HomeCompanySummary.fromJson(companyMap),
      financeToday: HomeFinanceToday.fromJson(financeMap),
      modules: HomeModulesSummary.fromJson(modulesMap),
      hourlyIncomeEstimate: HomeHourlyIncomeEstimate.fromJson(hourlyIncomeMap),
      ongoingActivities: ongoingList
          .whereType<Map>()
          .map(
            (item) =>
                HomeOngoingActivity.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      notifications: notificationList
          .whereType<Map>()
          .map(
            (item) => PlayerNotificationModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      activeProductions: activeProdList
          .whereType<Map>()
          .map(
            (item) =>
                HomeActiveProduction.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      unreadNotificationCount:
          (summaryMap['unread_count'] as num?)?.toInt() ?? 0,
      activeWarningCount:
          (summaryMap['active_warning_count'] as num?)?.toInt() ?? 0,
    );
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static List<dynamic> _asList(dynamic value) {
    if (value is List<dynamic>) return value;
    if (value is List) return List<dynamic>.from(value);
    return const <dynamic>[];
  }
}

class HomeHourlyIncomeEstimate {
  final double total;
  final double storeRevenue;
  final double productionValue;

  const HomeHourlyIncomeEstimate({
    required this.total,
    required this.storeRevenue,
    required this.productionValue,
  });

  factory HomeHourlyIncomeEstimate.fromJson(Map<String, dynamic> json) {
    return HomeHourlyIncomeEstimate(
      total: (json['total'] as num?)?.toDouble() ?? 0,
      storeRevenue: (json['store_revenue'] as num?)?.toDouble() ?? 0,
      productionValue: (json['production_value'] as num?)?.toDouble() ?? 0,
    );
  }
}

class HomePlayerSummary {
  final String playerName;
  final String companyName;
  final String avatarId;
  final int level;
  final double cash;
  final double gold;
  final int currentLevelExperience;
  final int nextLevelRequiredExperience;
  final double expProgressRatio;
  final int achievementUnlockedCount;
  final int achievementTotalCount;

  const HomePlayerSummary({
    required this.playerName,
    required this.companyName,
    required this.avatarId,
    required this.level,
    required this.cash,
    required this.gold,
    required this.currentLevelExperience,
    required this.nextLevelRequiredExperience,
    required this.expProgressRatio,
    required this.achievementUnlockedCount,
    required this.achievementTotalCount,
  });

  factory HomePlayerSummary.fromJson(Map<String, dynamic> json) {
    return HomePlayerSummary(
      playerName: (json['player_name'] ?? 'Oyuncu').toString(),
      companyName: (json['company_name'] ?? 'Yeni Holding').toString(),
      avatarId: (json['avatar_id'] ?? 'ae1.webp').toString(),
      level: (json['level'] as num?)?.toInt() ?? 1,
      cash: (json['cash'] as num?)?.toDouble() ?? 0,
      gold: (json['gold'] as num?)?.toDouble() ?? 0,
      currentLevelExperience:
          (json['current_level_experience'] as num?)?.toInt() ?? 0,
      nextLevelRequiredExperience:
          (json['next_level_required_experience'] as num?)?.toInt() ?? 1,
      expProgressRatio: (json['exp_progress_ratio'] as num?)?.toDouble() ?? 0,
      achievementUnlockedCount:
          (json['achievement_unlocked_count'] as num?)?.toInt() ?? 0,
      achievementTotalCount:
          (json['achievement_total_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class HomeCompanySummary {
  final double companyValue;
  final double todayProfit;
  final int activeBusinessCount;
  final int totalBusinessCount;
  final String headquartersCityName;
  final String companyStatus;
  final List<double> companyValueHistory;

  const HomeCompanySummary({
    required this.companyValue,
    required this.todayProfit,
    required this.activeBusinessCount,
    required this.totalBusinessCount,
    required this.headquartersCityName,
    required this.companyStatus,
    required this.companyValueHistory,
  });

  factory HomeCompanySummary.fromJson(Map<String, dynamic> json) {
    return HomeCompanySummary(
      companyValue: (json['company_value'] as num?)?.toDouble() ?? 0,
      todayProfit: (json['today_profit'] as num?)?.toDouble() ?? 0,
      activeBusinessCount:
          (json['active_business_count'] as num?)?.toInt() ?? 0,
      totalBusinessCount: (json['total_business_count'] as num?)?.toInt() ?? 0,
      headquartersCityName: (json['headquarters_city_name'] ?? '-').toString(),
      companyStatus: (json['company_status'] ?? 'istikrarli').toString(),
      companyValueHistory:
          (json['company_value_history'] as List?)
              ?.map((item) => (item as num).toDouble())
              .toList() ??
          const <double>[],
    );
  }
}

class HomeFinanceToday {
  final double revenue;
  final double productionCost;
  final double logisticsCost;
  final double netProfit;

  const HomeFinanceToday({
    required this.revenue,
    required this.productionCost,
    required this.logisticsCost,
    required this.netProfit,
  });

  factory HomeFinanceToday.fromJson(Map<String, dynamic> json) {
    return HomeFinanceToday(
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      productionCost: (json['production_cost'] as num?)?.toDouble() ?? 0,
      logisticsCost: (json['logistics_cost'] as num?)?.toDouble() ?? 0,
      netProfit: (json['net_profit'] as num?)?.toDouble() ?? 0,
    );
  }
}

class HomeModulesSummary {
  final HomeModuleMetrics stores;
  final HomeModuleMetrics warehouses;
  final HomeModuleMetrics factories;
  final HomeModuleMetrics fields;
  final HomeModuleMetrics farms;
  final HomeModuleMetrics mines;
  final HomeModuleMetrics logistics;
  final HomeModuleMetrics arge;

  const HomeModulesSummary({
    required this.stores,
    required this.warehouses,
    required this.factories,
    required this.fields,
    required this.farms,
    required this.mines,
    required this.logistics,
    required this.arge,
  });

  factory HomeModulesSummary.fromJson(Map<String, dynamic> json) {
    return HomeModulesSummary(
      stores: HomeModuleMetrics.fromJson(
        HomeDashboardModel._asMap(json['stores']),
      ),
      warehouses: HomeModuleMetrics.fromJson(
        HomeDashboardModel._asMap(json['warehouses']),
      ),
      factories: HomeModuleMetrics.fromJson(
        HomeDashboardModel._asMap(json['factories']),
      ),
      fields: HomeModuleMetrics.fromJson(
        HomeDashboardModel._asMap(json['fields']),
      ),
      farms: HomeModuleMetrics.fromJson(
        HomeDashboardModel._asMap(json['farms']),
      ),
      mines: HomeModuleMetrics.fromJson(
        HomeDashboardModel._asMap(json['mines']),
      ),
      logistics: HomeModuleMetrics.fromJson(
        HomeDashboardModel._asMap(json['logistics']),
      ),
      arge: HomeModuleMetrics.fromJson(HomeDashboardModel._asMap(json['arge'])),
    );
  }
}

class HomeModuleMetrics {
  final int count;
  final int activeCount;
  final int warningCount;
  final int blockedCount;
  final int totalBusinessCount;
  final int vehicleCount;
  final int activeTripCount;
  final int activeResearchCount;
  final int remainingSeconds;
  final double stockRatio;
  final double capacityRatio;
  final double productionRatio;
  final double fuelRatio;

  const HomeModuleMetrics({
    required this.count,
    required this.activeCount,
    required this.warningCount,
    required this.blockedCount,
    required this.totalBusinessCount,
    required this.vehicleCount,
    required this.activeTripCount,
    required this.activeResearchCount,
    required this.remainingSeconds,
    required this.stockRatio,
    required this.capacityRatio,
    required this.productionRatio,
    required this.fuelRatio,
  });

  factory HomeModuleMetrics.fromJson(Map<String, dynamic> json) {
    return HomeModuleMetrics(
      count: (json['count'] as num?)?.toInt() ?? 0,
      activeCount: (json['active_count'] as num?)?.toInt() ?? 0,
      warningCount: (json['warning_count'] as num?)?.toInt() ?? 0,
      blockedCount: (json['blocked_count'] as num?)?.toInt() ?? 0,
      totalBusinessCount: (json['total_business_count'] as num?)?.toInt() ?? 0,
      vehicleCount: (json['vehicle_count'] as num?)?.toInt() ?? 0,
      activeTripCount: (json['active_trip_count'] as num?)?.toInt() ?? 0,
      activeResearchCount:
          (json['active_research_count'] as num?)?.toInt() ?? 0,
      remainingSeconds: (json['remaining_seconds'] as num?)?.toInt() ?? 0,
      stockRatio: (json['stock_ratio'] as num?)?.toDouble() ?? 0,
      capacityRatio: (json['capacity_ratio'] as num?)?.toDouble() ?? 0,
      productionRatio: (json['production_ratio'] as num?)?.toDouble() ?? 0,
      fuelRatio: (json['fuel_ratio'] as num?)?.toDouble() ?? 0,
    );
  }
}

class HomeOngoingActivity {
  final String id;
  final String type;
  final String kind;
  final String title;
  final String subtitle;
  final DateTime startedAt;
  final DateTime finishAt;

  const HomeOngoingActivity({
    required this.id,
    required this.type,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.startedAt,
    required this.finishAt,
  });

  factory HomeOngoingActivity.fromJson(Map<String, dynamic> json) {
    return HomeOngoingActivity(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      title: (json['title'] ?? 'Islem').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      startedAt:
          DateTime.tryParse((json['started_at'] ?? '').toString()) ??
          DateTime.now().toUtc(),
      finishAt:
          DateTime.tryParse((json['finish_at'] ?? '').toString()) ??
          DateTime.now().toUtc(),
    );
  }

  Duration get totalDuration => finishAt.difference(startedAt);

  Duration get remainingDuration {
    final diff = finishAt.toLocal().difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get isHomeOngoingSupported =>
      type == 'construction' || type == 'upgrade' || type == 'research';

  double get progressRatio {
    final totalMs = totalDuration.inMilliseconds;
    if (totalMs <= 0) return 1;
    final elapsedMs = DateTime.now()
        .toUtc()
        .difference(startedAt.toUtc())
        .inMilliseconds;
    final ratio = elapsedMs / totalMs;
    if (ratio < 0) return 0;
    if (ratio > 1) return 1;
    return ratio;
  }
}

class HomeActiveProduction {
  final String productId;
  final String productName;
  final String productIcon;
  final String ownerKind;
  final int qualityLevel;
  final int activeSlots;

  const HomeActiveProduction({
    required this.productId,
    required this.productName,
    required this.productIcon,
    required this.ownerKind,
    required this.qualityLevel,
    required this.activeSlots,
  });

  factory HomeActiveProduction.fromJson(Map<String, dynamic> json) {
    return HomeActiveProduction(
      productId: (json['product_id'] ?? '').toString(),
      productName: (json['product_name'] ?? '').toString(),
      productIcon: (json['product_icon'] ?? '').toString(),
      ownerKind: (json['owner_kind'] ?? '').toString(),
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 1,
      activeSlots: (json['active_slots'] as num?)?.toInt() ?? 0,
    );
  }
}

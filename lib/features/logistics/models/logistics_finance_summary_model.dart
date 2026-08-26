class LogisticsFinanceSummaryModel {
  final double totalIncome;
  final double totalExpense;
  final double netProfit;
  final double vehiclePurchaseExpense;
  final double fuelPurchaseExpense;
  final double maintenanceExpense;
  final double rentalIncome;
  final double totalDistanceKm;
  final int totalTrips;
  final int totalCargoDelivered;
  final double totalFuelUsed;

  const LogisticsFinanceSummaryModel({
    required this.totalIncome,
    required this.totalExpense,
    required this.netProfit,
    required this.vehiclePurchaseExpense,
    required this.fuelPurchaseExpense,
    required this.maintenanceExpense,
    required this.rentalIncome,
    this.totalDistanceKm = 0.0,
    this.totalTrips = 0,
    this.totalCargoDelivered = 0,
    this.totalFuelUsed = 0.0,
  });

  const LogisticsFinanceSummaryModel.empty()
      : totalIncome = 0,
        totalExpense = 0,
        netProfit = 0,
        vehiclePurchaseExpense = 0,
        fuelPurchaseExpense = 0,
        maintenanceExpense = 0,
        rentalIncome = 0,
        totalDistanceKm = 0.0,
        totalTrips = 0,
        totalCargoDelivered = 0,
        totalFuelUsed = 0.0;

  factory LogisticsFinanceSummaryModel.fromJson(Map<String, dynamic> json) {
    double parseNum(String key) => (json[key] as num?)?.toDouble() ?? 0.0;
    int parseInt(String key) => (json[key] as num?)?.toInt() ?? 0;

    return LogisticsFinanceSummaryModel(
      totalIncome: parseNum('total_income'),
      totalExpense: parseNum('total_expense'),
      netProfit: parseNum('net_profit'),
      vehiclePurchaseExpense: parseNum('vehicle_purchase_expense'),
      fuelPurchaseExpense: parseNum('fuel_purchase_expense'),
      maintenanceExpense: parseNum('maintenance_expense'),
      rentalIncome: parseNum('rental_income'),
      totalDistanceKm: parseNum('total_distance_km'),
      totalTrips: parseInt('total_trips'),
      totalCargoDelivered: parseInt('total_cargo_delivered'),
      totalFuelUsed: parseNum('total_fuel_used'),
    );
  }
}

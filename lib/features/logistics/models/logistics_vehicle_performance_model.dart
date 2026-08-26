class LogisticsVehiclePerformanceModel {
  final String vehicleId;
  final int totalTrips;
  final int completedTrips;
  final int activeTrips;
  final int rentalTrips;
  final double rentalRevenue;
  final double totalDistanceKm;
  final double totalFuelUsed;
  final int totalCargoQuantity;
  final double totalTransportCost;
  final DateTime? lastActivityAt;

  const LogisticsVehiclePerformanceModel({
    required this.vehicleId,
    required this.totalTrips,
    required this.completedTrips,
    required this.activeTrips,
    required this.rentalTrips,
    required this.rentalRevenue,
    this.totalDistanceKm = 0.0,
    this.totalFuelUsed = 0.0,
    this.totalCargoQuantity = 0,
    this.totalTransportCost = 0.0,
    required this.lastActivityAt,
  });

  const LogisticsVehiclePerformanceModel.empty(String vehicleId)
    : this(
        vehicleId: vehicleId,
        totalTrips: 0,
        completedTrips: 0,
        activeTrips: 0,
        rentalTrips: 0,
        rentalRevenue: 0,
        totalDistanceKm: 0.0,
        totalFuelUsed: 0.0,
        totalCargoQuantity: 0,
        totalTransportCost: 0.0,
        lastActivityAt: null,
      );
}

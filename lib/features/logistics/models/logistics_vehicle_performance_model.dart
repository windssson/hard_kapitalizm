class LogisticsVehiclePerformanceModel {
  final String vehicleId;
  final int totalTrips;
  final int completedTrips;
  final int activeTrips;
  final int rentalTrips;
  final double rentalRevenue;
  final DateTime? lastActivityAt;

  const LogisticsVehiclePerformanceModel({
    required this.vehicleId,
    required this.totalTrips,
    required this.completedTrips,
    required this.activeTrips,
    required this.rentalTrips,
    required this.rentalRevenue,
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
        lastActivityAt: null,
      );
}

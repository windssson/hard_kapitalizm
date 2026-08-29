class DepositModel {
  final String id;
  final String playerId;
  final double amount;
  final double interestRate;
  final double expectedPayout;
  final DateTime lockedUntil;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  DepositModel({
    required this.id,
    required this.playerId,
    required this.amount,
    required this.interestRate,
    required this.expectedPayout,
    required this.lockedUntil,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DepositModel.fromJson(Map<String, dynamic> json) {
    return DepositModel(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      interestRate: (json['interest_rate'] as num).toDouble(),
      expectedPayout: (json['expected_payout'] as num).toDouble(),
      lockedUntil: DateTime.parse(json['locked_until'] as String).toLocal(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  DepositModel copyWith({
    String? id,
    String? playerId,
    double? amount,
    double? interestRate,
    double? expectedPayout,
    DateTime? lockedUntil,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DepositModel(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      amount: amount ?? this.amount,
      interestRate: interestRate ?? this.interestRate,
      expectedPayout: expectedPayout ?? this.expectedPayout,
      lockedUntil: lockedUntil ?? this.lockedUntil,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

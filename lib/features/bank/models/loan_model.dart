class LoanModel {
  final String id;
  final String playerId;
  final double amount;
  final double interestRate;
  final double totalDue;
  final double totalPaid;
  final int installmentsTotal;
  final int installmentsPaid;
  final double installmentAmount;
  final DateTime nextInstallmentDueAt;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  LoanModel({
    required this.id,
    required this.playerId,
    required this.amount,
    required this.interestRate,
    required this.totalDue,
    required this.totalPaid,
    required this.installmentsTotal,
    required this.installmentsPaid,
    required this.installmentAmount,
    required this.nextInstallmentDueAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  int get remainingInstallments => installmentsTotal - installmentsPaid;
  double get remainingPrincipal =>
      installmentsTotal > 0 ? (amount * (remainingInstallments / installmentsTotal)) : 0.0;
  bool get isDefaulted => status == 'defaulted';
  bool get isPaid => status == 'paid';

  factory LoanModel.fromJson(Map<String, dynamic> json) {
    return LoanModel(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      interestRate: (json['interest_rate'] as num).toDouble(),
      totalDue: (json['total_due'] as num).toDouble(),
      totalPaid: (json['total_paid'] as num).toDouble(),
      installmentsTotal: (json['installments_total'] as num?)?.toInt() ?? 0,
      installmentsPaid: (json['installments_paid'] as num?)?.toInt() ?? 0,
      installmentAmount: (json['installment_amount'] as num).toDouble(),
      nextInstallmentDueAt: DateTime.parse(json['next_installment_due_at'] as String).toLocal(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}

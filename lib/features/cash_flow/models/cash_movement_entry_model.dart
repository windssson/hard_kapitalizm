class CashMovementEntryModel {
  const CashMovementEntryModel({
    required this.id,
    required this.amount,
    required this.createdAt,
    required this.title,
    this.description,
    this.balanceAfter,
    this.category,
    this.referenceId,
    this.referenceType,
    this.raw = const {},
  });

  final String id;
  final double amount;
  final DateTime createdAt;
  final String title;
  final String? description;
  final double? balanceAfter;
  final String? category;
  final String? referenceId;
  final String? referenceType;
  final Map<String, dynamic> raw;

  bool get isIncome => amount >= 0;
}

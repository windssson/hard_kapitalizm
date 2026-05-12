class StoreHistoryItemModel {
  final String id;
  final String type;
  final DateTime happenedAt;
  final String title;
  final String subtitle;
  final String productName;
  final int quantity;
  final double amount;
  final double? secondaryAmount;
  final int? qualityLevel;
  final String status;

  const StoreHistoryItemModel({
    required this.id,
    required this.type,
    required this.happenedAt,
    required this.title,
    required this.subtitle,
    required this.productName,
    required this.quantity,
    required this.amount,
    required this.secondaryAmount,
    required this.qualityLevel,
    required this.status,
  });

  bool get isSale => type == 'sale';
  bool get isIncomingTransfer => type == 'incoming_transfer';
  bool get isOutgoingTransfer => type == 'outgoing_transfer';
}

class ProductPriceHistoryModel {
  final String productId;
  final List<double> prices;
  final DateTime updatedAt;

  ProductPriceHistoryModel({
    required this.productId,
    required this.prices,
    required this.updatedAt,
  });

  factory ProductPriceHistoryModel.fromJson(Map<String, dynamic> json) {
    final indexedPrices = <MapEntry<int, double>>[];

    for (final entry in json.entries) {
      if (!entry.key.startsWith('price_day_')) continue;
      final index = int.tryParse(entry.key.replaceFirst('price_day_', ''));
      if (index == null) continue;
      final value = double.tryParse(entry.value?.toString() ?? '0') ?? 0.0;
      indexedPrices.add(MapEntry(index, value));
    }

    indexedPrices.sort((a, b) => b.key.compareTo(a.key));

    final rawPrices = json['prices'];
    final prices = rawPrices is List
        ? rawPrices
              .map((value) => double.tryParse(value?.toString() ?? '0') ?? 0.0)
              .toList()
        : indexedPrices.map((entry) => entry.value).toList();
    final updatedAtRaw = json['updated_at']?.toString();

    return ProductPriceHistoryModel(
      productId: json['product_id']?.toString() ?? '',
      prices: prices,
      updatedAt: updatedAtRaw != null
          ? DateTime.tryParse(updatedAtRaw) ??
              DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

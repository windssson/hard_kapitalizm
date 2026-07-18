/// Inventory/slot değişimleri (depo slotu, mağaza slotu, üretim envanteri vb.)
class InventoryChange {
  final String? slotId;
  final String? productId;
  final String? productName;
  final String? productIcon;
  final int? qualityLevel;
  final String? brandId;
  final int? quantity;
  final int? pendingQuantity;
  final double? cost;
  final double? price;
  final bool? isEmpty;
  final Map<String, dynamic> raw;

  const InventoryChange({
    this.slotId,
    this.productId,
    this.productName,
    this.productIcon,
    this.qualityLevel,
    this.brandId,
    this.quantity,
    this.pendingQuantity,
    this.cost,
    this.price,
    this.isEmpty,
    required this.raw,
  });

  factory InventoryChange.fromJson(Map<String, dynamic> json) {
    return InventoryChange(
      slotId: json['slot_id']?.toString() ?? json['id']?.toString(),
      productId: json['product_id']?.toString(),
      productName: json['product_name']?.toString(),
      productIcon: json['product_icon']?.toString(),
      qualityLevel: (json['quality_level'] as num?)?.toInt(),
      brandId: json['brand_id']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt(),
      pendingQuantity: (json['pending_quantity'] as num?)?.toInt(),
      cost: (json['cost'] as num?)?.toDouble(),
      price: (json['price'] as num?)?.toDouble(),
      isEmpty: json['is_empty'] as bool?,
      raw: json,
    );
  }
}

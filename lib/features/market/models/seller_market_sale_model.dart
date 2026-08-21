class SellerMarketSaleItemModel {
  final String id;
  final String productId;
  final String productName;
  final String productIcon;
  final int quantity;
  final int qualityLevel;
  final double unitPrice;
  final double totalPrice;
  final String? brandId;

  const SellerMarketSaleItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productIcon,
    required this.quantity,
    required this.qualityLevel,
    required this.unitPrice,
    required this.totalPrice,
    this.brandId,
  });

  factory SellerMarketSaleItemModel.fromJson(Map<String, dynamic> json) {
    return SellerMarketSaleItemModel(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? 'Ürün',
      productIcon: json['product_icon']?.toString() ?? 'default.webp',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      brandId: json['brand_id']?.toString(),
    );
  }
}

class SellerMarketSaleModel {
  final String id;
  final String transferType;
  final String status;
  final double totalPrice;
  final int totalQuantity;
  final int itemCount;
  final DateTime? startedAt;
  final DateTime? finishAt;
  final DateTime? completedAt;
  final String? buyerPlayerId;
  final String buyerPlayerName;
  final String buyerCompanyName;
  final String buyerAvatarId;
  final String sellerWarehouseName;
  final String sellerCityName;
  final String buyerCityName;
  final List<SellerMarketSaleItemModel> items;

  const SellerMarketSaleModel({
    required this.id,
    required this.transferType,
    required this.status,
    required this.totalPrice,
    required this.totalQuantity,
    required this.itemCount,
    this.startedAt,
    this.finishAt,
    this.completedAt,
    this.buyerPlayerId,
    required this.buyerPlayerName,
    required this.buyerCompanyName,
    required this.buyerAvatarId,
    required this.sellerWarehouseName,
    required this.sellerCityName,
    required this.buyerCityName,
    required this.items,
  });

  factory SellerMarketSaleModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final parsedItems = rawItems
        .map(
          (e) =>
              SellerMarketSaleItemModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    return SellerMarketSaleModel(
      id: json['id']?.toString() ?? '',
      transferType: json['transfer_type']?.toString() ?? 'market_transfer',
      status: json['status']?.toString() ?? 'completed',
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      totalQuantity: (json['total_quantity'] as num?)?.toInt() ?? 0,
      itemCount: (json['item_count'] as num?)?.toInt() ?? parsedItems.length,
      startedAt: parseDate(json['started_at']),
      finishAt: parseDate(json['finish_at']),
      completedAt: parseDate(json['completed_at']),
      buyerPlayerId: json['buyer_player_id']?.toString(),
      buyerPlayerName: json['buyer_player_name']?.toString() ?? 'Oyuncu',
      buyerCompanyName: json['buyer_company_name']?.toString() ?? 'Şirket',
      buyerAvatarId: json['buyer_avatar_id']?.toString() ?? 'ae1.webp',
      sellerWarehouseName: json['seller_warehouse_name']?.toString() ?? 'Depo',
      sellerCityName: json['seller_city_name']?.toString() ?? '-',
      buyerCityName: json['buyer_city_name']?.toString() ?? '-',
      items: parsedItems,
    );
  }
}

class SellerMarketSalesHistoryResponse {
  final bool success;
  final int totalSalesCount;
  final int totalSoldQuantity;
  final double totalRevenue;
  final List<SellerMarketSaleModel> sales;

  const SellerMarketSalesHistoryResponse({
    required this.success,
    required this.totalSalesCount,
    required this.totalSoldQuantity,
    required this.totalRevenue,
    required this.sales,
  });

  factory SellerMarketSalesHistoryResponse.fromJson(Map<String, dynamic> json) {
    final rawSales = json['sales'] as List<dynamic>? ?? const [];
    final parsedSales = rawSales
        .map(
          (e) =>
              SellerMarketSaleModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    return SellerMarketSalesHistoryResponse(
      success: json['success'] == true,
      totalSalesCount: (json['total_sales_count'] as num?)?.toInt() ?? 0,
      totalSoldQuantity: (json['total_sold_quantity'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      sales: parsedSales,
    );
  }
}

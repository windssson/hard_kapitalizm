import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/farm/models/farm_model.dart';

class FarmSlotPreviewModel {
  final String id;
  final int slotIndex;
  final bool isActive;
  final String? productId;
  final ProductModel? product;

  const FarmSlotPreviewModel({
    required this.id,
    required this.slotIndex,
    required this.isActive,
    required this.productId,
    required this.product,
  });

  bool get hasProduct => productId != null && productId!.isNotEmpty;

  factory FarmSlotPreviewModel.fromJson(Map<String, dynamic> json) {
    return FarmSlotPreviewModel(
      id: (json['id'] ?? '').toString(),
      slotIndex: (json['slot_index'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      productId: json['product_id']?.toString(),
      product: json['product'] != null
          ? ProductModel.fromJson(Map<String, dynamic>.from(json['product'] as Map))
          : null,
    );
  }
}

class FarmListItemModel {
  final FarmModel farm;
  final String cityName;
  final String farmTypeName;
  final String farmTypeIcon;
  final int outputStockQuantity;
  final List<FarmSlotPreviewModel> slots;

  const FarmListItemModel({
    required this.farm,
    required this.cityName,
    required this.farmTypeName,
    required this.farmTypeIcon,
    required this.outputStockQuantity,
    required this.slots,
  });

  int get totalOutputCapacity {
    final slotCount = farm.currentSlotCount > 0 ? farm.currentSlotCount : 1;
    return farm.outputCapacity * slotCount;
  }

  double get outputStockRatio {
    if (totalOutputCapacity <= 0) return 0.0;
    return (outputStockQuantity / totalOutputCapacity).clamp(0.0, 1.0);
  }
}

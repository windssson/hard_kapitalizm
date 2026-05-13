import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/field/models/field_model.dart';

class FieldSlotPreviewModel {
  final String id;
  final int slotIndex;
  final bool isActive;
  final String? productId;
  final ProductModel? product;

  const FieldSlotPreviewModel({
    required this.id,
    required this.slotIndex,
    required this.isActive,
    required this.productId,
    required this.product,
  });

  bool get hasProduct => productId != null && productId!.isNotEmpty;

  factory FieldSlotPreviewModel.fromJson(Map<String, dynamic> json) {
    return FieldSlotPreviewModel(
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

class FieldListItemModel {
  final FieldModel field;
  final String cityName;
  final String fieldTypeName;
  final String fieldTypeIcon;
  final int outputStockQuantity;
  final List<FieldSlotPreviewModel> slots;

  const FieldListItemModel({
    required this.field,
    required this.cityName,
    required this.fieldTypeName,
    required this.fieldTypeIcon,
    required this.outputStockQuantity,
    required this.slots,
  });

  double get outputStockRatio {
    if (field.outputCapacity <= 0) return 0.0;
    return (outputStockQuantity / field.outputCapacity).clamp(0.0, 1.0);
  }
}

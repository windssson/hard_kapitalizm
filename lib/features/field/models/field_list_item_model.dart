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
  final int inputStockQuantity;
  final List<FieldSlotPreviewModel> slots;

  const FieldListItemModel({
    required this.field,
    required this.cityName,
    required this.fieldTypeName,
    required this.fieldTypeIcon,
    required this.outputStockQuantity,
    required this.inputStockQuantity,
    required this.slots,
  });

  int get totalOutputCapacity {
    return field.outputCapacity;
  }

  double get outputStockRatio {
    if (totalOutputCapacity <= 0) return 0.0;
    return (outputStockQuantity / totalOutputCapacity).clamp(0.0, 1.0);
  }

  int get totalInputCapacity {
    return field.inputCapacity;
  }

  double get inputStockRatio {
    if (totalInputCapacity <= 0) return 0.0;
    return (inputStockQuantity / totalInputCapacity).clamp(0.0, 1.0);
  }

  bool get hasActiveProduction => slots.any((s) => s.hasProduct);

  String? get warningReason {
    if (!field.isActive) return 'Devre Dışı';
    if (!hasActiveProduction) return 'Ekim Yok!';
    if (outputStockRatio >= 1.0) return 'Depo Dolu!';
    return null;
  }

  bool get hasWarning => warningReason != null;

  FieldListItemModel copyWith({
    FieldModel? field,
    String? cityName,
    String? fieldTypeName,
    String? fieldTypeIcon,
    int? outputStockQuantity,
    int? inputStockQuantity,
    List<FieldSlotPreviewModel>? slots,
  }) {
    return FieldListItemModel(
      field: field ?? this.field,
      cityName: cityName ?? this.cityName,
      fieldTypeName: fieldTypeName ?? this.fieldTypeName,
      fieldTypeIcon: fieldTypeIcon ?? this.fieldTypeIcon,
      outputStockQuantity: outputStockQuantity ?? this.outputStockQuantity,
      inputStockQuantity: inputStockQuantity ?? this.inputStockQuantity,
      slots: slots ?? this.slots,
    );
  }
}

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
  final int inputStockQuantity;
  final List<FarmSlotPreviewModel> slots;

  const FarmListItemModel({
    required this.farm,
    required this.cityName,
    required this.farmTypeName,
    required this.farmTypeIcon,
    required this.outputStockQuantity,
    required this.inputStockQuantity,
    required this.slots,
  });

  int get totalOutputCapacity {
    return farm.outputCapacity;
  }

  double get outputStockRatio {
    if (totalOutputCapacity <= 0) return 0.0;
    return (outputStockQuantity / totalOutputCapacity).clamp(0.0, 1.0);
  }

  int get totalInputCapacity {
    return farm.inputCapacity;
  }

  double get inputStockRatio {
    if (totalInputCapacity <= 0) return 0.0;
    return (inputStockQuantity / totalInputCapacity).clamp(0.0, 1.0);
  }

  bool get hasActiveProduction => slots.any((s) => s.hasProduct);

  String? get warningReason {
    if (!farm.isActive) return 'Devre Dışı';
    if (!hasActiveProduction) return 'Üretim Yok!';
    if (outputStockRatio >= 1.0) return 'Depo Dolu!';
    if (farm.inputCapacity > 0 && inputStockQuantity <= 0 && hasActiveProduction) {
      return 'Yem Yok!';
    }
    return null;
  }

  bool get hasWarning => warningReason != null;

  FarmListItemModel copyWith({
    FarmModel? farm,
    String? cityName,
    String? farmTypeName,
    String? farmTypeIcon,
    int? outputStockQuantity,
    int? inputStockQuantity,
    List<FarmSlotPreviewModel>? slots,
  }) {
    return FarmListItemModel(
      farm: farm ?? this.farm,
      cityName: cityName ?? this.cityName,
      farmTypeName: farmTypeName ?? this.farmTypeName,
      farmTypeIcon: farmTypeIcon ?? this.farmTypeIcon,
      outputStockQuantity: outputStockQuantity ?? this.outputStockQuantity,
      inputStockQuantity: inputStockQuantity ?? this.inputStockQuantity,
      slots: slots ?? this.slots,
    );
  }
}

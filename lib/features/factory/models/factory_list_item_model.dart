import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/factory/models/factory_model.dart';

class FactoryListItemModel {
  final FactoryModel factory;
  final String cityName;
  final String factoryTypeName;
  final String factoryTypeIcon;
  final int inputStockQuantity;
  final int outputStockQuantity;
  final ProductModel? selectedProduct;

  const FactoryListItemModel({
    required this.factory,
    required this.cityName,
    required this.factoryTypeName,
    required this.factoryTypeIcon,
    required this.inputStockQuantity,
    required this.outputStockQuantity,
    required this.selectedProduct,
  });

  double get inputStockRatio {
    if (factory.inputCapacity <= 0) return 0.0;
    return (inputStockQuantity / factory.inputCapacity).clamp(0.0, 1.0);
  }

  double get outputStockRatio {
    if (factory.outputCapacity <= 0) return 0.0;
    return (outputStockQuantity / factory.outputCapacity).clamp(0.0, 1.0);
  }

  bool get hasSelectedProduct =>
      selectedProduct != null &&
      selectedProduct!.id.isNotEmpty &&
      selectedProduct!.urunAdi.isNotEmpty;

  bool get hasInputStock => inputStockQuantity > 0;

  bool get isOutputFull =>
      factory.outputCapacity > 0 && outputStockQuantity >= factory.outputCapacity;

  String? get warningReason {
    if (!factory.isActive) return 'Devre Dışı';
    if (!hasSelectedProduct) return 'Ürün Seçilmedi!';
    if (isOutputFull) return 'Depo Dolu!';
    if (!hasInputStock) return 'Hammadde Yok!';
    return null;
  }

  bool get hasWarning => warningReason != null;

  FactoryListItemModel copyWith({
    FactoryModel? factory,
    String? cityName,
    String? factoryTypeName,
    String? factoryTypeIcon,
    int? inputStockQuantity,
    int? outputStockQuantity,
    ProductModel? selectedProduct,
  }) {
    return FactoryListItemModel(
      factory: factory ?? this.factory,
      cityName: cityName ?? this.cityName,
      factoryTypeName: factoryTypeName ?? this.factoryTypeName,
      factoryTypeIcon: factoryTypeIcon ?? this.factoryTypeIcon,
      inputStockQuantity: inputStockQuantity ?? this.inputStockQuantity,
      outputStockQuantity: outputStockQuantity ?? this.outputStockQuantity,
      selectedProduct: selectedProduct ?? this.selectedProduct,
    );
  }
}

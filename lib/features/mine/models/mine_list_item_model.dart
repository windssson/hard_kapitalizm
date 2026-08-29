import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';

class MineListItemModel {
  final MineModel mine;
  final String cityName;
  final String mineTypeName;
  final String mineTypeIcon;
  final int outputStockQuantity;
  final ProductModel? selectedProduct;

  const MineListItemModel({
    required this.mine,
    required this.cityName,
    required this.mineTypeName,
    required this.mineTypeIcon,
    required this.outputStockQuantity,
    required this.selectedProduct,
  });

  double get outputStockRatio {
    if (mine.outputCapacity <= 0) return 0.0;
    return (outputStockQuantity / mine.outputCapacity).clamp(0.0, 1.0);
  }

  bool get hasSelectedProduct =>
      selectedProduct != null &&
      selectedProduct!.id.isNotEmpty &&
      selectedProduct!.urunAdi.isNotEmpty;

  String? get warningReason {
    if (!mine.isActive) return 'Devre Dışı';
    if (!hasSelectedProduct) return 'Cevher Seçilmedi!';
    if (outputStockRatio >= 1.0) return 'Depo Dolu!';
    return null;
  }

  bool get hasWarning => warningReason != null;

  MineListItemModel copyWith({
    MineModel? mine,
    String? cityName,
    String? mineTypeName,
    String? mineTypeIcon,
    int? outputStockQuantity,
    ProductModel? selectedProduct,
  }) {
    return MineListItemModel(
      mine: mine ?? this.mine,
      cityName: cityName ?? this.cityName,
      mineTypeName: mineTypeName ?? this.mineTypeName,
      mineTypeIcon: mineTypeIcon ?? this.mineTypeIcon,
      outputStockQuantity: outputStockQuantity ?? this.outputStockQuantity,
      selectedProduct: selectedProduct ?? this.selectedProduct,
    );
  }
}

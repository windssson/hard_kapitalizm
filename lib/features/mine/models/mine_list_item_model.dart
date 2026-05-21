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
}

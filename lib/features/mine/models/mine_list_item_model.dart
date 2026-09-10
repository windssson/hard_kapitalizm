import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/core/models/production_slot_model.dart';
import 'package:hard_kapitalizm/features/mine/models/mine_model.dart';

class MineListItemModel {
  final MineModel mine;
  final String cityName;
  final String mineTypeName;
  final String mineTypeIcon;
  final int outputStockQuantity;

  /// Legacy single-product mirror. Kept until the mine list UI is migrated.
  final ProductModel? selectedProduct;

  /// New backend production configuration source.
  final List<ProductionSlotContractModel> productionSlots;

  const MineListItemModel({
    required this.mine,
    required this.cityName,
    required this.mineTypeName,
    required this.mineTypeIcon,
    required this.outputStockQuantity,
    required this.selectedProduct,
    this.productionSlots = const [],
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
    List<ProductionSlotContractModel>? productionSlots,
  }) {
    return MineListItemModel(
      mine: mine ?? this.mine,
      cityName: cityName ?? this.cityName,
      mineTypeName: mineTypeName ?? this.mineTypeName,
      mineTypeIcon: mineTypeIcon ?? this.mineTypeIcon,
      outputStockQuantity: outputStockQuantity ?? this.outputStockQuantity,
      selectedProduct: selectedProduct ?? this.selectedProduct,
      productionSlots: productionSlots ?? this.productionSlots,
    );
  }
}

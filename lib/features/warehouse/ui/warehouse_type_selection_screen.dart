import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';

class WarehouseTypeSelectionScreen extends ConsumerStatefulWidget {
  final CityModel selectedCity;

  const WarehouseTypeSelectionScreen({super.key, required this.selectedCity});

  @override
  ConsumerState<WarehouseTypeSelectionScreen> createState() =>
      _WarehouseTypeSelectionScreenState();
}

class _WarehouseTypeSelectionScreenState
    extends ConsumerState<WarehouseTypeSelectionScreen> {
  Map<String, dynamic>? _selectedType;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(warehouseTypesProvider);
    final playerAsync = ref.watch(playerStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            SecondaryTopBar(title: '${widget.selectedCity.name} - Depo Türü'),
            Expanded(
              child: playerAsync.when(
                data: (player) => typesAsync.when(
                  data: (types) => _buildTypeList(
                    types,
                    (player?.cash ?? 0).toDouble(),
                    player?.level ?? 1,
                  ),
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
                  error: (error, stack) => Center(child: Text('Hata: $error', style: TextStyle(color: AppColors.red))),
                ),
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
                error: (error, stack) => const Center(child: Text('Oyuncu bilgisi alınamadı.')),
              ),
            ),
            _buildActionPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeList(List<dynamic> types, double playerCash, int playerLevel) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      itemCount: types.length,
      itemBuilder: (context, index) {
        final type = types[index] as Map<String, dynamic>;
        final isSelected = _selectedType?['id'] == type['id'];

        final bool levelLocked = playerLevel < (type['required_level'] ?? 1);
        final bool cashLocked = playerCash < (type['cost'] ?? 0);
        final bool isLocked = levelLocked || cashLocked;

        return GestureDetector(
          onTap: isLocked ? null : () => setState(() => _selectedType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.gold.withValues(alpha: 0.1) : AppColors.cardBg,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isSelected ? AppColors.gold : AppColors.border.withValues(alpha: isLocked ? 0.2 : 0.5),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Opacity(
              opacity: isLocked ? 0.6 : 1.0,
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 65.w,
                        height: 65.w,
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: AppColors.cardBgLight,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: isSelected ? AppColors.gold : AppColors.border),
                        ),
                        child: CachedAssetImage(fileName: type['icon'] ?? 'warehouse.webp', fit: BoxFit.contain),
                      ),
                      if (isLocked)
                        Container(
                          width: 65.w,
                          height: 65.w,
                          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12.r)),
                          child: Icon(Icons.lock, color: AppColors.gold, size: 24.sp),
                        ),
                    ],
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type['name'] ?? 'Bilinmeyen Depo',
                          style: TextStyle(color: isSelected ? AppColors.gold : Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            _buildDetailChip(Icons.monetization_on, _formatMoney((type['cost'] ?? 0).toDouble()), cashLocked ? AppColors.red : AppColors.gold),
                            SizedBox(width: 8.w),
                            _buildDetailChip(Icons.storage, '${type['base_capacity'] ?? 0} m³', AppColors.blue),
                            SizedBox(width: 8.w),
                            _buildDetailChip(Icons.stars, 'Lv. ${type['required_level'] ?? 1}', levelLocked ? AppColors.red : Colors.blueAccent),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isSelected) Icon(Icons.check_circle, color: AppColors.gold, size: 24.sp),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 10.sp),
        SizedBox(width: 4.w),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 10.sp)),
      ],
    );
  }

  Widget _buildActionPanel() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedType != null) ...[
            Text(
              '${widget.selectedCity.name} şehrinde ${_selectedType!['name']} inşa edilecek.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
          ],
          SizedBox(
            width: double.infinity,
            height: 55.h,
            child: ElevatedButton(
              onPressed: (_selectedType != null && !_isProcessing) ? _handleEstablish : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: _isProcessing
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : Text('DEPOYU İNŞA ET', style: TextStyle(color: _selectedType != null ? Colors.black : Colors.white30, fontSize: 14.sp, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(double val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toStringAsFixed(0);
  }

  Future<void> _handleEstablish() async {
    if (_selectedType == null) return;
    setState(() => _isProcessing = true);
    try {
      final result = await ref.read(warehouseActionProvider).createWarehouse(
        cityId: widget.selectedCity.id,
        typeId: _selectedType!['id'],
        name: _selectedType!['name'],
      );
      if (result['success'] == true) {
        if (mounted) {
          ref.invalidate(warehouseListProvider);
          AppSnackbar.show(context, title: 'Başarılı', message: 'Depo inşaatı başladı!', type: SnackbarType.success);
          context.go('/warehouses');
        }
      } else {
        if (mounted) AppSnackbar.show(context, title: 'Hata', message: result['message'] ?? 'Hata oluştu.', type: SnackbarType.error);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

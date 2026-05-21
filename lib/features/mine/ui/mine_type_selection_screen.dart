import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';

class MineTypeSelectionScreen extends ConsumerStatefulWidget {
  final CityModel selectedCity;

  const MineTypeSelectionScreen({super.key, required this.selectedCity});

  @override
  ConsumerState<MineTypeSelectionScreen> createState() =>
      _MineTypeSelectionScreenState();
}

class _MineTypeSelectionScreenState
    extends ConsumerState<MineTypeSelectionScreen> {
  Map<String, dynamic>? _selectedType;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(mineTypesProvider);
    final playerAsync = ref.watch(playerStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            SecondaryTopBar(title: '${widget.selectedCity.name} - Maden Türü'),
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

        return Container(
          margin: EdgeInsets.only(bottom: 14.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            color: AppColors.cardBg.withValues(alpha: 0.85),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isSelected 
                    ? AppColors.gold.withValues(alpha: 0.15) 
                    : AppColors.cardBg.withValues(alpha: 0.85),
                AppColors.cardBgLight.withValues(alpha: isSelected ? 0.3 : 0.4),
              ],
            ),
            border: Border.all(
              color: isSelected 
                  ? AppColors.gold 
                  : AppColors.border.withValues(alpha: isLocked ? 0.2 : 0.5),
              width: isSelected ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
              if (isSelected)
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isLocked ? null : () => setState(() => _selectedType = type),
                splashColor: AppColors.gold.withValues(alpha: 0.15),
                highlightColor: AppColors.gold.withValues(alpha: 0.08),
                child: Opacity(
                  opacity: isLocked ? 0.55 : 1.0,
                  child: Padding(
                    padding: EdgeInsets.all(14.w),
                    child: Row(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 70.w,
                              height: 70.w,
                              padding: EdgeInsets.all(10.w),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: isSelected 
                                      ? AppColors.gold.withValues(alpha: 0.5) 
                                      : AppColors.border.withValues(alpha: 0.3),
                                  width: 1.2,
                                ),
                              ),
                              child: CachedAssetImage(
                                fileName: type['icon'] ?? 'mine.webp', 
                                fit: BoxFit.contain,
                              ),
                            ),
                            if (isLocked)
                              Container(
                                width: 70.w,
                                height: 70.w,
                                decoration: BoxDecoration(
                                  color: Colors.black54, 
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                child: Icon(
                                  Icons.lock_outline, 
                                  color: AppColors.gold, 
                                  size: 22.sp,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type['name'] ?? 'Bilinmeyen Maden',
                                style: TextStyle(
                                  color: isSelected ? AppColors.goldLight : Colors.white, 
                                  fontSize: 15.sp, 
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Wrap(
                                spacing: 6.w,
                                runSpacing: 6.h,
                                children: [
                                  _buildDetailChip(
                                    Icons.monetization_on_outlined, 
                                    _formatMoney((type['cost'] ?? 0).toDouble()), 
                                    cashLocked ? AppColors.red : AppColors.gold,
                                  ),
                                  _buildDetailChip(
                                    Icons.inventory_2_outlined, 
                                    '${type['output_capacity'] ?? 0} Kap.', 
                                    AppColors.blue,
                                  ),
                                  _buildDetailChip(
                                    Icons.stars_outlined, 
                                    'Lv. ${type['required_level'] ?? 1}', 
                                    levelLocked ? AppColors.red : Colors.blueAccent,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isSelected) 
                          Icon(
                            Icons.check_circle_rounded, 
                            color: AppColors.gold, 
                            size: 26.sp,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailChip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: color.withValues(alpha: 0.25), 
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11.sp),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.95), 
              fontSize: 9.sp, 
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel() {
    final hasSelection = _selectedType != null;
    final isEnabled = hasSelection && !_isProcessing;

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black87, 
            blurRadius: 25, 
            offset: const Offset(0, -6),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasSelection) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: AppColors.gold, size: 14.sp),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: Text(
                      '${widget.selectedCity.name} şehrinde ${_selectedType!['name']} inşa edilecek.',
                      style: TextStyle(
                        color: AppColors.textSecondary, 
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
          ],
          Container(
            width: double.infinity,
            height: 52.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14.r),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isEnabled ? _handleEstablish : null,
                  splashColor: Colors.black12,
                  highlightColor: Colors.black.withValues(alpha: 0.05),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: isEnabled
                          ? const LinearGradient(
                              colors: [
                                AppColors.goldLight,
                                AppColors.gold,
                                AppColors.goldDark,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.03),
                                Colors.white.withValues(alpha: 0.05),
                              ],
                            ),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: isEnabled
                            ? AppColors.goldLight.withValues(alpha: 0.5)
                            : AppColors.border.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: _isProcessing
                          ? SizedBox(
                              height: 20.w,
                              width: 20.w,
                              child: const CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'MADENİ İNŞA ET',
                              style: TextStyle(
                                color: isEnabled ? Colors.black : AppColors.textMuted,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
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
      final result = await ref.read(mineActionProvider).createMine(
        cityId: widget.selectedCity.id,
        typeId: _selectedType!['id'],
        name: _selectedType!['name'],
      );
      if (result['success'] == true) {
        if (mounted) {
          AppSnackbar.show(context, title: 'Başarılı', message: 'Maden inşaatı başladı!', type: SnackbarType.success);
          context.go('/mines');
        }
      } else {
        if (mounted) AppSnackbar.show(context, title: 'Hata', message: result['message'] ?? 'Hata oluştu.', type: SnackbarType.error);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

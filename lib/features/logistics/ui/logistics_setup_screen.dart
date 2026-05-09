import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_company_type_model.dart';

class LogisticsSetupScreen extends ConsumerStatefulWidget {
  const LogisticsSetupScreen({super.key});

  @override
  ConsumerState<LogisticsSetupScreen> createState() => _LogisticsSetupScreenState();
}

class _LogisticsSetupScreenState extends ConsumerState<LogisticsSetupScreen> {
  LogisticsCompanyTypeModel? _selectedType;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final playerAsync = ref.watch(playerStreamProvider);
    final typesAsync = ref.watch(logisticsCompanyTypesProvider);
    final companyAsync = ref.watch(playerLogisticsCompanyProvider);
    final constructionAsync = ref.watch(playerLogisticsConstructionProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Nakliye Firmasi Kur'),
            Expanded(
              child: companyAsync.when(
                data: (company) {
                  if (company != null) {
                    return _buildAlreadyExistsState(
                      title: company.name,
                      message: 'Bu oyuncunun zaten kurulu bir nakliye firmasi var.',
                    );
                  }

                  return constructionAsync.when(
                    data: (construction) {
                      if (construction != null) {
                        final params = construction['params'] as Map<String, dynamic>?;
                        return _buildAlreadyExistsState(
                          title: (params?['name'] ?? 'Nakliye Firmasi').toString(),
                          message: 'Nakliye firmanin insaati devam ediyor. Yonetim ekranindan takip edebilirsin.',
                        );
                      }

                      return playerAsync.when(
                        data: (player) => typesAsync.when(
                          data: (types) => _buildContent(
                            types: types,
                            playerCash: player?.cash ?? 0,
                            playerLevel: player?.level ?? 1,
                          ),
                          loading: _buildLoading,
                          error: (error, stack) => _buildError('Firma tipleri yuklenemedi: $error'),
                        ),
                        loading: _buildLoading,
                        error: (error, stack) => _buildError('Oyuncu bilgisi yuklenemedi.'),
                      );
                    },
                    loading: _buildLoading,
                    error: (error, stack) => _buildError('Insaat durumu okunamadi.'),
                  );
                },
                loading: _buildLoading,
                error: (error, stack) => _buildError('Firma bilgisi okunamadi.'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({
    required List<LogisticsCompanyTypeModel> types,
    required double playerCash,
    required int playerLevel,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIntroCard(),
          SizedBox(height: 16.h),
          _buildSectionTitle('Firma Tipi'),
          SizedBox(height: 8.h),
          ...types.map((type) => _buildTypeCard(type, playerCash, playerLevel)),
          SizedBox(height: 24.h),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              color: AppColors.cardBgLight,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(Icons.local_shipping, color: AppColors.gold, size: 28.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Text(
              'Nakliye firmasi, oyuncular arasi ticaret ve transfer sistemlerinin merkezi olacak. Bu yapi global calisacak; sadece firma tipini secip kurulumu baslatman yeterli.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.titleGold.copyWith(fontSize: 16.sp),
    );
  }

  Widget _buildTypeCard(
    LogisticsCompanyTypeModel type,
    double playerCash,
    int playerLevel,
  ) {
    final isSelected = _selectedType?.id == type.id;
    final levelLocked = playerLevel < type.requiredLevel;
    final cashLocked = playerCash < type.cost;
    final isLocked = levelLocked || cashLocked;

    return GestureDetector(
      onTap: isLocked ? null : () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold.withValues(alpha: 0.08) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Opacity(
          opacity: isLocked ? 0.55 : 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.apartment, color: AppColors.gold, size: 26.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        _buildMetaChip(Icons.payments, _formatMoney(type.cost)),
                        _buildMetaChip(Icons.star, 'Lv. ${type.requiredLevel}'),
                        _buildMetaChip(Icons.local_shipping, '${type.maxVehicleCount} arac'),
                        _buildMetaChip(Icons.local_gas_station, '${type.fuelCapacity} yakit'),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Insaat suresi ${type.constructionTimeMinutes} dakika',
                      style: AppTextStyles.body,
                    ),
                    if (isLocked) ...[
                      SizedBox(height: 6.h),
                      Text(
                        levelLocked ? 'Seviye yetersiz' : 'Nakit yetersiz',
                        style: TextStyle(
                          color: AppColors.red,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: AppColors.gold, size: 22.sp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight,
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.gold, size: 12.sp),
          SizedBox(width: 5.w),
          Text(text, style: AppTextStyles.body),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = _selectedType != null && !_isSubmitting;

    return SizedBox(
      width: double.infinity,
      height: 54.h,
      child: ElevatedButton(
        onPressed: canSubmit ? _handleSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : Text(
                'NAKLIYE FIRMASINI KUR',
                style: TextStyle(
                  color: canSubmit ? Colors.black : Colors.white.withValues(alpha: 0.35),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }

  Widget _buildAlreadyExistsState({
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_shipping, color: AppColors.gold, size: 42.sp),
              SizedBox(height: 12.h),
              Text(title, style: AppTextStyles.h2, textAlign: TextAlign.center),
              SizedBox(height: 8.h),
              Text(
                message,
                style: AppTextStyles.body.copyWith(height: 1.5),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go('/logistics'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.gold),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                  child: Text(
                    'YONETIME GIT',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.gold),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Text(
          message,
          style: TextStyle(color: AppColors.red, fontSize: 14.sp),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_selectedType == null) return;

    setState(() => _isSubmitting = true);

    try {
      final result = await ref.read(logisticsActionProvider).createLogisticsCompany(
            typeId: _selectedType!.id,
            name: _selectedType!.name,
          );

      if (!mounted) return;

      if (result['success'] == true) {
        ref.invalidate(playerLogisticsCompanyProvider);
        ref.invalidate(playerLogisticsConstructionProvider);
        ref.invalidate(logisticsCompanyListStreamProvider);

        AppSnackbar.show(
          context,
          title: 'Basarili',
          message: 'Nakliye firmasi insaati baslatildi.',
          type: SnackbarType.success,
        );
        context.go('/logistics');
        return;
      }

      AppSnackbar.show(
        context,
        title: 'Hata',
        message: (result['message'] ?? 'Islem basarisiz oldu.').toString(),
        type: SnackbarType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatMoney(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}

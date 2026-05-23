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
            const SecondaryTopBar(title: 'Lojistik Ağı Kur'),
            Expanded(
              child: companyAsync.when(
                data: (company) {
                  if (company != null) {
                    return _buildRedirectState(
                      title: company.name,
                      message: 'Zaten aktif bir lojistik firmanız bulunuyor.',
                    );
                  }

                  return constructionAsync.when(
                    data: (construction) {
                      if (construction != null) {
                        final params = construction['params'] as Map<String, dynamic>?;
                        return _buildRedirectState(
                          title: (params?['name'] ?? 'Lojistik Firması').toString(),
                          message: 'Lojistik merkezinizin inşaatı devam ediyor.',
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
                          error: (error, stack) => _buildError('Firma tipleri yüklenemedi.'),
                        ),
                        loading: _buildLoading,
                        error: (error, stack) => _buildError('Oyuncu bilgisi okunamadı.'),
                      );
                    },
                    loading: _buildLoading,
                    error: (error, stack) => _buildError('İnşaat durumu okunamadı.'),
                  );
                },
                loading: _buildLoading,
                error: (error, stack) => _buildError('Veri senkronizasyon hatası.'),
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
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 100.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPremiumIntro(),
          SizedBox(height: 24.h),
          _buildSectionTitle('OPERASYON MERKEZİ TİPİ'),
          SizedBox(height: 12.h),
          ...types.map((type) => _buildTypeCard(type, playerCash, playerLevel)),
          SizedBox(height: 24.h),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildPremiumIntro() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.cardBg, AppColors.cardBgLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60.w,
            height: 60.w,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.hub_outlined, color: AppColors.gold, size: 32.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lojistik Hub', style: AppTextStyles.h2.copyWith(color: AppColors.gold)),
                SizedBox(height: 4.h),
                Text(
                  'Ticaretin kalbi burada atar. Mal taşıyın, araç kiralayın ve imparatorluğunuzu büyütün.',
                  style: AppTextStyles.body.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w),
      child: Text(
        title,
        style: AppTextStyles.titleGold.copyWith(fontSize: 12.sp, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildTypeCard(LogisticsCompanyTypeModel type, double playerCash, int playerLevel) {
    final isSelected = _selectedType?.id == type.id;
    final levelLocked = playerLevel < type.requiredLevel;
    final cashLocked = playerCash < type.cost;
    final isLocked = levelLocked || cashLocked;

    return GestureDetector(
      onTap: isLocked ? null : () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold.withValues(alpha: 0.05) : AppColors.cardBg,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.1), blurRadius: 10)] : null,
        ),
        child: Opacity(
          opacity: isLocked ? 0.5 : 1.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: AppColors.cardBgLight,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: isSelected ? AppColors.gold.withValues(alpha: 0.3) : AppColors.border),
                ),
                child: Icon(Icons.apartment_rounded, color: AppColors.gold, size: 28.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.name, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w800)),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: [
                        _buildTypeChip(Icons.payments_outlined, _formatMoney(type.cost), cashLocked ? AppColors.red : AppColors.green),
                        _buildTypeChip(Icons.star_outline, 'Lv. ${type.requiredLevel}', levelLocked ? AppColors.red : AppColors.blue),
                        _buildTypeChip(Icons.local_shipping_outlined, '${type.maxVehicleCount} Kapasite', AppColors.gold),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, color: AppColors.textMuted, size: 12.sp),
                        SizedBox(width: 4.w),
                        Text('İnşaat: ${type.constructionTimeMinutes} Dakika', style: AppTextStyles.body.copyWith(fontSize: 11.sp)),
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: AppColors.gold, size: 24.sp),
              if (isLocked) Icon(Icons.lock_outline, color: AppColors.red.withValues(alpha: 0.7), size: 20.sp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10.sp),
          SizedBox(width: 4.w),
          Text(label, style: TextStyle(color: color, fontSize: 9.sp, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = _selectedType != null && !_isSubmitting;

    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: canSubmit ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5))] : null,
      ),
      child: ElevatedButton(
        onPressed: canSubmit ? _handleSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          disabledBackgroundColor: AppColors.border,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
            : Text(
                'MERKEZİ KURMAYI BAŞLAT',
                style: TextStyle(color: Colors.black, fontSize: 14.sp, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
      ),
    );
  }

  Widget _buildRedirectState({required String title, required String message}) {
    return Center(
      child: Container(
        margin: EdgeInsets.all(24.w),
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: AppColors.borderGold.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_outlined, color: AppColors.gold, size: 48.sp),
            SizedBox(height: 16.h),
            Text(title, style: AppTextStyles.h2, textAlign: TextAlign.center),
            SizedBox(height: 8.h),
            Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/logistics'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardBgLight,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r), side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5))),
                ),
                child: Text('YÖNETİM EKRANINA GİT', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() => const Center(child: CircularProgressIndicator(color: AppColors.gold));
  Widget _buildError(String m) => Center(child: Text(m, style: TextStyle(color: AppColors.red)));

  Future<void> _handleSubmit() async {
    if (_selectedType == null) return;
    setState(() => _isSubmitting = true);
    try {
      final res = await ref.read(logisticsActionProvider).createLogisticsCompany(typeId: _selectedType!.id, name: _selectedType!.name);
      if (res['success'] == true) {
        ref.invalidate(playerLogisticsCompanyProvider);
        ref.invalidate(playerLogisticsConstructionProvider);
        AppSnackbar.show(context, title: 'Başarılı', message: 'İnşaat başlatıldı.', type: SnackbarType.success);
        context.go('/logistics');
      } else {
        AppSnackbar.show(context, title: 'Hata', message: res['message'] ?? 'Islem basarisiz.', type: SnackbarType.error);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _formatMoney(double a) => a >= 1000000 ? '${(a/1000000).toStringAsFixed(1)}M' : (a >= 1000 ? '${(a/1000).toStringAsFixed(1)}K' : a.toStringAsFixed(0));
}

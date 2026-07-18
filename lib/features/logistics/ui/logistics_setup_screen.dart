import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/logistics/models/logistics_company_type_model.dart';

class LogisticsSetupScreen extends ConsumerStatefulWidget {
  const LogisticsSetupScreen({super.key});

  @override
  ConsumerState<LogisticsSetupScreen> createState() =>
      _LogisticsSetupScreenState();
}

class _LogisticsSetupScreenState extends ConsumerState<LogisticsSetupScreen> {
  LogisticsCompanyTypeModel? _selectedType;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final playerAsync = ref.watch(playerProvider);
    final typesAsync = ref.watch(logisticsCompanyTypesProvider);
    final companyAsync = ref.watch(playerLogisticsCompanyProvider);
    final constructionAsync = ref.watch(playerLogisticsConstructionProvider);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryTopBar(title: 'Lojistik Agi Kur'),
            Expanded(
              child: companyAsync.when(
                data: (company) {
                  if (company != null) {
                    return _buildRedirectState(
                      title: company.name,
                      message: 'Zaten aktif bir lojistik firmaniz bulunuyor.',
                    );
                  }

                  return constructionAsync.when(
                    data: (construction) {
                      if (construction != null) {
                        final params =
                            construction['params'] is Map<String, dynamic>
                            ? construction['params'] as Map<String, dynamic>
                            : construction['params'] is Map
                                ? Map<String, dynamic>.from(
                                    construction['params'] as Map,
                                  )
                                : null;
                        return _buildRedirectState(
                          title:
                              (params?['name'] ?? 'Lojistik Firmasi').toString(),
                          message:
                              'Lojistik merkezinizin insaati devam ediyor.',
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
                          error: (error, stack) =>
                              _buildError('Firma tipleri yuklenemedi.'),
                        ),
                        loading: _buildLoading,
                        error: (error, stack) =>
                            _buildError('Oyuncu bilgisi okunamadi.'),
                      );
                    },
                    loading: _buildLoading,
                    error: (error, stack) =>
                        _buildError('Insaat durumu okunamadi.'),
                  );
                },
                loading: _buildLoading,
                error: (error, stack) =>
                    _buildError('Veri senkronizasyon hatasi.'),
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
      padding: EdgeInsets.fromLTRB(5.w, 12.h, 5.w, 100.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPremiumIntro(),
          SizedBox(height: 24.h),
          _buildSectionTitle('OPERASYON MERKEZI TIPI'),
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
            child: Icon(AppIcons.hubOutlined, color: AppColors.gold, size: AppIconSizes.display),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lojistik Hub',
                  style: AppTextStyles.h2.standardCopyWith(color: AppColors.gold),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Ticaretin kalbi burada atar. Mal tasiyin, arac kiralayin ve imparatorlugunuzu buyutun.',
                  style: AppTextStyles.body.standardCopyWith(height: 1.4),
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
        style: AppTextStyles.titleGold.standardCopyWith(
          fontSize: AppTypography.body,
          letterSpacing: 1.2,
        ),
      ),
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
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.05)
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? AppColors.gold : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ]
              : null,
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
                  border: Border.all(
                    color: isSelected
                        ? AppColors.gold.withValues(alpha: 0.3)
                        : AppColors.border,
                  ),
                ),
                child: Icon(
                  AppIcons.apartmentRounded,
                  color: AppColors.gold,
                  size: AppIconSizes.xLarge,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.name,
                      style: AppTextStyles.h2.standardCopyWith(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.titleLarge,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: [
                        _buildTypeChip(
                          AppIcons.paymentsOutlined,
                          _formatMoney(type.cost),
                          cashLocked ? AppColors.red : AppColors.green,
                        ),
                        _buildTypeChip(
                          AppIcons.starOutline,
                          'Lv. ${type.requiredLevel}',
                          levelLocked ? AppColors.red : AppColors.blue,
                        ),
                        _buildTypeChip(
                          AppIcons.localShippingOutlined,
                          '${type.maxVehicleCount} Kapasite',
                          AppColors.gold,
                        ),
                        _buildTypeChip(
                          AppIcons.gasMeterOutlined,
                          '${type.fuelCapacity} L Yakit',
                          AppColors.warning,
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Icon(
                          AppIcons.timerOutlined,
                          color: AppColors.textMuted,
                          size: AppIconSizes.xSmall,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'Insaat: ${type.constructionTimeMinutes} Dakika',
                          style: AppTextStyles.body.standardCopyWith(fontSize: AppTypography.bodySmall),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(AppIcons.checkCircle, color: AppColors.gold, size: AppIconSizes.large),
              if (isLocked)
                Icon(
                  AppIcons.lockOutline,
                  color: AppColors.red.withValues(alpha: 0.7),
                  size: AppIconSizes.medium,
                ),
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
          Icon(icon, color: color, size: AppIconSizes.xxSmall),
          SizedBox(width: 4.w),
          Text(
            label,
            style: AppTextStyles.caption.standardCopyWith(
              color: color,
              fontSize: AppTypography.caption,
              fontWeight: FontWeight.bold,
            ),
          ),
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
        boxShadow: canSubmit
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: canSubmit ? _handleSubmit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          disabledBackgroundColor: AppColors.border,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 24,
                height: 24,
                child: AppLoadingIndicator(
                  color: AppColors.textOnAccent,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                'MERKEZI KURMAYI BASLAT',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textOnAccent,
                  fontSize: AppTypography.title,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }

  Widget _buildRedirectState({
    required String title,
    required String message,
  }) {
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
            Icon(
              AppIcons.verifiedUserOutlined,
              color: AppColors.gold,
              size: AppIconSizes.hero,
            ),
            SizedBox(height: 16.h),
            Text(title, style: AppTextStyles.h2, textAlign: TextAlign.center),
            SizedBox(height: 8.h),
            Text(
              message,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/logistics'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardBgLight,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    side: BorderSide(
                      color: AppColors.gold.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Text(
                  'YONETIM EKRANINA GIT',
                  style: AppTextStyles.body.standardCopyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() =>
      Center(child: AppLoadingIndicator(color: AppColors.gold));

  Widget _buildError(String message) =>
      Center(
        child: Text(
          message,
          style: AppTextStyles.body.standardCopyWith(color: AppColors.red),
        ),
      );

  Future<void> _handleSubmit() async {
    if (_selectedType == null) return;

    setState(() => _isSubmitting = true);
    try {
      final res = await ref.read(logisticsActionProvider).createLogisticsCompany(
            typeId: _selectedType!.id,
            name: _selectedType!.name,
            syncProviders: false,
          );
      if (!mounted) return;

      if (res['success'] == true) {
        ref.invalidate(playerLogisticsCompanyProvider);
        ref.invalidate(playerLogisticsConstructionProvider);
        AppSnackbar.show(
          context,
          title: 'Basarili',
          message: 'Insaat baslatildi.',
          type: SnackbarType.success,
        );
        context.go('/logistics');
      } else {
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: res['message'] ?? 'Islem basarisiz.',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatMoney(double amount) {
    return AppMoney.compact(amount);
  }
}

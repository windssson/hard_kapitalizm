import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/data/static_catalog_provider.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/app_progress.dart';
import 'package:hard_kapitalizm/core/utils/app_money.dart';
import 'package:hard_kapitalizm/core/widgets/secondary_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/type_product_preview.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/models/product_model.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/core/models/mutation/player_changes.dart';
import 'package:hard_kapitalizm/core/utils/app_snackbar.dart';
import 'package:hard_kapitalizm/core/widgets/tutorial_provider.dart';

// Modül özel listelerinin güncellenmesi için provider importları
import 'package:hard_kapitalizm/features/farm/data/farm_provider.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';
import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';

class BuildingTypeSelectionScreen extends ConsumerStatefulWidget {
  final CityModel selectedCity;
  final String buildingKind; // 'farm', 'field', 'mine', 'factory', 'store', 'warehouse'

  const BuildingTypeSelectionScreen({
    super.key,
    required this.selectedCity,
    required this.buildingKind,
  });

  @override
  ConsumerState<BuildingTypeSelectionScreen> createState() =>
      _BuildingTypeSelectionScreenState();
}

class _BuildingTypeSelectionScreenState
    extends ConsumerState<BuildingTypeSelectionScreen> {
  Map<String, dynamic>? _selectedType;
  bool _isProcessing = false;

  String _getBuildingKindTitle() {
    switch (widget.buildingKind) {
      case 'farm':
        return 'Tarla Seçimi';
      case 'field':
        return 'Çiftlik Seçimi';
      case 'mine':
        return 'Maden Ocağı Seçimi';
      case 'factory':
        return 'Fabrika Seçimi';
      case 'store':
        return 'Mağaza Seçimi';
      case 'warehouse':
        return 'Depo Seçimi';
      default:
        return 'Bina Seçimi';
    }
  }

  String _getEstablishButtonText() {
    switch (widget.buildingKind) {
      case 'farm':
        return 'TARLAYI İNŞA ET';
      case 'field':
        return 'ÇİFTLİĞİ İNŞA ET';
      case 'mine':
        return 'MADENİ İNŞA ET';
      case 'factory':
        return 'FABRİKAYI İNŞA ET';
      case 'store':
        return 'MAĞAZAYI KUR';
      case 'warehouse':
        return 'DEPOYU İNŞA ET';
      default:
        return 'BİNAYI İNŞA ET';
    }
  }

  String _getBuildingKindDisplayName() {
    switch (widget.buildingKind) {
      case 'farm':
        return 'Tarla';
      case 'field':
        return 'Çiftlik';
      case 'mine':
        return 'Maden';
      case 'factory':
        return 'Fabrika';
      case 'store':
        return 'Mağaza';
      case 'warehouse':
        return 'Depo';
      default:
        return 'Bina';
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerAsync = ref.watch(playerProvider);
    final catalogsAsync = ref.watch(staticCatalogsProvider);
    final saturationsAsync = widget.buildingKind == 'store'
        ? ref.watch(cityStoreSaturationsProvider(widget.selectedCity.id))
        : const AsyncValue.data(<Map<String, dynamic>>[]);

    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            SecondaryTopBar(
              title: '${widget.selectedCity.name} - ${_getBuildingKindTitle()}',
            ),
            Expanded(
              child: playerAsync.when(
                data: (player) => catalogsAsync.when(
                  data: (catalogs) {
                    final saturations = saturationsAsync.value ?? const [];
                    // buildingKind'e göre ilgili kataloğu seç
                    final List<dynamic> rawTypes;
                    switch (widget.buildingKind) {
                      case 'farm':
                        rawTypes = catalogs.farmTypes;
                        break;
                      case 'field':
                        rawTypes = catalogs.fieldTypes;
                        break;
                      case 'mine':
                        rawTypes = catalogs.mineTypes;
                        break;
                      case 'factory':
                        rawTypes = catalogs.factoryTypes;
                        break;
                      case 'warehouse':
                        rawTypes = catalogs.warehouseTypes;
                        break;
                      case 'store':
                        rawTypes = catalogs.storeTypes.map((t) => t.toJson()).toList();
                        break;
                      default:
                        rawTypes = [];
                    }

                    return _buildTypeList(
                      rawTypes,
                      catalogs.products,
                      (player?.cash ?? 0).toDouble(),
                      player?.level ?? 1,
                      saturations,
                    );
                  },
                  loading: () => Center(
                    child: AppLoadingIndicator(color: AppColors.gold),
                  ),
                  error: (error, stack) => const Center(
                    child: Text('Katalog verileri yüklenemedi.'),
                  ),
                ),
                loading: () => Center(
                  child: AppLoadingIndicator(color: AppColors.gold),
                ),
                error: (error, stack) => const Center(
                  child: Text('Oyuncu bilgileri yüklenemedi.'),
                ),
              ),
            ),
            _buildActionPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeList(
    List<dynamic> types,
    List<ProductModel> products,
    double playerCash,
    int playerLevel, [
    List<Map<String, dynamic>> saturations = const [],
  ]) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      itemCount: types.length,
      itemBuilder: (context, index) {
        final type = Map<String, dynamic>.from(types[index] as Map);
        final isSelected = _selectedType?['id'] == type['id'];

        final bool levelLocked = playerLevel < (type['required_level'] ?? 1);
        final bool cashLocked = playerCash < (type['cost'] ?? 0);
        final bool isLocked = levelLocked || cashLocked;

        final bool isManav = type['name'].toString().toLowerCase().contains('manav') ||
                             type['icon'].toString().toLowerCase().contains('manav');

        final saturationData = widget.buildingKind == 'store'
            ? saturations.cast<Map<String, dynamic>?>().firstWhere(
                (s) => s?['store_type_id'] == type['id'],
                orElse: () => null,
              )
            : null;

        return GestureDetector(
          key: isManav ? TutorialKeys.buildingTypeManavKey : null,
          onTap: isLocked
              ? null
              : () {
                  setState(() => _selectedType = type);
                  if (ref.read(tutorialProvider).step == TutorialStep.selectManav && isManav) {
                    ref.read(tutorialProvider.notifier).setStep(TutorialStep.confirmManavBuild);
                  }
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.gold.withValues(alpha: 0.1)
                  : AppColors.cardBg,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isSelected
                    ? AppColors.gold
                    : AppColors.border.withValues(alpha: isLocked ? 0.2 : 0.5),
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
                          border: Border.all(
                            color: isSelected ? AppColors.gold : AppColors.border,
                          ),
                        ),
                        child: CachedAssetImage(
                          fileName: (type['icon'] ?? '${widget.buildingKind}.webp').toString(),
                          fit: BoxFit.contain,
                        ),
                      ),
                      if (isLocked)
                        Container(
                          width: 65.w,
                          height: 65.w,
                          decoration: BoxDecoration(
                            color: AppFx.panelWash(0.45),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            AppIcons.lock,
                            color: AppColors.gold,
                            size: AppIconSizes.large,
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
                          (type['name'] ?? 'Bilinmeyen Tesis').toString(),
                          style: AppTextStyles.h2.standardCopyWith(
                            color: isSelected ? AppColors.gold : AppColors.white,
                            fontSize: AppTypography.titleLarge,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.buildingKind == 'store' && saturationData != null) ...[
                          SizedBox(height: 5.h),
                          _buildSaturationBadge(saturationData),
                        ],
                        if (_getCategoryBonus(type['name'] ?? '') > 1.0) ...[
                          SizedBox(height: 6.h),
                          _buildBonusBadge(_getCategoryBonus(type['name'] ?? '')),
                        ],
                        SizedBox(height: 8.h),
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 4.h,
                          children: [
                            _buildDetailChip(
                              AppIcons.monetizationOn,
                              _formatMoney((type['cost'] ?? 0).toDouble()),
                              cashLocked ? AppColors.red : AppColors.gold,
                            ),
                            if (type['max_slot_count'] != null)
                              _buildDetailChip(
                                AppIcons.layers,
                                '${type['max_slot_count']} Slot',
                                AppColors.blue,
                              ),
                            if (type['output_capacity'] != null)
                              _buildDetailChip(
                                AppIcons.inventory2Outlined,
                                '${type['output_capacity']} Kap.',
                                AppColors.blue,
                              ),
                            if (type['construction_time_minutes'] != null)
                              _buildDetailChip(
                                AppIcons.schedule,
                                '${type['construction_time_minutes']} Dk.',
                                AppColors.blue,
                              ),
                            _buildDetailChip(
                              AppIcons.stars,
                              'Lv. ${type['required_level'] ?? 1}',
                              levelLocked ? AppColors.red : AppColors.info,
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        TypeProductPreview(
                          title: 'Üretebileceği / Satabileceği Ürünler',
                          products: resolveAcceptedProducts(
                            parseAcceptedProductIds(type['accepted_product_ids'] ?? type['sellable_product_ids']),
                            products,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      AppIcons.checkCircle,
                      color: AppColors.gold,
                      size: AppIconSizes.large,
                    ),
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
        Icon(icon, color: color, size: AppIconSizes.xxSmall),
        SizedBox(width: 4.w),
        Text(
          label,
          style: AppTextStyles.caption.standardCopyWith(
            color: AppColors.textMuted,
            fontSize: AppTypography.label,
          ),
        ),
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
        boxShadow: [
          BoxShadow(
            color: AppFx.shadow(0.54),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedType != null) ...[
            Text(
              '${widget.selectedCity.name} şehrinde ${_selectedType!['name']} inşa edilecek.',
              style: AppTextStyles.body.standardCopyWith(
                color: AppColors.textMuted,
                fontSize: AppTypography.bodySmall,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
          ],
          SizedBox(
            width: double.infinity,
            height: 55.h,
            child: ElevatedButton(
              key: TutorialKeys.buildingTypeConfirmKey,
              onPressed: (_selectedType != null && !_isProcessing)
                  ? _handleEstablish
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: _isProcessing
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: AppLoadingIndicator(
                        color: AppColors.textOnAccent,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _getEstablishButtonText(),
                      style: AppTextStyles.button.standardCopyWith(
                        color: _selectedType != null
                            ? AppColors.textOnAccent
                            : AppColors.white.withValues(alpha: 0.30),
                        fontSize: AppTypography.title,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(double val) {
    return AppMoney.compact(val);
  }

  Future<void> _handleEstablish() async {
    if (_selectedType == null) return;
    setState(() => _isProcessing = true);
    
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: 'Oturum açılmamış.',
          type: SnackbarType.error,
        );
        return;
      }

      final String kind = widget.buildingKind;
      final String typeId = _selectedType!['id'].toString();
      final String name = _selectedType!['name'].toString();

      final response = await supabase.rpc(
        'start_building_construction',
        params: {
          'p_player_id': user.id,
          'p_city_id': widget.selectedCity.id,
          'p_building_kind': kind,
          'p_type_id': typeId,
          'p_name': name,
        },
      );

      final result = Map<String, dynamic>.from(response as Map);

      if (result['success'] == true) {
        if (!mounted) return;

        // Player cash'ini invalidate yerine patch ile anında güncelle
        final playerChanges = PlayerChanges.tryExtract(result);
        if (playerChanges != null) {
          ref.read(playerProvider.notifier).applyChanges(playerChanges);
        } else {
          ref.invalidate(playerProvider); // fallback: changed.player yoksa yenile
        }

        switch (kind) {
          case 'farm':
            ref.invalidate(farmListProvider);
            ref.invalidate(farmConstructionProvider);
            break;
          case 'field':
            ref.invalidate(fieldListProvider);
            ref.invalidate(fieldConstructionProvider);
            break;
          case 'mine':
            ref.invalidate(mineListProvider);
            ref.invalidate(mineConstructionProvider);
            break;
          case 'factory':
            ref.invalidate(factoryListProvider);
            ref.invalidate(factoryConstructionProvider);
            break;
          case 'store':
            await ref.read(storesListProvider.notifier).refresh();
            break;
          case 'warehouse':
            await ref.read(warehouseListProvider.notifier).refresh();
            break;
        }

        if (!mounted) return;

        AppSnackbar.show(
          context,
          title: 'Başarılı',
          message: '${_getBuildingKindDisplayName()} inşaatı başarıyla başladı!',
          type: SnackbarType.success,
        );

        if (ref.read(tutorialProvider).step == TutorialStep.confirmManavBuild) {
          ref.read(tutorialProvider.notifier).setStep(TutorialStep.clickQuickFinish);
        }

        final String redirectRoute = kind == 'store' ? '/store' : '/${kind}s';
        context.go(redirectRoute);
      } else {
        if (mounted) {
          AppSnackbar.show(
            context,
            title: 'Hata',
            message: result['message'] ?? 'İşlem başarısız.',
            type: SnackbarType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: e.toString(),
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  double _getCategoryBonus(String typeName) {
    String clean = typeName.toLowerCase().trim();
    clean = clean
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('i̇', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll('/', '_')
        .replaceAll('&', 've');
        
    final String key = 'bonus_$clean';
    return widget.selectedCity.categoryBonuses[key] ?? 1.0;
  }

  Widget _buildBonusBadge(double bonus) {
    final bool isGolden = bonus >= 1.30;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isGolden
            ? AppColors.gold.withValues(alpha: 0.20)
            : Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: isGolden ? AppColors.gold : Colors.green,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.trending_up,
            color: isGolden ? AppColors.gold : Colors.green,
            size: 14.sp,
          ),
          SizedBox(width: 4.w),
          Text(
            '+%${((bonus - 1.0) * 100).toInt()} Katsayı Avantajı',
            style: AppTextStyles.caption.standardCopyWith(
              color: isGolden ? AppColors.gold : Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 10.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaturationBadge(Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'balanced';
    final label = data['status_label'] as String? ?? 'Dengeli Pazar';
    final currentCount = data['current_count'] ?? 0;
    final idealCapacity = data['ideal_capacity'] ?? 1;
    final saturationPct = (data['saturation_pct'] ?? 0).toString();

    Color badgeColor;
    IconData badgeIcon;
    if (status == 'opportunity') {
      badgeColor = Colors.green;
      badgeIcon = Icons.trending_up_rounded;
    } else if (status == 'balanced') {
      badgeColor = AppColors.gold;
      badgeIcon = Icons.balance_rounded;
    } else if (status == 'competitive') {
      badgeColor = Colors.orange;
      badgeIcon = Icons.local_fire_department_rounded;
    } else {
      badgeColor = Colors.redAccent;
      badgeIcon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1.w),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, color: badgeColor, size: 13.sp),
          SizedBox(width: 5.w),
          Flexible(
            child: Text(
              '$label • $currentCount/$idealCapacity Mağaza (%$saturationPct)',
              style: AppTextStyles.caption.standardCopyWith(
                color: badgeColor,
                fontSize: 9.5.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

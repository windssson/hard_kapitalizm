import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/tutorial_provider.dart';

class TutorialOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const TutorialOverlay({super.key, required this.child});

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay>
    with WidgetsBindingObserver {
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateTargetRect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _updateTargetRect();
  }

  @override
  void didUpdateWidget(covariant TutorialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTargetRect();
  }

  void _updateTargetRect() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final step = ref.read(tutorialProvider).step;
      final key = _getKeyForStep(step);
      if (key == null) {
        if (_targetRect != null) {
          setState(() {
            _targetRect = null;
          });
        }
        return;
      }

      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _updateTargetRect();
        });
        return;
      }

      final size = renderBox.size;
      final offset = renderBox.localToGlobal(Offset.zero);
      final rect = Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);

      if (_targetRect != rect) {
        setState(() {
          _targetRect = rect;
        });
      }
    });
  }

  GlobalKey? _getKeyForStep(TutorialStep step) {
    switch (step) {
      case TutorialStep.clickFirstStore:
        return TutorialKeys.homeStoresModuleKey;
      case TutorialStep.clickStoreFab:
        return TutorialKeys.storeScreenFabKey;
      case TutorialStep.selectCity:
        return null;
      case TutorialStep.confirmCity:
        return TutorialKeys.citySelectionConfirmKey;
      case TutorialStep.selectManav:
        return TutorialKeys.buildingTypeManavKey;
      case TutorialStep.confirmManavBuild:
        return TutorialKeys.buildingTypeConfirmKey;
      case TutorialStep.clickQuickFinish:
        if (TutorialKeys.quickFinishDialogConfirmKey.currentContext != null) {
          return TutorialKeys.quickFinishDialogConfirmKey;
        }
        return TutorialKeys.constructionGoldFinishKey;
      case TutorialStep.clickEnterStore:
        return TutorialKeys.newStoreItemKey;
      case TutorialStep.clickSelectProduct:
        if (TutorialKeys.productSelectionFirstItemKey.currentContext != null) {
          return TutorialKeys.productSelectionFirstItemKey;
        }
        return TutorialKeys.storeSlotSelectProductKey;
      case TutorialStep.clickSetPrice:
        if (TutorialKeys.priceDialogConfirmKey.currentContext != null) {
          return TutorialKeys.priceDialogConfirmKey;
        }
        return TutorialKeys.storeSlotPriceKey;
      case TutorialStep.clickAddStock:
        return TutorialKeys.storeSlotOrderStockKey;
      default:
        return null;
    }
  }

  String _getAssistantText(TutorialStep step) {
    switch (step) {
      case TutorialStep.welcome:
        return 'Hoş geldin patron! Birlikte büyük bir ticaret imparatorluğu kuracağız. Hadi ilk perakende mağazamızı açalım!';
      case TutorialStep.clickFirstStore:
        return 'Öncelikle Mağazalar menüsüne tıklayarak mevcut yatırımlarımızı yönetelim.';
      case TutorialStep.clickStoreFab:
        return 'Henüz hiç mağazamız yok. Yeni bir mağaza kurmak için sağ alttaki "+" (Mağaza Kur) butonuna tıkla.';
      case TutorialStep.selectCity:
        return 'Mağazayı kurmak istediğin şehri haritadan veya yukarıdaki listeden özgürce seç.';
      case TutorialStep.confirmCity:
        return 'Harika seçim! Şimdi "Devam Et" butonuna tıklayarak mağaza türünü seçmeye geçelim.';
      case TutorialStep.selectManav:
        return 'İlk mağazamız olarak halkın en çok ihtiyaç duyduğu taze sebze ve meyveleri satacağımız "Manav"ı seç.';
      case TutorialStep.confirmManavBuild:
        return 'Harika! "MAĞAZAYI KUR" butonuna tıklayarak manav inşaatını başlatalım.';
      case TutorialStep.clickQuickFinish:
        return 'Mağazamızın kurulması normalde zaman alır. Ama biz bir kapitalistiz! Yıldız (Gold) harcayarak inşaatı hemen tamamlayalım.';
      case TutorialStep.clickEnterStore:
        return 'Süper! Manavımız kuruldu. Yönetim sayfasına girmek için mağazanın üzerine tıkla.';
      case TutorialStep.clickSelectProduct:
        if (TutorialKeys.productSelectionFirstItemKey.currentContext != null) {
          return 'Harika! Şimdi listeden satmak istediğin ilk taze meyveyi (örn. Elma) seç.';
        }
        return 'Manavımızın rafları şu an boş! İlk olarak "Ürün Seç" butonuna tıklayarak rafa taze bir meyve/sebze koyalım.';
      case TutorialStep.clickSetPrice:
        if (TutorialKeys.priceDialogConfirmKey.currentContext != null) {
          return 'Hedef satış fiyatını belirledikten sonra "Kaydet" butonuna tıkla.';
        }
        return 'Tebrikler! Ürünü rafa dizdin. Şimdi ürünün birim satış fiyatını belirlemek için fiyat kutusuna tıkla ve satış fiyatını ayarla.';
      case TutorialStep.clickAddStock:
        return 'Raflarımız hazır! Şimdi Pazar\'dan veya depodan ilk taze stok siparişimizi vermek için "Stok Ekle" butonuna tıkla.';
      case TutorialStep.finished:
        return 'Tebrikler patron! Mağazanı kurdun, ürününü yerleştirdin, fiyatını belirledin ve tedarik zincirini başlattın. İşte sana şirket başlangıç sermayesi!';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tutorialState = ref.watch(tutorialProvider);
    final step = tutorialState.step;

    if (step == TutorialStep.none) {
      return widget.child;
    }

    ref.listen(tutorialProvider, (previous, next) {
      _updateTargetRect();
    });

    final hasTarget = _targetRect != null;
    final isFullscreenMessage =
        step == TutorialStep.welcome || step == TutorialStep.finished;
    final screenSize = MediaQuery.of(context).size;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _updateTargetRect();
        return false;
      },
      child: Stack(
        children: [
          widget.child,
          if (!isFullscreenMessage && step != TutorialStep.selectCity)
            IgnorePointer(
              ignoring: true,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.82),
                  BlendMode.srcOut,
                ),
                child: Stack(
                  children: [
                    Container(color: Colors.transparent),
                    if (hasTarget)
                      Positioned.fromRect(
                        rect: _targetRect!.inflate(6.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          else if (isFullscreenMessage)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.read(tutorialProvider.notifier).completeStep(step);
              },
              child: Container(color: Colors.black.withValues(alpha: 0.85)),
            ),
          if (!isFullscreenMessage && step != TutorialStep.selectCity) ...[
            if (hasTarget) ..._buildTargetBarriers(_targetRect!, screenSize),
          ],
          _buildAssistantCard(step),
        ],
      ),
    );
  }

  List<Widget> _buildTargetBarriers(Rect targetRect, Size screenSize) {
    final inflated = targetRect.inflate(6.0);
    final topHeight = inflated.top.clamp(0.0, screenSize.height);
    final bottomTop = inflated.bottom.clamp(0.0, screenSize.height);
    final leftWidth = inflated.left.clamp(0.0, screenSize.width);
    final rightLeft = inflated.right.clamp(0.0, screenSize.width);
    final targetHeight = inflated.height.clamp(0.0, screenSize.height);

    Widget blocker() =>
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {});

    return [
      if (topHeight > 0)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: topHeight,
          child: blocker(),
        ),
      if (bottomTop < screenSize.height)
        Positioned(
          left: 0,
          right: 0,
          top: bottomTop,
          bottom: 0,
          child: blocker(),
        ),
      if (leftWidth > 0)
        Positioned(
          left: 0,
          width: leftWidth,
          top: topHeight,
          height: targetHeight,
          child: blocker(),
        ),
      if (rightLeft < screenSize.width)
        Positioned(
          left: rightLeft,
          right: 0,
          top: topHeight,
          height: targetHeight,
          child: blocker(),
        ),
    ];
  }

  Widget _buildAssistantCard(TutorialStep step) {
    final text = _getAssistantText(step);
    if (text.isEmpty) return const SizedBox.shrink();

    final targetRect = _targetRect;
    final bool hasTargetRect = targetRect != null;
    final bool isTop = hasTargetRect && targetRect.top < 380.h;
    final isFullscreenMessage =
        step == TutorialStep.welcome || step == TutorialStep.finished;

    Widget cardContent = Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.7),
          width: 1.5.w,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.18),
            blurRadius: 24.r,
            spreadRadius: 1.r,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 30.r,
            spreadRadius: 4.r,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.cardBg,
                AppColors.cardBgLight.withValues(alpha: 0.85),
              ],
            ),
          ),
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst Başlık: Avatar + İsim & Rozet + Atla Butonu
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52.w,
                    height: 52.w,
                    padding: EdgeInsets.all(2.5.w),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.gold,
                          AppColors.borderGold,
                          AppColors.goldLight,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.35),
                          blurRadius: 12.r,
                          spreadRadius: 1.r,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: AppColors.cardBg,
                      child: Icon(
                        AppIcons.person,
                        color: AppColors.gold,
                        size: 28.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Asistan Leyla',
                              style: AppTextStyles.h2.standardCopyWith(
                                color: AppColors.gold,
                                fontSize: AppTypography.titleLarge,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 7.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.4),
                                  width: 1.w,
                                ),
                              ),
                              child: Text(
                                'DANIŞMAN',
                                style: AppTextStyles.caption.standardCopyWith(
                                  color: AppColors.gold,
                                  fontSize: AppTypography.micro,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Container(
                              width: 6.w,
                              height: 6.w,
                              decoration: BoxDecoration(
                                color: AppColors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Canlı Rehberlik Modu',
                              style: AppTextStyles.caption.standardCopyWith(
                                color: AppColors.textMuted,
                                fontSize: AppTypography.micro,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isFullscreenMessage)
                    GestureDetector(
                      onTap: () {
                        ref.read(tutorialProvider.notifier).finishTutorial();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardBgLight.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: AppColors.textMuted.withValues(alpha: 0.3),
                            width: 1.w,
                          ),
                        ),
                        child: Text(
                          'Atla ✕',
                          style: AppTextStyles.caption.standardCopyWith(
                            color: AppColors.textMuted,
                            fontSize: AppTypography.micro,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 12.h),
              Divider(
                color: AppColors.borderGold.withValues(alpha: 0.25),
                height: 1,
              ),
              SizedBox(height: 12.h),
              // Mesaj Gövdesi
              Text(
                text,
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.bodyLarge,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // Tam Ekran Mesajları İçin Özel Buton
              if (step == TutorialStep.finished) ...[
                SizedBox(height: 14.h),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildRewardChip('💰 +25.000 ₺', AppColors.green),
                      _buildRewardChip('⭐ +10 Yıldız', AppColors.gold),
                      _buildRewardChip('🏆 +100 XP', AppColors.blue),
                    ],
                  ),
                ),
              ],
              if (isFullscreenMessage) ...[
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(tutorialProvider.notifier).completeStep(step);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      elevation: 6,
                      shadowColor: AppColors.gold.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          step == TutorialStep.finished
                              ? 'Ödülleri Al & Başla 🚀'
                              : 'Devam Et ➔',
                          style: AppTextStyles.button.standardCopyWith(
                            color: AppColors.textOnAccent,
                            fontSize: AppTypography.bodyLarge,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    cardContent = DefaultTextStyle(
      style: const TextStyle(decoration: TextDecoration.none),
      child: Material(type: MaterialType.transparency, child: cardContent),
    );

    if (isFullscreenMessage) {
      return Center(child: cardContent);
    }

    if (!hasTargetRect) {
      return Positioned(
        left: 0,
        right: 0,
        bottom: 40.h,
        child: SafeArea(bottom: true, child: cardContent),
      );
    }

    return Positioned(
      left: 0,
      right: 0,
      top: isTop ? targetRect.bottom + 25.h : null,
      bottom: !isTop
          ? MediaQuery.of(context).size.height - targetRect.top + 20.h
          : null,
      child: SafeArea(top: isTop, bottom: !isTop, child: cardContent),
    );
  }

  Widget _buildRewardChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

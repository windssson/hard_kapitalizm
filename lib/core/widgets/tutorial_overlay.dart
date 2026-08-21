import 'dart:async';

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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  Rect? _targetRect;
  late final AnimationController _pulseController;
  Timer? _trackingTimer;
  GlobalKey? _lastEnsuredKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _startTracking();
  }

  @override
  void dispose() {
    _stopTracking();
    _pulseController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      _updateTargetRect();
    });
  }

  void _stopTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
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
    if (!mounted) return;
    final step = ref.read(tutorialProvider).step;
    if (step == TutorialStep.none) {
      if (_targetRect != null) {
        setState(() {
          _targetRect = null;
          _lastEnsuredKey = null;
        });
      }
      return;
    }

    final key = _getKeyForStep(step);
    if (key == null) {
      if (_targetRect != null) {
        setState(() {
          _targetRect = null;
        });
      }
      return;
    }

    final currentContext = key.currentContext;
    if (currentContext == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateTargetRect();
      });
      return;
    }

    final renderBox = currentContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || renderBox.size.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
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

    if (_lastEnsuredKey != key) {
      _lastEnsuredKey = key;
      Scrollable.ensureVisible(
        currentContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
      ).catchError((_) {});
    }
  }

  GlobalKey? _getKeyForStep(TutorialStep step) {
    GlobalKey? directKey;
    switch (step) {
      case TutorialStep.welcome:
      case TutorialStep.finished:
      case TutorialStep.none:
        return null;
      case TutorialStep.clickFirstStore:
        return TutorialKeys.homeStoresModuleKey;
      case TutorialStep.clickStoreFab:
        directKey = TutorialKeys.storeScreenFabKey;
        break;
      case TutorialStep.selectCity:
        return null;
      case TutorialStep.confirmCity:
        directKey = TutorialKeys.citySelectionConfirmKey;
        break;
      case TutorialStep.selectManav:
        directKey = TutorialKeys.buildingTypeManavKey;
        break;
      case TutorialStep.confirmManavBuild:
        directKey = TutorialKeys.buildingTypeConfirmKey;
        break;
      case TutorialStep.clickQuickFinish:
        if (TutorialKeys.quickFinishDialogConfirmKey.currentContext != null) {
          return TutorialKeys.quickFinishDialogConfirmKey;
        }
        directKey = TutorialKeys.constructionGoldFinishKey;
        break;
      case TutorialStep.clickEnterStore:
        directKey = TutorialKeys.newStoreItemKey;
        break;
      case TutorialStep.clickCreateShelf:
        if (TutorialKeys.storeEmptyShelfButtonKey.currentContext != null) {
          return TutorialKeys.storeEmptyShelfButtonKey;
        }
        directKey = TutorialKeys.storeQuickActionOpenSlotKey;
        break;
      case TutorialStep.clickGoToMarket:
        directKey = TutorialKeys.storeGoToMarketButtonKey;
        break;
      case TutorialStep.selectMarketWarehouse:
        directKey = TutorialKeys.marketWarehouseFirstItemKey;
        break;
      case TutorialStep.selectMarketProduct:
        directKey = TutorialKeys.marketProductFirstItemKey;
        break;
      case TutorialStep.clickMarketBuyListing:
        directKey = TutorialKeys.marketListingFirstAddKey;
        break;
      case TutorialStep.confirmMarketCartBuy:
        directKey = TutorialKeys.marketAddToCartConfirmKey;
        break;
      case TutorialStep.confirmMarketCheckout:
        if (TutorialKeys.marketCheckoutConfirmKey.currentContext != null) {
          return TutorialKeys.marketCheckoutConfirmKey;
        }
        directKey = TutorialKeys.marketCartLauncherKey;
        break;
      case TutorialStep.returnToStore:
        if (TutorialKeys.marketReturnToStoreKey.currentContext != null) {
          return TutorialKeys.marketReturnToStoreKey;
        }
        directKey = TutorialKeys.homeStoresModuleKey;
        break;
      case TutorialStep.clickSelectProduct:
        if (TutorialKeys.productSelectionFirstItemKey.currentContext != null) {
          return TutorialKeys.productSelectionFirstItemKey;
        }
        directKey = TutorialKeys.storeSlotSelectProductKey;
        break;
      case TutorialStep.clickSetPrice:
        if (TutorialKeys.priceDialogConfirmKey.currentContext != null) {
          return TutorialKeys.priceDialogConfirmKey;
        }
        directKey = TutorialKeys.storeSlotPriceKey;
        break;
      case TutorialStep.clickAddStock:
        if (TutorialKeys.stockRefillConfirmKey.currentContext != null) {
          return TutorialKeys.stockRefillConfirmKey;
        }
        directKey = TutorialKeys.storeSlotOrderStockKey;
        break;
    }

    if (directKey.currentContext != null) {
      return directKey;
    }

    // Ekran dışı akıllı geri yönlendirme (Örn: Kullanıcı ana sayfaya döndüyse veya oyunu kapatıp açtıysa)
    if (step != TutorialStep.welcome &&
        step != TutorialStep.finished &&
        step != TutorialStep.none &&
        step != TutorialStep.selectCity) {
      if (TutorialKeys.newStoreItemKey.currentContext != null) {
        return TutorialKeys.newStoreItemKey;
      }
      if (TutorialKeys.homeStoresModuleKey.currentContext != null) {
        return TutorialKeys.homeStoresModuleKey;
      }
    }

    return directKey;
  }

  String _getAssistantText(TutorialStep step) {
    final effectiveKey = _getKeyForStep(step);
    if (effectiveKey == TutorialKeys.homeStoresModuleKey &&
        step != TutorialStep.clickFirstStore &&
        step != TutorialStep.welcome &&
        step != TutorialStep.finished) {
      return 'Yarım kalan manav kurulumumuza devam etmek için "Mağazalar" menüsüne tıkla.';
    }
    if (effectiveKey == TutorialKeys.newStoreItemKey &&
        step != TutorialStep.clickEnterStore &&
        step != TutorialStep.welcome &&
        step != TutorialStep.finished) {
      return 'Manavımızın içine girerek kuruluma kaldığımız yerden devam edelim.';
    }

    switch (step) {
      case TutorialStep.welcome:
        return 'Hoş geldin patron! Ben danışmanın Leyla. Bu holdingde sıfırdan başlayıp Türkiye\'nin en büyük ticaret imparatorluğunu kuracağız. İlk gelir kapımızı açmak için perakende mağazamızı kuralım!';
      case TutorialStep.clickFirstStore:
        return 'Mağazalar; doğrudan şehirdeki tüketicilere perakende satış yaparak holdingimize düzenli nakit akışı ve kâr sağlayan ana gelir merkezimizdir. İncelemek için Mağazalar menüsüne tıkla.';
      case TutorialStep.clickStoreFab:
        return 'Her yeni mağaza, yeni bir ciro ve kâr kaynağı demektir. Şehirde yeni bir perakende işletmesi açmak için sağ alttaki "+" (Mağaza Kur) butonuna dokun.';
      case TutorialStep.selectCity:
        return 'Şehir seçimi çok kritiktir patron! Her şehrin nüfusu, vergi oranları ve tüketici talebi farklıdır. Yüksek potansiyelli bir şehir seçerek ilk yatırımını başlat.';
      case TutorialStep.confirmCity:
        return 'Harika bir lokasyon seçtin! Şehirdeki tüketici potansiyelini değerlendirmek için "Devam Et" butonuna tıklayarak sektör seçimine geçelim.';
      case TutorialStep.selectManav:
        return 'Manav; halkın her gün tükettiği domates, elma gibi taze gıdaları satan, nakit dönüş hızı en yüksek perakende işletmesidir. Başlangıç yatırımı olarak "Manav"ı seç.';
      case TutorialStep.confirmManavBuild:
        return 'Mağazamız kurulduğunda arkasında otomatik olarak soğuk hava deposu da faaliyete geçecek. "MAĞAZAYI KUR" butonuna tıklayarak inşaatı başlatalım.';
      case TutorialStep.clickQuickFinish:
        return 'Normalde inşaatlar zaman alır; fakat hızlı büyüyen kapitalistler Yıldız (Gold) kullanarak tesislerini anında faaliyete geçirir. Yıldız ile inşaatı hemen tamamlayalım!';
      case TutorialStep.clickEnterStore:
        return 'Süper! Manavımız kuruldu. İçeri girerek rafları düzenleyelim, fiyat politikamızı belirleyelim ve tedarik zincirini başlatalım.';
      case TutorialStep.clickCreateShelf:
        return 'Mağazalar raf mantığıyla çalışır. Her raf ayrı bir ürün çeşidini temsil eder ve müşterilere buradan satış yapılır. İlk satış alanımızı açmak için "RAF OLUŞTUR" butonuna tıkla.';
      case TutorialStep.clickGoToMarket:
        return 'Pazar (Global Borsa); diğer oyuncuların ve üreticilerin ürünlerini toptan alıp satabildiğin serbest ticaret merkezidir. Manavımızı dolduracak taze ürünleri toptan almak için "PAZARA GİT" butonuna tıkla.';
      case TutorialStep.selectMarketWarehouse:
        return 'Pazardan yapacağın toptan alımlar doğrudan seçtiğin depoya sevk edilir. Manavımızın arkasındaki entegre depolama alanını kullanmak için "Manav Deposu"nu seç.';
      case TutorialStep.selectMarketProduct:
        return 'Pazardaki toptan ürün kataloğundan manavında satmak istediğin taze bir ürünü (örneğin Domates veya Elma) seç.';
      case TutorialStep.clickMarketBuyListing:
        return 'Pazarda farklı üreticilerin kalite ve fiyat tekliflerini görürsün. En düşük maliyetle en yüksek kârı elde etmek için en uygun ilanın yanındaki "EKLE" butonuna tıkla.';
      case TutorialStep.confirmMarketCartBuy:
        return 'Toptan alım miktarını belirle. Aldığın mallar anında depona aktarılacak. Şimdi "SEPETE EKLE" butonuna tıkla.';
      case TutorialStep.confirmMarketCheckout:
        return 'Pazar sepetindeki siparişi onaylamak için "ALIMI TAMAMLA" butonuna tıkla. Satın aldığın ürünler anında Manav Depona teslim edilecek.';
      case TutorialStep.returnToStore:
        return 'Toptan mallarımız depomuza ulaştı! Şimdi depodaki ürünleri tezgaha dizmek ve satış fiyatını belirlemek için "MANAVA DÖN" butonuna tıkla.';
      case TutorialStep.clickSelectProduct:
        if (TutorialKeys.productSelectionFirstItemKey.currentContext != null) {
          return 'Depoda bekleyen taze ürününü seçerek bu rafa bağla.';
        }
        return 'Boş rafımıza depodaki ürünümüzü yerleştirmek için "Ürün Seç" butonuna dokun.';
      case TutorialStep.clickSetPrice:
        if (TutorialKeys.priceDialogConfirmKey.currentContext != null) {
          return 'Birim satış fiyatını belirledikten sonra "Kaydet" butonuna tıkla. Maliyetinin üzerinde bir fiyat koymayı unutma!';
        }
        return 'Fiyat Esnekliği Kuralı: Fiyatı maliyete yakın tutarsan ürünler çok HIZLI satılır, yüksek tutarsan kâr marjın artar ama satış hızı yavaşlar. Fiyat belirlemek için fiyat kutusuna dokun.';
      case TutorialStep.clickAddStock:
        if (TutorialKeys.stockRefillConfirmKey.currentContext != null) {
          return 'Depodaki stoğu satış tezgahına çekmek için "TRANSFER ET" butonuna tıkla.';
        }
        return 'Ürün ve fiyat hazır! Müşterilerin alışveriş yapabilmesi için depodaki malları tezgaha çekmemiz gerekiyor. "Stok Ekle" butonuna dokun.';
      case TutorialStep.finished:
        return 'Tebrikler patron! Tam bir kapitalist gibi tüm tedarik zincirini yönettin: Mağazayı kurdun, toptan mal aldın, rafları doldurdun ve satışa başladın. Artık her dakika ciro ve kâr elde edeceksin. Yeni birimler aç, üretim zinciri kur ve imparatorluğunu büyüt!';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tutorialState = ref.watch(tutorialProvider);
    final step = tutorialState.step;

    ref.listen(tutorialProvider, (previous, next) {
      _updateTargetRect();
    });

    if (step == TutorialStep.none) {
      return widget.child;
    }

    final hasTarget = _targetRect != null;
    final isFullscreenMessage =
        step == TutorialStep.welcome || step == TutorialStep.finished;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _updateTargetRect();
        return false;
      },
      child: Stack(
        children: [
          widget.child,
          if (!isFullscreenMessage && step != TutorialStep.selectCity) ...[
            IgnorePointer(
              ignoring: true,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.55),
                  BlendMode.srcOut,
                ),
                child: Stack(
                  children: [
                    Container(color: Colors.transparent),
                    if (hasTarget)
                      Positioned.fromRect(
                        rect: _targetRect!.inflate(4.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (hasTarget)
              Positioned.fromRect(
                rect: _targetRect!.inflate(4.0),
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final pulseVal = _pulseController.value;
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: Color.lerp(
                              AppColors.gold.withValues(alpha: 0.7),
                              AppColors.goldLight,
                              pulseVal,
                            )!,
                            width: 1.5.w,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(
                                alpha: 0.15 + (0.10 * pulseVal),
                              ),
                              blurRadius: 8.r + (4.r * pulseVal),
                              spreadRadius: 0.5.r,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
          ] else if (isFullscreenMessage)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (step != TutorialStep.finished) {
                  ref.read(tutorialProvider.notifier).completeStep(step);
                }
              },
              child: Container(color: Colors.black.withValues(alpha: 0.65)),
            ),
          _buildAssistantCard(step),
        ],
      ),
    );
  }

  Widget _buildAssistantCard(TutorialStep step) {
    final text = _getAssistantText(step);
    if (text.isEmpty) return const SizedBox.shrink();

    final targetRect = _targetRect;
    final bool hasTargetRect = targetRect != null;
    final screenHeight = MediaQuery.of(context).size.height;
    final double spaceAbove = hasTargetRect ? targetRect.top : screenHeight / 2;
    final double spaceBelow = hasTargetRect
        ? screenHeight - targetRect.bottom
        : screenHeight / 2;
    final bool placeBelow =
        spaceBelow >= 280.h || (spaceBelow > spaceAbove && spaceBelow >= 200.h);
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 1.8.w),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.3),
                          blurRadius: 10.r,
                          spreadRadius: 1.r,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/asistan.webp',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            CircleAvatar(
                              backgroundColor: AppColors.cardBg,
                              child: Icon(
                                AppIcons.person,
                                color: AppColors.gold,
                                size: 28.sp,
                              ),
                            ),
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
                        ref.read(tutorialProvider.notifier).pauseTutorial();
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
                          'Kapat ✕',
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
                              ? 'Başlayalım! 🚀'
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
      top: placeBelow
          ? (targetRect.bottom + 16.h).clamp(0.0, screenHeight - 120.h)
          : null,
      bottom: !placeBelow
          ? (screenHeight - targetRect.top + 16.h).clamp(
              0.0,
              screenHeight - 120.h,
            )
          : null,
      child: SafeArea(top: placeBelow, bottom: !placeBelow, child: cardContent),
    );
  }
}

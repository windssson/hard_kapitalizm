import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/tutorial_provider.dart';
import 'package:hard_kapitalizm/main.dart';

class _AssistantStepInfo {
  final String title;
  final String message;
  final String? tip;
  final String? recoveryRoute;
  final String? recoveryButtonText;

  const _AssistantStepInfo({
    required this.title,
    required this.message,
    this.tip,
    this.recoveryRoute,
    this.recoveryButtonText,
  });
}

class _SpotlightBarrier extends StatelessWidget {
  final Rect? targetRect;

  const _SpotlightBarrier({required this.targetRect});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final rect = targetRect;

    if (rect == null) {
      return Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: const SizedBox.expand(),
        ),
      );
    }

    final top = rect.top.clamp(0.0, screenSize.height);
    final bottom = rect.bottom.clamp(0.0, screenSize.height);
    final left = rect.left.clamp(0.0, screenSize.width);
    final right = rect.right.clamp(0.0, screenSize.width);

    return Positioned.fill(
      child: Stack(
        children: [
          // 1. Üst Bariyer
          if (top > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: top,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
              ),
            ),

          // 2. Alt Bariyer
          if (screenSize.height - bottom > 0)
            Positioned(
              top: bottom,
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
              ),
            ),

          // 3. Sol Bariyer
          if (left > 0 && bottom > top)
            Positioned(
              top: top,
              height: bottom - top,
              left: 0,
              width: left,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
              ),
            ),

          // 4. Sağ Bariyer
          if (screenSize.width - right > 0 && bottom > top)
            Positioned(
              top: top,
              height: bottom - top,
              left: right,
              right: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
              ),
            ),
        ],
      ),
    );
  }
}

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
    final tutorialState = ref.read(tutorialProvider);
    final step = tutorialState.step;
    if (step == TutorialStep.none || tutorialState.isPaused) {
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
        directKey = TutorialKeys.navMarketKey;
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
      case TutorialStep.returnToHome:
        directKey = TutorialKeys.navHomeKey;
        break;
      case TutorialStep.returnToStoresModule:
        directKey = TutorialKeys.homeStoresModuleKey;
        break;
      case TutorialStep.returnToStoreDetail:
        directKey = TutorialKeys.newStoreItemKey;
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
      case TutorialStep.viewSalesReport:
        return TutorialKeys.salesReportDialogKey;
    }

    if (directKey.currentContext != null) {
      return directKey;
    }

    // Ekran dışı akıllı geri yönlendirme
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

  _AssistantStepInfo _getStepInfo(TutorialStep step) {
    switch (step) {
      case TutorialStep.welcome:
        return const _AssistantStepInfo(
          title: 'Ticaret İmparatorluğuna Hoş Geldin!',
          message:
              'Hoş geldin patron! Ben danışmanın Leyla. Bu holdingde sıfırdan başlayıp Türkiye\'nin en büyük ticaret imparatorluğunu kuracağız. İlk gelir kapımızı açmak için perakende mağazamızı kuralım!',
          tip: 'Ticaret kuralı: Perakende satış holdingin can damarıdır.',
        );
      case TutorialStep.clickFirstStore:
        return const _AssistantStepInfo(
          title: '1. Adım: Mağazalar Modülü',
          message:
              'Mağazalar; doğrudan şehirdeki tüketicilere perakende satış yaparak holdingimize düzenli nakit akışı ve kâr sağlayan ana gelir merkezimizdir. İncelemek için **Mağazalar** menüsüne dokun.',
          tip: 'Şehir halkının tüketim talebi her dakika kâr olarak kasana akar.',
          recoveryRoute: '/home',
          recoveryButtonText: 'Ana Sayfaya Git',
        );
      case TutorialStep.clickStoreFab:
        return const _AssistantStepInfo(
          title: '2. Adım: Yeni Mağaza Açılışı',
          message:
              'Her yeni mağaza, yeni bir ciro ve kâr kaynağı demektir. Şehirde yeni bir perakende işletmesi açmak için sağ alttaki **"+" (Mağaza Kur)** butonuna dokun.',
          tip: 'Farklı şehirlerde mağaza açarak pazar payını genişletebilirsin.',
          recoveryRoute: '/store',
          recoveryButtonText: 'Mağazalar Listesine Git',
        );
      case TutorialStep.selectCity:
        return const _AssistantStepInfo(
          title: '3. Adım: Pazar & Şehir Seçimi',
          message:
              'Şehir seçimi çok kritiktir patron! Her şehrin nüfusu, vergi oranı ve tüketici talebi farklıdır. Yüksek potansiyelli bir şehir seçerek ilk yatırımını başlat.',
          tip: 'Yüksek nüfuslu şehirlerde satış hacmi ve kâr potansiyeli daha yüksektir.',
          recoveryRoute: '/store/new/city',
          recoveryButtonText: 'Şehir Seçimine Git',
        );
      case TutorialStep.confirmCity:
        return const _AssistantStepInfo(
          title: '4. Adım: Lokasyon Onayı',
          message:
              'Harika bir lokasyon seçtin! Şehirdeki tüketici potansiyelini değerlendirmek için **"Devam Et"** butonuna tıklayarak sektör seçimine geçelim.',
          tip: 'Şehrin lojistik avantajlarını da göz önünde bulundur.',
          recoveryRoute: '/store/new/city',
          recoveryButtonText: 'Şehir Seçimine Git',
        );
      case TutorialStep.selectManav:
        return const _AssistantStepInfo(
          title: '5. Adım: Sektör Seçimi (Manav)',
          message:
              'Manav; halkın her gün tükettiği domates, elma gibi taze gıdaları satan, nakit dönüş hızı en yüksek perakende işletmesidir. Başlangıç yatırımı olarak **"Manav"** sektörünü seç.',
          tip: 'Taze gıda talebi hiçbir zaman bitmez ve sürekli ciro üretir.',
          recoveryRoute: '/store',
          recoveryButtonText: 'Mağazalar Ekranına Git',
        );
      case TutorialStep.confirmManavBuild:
        return const _AssistantStepInfo(
          title: '6. Adım: İnşaatı Başlat',
          message:
              'Mağazamız kurulduğunda arkasında otomatik olarak soğuk hava deposu da faaliyete geçecek. **"MAĞAZAYI KUR"** butonuna tıklayarak inşaatı başlatalım.',
          tip: 'Entegre depo sayesinde pazardan doğrudan toptan ürün çekebilirsin.',
          recoveryRoute: '/store',
          recoveryButtonText: 'Mağazalar Ekranına Git',
        );
      case TutorialStep.clickQuickFinish:
        return const _AssistantStepInfo(
          title: '7. Adım: Hızlı Tamamlama',
          message:
              'Normalde inşaatlar zaman alır; fakat hızlı büyüyen kapitalistler Yıldız (Gold) kullanarak tesislerini anında faaliyete geçirir. Yıldız ile inşaatı hemen tamamlayalım!',
          tip: 'Zaman nakittir! Tesisleri erken açmak erkenden ciro kazanmaya başlatır.',
          recoveryRoute: '/store',
          recoveryButtonText: 'Mağazalar Ekranına Git',
        );
      case TutorialStep.clickEnterStore:
        return const _AssistantStepInfo(
          title: '8. Adım: Mağazaya Giriş',
          message:
              'Süper! Manavımız kuruldu. İçeri girerek rafları düzenleyelim, fiyat politikamızı belirleyelim ve tedarik zincirini başlatalım.',
          tip: 'Mağaza detayında anlık stok, satış hızı ve kâr grafiğini izleyebilirsin.',
          recoveryRoute: '/store',
          recoveryButtonText: 'Mağazalar Ekranına Git',
        );
      case TutorialStep.clickCreateShelf:
        return const _AssistantStepInfo(
          title: '9. Adım: Satış Rafı Açma',
          message:
              'Mağazalar raf mantığıyla çalışır. Her raf ayrı bir ürün çeşidini temsil eder ve müşterilere buradan satış yapılır. İlk satış alanımızı açmak için **"RAF OLUŞTUR"** butonuna dokun.',
          tip: 'Daha fazla raf = Daha fazla ürün çeşidi = Daha yüksek günlük ciro.',
          recoveryRoute: '/store',
          recoveryButtonText: 'Manav Detayına Git',
        );
      case TutorialStep.clickGoToMarket:
        return const _AssistantStepInfo(
          title: '10. Adım: Toptan Pazar Tedariği',
          message:
              'Pazar (Global Borsa); diğer üreticilerin ürünlerini toptan alıp satabildiğin serbest ticaret merkezidir. Taze ürünleri toptan almak için alt menüdeki **"Pazar"** sekmesine dokun.',
          tip: 'Oyun boyunca tüm toptan alım-satım işlemlerine alt menüdeki Pazar sekmesinden ulaşacaksın.',
          recoveryRoute: '/market',
          recoveryButtonText: 'Pazar Yerine Git',
        );
      case TutorialStep.selectMarketWarehouse:
        return const _AssistantStepInfo(
          title: '11. Adım: Teslimat Deposu',
          message:
              'Pazardan yapacağın toptan alımlar doğrudan seçtiğin depoya sevk edilir. Manavımızın arkasındaki entegre depolama alanını kullanmak için **"Manav Deposu"**nu seç.',
          tip: 'Depolar ürünleri güvenle saklar ve bozulmasını önler.',
          recoveryRoute: '/market',
          recoveryButtonText: 'Pazar Yerine Git',
        );
      case TutorialStep.selectMarketProduct:
        return const _AssistantStepInfo(
          title: '12. Adım: Ürün Kataloğu',
          message:
              'Pazardaki toptan ürün kataloğundan manavında satmak istediğin taze bir ürünü (örneğin **Domates** veya **Elma**) seç.',
          tip: 'Pazardaki arz ve talep dengesine göre fiyatlar anlık değişebilir.',
          recoveryRoute: '/market',
          recoveryButtonText: 'Pazar Yerine Git',
        );
      case TutorialStep.clickMarketBuyListing:
        return const _AssistantStepInfo(
          title: '13. Adım: Satıcı ve Fiyat Teklifi',
          message:
              'Pazarda üreticilerin kalite, mesafe ve fiyat tekliflerini görürsün. En kârlı alımı yapmak için **en uygun satıcı kartına** dokunup ürünü sepete ekle.',
          tip: 'Tedarikçinin puanı, stok miktarı ve ürün kalitesi kârını doğrudan etkiler.',
          recoveryRoute: '/market',
          recoveryButtonText: 'Pazar Yerine Git',
        );
      case TutorialStep.confirmMarketCartBuy:
        return const _AssistantStepInfo(
          title: '14. Adım: Miktar Belirleme',
          message:
              'Toptan alım miktarını belirle. Aldığın mallar anında depona aktarılacak. Şimdi **"SEPETE EKLE"** butonuna dokun.',
          tip: 'Depo kapasiteni aşmayacak miktarda toptan alım yapmaya özen göster.',
          recoveryRoute: '/market',
          recoveryButtonText: 'Pazar Yerine Git',
        );
      case TutorialStep.confirmMarketCheckout:
        return const _AssistantStepInfo(
          title: '15. Adım: Sipariş ve Sepet Özeti',
          message:
              'Sepet özetini incele. Alım miktarını ve toplam maliyeti kontrol ettikten sonra **"ALIMI TAMAMLA"** butonuna dokun.',
          tip: 'Satın aldığın ürünler anında Manav Depona teslim edilir.',
          recoveryRoute: '/market',
          recoveryButtonText: 'Pazar Yerine Git',
        );
      case TutorialStep.returnToHome:
        return const _AssistantStepInfo(
          title: '16. Adım: Ana Sayfaya Dönüş',
          message:
              'Toptan alım tamamlandı patron! Şimdi işletmemizi yönetmek üzere alt menüdeki **"Ana Sayfa"** sekmesine dokun.',
          tip: 'Alt menü üzerinden dilediğin zaman şirketinin tüm operasyonlarına ulaşabilirsin.',
          recoveryRoute: '/home',
          recoveryButtonText: 'Ana Sayfaya Git',
        );
      case TutorialStep.returnToStoresModule:
        return const _AssistantStepInfo(
          title: '17. Adım: Mağazalar Modülü',
          message:
              'Yönetim merkezindeyiz. Perakende satış birimlerimizi görmek için **"Mağazalar"** kartına dokun.',
          tip: 'Tüm perakende mağazalarının satış ve ciro performansını buradan yönetirsin.',
          recoveryRoute: '/home',
          recoveryButtonText: 'Ana Sayfaya Git',
        );
      case TutorialStep.returnToStoreDetail:
        return const _AssistantStepInfo(
          title: '18. Adım: Manava Giriş',
          message:
              'Az önce kurduğumuz ve depolaması hazır olan **"Manav"** mağazamıza dokunarak içeri gir.',
          tip: 'Mağazanın içine girerek rafları düzenleyebilir ve fiyatları güncelleyebilirsin.',
          recoveryRoute: '/store',
          recoveryButtonText: 'Mağazalara Git',
        );
      case TutorialStep.clickSelectProduct:
        return const _AssistantStepInfo(
          title: '19. Adım: Rafa Ürün Bağlama',
          message:
              'Boş rafımıza pazardan aldığımız taze ürünümüzü yerleştirmek için **"Ürün Seç"** butonuna dokun.',
          tip: 'Her rafa farklı ürün koyarak mağazanı çeşitlendirebilirsin.',
          recoveryRoute: '/store',
          recoveryButtonText: 'Manav Detayına Git',
        );
      case TutorialStep.clickAddStock:
        return const _AssistantStepInfo(
          title: '20. Adım: Tezgaha Stok Çekme',
          message:
              'Rafta ürünümüz tanımlandı! Şimdi depodaki ürünleri satış tezgahına aktaralım. Böylece rafta birim maliyetimiz hesaplanacak. **"Stok Ekle"** butonuna dokun.',
          tip: 'Tezgaha stok aktarıldığında ortalama birim maliyet hesaplanır ve kâr marjını net görürsün.',
          recoveryRoute: '/store',
          recoveryButtonText: 'Manav Detayına Git',
        );
      case TutorialStep.clickSetPrice:
        return const _AssistantStepInfo(
          title: '21. Adım: Satış Fiyatı & Kâr Marjı',
          message:
              'Maliyetimiz belirlendi patron! Şimdi maliyetinin üzerine kâr marjını koyarak satış fiyatını belirle. Fiyat kutusuna dokunup kârlı bir birim fiyat gir.',
          tip: 'Fiyat Esnekliği: Maliyetin biraz üzerinde satarak hem yüksek talep yakalayabilir hem de süratle kâr edebilirsin.',
          recoveryRoute: '/store',
          recoveryButtonText: 'Manav Detayına Git',
        );
      case TutorialStep.viewSalesReport:
        return const _AssistantStepInfo(
          title: '22. Adım: İlk Satış Raporu & Kasa',
          message:
              'Tebrikler patron! 15 dakikalık açılış satışımızın raporu geldi. Burada toplam cironu, maliyetler sonrası net kârını, satılan adetleri ve kazandığın deneyim puanını (XP) görüyorsun. İnceledikten sonra **"Kapat"** butonuna dokun.',
          tip: 'Ticaret kuralı: Satış yaptıkça şirket seviyen artar ve yeni sektörlerin kilidi açılır.',
          recoveryRoute: '/store',
          recoveryButtonText: 'Manav Detayına Git',
        );
      case TutorialStep.finished:
        return const _AssistantStepInfo(
          title: 'Tebrikler Patron! 🚀',
          message:
              'Tam bir kapitalist gibi tüm tedarik zincirini yönettin: Mağazayı kurdun, toptan mal aldın, rafları doldurdun, fiyatını belirledin ve ilk kârını elde ettin! Artık her dakika ciro ve kâr akışı devam edecek. Şimdi yeni mağazalar aç, üretim zincirleri kur ve imparatorluğunu büyüt!',
          tip: 'Bir sonraki hedef: Tarla ve Çiftlik kurarak kendi hammaddeni üretmek!',
        );
      default:
        return const _AssistantStepInfo(title: '', message: '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tutorialState = ref.watch(tutorialProvider);
    final step = tutorialState.step;

    ref.listen(tutorialProvider, (previous, next) {
      _updateTargetRect();
    });

    if (step == TutorialStep.none || tutorialState.isPaused) {
      if (tutorialState.isPaused &&
          !tutorialState.hasSeenTutorial &&
          step != TutorialStep.none &&
          step != TutorialStep.finished) {
        return Stack(
          children: [
            widget.child,
            Positioned(
              bottom: 80.h,
              right: 16.w,
              child: SafeArea(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      ref.read(tutorialProvider.notifier).resumeTutorial();
                    },
                    borderRadius: BorderRadius.circular(24.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(
                          color: AppColors.gold,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.school_rounded,
                            color: AppColors.gold,
                            size: 16.sp,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'Rehbere Devam Et',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }
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
            // 1. Dokunma Engelleme Bariyeri (Aydınlatılan alan dışındaki her yeri kilitler)
            _SpotlightBarrier(
              targetRect: hasTarget ? _targetRect!.inflate(5.0) : null,
            ),
            // 2. Görsel Karartma Efekti
            IgnorePointer(
              ignoring: true,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.60),
                  BlendMode.srcOut,
                ),
                child: Stack(
                  children: [
                    Container(color: Colors.transparent),
                    if (hasTarget)
                      Positioned.fromRect(
                        rect: _targetRect!.inflate(5.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // 3. Altın Işıma Efekti
            if (hasTarget)
              Positioned.fromRect(
                rect: _targetRect!.inflate(5.0),
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final pulseVal = _pulseController.value;
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: AppColors.gold.withValues(
                              alpha: 0.45 + (0.20 * pulseVal),
                            ),
                            width: 1.5.w,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(
                                alpha: 0.08 + (0.07 * pulseVal),
                              ),
                              blurRadius: 6.r + (3.r * pulseVal),
                              spreadRadius: 0,
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
              child: Container(color: Colors.black.withValues(alpha: 0.70)),
            ),
          _buildAssistantCard(step),
        ],
      ),
    );
  }

  Widget _buildRichText(String text) {
    final spans = <TextSpan>[];
    final parts = text.split('**');

    for (int i = 0; i < parts.length; i++) {
      final isBold = i % 2 == 1;
      if (parts[i].isEmpty) continue;

      spans.add(
        TextSpan(
          text: parts[i],
          style: TextStyle(
            color: isBold ? AppColors.goldLight : AppColors.textPrimary,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w500,
            fontSize: AppTypography.body,
            height: 1.45,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildAssistantCard(TutorialStep step) {
    final info = _getStepInfo(step);
    if (info.message.isEmpty) return const SizedBox.shrink();

    final targetRect = _targetRect;
    final bool hasTargetRect = targetRect != null;
    final screenHeight = MediaQuery.of(context).size.height;
    final double spaceAbove = hasTargetRect ? targetRect.top : screenHeight / 2;
    final double spaceBelow = hasTargetRect
        ? screenHeight - targetRect.bottom
        : screenHeight / 2;
    final bool placeBelow =
        spaceBelow >= 300.h || (spaceBelow > spaceAbove && spaceBelow >= 220.h);
    final isFullscreenMessage =
        step == TutorialStep.welcome || step == TutorialStep.finished;

    final int stepIndex = step.index;
    final int totalSteps = TutorialStep.values.length - 2; // none & finished hariç

    Widget cardContent = Container(
      margin: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.75),
          width: 1.5.w,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.20),
            blurRadius: 24.r,
            spreadRadius: 1.r,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            blurRadius: 30.r,
            spreadRadius: 4.r,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.cardBg,
                  AppColors.cardBgLight.withValues(alpha: 0.90),
                ],
              ),
            ),
            padding: EdgeInsets.all(16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── ÜST BAŞLIK: Avatar + İsim + Adım Rozeti + Kapat ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48.w,
                      height: 48.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold, width: 1.8.w),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.35),
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
                                  size: 26.sp,
                                ),
                              ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
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
                              SizedBox(width: 6.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6.r),
                                  border: Border.all(
                                    color: AppColors.gold.withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  isFullscreenMessage
                                      ? (step == TutorialStep.welcome ? 'BAŞLANGIÇ' : 'MEZUNİYET')
                                      : 'Adım $stepIndex / $totalSteps',
                                  style: AppTextStyles.caption.standardCopyWith(
                                    color: AppColors.gold,
                                    fontSize: AppTypography.micro,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            info.title,
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.goldLight,
                              fontSize: AppTypography.caption,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6.w,
                            height: 6.w,
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            'CANLI',
                            style: AppTextStyles.caption.standardCopyWith(
                              color: AppColors.gold,
                              fontSize: AppTypography.micro,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Divider(
                  color: AppColors.borderGold.withValues(alpha: 0.25),
                  height: 1,
                ),
                SizedBox(height: 10.h),

                // ── MESAJ GÖVDESİ (Zengin Metin) ──
                _buildRichText(info.message),

                // ── STRATEJİ İPUCU KUTUSU ──
                if (info.tip != null) ...[
                  SizedBox(height: 10.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2B3A).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: const Color(0xFF00E5FF),
                          size: 14.sp,
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            info.tip!,
                            style: TextStyle(
                              color: const Color(0xFFE0F7FA),
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── AKILLI KURTARMA / HEDEF EKRANA GİT BUTONU ──
                if (!hasTargetRect && !isFullscreenMessage && info.recoveryRoute != null) ...[
                  SizedBox(height: 12.h),
                  SizedBox(
                    width: double.infinity,
                    height: 40.h,
                    child: ElevatedButton(
                      onPressed: () {
                        appRouter.go(info.recoveryRoute!);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.background,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.navigation_rounded,
                            size: 15.sp,
                            color: AppColors.background,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            info.recoveryButtonText ?? 'Kaldığın Yere Git ➔',
                            style: TextStyle(
                              color: AppColors.background,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ── TAM EKRAN MESAJLARI İÇİN ÖZEL BUTON ──
                if (isFullscreenMessage) ...[
                  SizedBox(height: 14.h),
                  SizedBox(
                    width: double.infinity,
                    height: 46.h,
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
                                ? 'İmparatorluğu Yönetmeye Başla! 🚀'
                                : 'Hemen Başlayalım ➔',
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
        bottom: 30.h,
        child: SafeArea(bottom: true, child: cardContent),
      );
    }

    return Positioned(
      left: 0,
      right: 0,
      top: placeBelow
          ? (targetRect.bottom + 14.h).clamp(0.0, screenHeight - 120.h)
          : null,
      bottom: !placeBelow
          ? (screenHeight - targetRect.top + 14.h).clamp(
              0.0,
              screenHeight - 120.h,
            )
          : null,
      child: SafeArea(top: placeBelow, bottom: !placeBelow, child: cardContent),
    );
  }
}

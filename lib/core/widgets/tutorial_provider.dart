import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hard_kapitalizm/features/home/data/home_dashboard_provider.dart';

enum TutorialStep {
  none,
  welcome,
  clickFirstStore,
  clickStoreFab,
  selectCity,
  confirmCity,
  selectManav,
  confirmManavBuild,
  clickQuickFinish,
  clickEnterStore,
  clickCreateShelf,
  clickGoToMarket,
  selectMarketWarehouse,
  selectMarketProduct,
  clickMarketBuyListing,
  confirmMarketCartBuy,
  confirmMarketCheckout,
  returnToHome,
  returnToStoresModule,
  returnToStoreDetail,
  clickSelectProduct,
  clickAddStock,
  clickSetPrice,
  viewSalesReport,
  finished
}

class TutorialKeys {
  static final GlobalKey homeStoresModuleKey = GlobalKey(debugLabel: 'home_stores_module');
  static final GlobalKey storeScreenFabKey = GlobalKey(debugLabel: 'store_screen_fab');
  static final GlobalKey citySelectionMapKey = GlobalKey(debugLabel: 'city_selection_map');
  static final GlobalKey citySelectionConfirmKey = GlobalKey(debugLabel: 'city_selection_confirm');
  static final GlobalKey buildingTypeManavKey = GlobalKey(debugLabel: 'building_type_manav');
  static final GlobalKey buildingTypeConfirmKey = GlobalKey(debugLabel: 'building_type_confirm');
  static final GlobalKey constructionGoldFinishKey = GlobalKey(debugLabel: 'construction_gold_finish');
  static final GlobalKey quickFinishDialogConfirmKey = GlobalKey(debugLabel: 'quick_finish_dialog_confirm');
  static final GlobalKey newStoreItemKey = GlobalKey(debugLabel: 'new_store_item');
  static final GlobalKey storeQuickActionOpenSlotKey = GlobalKey(debugLabel: 'store_quick_action_open_slot');
  static final GlobalKey storeEmptyShelfButtonKey = GlobalKey(debugLabel: 'store_empty_shelf_button');
  static final GlobalKey navMarketKey = GlobalKey(debugLabel: 'nav_market');
  static final GlobalKey navHomeKey = GlobalKey(debugLabel: 'nav_home');
  static final GlobalKey marketWarehouseFirstItemKey = GlobalKey(debugLabel: 'market_warehouse_first_item');
  static final GlobalKey marketProductFirstItemKey = GlobalKey(debugLabel: 'market_product_first_item');
  static final GlobalKey marketListingFirstAddKey = GlobalKey(debugLabel: 'market_listing_first_add');
  static final GlobalKey marketAddToCartConfirmKey = GlobalKey(debugLabel: 'market_add_to_cart_confirm');
  static final GlobalKey marketCartLauncherKey = GlobalKey(debugLabel: 'market_cart_launcher');
  static final GlobalKey marketCheckoutConfirmKey = GlobalKey(debugLabel: 'market_checkout_confirm');
  static final GlobalKey storeSlotSelectProductKey = GlobalKey(debugLabel: 'store_slot_select_product');
  static final GlobalKey productSelectionFirstItemKey = GlobalKey(debugLabel: 'product_selection_first_item');
  static final GlobalKey storeSlotPriceKey = GlobalKey(debugLabel: 'store_slot_price');
  static final GlobalKey priceDialogConfirmKey = GlobalKey(debugLabel: 'price_dialog_confirm');
  static final GlobalKey storeSlotOrderStockKey = GlobalKey(debugLabel: 'store_slot_order_stock');
  static final GlobalKey stockRefillConfirmKey = GlobalKey(debugLabel: 'stock_refill_confirm');
  static final GlobalKey salesReportDialogKey = GlobalKey(debugLabel: 'sales_report_dialog');
}

class TutorialState {
  final TutorialStep step;
  final bool hasSeenTutorial;
  final bool isPaused;
  final bool isLoaded;

  TutorialState({
    required this.step,
    required this.hasSeenTutorial,
    this.isPaused = false,
    this.isLoaded = false,
  });

  TutorialState copyWith({
    TutorialStep? step,
    bool? hasSeenTutorial,
    bool? isPaused,
    bool? isLoaded,
  }) {
    return TutorialState(
      step: step ?? this.step,
      hasSeenTutorial: hasSeenTutorial ?? this.hasSeenTutorial,
      isPaused: isPaused ?? this.isPaused,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class TutorialNotifier extends Notifier<TutorialState> {
  static const String _prefSeenKey = 'has_seen_tutorial';
  static const String _prefStepKey = 'current_tutorial_step';
  static const String _prefPausedKey = 'is_tutorial_paused';

  @override
  TutorialState build() {
    _loadFromPrefs();
    return TutorialState(
      step: TutorialStep.none,
      hasSeenTutorial: false,
      isPaused: false,
    );
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool(_prefSeenKey) ?? false;
      final isPaused = prefs.getBool(_prefPausedKey) ?? false;
      final savedStepName = prefs.getString(_prefStepKey);

      TutorialStep restoredStep = TutorialStep.none;
      if (!hasSeen && savedStepName != null && savedStepName.isNotEmpty) {
        try {
          restoredStep = TutorialStep.values.firstWhere(
            (s) => s.name == savedStepName,
            orElse: () => TutorialStep.welcome,
          );
        } catch (_) {
          restoredStep = TutorialStep.welcome;
        }
      }

      state = TutorialState(
        step: restoredStep,
        hasSeenTutorial: hasSeen,
        isPaused: isPaused,
        isLoaded: true,
      );
    } catch (e) {
      debugPrint('Tutorial: Prefs yüklenirken hata: $e');
      state = state.copyWith(isLoaded: true);
    }
  }

  Future<void> _saveStepToPrefs(TutorialStep step) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefStepKey, step.name);
    } catch (e) {
      debugPrint('Tutorial: Adım kaydedilirken hata: $e');
    }
  }

  Future<void> _saveSeenToPrefs(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefSeenKey, value);
    } catch (e) {
      debugPrint('Tutorial: Görülme durumu kaydedilirken hata: $e');
    }
  }

  Future<void> _savePausedToPrefs(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefPausedKey, value);
    } catch (e) {
      debugPrint('Tutorial: Duraklatma durumu kaydedilirken hata: $e');
    }
  }

  void startTutorial({bool force = false}) {
    if (state.hasSeenTutorial && !force) return;
    final initialStep = (state.step != TutorialStep.none && !force)
        ? state.step
        : TutorialStep.welcome;
    state = state.copyWith(
      step: initialStep,
      hasSeenTutorial: false,
      isPaused: false,
    );
    _saveStepToPrefs(initialStep);
    _saveSeenToPrefs(false);
    _savePausedToPrefs(false);
  }

  void restartTutorial() {
    state = state.copyWith(
      step: TutorialStep.welcome,
      hasSeenTutorial: false,
      isPaused: false,
    );
    _saveStepToPrefs(TutorialStep.welcome);
    _saveSeenToPrefs(false);
    _savePausedToPrefs(false);
  }

  void resumeTutorial() {
    final targetStep = state.step != TutorialStep.none
        ? state.step
        : TutorialStep.welcome;
    state = state.copyWith(step: targetStep, isPaused: false);
    _savePausedToPrefs(false);
  }

  void setStep(TutorialStep step) {
    if (state.isPaused && step != TutorialStep.finished) return;
    state = state.copyWith(step: step);
    _saveStepToPrefs(step);
  }

  void completeStep(TutorialStep completedStep) {
    if (state.step == completedStep) {
      final nextIndex = state.step.index + 1;
      if (nextIndex < TutorialStep.values.length) {
        final nextStep = TutorialStep.values[nextIndex];
        state = state.copyWith(step: nextStep);
        _saveStepToPrefs(nextStep);
      } else {
        finishTutorial();
      }
    }
  }

  void pauseTutorial() {
    state = state.copyWith(isPaused: true);
    _savePausedToPrefs(true);
  }

  void finishTutorial() {
    state = state.copyWith(
      step: TutorialStep.none,
      hasSeenTutorial: true,
      isPaused: false,
    );
    _saveStepToPrefs(TutorialStep.none);
    _saveSeenToPrefs(true);
    _savePausedToPrefs(false);
    ref.invalidate(homeDashboardProvider);
  }
}

final tutorialProvider = NotifierProvider<TutorialNotifier, TutorialState>(() {
  return TutorialNotifier();
});


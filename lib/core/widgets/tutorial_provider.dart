import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  clickSelectProduct,
  clickSetPrice,
  clickAddStock,
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
  static final GlobalKey storeSlotSelectProductKey = GlobalKey(debugLabel: 'store_slot_select_product');
  static final GlobalKey productSelectionFirstItemKey = GlobalKey(debugLabel: 'product_selection_first_item');
  static final GlobalKey storeSlotPriceKey = GlobalKey(debugLabel: 'store_slot_price');
  static final GlobalKey priceDialogConfirmKey = GlobalKey(debugLabel: 'price_dialog_confirm');
  static final GlobalKey storeSlotOrderStockKey = GlobalKey(debugLabel: 'store_slot_order_stock');
  static final GlobalKey stockRefillConfirmKey = GlobalKey(debugLabel: 'stock_refill_confirm');
}

class TutorialState {
  final TutorialStep step;
  final bool hasSeenTutorial;

  TutorialState({
    required this.step,
    required this.hasSeenTutorial,
  });

  TutorialState copyWith({
    TutorialStep? step,
    bool? hasSeenTutorial,
  }) {
    return TutorialState(
      step: step ?? this.step,
      hasSeenTutorial: hasSeenTutorial ?? this.hasSeenTutorial,
    );
  }
}

class TutorialNotifier extends Notifier<TutorialState> {
  static const String _prefSeenKey = 'has_seen_tutorial';
  static const String _prefStepKey = 'current_tutorial_step';

  // TODO: İleriki seviyelerde yeni birimler açıldıkça (örn. Seviye 4 Tarla, Seviye 7 Çiftlik, Seviye 10 Fabrika, Seviye 15 Maden) seviye bazlı öğretici adımları tetiklenecek.

  @override
  TutorialState build() {
    _loadFromPrefs();
    return TutorialState(step: TutorialStep.none, hasSeenTutorial: false);
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool(_prefSeenKey) ?? false;
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
      );
    } catch (_) {}
  }

  Future<void> _saveStepToPrefs(TutorialStep step) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefStepKey, step.name);
    } catch (_) {}
  }

  Future<void> _saveSeenToPrefs(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefSeenKey, value);
    } catch (_) {}
  }

  void startTutorial({bool force = false}) {
    if (state.hasSeenTutorial && !force) return;
    final initialStep = state.step != TutorialStep.none && !force
        ? state.step
        : TutorialStep.welcome;
    state = TutorialState(step: initialStep, hasSeenTutorial: false);
    _saveStepToPrefs(initialStep);
    _saveSeenToPrefs(false);
  }

  void restartTutorial() {
    state = TutorialState(step: TutorialStep.welcome, hasSeenTutorial: false);
    _saveStepToPrefs(TutorialStep.welcome);
    _saveSeenToPrefs(false);
  }

  void setStep(TutorialStep step) {
    if (step == TutorialStep.finished) {
      finishTutorial();
    } else {
      state = state.copyWith(step: step);
      _saveStepToPrefs(step);
    }
  }

  void completeStep(TutorialStep completedStep) {
    if (state.step == completedStep) {
      final nextIndex = state.step.index + 1;
      if (nextIndex < TutorialStep.values.length) {
        final nextStep = TutorialStep.values[nextIndex];
        if (nextStep == TutorialStep.finished) {
          finishTutorial();
        } else {
          state = state.copyWith(step: nextStep);
          _saveStepToPrefs(nextStep);
        }
      } else {
        finishTutorial();
      }
    }
  }

  void finishTutorial() {
    state = state.copyWith(step: TutorialStep.none, hasSeenTutorial: true);
    _saveStepToPrefs(TutorialStep.none);
    _saveSeenToPrefs(true);
  }
}

final tutorialProvider = NotifierProvider<TutorialNotifier, TutorialState>(() {
  return TutorialNotifier();
});


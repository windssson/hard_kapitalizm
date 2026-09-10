from pathlib import Path

path = Path('lib/features/arge/ui/arge_screen.dart')
text = path.read_text(encoding='utf-8')

anchor = "import 'package:hard_kapitalizm/core/ads/rewarded_time_reduction_flow.dart';\n"
imports = """import 'package:hard_kapitalizm/core/ads/rewarded_time_reduction_flow.dart';
import 'package:hard_kapitalizm/core/data/building_construction_quote_provider.dart';
import 'package:hard_kapitalizm/core/data/building_upgrade_quote_provider.dart';
"""
if "building_construction_quote_provider.dart" not in text:
    text = text.replace(anchor, imports, 1)

anchor = "import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';\n"
imports = """import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/core/widgets/building_construction_quote_sheet.dart';
import 'package:hard_kapitalizm/core/widgets/building_upgrade_sheet.dart';
"""
if "building_construction_quote_sheet.dart" not in text:
    text = text.replace(anchor, imports, 1)

# Backend quote must be reachable even when the local cash hint is red.
text = text.replace(
    "onPressed: (_isCenterSubmitting || !hasCash)\n                  ? null\n                  : _onStartCenterConstruction,",
    "onPressed: _isCenterSubmitting ? null : _onStartCenterConstruction,",
    1,
)

start = text.index("  void _showCenterUpgradeSheet(ArgeCenterModel center) {")
end = text.index("  Future<void> _startCenterUpgrade(String centerId) async {", start)
replacement = r'''  Future<void> _showCenterUpgradeSheet(ArgeCenterModel center) async {
    final request = (buildingKind: 'arge_center', entityId: center.id);

    try {
      ref.invalidate(buildingUpgradeQuoteProvider(request));
      final quote = await ref.read(buildingUpgradeQuoteProvider(request).future);
      if (!mounted) return;

      if (quote.isMaximumLevel) {
        AppSnackbar.show(
          context,
          title: 'Maksimum Seviye',
          message: 'AR-GE merkezi maksimum seviye ${quote.maxLevel}.',
          type: SnackbarType.info,
        );
        return;
      }

      final targetLevel = quote.targetLevel;
      if (targetLevel == null) {
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: 'Yükseltme hedef seviyesi alınamadı.',
          type: SnackbarType.error,
        );
        return;
      }

      final slotsEffect = quote.effect('arge_max_concurrent_researches');
      final reductionEffect = quote.effect('arge_duration_reduction_pct');

      await showBuildingUpgradeSheet(
        context: context,
        title: 'AR-GE Merkezi Yükseltmesi',
        buildingName: center.name,
        icon: Icons.science_rounded,
        currentLevel: quote.currentLevel,
        targetLevel: targetLevel,
        durationLabel: '${quote.durationMinutes} dk',
        costLabel: AppMoney.compact(quote.cashCost),
        requirementLabel: quote.canUpgrade ? null : quote.requirementLabel,
        canConfirm: quote.canUpgrade,
        requiredMaterials: quote.requiredMaterials,
        materialSourceLabel: 'Merkez şehirdeki Genel Depo',
        benefits: [
          if (slotsEffect != null)
            BuildingUpgradeBenefit(
              icon: Icons.dashboard_customize_outlined,
              label: 'Eşzamanlı araştırma',
              before: slotsEffect.previousValue.toInt().toString(),
              after: slotsEffect.nextValue.toInt().toString(),
            ),
          if (reductionEffect != null)
            BuildingUpgradeBenefit(
              icon: Icons.timer_outlined,
              label: 'Süre indirimi',
              before: '%${reductionEffect.previousValue.toStringAsFixed(0)}',
              after: '%${reductionEffect.nextValue.toStringAsFixed(0)}',
            ),
        ],
        onConfirm: () => _startCenterUpgrade(center.id),
      );
    } catch (error) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: error.toString(),
        type: SnackbarType.error,
      );
    }
  }

'''
text = text[:start] + replacement + text[end:]

start = text.index("  Future<void> _onStartCenterConstruction() async {")
end = text.index("  Future<void> _onCompleteCenterConstruction(String constructionId) async {", start)
replacement = r'''  Future<void> _onStartCenterConstruction() async {
    if (_isCenterSubmitting) return;

    final headquartersCityId = ref.read(playerProvider).value?.headquartersCityId;
    if (headquartersCityId == null || headquartersCityId.isEmpty) {
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: 'AR-GE merkezi için merkez şehir bulunamadı.',
        type: SnackbarType.error,
      );
      return;
    }

    final request = (
      cityId: headquartersCityId,
      buildingKind: 'arge_center',
      buildingTypeId: null,
    );

    setState(() => _isCenterSubmitting = true);
    try {
      ref.invalidate(buildingConstructionQuoteProvider(request));
      final quote = await ref.read(
        buildingConstructionQuoteProvider(request).future,
      );
      if (!mounted) return;

      setState(() => _isCenterSubmitting = false);
      final approved = await showBuildingConstructionQuoteSheet(
        context: context,
        buildingName: quote.name.isEmpty ? 'AR-GE Merkezi' : quote.name,
        icon: AppIcons.scienceOutlined,
        quote: quote,
      );
      if (!approved || !mounted) return;

      setState(() => _isCenterSubmitting = true);
      final result = await ref
          .read(argeActionProvider)
          .startCenterConstruction(syncProviders: false);
      if (!mounted) return;

      if (result['success'] == true) {
        // MutationSyncService already applied the authoritative player/warehouse
        // patches returned by the backend. Do not subtract cash a second time.
        FloatingFeedback.show(
          context,
          amount: quote.cashCost,
          type: FloatingFeedbackType.cashRemove,
        );
        ref.invalidate(playerArgeConstructionProvider);
        AppSnackbar.show(
          context,
          title: 'Kurulum Başladı',
          message: 'AR-GE merkezinizin kurulumu başlatıldı.',
          type: SnackbarType.success,
        );
      } else {
        AppSnackbar.show(
          context,
          title: 'Hata',
          message: result['message']?.toString() ?? 'Bilinmeyen hata.',
          type: SnackbarType.error,
        );
      }
    } catch (error) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        title: 'Hata',
        message: error.toString(),
        type: SnackbarType.error,
      );
    } finally {
      if (mounted && _isCenterSubmitting) {
        setState(() => _isCenterSubmitting = false);
      }
    }
  }

'''
text = text[:start] + replacement + text[end:]

path.write_text(text, encoding='utf-8')

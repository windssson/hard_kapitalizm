from pathlib import Path


def patch_factory():
    path = Path('lib/features/factory/ui/factory_detail_screen.dart')
    text = path.read_text(encoding='utf-8')

    anchor = "import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';\n"
    if "factory_multislot_provider.dart" not in text:
        text = text.replace(
            anchor,
            anchor
            + "import 'package:hard_kapitalizm/features/factory/data/factory_multislot_provider.dart';\n"
            + "import 'package:hard_kapitalizm/features/factory/ui/factory_multislot_section.dart';\n",
            1,
        )

    text = text.replace(
        "                      _buildHero(detail),",
        "                      _buildHero(_liveFactoryDetail(ref, detail)),",
        1,
    )

    old = """                      _buildSectionHeader(
                        'Üretim Hattı',
                        'Fabrikanın aktif ürününü, hammadde akışını ve depoya sevklerini buradan yönetebilirsin.',
                        icon: AppIcons.precisionManufacturingRounded,
                        color: AppColors.gold,
                      ),
                      SizedBox(height: 10.h),
                      _buildProductionCard(context, ref, detail, activeBoost),
"""
    new = """                      _buildSectionHeader(
                        'Üretim Hatları',
                        'Her üretim slotunun ürününü, kalitesini, markasını ve çalışma durumunu ayrı ayrı yönetebilirsin.',
                        icon: AppIcons.precisionManufacturingRounded,
                        color: AppColors.gold,
                      ),
                      SizedBox(height: 10.h),
                      FactoryMultiSlotSection(
                        factoryId: detail.factory.id,
                        factoryTypeId: detail.factoryType.id,
                        currentSlotCount: detail.factory.currentSlotCount,
                        maxSlotCount: detail.factory.maxSlotCount,
                      ),
                      SizedBox(height: 12.h),
                      _buildFactoryInventoryOverview(
                        context,
                        ref,
                        detail,
                      ),
"""
    if old not in text:
        raise RuntimeError('Factory production block anchor not found')
    text = text.replace(old, new, 1)

    text = text.replace(
        "if (detail.orphanInputInventories.isNotEmpty) ...[",
        "if (_liveFactoryDetail(ref, detail).orphanInputInventories.isNotEmpty) ...[",
        1,
    )
    text = text.replace(
        "...detail.orphanInputInventories.map(",
        "..._liveFactoryDetail(ref, detail).orphanInputInventories.map(",
        1,
    )

    start = text.index("  Widget _buildQuickActions(\n")
    end = text.index("  Widget _buildActionButton(\n", start)
    quick = r'''  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
    BuildingBoostModel? activeBoost,
    BuildingUpgradeModel? activeUpgrade,
  ) {
    final liveDetail = _liveFactoryDetail(ref, detail);
    final hasProduct = liveDetail.hasConfiguredProduction;
    final canBoost = liveDetail.hasActiveProduction && liveDetail.factory.isActive;
    final canUpgrade = liveDetail.factory.isActive;

    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.18),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppFx.softOverlay(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Ürün Al',
                  AppIcons.downloadRounded,
                  AppColors.gold,
                  () => _startFactoryReceiveFlow(context, ref, liveDetail),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildActionButton(
                  'Ürün Gönder',
                  AppIcons.localShippingRounded,
                  AppColors.blue,
                  () => _startFactorySendFlow(context, ref, liveDetail),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Boost',
                  AppIcons.flashOnRounded,
                  canBoost ? AppColors.goldDark : AppColors.textMuted,
                  canBoost
                      ? () => _showFactoryBoostSheet(
                          context,
                          ref,
                          liveDetail,
                          activeBoost,
                        )
                      : () {
                          AppSnackbar.show(
                            context,
                            title: 'Bilgi',
                            message: hasProduct
                                ? 'Boost için en az bir üretim slotunun aktif olması gerekir.'
                                : 'Boost başlatmadan önce en az bir üretim slotu yapılandırmalısın.',
                            type: SnackbarType.info,
                          );
                        },
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildActionButton(
                  'Yükselt',
                  AppIcons.upgradeRounded,
                  canUpgrade ? AppColors.green : AppColors.textMuted,
                  canUpgrade
                      ? () => _showFactoryUpgradeSheet(
                          context,
                          ref,
                          liveDetail,
                          activeUpgrade,
                        )
                      : () {
                          AppSnackbar.show(
                            context,
                            title: 'Bilgi',
                            message:
                                'Yükseltme başlatmak için fabrikanın aktif olması gerekir.',
                            type: SnackbarType.info,
                          );
                        },
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildActionButton(
                  'Rapor',
                  AppIcons.queryStatsRounded,
                  AppColors.blue,
                  () => context.push(
                    '/production-report/factory/${liveDetail.factory.id}?name=${Uri.encodeComponent(liveDetail.factory.name)}',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

'''
    text = text[:start] + quick + text[end:]

    marker = "  Widget _buildProductionCard(\n"
    insert_at = text.index(marker)
    helpers = r'''  FactoryDetailModel _liveFactoryDetail(
    WidgetRef ref,
    FactoryDetailModel detail,
  ) {
    final slots = ref.watch(factoryProductionSlotsProvider(detail.factory.id)).value;
    if (slots == null) return detail;
    return detail.copyWith(productionSlots: slots);
  }

  Widget _buildFactoryInventoryOverview(
    BuildContext context,
    WidgetRef ref,
    FactoryDetailModel detail,
  ) {
    final liveDetail = _liveFactoryDetail(ref, detail);
    final inputs = liveDetail.inputInventories;
    final outputs = liveDetail.outputInventories;

    if (inputs.isEmpty && outputs.isEmpty) {
      return _buildEmptyCard(
        'Yapılandırılmış slotlar üretim yaptıkça hammadde ve ürün stokları burada görünecek.',
      );
    }

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (inputs.isNotEmpty) ...[
            _buildMiniFlowHeader('Ortak Hammadde Stoğu', AppColors.blue),
            SizedBox(height: 8.h),
            _buildSharedInputCapacityBar(liveDetail),
            SizedBox(height: 8.h),
            ...inputs.map(_buildCompactInventoryRow),
          ],
          if (inputs.isNotEmpty && outputs.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Divider(color: AppFx.softOverlay(0.06), height: 1),
            SizedBox(height: 12.h),
          ],
          if (outputs.isNotEmpty) ...[
            _buildMiniFlowHeader('Üretilen Ürünler', AppColors.green),
            SizedBox(height: 8.h),
            ...outputs.map(
              (inventory) => _buildInputInventoryCard(
                context,
                ref,
                liveDetail,
                inventory,
              ),
            ),
          ],
        ],
      ),
    );
  }

'''
    text = text[:insert_at] + helpers + text[insert_at:]
    path.write_text(text, encoding='utf-8')


def patch_mine():
    path = Path('lib/features/mine/ui/mine_detail_screen.dart')
    text = path.read_text(encoding='utf-8')

    anchor = "import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';\n"
    if "mine_multislot_provider.dart" not in text:
        text = text.replace(
            anchor,
            anchor
            + "import 'package:hard_kapitalizm/features/mine/data/mine_multislot_provider.dart';\n"
            + "import 'package:hard_kapitalizm/features/mine/ui/mine_multislot_section.dart';\n",
            1,
        )

    text = text.replace(
        "                      _buildHero(detail),",
        "                      _buildHero(_liveMineDetail(ref, detail)),",
        1,
    )

    old = """                      _buildSectionHeader(
                        'Üretim',
                        'Madende seçili kaynağı, stok durumunu ve depoya sevkleri buradan yönetebilirsin.',
                        icon: AppIcons.hardwareRounded,
                        color: AppColors.gold,
                      ),
                      SizedBox(height: 10.h),
                      _buildProductionCard(context, ref, detail, activeBoost),
"""
    new = """                      _buildSectionHeader(
                        'Üretim Slotları',
                        'Her slotun kaynağını, kalitesini, markasını ve çalışma durumunu ayrı ayrı yönetebilirsin.',
                        icon: AppIcons.hardwareRounded,
                        color: AppColors.gold,
                      ),
                      SizedBox(height: 10.h),
                      MineMultiSlotSection(
                        mineId: detail.mine.id,
                        mineTypeId: detail.mineType.id,
                        currentSlotCount: detail.mine.currentSlotCount,
                        maxSlotCount: detail.mine.maxSlotCount,
                      ),
                      SizedBox(height: 12.h),
                      _buildMineInventoryOverview(context, ref, detail),
"""
    if old not in text:
        raise RuntimeError('Mine production block anchor not found')
    text = text.replace(old, new, 1)

    start = text.index("  Widget _buildQuickActions(\n")
    end = text.index("  Widget _buildActionButton(\n", start)
    quick = r'''  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
    BuildingBoostModel? activeBoost,
    BuildingUpgradeModel? activeUpgrade,
  ) {
    final liveDetail = _liveMineDetail(ref, detail);
    final hasProduct = liveDetail.hasConfiguredProduction;
    final canBoost = liveDetail.hasActiveProduction && liveDetail.mine.isActive;
    final canUpgrade = liveDetail.mine.isActive;

    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: AppFx.panelWash(0.18),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppFx.softOverlay(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Ürün Gönder',
                  AppIcons.localShippingRounded,
                  AppColors.blue,
                  () => _startMineSendFlow(context, ref, liveDetail),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Boost',
                  AppIcons.flashOnRounded,
                  canBoost ? AppColors.goldDark : AppColors.textMuted,
                  canBoost
                      ? () => _showMineBoostSheet(
                          context,
                          ref,
                          liveDetail,
                          activeBoost,
                        )
                      : () {
                          AppSnackbar.show(
                            context,
                            title: 'Bilgi',
                            message: hasProduct
                                ? 'Boost için en az bir üretim slotunun aktif olması gerekir.'
                                : 'Boost başlatmadan önce en az bir üretim slotu yapılandırmalısın.',
                            type: SnackbarType.info,
                          );
                        },
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildActionButton(
                  'Yükselt',
                  AppIcons.upgradeRounded,
                  canUpgrade ? AppColors.green : AppColors.textMuted,
                  canUpgrade
                      ? () => _showMineUpgradeSheet(
                          context,
                          ref,
                          liveDetail,
                          activeUpgrade,
                        )
                      : () {
                          AppSnackbar.show(
                            context,
                            title: 'Bilgi',
                            message:
                                'Yükseltme başlatmak için madenin aktif olması gerekir.',
                            type: SnackbarType.info,
                          );
                        },
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildActionButton(
                  'Rapor',
                  AppIcons.queryStatsRounded,
                  AppColors.blue,
                  () => context.push(
                    '/production-report/mine/${liveDetail.mine.id}?name=${Uri.encodeComponent(liveDetail.mine.name)}',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

'''
    text = text[:start] + quick + text[end:]

    marker = "  Widget _buildProductionCard(\n"
    insert_at = text.index(marker)
    helpers = r'''  MineDetailModel _liveMineDetail(
    WidgetRef ref,
    MineDetailModel detail,
  ) {
    final slots = ref.watch(mineProductionSlotsProvider(detail.mine.id)).value;
    if (slots == null) return detail;
    return detail.copyWith(productionSlots: slots);
  }

  Widget _buildMineInventoryOverview(
    BuildContext context,
    WidgetRef ref,
    MineDetailModel detail,
  ) {
    final liveDetail = _liveMineDetail(ref, detail);
    final outputs = liveDetail.outputInventories;

    if (outputs.isEmpty) {
      return _buildEmptyCard(
        'Yapılandırılmış slotlar üretim yaptıkça çıkarılan ürünler burada görünecek.',
      );
    }

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: AppDecorations.panelGlass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMiniFlowHeader('Çıkarılan Ürünler', AppColors.green),
          SizedBox(height: 8.h),
          ...outputs.map(
            (inventory) => _buildInventoryCard(
              context,
              ref,
              liveDetail,
              inventory,
            ),
          ),
        ],
      ),
    );
  }

'''
    text = text[:insert_at] + helpers + text[insert_at:]
    path.write_text(text, encoding='utf-8')


def patch_sections():
    for rel, fallback in [
        ('lib/features/factory/ui/factory_multislot_section.dart', 'currentSlotCount'),
        ('lib/features/mine/ui/mine_multislot_section.dart', 'currentSlotCount'),
    ]:
        path = Path(rel)
        text = path.read_text(encoding='utf-8')
        needle = "    final slotsAsync = ref.watch("
        idx = text.index(needle)
        line_end = text.index("\n", idx)
        insert = "\n    final displayedSlotCount = slotsAsync.value?.length ?? currentSlotCount;"
        if 'displayedSlotCount' not in text:
            text = text[:line_end] + insert + text[line_end:]
        text = text.replace(
            "'$currentSlotCount / $maxSlotCount hat açık'",
            "'$displayedSlotCount / $maxSlotCount hat açık'",
        )
        text = text.replace(
            "'$currentSlotCount / $maxSlotCount slot açık'",
            "'$displayedSlotCount / $maxSlotCount slot açık'",
        )
        text = text.replace(
            "if (currentSlotCount < maxSlotCount)",
            "if (displayedSlotCount < maxSlotCount)",
        )
        path.write_text(text, encoding='utf-8')


patch_factory()
patch_mine()
patch_sections()

from pathlib import Path

factory = Path('lib/features/factory/ui/factory_detail_screen.dart')
text = factory.read_text(encoding='utf-8')
needle = "  Widget _buildProductionCard(\n"
if "// ignore: unused_element\n  Widget _buildProductionCard(" not in text:
    text = text.replace(needle, "  // Legacy single-product card kept temporarily for rollback compatibility.\n  // ignore: unused_element\n" + needle, 1)
factory.write_text(text, encoding='utf-8')

mine = Path('lib/features/mine/ui/mine_detail_screen.dart')
text = mine.read_text(encoding='utf-8')
old = """          _buildMiniFlowHeader('Çıkarılan Ürünler', AppColors.green),
          SizedBox(height: 8.h),
          ...outputs.map(
            (inventory) => _buildInventoryCard(
              context,
              ref,
              liveDetail,
              inventory,
            ),
          ),
"""
new = """          Row(
            children: [
              Icon(
                AppIcons.inventory2Outlined,
                color: AppColors.green,
                size: AppIconSizes.small,
              ),
              SizedBox(width: 7.w),
              Text(
                'Çıkarılan Ürünler',
                style: AppTextStyles.body.standardCopyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ...outputs.map(
            (inventory) => Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: _buildOutputSummaryRow(
                context,
                ref,
                liveDetail,
                inventory,
              ),
            ),
          ),
"""
if old not in text:
    raise RuntimeError('Mine inventory overview anchor not found')
text = text.replace(old, new, 1)
needle = "  Widget _buildProductionCard(\n"
if "// ignore: unused_element\n  Widget _buildProductionCard(" not in text:
    text = text.replace(needle, "  // Legacy single-product card kept temporarily for rollback compatibility.\n  // ignore: unused_element\n" + needle, 1)
mine.write_text(text, encoding='utf-8')

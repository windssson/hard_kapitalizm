import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/widgets/cached_asset_image.dart';
import 'package:hard_kapitalizm/core/widgets/app_top_bar.dart';
import 'package:hard_kapitalizm/core/widgets/app_bottom_nav.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            const AppTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Column(
                  children: [
                    _buildCompanySummaryCard(),
                    SizedBox(height: 12.h),
                    _buildModuleGrid(),
                    SizedBox(height: 12.h),
                    _buildFinancialStats(),
                    SizedBox(height: 12.h),
                    _buildNewsSection(),
                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
            AppBottomNav(
              selectedIndex: _selectedIndex,
              onItemSelected: (index) {
                if (index == _selectedIndex) return;
                switch (index) {
                  case 0:
                    context.go('/home');
                    break;
                  case 2:
                    context.go('/store');
                    break;
                  case 4:
                    context.go('/profile');
                    break;
                  // İleride 1, 3 buralara eklenecek
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Şirket Özeti Kartı ───────────────────────────────────────────────────
  Widget _buildCompanySummaryCard() {
    return Consumer(
      builder: (context, ref, child) {
        final playerAsyncValue = ref.watch(playerStreamProvider);
        final player = playerAsyncValue.value;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.borderGold),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kart Başlığı
              Container(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                child: Text('ŞİRKET ÖZETİ', style: AppTextStyles.titleGold),
              ),
              // İçerik (Görsel ve İstatistikler)
              Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sol: Avatar ve Seviye Çerçevesi
                    Expanded(
                      flex: 10,
                      child: SizedBox(
                        height: 180.h,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Avatar Çerçevesi ve Rozet
                            Stack(
                              alignment: Alignment.bottomCenter,
                              clipBehavior: Clip.none,
                              children: [
                                // Dış Çerçeve (Level'a göre renk/stil alacak, örn: Altın)
                                Container(
                                  margin: EdgeInsets.only(
                                    bottom: 10.h,
                                  ), // Rozet için yer
                                  width: 100.w,
                                  height: 100.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.cardBgLight,
                                    border: Border.all(
                                      color: AppColors.gold,
                                      width: 3.w,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.gold.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 12.r,
                                        spreadRadius: 2.r,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: CachedAssetImage(
                                      fileName: player != null
                                          ? player.avatarId
                                          : 'ae1.webp', // Oyuncunun seçeceği avatar
                                      fit: BoxFit.cover,
                                      placeholder: Icon(
                                        Icons.person,
                                        color: AppColors.gold,
                                        size: 50.sp,
                                      ),
                                      errorWidget: Icon(
                                        Icons.person,
                                        color: AppColors.gold,
                                        size: 50.sp,
                                      ),
                                    ),
                                  ),
                                ),
                                // Seviye Rozeti
                                Positioned(
                                  bottom: 0,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16.w,
                                      vertical: 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.navBg,
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: AppColors.gold,
                                        width: 2.w,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 4.r,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      player != null
                                          ? 'Lv. ${player.level}'
                                          : 'Lv. 1',
                                      style: TextStyle(
                                        color: AppColors.goldLight,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),
                            // Unvan
                            Text(
                              player != null ? player.playerName : 'CEO',
                              style: TextStyle(
                                color: AppColors.goldLight,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            // Exp Bar
                            Container(
                              height: 6.h,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(3.r),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: player != null
                                    ? (player.experience / 1000).clamp(0.0, 1.0)
                                    : 0.0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.gold,
                                    borderRadius: BorderRadius.circular(3.r),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              player != null
                                  ? '${player.experience} / 1000 XP'
                                  : '0 / 1000 XP',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    // Sağ: İstatistikler
                    Expanded(
                      flex: 11,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Şirket Değeri', style: AppTextStyles.body),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                player != null
                                    ? _formatMoney(player.cash)
                                    : '...',
                                style: AppTextStyles.statValue,
                              ),
                              const Spacer(),
                              Icon(
                                Icons.bar_chart,
                                color: AppColors.gold,
                                size: 36.sp,
                              ),
                            ],
                          ),
                          SizedBox(height: 6.h),
                          Divider(color: AppColors.border, height: 1.h),
                          SizedBox(height: 10.h),
                          _buildSummaryRow(
                            Icons.show_chart,
                            'Günlük Kâr',
                            '+1.28M',
                            AppColors.green,
                          ),
                          SizedBox(height: 8.h),
                          _buildSummaryRow(
                            Icons.business,
                            'Aktif İşletme',
                            '18 işletme',
                            AppColors.textPrimary,
                          ),
                          SizedBox(height: 8.h),
                          _buildSummaryRow(
                            Icons.location_on,
                            'Şehir:',
                            'Erzurum',
                            AppColors.textPrimary,
                          ),
                          SizedBox(height: 16.h),
                          // Şirket Raporu Butonu
                          Container(
                            width: double.infinity,
                            height: 36.h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF0F2B5B), Color(0xFF061430)],
                              ),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(color: Color(0xFF1E407C)),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {},
                                borderRadius: BorderRadius.circular(8.r),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.analytics,
                                      color: AppColors.textPrimary,
                                      size: 16.sp,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Şirket Raporu',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.chevron_right,
                                      color: AppColors.textPrimary,
                                      size: 18.sp,
                                    ),
                                    SizedBox(width: 4.w),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatMoney(dynamic amount) {
    if (amount == null) return '0';
    double val = double.parse(amount.toString());
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1)}M';
    } else if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1)}K';
    }
    return val.toStringAsFixed(0);
  }

  Widget _buildSummaryRow(
    IconData icon,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 16.sp),
        SizedBox(width: 6.w),
        Text(label, style: AppTextStyles.body),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ─── Modül Gridi ──────────────────────────────────────────────────────────
  Widget _buildModuleGrid() {
    final modules = [
      {'title': 'Mağazalar', 'image': 'magazalar.webp'},
      {'title': 'Depolar', 'image': 'depolar.webp'},
      {'title': 'Fabrikalar', 'image': 'fabrikalar.webp'},
      {'title': 'Tarlalar', 'image': 'tarlalar.webp'},
      {'title': 'Çiftlikler', 'image': 'ciftlikler.webp'},
      {'title': 'Madenler', 'image': 'madenler.webp'},
      {'title': 'Nakliye', 'image': 'nakliyeler.webp'},
      {'title': 'AR-GE', 'image': 'arge.webp'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 6.w,
        mainAxisSpacing: 6.h,
        childAspectRatio: 0.85,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        return Material(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(10.r),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (modules[index]['title'] == 'Mağazalar') {
                context.go('/store');
              }
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppColors.borderGold.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Modül Görseli
                  SizedBox(
                    width: 64.w,
                    height: 64.h,
                    child: CachedAssetImage(
                      fileName: modules[index]['image'] as String,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        modules[index]['title'] as String,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.gold,
                        size: 14.sp,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Finansal İstatistikler ───────────────────────────────────────────────
  Widget _buildFinancialStats() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFinStatItem(
            'Toplam Gelir',
            '+12.85M',
            'Bugün',
            AppColors.green,
            Icons.payments,
            Colors.green,
          ),
          _buildVerticalDivider(),
          _buildFinStatItem(
            'Gider',
            '-6.42M',
            'Bugün',
            AppColors.red,
            Icons.account_balance_wallet,
            Colors.red,
          ),
          _buildVerticalDivider(),
          _buildFinStatItem(
            'Net Kâr',
            '+6.43M',
            'Bugün',
            AppColors.green,
            Icons.monetization_on,
            AppColors.gold,
          ),
          _buildVerticalDivider(),
          _buildFinStatItem(
            'Bekleyen İşlem',
            '7',
            'Adet',
            AppColors.gold,
            Icons.hourglass_top,
            AppColors.gold,
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 40.h, width: 1.w, color: AppColors.border);
  }

  Widget _buildFinStatItem(
    String title,
    String value,
    String subtitle,
    Color valueColor,
    IconData icon,
    Color iconColor,
  ) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 18.sp),
          SizedBox(width: 4.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(title, style: AppTextStyles.body.copyWith(fontSize: 10.sp)),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: AppTextStyles.body.copyWith(fontSize: 10.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Güncel Durum ─────────────────────────────────────────────────────────
  Widget _buildNewsSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(Icons.notifications, color: AppColors.gold, size: 20.sp),
                SizedBox(width: 8.w),
                Text(
                  'Güncel Durum',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Tümünü Gör',
                  style: TextStyle(color: AppColors.blue, fontSize: 12.sp),
                ),
                Icon(Icons.chevron_right, color: AppColors.blue, size: 16.sp),
              ],
            ),
          ),
          Divider(height: 1.h, color: AppColors.border),
          // Yatay kaydırılabilir bildirimler
          SizedBox(
            height: 80.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              children: [
                _buildNewsCard(
                  'Bisküvi fabrikasında\nhammadde azalıyor.',
                  '15 dk önce',
                  Icons.cookie,
                  Colors.orange,
                  Icons.warning_amber_rounded,
                  Colors.red,
                ),
                _buildNewsCard(
                  '1 nakliye aracı\nteslimata çıktı.',
                  '35 dk önce',
                  Icons.local_shipping,
                  AppColors.blue,
                  Icons.check_circle,
                  AppColors.green,
                ),
                _buildNewsCard(
                  'Vergi ödeme tarihi\nyaklaşıyor.',
                  '2 sa önce',
                  Icons.receipt_long,
                  AppColors.gold,
                  Icons.warning_amber_rounded,
                  Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(
    String text,
    String time,
    IconData mainIcon,
    Color mainColor,
    IconData badgeIcon,
    Color badgeColor,
  ) {
    return Container(
      width: 240.w,
      margin: EdgeInsets.only(right: 12),
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBgLight,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // İkon ve Badge Stack
          SizedBox(
            width: 40.w,
            height: 40.h,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(mainIcon, color: mainColor, size: 20.sp),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(badgeIcon, color: badgeColor, size: 14.sp),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          // Metinler
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.sp,
                    height: 1.2.h,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: AppColors.textMuted,
                      size: 10.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      time,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.gold, size: 18.sp),
        ],
      ),
    );
  }
}

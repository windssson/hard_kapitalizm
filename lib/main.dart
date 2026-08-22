import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/ads/transfer_finish_rewarded_ad_service.dart';
import 'package:hard_kapitalizm/core/constants/supabase_constants.dart';
import 'package:hard_kapitalizm/features/home/ui/home_screen.dart';
import 'package:hard_kapitalizm/features/splash/ui/splash_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/store_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/store_detail_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/store_history_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/store_performance_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/store_warehouse_detail_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/city_selection_screen.dart';
import 'package:hard_kapitalizm/core/widgets/building_type_selection_screen.dart';
import 'package:hard_kapitalizm/features/auth/ui/profile_screen.dart';
import 'package:hard_kapitalizm/features/auth/ui/public_profile_screen.dart';
import 'package:hard_kapitalizm/features/premium/ui/premium_store_screen.dart';
import 'package:hard_kapitalizm/features/field/ui/field_screen.dart';
import 'package:hard_kapitalizm/features/field/ui/field_detail_screen.dart';
import 'package:hard_kapitalizm/features/farm/ui/farm_screen.dart';
import 'package:hard_kapitalizm/features/farm/ui/farm_detail_screen.dart';
import 'package:hard_kapitalizm/features/factory/ui/factory_screen.dart';
import 'package:hard_kapitalizm/features/factory/ui/factory_detail_screen.dart';
import 'package:hard_kapitalizm/features/mine/ui/mine_screen.dart';
import 'package:hard_kapitalizm/features/mine/ui/mine_detail_screen.dart';
import 'package:hard_kapitalizm/core/widgets/tutorial_overlay.dart';
import 'package:hard_kapitalizm/features/market/ui/market_screen.dart';
import 'package:hard_kapitalizm/features/company/ui/company_screen.dart';
import 'package:hard_kapitalizm/features/company/ui/brand_design_screen.dart';
import 'package:hard_kapitalizm/features/company/ui/brand_product_design_screen.dart';
import 'package:hard_kapitalizm/features/logistics/ui/logistics_finance_report_screen.dart';
import 'package:hard_kapitalizm/features/logistics/ui/logistics_management_screen.dart';
import 'package:hard_kapitalizm/features/logistics/ui/logistics_setup_screen.dart';
import 'package:hard_kapitalizm/features/transfer_map/ui/transfer_map_screen.dart';
import 'package:hard_kapitalizm/features/warehouse/ui/warehouse_screen.dart';
import 'package:hard_kapitalizm/features/warehouse/ui/warehouse_detail_screen.dart';
import 'package:hard_kapitalizm/features/warehouse/ui/warehouse_history_screen.dart';
import 'package:hard_kapitalizm/features/arge/ui/arge_screen.dart';
import 'package:hard_kapitalizm/features/mission/ui/mission_screen.dart';
import 'package:hard_kapitalizm/features/tax/ui/tax_screen.dart';
import 'package:hard_kapitalizm/features/bank/ui/bank_screen.dart';
import 'package:hard_kapitalizm/features/notification/ui/notification_screen.dart';
import 'package:hard_kapitalizm/features/notification/ui/alert_screen.dart';
import 'package:hard_kapitalizm/features/achievement/ui/achievement_screen.dart';
import 'package:hard_kapitalizm/features/leaderboard/ui/leaderboard_screen.dart';
import 'package:hard_kapitalizm/features/cash_flow/ui/cash_flow_screen.dart';
import 'package:hard_kapitalizm/features/production_report/ui/production_report_screen.dart';
import 'package:hard_kapitalizm/features/tender/ui/tender_center_screen.dart';
import 'package:hard_kapitalizm/features/tender/ui/tender_detail_screen.dart';
import 'package:hard_kapitalizm/features/chat/ui/chat_screen.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/navigation/app_route_observer.dart';
import 'package:hard_kapitalizm/core/widgets/timed_task_runtime.dart';

import 'package:hard_kapitalizm/features/auth/ui/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    publishableKey: SupabaseConstants.supabaseAnonKey,
  );

  if (TransferFinishRewardedAdService.appId != null) {
    await MobileAds.instance.initialize();
  }

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: HardKapitalizmApp()));
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  observers: [appRouteObserver],
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/missions',
      builder: (context, state) => const MissionScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationScreen(),
    ),
    GoRoute(path: '/alerts', builder: (context, state) => const AlertScreen()),
    GoRoute(
      path: '/achievements',
      builder: (context, state) => const AchievementScreen(),
    ),
    GoRoute(
      path: '/leaderboard',
      builder: (context, state) => const LeaderboardScreen(),
    ),
    GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
    GoRoute(
      path: '/cash-history',
      builder: (context, state) => const CashFlowScreen(),
    ),
    GoRoute(
      path: '/production-report/:ownerKind/:id',
      builder: (context, state) => ProductionReportScreen(
        ownerKind: state.pathParameters['ownerKind'] ?? 'factory',
        ownerId: state.pathParameters['id'] ?? '',
        ownerName: state.uri.queryParameters['name'] ?? 'Uretim Birimi',
      ),
    ),
    GoRoute(
      path: '/transfer-map',
      builder: (context, state) => const TransferMapScreen(),
    ),
    GoRoute(
      path: '/store',
      builder: (context, state) => const StoreScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) => const CitySelectionScreen(),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra is CityModel ? (state.extra as CityModel) : null;
            if (city == null) {
              return const CitySelectionScreen();
            }
            return BuildingTypeSelectionScreen(
              selectedCity: city,
              buildingKind: 'store',
            );
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              StoreDetailScreen(storeId: state.pathParameters['id'] ?? ''),
          routes: [
            GoRoute(
              path: 'history',
              builder: (context, state) =>
                  StoreHistoryScreen(storeId: state.pathParameters['id'] ?? ''),
            ),
            GoRoute(
              path: 'report',
              builder: (context, state) =>
                  StorePerformanceScreen(storeId: state.pathParameters['id'] ?? ''),
            ),
            GoRoute(
              path: 'warehouse',
              builder: (context, state) => StoreWarehouseDetailScreen(
                storeId: state.pathParameters['id'] ?? '',
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
      routes: [
        GoRoute(
          path: 'public/:id',
          builder: (context, state) =>
              PublicProfileScreen(playerId: state.pathParameters['id'] ?? ''),
        ),
      ],
    ),
    GoRoute(
      path: '/premium-store',
      builder: (context, state) => const PremiumStoreScreen(),
    ),
    GoRoute(
      path: '/fields',
      builder: (context, state) => const FieldScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) =>
              const CitySelectionScreen(buildingKind: 'field'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra is CityModel ? (state.extra as CityModel) : null;
            if (city == null) {
              return const CitySelectionScreen(buildingKind: 'field');
            }
            return BuildingTypeSelectionScreen(
              selectedCity: city,
              buildingKind: 'field',
            );
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              FieldDetailScreen(fieldId: state.pathParameters['id'] ?? ''),
        ),
      ],
    ),
    GoRoute(
      path: '/farms',
      builder: (context, state) => const FarmScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) =>
              const CitySelectionScreen(buildingKind: 'farm'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra is CityModel ? (state.extra as CityModel) : null;
            if (city == null) {
              return const CitySelectionScreen(buildingKind: 'farm');
            }
            return BuildingTypeSelectionScreen(
              selectedCity: city,
              buildingKind: 'farm',
            );
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              FarmDetailScreen(farmId: state.pathParameters['id'] ?? ''),
        ),
      ],
    ),
    GoRoute(
      path: '/factories',
      builder: (context, state) => const FactoryScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) =>
              const CitySelectionScreen(buildingKind: 'factory'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra is CityModel ? (state.extra as CityModel) : null;
            if (city == null) {
              return const CitySelectionScreen(buildingKind: 'factory');
            }
            return BuildingTypeSelectionScreen(
              selectedCity: city,
              buildingKind: 'factory',
            );
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              FactoryDetailScreen(factoryId: state.pathParameters['id'] ?? ''),
        ),
      ],
    ),
    GoRoute(
      path: '/mines',
      builder: (context, state) => const MineScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) =>
              const CitySelectionScreen(buildingKind: 'mine'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra is CityModel ? (state.extra as CityModel) : null;
            if (city == null) {
              return const CitySelectionScreen(buildingKind: 'mine');
            }
            return BuildingTypeSelectionScreen(
              selectedCity: city,
              buildingKind: 'mine',
            );
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              MineDetailScreen(mineId: state.pathParameters['id'] ?? ''),
        ),
      ],
    ),
    GoRoute(
      path: '/logistics',
      builder: (context, state) => const LogisticsManagementScreen(),
    ),
    GoRoute(
      path: '/logistics/finance',
      builder: (context, state) => const LogisticsFinanceReportScreen(),
    ),
    GoRoute(
      path: '/logistics/setup',
      builder: (context, state) => const LogisticsSetupScreen(),
    ),
    GoRoute(
      path: '/company',
      builder: (context, state) => const CompanyScreen(),
    ),
    GoRoute(
      path: '/company/design',
      builder: (context, state) => const BrandDesignScreen(),
    ),
    GoRoute(
      path: '/company/products/:productId/design',
      builder: (context, state) => BrandProductDesignScreen(
        productId: state.pathParameters['productId'] ?? '',
      ),
    ),
    GoRoute(
      path: '/market',
      builder: (context, state) {
        final warehouseId = state.uri.queryParameters['warehouseId'] ?? '';
        final playerId = state.uri.queryParameters['playerId'] ?? '';
        final cityId = state.uri.queryParameters['cityId'] ?? '';

        return MarketScreen(
          warehouseId: warehouseId,
          playerId: playerId,
          cityId: cityId,
        );
      },
    ),
    GoRoute(
      path: '/market/:productId',
      builder: (context, state) {
        final productId = state.pathParameters['productId'] ?? '';
        final warehouseId = state.uri.queryParameters['warehouseId'] ?? '';
        final playerId = state.uri.queryParameters['playerId'] ?? '';
        final cityId = state.uri.queryParameters['cityId'] ?? '';

        return MarketScreen(
          productId: productId,
          warehouseId: warehouseId,
          playerId: playerId,
          cityId: cityId,
        );
      },
    ),
    GoRoute(
      path: '/warehouses',
      builder: (context, state) => const WarehouseScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) =>
              const CitySelectionScreen(buildingKind: 'warehouse'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra is CityModel ? (state.extra as CityModel) : null;
            if (city == null) {
              return const CitySelectionScreen(buildingKind: 'warehouse');
            }
            return BuildingTypeSelectionScreen(
              selectedCity: city,
              buildingKind: 'warehouse',
            );
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return WarehouseDetailScreen(warehouseId: id);
          },
          routes: [
            GoRoute(
              path: 'history',
              builder: (context, state) => WarehouseHistoryScreen(
                warehouseId: state.pathParameters['id'] ?? '',
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: '/arge', builder: (context, state) => const ArgeScreen()),
    GoRoute(path: '/tax', builder: (context, state) => const TaxScreen()),
    GoRoute(path: '/bank', builder: (context, state) => const BankScreen()),
    GoRoute(
      path: '/tenders',
      builder: (context, state) => const TenderCenterScreen(),
      routes: [
        GoRoute(
          path: 'open/:id',
          builder: (context, state) =>
              TenderDetailScreen(tenderId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: 'player/:id',
          builder: (context, state) =>
              TenderDetailScreen(playerTenderId: state.pathParameters['id'] ?? ''),
        ),
      ],
    ),
  ],
);

class HardKapitalizmApp extends StatelessWidget {
  const HardKapitalizmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        final appTheme = AppTheme.buildTheme();
        return MaterialApp.router(
          title: 'Hard Kapitalizm',
          debugShowCheckedModeBanner: false,
          theme: appTheme.copyWith(
            scaffoldBackgroundColor: AppColors.transparent,
            colorScheme: appTheme.colorScheme.copyWith(
              surface: AppColors.transparent,
            ),
          ),
          builder: (context, materialChild) {
            return TimedTaskRuntime(
              child: Stack(
                children: [
                  Container(color: AppColors.background),
                  TutorialOverlay(child: materialChild!),
                ],
              ),
            );
          },
          routerConfig: appRouter,
        );
      },
    );
  }
}

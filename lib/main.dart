import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hard_kapitalizm/core/constants/supabase_constants.dart';
import 'package:hard_kapitalizm/features/home/ui/home_screen.dart';
import 'package:hard_kapitalizm/features/splash/ui/splash_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/store_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/store_detail_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/store_history_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/store_performance_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/store_warehouse_detail_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/city_selection_screen.dart';
import 'package:hard_kapitalizm/features/store/ui/store_type_selection_screen.dart';
import 'package:hard_kapitalizm/features/auth/ui/profile_screen.dart';
import 'package:hard_kapitalizm/features/field/ui/field_screen.dart';
import 'package:hard_kapitalizm/features/field/ui/field_detail_screen.dart';
import 'package:hard_kapitalizm/features/field/ui/field_type_selection_screen.dart';
import 'package:hard_kapitalizm/features/farm/ui/farm_screen.dart';
import 'package:hard_kapitalizm/features/farm/ui/farm_detail_screen.dart';
import 'package:hard_kapitalizm/features/farm/ui/farm_type_selection_screen.dart';
import 'package:hard_kapitalizm/features/factory/ui/factory_screen.dart';
import 'package:hard_kapitalizm/features/factory/ui/factory_detail_screen.dart';
import 'package:hard_kapitalizm/features/factory/ui/factory_type_selection_screen.dart';
import 'package:hard_kapitalizm/features/mine/ui/mine_screen.dart';
import 'package:hard_kapitalizm/features/mine/ui/mine_detail_screen.dart';
import 'package:hard_kapitalizm/features/mine/ui/mine_type_selection_screen.dart';
import 'package:hard_kapitalizm/features/market/ui/market_screen.dart';
import 'package:hard_kapitalizm/features/company/ui/company_screen.dart';
import 'package:hard_kapitalizm/features/company/ui/brand_design_screen.dart';
import 'package:hard_kapitalizm/features/company/ui/brand_product_design_screen.dart';
import 'package:hard_kapitalizm/features/logistics/ui/logistics_finance_report_screen.dart';
import 'package:hard_kapitalizm/features/logistics/ui/logistics_management_screen.dart';
import 'package:hard_kapitalizm/features/logistics/ui/logistics_setup_screen.dart';
import 'package:hard_kapitalizm/features/transfer_map/ui/transfer_map_screen.dart';
import 'package:hard_kapitalizm/features/warehouse/ui/warehouse_screen.dart';
import 'package:hard_kapitalizm/features/warehouse/ui/warehouse_type_selection_screen.dart';
import 'package:hard_kapitalizm/features/warehouse/ui/warehouse_detail_screen.dart';
import 'package:hard_kapitalizm/features/warehouse/ui/warehouse_history_screen.dart';
import 'package:hard_kapitalizm/features/arge/ui/arge_screen.dart';
import 'package:hard_kapitalizm/features/mission/ui/mission_screen.dart';
import 'package:hard_kapitalizm/features/notification/ui/notification_screen.dart';
import 'package:hard_kapitalizm/features/notification/ui/alert_screen.dart';
import 'package:hard_kapitalizm/features/achievement/ui/achievement_screen.dart';
import 'package:hard_kapitalizm/features/cash_flow/ui/cash_flow_screen.dart';
import 'package:hard_kapitalizm/features/production_report/ui/production_report_screen.dart';
import 'package:hard_kapitalizm/core/theme/app_theme.dart';
import 'package:hard_kapitalizm/core/models/city_model.dart';
import 'package:hard_kapitalizm/core/navigation/app_route_observer.dart';
import 'package:hard_kapitalizm/core/widgets/timed_task_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: HardKapitalizmApp()));
}

final _router = GoRouter(
  initialLocation: '/',
  observers: [appRouteObserver],
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/missions',
      builder: (context, state) => const MissionScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationScreen(),
    ),
    GoRoute(
      path: '/alerts',
      builder: (context, state) => const AlertScreen(),
    ),
    GoRoute(
      path: '/achievements',
      builder: (context, state) => const AchievementScreen(),
    ),
    GoRoute(
      path: '/cash-history',
      builder: (context, state) => const CashFlowScreen(),
    ),
    GoRoute(
      path: '/production-report/:ownerKind/:id',
      builder: (context, state) => ProductionReportScreen(
        ownerKind: state.pathParameters['ownerKind']!,
        ownerId: state.pathParameters['id']!,
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
            final city = state.extra as CityModel;
            return StoreTypeSelectionScreen(selectedCity: city);
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) => StoreDetailScreen(
            storeId: state.pathParameters['id']!,
          ),
          routes: [
            GoRoute(
              path: 'history',
              builder: (context, state) => StoreHistoryScreen(
                storeId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: 'report',
              builder: (context, state) => StorePerformanceScreen(
                storeId: state.pathParameters['id']!,
              ),
            ),
            GoRoute(
              path: 'warehouse',
              builder: (context, state) => StoreWarehouseDetailScreen(
                storeId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(
      path: '/fields',
      builder: (context, state) => const FieldScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) => const CitySelectionScreen(buildingKind: 'field'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra as CityModel;
            return FieldTypeSelectionScreen(selectedCity: city);
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              FieldDetailScreen(fieldId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/farms',
      builder: (context, state) => const FarmScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) => const CitySelectionScreen(buildingKind: 'farm'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra as CityModel;
            return FarmTypeSelectionScreen(selectedCity: city);
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              FarmDetailScreen(farmId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/factories',
      builder: (context, state) => const FactoryScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) => const CitySelectionScreen(buildingKind: 'factory'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra as CityModel;
            return FactoryTypeSelectionScreen(selectedCity: city);
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) => FactoryDetailScreen(
            factoryId: state.pathParameters['id']!,
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/mines',
      builder: (context, state) => const MineScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) => const CitySelectionScreen(buildingKind: 'mine'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra as CityModel;
            return MineTypeSelectionScreen(selectedCity: city);
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) => MineDetailScreen(
            mineId: state.pathParameters['id']!,
          ),
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
        productId: state.pathParameters['productId']!,
      ),
    ),
    GoRoute(
      path: '/market',
      builder: (context, state) {
        final warehouseId = state.uri.queryParameters['warehouseId'] ?? '';
        final playerId = state.uri.queryParameters['playerId'] ?? '';
        final cityId = state.uri.queryParameters['cityId'] ?? '';
        final targetType = state.uri.queryParameters['targetType'] ?? 'warehouse';
        final storeId = state.uri.queryParameters['storeId'] ?? '';
        final storeSlotId = state.uri.queryParameters['storeSlotId'] ?? '';

        return MarketScreen(
          warehouseId: warehouseId,
          playerId: playerId,
          cityId: cityId,
          targetType: targetType,
          storeId: storeId,
          storeSlotId: storeSlotId,
        );
      },
    ),
    GoRoute(
      path: '/market/:productId',
      builder: (context, state) {
        final productId = state.pathParameters['productId']!;
        final warehouseId = state.uri.queryParameters['warehouseId'] ?? '';
        final playerId = state.uri.queryParameters['playerId'] ?? '';
        final cityId = state.uri.queryParameters['cityId'] ?? '';
        final targetType = state.uri.queryParameters['targetType'] ?? 'warehouse';
        final storeId = state.uri.queryParameters['storeId'] ?? '';
        final storeSlotId = state.uri.queryParameters['storeSlotId'] ?? '';

        return MarketScreen(
          productId: productId,
          warehouseId: warehouseId,
          playerId: playerId,
          cityId: cityId,
          targetType: targetType,
          storeId: storeId,
          storeSlotId: storeSlotId,
        );
      },
    ),
    GoRoute(
      path: '/warehouses',
      builder: (context, state) => const WarehouseScreen(),
      routes: [
        GoRoute(
          path: 'new/city',
          builder: (context, state) => const CitySelectionScreen(buildingKind: 'warehouse'),
        ),
        GoRoute(
          path: 'new/type',
          builder: (context, state) {
            final city = state.extra as CityModel;
            return WarehouseTypeSelectionScreen(selectedCity: city);
          },
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return WarehouseDetailScreen(warehouseId: id);
          },
          routes: [
            GoRoute(
              path: 'history',
              builder: (context, state) => WarehouseHistoryScreen(
                warehouseId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/arge',
      builder: (context, state) => const ArgeScreen(),
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
        return MaterialApp.router(
          title: 'Hard Kapitalizm',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            scaffoldBackgroundColor: Colors.transparent,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blueGrey,
              brightness: Brightness.dark,
              surface: Colors.transparent,
            ),
            useMaterial3: true,
          ),
          builder: (context, materialChild) {
            return TimedTaskRuntime(
              child: Stack(
                children: [
                  Container(color: AppColors.background),
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.06,
                      child: Image.asset(
                        'assets/back.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  materialChild!,
                ],
              ),
            );
          },
          routerConfig: _router,
        );
      },
    );
  }
}

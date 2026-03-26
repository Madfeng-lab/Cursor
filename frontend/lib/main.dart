import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api_client.dart';
import 'auth_page.dart';
import 'auth_state.dart';
import 'home_page.dart';
import 'training_page.dart';
import 'diet_page.dart';
import 'stats_page.dart';
import 'widgets/ai_coach_fab.dart';

// 构建时可覆盖：`flutter run --dart-define=API_BASE=http://10.0.2.2:8080`
const String _kApiBaseFromEnv = String.fromEnvironment(
  'API_BASE',
  defaultValue: '',
);

void main() {
  runApp(const FitnessApp());
}

class MainTabState extends ChangeNotifier {
  int _index = 0;

  int get index => _index;

  void setIndex(int value) {
    if (value == _index) return;
    _index = value;
    notifyListeners();
  }

  /// 无论当前 tab 是否已经是指定值，都强制触发一次重建。
  /// 用于训练完成后刷新主页「进行中」卡片等状态。
  void refresh() {
    notifyListeners();
  }
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    final resolvedApiBase = _kApiBaseFromEnv.isNotEmpty
        ? _kApiBaseFromEnv
        : _resolveDefaultApiBase();
    final apiClient = ApiClient(baseUrl: resolvedApiBase);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState(apiClient)),
        ChangeNotifierProvider(create: (_) => MainTabState()),
      ],
      child: Consumer<AuthState>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'Fitness MVP',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
            home: auth.isAuthenticated ? const MainScaffold() : const AuthPage(),
          );
        },
      ),
    );
  }
}

String _resolveDefaultApiBase() {
  if (!Uri.base.hasAuthority) return 'http://localhost:8080';

  final host = Uri.base.host.toLowerCase();
  final isLocalHost = host == 'localhost' || host == '127.0.0.1';

  // Flutter web debug server usually runs on a random localhost port
  // (e.g. 59244). Backend remains on 8080, so use it by default.
  if (isLocalHost && Uri.base.port != 8080) {
    return 'http://localhost:8080';
  }
  return Uri.base.origin;
}

class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final tabState = context.watch<MainTabState>();
    final pages = [
      HomePage(),
      const TrainingPage(),
      const DietPage(),
      const StatsPage(),
      const ProfilePage(),
    ];
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: pages[tabState.index]),
          Positioned.fill(
            child: Consumer<AuthState>(
              builder: (context, auth, _) {
                return AiCoachFab(apiClient: auth.apiClient);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabState.index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '首页'),
          NavigationDestination(icon: Icon(Icons.fitness_center_outlined), label: '训练'),
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), label: '饮食'),
          NavigationDestination(icon: Icon(Icons.show_chart_outlined), label: '统计'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
        ],
        onDestinationSelected: (index) {
          context.read<MainTabState>().setIndex(index);
        },
      ),
    );
  }
}



class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(auth.isAuthenticated ? '已登录' : '未登录'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: auth.isAuthenticated ? auth.logout : null,
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
  }
}


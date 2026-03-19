import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api_client.dart';
import 'auth_page.dart';
import 'auth_state.dart';
import 'home_page.dart';
import 'training_page.dart';
import 'diet_page.dart';
import 'stats_page.dart';

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
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient(
      // Web/Windows use localhost; Android emulator would use 10.0.2.2.
      // 部署到服务器时可改回 Uri.base.origin
      baseUrl: 'http://localhost:8080',
    );

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

class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final tabState = context.watch<MainTabState>();
    final pages = [
      const HomePage(),
      const TrainingPage(),
      const DietPage(),
      const StatsPage(),
      const ProfilePage(),
    ];
    return Scaffold(
      body: pages[tabState.index],
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


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api_client.dart';
import 'auth_state.dart';
import 'main.dart';
import 'training_detail_page.dart';
import 'training_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = context.read<AuthState>().apiClient;
    // 目前后端还未从 token 解析 userId，这里先用 1 作为演示账号。
    const userId = 1;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HomeHeader(),
              const SizedBox(height: 16),
              const _DailyCalorieBalanceCard(),
              const SizedBox(height: 16),
              _QuickActionsRow(
                onWorkout: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TrainingPage(),
                    ),
                  );
                },
                onDiet: () {
                  final mainTabState = context.read<MainTabState>();
                  mainTabState.setIndex(2);
                },
              ),
              const SizedBox(height: 20),
              _TodayWorkoutFocusCard(apiClient: apiClient, userId: userId),
              const SizedBox(height: 20),
              const _DietAnalysisBriefCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey.shade300,
              child: const Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '早上好,',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  'Alex Zhang',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_outlined),
        ),
      ],
    );
  }
}

class _DailyCalorieBalanceCard extends StatelessWidget {
  const _DailyCalorieBalanceCard();

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF25F46A);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日热量平衡',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '还可摄入 450 kcal',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '1,230',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'kcal 净值',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Container(color: Colors.grey.shade200),
                    FractionallySizedBox(
                      widthFactor: 0.65,
                      child: Container(color: primary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(
                  child: _CalorieSmallCard(
                    icon: Icons.restaurant,
                    iconColor: primary,
                    title: '已摄入',
                    value: '1,850 kcal',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _CalorieSmallCard(
                    icon: Icons.bolt,
                    iconColor: Colors.blue,
                    title: '已消耗',
                    value: '620 kcal',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalorieSmallCard extends StatelessWidget {
  const _CalorieSmallCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: iconColor.withOpacity(0.06),
        border: Border.all(color: iconColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 4),
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onWorkout,
    required this.onDiet,
  });

  final VoidCallback onWorkout;
  final VoidCallback onDiet;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF25F46A);
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: onWorkout,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              shadowColor: primary.withOpacity(0.3),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.fitness_center),
                SizedBox(height: 4),
                Text('记录健身', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: onDiet,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.fastfood, color: primary),
                SizedBox(height: 4),
                Text('记录饮食', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayWorkoutFocusCard extends StatelessWidget {
  const _TodayWorkoutFocusCard({
    required this.apiClient,
    required this.userId,
  });

  final ApiClient apiClient;
  final int userId;

  @override
  Widget build(BuildContext context) {
    final mainTabState = context.read<MainTabState>();
    return SizedBox(
      height: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FutureBuilder<WorkoutSessionLite?>(
          future: apiClient.fetchUnfinishedWorkoutSession(userId: userId),
          builder: (context, snapshot) {
            final unfinished = snapshot.data;
            final isEffectivelyUnfinished = unfinished != null &&
                unfinished.exercises.isNotEmpty &&
                unfinished.exercises.any((ex) =>
                    ex.sets.isEmpty ||
                    ex.sets.any((s) => !s.completed));
            final hasUnfinished = isEffectivelyUnfinished;
            final loading = snapshot.connectionState != ConnectionState.done;

            final tagColor = hasUnfinished ? const Color(0xFF25F46A) : Colors.grey;
            final tagText = hasUnfinished ? '进行中' : '未开始';
            final unfinishedTitle = unfinished?.title;
            final titleText = (unfinishedTitle != null && unfinishedTitle.isNotEmpty)
                ? unfinishedTitle
                : '开始一次训练吧';
            final subtitleText = (!hasUnfinished || unfinished == null)
                ? '点击进入动作库选择训练动作'
                : '${unfinished.exercises.length} 个动作 | 已用 ${unfinished.elapsedSeconds ~/ 60} 分钟';

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: loading
                    ? null
                    : () async {
                        try {
                          // 点击时重新拉取最新的未完成会话，避免 FutureBuilder 的快照陈旧导致跳错页面。
                          final currentUnfinished = await apiClient.fetchUnfinishedWorkoutSession(
                            userId: userId,
                          );
                          final currentEffectivelyUnfinished = currentUnfinished != null &&
                              currentUnfinished.exercises.isNotEmpty &&
                              currentUnfinished.exercises.any((ex) =>
                                  ex.sets.isEmpty ||
                                  ex.sets.any((s) => !s.completed));

                          if (currentEffectivelyUnfinished) {
                            if (!context.mounted) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TrainingDetailPage(
                                  apiClient: apiClient,
                                  userId: userId,
                                  exerciseName: currentUnfinished!.title,
                                  imageAssetPath: null,
                                  previousExercises: null,
                                  onTrainingComplete: () => mainTabState.refresh(),
                                ),
                              ),
                            );
                          } else {
                            if (!context.mounted) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TrainingPage(),
                              ),
                            );
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('跳转失败: $e')),
                          );
                        }
                      },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.grey.shade300),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black87,
                            Colors.black45,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasUnfinished)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: tagColor,
                                  ),
                                  child: Text(
                                    tagText,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (hasUnfinished) const SizedBox(height: 8),
                          Text(
                            titleText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitleText,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DietAnalysisBriefCard extends StatelessWidget {
  const _DietAnalysisBriefCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              '饮食分析简报',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '查看详情',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF25F46A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: const [
                    Expanded(
                      child: _MacroBar(
                        label: '蛋白质',
                        color: Colors.orange,
                        value: 0.45,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _MacroBar(
                        label: '碳水',
                        color: Colors.blue,
                        value: 0.7,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _MacroBar(
                        label: '脂肪',
                        color: Colors.amber,
                        value: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25F46A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.tips_and_updates_outlined,
                        color: Color(0xFF25F46A),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '今天的蛋白摄入量略低，建议在晚餐中增加 100g 鸡胸肉或一杯蛋白粉以达到目标。',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.color,
    required this.value,
  });

  final String label;
  final Color color;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(color: Colors.grey.shade200),
                FractionallySizedBox(
                  widthFactor: value,
                  child: Container(color: color),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}



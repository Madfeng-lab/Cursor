import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api_client.dart';
import 'auth_state.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  static const _userId = 1;

  StatsOverview? _overview;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final now = DateTime.now();
    final weekday = now.weekday;
    final monday = now.subtract(Duration(days: weekday - 1));
    final from = '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    final to = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      final apiClient = context.read<AuthState>().apiClient;
      final data = await apiClient.fetchStatsOverview(userId: _userId, from: from, to: to);
      if (!mounted) return;
      setState(() {
        _overview = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据统计'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SegmentedHeader(
              onToggle: (index) {
                // TODO: 切换「数据统计 / 个人记录」
              },
            ),
            const SizedBox(height: 16),
            if (_loading && _overview == null)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_error != null && _overview == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: const Text('重试')),
                    ],
                  ),
                ),
              )
            else ...[
              _WeightTrendCard(
                overview: _overview,
                onViewDetail: () {
                  // TODO: 查看体重详情
                },
              ),
              const SizedBox(height: 16),
              _TrainingBarCard(
                overview: _overview,
                onViewDetail: () {
                  // TODO: 查看训练频率详情
                },
              ),
              const SizedBox(height: 16),
              const Text(
                '个人最好成绩 (PR)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const _PrGrid(),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentedHeader extends StatelessWidget {
  const _SegmentedHeader({required this.onToggle});

  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.grey.shade100,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '数据统计',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                child: const Text(
                  '个人记录',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightTrendCard extends StatelessWidget {
  const _WeightTrendCard({this.overview, required this.onViewDetail});

  final StatsOverview? overview;
  final VoidCallback onViewDetail;

  @override
  Widget build(BuildContext context) {
    final weightByDate = overview?.weightByDate ?? {};
    final sortedDates = weightByDate.keys.toList()..sort();
    final latestWeight = sortedDates.isEmpty ? null : weightByDate[sortedDates.last];
    final subtitle = latestWeight != null
        ? '当前 ${latestWeight.toStringAsFixed(1)} kg${sortedDates.length > 1 ? '  ·  本周 ${sortedDates.length} 条记录' : ''}'
        : '暂无体重数据，可在「个人记录」中录入';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '体重趋势',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: onViewDetail,
                  child: const Text(
                    '本周',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade100,
              ),
              alignment: Alignment.center,
              child: sortedDates.isEmpty
                  ? const Text(
                      '体重折线图占位',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    )
                  : Text(
                      '本周 ${sortedDates.length} 条体重记录',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainingBarCard extends StatelessWidget {
  const _TrainingBarCard({this.overview, required this.onViewDetail});

  final StatsOverview? overview;
  final VoidCallback onViewDetail;

  @override
  Widget build(BuildContext context) {
    final count = overview?.totalWorkouts ?? 0;
    final volume = overview?.totalVolumeKg ?? 0;
    final calories = overview?.totalCalories ?? 0;
    final subtitle = '本周训练 $count 次  ·  总重量 ${volume.toStringAsFixed(0)} kg  ·  预估消耗 ${calories.toStringAsFixed(0)} 卡';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '每周训练次数',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: onViewDetail,
                  child: const Text(
                    '更多',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade100,
              ),
              alignment: Alignment.center,
              child: count > 0
                  ? Text(
                      '本周完成 $count 次训练',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    )
                  : const Text(
                      '本周暂无训练记录',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrGrid extends StatelessWidget {
  const _PrGrid();

  @override
  Widget build(BuildContext context) {
    final items = [
      _PrItemData('卧推', '80.0 kg'),
      _PrItemData('深蹲', '120.0 kg'),
      _PrItemData('硬拉', '140.0 kg'),
      _PrItemData('5km 跑', '24:15'),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: () {
            // TODO: 查看该动作历史 PR
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  item.value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PrItemData {
  _PrItemData(this.title, this.value);

  final String title;
  final String value;
}


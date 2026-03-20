import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_state.dart';
import 'main.dart';
import 'training_detail_page.dart';
import 'create_exercise_page.dart';
import 'exercise_data.dart' as ex;
import 'widgets/exercise_animation_player.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  final List<String> _muscleGroups = [
    '胸部',
    '背部',
    '腿部',
    '肩部',
    '手臂',
    '腹部',
    '全身',
  ];
  int _selectedGroupIndex = 0;

  final TextEditingController _searchController = TextEditingController();

  List<ex.Exercise> _allExercises = [];
  List<_ExerciseData> _currentExercises = [];
  /// 当前选中的动作 id 集合，支持多选
  Set<String> _selectedExerciseIds = {};
  /// 从训练详情页「新增训练动作」返回时带回来的已存在动作列表，用于追加到新详情页
  List<SessionExerciseItem>? _pendingSessionSoFar;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // 首次加载 JSON 动作库
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExercises();
    });
  }

  void _onSearchChanged() {
    _filterExercises();
  }

  Future<void> _loadExercises() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ex.loadExercisesFromJson();
      setState(() {
        _allExercises = list;
      });
      _filterExercises();
    } catch (e) {
      setState(() {
        _error = '加载动作库失败，请检查 assets/data/exercises.json';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// 从静态内存列表中过滤当前肌群和关键字
  void _filterExercises() {
    final groupName = _muscleGroups[_selectedGroupIndex];
    final keyword = _searchController.text.trim();

    final all = _allExercises
        .where((e) => e.muscleGroup == groupName)
        .toList();

    final filtered = keyword.isEmpty
        ? all
        : all
            .where((e) =>
                e.name.contains(keyword) ||
                e.details.contains(keyword))
            .toList();

    setState(() {
      _currentExercises = filtered
          .map(
            (e) => _ExerciseData(
              id: e.id,
              title: e.name,
              // 默认列表不显示详细描述，只在「查看要点」时弹出
              subtitle: '',
              details: e.details,
              imageAssetPath: e.imageAssetPath,
            ),
          )
          .toList();
      // 移除不在当前列表中的选中项
      _selectedExerciseIds.removeWhere(
        (id) => !_currentExercises.any((e) => e.id == id),
      );
    });
  }

  void _navigateToFirstExercise() {
    if (_selectedExerciseIds.isEmpty) return;

    final apiClient = context.read<AuthState>().apiClient;
    const userId = 1;

    // 获取选中的动作按顺序排列
    final selectedIds = _selectedExerciseIds.toList();
    final exercises = _currentExercises
        .where((e) => selectedIds.contains(e.id))
        .toList();

    if (exercises.isEmpty) return;

    // 第一个动作作为当前编辑动作
    final firstExercise = exercises.first;
    final firstExerciseName = firstExercise.title;
    final firstExerciseImageAssetPath = firstExercise.imageAssetPath;

    // 其他动作作为已完成动作
    final otherExercises = exercises.sublist(1).map((e) {
      return SessionExerciseItem(
        exerciseName: e.title,
        sets: [],
        difficulty: null,
      );
    }).toList();

    // 将之前已有的动作加上去
    final List<SessionExerciseItem> allPrevious = [
      ...?_pendingSessionSoFar,
      ...otherExercises,
    ];

    // 使用 Provider 获取 MainTabState 来切换回首页
    final mainTabState = context.read<MainTabState>();
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => TrainingDetailPage(
              apiClient: apiClient,
              userId: userId,
              exerciseName: firstExerciseName,
              imageAssetPath: firstExerciseImageAssetPath,
              previousExercises: allPrevious.isEmpty ? null : allPrevious,
              onTrainingComplete: () => mainTabState.setIndex(0),
            ),
          ),
        )
        .then((result) {
          if (result != null && result is List<SessionExerciseItem>) {
            setState(() {
              _pendingSessionSoFar = result;
              // 返回时清除已选中的动作，以便下次选择时默认无勾选
              _selectedExerciseIds.clear();
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSearchBar(),
            Expanded(
              child: Row(
                children: [
                  _buildSidebar(),
                  Expanded(child: _buildExerciseList()),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedExerciseIds.isEmpty ? null : () {
          _navigateToFirstExercise();
        },
        label: Text('确认选择 (${_selectedExerciseIds.length})'),
        icon: const Icon(Icons.arrow_forward),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.arrow_back),
          ),
          const Text(
            '动作库',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF25F46A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: IconButton(
              onPressed: () async {
                // 跳转到新增自定义动作页，返回表单数据
                final result = await Navigator.of(context).push<Map<String, dynamic>>(
                  MaterialPageRoute(builder: (_) => const CreateExercisePage()),
                );
                if (!mounted || result == null) return;

                try {
                  // 追加到静态内存列表（使用占位图片）
                  final newId = 'custom_${_allExercises.length + 1}';
                  _allExercises.add(
                    ex.Exercise(
                      id: newId,
                      name: result['name'] as String,
                      muscleGroup: result['primaryMuscle'] as String,
                      difficulty: '入门',
                      details: (result['description'] as String?) ?? '',
                      imageAssetPath: '',
                    ),
                  );
                  // 如果新建的动作属于当前选中部位，则刷新过滤
                  if (result['primaryMuscle'] ==
                      _muscleGroups[_selectedGroupIndex]) {
                    _filterExercises();
                  }
                } catch (e) {
                  if (!mounted) return;
                  debugPrint('保存动作失败: $e');
                }
              },
              icon: const Icon(Icons.add, color: Color(0xFF25F46A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: '搜索动作、部位、器械',
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
      ),
      child: ListView.builder(
        itemCount: _muscleGroups.length,
        itemBuilder: (context, index) {
          final selected = index == _selectedGroupIndex;
          return InkWell(
            onTap: () {
              setState(() => _selectedGroupIndex = index);
              _filterExercises();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                border: selected
                    ? Border(
                        right: BorderSide(
                          color: const Color(0xFF25F46A),
                          width: 3,
                        ),
                      )
                    : null,
              ),
              child: Center(
                child: Text(
                  _muscleGroups[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color:
                        selected ? const Color(0xFF25F46A) : Colors.grey[600],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExerciseList() {
    final groupName = _muscleGroups[_selectedGroupIndex];

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    if (_currentExercises.isEmpty) {
      return Center(
        child: Text('$groupName 暂无动作'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _currentExercises.length + 1, // +1 用于顶部标题
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '$groupName训练动作 (${_currentExercises.length})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          );
        }

        final ex = _currentExercises[index - 1];
        final selected = _selectedExerciseIds.contains(ex.id);

        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: InkWell(
            onTap: () {
              setState(() {
                if (_selectedExerciseIds.contains(ex.id)) {
                  _selectedExerciseIds.remove(ex.id);
                } else {
                  _selectedExerciseIds.add(ex.id);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: selected
                ? _SelectedExerciseCard(
                    title: ex.title,
                    subtitle: ex.subtitle,
                    details: ex.details,
                    imageAssetPath: ex.imageAssetPath,
                  )
                : _ExerciseCard(
                    title: ex.title,
                    subtitle: ex.subtitle,
                    details: ex.details,
                    imageAssetPath: ex.imageAssetPath,
                  ),
          ),
        );
      },
    );
  }
}

class _ExerciseData {
  final String id;
  final String title;
  final String subtitle;
  final String details;
  final String imageAssetPath;

  const _ExerciseData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.imageAssetPath,
  });
}

class _SelectedExerciseCard extends StatelessWidget {
  const _SelectedExerciseCard({
    required this.title,
    required this.subtitle,
    required this.details,
    required this.imageAssetPath,
  });

  final String title;
  final String subtitle;
  final String details;
  final String imageAssetPath;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _ExerciseCard(
          title: title,
          subtitle: subtitle,
          details: details,
          imageAssetPath: imageAssetPath,
          selected: true,
        ),
        Positioned(
          top: -6,
          right: -6,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF25F46A),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(Icons.check, size: 16, color: Colors.black),
          ),
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.title,
    required this.subtitle,
    required this.details,
    required this.imageAssetPath,
    this.selected = false,
  });

  final String title;
  final String subtitle;
  final String details;
  final String imageAssetPath;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFF25F46A)
        : Colors.grey.shade200;
    final borderWidth = selected ? 2.0 : 1.0;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade100,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ExerciseAnimationPlayer(
                assetPath: imageAssetPath,
                animationName: '',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder: (ctx) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                details,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '查看要点',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? const Color(0xFF25F46A)
                              : Colors.grey,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color:
                            selected ? const Color(0xFF25F46A) : Colors.grey,
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
  }
}



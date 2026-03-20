import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'widgets/exercise_animation_player.dart';

/// 本场训练中已完成的动作条目（用于追加展示）
class SessionExerciseItem {
  final String exerciseName;
  final List<WorkoutSet> sets;
  Difficulty? difficulty;

  SessionExerciseItem({
    required this.exerciseName,
    required this.sets,
    this.difficulty,
  });
}

class TrainingDetailPage extends StatefulWidget {
  const TrainingDetailPage({
    super.key,
    required this.apiClient,
    required this.userId,
    this.exerciseName,
    this.workoutTitle,
    this.imageAssetPath,
    this.previousExercises,
    this.onTrainingComplete,
  });

  final ApiClient apiClient;
  final int userId;
  /// 从动作库选中的动作名称，未传则显示默认「杠铃卧推」
  final String? exerciseName;
  /// 本次训练标题（例如“胸+三头”），用于展示在页面顶部并在退出/恢复时写入会话。
  final String? workoutTitle;
  /// 动作图片基准路径（通常以 `.../0.jpg` 结尾），用于在详情页展示两帧动图。
  final String? imageAssetPath;
  /// 本场训练中已存在的动作（在上面展示，当前动作为本次追加）
  final List<SessionExerciseItem>? previousExercises;
  /// 完成训练并保存成功后调用（由调用方切回首页等）
  final VoidCallback? onTrainingComplete;

  @override
  State<TrainingDetailPage> createState() => _TrainingDetailPageState();
}

const Color _bgDark = Color(0xFF101828);
const Color _primary = Color(0xFF25F46A);

class _TrainingDetailPageState extends State<TrainingDetailPage> {
  int? _sessionId;
  DateTime? _sessionStartedAt;
  late final TextEditingController _titleController;
  bool _starting = false;
  bool _finishing = false;
  String? _error;

  int _elapsedSeconds = 0;
  Timer? _timer;

  // 组数据
  List<WorkoutSet> _sets = [
    WorkoutSet(weight: 80, reps: 10, completed: true),
    WorkoutSet(weight: 80, reps: 12, completed: false),
    WorkoutSet(weight: 85, reps: 8, completed: false),
  ];
  int _currentIndex = 1; // 第二组为当前编辑

  // 难度反馈：当前正在训练的动作难度
  Difficulty _currentDifficulty = Difficulty.normal;

  // 已完成动作的难度反馈：key 为动作索引，value 为难度
  Map<int, Difficulty> _exerciseDifficulty = {};

  // 休息时间
  int _restSeconds = 90;

  // 已完成动作的折叠状态：key 为动作索引，value 为是否折叠
  Map<int, bool> _exerciseCollapsed = {};

  // 当前训练动作是否折叠
  bool _currentExerciseCollapsed = false;

  // 本场训练中已完成的动作列表（可变）
  late List<SessionExerciseItem> _previousExercises;  

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.workoutTitle ??
          widget.exerciseName ??
          '今日训练',
    );
    // 复制一份列表用于本页面内部修改（如删除动作）
    _previousExercises = widget.previousExercises != null
        ? List<SessionExerciseItem>.from(widget.previousExercises!)
        : [];

    _startSession();
  }

  void _initializeCollapsedStates() {
    _exerciseCollapsed.clear();
    _exerciseDifficulty.clear();

    for (int i = 0; i < _previousExercises.length; i++) {
      final item = _previousExercises[i];
      final allCompleted = item.sets.every((set) => set.completed);
      // 所有组都完成的动作自动折叠
      _exerciseCollapsed[i] = allCompleted;
      // 读取该动作的难度反馈
      _exerciseDifficulty[i] = item.difficulty ?? Difficulty.normal;
    }

    // 检查当前动作是否所有组都完成
    final currentAllCompleted = _sets.every((set) => set.completed);
    _currentExerciseCollapsed = currentAllCompleted;
    _currentIndex = 0;
    for (int i = 0; i < _sets.length; i++) {
      if (!_sets[i].completed) {
        _currentIndex = i;
        break;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (_sessionStartedAt == null) return;

    // 用 startedAt 计算，确保退出后再次进入能从后端继续计时。
    _elapsedSeconds = DateTime.now().difference(_sessionStartedAt!).inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final startedAt = _sessionStartedAt;
      if (startedAt == null) return;
      final diffSeconds = DateTime.now().difference(startedAt).inSeconds;
      setState(() => _elapsedSeconds = diffSeconds);
    });
  }

  Future<void> _startSession() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final unfinished =
          await widget.apiClient.fetchUnfinishedWorkoutSession(userId: widget.userId);
      if (unfinished != null) {
        _sessionId = unfinished.id;
        _sessionStartedAt = unfinished.startedAt;

        // 恢复会话标题（优先使用会话本身，确保退出/恢复一致）
        _titleController.text =
            unfinished.title.isNotEmpty ? unfinished.title : _titleController.text;

        final shouldRestoreExerciseData =
            widget.previousExercises == null ||
            (widget.exerciseName != null &&
                widget.exerciseName == unfinished.title);

        if (shouldRestoreExerciseData && unfinished.exercises.isNotEmpty) {
          final allExercises = unfinished.exercises;
          final prevExercises = allExercises.sublist(
            0,
            allExercises.length - 1,
          );
          final currentExercise = allExercises.last;

          _previousExercises = prevExercises
              .map((ex) => SessionExerciseItem(
                    exerciseName: ex.name,
                    sets: (ex.sets.toList()
                      ..sort((a, b) => a.setIndex.compareTo(b.setIndex)))
                        .map((s) => WorkoutSet(
                              weight: s.weightKg.round(),
                              reps: s.reps,
                              completed: s.completed,
                            ))
                        .toList(),
                    difficulty: null,
                  ))
              .toList();

          // 当前动作的组
          _sets = (currentExercise.sets.toList()
            ..sort((a, b) => a.setIndex.compareTo(b.setIndex)))
              .map((s) => WorkoutSet(
                    weight: s.weightKg.round(),
                    reps: s.reps,
                    completed: s.completed,
                  ))
              .toList();

          // 优先恢复 restSeconds（如未存过则保留页面默认值）
          int? firstRest;
          for (final s in currentExercise.sets) {
            if (s.restSeconds != null) {
              firstRest = s.restSeconds;
              break;
            }
          }
          if (firstRest != null) _restSeconds = firstRest;
        }

        _initializeCollapsedStates();
        _startTimer();
      } else {
        final res = await widget.apiClient.startWorkoutSession(
          userId: widget.userId,
          title: _titleController.text.trim().isNotEmpty
              ? _titleController.text.trim()
              : '今日训练',
        );
        _sessionId = res['id'] as int?;
        final startedAtRaw = res['startedAt'] as String?;
        _sessionStartedAt = startedAtRaw != null
            ? DateTime.parse(startedAtRaw)
            : DateTime.now();
        _initializeCollapsedStates();
        _startTimer();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _starting = false);
    }
  }

  Future<void> _saveProgressIfNeeded() async {
    if (_sessionId == null) return;

    final allItems = <SessionExerciseItem>[
      ..._previousExercises,
      SessionExerciseItem(
        exerciseName: widget.exerciseName ?? '杠铃卧推',
        sets: _sets,
        difficulty: _currentDifficulty,
      ),
    ];

    final exercises = List<Map<String, dynamic>>.generate(allItems.length, (i) {
      final item = allItems[i];
      return {
        'name': item.exerciseName,
        'primaryMuscleGroup': null,
        'sets': List.generate(item.sets.length, (j) {
          final s = item.sets[j];
          return {
            'setIndex': j,
            'weightKg': s.weight.toDouble(),
            'reps': s.reps,
            'completed': s.completed,
            'restSeconds': _restSeconds,
          };
        }),
      };
    });

    await widget.apiClient.saveWorkoutSessionProgress(
      sessionId: _sessionId!,
      title: _titleController.text.trim(),
      exercises: exercises,
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatRest(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _finishSession() async {
    if (_sessionId == null) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _finishing = true;
      _error = null;
    });

    try {
      // 汇总本场训练：已完成动作 + 当前动作
      final allItems = <SessionExerciseItem>[
        ..._previousExercises,
        SessionExerciseItem(
          exerciseName: widget.exerciseName ?? '杠铃卧推',
          sets: _sets,
          difficulty: _currentDifficulty,
        ),
      ];

      double totalVolume = 0;
      for (final item in allItems) {
        for (final s in item.sets) {
          totalVolume += s.weight * s.reps;
        }
      }
      final estCalories = totalVolume / 1000 * 50;

      await widget.apiClient.finishWorkoutSession(
        sessionId: _sessionId!,
        completed: true,
        title: _titleController.text.trim(),
        totalVolumeKg: totalVolume,
        estimatedCalories: estCalories,
        exercises: List.generate(allItems.length, (i) {
          final item = allItems[i];
          return {
            'name': item.exerciseName,
            'primaryMuscleGroup': null,
            'sets': List.generate(item.sets.length, (j) {
              final s = item.sets[j];
              return {
                'setIndex': j,
                'weightKg': s.weight.toDouble(),
                'reps': s.reps,
                'completed': s.completed,
                'restSeconds': _restSeconds,
              };
            }),
          };
        }),
      );
      if (!mounted) return;
      // 先关闭详情页，再在下一帧切回首页，确保用户先看到页面关闭
      final onComplete = widget.onTrainingComplete;
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (onComplete != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onComplete());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _finishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 点击返回/关闭时：如果不是“完成训练”流程，则保存当前组数据并保持会话未完成。
        if (_finishing) return true;
        try {
          await _saveProgressIfNeeded();
        } catch (_) {
          // 保存失败也允许退出，避免阻塞用户操作。
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: _bgDark,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWorkoutTitleInput(),
                const SizedBox(height: 12),
                _buildHeader(context),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_previousExercises.isNotEmpty) ...[
                          _buildPreviousExercises(),
                          const SizedBox(height: 16),
                        ],
                        _buildCurrentExercise(),
                        const SizedBox(height: 20),
                        _buildDifficultyFeedback(),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ],
                        // 底部留白，避免最后一组被遮挡或难以点击
                        SizedBox(
                            height:
                                MediaQuery.of(context).padding.bottom + 80),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 上一个动作完成后可点此按钮返回动作库选下一个动作
                Center(
                  child: TextButton.icon(
                    onPressed: (_starting || _finishing)
                        ? null
                        : () {
                            final name = widget.exerciseName ?? '杠铃卧推';
                            final currentCopy = _sets
                                .map((s) => WorkoutSet(
                                      weight: s.weight,
                                      reps: s.reps,
                                      completed: s.completed,
                                    ))
                                .toList();
                            final sessionSoFar = [
                              ..._previousExercises,
                              SessionExerciseItem(
                                exerciseName: name,
                                sets: currentCopy,
                                difficulty: _currentDifficulty,
                              ),
                            ];
                            Navigator.of(context).pop(sessionSoFar);
                          },
                    icon: Icon(
                      Icons.add_circle_outline,
                      size: 20,
                      color: (_starting || _finishing) ? Colors.grey : _primary,
                    ),
                    label: Text(
                      '新增训练动作',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: (_starting || _finishing) ? Colors.grey : _primary,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: _primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutTitleInput() {
    return TextField(
      controller: _titleController,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      maxLines: 1,
      decoration: InputDecoration(
        hintText: '例如：胸+三头',
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFF0B1220),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primary.withOpacity(0.35), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primary.withOpacity(0.35), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primary, width: 1.6),
        ),
      ),
      onChanged: (_) {
        // 保持轻量；保存进度/结束训练时统一写入后端。
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _circleIconButton(
          icon: Icons.close,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '总时长',
              style:
                  TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(_elapsedSeconds),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        _circleIconButton(
          icon: Icons.history,
          iconColor: _primary,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _circleIconButton({
    required IconData icon,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? Colors.white, size: 22),
      ),
    );
  }

  Widget _buildCurrentExercise() {
    return Container(
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _primary.withOpacity(0.4), width: 1),
      ),
      child: Column(
        children: [
          // 当前动作标题栏
          InkWell(
            onTap: () {
              setState(() {
                _currentExerciseCollapsed = !_currentExerciseCollapsed;
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.play_arrow,
                        size: 16,
                        color: Color(0xFF25F46A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.exerciseName ?? '杠铃卧推',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '正在训练',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${_sets.where((s) => s.completed).length}/${_sets.length} 组',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _currentExerciseCollapsed ? Icons.expand_more : Icons.expand_less,
                        size: 20,
                        color: Color(0xFF9CA3AF),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 展开时显示详细内容
          if (!_currentExerciseCollapsed) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildExerciseTitleAndVideo(),
                  const SizedBox(height: 16),
                  _buildSetList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviousExercises() {
    final list = _previousExercises;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '已完成动作 (${list.length})',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...List.generate(list.length, (i) {
          final item = list[i];
          final setSummary = item.sets
              .map((s) => '${s.weight}kg×${s.reps}')
              .join(' / ');
          final completedCount =
              item.sets.where((s) => s.completed).length;
          final isCollapsed = _exerciseCollapsed[i] ?? false;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _primary.withOpacity(0.4), width: 1),
              ),
              child: Column(
                children: [
                  // 动作标题栏
                  InkWell(
                    onTap: () {
                      setState(() {
                        _exerciseCollapsed[i] = !isCollapsed;
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.exerciseName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                if (!isCollapsed && setSummary.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    setSummary,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '$completedCount/${item.sets.length} 组',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isCollapsed ? Icons.expand_more : Icons.expand_less,
                                size: 20,
                                color: Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  _showDeleteExerciseDialog(i);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 展开时显示详细组信息和难度反馈
                  if (!isCollapsed) ...[
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2933),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 显示组信息
                          ...List.generate(item.sets.length, (setIndex) {
                            final set = item.sets[setIndex];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111827),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _primary.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 32,
                                          child: Text(
                                            '${setIndex + 1}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        // 重量编辑框
                                        SizedBox(
                                          width: 70,
                                          child: TextField(
                                            controller: TextEditingController(text: set.weight.toString()),
                                            textAlign: TextAlign.center,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            onChanged: (value) {
                                              setState(() {
                                                set.weight = int.tryParse(value) ?? set.weight;
                                              });
                                            },
                                            decoration: InputDecoration(
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              filled: true,
                                              fillColor: const Color(0xFF020617),
                                              hintText: '0',
                                              hintStyle: const TextStyle(color: Color(0xFF4B5563)),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(color: _primary.withOpacity(0.4)),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        // 次数编辑框
                                        SizedBox(
                                          width: 48,
                                          child: TextField(
                                            controller: TextEditingController(text: set.reps.toString()),
                                            textAlign: TextAlign.center,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            onChanged: (value) {
                                              setState(() {
                                                set.reps = int.tryParse(value) ?? set.reps;
                                              });
                                            },
                                            decoration: InputDecoration(
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                              filled: true,
                                              fillColor: const Color(0xFF020617),
                                              hintText: '0',
                                              hintStyle: const TextStyle(color: Color(0xFF4B5563)),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(color: _primary.withOpacity(0.4)),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        // 勾选框 - 可点击切换状态
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              set.completed = !set.completed;
                                            });
                                          },
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(6),
                                              color: set.completed ? _primary : const Color(0xFF4B5563),
                                              border: set.completed ? null : Border.all(
                                                color: _primary.withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: set.completed
                                                ? const Icon(Icons.check, size: 14, color: Colors.black)
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // 删除按钮
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              item.sets.removeAt(setIndex);
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.clear,
                                              size: 14,
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          // 新增一组按钮
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  if (item.sets.isNotEmpty) {
                                    final last = item.sets.last;
                                    item.sets.add(
                                      WorkoutSet(
                                        weight: last.weight,
                                        reps: last.reps,
                                        completed: false,
                                      ),
                                    );
                                  } else {
                                    item.sets.add(
                                      WorkoutSet(
                                        weight: 0,
                                        reps: 0,
                                        completed: false,
                                      ),
                                    );
                                  }
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: _primary.withOpacity(0.5),
                                  width: 1,
                                ),
                                foregroundColor: _primary.withOpacity(0.7),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                '新增一组',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          // 显示难度反馈
                          const SizedBox(height: 12),
                          const Divider(color: Color(0xFF4B5563), height: 1),
                          const SizedBox(height: 12),
                          _buildExerciseDifficultyFeedback(i),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildExerciseTitleAndVideo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.exerciseName ?? '杠铃卧推',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.info_outline, size: 16, color: _primary),
              label: const Text(
                '详情',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black),
                Positioned.fill(
                  child: ExerciseAnimationPlayer(
                    assetPath: widget.imageAssetPath ?? '',
                    animationName: '',
                  ),
                ),
                Container(color: Colors.black.withOpacity(0.25)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSetList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 表头
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '组项',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  SizedBox(width: 24),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '重量 (KG)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                  SizedBox(width: 24),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '次数',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ],
              ),
              const Icon(Icons.done_all, size: 18, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // 动态组列表
        ...List.generate(_sets.length, (index) {
          final set = _sets[index];
          final setNo = index + 1;
          final isCurrent = index == _currentIndex;
          final isNext = index > _currentIndex && !set.completed;

          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _SetRow(
              setNumber: setNo,
              set: set,
              isCurrent: isCurrent,
              isNext: isNext,
              onComplete: () {
                setState(() {
                  set.completed = true;
                  final next =
                      _sets.indexWhere((s) => !s.completed);
                  if (next != -1) _currentIndex = next;

                  // 检查是否所有组都完成了，如果是则自动折叠
                  final allCompleted = _sets.every((s) => s.completed);
                  if (allCompleted) {
                    _currentExerciseCollapsed = true;
                  }
                });
              },
              onChangedWeight: (value) {
                final w = int.tryParse(value) ?? set.weight;
                setState(() => set.weight = w);
              },
              onChangedReps: (value) {
                final r = int.tryParse(value) ?? set.reps;
                setState(() => set.reps = r);
              },
              onDelete: () {
                _showDeleteSetDialog(index);
              },
            ),
          );
        }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              final last = _sets.last;
              _sets.add(
                WorkoutSet(
                  weight: last.weight,
                  reps: last.reps,
                  completed: false,
                ),
              );
              // 让新增的这一组成为当前可操作组，否则最后一组会显示为灰色无法勾选完成
              _currentIndex = _sets.length - 1;
              // 添加新组时展开当前动作
              _currentExerciseCollapsed = false;
            });
          },
          style: OutlinedButton.styleFrom(
            side: const BorderSide(
              color: _primary,
              width: 1.5,
            ),
            foregroundColor: _primary,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text(
            '新增一组',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultyFeedback() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            '本动作难度反馈',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DifficultyChip(
                label: '简单',
                icon: Icons.sentiment_satisfied_alt,
                color: Colors.blue,
                selected: _currentDifficulty == Difficulty.easy,
                onTap: () =>
                    setState(() => _currentDifficulty = Difficulty.easy),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DifficultyChip(
                label: '正常',
                icon: Icons.sentiment_neutral,
                color: _primary,
                selected: _currentDifficulty == Difficulty.normal,
                onTap: () =>
                    setState(() => _currentDifficulty = Difficulty.normal),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DifficultyChip(
                label: '困难',
                icon: Icons.sentiment_very_dissatisfied,
                color: Colors.red,
                selected: _currentDifficulty == Difficulty.hard,
                onTap: () =>
                    setState(() => _currentDifficulty = Difficulty.hard),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExerciseDifficultyFeedback(int exerciseIndex) {
    final currentDiff = _exerciseDifficulty[exerciseIndex] ?? Difficulty.normal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '难度反馈',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DifficultyChip(
                label: '简单',
                icon: Icons.sentiment_satisfied_alt,
                color: Colors.blue,
                selected: currentDiff == Difficulty.easy,
                onTap: () {
                  setState(() {
                    _exerciseDifficulty[exerciseIndex] = Difficulty.easy;
                    _previousExercises[exerciseIndex].difficulty = Difficulty.easy;
                  });
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _DifficultyChip(
                label: '正常',
                icon: Icons.sentiment_neutral,
                color: _primary,
                selected: currentDiff == Difficulty.normal,
                onTap: () {
                  setState(() {
                    _exerciseDifficulty[exerciseIndex] = Difficulty.normal;
                    _previousExercises[exerciseIndex].difficulty = Difficulty.normal;
                  });
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _DifficultyChip(
                label: '困难',
                icon: Icons.sentiment_very_dissatisfied,
                color: Colors.red,
                selected: currentDiff == Difficulty.hard,
                onTap: () {
                  setState(() {
                    _exerciseDifficulty[exerciseIndex] = Difficulty.hard;
                    _previousExercises[exerciseIndex].difficulty = Difficulty.hard;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Row(
      children: [
        // Resting 卡片
        Flexible(
          flex: 6,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2933),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _primary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'RESTING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _primary,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatRest(_restSeconds),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _squareIconButton(
                      Icons.remove,
                      onTap: () {
                        setState(() {
                          _restSeconds =
                              (_restSeconds - 10).clamp(0, 600);
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    _squareIconButton(
                      Icons.add,
                      onTap: () {
                        setState(() {
                          _restSeconds =
                              (_restSeconds + 10).clamp(0, 600);
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 完成训练按钮
        Flexible(
          flex: 7,
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: (_starting || _finishing) ? null : _finishSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 8,
                shadowColor: _primary.withOpacity(0.3),
              ),
              child: _finishing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          '完成训练',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 20),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _squareIconButton(IconData icon, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }

  void _showDeleteExerciseDialog(int exerciseIndex) {
    final exercise = _previousExercises[exerciseIndex];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2933),
        title: const Text(
          '删除动作',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '确定要删除 "${exercise.exerciseName}" 吗？\n这将删除该动作的所有组数据。',
          style: const TextStyle(color: Color(0xFF9CA3AF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '取消',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                // 从本地可变列表中移除该动作
                _previousExercises.removeAt(exerciseIndex);
                
                // 重新调整折叠状态映射
                final newCollapsedState = <int, bool>{};
                for (int i = 0; i < _previousExercises.length; i++) {
                  if (i < exerciseIndex) {
                    newCollapsedState[i] = _exerciseCollapsed[i] ?? false;
                  } else {
                    newCollapsedState[i] = _exerciseCollapsed[i + 1] ?? false;
                  }
                }
                _exerciseCollapsed
                  ..clear()
                  ..addAll(newCollapsedState);
              });
              Navigator.of(context).pop();
            },
            child: const Text(
              '删除',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteSetDialog(int setIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2933),
        title: const Text(
          '删除组',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '确定要删除第 ${setIndex + 1} 组吗？',
          style: const TextStyle(color: Color(0xFF9CA3AF)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              '取消',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _sets.removeAt(setIndex);
                
                // 调整当前索引
                if (_currentIndex >= setIndex && _currentIndex > 0) {
                  _currentIndex--;
                }
                
                // 如果删除的是当前正在编辑的组，调整为前一个
                if (_currentIndex >= _sets.length) {
                  _currentIndex = _sets.length - 1;
                }
                
                // 检查是否需要展开当前动作
                if (_sets.isNotEmpty) {
                  _currentExerciseCollapsed = false;
                }
              });
              Navigator.of(context).pop();
            },
            child: const Text(
              '删除',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

// 组数据模型
class WorkoutSet {
  int weight;
  int reps;
  bool completed;

  WorkoutSet({
    required this.weight,
    required this.reps,
    this.completed = false,
  });
}

enum Difficulty { easy, normal, hard }

// 单行 Set UI
class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.setNumber,
    required this.set,
    required this.isCurrent,
    required this.isNext,
    required this.onComplete,
    required this.onChangedWeight,
    required this.onChangedReps,
    required this.onDelete,
  });

  final int setNumber;
  final WorkoutSet set;
  final bool isCurrent;
  final bool isNext;
  final VoidCallback onComplete;
  final ValueChanged<String> onChangedWeight;
  final ValueChanged<String> onChangedReps;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color bgColor;
    if (isCurrent) {
      borderColor = _primary;
      bgColor = _primary.withOpacity(0.08);
    } else if (isNext) {
      borderColor = const Color(0xFF4B5563);
      bgColor = const Color(0xFF111827);
    } else {
      borderColor = _primary.withOpacity(0.4);
      bgColor = const Color(0xFF111827);
    }

    final leadingColor =
        isCurrent ? _primary : const Color(0xFF9CA3AF);

    final rowContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isCurrent ? 2 : 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '$setNumber',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: leadingColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              _buildCell(
                value: set.weight.toString(),
                editable: isCurrent,
                onChanged: onChangedWeight,
              ),
              const SizedBox(width: 24),
              _buildCell(
                value: set.reps.toString(),
                editable: isCurrent,
                onChanged: onChangedReps,
              ),
            ],
          ),
          Row(
            children: [
              _buildStatusIcon(),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // 未完成的组：整行可点击完成，避免勾选区域被挡或点不到
    if (!set.completed) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onComplete,
          borderRadius: BorderRadius.circular(14),
          child: rowContent,
        ),
      );
    }
    return rowContent;
  }

  Widget _buildCell({
    required String value,
    required bool editable,
    required ValueChanged<String> onChanged,
  }) {
    if (editable) {
      return SizedBox(
        width: 70,
        child: TextField(
          controller: TextEditingController(text: value),
          textAlign: TextAlign.center,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            filled: true,
            fillColor: const Color(0xFF020617),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: _primary.withOpacity(0.4)),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 70,
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    const minTapSize = 44.0; // 最小点击区域，避免误触或点不到
    if (!set.completed) {
      // 所有未完成的组都显示可点击的勾选框
      Color borderColor;
      Color iconColor;
      if (isCurrent) {
        borderColor = _primary;
        iconColor = _primary;
      } else if (isNext) {
        borderColor = const Color(0xFF4B5563);
        iconColor = const Color(0xFF4B5563);
      } else {
        // 其他未完成的组也显示可点击样式，但颜色更淡
        borderColor = _primary.withOpacity(0.6);
        iconColor = _primary.withOpacity(0.6);
      }

      return SizedBox(
        width: minTapSize,
        height: minTapSize,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Icon(Icons.check, color: iconColor, size: 18),
          ),
        ),
      );
    }

    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _primary,
          ),
          child: const Icon(Icons.check, color: Colors.black, size: 18),
        ),
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _bgDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : const Color(0xFF4B5563),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: selected ? color : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
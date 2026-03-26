import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';

class TrainingSessionPage extends StatefulWidget {
  const TrainingSessionPage({
    super.key,
    required this.apiClient,
    required this.userId,
  });

  final ApiClient apiClient;
  final int userId;

  @override
  State<TrainingSessionPage> createState() => _TrainingSessionPageState();
}

class _TrainingSessionPageState extends State<TrainingSessionPage> {
  int? _sessionId;
  bool _starting = false;
  bool _finishing = false;
  String? _error;

  int _elapsedSeconds = 0;
  Timer? _timer;

  final _titleController = TextEditingController(text: '今日训练');
  final _volumeController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _startTimer();
    _startSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _titleController.dispose();
    _volumeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  Future<void> _startSession() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final result = await widget.apiClient.startWorkoutSession(
        userId: widget.userId,
        title: _titleController.text,
      );
      setState(() {
        _sessionId = result['id'] as int?;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _starting = false;
      });
    }
  }

  Future<void> _finishSession() async {
    if (_sessionId == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _finishing = true;
      _error = null;
    });
    try {
      final volume = double.tryParse(_volumeController.text) ?? 0;
      // 简单估算：每 1000kg 训练量约消耗 50 kcal，可后续优化。
      final estCalories = volume / 1000 * 50;
      await widget.apiClient.finishWorkoutSession(
        sessionId: _sessionId!,
        completed: true,
        title: _titleController.text.trim(),
        elapsedSeconds: _elapsedSeconds,
        totalVolumeKg: volume,
        estimatedCalories: estCalories,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _finishing = false;
      });
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int _restSeconds = 90;

  String _formatRest(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildExerciseTitleAndMedia(),
                  _buildSetList(),
                  _buildDifficultyFeedback(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomControls(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
        border: Border(
          bottom: BorderSide(
            color: Colors.green.withOpacity(0.15),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
          Column(
            children: [
              const Text(
                '总时长',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                _formatTime(_elapsedSeconds),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              // TODO: 查看历史记录
            },
            icon: const Icon(Icons.history),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseTitleAndMedia() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '杠铃卧推',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  // TODO: 显示动作详情
                },
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text(
                  '详情',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.grey.shade300),
                  Container(
                    color: Colors.black.withOpacity(0.25),
                  ),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        // TODO: 播放教学视频
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFF25F46A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          size: 36,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '重量 (KG)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '次数',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.done_all, color: Colors.grey, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 第一组：已完成示例
          _SetRow.completed(setNumber: 1, weight: 80, reps: 10),
          const SizedBox(height: 8),
          // 第二组：正在进行（可编辑）
          _SetRow.current(
            weightController: TextEditingController(text: '85'),
            repsController: TextEditingController(text: '8'),
            setNumber: 2,
            onComplete: () {
              // TODO: 标记当前组完成
            },
          ),
          const SizedBox(height: 8),
          // 第三组：下一组
          _SetRow.next(setNumber: 3, weight: 85, reps: 8),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: 新增一组
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('新增一组'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyFeedback() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '本动作难度反馈',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
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
                  selected: false,
                  onTap: () {
                    // TODO: 记录反馈
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DifficultyChip(
                  label: '正常',
                  icon: Icons.sentiment_neutral,
                  color: const Color(0xFF25F46A),
                  selected: true,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DifficultyChip(
                  label: '困难',
                  icon: Icons.sentiment_very_dissatisfied,
                  color: Colors.red,
                  selected: false,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF25F46A).withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resting',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF25F46A),
                        ),
                      ),
                      Text(
                        _formatRest(_restSeconds),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _restSeconds =
                                (_restSeconds - 10).clamp(0, 600);
                          });
                        },
                        icon: const Icon(Icons.remove),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _restSeconds =
                                (_restSeconds + 10).clamp(0, 600);
                          });
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: FilledButton(
              onPressed: (_starting || _finishing) ? null : _finishSession,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25F46A),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: _finishing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
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
                        Icon(Icons.chevron_right),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow.completed({
    required this.setNumber,
    required this.weight,
    required this.reps,
  })  : isCurrent = false,
        weightController = null,
        repsController = null,
        onComplete = null,
        isNext = false;

  const _SetRow.current({
    required this.setNumber,
    required this.weightController,
    required this.repsController,
    required this.onComplete,
  })  : isCurrent = true,
        weight = null,
        reps = null,
        isNext = false;

  const _SetRow.next({
    required this.setNumber,
    required this.weight,
    required this.reps,
  })  : isCurrent = false,
        weightController = null,
        repsController = null,
        onComplete = null,
        isNext = true;

  final int setNumber;
  final int? weight;
  final int? reps;
  final bool isCurrent;
  final bool isNext;
  final TextEditingController? weightController;
  final TextEditingController? repsController;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF25F46A);
    Color borderColor;
    Color bgColor;
    if (isCurrent) {
      borderColor = primary;
      bgColor = primary.withOpacity(0.08);
    } else if (isNext) {
      borderColor = Colors.grey.shade300;
      bgColor = Colors.white;
    } else {
      borderColor = primary.withOpacity(0.3);
      bgColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: bgColor,
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
                    fontWeight: FontWeight.bold,
                    color: isCurrent ? primary : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 70,
                child: _buildCell(
                  context,
                  isCurrent: isCurrent,
                  controller: weightController,
                  value: weight?.toString() ?? '',
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 48,
                child: _buildCell(
                  context,
                  isCurrent: isCurrent,
                  controller: repsController,
                  value: reps?.toString() ?? '',
                ),
              ),
            ],
          ),
          _buildStatusIcon(primary),
        ],
      ),
    );
  }

  Widget _buildCell(
    BuildContext context, {
    required bool isCurrent,
    TextEditingController? controller,
    required String value,
  }) {
    if (isCurrent && controller != null) {
      return TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        style: const TextStyle(fontWeight: FontWeight.bold),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildStatusIcon(Color primary) {
    if (isCurrent) {
      return InkWell(
        onTap: onComplete,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: primary, width: 2),
          ),
          child: Icon(Icons.check, color: primary, size: 18),
        ),
      );
    }

    if (isNext) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300, width: 2),
        ),
        child: Icon(Icons.check, color: Colors.grey.shade300, size: 18),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: primary,
      ),
      child: const Icon(Icons.check, color: Colors.black, size: 18),
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
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
                color: selected ? color : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


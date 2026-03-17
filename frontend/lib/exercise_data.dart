import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class Exercise {
  final String id;
  final String name;
  final String muscleGroup; // 胸部, 背部, etc.
  final String difficulty; // 入门, 中级, 高级
  final String details; // 动作要点描述
  final String imageAssetPath; // 图片路径，例如 'assets/images/chest_01.png'

  Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.difficulty,
    required this.details,
    required this.imageAssetPath,
  });
}

/// 从 assets/data/exercises.json 载入 free-exercise-db 的数据，
/// 并映射到当前应用使用的 Exercise 模型。
Future<List<Exercise>> loadExercisesFromJson() async {
  final raw =
      await rootBundle.loadString('assets/data/exercises.json'); // 放在此路径下
  final List<dynamic> list = jsonDecode(raw) as List<dynamic>;

  return list.map((e) {
    final map = e as Map<String, dynamic>;
    return Exercise(
      id: map['id'] as String,
      name: _translateExerciseName(map['name'] as String),
      muscleGroup:
          _mapPrimaryMusclesToGroup(map['primaryMuscles'] as List<dynamic>?),
      difficulty: _mapLevelToDifficulty(map['level'] as String?),
      details: _joinInstructions(map['instructions'] as List<dynamic>?),
      imageAssetPath: _buildImageAssetPath(map['images'] as List<dynamic>?),
    );
  }).toList();
}

/// 简单的英文动作名 → 中文翻译映射。
/// 未命中时，保留英文原文。
String _translateExerciseName(String name) {
  final key = name.toLowerCase();

  // 先尝试整句精确映射（常见热门动作）
  const fullDict = <String, String>{
    'barbell bench press - medium grip': '杠铃卧推（中等握距）',
    'alternating floor press': '交替地板推举',
    'air bike': '空中自行车卷腹',
    'around the worlds': '环绕飞鸟',
    'pull up': '引体向上',
    'chin up': '正握引体向上',
    'push up': '俯卧撑',
    'incline push-up': '上斜俯卧撑',
    'decline push-up': '下斜俯卧撑',
    'deadlift': '硬拉',
    'romanian deadlift': '罗马尼亚硬拉',
    'sumo deadlift': '相扑硬拉',
    'squat': '深蹲',
    'front squat': '前蹲',
    'back squat': '背蹲',
    'dumbbell fly': '哑铃飞鸟',
    'incline dumbbell press': '上斜哑铃卧推',
    'lat pulldown': '高位下拉',
  };
  final full = fullDict[key];
  if (full != null) return full;

  // 否则按单词翻译并拼接，尽量给出中文大意
  const wordDict = <String, String>{
    'barbell': '杠铃',
    'dumbbell': '哑铃',
    'kettlebell': '壶铃',
    'bench': '卧推凳',
    'press': '推举',
    'curl': '弯举',
    'row': '划船',
    'pull': '拉',
    'pulldown': '下拉',
    'fly': '飞鸟',
    'squat': '深蹲',
    'lunge': '箭步蹲',
    'deadlift': '硬拉',
    'crunch': '卷腹',
    'sit-up': '仰卧起坐',
    'plank': '平板支撑',
    'push-up': '俯卧撑',
    'pushup': '俯卧撑',
    'press-up': '俯卧撑',
    'hip': '髋部',
    'thrust': '顶臀',
    'extension': '伸展',
    'raise': '抬举',
    'front': '前',
    'back': '背',
    'side': '侧',
    'lateral': '侧平举',
    'reverse': '反向',
    'incline': '上斜',
    'decline': '下斜',
    'seated': '坐姿',
    'lying': '仰卧',
    'standing': '站姿',
    'cable': '拉力器',
    'machine': '器械',
    'smith': '史密斯机',
    'hanging': '悬垂',
    'alternate': '交替',
    'alternating': '交替',
    'single-arm': '单臂',
    'single arm': '单臂',
    'one-arm': '单臂',
    'one arm': '单臂',
    'double': '双臂',
    'wide-grip': '宽握',
    'close-grip': '窄握',
    'medium grip': '中等握距',
    'grip': '握距',
    'overhead': '头上',
    'floor': '地板',
    'flyes': '飞鸟',
    'presses': '推举',
    'twist': '扭转',
    'bike': '自行车',
  };

  // 用空格和常见符号拆分，再逐词翻译
  final buffer = StringBuffer();
  final tokenReg = RegExp(r"[A-Za-z\-']+|\W+");
  for (final match in tokenReg.allMatches(name)) {
    final token = match.group(0)!;
    final lower = token.toLowerCase();
    final mapped = wordDict[lower];
    if (mapped != null) {
      buffer.write(mapped);
    } else {
      buffer.write(token);
    }
  }

  final translated = buffer.toString();
  return translated == name ? name : translated;
}

String _mapPrimaryMusclesToGroup(List<dynamic>? primary) {
  if (primary == null || primary.isEmpty) return '全身';
  final first = (primary.first as String).toLowerCase();
  switch (first) {
    case 'chest':
      return '胸部';
    case 'back':
      return '背部';
    case 'shoulders':
      return '肩部';
    case 'biceps':
    case 'triceps':
    case 'forearms':
      return '手臂';
    case 'quadriceps':
    case 'hamstrings':
    case 'glutes':
    case 'calves':
      return '腿部';
    case 'abdominals':
    case 'abductors':
    case 'adductors':
      return '腹部';
    default:
      return '全身';
  }
}

String _mapLevelToDifficulty(String? level) {
  if (level == null) return '入门';
  final l = level.toLowerCase();
  if (l.contains('beginner') || l.contains('novice')) return '入门';
  if (l.contains('intermediate')) return '中级';
  if (l.contains('advanced') || l.contains('expert')) return '高级';
  return '入门';
}

String _joinInstructions(List<dynamic>? instructions) {
  if (instructions == null || instructions.isEmpty) return '';
  return instructions.map((e) => e.toString()).join('\n');
}

String _buildImageAssetPath(List<dynamic>? images) {
  if (images == null || images.isEmpty) {
    return 'assets/images/custom_placeholder.png';
  }
  final first = images.first.toString(); // 形如 "Air_Bike/0.jpg"
  return '/images/exercises/$first';
}
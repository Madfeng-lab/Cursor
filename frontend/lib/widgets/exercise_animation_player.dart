import 'package:flutter/material.dart';

/// 简化版：不再使用 Rive，直接加载图片资源。
class ExerciseAnimationPlayer extends StatelessWidget {
  final String assetPath;
  final String animationName; // 保留参数以兼容现有调用，实际未使用

  const ExerciseAnimationPlayer({
    Key? key,
    required this.assetPath,
    required this.animationName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return const Icon(Icons.image_not_supported, size: 32);
          },
        ),
      ),
    );
  }
}


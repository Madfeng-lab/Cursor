import 'package:flutter/material.dart';

const _exerciseImageAssetPrefix = 'assets/images/exercises/';
const _exerciseImageRemotePrefix =
    'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';

/// 简化版：优先加载本地动作图，本地缺失时回退到 Web 静态文件和公开原图。
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
    final normalizedPath = assetPath.trim();
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20.0),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: _buildImage(normalizedPath),
      ),
    );
  }

  Widget _buildImage(String path) {
    if (path.isEmpty) {
      return _buildFallback();
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    }

    final webStaticUrl = _toWebStaticUrl(path);
    final remoteFallbackUrl = _toRemoteExerciseUrl(path);
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        if (webStaticUrl != null) {
          return Image.network(
            webStaticUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              if (remoteFallbackUrl == null) {
                return _buildFallback();
              }
              return Image.network(
                remoteFallbackUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallback(),
              );
            },
          );
        }

        if (remoteFallbackUrl == null) {
          return _buildFallback();
        }
        return Image.network(
          remoteFallbackUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      },
    );
  }

  String? _toWebStaticUrl(String path) {
    if (!path.startsWith('assets/')) {
      return null;
    }
    return 'assets/$path';
  }

  String? _toRemoteExerciseUrl(String path) {
    if (!path.startsWith(_exerciseImageAssetPrefix)) {
      return null;
    }
    final relativePath = path.substring(_exerciseImageAssetPrefix.length);
    if (relativePath.isEmpty) {
      return null;
    }
    return '$_exerciseImageRemotePrefix$relativePath';
  }

  Widget _buildFallback() {
    return const Icon(Icons.image_not_supported, size: 32);
  }
}


import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

const _exerciseImageAssetPrefix = 'assets/images/exercises/';
const _exerciseImageRemotePrefix =
    'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';

/// 动作“动图”播放器：用每个动作的两帧图片（`0.jpg` / `1.jpg`）轮播实现。
/// 约定：`assetPath` 通常来自 `assets/images/exercises/.../0.jpg`（或 `1.jpg`）。
class ExerciseAnimationPlayer extends StatefulWidget {
  final String assetPath;
  final String animationName; // 保留参数以兼容现有调用
  final Duration frameInterval;

  const ExerciseAnimationPlayer({
    Key? key,
    required this.assetPath,
    required this.animationName,
    this.frameInterval = const Duration(milliseconds: 1000),
  }) : super(key: key);

  @override
  State<ExerciseAnimationPlayer> createState() =>
      _ExerciseAnimationPlayerState();
}

class _ExerciseAnimationPlayerState extends State<ExerciseAnimationPlayer> {
  late List<String> _frames; // [frame0Path, frame1Path]
  int _idx = 0;
  bool _canAnimate = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _recomputeFrames();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant ExerciseAnimationPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _recomputeFrames();
      _startTimerIfNeeded();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    _timer = null;

    if (!_canAnimate) return;

    _timer = Timer.periodic(widget.frameInterval, (_) {
      if (!mounted) return;
      setState(() {
        _idx = (_idx + 1) % 2;
      });
    });
  }

  void _recomputeFrames() {
    final p = widget.assetPath.trim();
    final resolved = _resolveTwoFrames(p);
    _frames = resolved.$1;
    _idx = 0;
    _canAnimate = resolved.$2;
  }

  (List<String>, bool) _resolveTwoFrames(String assetPath) {
    if (assetPath.isEmpty) return ([assetPath, assetPath], false);

    final m = RegExp(r'^(.*)/[01]\.(jpg|jpeg|png|webp)$',
            caseSensitive: false)
        .firstMatch(assetPath);
    if (m == null) return ([assetPath, assetPath], false);

    final base = m.group(1)!; // 不包含末尾 /0.jpg
    final ext = m.group(2)!;

    final frame0 = '$base/0.$ext';
    final frame1 = '$base/1.$ext';
    return ([frame0, frame1], true);
  }

  @override
  Widget build(BuildContext context) {
    final bg = BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(20.0),
    );

    final p0 = _frames.length >= 2 ? _frames[_idx] : '';
    return Container(
      decoration: bg,
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: _frames.isEmpty
            ? _buildSingleImage('')
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _buildSingleImage(
                  p0,
                  key: ValueKey<int>(_idx),
                ),
              ),
      ),
    );
  }

  Widget _buildSingleImage(String path, {Key? key}) {
    return KeyedSubtree(
      key: key,
      child: _buildImage(path),
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

    // Web 场景：为了配合你“把图片拷到 build/web 下再静态访问”的部署方式，
    // 直接走静态文件 URL，避免 `Image.asset` 依赖 asset manifest 导致找不到。
    if (kIsWeb) {
      final webStaticUrl = _toWebStaticUrl(path);
      if (webStaticUrl != null) {
        return Image.network(
          webStaticUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      }
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
    // 注意：这是绝对路径，必须从站点根开始。
    // `path` 的格式为 `assets/images/...`，部署时静态资源应从 `/assets/...` 读取。
    // assets/images/... -> /assets/images/...
    return '/$path';
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


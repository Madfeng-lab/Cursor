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

    final webStaticUrls = _toWebStaticUrls(path);
    final remoteFallbackUrl = _toRemoteExerciseUrl(path);

    // Web 场景：优先尝试静态 URL（兼容 /assets/images 与 /assets/assets/images 两种部署），
    // 失败后再回退到远端图源。
    if (kIsWeb) {
      if (webStaticUrls.isNotEmpty) {
        return _buildNetworkWithFallback(
          urls: webStaticUrls,
          fit: BoxFit.cover,
          finalFallback: remoteFallbackUrl == null
              ? _buildFallback()
              : Image.network(
                  remoteFallbackUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildFallback(),
                ),
        );
      }
    }

    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        if (webStaticUrls.isNotEmpty) {
          return _buildNetworkWithFallback(
            urls: webStaticUrls,
            fit: BoxFit.cover,
            finalFallback: remoteFallbackUrl == null
                ? _buildFallback()
                : Image.network(
                    remoteFallbackUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildFallback(),
                  ),
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

  List<String> _toWebStaticUrls(String path) {
    if (!path.startsWith('assets/')) {
      return const [];
    }
    // 兼容两种常见部署目录：
    // 1) /assets/images/...（自定义复制）
    // 2) /assets/assets/images/...（Flutter web 默认 assets 根）
    return ['/$path', '/assets/$path'];
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

  Widget _buildNetworkWithFallback({
    required List<String> urls,
    required BoxFit fit,
    required Widget finalFallback,
    int index = 0,
  }) {
    if (index >= urls.length) {
      return finalFallback;
    }
    return Image.network(
      urls[index],
      fit: fit,
      errorBuilder: (_, __, ___) => _buildNetworkWithFallback(
        urls: urls,
        fit: fit,
        finalFallback: finalFallback,
        index: index + 1,
      ),
    );
  }
}


import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'api_client.dart';
import 'auth_state.dart';
import 'food_ai_service.dart';
import 'stats_page.dart';

// 统一的饮食页主题色
const Color kDietPrimary = Color(0xFF25F46A);
const Color kDietBackgroundLight = Color(0xFFF5F8F6);

const int _userId = 1;
const int _targetCalories = 2300;
const double _targetCarbs = 220;
const double _targetProtein = 120;
const double _targetFat = 70;

String _dateStr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 缩小为 JPEG 缩略图，降低饮食 API payload 体积。
Uint8List? _mealPhotoThumbnailBytes(
  Uint8List raw, {
  int maxWidth = 480,
  int quality = 78,
}) {
  try {
    final decoded = img.decodeImage(raw);
    if (decoded == null) return null;
    final resized = decoded.width <= maxWidth
        ? decoded
        : img.copyResize(decoded, width: maxWidth);
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  } catch (_) {
    return null;
  }
}

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<DietPage> {
  DateTime _selectedDate = DateTime.now();
  List<DietMeal> _meals = [];
  List<DietFood> _foods = [];
  bool _loading = true;
  String? _error;

  ApiClient get _api => context.read<AuthState>().apiClient;

  late final FoodAiService _foodAi;

  @override
  void initState() {
    super.initState();
    _foodAi = FoodAiService(backendBaseUrl: _api.baseUrl);
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = _dateStr(_selectedDate);
      final to = from;
      final list = await _api.listDietMeals(userId: _userId, from: from, to: to);
      if (!mounted) return;
      setState(() {
        _meals = list;
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

  Future<void> _loadFoods() async {
    try {
      final list = await _api.listDietFoods();
      if (!mounted) return;
      setState(() => _foods = list);
    } catch (_) {}
  }

  DietMeal? _mealFor(String mealType) {
    try {
      return _meals.firstWhere((m) => m.mealType == mealType);
    } catch (_) {
      return null;
    }
  }

  int get _totalCalories =>
      _meals.fold(0, (s, m) => s + m.totalCalories);
  double get _totalProtein => _meals.fold(0.0, (s, m) => s + m.totalProtein);
  double get _totalCarbs => _meals.fold(0.0, (s, m) => s + m.totalCarbs);
  double get _totalFat => _meals.fold(0.0, (s, m) => s + m.totalFat);

  void _onAddFood(String mealType) async {
    await _loadFoods();
    if (!mounted) return;
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AddFoodToMealDialog(
        apiClient: _api,
        userId: _userId,
        date: _dateStr(_selectedDate),
        mealType: mealType,
        existingMeal: _mealFor(mealType),
        foods: _foods,
        onCreateFood: () async {
          await _loadFoods();
          if (!mounted) return;
          setState(() {});
        },
        getFreshFoods: () => _api.listDietFoods(),
      ),
    );
    if (added == true) _loadMeals();
  }

  void _onQuickCopy(String mealType) async {
    final yesterday = _selectedDate.subtract(const Duration(days: 1));
    final from = _dateStr(yesterday);
    final to = from;
    try {
      final list = await _api.listDietMeals(userId: _userId, from: from, to: to);
      DietMeal? prev;
      try {
        prev = list.firstWhere((m) => m.mealType == mealType);
      } catch (_) {}
      if (prev == null || prev.items.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('前一天该餐次无记录')),
        );
        return;
      }
      final todayStr = _dateStr(_selectedDate);
      final items = prev.items.map((e) => {'foodId': e.food.id, 'amount': e.amount}).toList();
      await _api.createDietMeal(userId: _userId, date: todayStr, mealType: mealType, items: items);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制前一餐')));
      _loadMeals();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('复制失败: $e')));
    }
  }

  Future<void> _onEditMealItem(DietMealItem item) async {
    if (item.id == null) return;
    await _loadFoods();
    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _EditMealItemDialog(
        apiClient: _api,
        item: item,
        foods: _foods,
      ),
    );
    if (result == true) _loadMeals();
  }

  Future<void> _onDeleteMealItem(DietMealItem item) async {
    if (item.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除该项？'),
        content: Text('确定从本餐中删除「${item.food.name}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _api.deleteDietMealItem(item.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
      _loadMeals();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  /// 选择本次 AI 识餐要记入的餐次。
  Future<String?> _pickMealTypeForAi() {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('AI 识餐记入哪一餐？', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('早餐'),
              onTap: () => Navigator.pop(ctx, 'breakfast'),
            ),
            ListTile(
              leading: const Icon(Icons.wb_sunny_rounded),
              title: const Text('午餐'),
              onTap: () => Navigator.pop(ctx, 'lunch'),
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('晚餐'),
              onTap: () => Navigator.pop(ctx, 'dinner'),
            ),
            ListTile(
              leading: const Icon(Icons.icecream_outlined),
              title: const Text('加餐'),
              onTap: () => Navigator.pop(ctx, 'snack'),
            ),
          ],
        ),
      ),
    );
  }

  Future<XFile?> _pickMealPhotoWithSource() async {
    final picker = ImagePicker();
    if (kIsWeb) {
      return picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'camera') {
      return picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
    }
    if (choice == 'gallery') {
      return picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    }
    return null;
  }

  String _guessMime(XFile file) {
    final p = '${file.path}${file.name}'.toLowerCase();
    if (p.contains('.png')) return 'image/png';
    if (p.contains('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _onAiPhotoMeal() async {
    final mealType = await _pickMealTypeForAi();
    if (mealType == null || !mounted) return;
    await _runAiRecognitionForMeal(mealType);
  }

  Future<void> _runAiRecognitionForMeal(String mealType) async {
    final xfile = await _pickMealPhotoWithSource();
    if (xfile == null || !mounted) return;

    Uint8List bytes;
    try {
      bytes = await xfile.readAsBytes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('读取照片失败：$e')),
      );
      return;
    }
    if (bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片为空，请重新选择')),
      );
      return;
    }

    final mime = _guessMime(xfile);

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => const _AiAnalyzingDialog(),
    );

    try {
      final result = await _foodAi.analyzeFood(
        imageBytes: bytes,
        mimeType: mime,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _AiFoodConfirmDialog(
          imageBytes: bytes,
          imageMimeType: mime,
          initial: result,
          mealType: mealType,
          api: _api,
          userId: _userId,
          dateStr: _dateStr(_selectedDate),
          existingMeal: _mealFor(mealType),
        ),
      );
      if (saved == true) _loadMeals();
    } on FoodAiException catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('识别未成功'),
          content: Text(e.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _runAiRecognitionForMeal(mealType);
              },
              style: FilledButton.styleFrom(backgroundColor: kDietPrimary),
              child: const Text('重新拍照'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('识餐失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: kDietBackgroundLight,
      appBar: AppBar(
        backgroundColor: kDietBackgroundLight,
        elevation: 0,
        titleSpacing: 0,
        title: InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => _selectedDate = picked);
            _loadMeals();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_outlined, color: kDietPrimary),
                const SizedBox(width: 8),
                Text(
                  _selectedDate.year == DateTime.now().year &&
                          _selectedDate.month == DateTime.now().month &&
                          _selectedDate.day == DateTime.now().day
                      ? '今日饮食'
                      : '${_selectedDate.month}月${_selectedDate.day}日 饮食',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StatsPage()),
              );
            },
            icon: Icon(
              Icons.analytics_outlined,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _loading && _meals.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _meals.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _loadMeals, child: const Text('重试')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadMeals,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RemainingCalorieCard(
                            caloriesIn: _totalCalories,
                            targetCalories: _targetCalories,
                          ),
                          const SizedBox(height: 16),
                          _MacroCards(
                            protein: _totalProtein,
                            carbs: _totalCarbs,
                            fat: _totalFat,
                          ),
                          const SizedBox(height: 16),
                          _AiNewRecordCard(onCameraTap: _onAiPhotoMeal),
                          const SizedBox(height: 24),
                          _MealSection(
                            icon: Icons.wb_sunny_outlined,
                            iconColor: Colors.orangeAccent,
                            title: '早餐',
                            subtitle: '建议 400-600 kcal',
                            showQuickCopy: true,
                            meal: _mealFor('breakfast'),
                            onAdd: () => _onAddFood('breakfast'),
                            onQuickCopy: () => _onQuickCopy('breakfast'),
                            onEditItem: _onEditMealItem,
                            onDeleteItem: _onDeleteMealItem,
                          ),
                          const SizedBox(height: 24),
                          _MealSection(
                            icon: Icons.wb_sunny_rounded,
                            iconColor: Colors.lightBlueAccent,
                            title: '午餐',
                            subtitle: '建议 600-800 kcal',
                            showQuickCopy: true,
                            meal: _mealFor('lunch'),
                            onAdd: () => _onAddFood('lunch'),
                            onQuickCopy: () => _onQuickCopy('lunch'),
                            onEditItem: _onEditMealItem,
                            onDeleteItem: _onDeleteMealItem,
                          ),
                          const SizedBox(height: 24),
                          _MealSection(
                            icon: Icons.dark_mode_outlined,
                            iconColor: Colors.indigoAccent,
                            title: '晚餐',
                            subtitle: '建议 400-600 kcal',
                            meal: _mealFor('dinner'),
                            onAdd: () => _onAddFood('dinner'),
                            onEditItem: _onEditMealItem,
                            onDeleteItem: _onDeleteMealItem,
                          ),
                          const SizedBox(height: 24),
                          _MealSection(
                            icon: Icons.icecream_outlined,
                            iconColor: Colors.pinkAccent,
                            title: '加餐',
                            meal: _mealFor('snack'),
                            onAdd: () => _onAddFood('snack'),
                            onEditItem: _onEditMealItem,
                            onDeleteItem: _onDeleteMealItem,
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kDietPrimary,
        onPressed: () async {
          final mealType = await showModalBottomSheet<String>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.wb_sunny_outlined),
                    title: const Text('早餐'),
                    onTap: () => Navigator.pop(ctx, 'breakfast'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.wb_sunny_rounded),
                    title: const Text('午餐'),
                    onTap: () => Navigator.pop(ctx, 'lunch'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.dark_mode_outlined),
                    title: const Text('晚餐'),
                    onTap: () => Navigator.pop(ctx, 'dinner'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.icecream_outlined),
                    title: const Text('加餐'),
                    onTap: () => Navigator.pop(ctx, 'snack'),
                  ),
                ],
              ),
            ),
          );
          if (mealType != null) _onAddFood(mealType);
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

class _RemainingCalorieCard extends StatelessWidget {
  const _RemainingCalorieCard({
    required this.caloriesIn,
    required this.targetCalories,
  });
  final int caloriesIn;
  final int targetCalories;

  @override
  Widget build(BuildContext context) {
    final remaining = (targetCalories - caloriesIn).clamp(0, targetCalories);
    final progress = targetCalories > 0 ? (caloriesIn / targetCalories).clamp(0.0, 1.0) : 0.0;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(20))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '剩余热量',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$remaining ',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: kDietPrimary,
                            ),
                          ),
                          const TextSpan(
                            text: 'kcal',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.local_fire_department_outlined,
                  size: 40,
                  color: Colors.orangeAccent,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(kDietPrimary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '已摄入 $caloriesIn / 目标 $targetCalories',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroCards extends StatelessWidget {
  const _MacroCards({
    required this.protein,
    required this.carbs,
    required this.fat,
  });
  final double protein;
  final double carbs;
  final double fat;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MacroCard(
                label: '碳水',
                valueText: '${carbs.toStringAsFixed(0)}g / ${_targetCarbs.toInt()}g',
                progress: _targetCarbs > 0 ? (carbs / _targetCarbs).clamp(0.0, 1.0) : 0,
                barColor: const Color(0xFF60A5FA),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MacroCard(
                label: '蛋白质',
                valueText: '${protein.toStringAsFixed(0)}g / ${_targetProtein.toInt()}g',
                progress: _targetProtein > 0 ? (protein / _targetProtein).clamp(0.0, 1.0) : 0,
                barColor: const Color(0xFFF97373),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MacroCard(
          label: '脂肪',
          valueText: '${fat.toStringAsFixed(0)}g / ${_targetFat.toInt()}g',
          progress: _targetFat > 0 ? (fat / _targetFat).clamp(0.0, 1.0) : 0,
          barColor: const Color(0xFFFBBF24),
        ),
      ],
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({
    required this.label,
    required this.valueText,
    required this.progress,
    required this.barColor,
  });

  final String label;
  final String valueText;
  final double progress;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  valueText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  const _MealSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.showQuickCopy = false,
    required this.meal,
    required this.onAdd,
    this.onQuickCopy,
    this.onEditItem,
    this.onDeleteItem,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool showQuickCopy;
  final DietMeal? meal;
  final VoidCallback onAdd;
  final VoidCallback? onQuickCopy;
  final void Function(DietMealItem item)? onEditItem;
  final void Function(DietMealItem item)? onDeleteItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ],
            ),
            Row(
              children: [
                if (showQuickCopy && onQuickCopy != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    onPressed: onQuickCopy,
                    icon: const Icon(Icons.content_copy, size: 16),
                    label: const Text('快速复制', style: TextStyle(fontSize: 11)),
                  ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      backgroundColor: kDietPrimary,
                      elevation: 1,
                    ),
                    onPressed: onAdd,
                    child: const Icon(Icons.add, size: 20, color: Colors.black),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (meal == null || meal!.items.isEmpty)
          const DottedBorderContainer(
            child: Center(
              child: Text(
                '尚未记录',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          )
        else
          ...meal!.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FoodItemCard(
                item: item,
                onEdit: item.id != null
                    ? () => onEditItem?.call(item)
                    : null,
                onDelete: item.id != null
                    ? () => onDeleteItem?.call(item)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _FoodItemCard extends StatelessWidget {
  const _FoodItemCard({
    required this.item,
    this.onEdit,
    this.onDelete,
  });

  final DietMealItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final title = item.food.name;
    final description = '${item.amount.toStringAsFixed(0)}g';
    final calories = '${item.calories} kcal';
    final b64 = item.food.photoBase64;

    Widget thumb;
    if (b64 != null && b64.isNotEmpty) {
      try {
        final bytes = base64Decode(b64);
        thumb = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _foodPlaceholderThumb(),
          ),
        );
      } catch (_) {
        thumb = _foodPlaceholderThumb();
      }
    } else {
      thumb = _foodPlaceholderThumb();
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(width: 48, height: 48, child: thumb),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              calories,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onEdit != null || onDelete != null) ...[
              const SizedBox(width: 4),
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(36, 36),
                  ),
                ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                  onPressed: onDelete,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(36, 36),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _foodPlaceholderThumb() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.restaurant_outlined,
        size: 24,
        color: Colors.grey,
      ),
    );
  }
}

class _AddFoodToMealDialog extends StatefulWidget {
  const _AddFoodToMealDialog({
    required this.apiClient,
    required this.userId,
    required this.date,
    required this.mealType,
    required this.existingMeal,
    required this.foods,
    required this.onCreateFood,
    required this.getFreshFoods,
  });
  final ApiClient apiClient;
  final int userId;
  final String date;
  final String mealType;
  final DietMeal? existingMeal;
  final List<DietFood> foods;
  final VoidCallback onCreateFood;
  final Future<List<DietFood>> Function() getFreshFoods;

  @override
  State<_AddFoodToMealDialog> createState() => _AddFoodToMealDialogState();
}

class _AddFoodToMealDialogState extends State<_AddFoodToMealDialog> {
  String _query = '';
  DietFood? _selectedFood;
  final _amountController = TextEditingController(text: '100');
  late List<DietFood> _foods;

  @override
  void initState() {
    super.initState();
    _foods = widget.foods;
  }

  @override
  void didUpdateWidget(covariant _AddFoodToMealDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.foods != widget.foods) _foods = widget.foods;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  List<DietFood> get _filtered => _foods
      .where((f) => f.name.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  Future<void> _onEditFood(DietFood food) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CreateFoodDialog(
        apiClient: widget.apiClient,
        initialFood: food,
        onCreated: () async {
          widget.onCreateFood();
          final fresh = await widget.getFreshFoods();
          if (mounted) setState(() => _foods = fresh);
        },
      ),
    );
    if (updated == true) {
      final fresh = await widget.getFreshFoods();
      if (mounted) setState(() => _foods = fresh);
    }
  }

  Future<void> _onDeleteFood(DietFood food) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除该食物？'),
        content: Text(
          '确定删除「${food.name}」？已添加到各餐中的该食物记录也会被移除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await widget.apiClient.deleteDietFood(food.id);
      if (!mounted) return;
      final fresh = await widget.getFreshFoods();
      if (mounted) setState(() => _foods = fresh);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  Future<void> _submit() async {
    final food = _selectedFood;
    final amount = double.tryParse(_amountController.text.trim());
    if (food == null || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择食物并填写克数')),
      );
      return;
    }
    try {
      if (widget.existingMeal != null) {
        await widget.apiClient.addDietMealItems(
          mealId: widget.existingMeal!.id,
          items: [{'foodId': food.id, 'amount': amount}],
        );
      } else {
        await widget.apiClient.createDietMeal(
          userId: widget.userId,
          date: widget.date,
          mealType: widget.mealType,
          items: [{'foodId': food.id, 'amount': amount}],
        );
      }
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final mealTypeName = const {
      'breakfast': '早餐',
      'lunch': '午餐',
      'dinner': '晚餐',
      'snack': '加餐',
    }[widget.mealType] ?? widget.mealType;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '添加至$mealTypeName',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: '搜索食物',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('无匹配食物，可先创建食物'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final f = filtered[i];
                          final selected = _selectedFood?.id == f.id;
                          return ListTile(
                            title: Text(f.name),
                            subtitle: Text(
                              '${f.calories ?? 0} kcal/100g  P${f.protein?.toStringAsFixed(0) ?? 0} C${f.carbs?.toStringAsFixed(0) ?? 0} F${f.fat?.toStringAsFixed(0) ?? 0}',
                            ),
                            selected: selected,
                            onTap: () => setState(() => _selectedFood = f),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => _onEditFood(f),
                                  style: IconButton.styleFrom(
                                    padding: const EdgeInsets.all(4),
                                    minimumSize: const Size(36, 36),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade400),
                                  onPressed: () => _onDeleteFood(f),
                                  style: IconButton.styleFrom(
                                    padding: const EdgeInsets.all(4),
                                    minimumSize: const Size(36, 36),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (_selectedFood != null) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: '克数 (g)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      final created = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => _CreateFoodDialog(
                          apiClient: widget.apiClient,
                          onCreated: () async {
                            widget.onCreateFood();
                            final fresh = await widget.getFreshFoods();
                            if (mounted) setState(() => _foods = fresh);
                          },
                        ),
                      );
                    },
                    child: const Text('新建食物'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(backgroundColor: kDietPrimary),
                    child: const Text('确定'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditMealItemDialog extends StatefulWidget {
  const _EditMealItemDialog({
    required this.apiClient,
    required this.item,
    required this.foods,
  });
  final ApiClient apiClient;
  final DietMealItem item;
  final List<DietFood> foods;

  @override
  State<_EditMealItemDialog> createState() => _EditMealItemDialogState();
}

class _EditMealItemDialogState extends State<_EditMealItemDialog> {
  late DietFood _selectedFood;
  late TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _selectedFood = widget.item.food;
    _amountController = TextEditingController(
      text: widget.item.amount.toStringAsFixed(0),
    );
  }

  List<DietFood> get _foodOptions {
    final list = List<DietFood>.from(widget.foods);
    if (!list.any((f) => f.id == widget.item.food.id)) {
      list.insert(0, widget.item.food);
    }
    return list;
  }

  DietFood? get _dropdownValue {
    try {
      return _foodOptions.firstWhere((f) => f.id == _selectedFood.id);
    } catch (_) {
      return _foodOptions.isNotEmpty ? _foodOptions.first : null;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效克数')),
      );
      return;
    }
    if (widget.item.id == null) return;
    try {
      await widget.apiClient.updateDietMealItem(
        widget.item.id!,
        amount: amount,
        foodId: _selectedFood.id,
      );
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('修改失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '修改食物',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DietFood>(
              value: _dropdownValue,
              decoration: const InputDecoration(
                labelText: '食物',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _foodOptions
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f.name),
                      ))
                  .toList(),
              onChanged: (f) => setState(() => _selectedFood = f!),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '克数 (g)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(backgroundColor: kDietPrimary),
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateFoodDialog extends StatefulWidget {
  const _CreateFoodDialog({
    required this.apiClient,
    required this.onCreated,
    this.initialFood,
  });
  final ApiClient apiClient;
  final Future<void> Function() onCreated;
  /// 非空时为「修改食物」模式
  final DietFood? initialFood;

  @override
  State<_CreateFoodDialog> createState() => _CreateFoodDialogState();
}

class _CreateFoodDialogState extends State<_CreateFoodDialog> {
  late TextEditingController _nameController;
  late TextEditingController _calController;
  late TextEditingController _pController;
  late TextEditingController _cController;
  late TextEditingController _fController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFood;
    _nameController = TextEditingController(text: f?.name ?? '');
    _calController = TextEditingController(text: f?.calories?.toString() ?? '0');
    _pController = TextEditingController(text: f?.protein?.toString() ?? '0');
    _cController = TextEditingController(text: f?.carbs?.toString() ?? '0');
    _fController = TextEditingController(text: f?.fat?.toString() ?? '0');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _calController.dispose();
    _pController.dispose();
    _cController.dispose();
    _fController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入食物名称')));
      return;
    }
    setState(() => _saving = true);
    try {
      final calories = int.tryParse(_calController.text.trim());
      final protein = double.tryParse(_pController.text.trim());
      final carbs = double.tryParse(_cController.text.trim());
      final fat = double.tryParse(_fController.text.trim());
      if (widget.initialFood != null) {
        await widget.apiClient.updateDietFood(
          widget.initialFood!.id,
          name: name,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
        );
      } else {
        await widget.apiClient.createDietFood(
          name: name,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
        );
      }
      await widget.onCreated();
      if (!context.mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.initialFood != null ? '修改失败: $e' : '创建失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initialFood != null ? '修改食物 (每100g)' : '新建食物 (每100g)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '名称', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _calController,
              decoration: const InputDecoration(labelText: '热量 (kcal)', border: OutlineInputBorder(), isDense: true),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pController,
                    decoration: const InputDecoration(labelText: '蛋白质', isDense: true),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _cController,
                    decoration: const InputDecoration(labelText: '碳水', isDense: true),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fController,
                    decoration: const InputDecoration(labelText: '脂肪', isDense: true),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: kDietPrimary),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(widget.initialFood != null ? '保存' : '创建'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// AI 分析中的全屏遮罩
class _AiAnalyzingDialog extends StatelessWidget {
  const _AiAnalyzingDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: kDietPrimary),
              SizedBox(height: 18),
              Text(
                'AI 正在分析食物...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                '请稍候',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 新增记录：圆形相机入口
class _AiNewRecordCard extends StatelessWidget {
  const _AiNewRecordCard({required this.onCameraTap});

  final VoidCallback onCameraTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '新增记录',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kIsWeb ? '上传照片，AI 估算营养（Web 为相册）' : '拍照或选图，AI 估算营养',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onCameraTap,
                customBorder: const CircleBorder(),
                child: Ink(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kDietPrimary,
                    boxShadow: [
                      BoxShadow(
                        color: kDietPrimary.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.black87,
                    size: 32,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AI 结果确认：缩略图 + 可编辑字段 + 保存到后端饮食接口
class _AiFoodConfirmDialog extends StatefulWidget {
  const _AiFoodConfirmDialog({
    required this.imageBytes,
    required this.imageMimeType,
    required this.initial,
    required this.mealType,
    required this.api,
    required this.userId,
    required this.dateStr,
    required this.existingMeal,
  });

  final Uint8List imageBytes;
  final String imageMimeType;
  final FoodAiResult initial;
  final String mealType;
  final ApiClient api;
  final int userId;
  final String dateStr;
  final DietMeal? existingMeal;

  @override
  State<_AiFoodConfirmDialog> createState() => _AiFoodConfirmDialogState();
}

class _AiFoodConfirmDialogState extends State<_AiFoodConfirmDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _calCtrl;
  late final TextEditingController _pCtrl;
  late final TextEditingController _cCtrl;
  late final TextEditingController _fCtrl;
  bool _saving = false;

  static const Color _kCalOrange = Color(0xFFFF6B35);

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _nameCtrl = TextEditingController(text: r.foodName);
    _weightCtrl = TextEditingController(
      text: r.estimatedWeightG <= 0
          ? '100'
          : r.estimatedWeightG.toStringAsFixed(0),
    );
    _calCtrl = TextEditingController(text: '${r.calories}');
    _pCtrl = TextEditingController(text: r.protein.toStringAsFixed(1));
    _cCtrl = TextEditingController(text: r.carbs.toStringAsFixed(1));
    _fCtrl = TextEditingController(text: r.fat.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _calCtrl.dispose();
    _pCtrl.dispose();
    _cCtrl.dispose();
    _fCtrl.dispose();
    super.dispose();
  }

  String get _mealTitle {
    const map = {
      'breakfast': '早餐',
      'lunch': '午餐',
      'dinner': '晚餐',
      'snack': '加餐',
    };
    return map[widget.mealType] ?? widget.mealType;
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final w = double.tryParse(_weightCtrl.text.trim());
    final cal = int.tryParse(_calCtrl.text.trim());
    final p = double.tryParse(_pCtrl.text.trim());
    final c = double.tryParse(_cCtrl.text.trim());
    final f = double.tryParse(_fCtrl.text.trim());

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写食物名称')),
      );
      return;
    }
    if (w == null || w <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写合理的重量（克）')),
      );
      return;
    }
    if (cal == null || cal < 0 || p == null || c == null || f == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写有效的营养数值')),
      );
      return;
    }

    final factor = 100.0 / w;
    final cal100 = (cal * factor).round().clamp(0, 100000);
    final p100 = (p * factor).clamp(0.0, 10000.0);
    final c100 = (c * factor).clamp(0.0, 10000.0);
    final f100 = (f * factor).clamp(0.0, 10000.0);

    setState(() => _saving = true);
    try {
      final thumbBytes =
          _mealPhotoThumbnailBytes(widget.imageBytes) ?? widget.imageBytes;
      final photoMime = identical(thumbBytes, widget.imageBytes)
          ? widget.imageMimeType
          : 'image/jpeg';
      final photoB64 = base64Encode(thumbBytes);

      final food = await widget.api.createDietFood(
        name: name,
        calories: cal100,
        protein: p100,
        carbs: c100,
        fat: f100,
        photoMimeType: photoMime,
        photoBase64: photoB64,
      );
      if (widget.existingMeal != null) {
        await widget.api.addDietMealItems(
          mealId: widget.existingMeal!.id,
          items: [
            {'foodId': food.id, 'amount': w},
          ],
        );
      } else {
        await widget.api.createDietMeal(
          userId: widget.userId,
          date: widget.dateStr,
          mealType: widget.mealType,
          items: [
            {'foodId': food.id, 'amount': w},
          ],
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    '确认营养估算',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '将加入：$_mealTitle',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.memory(
                    widget.imageBytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '食物名称',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _weightCtrl,
                decoration: const InputDecoration(
                  labelText: '估算重量 (g)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _calCtrl,
                decoration: const InputDecoration(
                  labelText: '热量 (kcal) · 整份',
                  labelStyle: TextStyle(color: _kCalOrange, fontWeight: FontWeight.w600),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _kCalOrange,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pCtrl,
                      decoration: const InputDecoration(
                        labelText: '蛋白质 (g)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _cCtrl,
                      decoration: const InputDecoration(
                        labelText: '碳水 (g)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _fCtrl,
                      decoration: const InputDecoration(
                        labelText: '脂肪 (g)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '说明：保存时会按「每 100g」写入食物库，并用当前克数记入本餐。',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: kDietPrimary),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black87,
                            ),
                          )
                        : const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DottedBorderContainer extends StatelessWidget {
  const DottedBorderContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
          style: BorderStyle.solid,
          width: 1.2,
        ),
        color: Colors.white.withOpacity(0.6),
      ),
      child: child,
    );
  }
}


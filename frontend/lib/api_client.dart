import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Minimal API client for the backend.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.requestTimeout = const Duration(seconds: 20),
  });

  /// Base URL of the backend, e.g.:
  /// - Android emulator: http://10.0.2.2:8080
  /// - iOS simulator: http://localhost:8080
  final String baseUrl;

  /// 避免后端未启动时请求一直挂起（登录按钮无限转圈）。
  final Duration requestTimeout;

  String? _token;

  Future<void> _debugLog({
    required String runId,
    required String hypothesisId,
    required String location,
    required String message,
    required Map<String, dynamic> data,
  }) async {
    try {
      await http
          .post(
            Uri.parse('http://127.0.0.1:7864/ingest/3f447c3b-a637-439a-bf29-7c7ba235083f'),
            headers: {
              'Content-Type': 'application/json',
              'X-Debug-Session-Id': '1c4714',
            },
            body: jsonEncode({
              'sessionId': '1c4714',
              'runId': runId,
              'hypothesisId': hypothesisId,
              'location': location,
              'message': message,
              'data': data,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<http.Response> _timed(Future<http.Response> request) async {
    try {
      return await request.timeout(requestTimeout);
    } on TimeoutException {
      throw Exception(
        '连接超时（${requestTimeout.inSeconds} 秒）请确认后端已在 $baseUrl 启动 '
        '（例如先运行 start-all.bat，并等到控制台出现 Started）',
      );
    } on http.ClientException catch (e) {
      throw Exception('无法连接服务器 $baseUrl：${e.message}');
    }
  }

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> _headers({bool withAuth = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (withAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/api/auth/login');
    final resp = await _timed(
      http.post(
        uri,
        headers: _headers(),
        body: jsonEncode({'email': email, 'password': password}),
      ),
    );
    if (resp.statusCode == 401) {
      throw Exception('邮箱或密码错误');
    }
    if (resp.statusCode != 200) {
      throw Exception('登录失败: ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final token = data['token'] as String;
    _token = token;
    return token;
  }

  Future<String> register({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/api/auth/register');
    final resp = await _timed(
      http.post(
        uri,
        headers: _headers(),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ),
    );
    if (resp.statusCode == 400 || resp.statusCode == 409) {
      throw Exception('注册失败: 邮箱可能已被使用或数据不合法');
    }
    if (resp.statusCode != 201) {
      throw Exception('注册失败: ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final token = data['token'] as String;
    _token = token;
    return token;
  }

  Future<List<Map<String, dynamic>>> fetchExercises({
    required String muscleGroup,
    String? keyword,
  }) async {
    final queryParameters = <String, String>{
      'muscleGroup': muscleGroup,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
    };
    final uri =
        Uri.parse('$baseUrl/api/exercises').replace(queryParameters: queryParameters);

    final resp = await http.get(uri, headers: _headers());
    if (resp.statusCode != 200) {
      throw Exception('获取动作列表失败: ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as List;
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createExercise({
    required String name,
    required String primaryMuscle,
    String? description,
    String? imageUrl,
    String? equipmentType,
  }) async {
    final uri = Uri.parse('$baseUrl/api/exercises');
    final resp = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'primaryMuscle': primaryMuscle,
        'description': description,
        'imageUrl': imageUrl,
        'equipmentType': equipmentType,
      }),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('创建动作失败: ${resp.statusCode}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Stream<String> aiCoachChatStream({
    required int memoryId,
    required String message,
  }) async* {
    const aiCoachFirstChunkTimeout = Duration(seconds: 75);
    final uri = Uri.parse('$baseUrl/api/aigymhelper/chat').replace(
      queryParameters: {
        'memoryId': '$memoryId',
        'message': message,
      },
    );
    final client = http.Client();
    try {
      final request = http.Request('GET', uri)
        ..headers.addAll(_headers(withAuth: _token != null))
        ..headers['Accept'] = 'text/event-stream';
      request.headers.remove('Content-Type');
      // #region agent log
      unawaited(_debugLog(
        runId: 'post-fix',
        hypothesisId: 'H6',
        location: 'api_client.dart:185',
        message: 'ai chat request sending',
        data: {
          'memoryId': memoryId,
          'messageLength': message.length,
          'timeoutSeconds': aiCoachFirstChunkTimeout.inSeconds,
          'baseUrl': baseUrl,
        },
      ));
      // #endregion

      final response = await client
          .send(request)
          .timeout(aiCoachFirstChunkTimeout);
      // #region agent log
      unawaited(_debugLog(
        runId: 'post-fix',
        hypothesisId: 'H7',
        location: 'api_client.dart:199',
        message: 'ai chat response headers received',
        data: {
          'statusCode': response.statusCode,
          'contentType': response.headers['content-type'] ?? '',
        },
      ));
      // #endregion
      if (response.statusCode != 200) {
        throw Exception('智能教练请求失败: ${response.statusCode}');
      }

      var chunkCount = 0;
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final chunk = line.substring(5).trimLeft();
        if (chunk.isEmpty) continue;
        chunkCount++;
        if (chunkCount <= 3) {
          // #region agent log
          unawaited(_debugLog(
            runId: 'post-fix',
            hypothesisId: 'H8',
            location: 'api_client.dart:223',
            message: 'ai chat chunk parsed',
            data: {
              'chunkCount': chunkCount,
              'chunkLength': chunk.length,
            },
          ));
          // #endregion
        }
        yield chunk;
      }
    } on TimeoutException {
      // #region agent log
      unawaited(_debugLog(
        runId: 'post-fix',
        hypothesisId: 'H9',
        location: 'api_client.dart:238',
        message: 'ai chat timeout',
        data: {
          'timeoutSeconds': aiCoachFirstChunkTimeout.inSeconds,
        },
      ));
      // #endregion
      throw Exception(
        '智能教练响应超时（${aiCoachFirstChunkTimeout.inSeconds} 秒），请检查后端服务状态',
      );
    } on http.ClientException catch (e) {
      // #region agent log
      unawaited(_debugLog(
        runId: 'post-fix',
        hypothesisId: 'H10',
        location: 'api_client.dart:250',
        message: 'ai chat client exception',
        data: {'error': e.message},
      ));
      // #endregion
      throw Exception('智能教练连接失败：${e.message}');
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> startWorkoutSession({
    required int userId,
    required String title,
  }) async {
    final uri = Uri.parse('$baseUrl/api/workouts/sessions?userId=$userId');
    final resp = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'title': title}),
    );
    if (resp.statusCode != 200) {
      throw Exception('开始训练失败: ${resp.statusCode}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<WorkoutSessionLite?> fetchUnfinishedWorkoutSession({
    required int userId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/workouts/sessions/unfinished')
        .replace(queryParameters: {'userId': '$userId'});
    final resp = await http.get(uri, headers: _headers());
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) {
      throw Exception('获取未完成训练失败: ${resp.statusCode}');
    }
    return WorkoutSessionLite.fromJson(
      jsonDecode(resp.body) as Map<String, dynamic>,
    );
  }

  Future<void> saveWorkoutSessionProgress({
    required int sessionId,
    required String title,
    required int elapsedSeconds,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final uri = Uri.parse('$baseUrl/api/workouts/sessions/$sessionId/progress');
    final resp = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'title': title,
        'elapsedSeconds': elapsedSeconds,
        'exercises': exercises,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('保存训练进度失败: ${resp.statusCode}');
    }
  }

  Future<Map<String, dynamic>> finishWorkoutSession({
    required int sessionId,
    required bool completed,
    required double totalVolumeKg,
    required double estimatedCalories,
    required String title,
    required int elapsedSeconds,
    List<Map<String, dynamic>>? exercises,
  }) async {
    final uri = Uri.parse('$baseUrl/api/workouts/sessions/$sessionId/finish');
    final resp = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'completed': completed,
        'title': title,
        'elapsedSeconds': elapsedSeconds,
        'totalVolumeKg': totalVolumeKg,
        'estimatedCalories': estimatedCalories,
        if (exercises != null) 'exercises': exercises,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('结束训练失败: ${resp.statusCode}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// 获取统计概览：指定时间范围内的训练次数、总重量、预估卡路里、体重记录。
  /// [from]/[to] 格式：yyyy-MM-dd
  Future<StatsOverview> fetchStatsOverview({
    required int userId,
    required String from,
    required String to,
  }) async {
    final uri = Uri.parse('$baseUrl/api/stats/overview')
        .replace(queryParameters: {'userId': '$userId', 'from': from, 'to': to});
    final resp = await http.get(uri, headers: _headers());
    if (resp.statusCode != 200) {
      throw Exception('获取统计失败: ${resp.statusCode}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return StatsOverview.fromJson(data);
  }

  // ---------- 饮食 ----------
  /// 食物列表（用于选择/搜索）
  Future<List<DietFood>> listDietFoods() async {
    final uri = Uri.parse('$baseUrl/api/diet/foods');
    final resp = await http.get(uri, headers: _headers());
    if (resp.statusCode != 200) throw Exception('获取食物列表失败: ${resp.statusCode}');
    final data = jsonDecode(resp.body) as List;
    return data.map((e) => DietFood.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 新增食物（每100g营养）
  Future<DietFood> createDietFood({
    required String name,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    String? photoMimeType,
    String? photoBase64,
  }) async {
    final uri = Uri.parse('$baseUrl/api/diet/foods');
    final body = <String, dynamic>{
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
    if (photoMimeType != null) body['photoMimeType'] = photoMimeType;
    if (photoBase64 != null) body['photoBase64'] = photoBase64;
    final resp = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('创建食物失败: ${resp.statusCode}');
    }
    return DietFood.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// 修改食物（每100g营养）
  Future<DietFood> updateDietFood(
    int foodId, {
    required String name,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
  }) async {
    final uri = Uri.parse('$baseUrl/api/diet/foods/$foodId');
    final resp = await http.put(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      }),
    );
    if (resp.statusCode != 200) throw Exception('修改食物失败: ${resp.statusCode}');
    return DietFood.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// 删除食物（会同时删除所有餐次中引用该食物的记录）
  Future<void> deleteDietFood(int foodId) async {
    final uri = Uri.parse('$baseUrl/api/diet/foods/$foodId');
    final resp = await http.delete(uri, headers: _headers());
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('删除食物失败: ${resp.statusCode}');
    }
  }

  /// 某日期范围内的餐次（含 items）
  Future<List<DietMeal>> listDietMeals({
    required int userId,
    required String from,
    required String to,
  }) async {
    final uri = Uri.parse('$baseUrl/api/diet/meals')
        .replace(queryParameters: {'userId': '$userId', 'from': from, 'to': to});
    final resp = await http.get(uri, headers: _headers());
    if (resp.statusCode != 200) throw Exception('获取饮食记录失败: ${resp.statusCode}');
    final data = jsonDecode(resp.body) as List;
    return data.map((e) => DietMeal.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 新建一餐（可多品项）
  Future<DietMeal> createDietMeal({
    required int userId,
    required String date,
    required String mealType,
    required List<Map<String, dynamic>> items,
  }) async {
    final uri = Uri.parse('$baseUrl/api/diet/meals?userId=$userId');
    final resp = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'date': date,
        'mealType': mealType,
        'items': items,
      }),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('保存餐次失败: ${resp.statusCode}');
    }
    return DietMeal.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// 向已有餐次追加食物
  Future<DietMeal> addDietMealItems({
    required int mealId,
    required List<Map<String, dynamic>> items,
  }) async {
    final uri = Uri.parse('$baseUrl/api/diet/meals/$mealId/items');
    final resp = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(items),
    );
    if (resp.statusCode != 200) throw Exception('添加食物失败: ${resp.statusCode}');
    return DietMeal.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  /// 删除餐次中的某一食物项
  Future<void> deleteDietMealItem(int mealFoodId) async {
    final uri = Uri.parse('$baseUrl/api/diet/meals/items/$mealFoodId');
    final resp = await http.delete(uri, headers: _headers());
    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw Exception('删除失败: ${resp.statusCode}');
    }
  }

  /// 修改餐次中某一食物项（克数或替换食物）
  Future<DietMealItem> updateDietMealItem(
    int mealFoodId, {
    double? amount,
    int? foodId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/diet/meals/items/$mealFoodId');
    final body = <String, dynamic>{};
    if (amount != null) body['amount'] = amount;
    if (foodId != null) body['foodId'] = foodId;
    final resp = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200) throw Exception('修改失败: ${resp.statusCode}');
    return DietMealItem.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }
}

class WorkoutSessionLite {
  WorkoutSessionLite({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.elapsedSeconds,
    this.exercises = const [],
  });

  final int id;
  final String title;
  final DateTime startedAt;
  final int elapsedSeconds;
  final List<WorkoutSessionExerciseLite> exercises;

  static WorkoutSessionLite fromJson(Map<String, dynamic> json) {
    final exercisesJson = json['exercises'] as List? ?? [];
    final exercises = exercisesJson
        .map((e) => WorkoutSessionExerciseLite.fromJson(e as Map<String, dynamic>))
        .toList();
    return WorkoutSessionLite(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      startedAt: DateTime.parse(json['startedAt'] as String),
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      exercises: exercises,
    );
  }
}

class WorkoutSessionExerciseLite {
  WorkoutSessionExerciseLite({
    required this.name,
    required this.sets,
  });

  final String name;
  final List<WorkoutSessionSetLite> sets;

  static WorkoutSessionExerciseLite fromJson(Map<String, dynamic> json) {
    final setsJson = json['sets'] as List? ?? [];
    final sets = setsJson
        .map((s) => WorkoutSessionSetLite.fromJson(s as Map<String, dynamic>))
        .toList();
    return WorkoutSessionExerciseLite(
      name: json['name'] as String? ?? '',
      sets: sets,
    );
  }
}

class WorkoutSessionSetLite {
  WorkoutSessionSetLite({
    required this.setIndex,
    required this.weightKg,
    required this.reps,
    required this.completed,
    this.restSeconds,
  });

  final int setIndex;
  final double weightKg;
  final int reps;
  final bool completed;
  final int? restSeconds;

  static WorkoutSessionSetLite fromJson(Map<String, dynamic> json) {
    return WorkoutSessionSetLite(
      setIndex: (json['setIndex'] as num?)?.toInt() ?? 0,
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0.0,
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as bool?) ?? false,
      restSeconds: (json['restSeconds'] as num?)?.toInt(),
    );
  }
}

/// 统计概览（与后端 /api/stats/overview 返回结构对应）
class StatsOverview {
  StatsOverview({
    required this.totalWorkouts,
    required this.totalVolumeKg,
    required this.totalCalories,
    required this.weightByDate,
  });

  final int totalWorkouts;
  final double totalVolumeKg;
  final double totalCalories;
  /// 日期 -> 该日体重(kg)，多条记录时取平均
  final Map<String, double> weightByDate;

  static StatsOverview fromJson(Map<String, dynamic> json) {
    final weightStats = json['weightStatsByDate'] as Map<String, dynamic>? ?? {};
    final weightByDate = <String, double>{};
    for (final e in weightStats.entries) {
      final date = e.key;
      final stats = e.value as Map<String, dynamic>;
      final avg = stats['average'] as num?;
      weightByDate[date] = avg?.toDouble() ?? 0;
    }
    return StatsOverview(
      totalWorkouts: (json['totalWorkouts'] as num?)?.toInt() ?? 0,
      totalVolumeKg: (json['totalVolumeKg'] as num?)?.toDouble() ?? 0,
      totalCalories: (json['totalCalories'] as num?)?.toDouble() ?? 0,
      weightByDate: weightByDate,
    );
  }
}

// ---------- 饮食模型 ----------
class DietFood {
  DietFood({
    required this.id,
    required this.name,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.photoMimeType,
    this.photoBase64,
  });
  final int id;
  final String name;
  final int? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final String? photoMimeType;
  final String? photoBase64;
  static DietFood fromJson(Map<String, dynamic> json) {
    return DietFood(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      calories: (json['calories'] as num?)?.toInt(),
      protein: (json['protein'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      photoMimeType: json['photoMimeType'] as String?,
      photoBase64: json['photoBase64'] as String?,
    );
  }
}

class DietMealItem {
  DietMealItem({this.id, required this.food, required this.amount});
  /// 后端 meal_foods 表主键，用于修改/删除
  final int? id;
  final DietFood food;
  final double amount;
  int get calories => ((food.calories ?? 0) * amount / 100).round();
  double get proteinG => (food.protein ?? 0) * amount / 100;
  double get carbsG => (food.carbs ?? 0) * amount / 100;
  double get fatG => (food.fat ?? 0) * amount / 100;
  static DietMealItem fromJson(Map<String, dynamic> json) {
    final foodJson = json['food'] as Map<String, dynamic>?;
    return DietMealItem(
      id: (json['id'] as num?)?.toInt(),
      food: foodJson != null ? DietFood.fromJson(foodJson) : DietFood(id: 0, name: '?'),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DietMeal {
  DietMeal({
    required this.id,
    required this.date,
    required this.mealType,
    required this.items,
  });
  final int id;
  final String date;
  final String mealType;
  final List<DietMealItem> items;
  int get totalCalories => items.fold(0, (s, i) => s + i.calories);
  double get totalProtein => items.fold(0.0, (s, i) => s + i.proteinG);
  double get totalCarbs => items.fold(0.0, (s, i) => s + i.carbsG);
  double get totalFat => items.fold(0.0, (s, i) => s + i.fatG);
  static DietMeal fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List? ?? [];
    return DietMeal(
      id: (json['id'] as num).toInt(),
      date: json['date'] as String? ?? '',
      mealType: json['mealType'] as String? ?? 'breakfast',
      items: itemsList.map((e) => DietMealItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}


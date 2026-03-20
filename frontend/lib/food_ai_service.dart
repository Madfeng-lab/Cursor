import 'dart:convert';

import 'package:http/http.dart' as http;

/// AI 识餐结果（对应模型返回的整份食物营养，非「每 100g」）。
class FoodAiResult {
  const FoodAiResult({
    required this.foodName,
    required this.estimatedWeightG,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final String foodName;
  /// 模型估算的食用重量（克）
  final double estimatedWeightG;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  /// 转为后端 `createDietFood` 所需的「每 100g」营养（按估算重量反推）。
  ({int calories, double protein, double carbs, double fat}) toPer100g() {
    final w = estimatedWeightG <= 0 ? 100.0 : estimatedWeightG;
    final factor = 100.0 / w;
    return (
      calories: (calories * factor).round().clamp(0, 100000),
      protein: (protein * factor).clamp(0, 10000),
      carbs: (carbs * factor).clamp(0, 10000),
      fat: (fat * factor).clamp(0, 10000),
    );
  }
}

/// 调用后端代理的多模态识餐接口（不在此传递任何第三方 Key）。
///
/// 前端仅 `POST` 至 `{backendBaseUrl}/api/ai/food/analyze`；
/// 由后端 `FoodAiArkService` 调用火山方舟 **`POST .../responses`**
///（`input` + `input_image` + `input_text`，与控制台「快捷 API」一致）。
///
/// 方舟 API Key / 模型等只在后端通过环境变量配置，参见
/// `docs/AI餐食识别与热量估算-开发流程.md`。
class FoodAiService {
  FoodAiService({required String backendBaseUrl})
      : _backendBaseUrl = backendBaseUrl.trim();

  final String _backendBaseUrl;

  /// [imageBytes] 图片二进制；[mimeType] 如 image/jpeg、image/png。
  ///
  /// 注意：此处不再把方舟 API Key 暴露在前端，而是把图片发给后端，
  /// 由后端去调用火山方舟 OpenAI 兼容接口。
  Future<FoodAiResult> analyzeFood({
    required List<int> imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    final base = _backendBaseUrl.endsWith('/')
        ? _backendBaseUrl.substring(0, _backendBaseUrl.length - 1)
        : _backendBaseUrl;

    final uri = Uri.parse('$base/api/ai/food/analyze');
    final base64 = base64Encode(imageBytes);

    http.Response resp;
    try {
      resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'imageBase64': base64,
              'mimeType': mimeType,
            }),
          )
          .timeout(const Duration(seconds: 120));
    } catch (e) {
      throw FoodAiException('网络请求失败，请检查网络后重试。$e');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw FoodAiException(
        'AI 服务返回错误 (${resp.statusCode})：'
        '${resp.body.length > 300 ? resp.body.substring(0, 300) + '…' : resp.body}',
      );
    }

    Map<String, dynamic> jsonRoot;
    try {
      jsonRoot = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw FoodAiException('AI 响应不是合法 JSON：$e');
    }

    final name = (jsonRoot['foodName'] ?? jsonRoot['food_name'])
        ?.toString()
        .trim();
    if (name == null || name.isEmpty) {
      throw FoodAiException('AI 未能识别食物名称，请换一张清晰照片重试');
    }

    final weight = _toDouble(jsonRoot['estimatedWeightG'] ?? jsonRoot['weight_g']);
    final calories = _toInt(jsonRoot['calories']);
    final protein = _toDouble(jsonRoot['protein']);
    final carbs = _toDouble(jsonRoot['carbs']);
    final fat = _toDouble(jsonRoot['fat']);

    return FoodAiResult(
      foodName: name,
      estimatedWeightG: weight <= 0 ? 100 : weight,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

class FoodAiException implements Exception {
  FoodAiException(this.message);
  final String message;

  @override
  String toString() => message;
}

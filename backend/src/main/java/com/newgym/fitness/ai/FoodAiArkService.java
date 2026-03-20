package com.newgym.fitness.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.newgym.fitness.ai.dto.AnalyzeFoodRequest;
import com.newgym.fitness.ai.dto.AnalyzeFoodResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 后端代调用火山方舟多模态接口。
 * <p>
 * Doubao-Seed 等在控制台「快捷 API」里使用 {@code POST /api/v3/responses}，
 * 请求体为 {@code input} 数组，图片块类型为 {@code input_image}，文本为 {@code input_text}
 * （与 {@code /chat/completions} + {@code messages} 的旧格式不同）。
 * </p>
 */
@Service
@RequiredArgsConstructor
public class FoodAiArkService {

    private final ObjectMapper objectMapper;

    @Value("${ai.ark.api-key:}")
    private String apiKey;

    @Value("${ai.ark.base-url:https://ark.cn-beijing.volces.com/api/v3}")
    private String baseUrl;

    @Value("${ai.ark.model:}")
    private String model;

    private static final String SYSTEM_PROMPT = """
            你是一位资深的营养师。请识别图片中的食物，估算其重量（克），并给出该份食物的总热量（kcal）、蛋白质、碳水化合物和脂肪的数值（均为整份食物，不是每100g）。
            请**仅**输出一个 JSON 对象，不要 markdown 代码块，不要其他说明文字。
            格式严格如下（数值用数字）：
            {"food_name": "...", "weight_g": 0, "calories": 0, "protein": 0, "carbs": 0, "fat": 0}
            """;

    public AnalyzeFoodResponse analyze(AnalyzeFoodRequest request) {
        if (apiKey == null || apiKey.trim().isEmpty()) {
            throw new FoodAiException("未配置 ai.ark.api-key");
        }
        if (model == null || model.trim().isEmpty()) {
            throw new FoodAiException("未配置 ai.ark.model（推理接入点 ID，如 ep-xxxx）");
        }

        String mimeType = (request.mimeType() == null || request.mimeType().isBlank())
                ? "image/jpeg"
                : request.mimeType().trim();
        String dataUrl = "data:" + mimeType + ";base64," + request.imageBase64();

        String normalizedBase = baseUrl == null ? "" : baseUrl.trim();
        while (normalizedBase.endsWith("/")) {
            normalizedBase = normalizedBase.substring(0, normalizedBase.length() - 1);
        }

        // 与控制台「快捷 API」一致：Responses API，非 chat/completions
        String endpoint = normalizedBase + "/responses";

        String userText = SYSTEM_PROMPT + "\n请分析这张餐食照片，按上文要求的 JSON 格式返回。";

        Map<String, Object> body = Map.of(
                "model", model.trim(),
                "input", List.of(
                        Map.of(
                                "role", "user",
                                "content", List.of(
                                        Map.of(
                                                "type", "input_image",
                                                "image_url", dataUrl
                                        ),
                                        Map.of(
                                                "type", "input_text",
                                                "text", userText
                                        )
                                )
                        )
                )
        );

        String json = writeJson(body);

        HttpClient client = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(20))
                .build();

        HttpRequest httpRequest = HttpRequest.newBuilder()
                .uri(URI.create(endpoint))
                .header("Content-Type", "application/json")
                .header("Authorization", "Bearer " + apiKey)
                .timeout(Duration.ofSeconds(120))
                .POST(HttpRequest.BodyPublishers.ofString(json))
                .build();

        HttpResponse<String> resp;
        try {
            resp = client.send(httpRequest, HttpResponse.BodyHandlers.ofString());
        } catch (Exception e) {
            throw new FoodAiException("AI 请求失败：" + e.getMessage());
        }

        if (resp.statusCode() < 200 || resp.statusCode() >= 300) {
            String detail = resp.body();
            if (detail != null && detail.length() > 500) detail = detail.substring(0, 500) + "...";
            throw new FoodAiException("AI 返回错误（" + resp.statusCode() + "）：" + detail);
        }

        JsonNode root;
        try {
            root = objectMapper.readTree(resp.body());
        } catch (Exception e) {
            throw new FoodAiException("AI 响应不是合法 JSON：" + e.getMessage());
        }

        String content = extractModelTextFromArkResponse(root);
        String extractedJson = extractJsonObject(content);

        JsonNode result;
        try {
            result = objectMapper.readTree(extractedJson);
        } catch (Exception e) {
            throw new FoodAiException("无法解析 AI 返回的 JSON：" + e.getMessage());
        }

        String foodName = result.path("food_name").asText(null);
        if (foodName == null || foodName.isBlank()) {
            throw new FoodAiException("AI 未能识别食物名称");
        }

        double weightG = result.path("weight_g").asDouble(0);
        if (weightG <= 0) weightG = 100;

        int calories = result.path("calories").asInt(0);
        double protein = result.path("protein").asDouble(0);
        double carbs = result.path("carbs").asDouble(0);
        double fat = result.path("fat").asDouble(0);

        return new AnalyzeFoodResponse(
                foodName.trim(),
                weightG,
                calories,
                protein,
                carbs,
                fat
        );
    }

    private String writeJson(Map<String, Object> body) {
        try {
            return objectMapper.writeValueAsString(body);
        } catch (Exception e) {
            throw new FoodAiException("序列化请求失败：" + e.getMessage());
        }
    }

    /**
     * Responses API：根字段 {@code output} 为数组，其中 {@code type:"message"} 的项里
     * {@code content[]} 含 {@code type:"output_text"} 或带 {@code text} 的块。
     * 兼容 chat/completions：{@code choices[0].message.content}。
     */
    private String extractModelTextFromArkResponse(JsonNode root) {
        JsonNode output = root.path("output");
        if (output.isArray() && !output.isEmpty()) {
            for (int i = output.size() - 1; i >= 0; i--) {
                JsonNode item = output.get(i);
                if (!"message".equals(item.path("type").asText())) {
                    continue;
                }
                JsonNode parts = item.path("content");
                if (!parts.isArray()) {
                    continue;
                }
                StringBuilder acc = new StringBuilder();
                for (JsonNode part : parts) {
                    String t = part.path("text").asText("");
                    if (t != null && !t.isBlank()) {
                        if (acc.length() > 0) {
                            acc.append('\n');
                        }
                        acc.append(t.trim());
                    }
                }
                if (acc.length() > 0) {
                    return acc.toString();
                }
            }
        }

        JsonNode choices = root.path("choices");
        if (choices.isArray() && !choices.isEmpty()) {
            JsonNode contentNode = choices.get(0).path("message").path("content");
            if (contentNode.isTextual()) {
                return contentNode.asText("");
            }
            if (contentNode.isArray()) {
                StringBuilder acc = new StringBuilder();
                for (JsonNode part : contentNode) {
                    if ("text".equals(part.path("type").asText())) {
                        String t = part.path("text").asText("");
                        if (t != null && !t.isBlank()) {
                            if (acc.length() > 0) {
                                acc.append('\n');
                            }
                            acc.append(t.trim());
                        }
                    }
                }
                if (acc.length() > 0) {
                    return acc.toString();
                }
            }
        }

        throw new FoodAiException("AI 响应中未找到模型文本（既无 output.message.content，也无 choices）");
    }

    private String extractJsonObject(String raw) {
        if (raw == null) {
            throw new FoodAiException("AI 返回内容为空");
        }
        String s = raw.trim();

        // 去掉可能的 ```json ... ```
        Pattern fence = Pattern.compile("```(?:json)?\\s*([\\s\\S]*?)```", Pattern.MULTILINE);
        Matcher m = fence.matcher(s);
        if (m.find()) {
            s = m.group(1).trim();
        }

        int start = s.indexOf('{');
        int end = s.lastIndexOf('}');
        if (start < 0 || end <= start) {
            throw new FoodAiException("无法从 AI 回复中提取 JSON");
        }
        return s.substring(start, end + 1);
    }
}


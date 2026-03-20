# AI 餐食识别与自动估算热量 — 开发流程说明

本文档总结本项目中「拍照 / 选图 → 多模态模型识餐 → 估算热量与营养素 → 用户确认 → 写入饮食记录」的**架构、模块、配置与迭代流程**，便于后续维护与扩展。

---

## 1. 功能与目标

| 能力 | 说明 |
|------|------|
| 输入 | 手机相机或相册中的一张餐食照片 |
| 模型 | 火山引擎**火山方舟**多模态模型（如 Doubao-Seed-2.0-pro 等，以控制台为准） |
| 输出 | 食物名称、估算重量（g）、整份热量（kcal）及蛋白质 / 碳水 / 脂肪 |
| 产品形态 | 饮食页提供入口 → 识别中 Loading → 结果弹窗可编辑 → 确认后按现有业务写入后端 |

**注意**：模型输出为估计值，仅作记录辅助，产品侧已通过「可编辑确认」降低误识别影响。

---

## 2. 总体架构（为何采用「后端代调用」）

```
Flutter App                         Spring Boot                         火山方舟 Ark
───────────                         ───────────                         ──────────────
diet_page + image_picker
      │
      ▼ Base64 + mimeType
POST /api/ai/food/analyze  ───────►  FoodAiController
                                         │
                                         ▼
                                    FoodAiArkService
                                         │
                                         ▼
                              POST {base-url}/responses
                              (input + input_image + input_text)
```

**设计要点**：

- **API Key 仅在后端**：通过环境变量注入，不进入前端包、不提交 Git。
- **统一网关与协议变更**：方舟侧若从 OpenAI 兼容形态调整为 **Responses API**（`input` / `input_image` / `input_text`），只需改 `FoodAiArkService`，App 仍只对接自家 `/api/ai/food/analyze`。
- **超时与错误**：后端可统一日志与脱敏；前端展示友好错误（`FoodAiException`）。

---

## 3. 端到端业务流程（开发视角）

1. **入口（Flutter `diet_page.dart`）**  
   - 用户选择餐次 → 点击 AI 相关入口 → `image_picker` 拍照或选图 → 得到 `imageBytes` + 推断的 `mimeType`。

2. **调用自家后端（`FoodAiService`）**  
   - `POST {ApiClient.baseUrl}/api/ai/food/analyze`  
   - Body：`{ "imageBase64": "<base64>", "mimeType": "image/jpeg" | "image/png" | ... }`

3. **后端代理（`FoodAiArkService`）**  
   - 将 Base64 拼成 `data:{mime};base64,{...}`，作为 `input_image.image_url`。  
   - 调用方舟 **`POST {ai.ark.base-url}/responses`**（注意：不是旧的 `/chat/completions` 多模态拼法）。  
   - 请求体结构与控制台「快捷 API」一致：`model` + `input[]` → `content[]` 含 `input_image` 与 `input_text`。  
   - 提示词要求模型**仅返回**约定 JSON（见下文协议）。

4. **解析模型回复**  
   - Responses 接口返回体中含 `output` 数组等结构；服务内从 `output` 中提取文本，再截取 JSON 对象。  
   - 兼容：若将来某些环境仍返回类 `choices` 结构，代码中可保留兜底解析（以当前 `FoodAiArkService` 实现为准）。

5. **返回前端并展示**  
   - 后端返回 `AnalyzeFoodResponse`（Jackson 序列化为 camelCase）。  
   - 前端映射为 `FoodAiResult`，弹出确认框（可改名称、热量等），确认后调用现有饮食保存接口（将「整份」折算为「每 100g」等逻辑在 `FoodAiResult.toPer100g()`）。

---

## 4. 关键代码与文件清单

| 层级 | 路径 | 职责 |
|------|------|------|
| 前端 UI / 流程 | `frontend/lib/diet_page.dart` | 选图、`FoodAiService` 调用、Loading、确认弹窗、错误提示 |
| 前端 HTTP | `frontend/lib/food_ai_service.dart` | `POST /api/ai/food/analyze`、JSON → `FoodAiResult` |
| 后端接口 | `backend/.../ai/FoodAiController.java` | 暴露 `POST /api/ai/food/analyze` |
| 后端 DTO | `backend/.../ai/dto/AnalyzeFoodRequest.java` | `imageBase64`, `mimeType` |
| 后端 DTO | `backend/.../ai/dto/AnalyzeFoodResponse.java` | `foodName`, `estimatedWeightG`, `calories`, `protein`, `carbs`, `fat` |
| 方舟调用 | `backend/.../ai/FoodAiArkService.java` | 构造 `/responses` 请求、解析、转 DTO |
| 异常 | `backend/.../ai/FoodAiException.java` | 业务层抛出，可由全局异常处理统一转 HTTP（若已配置） |
| 依赖 | `frontend/pubspec.yaml` | `http`、`image_picker` |
| 权限 | `frontend/android/.../AndroidManifest.xml`、`ios/Runner/Info.plist` | 相机 / 相册相关权限与说明文案 |

---

## 5. 数据协议

### 5.1 App → 后端 `AnalyzeFoodRequest`

```json
{
  "imageBase64": "<不含 data: 前缀的 Base64>",
  "mimeType": "image/jpeg"
}
```

### 5.2 模型被要求返回的 JSON（后端提示词约束）

模型输出（经截取后）应可被解析为：

```json
{
  "food_name": "字符串",
  "weight_g": 0,
  "calories": 0,
  "protein": 0,
  "carbs": 0,
  "fat": 0
}
```

含义：**整份食物**的重量与营养素，不是每 100g。

### 5.3 后端 → App `AnalyzeFoodResponse`（JSON 字段名 camelCase）

- `foodName`  
- `estimatedWeightG`  
- `calories`, `protein`, `carbs`, `fat`  

前端 `FoodAiService` 同时兼容 snake_case 键（如 `food_name` / `weight_g`）以增强健壮性。

---

## 6. 配置项（火山方舟）

### 6.1 Spring 配置（`application.yml` / 环境变量）

| 配置项 | 环境变量 | 说明 |
|--------|-----------|------|
| `ai.ark.api-key` | `FOOD_AI_API_KEY` | 方舟控制台创建的 API Key |
| `ai.ark.base-url` | `FOOD_AI_BASE_URL` | 一般为 `https://ark.cn-beijing.volces.com/api/v3`（地域以控制台为准） |
| `ai.ark.model` | `FOOD_AI_MODEL` | 控制台展示的**模型 ID**（如 `doubao-seed-2-0-pro-260215`）或自建**推理接入点** `ep-xxxx`，以实际可用为准 |

**不要将真实 Key 写入仓库默认值**；生产环境仅用环境变量或密钥管理注入。

### 6.2 控制台侧你需要完成的步骤

1. 开通方舟、创建 **API Key**。  
2. 选用支持**图片理解**的模型（如 Doubao-Seed-2.0-pro）。  
3. 在「快捷 API」中确认调用方式为 **`POST .../api/v3/responses`**，并对照请求体字段（`input` / `input_image` / `input_text`）。  
4. 将上述 Key、base-url、model 配到运行环境（本地 IDE、服务器 `systemd`/`start.sh`、Docker 等）。

部署脚本示例可参考仓库根目录 `deploy.sh` 中向 `java -jar` 传递 `FOOD_AI_*` 环境变量的写法。

---

## 7. 本地开发建议流程

1. **后端**：配置 `FOOD_AI_API_KEY`、`FOOD_AI_MODEL`，可选 `FOOD_AI_BASE_URL`；启动 Spring Boot（如 `8080`）。  
2. **前端**：`ApiClient.baseUrl` 指向该后端（本地调试常用 `http://localhost:8080`；真机注意局域网 IP）。  
3. **验证**：  
   - 先 `POST /api/ai/food/analyze`（Swagger 或 curl）用一张小图测通；  
   - 再在 App 饮食页走完整拍照流程。  
4. **联调日志**：关注后端 Ark HTTP 状态码与返回体；若方舟报 `InvalidParameter`，对照控制台最新示例检查 `model` 与 body 是否一致。

---

## 8. 部署与运维要点

- **环境变量**：与本地一致，确保进程可见 `FOOD_AI_*`。  
- **超时**：识图可能较慢，前端 HTTP 已设较长超时；后端 `HttpClient` 超时可随业务调整。  
- **安全**：`/api/ai/food/analyze` 若需登录，应在 `SecurityConfig` 中收紧（当前项目若仍为 `permitAll`，上线前请按产品要求改为需 JWT）。  
- **图片大小**：过大 Base64 会增加内存与网关限制；必要时可在后端或前端先做压缩（迭代项）。

---

## 9. 常见问题（排错）

| 现象 | 可能原因 | 方向 |
|------|----------|------|
| 400 `InvalidParameter` / MultiContent | 曾用错 `/chat/completions` 或 `messages` 与方舟不一致 | 已改为 `/responses` + `input_*`，对照控制台 |
| 只识别文字、不认图 | `FOOD_AI_MODEL` 非多模态接入点 / 模型选错 | 换视觉模型或正确 `ep-` |
| `image_url` 被拒 | 部分环境不接受 `data:` URL | 改为可访问的 `https` 图片或对接方舟 Files API（迭代） |
| 前端连不上分析接口 | `baseUrl`、反向代理、CORS、安全组 | 检查 Nginx 与 `ApiClient` |

---

## 10. 后续可扩展方向

- 结果缓存（相同图片哈希短期复用）。  
- 服务端图片压缩与大小校验。  
- 结构化输出（若方舟支持 JSON Schema / response_format）。  
- 将识餐结果与食物库 ID 绑定，提高记录一致性。  
- 鉴权：仅登录用户可调用 `/api/ai/food/analyze`，并做限流。

---

## 11. 参考链接（官方）

- [图片理解 - 火山方舟文档](https://www.volcengine.com/docs/82379/1362931)  
- [对话 / Responses 相关 API 参考](https://www.volcengine.com/docs/82379/1494384)  
- [Responses API 说明](https://www.volcengine.com/docs/82379/1585135)  

（具体字段以你控制台当前模型页的 **Rest API 示例** 为准。）

---

*文档版本：与仓库实现同步维护；修改 `FoodAiArkService` 或 API 路径时请同步更新本节。*

# API 直调参考（OpenAI 兼容协议）

服务端点：`https://jd.glowjames.top/v1/chat/completions`（POST）。

## 请求

```http
POST /v1/chat/completions HTTP/1.1
Content-Type: application/json
Authorization: Bearer <key>
```

```json
{
  "model": "jiaodui",
  "messages": [{ "role": "user", "content": "他慢慢的走了。" }],
  "stream": false
}
```

## 参数

- **`model`**：
  - `jiaodui`（默认）：结构化 JSON，`choices[0].message.content` 是
    `{"file": ..., "total": N, "items": [{"index","wrong","suggestion","type","offset"}]}` 字符串。
    其中 `index` 从 1 起；`offset` 是原文中的位置（按 Unicode 字符计，从 1 起）；
    `type` 是错误类别，取值 `general` / `grammar` / `typo` / `style` 等，可能省略。
  - `jiaodui-text`：可读文本报告，`content` 即报告文本本身（直接展示即可，无需二次解析）。
  - `jiaodui-json`：`jiaodui` 的别名。
  - 为空或未知时服务端一律按 `jiaodui`（结构化 JSON）处理。
- **`messages`**：数组。取**最后一个 `role=user`** 的消息作为待校对文本；没有则 400。
- **`stream`**：`true` 时 SSE（`text/event-stream`，`data:` JSON chunk + `data: [DONE]`）。

## 限制

| 项目 | 值 | 超限表现 |
|---|---|---|
| HTTP body | ≤ 1MB | 400（body_too_large） |
| 单次输入 | ≤ 40,000 字（按 Unicode 字符计，非字节） | 400（context_length_exceeded） |
| 限流（每 Key） | 每 2 秒 1 次（30 次/分钟），突发上限 4 | 429（rate_limit_exceeded），响应带 `Retry-After: 2` |
| Key 数量 | 每账户 1 个有效 Key，更换先吊销旧的再创建 | 创建时提示已达上限 |
| 超时 | 服务端约 30s | 504（timeout） |

## 错误格式

非 2xx 返回 OpenAI 风格错误体（`param` 仅在缺少 `messages` 时出现，其余为空省略）：

```json
{ "error": { "message": "...", "type": "...", "param": "messages", "code": "..." } }
```

常见：400（body 超 1MB、输入超 40,000 字或缺 `role=user` 消息）、401（缺/错 Key，`invalid_api_key`）、405（非 POST，`method_not_allowed`）、429（限流，`rate_limit_exceeded`，带 `Retry-After: 2`）、504（超时，`timeout`）。

## curl 示例

```bash
curl -s https://jd.glowjames.top/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JIAODUI_API_KEY" \
  -d '{"model":"jiaodui","messages":[{"role":"user","content":"他慢慢的走了。"}],"stream":false}' \
| python3 -m json.tool
```

调试可用 `scripts/beautare_client.py`（打印原始响应，支持 `--stream`）。

## 数据与隐私

- OpenAI 兼容接口（CLI / API / Skill / MCP 均走这条）不提供校对历史记录功能，但候选检查日志默认开启。
- 触发同音字等候选检查时，服务端会保存该次请求的完整输入原文、候选词和判定分数，用于改进校对准确率。日志以请求编号和文本哈希标识，未单独设置用户 ID、API Key 或邮箱字段，与账户信息位于同一数据库的不同表。原文本身可能包含个人信息，不会自动匿名化；不用于广告、营销或第三方共享。未触发候选检查的请求不会在该日志中留下原文。
- 删除账户不会自动删除候选检查日志中的原文。目前该日志没有自动到期删除机制，清理需由运营方手动执行。
- 提交敏感稿件前请阅读隐私政策，并根据用户的数据处理要求决定是否提交。不擅自替换姓名、地名或其他正文。
- 完整隐私口径见服务端<a href="https://jd.glowjames.top/privacy">隐私政策</a>。

## 结果怎么用

API 与 CLI 结构化结果按以下方式处理；MCP 返回可读文本，不保证提供 offset：

1. **给人看** → 用 `jiaodui-text`，`content` 就是报告文本，直接展示，不必二次解析。
2. **给程序用** → 用 `jiaodui`（默认）。`content` 是 JSON 字符串：

   ```json
   { "file": "", "total": 1,
     "items": [ { "index": 1, "wrong": "慢慢的走", "suggestion": "慢慢地走",
                  "type": "general", "offset": 2 } ] }
   ```

   - `index` 从 1 起；`type` 可能省略；`total` 为该次建议总数。
   - `offset` 是 `wrong` **首个字符在原文中的位置**（按 Unicode 字符计，从 1 起）。
     例：`他慢慢的走了。` 返回 `offset: 2`，对应第 2 个字符起的 `慢慢的走`。

3. **回写原文**（批量/管线场景）：

   - 用 `offset` 定位，**不要**用 `wrong` 做字符串搜索——同一串可能在原文多次出现，搜到的未必是这一处。
   - 同一次结果里有多条时，**从后往前**替换（先改 `offset` 大的），否则前面的替换会让后面所有 `offset` 失效。
   - 建议是**候选**不是判决：可以部分采纳；`wrong`/`suggestion` 为空或相等的条目跳过。
   - 若要精确定位替换范围，按字符（rune）切片而不是按字节，中文一个字算一个字符。


分块结果的 offset 相对于各块输入，映射到文件前须计入块起点。过滤代码等内容时保留位置映射。应用前核对定位处原文与 wrong 一致，跳过重叠或不匹配的建议，不做全局字符串替换。

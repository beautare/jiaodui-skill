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
  - `jiaodui-text`：可读文本报告，`content` 即报告原文。
  - `jiaodui-json`：`jiaodui` 的别名。
  - 为空或未知时服务端一律按 `jiaodui`（结构化 JSON）处理。
- **`messages`**：数组。取**最后一个 `role=user`** 的消息作为待校对文本；没有则 400。
- **`stream`**：`true` 时 SSE（`text/event-stream`，`data:` JSON chunk + `data: [DONE]`）。

## 限制

| 项目 | 值 |
|---|---|
| HTTP body | ≤ 1MB（超限 400） |
| 单次输入 | ≤ 40,000 字（超限 400） |
| 限流 | 每个 key 2 QPS（超限 429） |
| key 数量 | 每个账户最多 5 个有效 key |
| 超时 | 服务端约 30s（超时 504）|

## 错误格式

非 2xx 返回 OpenAI 风格错误体：

```json
{ "error": { "message": "...", "type": "...", "code": "..." } }
```

常见：401（缺/错 key）、400（参数缺失或超长）、429（限流/配额用完）、504（超时）。

## curl 示例

```bash
curl -s https://jd.glowjames.top/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JIAODUI_API_KEY" \
  -d '{"model":"jiaodui","messages":[{"role":"user","content":"他慢慢的走了。"}],"stream":false}' \
| python3 -m json.tool
```

调试可用 `scripts/beautare_client.py`（打印原始响应，支持 `--stream`）。

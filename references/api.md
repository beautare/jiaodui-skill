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

- OpenAI 兼容接口（CLI / API / Skill / MCP 均走这条）**不主动保存原文**。
- 仅当文本触发同音字等候选检查时，服务端质量改进日志会记录该次输入原文，用于改进校对准确率；该日志与账户/请求元数据分开存放，仅用于质量改进，不用于广告、营销或第三方共享，并按运营方保留策略定期清理。
- 提交文本前请注意：不要向接口发送您不希望被记录的内容（例如未发布的稿件、含个人敏感信息的文本）。匿名文本替换（把姓名/地名等替换为占位符）后再提交，是规避不必要记录的安全做法。
- 完整隐私口径见服务端<a href="https://jd.glowjames.top/privacy">隐私政策</a>。

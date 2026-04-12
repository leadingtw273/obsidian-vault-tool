# Add Question：管理 QUESTIONS.md 開放問題隊列

把「我想搞清楚 X」結構化為 QUESTIONS.md 的開放問題。
後續 archive 新來源時（Step 2.3）會自動匹配「這份 source 是否能回答某個開放問題」。

> 詳細 spec 見 `${CLAUDE_PLUGIN_ROOT}/references/workflow/ask-flow.md`。

---

## Step 0：前置準備

### 0.1 讀取 interaction_mode

依 `${CLAUDE_PLUGIN_ROOT}/references/governance/agent-mode.md`，從 vault CLAUDE.md 讀取 `interaction_mode`。缺失 → 預設 `human`。

### 0.2 解析使用者意圖

| 意圖 | 動作 |
|------|------|
| `ask <問題文字>` | 進入 Step 1（新增問題）|
| `ask --close <Q-NNN>` | 進入 Step 3（關閉問題）|
| `ask --list` | 進入 Step 4（列出清單）|
| 「open question」「待回答」 | 進入 Step 4 |
| 「我想搞清楚 X」 | 進入 Step 1，X 為問題文字 |

---

## Step 1：新增問題

### 1.1 讀取 QUESTIONS.md

用 Read 工具讀取 `[vault_path]/QUESTIONS.md`。

若檔案不存在 → 提示使用者先執行 `/vault-tool update` 建立 v0.9 系統檔，然後終止。

解析 `## Open` 段落，取得目前最大 Q-NNN 流水號。

### 1.2 問題規範化（Mode 分流）

**Human mode**：

> **Prompt 範本**（主對話自我指令）：
>
> ```
> 將以下使用者口語問題規範化為可驗證的問題：
>
> 原始輸入：「[使用者的原始文字]」
>
> 規範化規則：
> 1. 補充個人語境（「在我的場景下」而非泛泛而論）
> 2. 把「真的嗎」改為「是否」（讓問題可被驗證）
> 3. 移除情緒語氣詞
> 4. 確保問題可在 1-2 句答案內回答
> 5. 若問題過於開放，拆成 2-3 個子問題
>
> 輸出格式：
> 規範化問題：[一句話]
> （若拆分）子問題 A：[...]
> （若拆分）子問題 B：[...]
> ```

規範化後詢問使用者確認：

```
規範化為「[規範化後的問題]」，確認嗎？
```

等待使用者確認。

**Agent mode**：

不規範化，保留原文。加註 `raw`（待人類規範化）。

### 1.3 分配 Q-NNN 流水號

`Q-[最大流水號 + 1]`，三位數補零（Q-001, Q-002, ...）。

### 1.4 寫入 QUESTIONS.md

用 Read + Edit 工具在 `## Open` 段落 append 新條目：

```
- [ ] Q-NNN: [規範化後的問題] (opened YYYY-MM-DD[, by agent][, source: reflect Stage N][, raw])
```

更新 frontmatter `last_updated`（用 Read + Edit）。

### 1.5 追加 log.md

```bash
obsidian append vault=[vault_name] path="log.md" content="\n## [YYYY-MM-DD HH:mm] ask [agent]? | Q-NNN: [問題摘要]\nmode: ask\ninteraction_mode: [human|agent]\ntouched_specs: [ask-flow]\nfail_reason: none\nmanual_fix: no"
```

### 1.6 確認通知

```
✓ 已新增 Q-NNN: [問題文字]
  寫入 QUESTIONS.md 的 ## Open 段落
  log.md 已追加 ask 條目
```

**Human mode 額外詢問**：「是否現在執行 query 嘗試回答？」

---

## Step 2：Agent / Reflect 自動新增（程式呼叫入口）

> 此 step 供 reflect skill 和其他 skill 以程式方式新增 question，不經過 Step 1 的規範化詢問。

輸入：
- `question_text`：問題文字
- `source_tag`：來源標記（如 `reflect Stage 3`、`curator`）
- `is_agent`：是否 agent mode

流程：
1. 讀取 QUESTIONS.md 取最大流水號
2. 分配 Q-NNN
3. 用 Read + Edit append：
   ```
   - [ ] Q-NNN: [question_text] (opened YYYY-MM-DD, by agent, source: [source_tag])
   ```
4. 追加 log.md
5. 回傳 Q-NNN 給呼叫方

---

## Step 3：關閉問題（僅 Human Mode）

> Agent mode 不可關閉問題（認知判斷由人類做，見 `references/governance/agent-mode.md`）。

### 3.1 驗證 mode

若 `interaction_mode == agent` → 拒絕執行：

```
⚠ Agent mode 不可關閉問題。切換到 human mode 後重試。
```

### 3.2 讀取 QUESTIONS.md

用 Read 讀取完整內容，找到 `Q-NNN` 條目。

若不存在 → 提示「Q-NNN 不在 Open 段落」並終止。

### 3.3 移動條目

用 Edit 工具：
1. 從 `## Open` 段落刪除 `- [ ] Q-NNN: ...` 行
2. 在 `## Answered` 段落 append：
   ```
   - [x] Q-NNN: [問題文字] (opened YYYY-MM-DD, answered YYYY-MM-DD[, via [[outputs/queries/...]]])
   ```

若使用者指定了回答來源（如 `ask --close Q-005 --via outputs/queries/2026-04-15-rag.md`），加入 `via [[...]]` 連結。

### 3.4 更新 frontmatter

用 Edit 更新 `last_updated` 為今日。

### 3.5 追加 log.md

```bash
obsidian append vault=[vault_name] path="log.md" content="\n## [YYYY-MM-DD HH:mm] ask | close Q-NNN\nmode: ask\ninteraction_mode: human\ntouched_specs: [ask-flow]\nfail_reason: none\nmanual_fix: no\n- closed: Q-NNN\n- via: [[outputs/queries/...]]"
```

### 3.6 確認通知

```
✓ 已關閉 Q-NNN: [問題文字]
  從 ## Open 移到 ## Answered
  [via [[outputs/queries/...]]]
```

---

## Step 4：列出清單

讀取 QUESTIONS.md，格式化輸出：

```
Open Questions ([N] 個)：
- Q-001: [問題文字] (opened YYYY-MM-DD)
- Q-002: [問題文字] (opened YYYY-MM-DD, by agent)
- ...

Answered Questions ([M] 個)：
- Q-000: [問題文字] (answered YYYY-MM-DD)
- ...
```

若 Open > 50 → 提示：

```
⚠ Open Questions 過多 ([N] > 50)
建議審視低優先級問題並關閉，或對 agent 自動產生的問題執行批次審視。
```

---

## 注意事項

1. QUESTIONS.md 的修改**只用 Read + Edit 工具**（管道 2），不用 obsidian CLI（避免格式損壞）
2. Q-NNN 流水號是全域遞增的（不分 open/answered），確保 ID 唯一性
3. Agent mode 下新增問題會在條目標記 `by agent`，讓人類 review 時能區分
4. 問題來源標記（`source: reflect Stage 3` 等）讓人類追溯「為什麼會有這個問題」
5. `--close` 只在 human mode 可用，agent 不可關閉（防回音室）

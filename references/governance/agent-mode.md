# Agent Operation Mode

> **status**: v0.9.0-alpha（new spec）
> **scope**: governance — 治理層
> **authority**: 本檔為 `interaction_mode` 機制的權威定義

## Summary

obsidian-vault-tool 支援兩種使用者：**human**（人類操作者）與 **agent**（AI agent 作為長期知識庫使用者）。本 spec 定義兩種模式的差異、各 step 的 fallback 行為、與 agent 啟動時的 self-check。Agent 使用者**不能阻塞**——所有需要人類確認的 step 都必須有「降級寫入待 review 清單」的 fallback。

## Core Concepts

1. **interaction_mode**：vault 內 `CLAUDE.md` 的 frontmatter 欄位，值為 `human` 或 `agent`
2. **non-blocking**：agent mode 下任何 step 都不能等待人類輸入
3. **deferred review**：agent mode 下需要人類確認的決策寫入 `overview.md` 的「待 review 清單」
4. **self-check**：agent 啟動時驗證 vault 完整性與 spec 可讀性
5. **mode boundary**：mode 由 vault 決定，不由 plugin 決定（同一 plugin 可服務不同 vault 的不同 mode）

## Specification

### 1. interaction_mode 欄位定義

vault 內的 `CLAUDE.md` 必須含 `interaction_mode` 欄位（plugin v0.9 起強制）：

```yaml
---
vault_version: 0.9.0
interaction_mode: human  # or agent
---
```

| 值 | 語意 | 預設 |
|----|------|-----|
| `human` | 人類操作者使用，可等待互動 | ✅ 預設值 |
| `agent` | AI agent 長期運行，**不可阻塞** | — |

未設定欄位時視為 `human`（向後相容 v0.8 vault）。

### 2. Mode 偵測時機

- **Step 0**（讀取 vault CLAUDE.md）必須解析 `interaction_mode` 並傳遞給後續所有 step
- mode 在單次 archive/query/reflect 流程中**不可變更**（避免半人半 agent 狀態）
- 若 vault 無 CLAUDE.md → 使用 `human` 預設值並在 `log.md` 記一條 warning

### 3. 各 Skill / Step 的 fallback 行為表

<!-- decision-id: agent-mode-fallback-table -->

| Skill / Step | human mode 行為 | agent mode 行為 |
|---|---|---|
| `archive` Step 2.5 confidence gate（high 候選） | 暫停請求使用者確認 | **降級為 `high_candidate`**，不升級 confidence；寫入 `overview.md` 待 review 清單 |
| `archive` Step 2.3 QUESTIONS 匹配（找到候選） | 提示「此來源可能回答開放問題 X，是否立即執行 query？」 | **跳過互動**，直接在來源頁附註 `## Possibly Answers` 區塊列出 candidate questions |
| `ask` skill「關閉問題」 | 使用者明確說「關閉這題」 | **不執行**，agent 不可關閉問題（仍由人類決定） |
| `ask` skill「新增問題」 | 互動式整理問題 | **可執行**，agent 可主動新增 |
| `curator` warning（孤兒、矛盾、缺漏）| 提示使用者並詢問是否修補 | **不阻塞**，全部寫入 `outputs/lint/<date>.md` |
| `curator` 自動修補（如升級主題目錄）| 提示使用者確認後執行 | **延後**，寫入 `outputs/lint/<date>.md` 的「建議修補」段落，不執行 |
| `reflect` Stage 0 反向檢驗失敗（找到反證）| 提示使用者確認結論 | **不阻塞**，寫入 `outputs/reflect/warnings.md` |
| `reflect` Stage 3 Gap Analysis 結果 | 顯示給使用者並詢問是否新增 question | **自動**將 gap 新增為 QUESTIONS.md 的開放問題 |
| `query` 結果信心度低 | 警告使用者並詢問是否繼續 | **不阻塞**，在輸出尾端附 `⚠ Confidence Notes` |
| `vault-tool` 破壞性操作（reset / delete）| 多重確認 | **拒絕執行**，要求改為 human mode 後重試 |
| `wiki-writer` 同名異物偵測（需人類裁決）| 提示使用者選擇合併策略 | **不阻塞**，分別建立兩個頁面並在 `outputs/lint/<date>.md` 標註「待人類裁決」 |

### 4. Agent 啟動 self-check（必須執行）

agent mode 下，每次 plugin 被 agent 呼叫時，**第一個動作**必須是 self-check：

```
Step S1: 讀取 vault/CLAUDE.md → 確認 interaction_mode = agent
Step S2: 確認 vault_version 與 plugin version 相容
Step S3: 確認以下檔案存在且可讀：
  - vault/index.md
  - vault/log.md
  - vault/overview.md（v0.9 起）
  - vault/QUESTIONS.md（v0.9 起）
Step S4: 讀取 ${CLAUDE_PLUGIN_ROOT}/references/governance/ 全部 spec
Step S5: 若任一步驟失敗 → 中止本次操作並寫入 vault/log.md 的 error 條目
```

self-check **不可省略**，即使 agent 已經連續執行多次。理由：vault 可能被外部修改，每次 self-check 是最便宜的偵測機制。

### 5. overview.md 的「待 review 清單」結構

agent mode 下產生的「待人類確認」事項統一寫入 `vault/overview.md` 的固定段落：

```markdown
## 待 Review 清單（agent mode 累積）

### high_candidate confidence（待人類確認升級為 high）
- [ ] [[主題知識/概念/RAG]] — 5 sources，agent 標記日期 2026-04-15
- [ ] [[主題知識/實體/Anthropic]] — 8 sources，agent 標記日期 2026-04-16

### 同名異物（待人類裁決合併策略）
- [ ] 「Transformer」出現在 [[主題知識/概念/Transformer]] 與 [[主題知識/實體/Transformer]]，agent 標記日期 2026-04-15

### curator 建議修補（待人類執行）
- [ ] 升級 `主題知識/概念/Attention.md` 為目錄結構（5 個子主題）

### reflect Stage 0 警告（待人類審視）
- [ ] [[主題知識/總覽/AI技術全景]] 的合成結論未通過反向檢驗，詳見 outputs/reflect/warnings.md
```

人類使用者切換回 human mode 後，可逐項處理這個清單。處理完的項目用 `[x]` 標記但**不刪除**（保留審計軌跡）。

### 6. log.md 的 mode 標記

agent mode 下的所有 log 條目必須在標籤後加 `[agent]` 後綴：

```markdown
## [2026-04-15 14:32] ingest [agent] | RAG 架構簡介
mode: full-archive
interaction_mode: agent
touched_specs: [confidence-gating, sha-integrity]
fail_reason: none
manual_fix: no
```

human mode 條目不需要後綴（向後相容 v0.8）。

### 7. 模式切換的安全規則

- 切換 mode = 修改 vault/CLAUDE.md 的 `interaction_mode` 欄位
- 切換**只能由人類執行**（agent 不可自我升級為 human 或自我降級）
- 切換後必須在 log.md 記錄切換事件
- 切換**不會**清除 overview.md 的待 review 清單

## Examples

### Example 1：human mode 下的 high confidence 流程

```
1. archive raw/articles/rag-paper.md
2. wiki-writer 處理 主題知識/概念/RAG.md
3. confidence 升級到 5 sources → 候選 high
4. plugin: "RAG 概念已達 5+ sources 且無重大矛盾，是否確認 confidence = high？"
5. human: "確認"
6. wiki-writer 寫入 confidence: high
7. log.md 記 ingest 條目（無 [agent] 後綴）
```

### Example 2：agent mode 下的 high candidate 流程

```
1. agent: archive raw/articles/rag-paper.md
2. wiki-writer 處理 主題知識/概念/RAG.md
3. confidence 升級到 5 sources → 候選 high
4. agent mode → 跳過互動
5. wiki-writer 寫入 confidence: medium（不升級）+ frontmatter 加 high_candidate: true
6. 在 overview.md 的「待 Review 清單」追加一行
7. log.md 記 ingest [agent] 條目，touched_specs 含 confidence-gating, agent-mode
```

### Example 3：agent self-check 失敗

```
1. agent 啟動 plugin
2. Step S1: 讀取 vault/CLAUDE.md → interaction_mode = agent ✓
3. Step S2: vault_version = 0.8.5 vs plugin version = 0.9.0 → 不相容
4. agent 中止本次操作
5. 寫入 vault/log.md：
   ## [2026-04-15 14:32] error [agent] | self-check failed
   step: S2
   reason: vault_version 0.8.5 < required 0.9.0
   action: 等待人類執行 vault-tool update
6. agent 不再嘗試任何寫入操作
```

## Rationale

### 為什麼需要 agent mode

v0.8 與更早版本假設使用者是人類，所有需要決策的 step 都會「暫停 + 詢問」。但 leadi 明確希望 plugin 也能作為「AI agent 的長期知識庫」使用——這時 agent 不能等待人類，每次互動阻塞會讓 agent 卡死。

agent mode 的設計原則是：**該決策的事仍然要做決策，只是把「需要人類最終裁決」的部分延後寫入待 review 清單，主流程不阻塞**。

### 為什麼是 vault 決定 mode 而非 plugin

同一個 plugin 可能服務多個 vault：leadi 自己的 vault（human）+ 朋友 A 的 vault（human）+ 某個自動化 agent 的 vault（agent）。如果 mode 由 plugin 決定，會無法區分。所以 mode 寫在 vault 的 CLAUDE.md 內，跟著 vault 走。

### 為什麼 agent 不能關閉 QUESTIONS.md 的問題

「關閉問題」代表「我認為這個問題已經被回答了」，這是**認知判斷**而非統計事實。agent 可以新增問題（從 raw 自動發現）、可以匹配問題（這個來源可能回答了 X），但「確認答案足夠」必須由人類做。否則 agent 會出現「自己提問自己關閉」的回音室風險。

### 為什麼 self-check 不可省略

agent 長期運行時，vault 可能被外部修改（人類偷偷編輯、git pull 拉到新版本、檔案系統錯誤）。每次 self-check 是最便宜的偵測機制——就算每次跑都通過，成本也只是讀 5 個檔案。一旦發生不一致，self-check 是最後防線。

### 為什麼破壞性操作（reset/delete）在 agent mode 下完全禁止

破壞性操作不可逆且會失去資料。agent 在沒有人類監督下執行破壞性操作的風險遠超過任何收益。明確「拒絕執行」比「嘗試降級」更安全。

### 為什麼 log 條目需要 `[agent]` 後綴

未來人類 review 時需要區分「這條 log 是我做的」與「這條 log 是 agent 自動做的」。後綴是最便宜的標記方式，且向後相容（grep 條目仍可工作）。

## Cross References

- `references/governance/confidence-gating.md` — confidence 升級規則與 agent fallback 細節
- `references/structure/index-and-log.md`（v0.9.0-beta 新增）— overview.md 結構
- `references/workflow/archive-flow.md`（v0.9.0-beta 新增）— archive 10 步驟流程含 mode 分流
- `references/claude-md-template.md` — vault CLAUDE.md 範本含 `interaction_mode` 欄位

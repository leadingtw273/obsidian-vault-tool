# Ask Flow

> **status**: v0.9.0-alpha（new spec）
> **scope**: workflow — 流程定義
> **authority**: 本檔為 ask skill 與 QUESTIONS.md 的權威定義
> **inspired by**: Karpathy LLM Wiki 教程的 ADD-QUESTION 操作

## Summary

ask skill 是 v0.9 新增的「問題導向」操作，讓使用者能把「**我想搞清楚 X**」結構化為 QUESTIONS.md 的開放問題隊列。後續 archive 新來源時，wiki-writer 會自動檢查「這份 source 是否能回答某個開放問題」，能的話提示使用者立即執行 query。本機制把「好奇心」變成持續可追蹤的資產，而非對話中一閃而過的念頭。

## Core Concepts

1. **QUESTIONS.md**：vault 內的單一問題隊列檔，含 Open / Answered 兩個段落
2. **問題規範化**：使用者的口語問題被 ask skill 整理為標準格式
3. **自動匹配**：archive 時 wiki-writer 比對新 source 與 open questions
4. **mode 分流**：human 可關閉問題（標記為 answered），agent **不可關閉**（避免回音室）
5. **問題來源**：人類主動 ask + agent reflect 自動加（標記來源）

## Specification

### 1. ask skill 的觸發詞

| 觸發詞 | 動作 |
|-------|------|
| `ask <問題>` | 新增為 open question |
| `add question <問題>` | 同上 |
| 「我想搞清楚...」「我想知道...」 | 提示是否新增為 question |
| 「open question」「待回答」 | 列出 open questions 清單 |
| `ask --close <id>` | 關閉一個 open question (僅 human mode) |
| `ask --list` | 列出所有 questions |

### 2. QUESTIONS.md 結構

vault 根目錄的 `QUESTIONS.md`：

```markdown
---
type: system-questions
graph-excluded: true
created: 2026-04-15
last_updated: 2026-04-20
---

# Open Questions

## Open

- [ ] Q-001: RAG 和 FineTune 在我的場景下哪個更適合？(opened 2026-04-15)
- [ ] Q-002: Transformer 是否真的是當代 AI 的唯一核心架構？(opened 2026-04-18, by agent)
- [ ] Q-003: 是否需要為「Chain-of-Thought」建立 concept 頁？(opened 2026-04-20, by agent, source: reflect Stage 3)

## Answered

- [x] Q-000: 什麼是 RAG？(opened 2026-04-10, answered 2026-04-12 via [[outputs/queries/2026-04-12-what-is-rag]])
```

| 段落 | 用途 |
|------|------|
| frontmatter | type: system-questions, graph-excluded: true |
| `# Open Questions` 標題 | 固定 |
| `## Open` | 未回答的問題清單，checkbox 格式 |
| `## Answered` | 已回答的問題（保留審計）|

### 3. Question 條目格式

<!-- decision-id: ask-question-entry-format -->

```
- [ ] Q-{NNN}: {規範化後的問題} (opened YYYY-MM-DD, [by agent | by reflect | ...], [source: ...])
```

| 欄位 | 必填 | 說明 |
|------|-----|------|
| `[ ]` / `[x]` | ✅ | checkbox 表示 open / answered |
| `Q-NNN` | ✅ | 流水號（自動分配），三位數 |
| 問題文字 | ✅ | 規範化後的問題（一句話、明確）|
| `opened YYYY-MM-DD` | ✅ | 新增日期 |
| `by agent` | ⚠ | 若由 agent 自動新增則加此標記 |
| `source: ...` | ⚠ | 若來自 reflect Stage 3 等自動分析，標出來源 |
| `answered YYYY-MM-DD via [[...]]` | ⚠ | 關閉時加，附 outputs 連結 |

### 4. 問題規範化規則

當使用者用口語表達問題時，ask skill 必須：

```
原始輸入: "RAG 和 FineTune 我到底該選哪個？"
規範化後: "RAG 和 FineTune 在我的場景下哪個更適合？"

原始輸入: "Transformer 真的這麼厲害嗎？"
規範化後: "Transformer 是否真的是當代 AI 的唯一核心架構？"

規範化原則:
1. 補充「我的場景」「我」等個人語境（讓問題具體化）
2. 把「真的嗎」改為「是否真的」（讓問題可被驗證）
3. 移除情緒語氣詞（「到底」「真的」等）
4. 確保問題可在 1-2 句答案內回答（過於開放的問題拆成多個 sub-question）
```

規範化由 LLM 執行，但在寫入前**必須詢問使用者確認**（human mode）或保留原文加註「未規範化」（agent mode）。

### 5. ask skill 的執行流程

#### Human Mode 流程

```
1. 使用者: ask "RAG 和 FineTune 哪個更適合？"
2. ask skill 讀取 vault/QUESTIONS.md
3. 解析既有 Open Questions
4. 規範化新問題
5. 詢問使用者: "規範化為「RAG 和 FineTune 在你的場景下哪個更適合？」是否確認？"
6. 使用者: "確認"
7. 分配 Q-ID (取最大 ID + 1)
8. append 到 QUESTIONS.md 的 Open 段落:
   - [ ] Q-005: RAG 和 FineTune 在你的場景下哪個更適合？(opened 2026-04-20)
9. 更新 frontmatter 的 last_updated
10. 寫入 log.md:
    ## [2026-04-20 14:32] ask | Q-005: RAG 和 FineTune ...
11. 詢問使用者: "是否現在執行 query 嘗試回答？"
```

#### Agent Mode 流程

```
1. agent: ask "RAG 和 FineTune 哪個更適合？" (例如來自 reflect Stage 3)
2. ask skill 讀取 QUESTIONS.md
3. 不規範化（保留原文 + 加註「待人類規範化」）
4. 直接 append:
   - [ ] Q-005: RAG 和 FineTune 哪個更適合？(opened 2026-04-20, by agent, source: reflect Stage 3, raw)
5. 更新 last_updated
6. log.md: ask [agent] | Q-005
7. 不執行 query (agent 不能單方面決定要不要回答)
```

### 6. archive 的自動匹配 (Step 2.3)

archive 流程的 Step 2.3 (新增於 v0.9) 必須執行：

```
Step 2.3.1: 讀取 vault/QUESTIONS.md 的 Open 段落
Step 2.3.2: 對每個 open question，用 LLM 判斷新 source 是否能回答
  - 「能完全回答」 → candidate to close
  - 「能部分回答」 → candidate to enrich
  - 「無關」 → 跳過
Step 2.3.3: 若有任何 candidate:
  - human mode: 顯示提示
  - agent mode: 寫入 source 頁的 ## Possibly Answers 段落
```

#### Source 頁的 `## Possibly Answers` 段落

```markdown
（在 source 頁正文末尾）

## Possibly Answers

- [[QUESTIONS#Q-005]] (candidate to close): 本來源直接比較了 RAG 與 FineTune 在多個場景下的表現
- [[QUESTIONS#Q-002]] (candidate to enrich): 本來源簡要提及 Transformer 的限制
```

### 7. 關閉 question (僅 human mode)

關閉問題 = 把條目從 `## Open` 移到 `## Answered`，並加上 answered 欄位。

```
ask --close Q-005

human mode 流程:
1. 讀取 Q-005 內容
2. 詢問: "Q-005 應該被哪個 outputs/queries/ 答案標記為已回答？"
3. 使用者輸入或選擇 outputs/queries/2026-04-22-rag-vs-finetune.md
4. 從 ## Open 移除 Q-005
5. 加到 ## Answered:
   - [x] Q-005: RAG 和 FineTune 在你的場景下哪個更適合？(opened 2026-04-20, answered 2026-04-22 via [[outputs/queries/2026-04-22-rag-vs-finetune]])
6. 更新 last_updated
7. log.md: ask --close | Q-005
```

**Agent mode 不可執行 close**。詳見 `references/governance/agent-mode.md` 的 fallback 表。

### 8. Question 來源標記

| 來源 | 標記 |
|------|------|
| 人類 ask | （無標記，預設）|
| agent ask（程式驅動）| `by agent` |
| reflect Stage 3 自動產生 | `by agent, source: reflect Stage 3` |
| reflect Stage 1 缺失中介概念 | `by agent, source: reflect Stage 1 (implicit concept)` |
| curator 偵測 | `by agent, source: curator` |

來源標記讓人類 review 時能優先處理「自己提的問題」vs「agent 自動產生的問題」。

### 9. Question 規模管理

當 Open Questions 超過 50 個時，curator 應在 lint 報告中提示：

```
⚠ Open Questions 過多 (52 > 50)
建議:
- 審視低優先級問題並關閉
- 對相似問題執行合併
- 對 agent 自動產生的問題執行批次審視
```

不強制限制，只提示。

## Examples

### Example 1：人類主動 ask

```
1. 使用者: ask "我到底該不該用 LangChain？"
2. ask skill 規範化:
   "在我的開發場景下，是否應該採用 LangChain 作為 LLM 框架？"
3. 詢問使用者: "規範化後可以嗎？"
4. 使用者: "可以"
5. 分配 Q-008
6. append QUESTIONS.md:
   - [ ] Q-008: 在我的開發場景下，是否應該採用 LangChain 作為 LLM 框架？(opened 2026-04-22)
7. 詢問使用者: "是否現在 query？"
8. 使用者: "好"
9. → 進入 query 流程
```

### Example 2：archive 觸發匹配

```
1. 使用者: archive raw/articles/langchain-vs-llamaindex.md
2. archive 流程進入 Step 2.3
3. 讀取 QUESTIONS.md
4. 遍歷 Open Questions:
   - Q-008: "LangChain ... " → 新 source 直接討論 → candidate to close
5. human mode → 顯示:
   ┌─────────────────────────────────────────────┐
   │ 此來源可能回答了開放問題:                   │
   │   Q-008: 在你的開發場景下，是否應該採用     │
   │          LangChain 作為 LLM 框架？          │
   │                                             │
   │ 是否現在 query 並嘗試關閉問題？             │
   │ [是] [否，繼續 archive] [稍後]              │
   └─────────────────────────────────────────────┘
6. 使用者: "是"
7. archive 暫停，進入 query
8. query 完成後產出 outputs/queries/2026-04-22-langchain-decision.md
9. 詢問是否關閉 Q-008
10. 使用者: "是"
11. Q-008 從 Open 移到 Answered，附 query 連結
12. archive 繼續完成 Step 3-5
```

### Example 3：agent mode 下的自動加問題

```
情境: agent 跑 reflect, Stage 3 找到 implicit concept "Chain-of-Thought"

reflect 自動動作:
1. 對該 implicit concept 執行 ask:
   "是否需要為 Chain-of-Thought 建立 concept 頁？"
2. agent mode → 不規範化
3. append QUESTIONS.md:
   - [ ] Q-009: 是否需要為 Chain-of-Thought 建立 concept 頁？(opened 2026-04-20, by agent, source: reflect Stage 1 (implicit concept), raw)
4. log.md: reflect [agent] | added Q-009 from Stage 1 implicit concept

人類後續處理:
1. 使用者打開 vault, 看到 QUESTIONS.md 有 Q-009
2. 注意到 "by agent, source: reflect Stage 1" 標記
3. 評估: 確實需要建立 chain-of-thought concept 頁
4. 手動執行 archive 一個相關 raw 來啟動建立流程
5. archive 完成後，使用者執行 ask --close Q-009 並指向新建立的 concept 頁
```

### Example 4：archive 部分匹配

```
1. archive raw/articles/transformer-history.md
2. Step 2.3 找到:
   - Q-002: "Transformer 是否真的是當代 AI 的唯一核心？" → candidate to enrich (僅補充歷史脈絡，不直接回答主問題)
3. agent mode → 寫入 source 頁的 ## Possibly Answers:
   ## Possibly Answers
   - [[QUESTIONS#Q-002]] (candidate to enrich): 本來源提供 Transformer 的歷史脈絡，補充 Q-002 的背景但未直接回答
4. log.md: ingest [agent] | enriched Q-002 (no close)
```

## Rationale

### 為什麼問題隊列是獨立檔（QUESTIONS.md）而非散落各處

替代設計：每個 concept 頁有 `## Open Questions` 段落。

不採用的理由：
- 問題的主體不一定對應某個既有 concept（例如「我想搞清楚 X」時 X 可能還沒有 concept 頁）
- 散落各處難以掌握「我有多少個未答問題」
- 跨概念的問題（「A 和 B 哪個好」）無處安放

獨立檔讓問題成為一階公民，可被全局管理。

### 為什麼 agent 不能關閉問題

關閉 = 「我認為這個問題已經被回答了」，這是**認知判斷**：
- 答案是否完整？
- 是否涵蓋使用者真正想問的層面？
- 是否需要追問？

agent 沒有「我認為答案足夠」的能力，只能識別「query 結果存在」這個事實。如果 agent 自動關閉，會出現「自己提問自己關閉自己引用的回音室」。

人類關閉問題是「**我接受這個答案**」的明確訊號。

### 為什麼 agent 加問題時不規範化

規範化是「**重新表達使用者意圖**」的活動。agent 加的問題（來自 reflect Stage 3）本來就不是使用者原話，agent 自己對它做「規範化」會讓問題與真實意圖距離更遠。

保留原文加註「待人類規範化」是更誠實的做法——人類後續可以審視並改寫為精確問題，再決定是否處理。

### 為什麼 archive 自動匹配只是「提示」而非「自動關閉」

匹配本身是 LLM 對「source 內容是否回答 question」的判斷，可能誤判。如果自動關閉：
- 使用者沒看過答案就被告知問題已回答
- 失去學習機會（看 source 內容是 query 的核心價值）

提示讓使用者保持參與，匹配只是「值得看」的訊號。

### 為什麼 source 頁有 `## Possibly Answers` 段落

這個段落是「**這個 source 與哪些 question 有關**」的反向索引。價值：
- 未來 review source 頁時能看到「啊原來這篇文章解答過 Q-008」
- 讓 source 頁有自己的「問題脈絡」
- 構成「問題 → source 答案」的雙向追溯

不放在 QUESTIONS.md 內的 Q-008 條目是因為：QUESTIONS.md 應保持簡潔（一行一個問題），詳細 source 列表會讓檔案難以快速 scan。

### 為什麼問題隊列上限是 50（軟限制）

50 是「人類能定期 review 的合理上限」。超過 50 後：
- 使用者很難記得每個問題的脈絡
- 新加的問題難以被注意到
- 「未答問題太多」本身會讓人放棄整個機制

軟限制（提示但不強制）保留彈性，但給出健康訊號。

### 與 Karpathy 教程的對齊

Karpathy 教程的 ADD-QUESTION 機制：
- 同樣有 QUESTIONS.md 結構（Open / Answered 兩段）
- 同樣有 archive 自動匹配
- 同樣建議 close 問題時連結到 outputs

obsidian-vault-tool 的差異：
- 加入 Q-NNN 流水號（Karpathy 沒有，純粹靠問題文字識別）
- 加入「by agent, source: ...」標記（為 agent mode 設計）
- 加入「規範化」步驟（Karpathy 直接寫使用者原話）
- 加入 source 頁的 `## Possibly Answers` 段落（Karpathy 沒有）
- mode 分流（agent 不可關閉、不規範化）

差異化的核心是「**雙使用者支援**」（leadi + agent + 朋友圈），這是 Karpathy 教程沒考慮的維度。

## Cross References

- `references/governance/agent-mode.md` — agent 不可關閉問題、不規範化
- `references/structure/outputs-layer.md` — outputs/queries/ 是 question 關閉時的連結對象
- `references/workflow/archive-flow.md`（同 commit 新增）— Step 2.3 的自動匹配
- `references/workflow/reflect-flow.md`（同 commit 新增）— Stage 3 自動加 question
- `references/workflow/query-flow.md`（同 commit 新增）— query 後的「是否關閉 question」詢問
- v0.9.0-rc 將新增 `skills/ask/SKILL.md` 與 `commands/add-question.md`

# Contradictions

> **status**: v0.9.0-alpha（new spec）
> **scope**: quality — 品質保證
> **authority**: 本檔為矛盾標注機制的權威定義

## Summary

當新 source 與既有 concept 頁的 Definition 不一致時，**必須在 concept 頁的 `## Contradictions` 段落顯式標註**——不允許靜默覆蓋。Human mode 下使用者可決定是否降級 confidence；agent mode 下只標註不降級（避免 agent 抹除歷史）。本機制的價值是讓「認知不確定性」可被追蹤，而不是被掩埋在歷史版本裡。

## Core Concepts

1. **顯式標註**：矛盾必須以特定格式寫入 `## Contradictions` 段落
2. **不靜默覆蓋**：新 source 不能直接改 Definition 而不留痕跡
3. **`⚠ 矛盾` 標記**：每條矛盾條目以 `⚠` 開頭，便於 grep / curator 偵測
4. **mode 分流**：human 可降級 confidence，agent 只標註
5. **與 confidence-gating 聯動**：有 `⚠ 矛盾` 標記時，自動升級規則被阻斷

## Specification

### 1. Contradictions 段落格式

每個 concept 頁（`主題知識/{概念|實體|比較|總覽}/*.md`）的 markdown body 必須有 `## Contradictions` 段落（即使為空）。

**空狀態**（建立時）：

```markdown
## Contradictions

_暫無已知矛盾。_
```

**有矛盾時**：

```markdown
## Contradictions

- ⚠ 2026-04-18（[[歷史紀錄/文章/2026-04-18/03_RAG新論文]]）：主張 RAG 是 single-pass joint training，與當前 Definition 的「兩階段架構」說法不一致
- ⚠ 2026-04-22（[[歷史紀錄/文章/2026-04-22/02_RAG實戰]]）：retrieval 階段使用 dense vs sparse 的選擇上有分歧，作者主張 sparse 優先
```

### 2. 條目格式

<!-- decision-id: contradictions-entry-format -->

每條 ⚠ 條目的格式：

```
- ⚠ {YYYY-MM-DD}（{[[source 頁 wikilink]]}）：{矛盾的具體描述}
```

| 欄位 | 必填 | 說明 |
|------|-----|------|
| `⚠` | ✅ | 開頭符號，便於 grep |
| 日期 | ✅ | 偵測到矛盾的日期（通常 = ingest 日期）|
| source wikilink | ✅ | 引發矛盾的來源 |
| 描述 | ✅ | 一句話說明矛盾內容（≤ 80 字）|

**禁止格式**：
- ❌ 沒有 `⚠` 開頭（無法被 curator 偵測）
- ❌ 沒有 source wikilink（無法追溯）
- ❌ 描述含「應該」「可能」等模糊用語（要事實陳述）

### 3. 矛盾偵測時機

<!-- decision-id: contradictions-detection-timing -->

| 時機 | 偵測者 | 動作 |
|------|--------|------|
| archive Step 2 wiki-writer 處理 concept 頁 | wiki-writer | 比對新 source 的 claims 與既有 Definition；不一致則標註 |
| curator 健康檢查 | curator | 掃描 concept 頁的 Contradictions 段落，產出統計報告 |
| reflect Stage 0 反向檢驗 | reflect / synthesis-writer | 從既有 sources 找反證，發現的矛盾**寫入 outputs/reflect/warnings.md**（不寫進 concept 頁，避免污染）|
| 使用者手動發現 | human | 使用者可手動編輯 concept 頁加入條目（但格式必須符合）|

### 4. Mode 分流：發現矛盾後的動作

#### Human Mode

```
1. wiki-writer 偵測新 source 與 Definition 不一致
2. 在 ## Contradictions 追加 ⚠ 條目
3. 詢問使用者：
   ┌──────────────────────────────────────────────┐
   │ 偵測到矛盾                                   │
   │ concept: [[主題知識/概念/RAG]]               │
   │ 當前 Definition: 兩階段架構                  │
   │ 新 source: [[歷史紀錄/文章/2026-04-18/03_]]  │
   │ 矛盾: 主張 single-pass                       │
   │                                              │
   │ 是否降級 confidence？                        │
   │ 當前: high                                   │
   │ 建議: medium                                 │
   │                                              │
   │ [是，降級] [否，維持] [更新 Definition]      │
   └──────────────────────────────────────────────┘
4. 使用者選擇：
   - 「是，降級」→ confidence 降一級（high→medium 或 medium→low），Evolution Log 記錄
   - 「否，維持」→ confidence 不變，但 ⚠ 條目仍保留
   - 「更新 Definition」→ 進入互動式 Definition 改寫流程（v1.0 才完整實作）
```

#### Agent Mode

```
1. wiki-writer 偵測矛盾
2. 在 ## Contradictions 追加 ⚠ 條目
3. **不降級 confidence**
4. 在 outputs/lint/<date>.md 追加：
   ## ⚠ Contradiction Detected (待人類處理)
   - concept: [[主題知識/概念/RAG]]
   - source: [[歷史紀錄/文章/2026-04-18/03_]]
   - 矛盾描述: ...
   - agent 已標註於 concept 頁的 Contradictions 段落
   - 建議人類動作: 評估是否降級 confidence
5. 在 overview.md 待 review 清單追加：
   ### 矛盾待裁決
   - [ ] [[主題知識/概念/RAG]] 出現新矛盾，agent 已標註，待人類降級決策（2026-04-18）
6. 繼續 archive 流程，不阻塞
```

### 5. 與 confidence-gating 的聯動

當 concept 頁的 `## Contradictions` 段落含**任何 `⚠` 條目**時：

- ❌ **阻斷自動升級**：confidence 不會從 low → medium 或 medium → high_candidate（無論 source_count 多少）
- ✅ 已是 high 的 concept 不會被自動降級（必須人類或外部降級行為觸發）
- ✅ Evolution Log 記錄「矛盾期間升級被凍結」

詳細升級規則見 `references/governance/confidence-gating.md`。

### 6. 矛盾解決後的處理

當人類確認某個 ⚠ 條目「已被解決」（例如新證據說服了人類接受某一方），可以：

1. **保留條目但加 `[已解決]` 前綴**：
   ```
   - [已解決] ⚠ 2026-04-18(...)：主張 single-pass，2026-04-25 由 [[新 source]] 證明此說法為誤
   ```
2. **不可刪除**：保留審計軌跡

curator 統計矛盾時應排除 `[已解決]` 條目。

### 7. 矛盾與 wiki-writer 的整合點

wiki-writer agent 在 archive Step 2 處理 concept 頁時，必須執行子流程：

```
Sub-step A: 讀取既有 concept 頁的 ## Definition 段落（或建立新頁時略過）
Sub-step B: 用 LLM 判斷新 source 的 claims 是否與既有 Definition 一致
  - 一致 → 可能進入 confidence 升級流程
  - 不一致 → 進入 Sub-step C
Sub-step C: 在 ## Contradictions 段落 append ⚠ 條目
Sub-step D: 讀取 vault/CLAUDE.md 的 interaction_mode
  - human → 進入 human gate（詢問使用者）
  - agent → 進入 agent fallback（寫 outputs/lint + overview.md 待 review）
Sub-step E: confidence 自動升級被本次 ⚠ 條目阻斷
```

詳細實作見 v0.9.0-beta 的 `agents/wiki-writer.md` 更新（本 commit 不動 wiki-writer，只定義 spec）。

## Examples

### Example 1：典型矛盾標註（agent mode）

```
當前 主題知識/概念/RAG.md:
  confidence: high, source_count: 6
  ## Definition
  RAG 是「先 retrieval 再 generation」的兩階段架構

新 source: 歷史紀錄/文章/2026-04-18/03_RAG新論文.md
  主張 RAG 應該用 single-pass joint training

agent mode 處理:
1. wiki-writer 偵測 claim 不一致
2. RAG.md 的 ## Contradictions 段落 append:
   - ⚠ 2026-04-18（[[歷史紀錄/文章/2026-04-18/03_RAG新論文]]）：主張 RAG 是 single-pass joint training，與當前 Definition 的「兩階段架構」說法不一致
3. confidence 維持 high（不降級）
4. source_count 增為 7（仍計入，但升級被阻斷）
5. outputs/lint/2026-04-18.md 追加 contradiction detected 條目
6. overview.md 待 review 清單新增「矛盾待裁決」項目
7. log.md 記錄 ingest [agent] | RAG新論文，touched_specs: [contradictions, agent-mode]
```

### Example 2：矛盾解決後的處理

```
情境：上面 Example 1 的矛盾，2026-04-25 人類發現該論文被作者撤回

人類動作:
1. 編輯 主題知識/概念/RAG.md 的 Contradictions 段落
2. 將 ⚠ 條目改為:
   - [已解決] ⚠ 2026-04-18（[[...]]）：主張 RAG 是 single-pass，2026-04-25 確認該論文被作者撤回（[[歷史紀錄/文章/2026-04-25/01_RAG論文撤回通知]]）
3. confidence 自動升級恢復可能性（因為沒有未解決的 ⚠）
4. Evolution Log 記錄:
   - 2026-04-25（7 sources）：矛盾解決（撤回論文），可恢復升級評估
```

### Example 3：reflect Stage 0 發現的矛盾

```
人類執行: reflect

reflect Stage 0 (反向檢驗):
1. 對 主題知識/概念/RAG.md 的 Definition 在已有 sources 中找反證
2. 發現 [[歷史紀錄/文章/2026-03-15/02_早期RAG論文]] 含「retrieval 與 generation 共享權重」的描述
3. 此描述潛在矛盾於現在的 Definition

reflect skill 動作:
1. **不直接寫進 concept 頁的 Contradictions**（避免污染認知中的矛盾與探索性發現）
2. 寫入 outputs/reflect/warnings.md:
   ## reflect Stage 0 - 潛在矛盾
   - concept: [[主題知識/概念/RAG]]
   - source: [[歷史紀錄/文章/2026-03-15/02_早期RAG論文]]
   - 描述: 「共享權重」說法可能與當前 Definition 不一致
   - 建議: 人類審視這個來源是否真的構成矛盾
3. 不修改 concept 頁
4. 不阻塞主流程
```

`outputs/reflect/warnings.md` 與 concept 頁的 `## Contradictions` 是兩種不同層次的記錄：
- `## Contradictions` = ingest 時的明確衝突（事實已被新 source 提出）
- `outputs/reflect/warnings.md` = reflect 時的探索性發現（可能是矛盾、可能是補充）

## Rationale

### 為什麼必須顯式標註而不是覆蓋

知識庫的價值在於「**追蹤認知如何隨時間演化**」。如果每次新 source 都直接覆蓋 Definition，所有衝突都被掩埋。半年後 leadi 想知道「我為什麼之前覺得 RAG 是兩階段而現在覺得是 single-pass」時，沒有任何證據。

顯式標註讓「分歧」成為一階公民，而非後台的 git diff 才能找回的隱性歷史。

### 為什麼 agent 不能降級 confidence

降級是**主動的認知判斷**：「我認為這個矛盾足以動搖既有結論」。agent 沒有「自我認知」，只能識別事實層面的不一致。

如果 agent 自動降級：
- 場景 A：新 source 是錯的（作者搞錯了），agent 降級 → 誤導後續 query
- 場景 B：新 source 是補充而非矛盾（agent 誤判），agent 降級 → 抹除已建立的信心

兩種誤判都比「不降級只標註」傷害大。**標註是事實，降級是判斷**——agent 只能做事實。

### 為什麼 ⚠ 條目阻斷自動升級

設計目的：**有任何未解決矛盾時，confidence 不應該繼續累積**。

想像情境：
- concept 頁有 1 個 ⚠ 條目
- 然後 ingest 5 個新 source 都跟既有 Definition 一致
- source_count 達到 5 → 是否應該升級為 high candidate？

如果升級：意味著「即使有未解決矛盾，多數共識仍然算數」——這是**多數暴力**而非真實認知狀態。

不升級的設計是說：「在這個矛盾被人類解決前，我不能告訴你這個 concept 是 high confidence」。這是更誠實的訊號。

### 為什麼 reflect 的發現不直接寫進 Contradictions

`## Contradictions` 段落的條目應該是「**新 source 帶來的明確衝突**」，是 ingest 階段的真實事件。reflect 的「潛在矛盾」是探索性的——可能是假警報。

如果 reflect 把所有探索性發現都寫進 Contradictions，會：
- 污染這個段落的訊號（人類無法區分「真矛盾」與「reflect 想太多」）
- 觸發 confidence 阻斷規則，造成誤升級阻塞

所以 reflect 的探索性發現走獨立通道（`outputs/reflect/warnings.md`），人類審視後再決定是否升級為正式 ⚠ 條目。

### 為什麼條目必須含日期 + source wikilink

矛盾條目是**審計資料**，必須能回答兩個問題：
1. **何時知道的**？（日期）
2. **怎麼知道的**？（source wikilink）

少了任何一個，條目就成了「不可驗證的個人斷言」，違反 Karpathy LLM Wiki 的「來源溯源」原則。

### 與 Karpathy 教程的差異

Karpathy 教程把 Contradictions 視為 source 頁與 concept 頁的共同欄位（兩邊都標）。obsidian-vault-tool 簡化為**只在 concept 頁標註**——理由是 source 頁是「事實記錄」（這個來源說了什麼），concept 頁是「認知整合」（這個概念目前的理解狀態），矛盾是「整合層面」的事件，不該污染事實層面。

如果 leadi 將來需要 source 頁也有 Contradictions 欄位（例如「這個 source 自己內部矛盾」），可在 v1.0 加入。v0.9 保持簡化。

## Cross References

- `references/governance/confidence-gating.md` — 升級規則被 ⚠ 阻斷的細節
- `references/governance/agent-mode.md` — agent fallback 寫入 outputs/lint
- `references/quality/sha-integrity.md` — 不直接相關，但 SHA 變動可能觸發 re-ingest 進而發現新矛盾（v1.0）
- `references/structure/outputs-layer.md`（同 commit 新增）— outputs/lint/ 與 outputs/reflect/warnings.md 的格式
- `references/workflow/reflect-flow.md`（同 commit 新增）— Stage 0 反向檢驗的矛盾偵測
- v0.9.0-beta 將更新 `agents/wiki-writer.md` 加入矛盾偵測 sub-steps

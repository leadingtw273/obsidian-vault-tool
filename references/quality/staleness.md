# Staleness

> **status**: v0.9.0-alpha（new spec）
> **scope**: quality — 品質保證
> **authority**: 本檔為時效性檢查機制的權威定義
> **inspired by**: Karpathy LLM Wiki 教程的 domain_volatility / staleness 機制

## Summary

知識會隨時間過時——特別是高速演化的領域（AI、加密貨幣、JavaScript 框架）。本 spec 定義 `domain_volatility` 三級制與對應的 staleness 閾值（90/180/365 天），讓 curator 與 query 能識別「這個 concept 可能已過時」並警告使用者。同時定義 `possibly_outdated` 自動標記規則（來源發表 > 2 年）。

## Core Concepts

1. **domain_volatility**：concept / source 頁的 frontmatter 欄位，值為 `high` / `medium` / `low`
2. **staleness 閾值**：依 volatility 決定「多久未更新算過時」
3. **last_reviewed**：concept 頁的 frontmatter 欄位，最近一次被更新或人類審視的日期
4. **possibly_outdated**：來源發表 > 2 年的自動標記（source 頁欄位）
5. **被動警告**：staleness 不會阻塞流程，只在 query / curator 時警告

## Specification

### 1. domain_volatility 三級定義

<!-- decision-id: staleness-volatility-levels -->

| 值 | 適用領域 | staleness 閾值 |
|----|---------|--------------|
| `high` | 快速演化（AI 模型、密碼學、新興框架）| **90 天** |
| `medium` | 中速演化（軟體工程實踐、設計模式、API 設計）| **180 天** |
| `low` | 緩慢演化（演算法、數學原理、基礎理論）| **365 天** |

預設為 `medium`（unknown 時的安全選擇）。

### 2. 設定 domain_volatility 的時機

| 時機 | 設定者 | 動作 |
|------|--------|------|
| concept 首次建立 | wiki-writer | 預設 `medium`，可由 LLM 依領域判斷調整 |
| concept 後續更新 | wiki-writer | **不變更**（人類專屬決策）|
| 人類審視時 | human | 可手動編輯 frontmatter 改變等級 |
| agent mode 下 | agent | 預設 `medium`，agent **不可變更**已存在的值 |

### 3. last_reviewed 欄位

每個 concept 頁的 frontmatter 必須含 `last_reviewed: YYYY-MM-DD`，更新時機：

| 動作 | 是否更新 last_reviewed |
|------|---------------------|
| concept 頁建立 | ✅ 設為當天 |
| wiki-writer 更新 concept（新 source ingest）| ✅ 設為當天 |
| confidence 升級 | ✅ 設為當天 |
| 人類手動編輯 | ✅ 設為當天 |
| curator 自動修補（格式整理）| ❌ **不更新**（不算「審視」）|
| reflect 掃描 | ❌ **不更新**（reflect 是讀，不是審視）|

### 4. Staleness 計算

<!-- decision-id: staleness-calculation -->

```
今天日期 - last_reviewed > 閾值（依 domain_volatility）
  ↓
則該 concept 為 stale
```

| domain_volatility | 閾值 | 說明 |
|------------------|------|------|
| high | > 90 天 | AI 等快速領域，每季要 review |
| medium | > 180 天 | 一般領域，每半年 review |
| low | > 365 天 | 基礎理論，每年 review |

curator 會掃描所有 concept 頁，列出 stale 清單到 `outputs/lint/<date>.md`。

### 5. possibly_outdated 自動標記（source 頁）

<!-- decision-id: staleness-source-outdated-rule -->

source 頁（`歷史紀錄/{type}/{date}/NN_title.md`）的 frontmatter `possibly_outdated` 欄位由 archive 自動判定：

```
ingest 日期 - source 的發表日期（從 raw 原文 frontmatter 取）> 2 年（730 天）
  ↓
則 possibly_outdated: true
```

若原文沒有發表日期，使用檔案系統 mtime 作為估算（並在 source 頁附註「日期估算」）。

`possibly_outdated: true` 的後果：
- query 引用此 source 時必須在輸出加 `⚠` 標記
- curator 列入「過時來源」清單
- 不影響 confidence（這只是時間警示，不是事實質疑）

### 6. Curator 的 staleness 檢查

curator skill（v0.9.0-rc 升級）將新增 staleness 檢查：

```
Step S1: 掃描 主題知識/ 下所有 concept 頁
Step S2: 計算每個頁面的 staleness（today - last_reviewed vs 閾值）
Step S3: 將 stale 頁面分為三組（依 volatility）並列入報告
Step S4: 同時列「最快過期」前 5 名（用來引導使用者優先 review 哪些）
Step S5: 寫入 outputs/lint/<date>.md
```

curator 不會自動修補 stale 狀態（這需要人類重新審視內容）。

### 7. Query 時的 staleness 警告

query skill（v0.9.0-rc 升級）將在輸出時：

- 引用的 source 頁有 `possibly_outdated: true` → 在該引用旁加 `⚠ 來源 > 2 年`
- 引用的 concept 頁是 stale → 在輸出尾端的 Confidence Notes 加：
  ```
  ⚠ Staleness Notes:
  - [[主題知識/概念/Transformer]] 上次審視 120 天前（high volatility，超過 90 天閾值）
  ```

### 8. Mode 分流

| 動作 | Human Mode | Agent Mode |
|------|-----------|-----------|
| curator 列出 stale 清單 | 顯示給使用者 | 寫入 outputs/lint/<date>.md，**不阻塞**，**不寫 overview.md 待 review**（避免覆蓋「待人類確認 high」這類更高優先級項目）|
| query 警告 stale | 在輸出加 `⚠` | 同 |
| stale 觸發 re-review | 提示使用者 | **不觸發**，agent 不可宣告「已 review」 |
| domain_volatility 變更 | 人類手動編輯 | **禁止** |

## Examples

### Example 1：典型 staleness 流程

```
Day 1 (2026-04-15): 建立 主題知識/概念/RAG.md
  domain_volatility: high (AI 領域)
  last_reviewed: 2026-04-15

Day 30 (2026-05-15): 新 source ingest，更新 RAG.md
  last_reviewed: 2026-05-15

Day 120 (2026-08-15): 距上次審視 92 天 > 90 天閾值 (high)
  curator 掃描時將 RAG.md 列入 stale 清單

Day 125: 人類執行 curator
  outputs/lint/2026-08-20.md:
    ## Stale Concepts
    ### high volatility (> 90 天未審視)
    - [[主題知識/概念/RAG]] - 92 天未審視

Day 130: 人類審視 RAG.md，確認內容仍正確，編輯 frontmatter:
  last_reviewed: 2026-08-25
  → 不再 stale
```

### Example 2：possibly_outdated 自動標記

```
ingest: raw/articles/2024-old-rag-paper.md
  原文 frontmatter date: 2024-03-15
  ingest 日期: 2026-04-15
  天數差: 761 天 > 730 天

archive Step 2 record-writer 寫入:
  歷史紀錄/文章/2026-04-15/05_2024舊RAG論文.md
  frontmatter:
    date: 2026-04-15           # ingest 日期
    source_published: 2024-03-15  # 原文發表日期
    possibly_outdated: true    # 自動標記
    raw_sha256: ...

後續 query 引用時:
  根據 [[歷史紀錄/文章/2026-04-15/05_2024舊RAG論文]] (⚠ 來源 > 2 年)，RAG 的 retrieval 部分通常使用...
```

### Example 3：agent mode 下的 staleness

```
Day N: agent 執行 curator
  → 偵測到 5 個 stale concept
  → 寫入 outputs/lint/<date>.md
  → **不寫 overview.md**（staleness 不是 high 優先級）
  → 不阻塞，agent 繼續其他工作

Day N+1: 人類使用者打開 vault
  → 人類自己看 outputs/lint/<date>.md
  → 決定要不要 review stale 內容
```

agent mode 下 staleness 是「**被動報告**」而非「**主動阻塞**」，這是與 confidence high_candidate（會寫入 overview.md 待 review）的關鍵差異。理由：staleness 不會造成「錯誤複利」，只會降低 query 的時效性，優先級較低。

## Rationale

### 為什麼用三級而不是連續閾值

連續閾值（例如「每天扣 1 分」）的好處是更精細，但實作成本高且使用者難理解。三級是 Karpathy 教程的設計，已被驗證可用：
- 90 / 180 / 365 三個門檻容易記憶
- 三個 volatility 等級對應「快/中/慢」，使用者可直覺判斷
- 實作只需一個比較

精細化（例如七級、連續分數）留給 v1.0 評估。

### 為什麼 last_reviewed 不更新於 reflect / curator 自動修補

「審視」應該是**有意識的內容檢查**，不是「碰過這個檔案」。reflect 是分析（讀），curator 自動修補是格式整理（不檢查內容對錯），都不算「我確認這個 concept 仍然準確」。

如果這些動作也更新 last_reviewed，會出現「reflect 跑一遍 → 所有 stale 都被『重置』→ 沒有真實 review 卻看似新鮮」的假象。

### 為什麼 agent 不可變更 domain_volatility

`domain_volatility` 是領域特性的判斷：「AI 是否快速演化？」這是**領域理解**而非事實統計。agent 可以建議，但不可單方面變更。

如果 agent 自動下調 volatility（例如「我覺得 AI 沒那麼快變」），會降低 staleness 觸發頻率，可能讓真正過時的內容繼續被 query 引用。**保守處理** = 預設 medium + 不准 agent 改。

### 為什麼 staleness 是被動警告而不是主動降級

被動警告（在 query / curator 時提示）vs 主動降級（confidence 自動降）：
- 被動警告的成本：使用者看到 ⚠ 後自己決定要不要重 review
- 主動降級的成本：concept 突然從 high 變 medium，所有引用此 concept 的 synthesis 也跟著降級——**錯誤複利的反向版本**

被動警告不會引發連鎖反應，更安全。staleness 是「提醒人類去重 review」的訊號，不是「自動失效」的開關。

### 為什麼 possibly_outdated 是 source 層欄位而非 concept 層

source 是「**事實記錄**」，發表日期是事實。source > 2 年是事實判斷。
concept 是「**認知整合**」，整合了多個來源後的結論可能仍然有效（即使部分 source 過時）。

把 possibly_outdated 放在 source 層的好處：
- query 引用 source 時可以針對性警告
- concept 整體的 staleness 由 last_reviewed 控制，不被個別 source 的時間影響
- 如果 5 個 sources 都過時，可以推斷 concept 也可能過時（這個推斷可由 curator 加入未來 spec）

### 與 Karpathy 教程的閾值對齊

Karpathy 教程的 staleness 閾值就是 90/180/365 天，本 spec 完全沿用。理由：
- 這些數字有實證使用紀錄
- 對齊讓「從 Karpathy 教程過來的使用者」零學習成本
- 沒有理由為了差異化而改數字

如果 leadi 將來覺得閾值不對，可在 v1.0 評估調整。alpha 階段保持與 Karpathy 一致。

## Cross References

- `references/governance/confidence-gating.md` — staleness 不直接觸發 confidence 變更，但 stale concept 的 query 結果會在 Confidence Notes 標警告
- `references/governance/agent-mode.md` — agent mode 下 staleness 不寫 overview.md 待 review
- `references/quality/sha-integrity.md` — last_verified（SHA）與 last_reviewed（內容審視）是兩個不同欄位
- `references/quality/contradictions.md` — staleness + contradiction 同時出現時，contradiction 優先級更高
- `references/structure/outputs-layer.md`（同 commit 新增）— outputs/lint/<date>.md 的 staleness 區段格式
- v0.9.0-rc 將更新 `skills/curator/SKILL.md` 加入 staleness 檢查
- v0.9.0-rc 將更新 `skills/query/commands/ask.md` 加入 staleness 警告

---
name: archive
description: >
  從 Vault 的 raw/ 目錄歸檔待處理檔案，透過 record-writer 建立來源記錄、wiki-writer upsert Wiki 主題頁，
  並自動更新 index.md 與 log.md，最後清理 raw/ 原檔。
  支援模式：完整歸檔（預設）、只記錄來源（record-only）、只寫知識（knowledge-only）。
  對話歸檔：使用者說「歸檔對話」、「歸檔當前對話」、「把剛剛聊的存起來」等，
  主對話先將對話內容寫入 raw/，再走 full-archive 流程。
  觸發情境：使用者說「歸檔」、「整理 raw」、「處理 inbox」、「存起來」、「整理」、「記錄」、
  「只要知識」、「只記錄來源」、「歸檔對話」、「歸檔當前對話」時使用。
allowed-tools: ["Read", "Glob", "Grep", "Bash", "Agent"]
---

# Archive

掃描 `raw/` 目錄，對每個待歸檔檔案呼叫 record-writer agent（建立來源記錄）與 wiki-writer agent × N（upsert 知識頁），
完成後更新 index.md 與 log.md，並將已成功歸檔的 raw 原檔移至 raw/archived/。

對話歸檔情境下，主對話先執行預處理（萃取對話內容 → 寫入 `raw/conversation-[YYYYMMDDHHmm].md`），再進入標準 full-archive 流程。

## 共用前置

> 以下步驟由主對話執行，不可委派 sub-agent：

1. 讀取 Vault `CLAUDE.md`，提取 `vault_path`、`vault_name`、`plugin_version`
2. 確認 `plugin_version` 與 `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` 的 `version` 一致。若不一致：
   - 輸出警告：`⚠️ plugin 版本不一致：Vault 為 [舊版]，plugin 為 [新版]。建議先執行 vault-tool update 更新設定。`
   - **不阻塞執行**，繼續流程（避免因版本差異導致使用者無法歸檔）
3. 這些值必須由主對話傳入每個 sub-agent prompt（sub-agent 無法自行讀取）

---

## 意圖解析

在進行路由之前，**優先判斷使用者是否有對話歸檔意圖**：

**對話歸檔觸發語意（以下任何一種均視為對話歸檔）**：
- 「歸檔對話」、「歸檔當前對話」、「歸檔這次對話」
- 「把剛剛聊的存起來」、「把這段對話存到 Vault」
- 「對話存檔」、「把對話記錄下來」
- 類似語意的表達

**若偵測到對話歸檔意圖**：執行 `commands/full-archive.md` 中的 **Step -1（對話歸檔預處理）**，完成後繼續走 full-archive 流程（Step 0 起）。

**若非對話歸檔意圖**：直接走下方路由邏輯，從 Step 0 開始。

---

## 排他規則（v0.9.0-rc 新增）

以下觸發詞**不應**路由到 archive，應路由到對應 skill：

| 使用者語意 | 應路由到 | 原因 |
|-----------|---------|------|
| 「我想搞清楚 X」「add question」 | **ask** skill | 記錄問題，不是歸檔來源 |
| 「查一下 X」「wiki 裡有沒有」「整理一下 X 主題」 | **query** skill | 即時回答，不是歸檔 |
| 「reflect」「找漏洞」「綜合分析」 | **reflect** skill | 二階認知，不是歸檔 |
| 「lint」「wiki 體檢」「檢查 wiki」 | **curator** skill | 健康檢查，不是歸檔 |

**判定關鍵**：archive 的核心語意是「**有一個 raw 檔或對話要處理**」。如果使用者沒有提到 raw 檔 / URL / 對話歸檔，且語意更像「提問」或「記錄問題」，**不應走 archive**。

---

## 路由邏輯

根據使用者意圖，讀取並執行對應的命令檔案：

| 模式 | 觸發情境 | 執行檔案 | 說明 |
|------|---------|---------|------|
| full-archive（預設） | 「歸檔」、「整理 raw」、「處理 inbox」、「存起來」、「整理」，以及對話歸檔（預處理後） | `commands/full-archive.md` | 掃描 raw/ → record-writer → wiki-writer upsert → 更新 index/log → 移至 raw/archived/ |
| record-only | 「只記錄來源」、「不要知識筆記」、「存個紀錄」 | `commands/record-only.md` | 只呼叫 record-writer 寫歷史紀錄，跳過 wiki-writer；仍追加 log.md，不更新 index.md |
| knowledge-only | 「只要知識」、「從歷史紀錄再推主題」、「不需要來源記錄」 | `commands/knowledge-only.md` | 從指定歷史紀錄檔案直接呼叫 wiki-writer upsert，跳過 record-writer；更新 index.md 與 log.md，不移至 raw/archived/ |

## 執行方式

判斷使用者意圖後，讀取對應的 `commands/*.md` 檔案，並嚴格按照其中的步驟執行。

```
PLUGIN_ROOT 為此 SKILL.md 所在目錄：${CLAUDE_PLUGIN_ROOT}/skills/archive
```

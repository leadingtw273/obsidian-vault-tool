# Record Only：僅建立來源記錄

只記錄來源，不產生知識筆記。適用於「存個紀錄就好」或「欄位不全但仍想歸檔歷史紀錄」的情境。

> 本模式跳過 wiki-writer 與 index.md 更新，但仍追加 log.md（記錄為 record-only 類型）。

---

## Step 0：解析 raw 檔路徑

從使用者輸入解析目標 raw 檔。若使用者未明確指定檔案路徑，使用 Glob 工具掃描 `[vault_path]/raw/*.md` 列出清單供選擇：

```
raw/ 目錄有 N 個待處理檔案：
  1. [檔名1]
  2. [檔名2]
  ...

請選擇要建立來源記錄的檔案（輸入「全部」或編號）：
```

等待使用者選擇後繼續。

---

## Step 1：對每個 raw 檔並行呼叫 record-writer

Agent tool，`subagent_type: "obsidian-vault-tool:record-writer"`。

**並行策略**：若選擇多個檔案，在**單一訊息**中發出多個 Agent tool 呼叫。

**每個 agent 的 Prompt**：
```
**raw 檔絕對路徑**：[vault_path]/raw/[檔名].md
**Vault 路徑**：[vault_path]
**Vault 名稱**：[vault_name]
**今日日期**：[YYYY-MM-DD]
```

**等待輸出並解析**：
```
raw_file_path：[絕對路徑]
來源記錄路徑：[完整路徑]
來源記錄檔名：[序號_概述]
知識主題列表：（本模式不使用，忽略）
來源類型：[content_type]

## 執行紀錄
（結構化執行紀錄）
```

從輸出提取以下欄位：
- `raw_file_path`（供 Step 3 移動至 raw/archived/ 用）
- `來源記錄路徑`、`來源記錄檔名`
- `來源類型`（`content_type`）
- 執行紀錄（存為 `record_writer_logs[]`）

**熔斷處理**：

- 若某個 record-writer 回報**欄位不全熔斷**，**該 raw 檔標記為失敗，不刪除原檔**，繼續處理其他檔案。
- 若某個 record-writer 回報**來源重複（友善終止）**，**移動 raw 原檔至 raw/archived/**，繼續處理其他檔案。

---

## Step 2：追加 log.md（主對話執行）

讀取 `${CLAUDE_PLUGIN_ROOT}/references/log-spec.md` 了解格式。

對每個 Step 1 成功的 raw 檔，使用 `obsidian append` 直接追加 record-only 類型的 ingest 條目：

```bash
obsidian append path="log.md" content="\n## [YYYY-MM-DD HH:mm] ingest | [來源標題] (record-only)\n- record: [[歷史紀錄/[type]/[YYYY-MM-DD]/[序號]_[概述]]]" vault=[vault_name]
```

**時間戳記**：執行 `date '+%Y-%m-%d %H:%M'` 取得當前本地時間。

條目格式說明：
```markdown

## [YYYY-MM-DD HH:mm] ingest | [來源標題] (record-only)
- record: [[歷史紀錄/[type]/[YYYY-MM-DD]/[序號]_[概述]]]
```

> 本模式僅有 `record:` 行，無 `new:` 或 `updated:` 行。
> log.md 採 append-only 模式，不讀取整檔、不覆寫。

> 注意：**不更新 index.md**（本模式不產生知識頁，index 無需變更）。

---

## Step 3：移動已成功處理的 raw 檔至 raw/archived/

對 Step 1 成功（record-writer 輸出完整）的 raw 檔，執行移動：

```bash
mv [vault_path]/raw/[檔名].md [vault_path]/raw/archived/[檔名].md
```

> 說明：raw 原檔移至 `raw/archived/` 保留，供日後 knowledge-only 模式的 wiki-writer 回讀完整原文使用。

**不移動**：Step 1 熔斷（欄位不全）的 raw 檔，保留在 `raw/` 供使用者後續處理。

---

## Step 4：完成通知

```
已完成來源記錄（處理 [N] 個 raw 檔）：

成功：[M] 個
- [[序號_概述]] → 歷史紀錄/[type]/[date]/[序號]_[概述].md

失敗：[K] 個
- [raw 檔名]：[失敗原因]（原檔保留在 raw/）
```

> 在完成通知末尾附加執行紀錄摘要：
```
---
## 執行紀錄摘要

**record-writer × N**
- [raw 檔名1]：✓ 成功（寫入 [路徑]）
- [raw 檔名2]：⛔ 失敗（欄位不全：[缺漏欄位]）

**log.md**：已追加 N 個 record-only ingest 條目
**raw/ 清理**：已移動 M 個已處理檔案至 raw/archived/，保留 K 個失敗檔案
```

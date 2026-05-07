# Record Only：僅建立來源記錄

只記錄來源，不產生知識筆記。適用於「存個紀錄就好」或「欄位不全但仍想歸檔歷史紀錄」的情境。

> 本模式跳過 wiki-writer 與 index.md 更新，但仍追加 log.md（記錄為 record-only 類型）。

---

## Step 0：解析 raw 檔路徑 + 讀取 interaction_mode

### 0.1 讀取 interaction_mode（v0.9.0-beta 新增）

依 `${CLAUDE_PLUGIN_ROOT}/references/governance/agent-mode.md` 規範，從 vault CLAUDE.md 讀取 `interaction_mode` 欄位。若欄位缺失 → 使用預設 `human`。

### 0.2 解析 raw 檔路徑

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

## Step 0.5：預分配序號（主對話執行）

> 解決並行 record-writer 的序號競態問題。主對話在呼叫 record-writer 前，先掃描目標目錄的現有序號，為每個 raw 檔預分配遞增序號。

1. **讀取所有 raw 檔的 content_type**：對 Step 0 確定的檔案清單，逐一用 Read 工具讀取 frontmatter，提取 `content_type`（若無則依 `source` 推斷，規則同 record-writer Step 3）

2. **按 content_type 分組**：將 raw 檔按 content_type 分組，對照類型目錄（同 full-archive Step 0.5 對照表）

3. **掃描現有序號**：對每個需要用到的類型目錄，用 Glob 工具掃描 `[vault_path]/歷史紀錄/[類型目錄]/[今日日期]/*.md`，取最大序號

4. **預分配序號**：從最大序號 + 1 開始，依同組內的 raw 檔順序遞增分配

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
**指定序號**：[N]（由 Step 0.5 預分配）
**interaction_mode**：[human|agent]（由 Step 0.1 讀取）
**cli_write_mode**：[cli_first|native_only]（由共用前置讀取）
```

**等待輸出並解析**：
```
raw_file_path：[絕對路徑]
來源記錄路徑：[完整路徑]
來源記錄檔名：[序號_概述]
知識主題樹：（本模式不使用，忽略）
來源類型：[content_type]

## 執行紀錄
（結構化執行紀錄）
```

從輸出提取以下欄位：
- `raw_file_path`（供 Step 3 移動至 raw/archived/ 用）
- `raw_archived_path`（歸檔後路徑 `raw/archived/[檔名].md`，供日後 knowledge-only 回讀用）
- `來源記錄路徑`、`來源記錄檔名`
- `來源類型`（`content_type`）
- 執行紀錄（存為 `record_writer_logs[]`）

**熔斷處理**：

- 若某個 record-writer 回報**欄位不全熔斷**，**該 raw 檔標記為失敗，不刪除原檔**，繼續處理其他檔案。
- 若某個 record-writer 回報**來源重複（友善終止）**，**移動 raw 原檔至 raw/archived/**，繼續處理其他檔案。

---

## Step 2：追加 log.md（主對話執行）

讀取 `${CLAUDE_PLUGIN_ROOT}/references/structure/log-spec.md` 了解格式。

對每個 Step 1 成功的 raw 檔，使用 `obsidian append` 直接追加 record-only 類型的 ingest 條目。

**v0.9.0-beta**：依 `interaction_mode` 決定條目標題格式：
- `human` mode → `## [YYYY-MM-DD HH:mm] ingest | [來源標題] (record-only)`
- `agent` mode → `## [YYYY-MM-DD HH:mm] ingest [agent] | [來源標題] (record-only)`

```bash
obsidian append vault=[vault_name] path="log.md" content="\n## [YYYY-MM-DD HH:mm] ingest [agent] | [來源標題] (record-only)\nmode: record-only\ninteraction_mode: [human|agent]\ntouched_specs: [sha-integrity, path-safety-spec]\nfail_reason: none\nmanual_fix: no\n- record: [[歷史紀錄/[來源類型目錄]/[YYYY-MM-DD]/[序號]_[概述]]]"
```

**時間戳記**：執行 `date '+%Y-%m-%d %H:%M'` 取得當前本地時間。

條目格式說明：
```markdown

## [YYYY-MM-DD HH:mm] ingest [agent] | [來源標題] (record-only)
mode: record-only
interaction_mode: agent
touched_specs: [sha-integrity, path-safety-spec]
fail_reason: none
manual_fix: no
- record: [[歷史紀錄/[來源類型目錄]/[YYYY-MM-DD]/[序號]_[概述]]]
```

> 本模式僅有 `record:` 行，無 `new:` 或 `updated:` 行。
> log.md 採 append-only 模式，不讀取整檔、不覆寫。

> 注意：**不更新 index.md**（本模式不產生知識頁，index 無需變更）。

---

## Step 3：移動已成功處理的 raw 檔至 raw/archived/

對 Step 1 成功（record-writer 輸出完整）的 raw 檔，執行移動：

```bash
mkdir -p [vault_path]/raw/archived
mv [vault_path]/raw/[檔名].md [vault_path]/raw/archived/[檔名].md
```

> 說明：raw 原檔移至 `raw/archived/` 保留，供日後 knowledge-only 模式的 wiki-writer 回讀完整原文使用。

**不移動**：Step 1 熔斷（欄位不全）的 raw 檔，保留在 `raw/` 供使用者後續處理。

---

## Step 4：完成通知

```
已完成來源記錄（處理 [N] 個 raw 檔）：

成功：[M] 個
- [[序號_概述]] → 歷史紀錄/[來源類型目錄]/[date]/[序號]_[概述].md

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

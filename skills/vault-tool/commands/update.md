# 更新知識庫設定（update）

將現有 Vault 的 plugin 設定更新至最新版本，**保留使用者自訂內容**。

---

## 前置條件

執行 `${CLAUDE_PLUGIN_ROOT}/scripts/check-init-status.sh [vault_path]`：

- 若輸出 `NOT_INITIALIZED` 或路徑不存在：告知知識庫尚未初始化，引導使用 `init` 建立
- 若輸出 `ALREADY_INITIALIZED`：繼續執行

---

## 步驟 1：版本比對

讀取 Vault `CLAUDE.md` 中的 `plugin_version` 欄位，與 `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` 的 `version` 比較：

- **版本一致**：告知使用者已是最新版本，詢問是否仍要強制更新
- **版本不一致**：直接繼續更新流程

---

## 步驟 2：讀取現有設定

從現有 `CLAUDE.md` 讀取（**不重新詢問使用者**）：

- `vault_name`
- `vault_path`
- `vault_path_windows`（若有）

---

## 步驟 3：更新 CLAUDE.md

讀取 `${CLAUDE_PLUGIN_ROOT}/references/claude-md-template.md` 重新生成模板內容。

**保留規則**：
- `<!-- vault-tool:managed-end -->` 標記**之後**的所有內容視為使用者自訂區塊，**完整保留**
- 標記之前的部分完全以新模板取代

佔位符替換：
- `{{vault_name}}` → 從現有 CLAUDE.md 讀取的 vault_name
- `{{vault_path}}` → 從現有 CLAUDE.md 讀取的 vault_path
- `{{vault_path_windows_line}}` → 若有 Windows 路徑則填入；否則移除此整行
- `{{plugin_version}}` → 最新版本號

---

## 步驟 4：補齊資料夾

讀取 `${CLAUDE_PLUGIN_ROOT}/references/structure/folder-structure.md` 確認完整規格。

確保以下資料夾存在（缺少的建立，**多餘的不刪**），v0.9.0-beta 起含新增資料夾：

```
raw/
raw/archived/
raw/personal/                  # v0.9.0-beta 新增
歷史紀錄/對話/
歷史紀錄/個人寫作/              # v0.9.0-beta 新增
主題知識/實體/
主題知識/概念/
主題知識/比較/
主題知識/總覽/
templates/
outputs/                       # v0.9.0-beta 新增
outputs/queries/               # v0.9.0-beta 新增
outputs/reflect/               # v0.9.0-beta 新增
outputs/lint/                  # v0.9.0-beta 新增
index/                         # v0.9.0-beta 新增
```

若偵測到 `主題知識/` 下有符合 `YYYY-MM-DD/` 格式的舊目錄，僅輸出提示訊息：

> 偵測到舊版按日期組織的 `主題知識/YYYY-MM-DD/` 目錄，這些目錄不在新架構規範內。請手動處理（移動、歸檔或忽略），update 命令不會自動遷移。

---

## 步驟 5：補齊模板

讀取 `${CLAUDE_PLUGIN_ROOT}/references/structure/templates-spec.md` 了解完整規格。

在 `templates/` 目錄補齊 3 個模板：

| 檔名 | 行為 |
|------|------|
| `raw.md` | 不存在則建立 |
| `來源記錄.md` | 不存在則建立；v0.9.0-beta 起若已存在但缺少 `raw_file`/`raw_sha256`/`last_verified`/`possibly_outdated` → 更新為新版模板 |
| `知識筆記.md` | 不存在則建立；v0.9.0-beta 起若已存在但缺少 `confidence`/`source_count`/`domain_volatility`/`last_reviewed`/`high_candidate` → 更新為新版模板 |

新版 **`知識筆記.md`** frontmatter 格式（v0.9.0-beta，15 欄位 + 2 強制段落）：
```yaml
---
title:
date: "{{date}}"
updated: "{{date}}"
tags:
  -
aliases: []
sources:
  -
category:
wiki_category:
content_type:
author:
confidence: low
source_count: 0
domain_volatility: medium
last_reviewed: "{{date}}"
high_candidate: false
---

## Contradictions

_暫無已知矛盾。_

## Evolution Log
```

新版 **`來源記錄.md`** frontmatter 格式（v0.9.0-beta，10 欄位）：
```yaml
---
title:
date: "{{date}}"
source:
category: 來源紀錄
content_type:
author:
raw_file:
raw_sha256:
last_verified: "{{date}}"
possibly_outdated: false
---
```

> 注意：`type` 與 `children` 欄位不在模板中預設，由 curator skill 在結構升級時動態加入。

---

## 步驟 5b：補齊系統檔（v0.9.0-beta 升級）

依 `references/structure/outputs-layer.md` 與 `references/governance/agent-mode.md`，補齊以下系統檔（不存在則建立，已存在則略過）：

### 既有系統檔（v0.8 已有）

- **`index.md`**：建立空白 Wiki 目錄索引
- **`log.md`**：建立空白時間軸日誌

```
obsidian create vault=[vault_name] path="index.md" content="# Wiki Index\n"
obsidian create vault=[vault_name] path="log.md" content="# Wiki Log\n\n<!-- append-only：只追加，不修改既有條目 -->\n<!-- v0.9.0-beta 格式：## [YYYY-MM-DD HH:mm] [ingest|query|curator|reflect|ask] [agent]? | [標題] -->\n<!-- 條目欄位: mode, interaction_mode, touched_specs, fail_reason, manual_fix -->\n"
```

### v0.9.0-beta 新增系統檔

- **`QUESTIONS.md`**：開放問題隊列（依 `references/workflow/ask-flow.md`）
- **`overview.md`**：Health Dashboard + 待 review 清單（依 `references/governance/agent-mode.md` Section 5）
- **`index/topic-index.md`**：極簡索引層（topic → wikilinks）
- **`index/question-index.md`**：極簡索引層（question → candidate sources）

```
obsidian create vault=[vault_name] path="QUESTIONS.md" content="---\ntype: system-questions\ngraph-excluded: true\ncreated: \"{{date}}\"\nlast_updated: \"{{date}}\"\n---\n\n# Open Questions\n\n## Open\n\n_暫無開放問題。_\n\n## Answered\n\n_暫無已回答問題。_\n"

obsidian create vault=[vault_name] path="overview.md" content="---\ntype: system-overview\ngraph-excluded: true\ncreated: \"{{date}}\"\nlast_updated: \"{{date}}\"\n---\n\n# Knowledge Base Overview\n\n## Health Dashboard\n\n_本區由 reflect / curator skill 自動更新。_\n\n## 待 Review 清單（agent mode 累積）\n\n### high_candidate confidence（待人類確認升級為 high）\n\n_暫無待 review 項目。_\n\n### 同名異物（待人類裁決合併策略）\n\n_暫無待 review 項目。_\n\n### curator 建議修補（待人類執行）\n\n_暫無待 review 項目。_\n\n### 矛盾待裁決（agent 已標註，待人類降級決策）\n\n_暫無待 review 項目。_\n"

obsidian create vault=[vault_name] path="index/topic-index.md" content="---\ntype: system-index\ngraph-excluded: true\n---\n\n# Topic Index\n"

obsidian create vault=[vault_name] path="index/question-index.md" content="---\ntype: system-index\ngraph-excluded: true\n---\n\n# Question Index\n"
```

### v0.9.0-beta CLAUDE.md 必補欄位

若現有 vault 的 `CLAUDE.md` 缺 `interaction_mode` 欄位（v0.8 vault 升級時必發生），自動補入：
- 預設值: `interaction_mode: human`
- 加入位置: 「初始化狀態」段落的 yaml 區塊內

### v0.9.1 CLAUDE.md 必補欄位

若現有 vault 的 `CLAUDE.md` 缺 `cli_write_mode` 欄位（v0.9.0 vault 升級時必發生），自動補入：
- 預設值: `cli_write_mode: cli_first`（保守選擇，不破壞既有 CLI 寫入流程）
- 加入位置: 「初始化狀態」段落的 yaml 區塊內，緊接 `interaction_mode` 之後
- 並在 CLAUDE.md 中加入「CLI Write Mode」段落（從新版 template 帶入）

> 若使用者環境已知 obsidian CLI 寫入會弄崩 Obsidian 主程式（例如 Obsidian 1.12.7 + 中文檔名密集 vault），update 完成後**告知使用者可手動將 `cli_write_mode` 改為 `native_only`** 規避 IPC bug。詳見 `${CLAUDE_PLUGIN_ROOT}/references/cli-usage.md` 的「IPC 訊息序列化崩潰」段落。

以上欄位由 Step 3 的 CLAUDE.md 重新生成統一處理（從新版 template 自動帶入）。

---

## 步驟 6：對齊 .obsidian 設定（增量更新）

> 注意：obsidian CLI 不支援 `.obsidian` 設定檔的讀寫，此步驟維持直接操作 JSON 檔案。

若 `.obsidian/` 存在，**增量更新**（只更新特定欄位，不刪除使用者其他設定）：

**a. `templates.json`**：更新 `folder`、`dateFormat`、`timeFormat`，保留其餘欄位

**b. `app.json`**：更新 `newFileLocation`（`folder`）、`newFileFolderPath`（`主題知識`），保留其餘欄位

**c. `core-plugins.json`**：確保 `"templates": true`，保留其餘設定

若 `.obsidian/` 不存在：略過，並在摘要說明。

---

## 步驟 7：更新全域 CLAUDE.md

若 `~/.claude/CLAUDE.md` 中已有 `## Vault: [vault_name]` 區塊，檢查路徑是否需要更新：

- 若路徑已一致：略過
- 若路徑有變動：更新區塊中的 `vault_path`（及 `vault_path_windows`）

---

## 完成摘要

```
✓ CLAUDE.md 已更新至 plugin v[新版本]（plugin_version 已寫入，自訂區塊已保留，interaction_mode 預設 human，cli_write_mode 預設 cli_first）
✓ 補齊資料夾：[列出新建的，含 v0.9.0-beta 新增 raw/personal/、歷史紀錄/個人寫作/、outputs/{queries,reflect,lint}/、index/]
✓ 補齊模板：[列出新建的或更新的，含 v0.9.0-beta 知識筆記 5 個新欄位 + 來源記錄 4 個 SHA 欄位]
✓ index.md / log.md：[已建立空白範本 / 已存在略過]
✓ QUESTIONS.md / overview.md / index/topic-index.md / index/question-index.md（v0.9.0-beta 新增）：[已建立 / 已存在略過]
✓ .obsidian 設定已增量更新（或：.obsidian 不存在，略過）
✓ 全域 CLAUDE.md 已同步

> 升級至 v0.9.0-beta 後，建議檢視 vault/CLAUDE.md 的 interaction_mode 欄位。
> 升級至 v0.9.1 後，若 obsidian CLI 寫入會弄崩 Obsidian 主程式（中文檔名 + Obsidian 1.12.7 IPC bug），可將 `cli_write_mode` 改為 `native_only` 全面改走 Read/Edit/Write。
> 若用於 AI agent 長期知識庫場景，可改為 `agent`。詳見 references/governance/agent-mode.md。
```

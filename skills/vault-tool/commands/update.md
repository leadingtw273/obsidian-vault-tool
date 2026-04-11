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

確保以下資料夾存在（缺少的建立，**多餘的不刪**）：

```
raw/
raw/archived/
歷史紀錄/對話/
主題知識/實體/
主題知識/概念/
主題知識/比較/
主題知識/總覽/
templates/
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
| `來源記錄.md` | 不存在則建立 |
| `知識筆記.md` | 不存在則建立；若已存在但 frontmatter 缺少 `updated`、`aliases`、`sources`、`wiki_category` 欄位（舊版 schema），則更新為新版模板內容 |

新版 **`知識筆記.md`** frontmatter 格式（需與 `references/structure/templates-spec.md` 一致）：
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
---
```

> 注意：`type` 與 `children` 欄位不在模板中預設，由 curator skill 在結構升級時動態加入。

---

## 步驟 5b：補齊 index.md 與 log.md

- **`index.md`**：若 Vault 根目錄不存在，建立空白 Wiki 目錄索引；已存在則略過
- **`log.md`**：若 Vault 根目錄不存在，建立空白時間軸日誌；已存在則略過

使用 obsidian CLI 寫入（分別執行，`create` 不加 `overwrite`，已存在時 CLI 會略過或報錯，確認後略過即可）：
```
obsidian create vault=[vault_name] path="index.md" content="# Wiki Index\n"
obsidian create vault=[vault_name] path="log.md" content="# Wiki Log\n\n<!-- append-only：只追加，不修改既有條目 -->\n<!-- 格式：## [YYYY-MM-DD HH:mm] [ingest|query|curator] | [標題] -->\n"
```

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
✓ CLAUDE.md 已更新至 plugin v[新版本]（plugin_version 已寫入，自訂區塊已保留）
✓ 補齊資料夾：[列出新建的，若無則顯示「無需補齊」]
✓ 補齊模板：[列出新建的或更新的，若無則顯示「無需補齊」]
✓ index.md：[已建立空白範本 / 已存在略過]
✓ log.md：[已建立空白範本 / 已存在略過]
✓ .obsidian 設定已增量更新（或：.obsidian 不存在，略過）
✓ 全域 CLAUDE.md 已同步
```

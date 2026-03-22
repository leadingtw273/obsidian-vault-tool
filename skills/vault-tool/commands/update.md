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

確保以下資料夾存在（缺少的建立，**多餘的不刪**）：

```
歷史紀錄/對話/
主題知識/
templates/
```

---

## 步驟 5：補齊模板

在 `templates/` 目錄補齊 2 個模板（**已存在的不覆蓋**，只建立缺少的）：

| 檔名 | category | content_type |
|------|----------|--------------|
| `來源記錄.md` | `來源紀錄` | （動態） |
| `知識筆記.md` | （動態） | （動態） |

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
✓ CLAUDE.md 已更新至 plugin v[新版本]（自訂區塊已保留）
✓ 補齊資料夾：[列出新建的，若無則顯示「無需補齊」]
✓ 補齊模板：[列出新建的，若無則顯示「無需補齊」]
✓ .obsidian 設定已增量更新（或：.obsidian 不存在，略過）
✓ 全域 CLAUDE.md 已同步
```

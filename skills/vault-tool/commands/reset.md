# 重置知識庫設定（reset）

完全重新生成所有 plugin 管理的設定檔與模板，**使用者筆記不受影響**。

---

## 前置條件

執行 `${CLAUDE_PLUGIN_ROOT}/scripts/check-init-status.sh [vault_path]`：

- 若路徑完全不存在：告知知識庫不存在，引導使用 `init` 建立
- 若路徑存在但 `NOT_INITIALIZED`（設定損壞）：詢問是否要重新初始化，可繼續
- 若 `ALREADY_INITIALIZED`：繼續執行

---

## 步驟 1：安全確認

明確告知使用者影響範圍，**要求確認後才繼續**：

> **重置將執行以下操作：**
> - CLAUDE.md：完全重新生成（自訂內容將遺失）
> - templates/ 下的所有模板：全部覆蓋
> - .obsidian/templates.json、app.json、core-plugins.json：完全重寫
>
> **以下內容不受影響：**
> - 歷史紀錄/、主題知識/ 中的所有筆記
>
> 確認要重置嗎？(y/n)

使用者確認後才繼續。

---

## 步驟 2：讀取現有設定

優先從現有 `CLAUDE.md` 讀取 `vault_name`、`vault_path`、`vault_path_windows`。

若 CLAUDE.md 已損壞或缺少關鍵欄位，重新詢問使用者。

---

## 步驟 3：完全重新生成 CLAUDE.md

讀取 `${CLAUDE_PLUGIN_ROOT}/references/claude-md-template.md`，**不保留任何原有內容**，完整重新生成。

佔位符替換：
- `{{vault_name}}` → vault_name
- `{{vault_path}}` → vault_path
- `{{vault_path_windows_line}}` → 若有 Windows 路徑則填入；否則移除此整行
- `{{plugin_version}}` → 從 plugin.json 讀取的最新版本號

---

## 步驟 4：覆蓋所有模板

讀取 `${CLAUDE_PLUGIN_ROOT}/references/templates-spec.md` 了解完整規格。

在 `templates/` 目錄**覆蓋**以下 2 個模板（無論是否已存在）：

**`來源記錄.md`**：
```yaml
---
title:
date: "{{date}}"
source:
category: 來源紀錄
content_type:
author:
---
```

**`知識筆記.md`**：
```yaml
---
title:
date: "{{date}}"
tags:
  -
source:
category:
content_type:
author:
---
```

---

## 步驟 5：重寫 .obsidian 設定

> 注意：obsidian CLI 不支援 `.obsidian` 設定檔的讀寫，此步驟維持直接操作 JSON 檔案。

若 `.obsidian/` 存在，**完全重寫**以下三個設定檔：

**a. `templates.json`**：
```json
{
  "folder": "templates",
  "dateFormat": "YYYY-MM-DDTHH:mm",
  "timeFormat": "HH:mm"
}
```

**b. `app.json`**：
```json
{
  "newFileLocation": "folder",
  "newFileFolderPath": "主題知識"
}
```

**c. `core-plugins.json`**：
確保包含 `"templates": true`，其他 core plugin 狀態重置為 Obsidian 預設值。

若 `.obsidian/` 不存在：略過，並在摘要說明。

---

## 步驟 6：補齊資料夾

確保以下資料夾存在（缺少的建立，多餘的不刪）：

```
歷史紀錄/對話/
主題知識/
templates/
```

---

## 完成摘要

```
✓ CLAUDE.md 已完全重新生成（plugin v[version]）
✓ 2 個模板已全部覆蓋（來源記錄、知識筆記）
✓ .obsidian 設定已完全重寫（或：.obsidian 不存在，略過）
✓ 資料夾結構已補齊
✓ 筆記內容完整保留，未受影響
```

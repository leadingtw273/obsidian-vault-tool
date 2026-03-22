# 刪除知識庫（delete）

移除 plugin 管理的設定，或刪除整個 Vault 目錄。提供三種模式供使用者選擇。

---

## 前置條件：確認 Vault 資訊

優先從現有 `CLAUDE.md` 讀取 `vault_name`、`vault_path`、`vault_path_windows`。

若使用者在訊息中已提供 vault 名稱或路徑，直接沿用；若未提供，從 `~/.claude/CLAUDE.md` 的 Vault 區塊讀取。

若 CLAUDE.md 已損壞或缺少關鍵欄位，重新詢問使用者。

---

## 步驟 1：列出影響範圍，選擇模式

向使用者說明三種刪除模式，**要求選擇**：

> **請選擇刪除模式：**
>
> **1. soft（軟刪除）**
> 僅移除 plugin 管理的設定檔：
> - 刪除 `CLAUDE.md`
> - 刪除 `templates/` 目錄下由 plugin 建立的 2 個模板
> - 移除 `.obsidian/templates.json`、`app.json` 中由 plugin 管理的欄位
> - 筆記、資料夾結構、其他 .obsidian 設定完整保留
>
> **2. medium（中度刪除）**
> 同 soft，另外移除空的管理資料夾：
> - 若 `templates/` 為空：刪除資料夾
> - 若 `歷史紀錄/` 下各子目錄（對話/YouTube/Facebook/文章/文件/網頁）為空：刪除這些子資料夾
> - `主題知識/`、有內容的資料夾保留
>
> **3. hard（完全刪除）**
> 刪除整個 Vault 目錄（`[vault_path]`）。
> **此操作不可逆，所有筆記將永久刪除。**

等待使用者選擇後繼續。

---

## 步驟 2：執行對應刪除

### Soft 模式

1. 刪除 `[vault_path]/CLAUDE.md`
2. 刪除 `templates/` 下的 2 個 plugin 模板（`來源記錄.md`、`知識筆記.md`），其他使用者自建模板不動
3. 若 `.obsidian/templates.json` 存在：刪除整個檔案（或移除 plugin 管理欄位）
4. 若 `.obsidian/app.json` 存在：移除 `newFileLocation`、`newFileFolderPath` 欄位，保留其餘欄位

### Medium 模式

執行 soft 模式所有步驟，再額外：

5. 若 `templates/` 目錄為空：刪除 `templates/`
6. 逐一檢查以下資料夾，若為空則刪除：
   - `歷史紀錄/對話/`
   - `歷史紀錄/YouTube/`
   - `歷史紀錄/Facebook/`
   - `歷史紀錄/文章/`
   - `歷史紀錄/文件/`
   - `歷史紀錄/網頁/`
   - 若上述子資料夾全部刪除後 `歷史紀錄/` 為空：刪除 `歷史紀錄/`

### Hard 模式

**需二次確認**：

> 您即將刪除整個 Vault 目錄：`[vault_path]`
> 此目錄包含所有筆記，刪除後**無法復原**。
>
> 請輸入 Vault 名稱（`[vault_name]`）確認刪除：

使用者輸入正確的 vault_name 後，執行：

```bash
rm -rf [vault_path]
```

---

## 步驟 3：清理全域 CLAUDE.md

詢問使用者：

> 是否要同時清理全域 `~/.claude/CLAUDE.md` 中的 `## Vault: [vault_name]` 區塊？

若使用者確認：讀取 `~/.claude/CLAUDE.md`，移除整個 `## Vault: [vault_name]` 區塊（含其下的 vault_path 等欄位，直到下一個 `##` 標題或檔案末尾）。

---

## 完成摘要

```
✓ [模式] 刪除完成
✓ 已移除：[列出已刪除的項目]
✓ 已保留：[列出未動的項目，soft/medium 模式]
✓ 全域 CLAUDE.md 的 vault 區塊已移除（或：已保留）
```

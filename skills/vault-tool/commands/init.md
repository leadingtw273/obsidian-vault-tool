# 知識庫建立精靈（init）

這是一個一次性互動精靈，協助使用者從零建立完整的 Obsidian Vault 環境，
包含資料夾結構、模板、CLAUDE.md 與 .obsidian 設定。

---

## 階段 1：歡迎說明

向使用者說明將要建立的內容（不需等待確認，直接呈現後進入階段 2）：

> 我將透過此精靈協助您建立完整的 Obsidian 知識庫，包含：
> - 標準資料夾結構（歷史紀錄/對話/、主題知識/、templates/）
> - 2 種筆記模板（來源記錄、知識筆記）
> - CLAUDE.md 設定檔（讓 Claude 了解此 Vault 的操作規範）

---

## 階段 2：收集資訊

若使用者已在訊息中提供了 vault 名稱或路徑，直接沿用，不需重複詢問。
只針對**尚未提供**的資訊提問：

1. **知識庫名稱**：請問您想為知識庫取什麼名稱？（例如 `my-vault`、`personal-notes`）
2. **存放路徑**：請問知識庫要建在哪個目錄？（例如 `/mnt/c/Users/xxx/Documents/my-vault`）

收到所有必要資訊後，**在開始建立前**向使用者確認：

> 請確認以下設定：
> - **知識庫名稱**：`[vault_name]`
> - **存放路徑**：`[vault_path]`（WSL2 環境時同時顯示 Windows 路徑）
>
> 確認後開始建立？(y/n)

等待使用者確認後才繼續階段 3。

收到答案後：

- 記錄 `vault_name` 與 `vault_path`
- 偵測作業系統環境：
  - 若 `vault_path` 以 `/mnt/` 開頭，判定為 WSL2 環境
  - WSL2 路徑轉換規則：`/mnt/c/Users/...` → `C:\Users\...`
  - 記錄 `vault_path_windows`（WSL2 環境才有）
- 讀取 `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` 取得 `version` 欄位

確認路徑不存在衝突：執行 `${CLAUDE_PLUGIN_ROOT}/scripts/check-init-status.sh [vault_path]`

- 若輸出 `ALREADY_INITIALIZED`：詢問使用者是否要重新初始化（覆蓋現有 CLAUDE.md）。
  同時告知也可考慮：
  - 執行「更新知識庫」（update）：保留自訂內容，更新 plugin 設定
  - 執行「重置知識庫」（reset）：完全重新生成所有設定
- 若輸出 `NOT_INITIALIZED` 或路徑不存在：直接繼續

---

## 階段 3：檢查依賴

執行依賴檢查腳本：

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/check-deps.sh
```

解讀結果：

- 輸出 `INSTALLED`：繼續執行
- 輸出 `NOT_INSTALLED`：告知使用者並等待安裝：
  > 需要先安裝 `obsidian-skills` plugin 才能使用完整功能：
  > ```
  > /plugin marketplace add kepano/obsidian-skills
  > /plugin install obsidian@obsidian-skills
  > ```
  > 安裝完成後請告訴我，我們繼續建立流程。
- 輸出 `NOT_FOUND`：告知使用者可能是全新環境，引導安裝上述 plugins。

---

## 階段 4：建立知識庫

### 步驟 4-1：建立資料夾結構

讀取 `${CLAUDE_PLUGIN_ROOT}/references/folder-structure.md` 了解完整規格。

在 Vault 根目錄確保以下資料夾存在（不存在則建立，已存在略過）：

```
歷史紀錄/對話/
主題知識/
templates/
```

### 步驟 4-2：建立模板檔案

讀取 `${CLAUDE_PLUGIN_ROOT}/references/templates-spec.md` 了解完整規格。

在 `templates/` 目錄建立以下 2 個模板（不存在則建立，已存在略過）：

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

### 步驟 4-3：生成 CLAUDE.md

讀取 `${CLAUDE_PLUGIN_ROOT}/references/claude-md-template.md` 模板，
將以下佔位符替換為實際值：

- `{{vault_name}}` → vault 資料夾名稱
- `{{vault_path}}` → 主要存取路徑（Linux/macOS 絕對路徑）
- `{{vault_path_windows_line}}` → 若有 Windows 路徑則替換為 `vault_path_windows: C:\...`；否則移除此整行
- `{{plugin_version}}` → 從 plugin.json 讀取的版本號

**注意**：若 Vault 根目錄已有 `CLAUDE.md`，先確認使用者是否要覆蓋，確認後才寫入。

### 步驟 4-4：對齊 .obsidian 設定

> 注意：obsidian CLI 不支援 `.obsidian` 設定檔的讀寫，此步驟維持直接操作 JSON 檔案。

檢查 Vault 根目錄是否有 `.obsidian/` 資料夾：

若**存在**，執行以下對齊：

**a. `templates.json`**（確保 templates 插件指向正確資料夾）：
```json
{
  "folder": "templates",
  "dateFormat": "YYYY-MM-DDTHH:mm",
  "timeFormat": "HH:mm"
}
```
- 若不存在：直接寫入
- 若已存在：僅更新 `folder`、`dateFormat`、`timeFormat`，保留其餘欄位

**b. `app.json`**（新筆記預設落在主題知識）：
需確保包含：
```json
{
  "newFileLocation": "folder",
  "newFileFolderPath": "主題知識"
}
```
- 若不存在：寫入含上述欄位的新檔
- 若已存在：僅更新這兩個欄位，保留其餘欄位

**c. `core-plugins.json`**（確保 templates 插件啟用）：
確保 `"templates": true`。

若 `.obsidian/` **不存在**：略過此步驟，並在完成摘要中說明。

---

## 階段 5：完成通知與全域設定

### 告知建立結果

告知使用者知識庫已建立在指定路徑。

### 詢問全域設定

詢問使用者：

> 是否要將此知識庫（`[vault_name]`）記錄到全域提示詞（`~/.claude/CLAUDE.md`）？
>
> 這樣 Claude 在所有專案中都能知道此知識庫的存在與路徑。

若使用者確認，讀取 `~/.claude/CLAUDE.md`，檢查是否已有 `## Vault: [vault_name]` 區塊：

- 若**已存在**：告知已記錄，略過
- 若**不存在**：附加以下內容至 `~/.claude/CLAUDE.md` 尾端（不覆蓋既有內容）：

```markdown
## Vault: [vault_name]

vault_path: [vault_path]
```

若 WSL2 環境，額外加上：
```markdown
vault_path_windows: [vault_path_windows]
```

### Obsidian 安裝提示

提示使用者：

> 若尚未安裝 Obsidian 應用程式，請至 https://obsidian.md 下載安裝。
> 安裝後，在 Obsidian 中選擇「開啟資料夾作為 Vault」，選取 `[vault_path]` 即可使用。

---

## 階段 6：完成摘要

列出所有已建立的項目：

```
✓ 資料夾結構建立完成（歷史紀錄/對話/、主題知識/、templates/）
✓ 模板檔案建立完成（templates/ 目錄下 2 個模板：來源記錄、知識筆記）
✓ CLAUDE.md 已生成（plugin v[version]）
✓ .obsidian 設定已對齊（或：.obsidian 尚未建立，Obsidian 首次開啟後可重新執行）
✓ 全域 CLAUDE.md 已記錄此 Vault

Vault 已就緒。可用的 skills：
- archive：歸檔任何來源（對話、URL、文章、YouTube 等）時觸發，同時產生來源記錄與知識筆記
- knowledge-archive：只要知識整理、不需來源記錄時觸發
- record-archive：只要來源記錄、不需知識整理時觸發
- tag-review：歸檔時自動呼叫，確保標籤品質
- social-scraper：抓取 Facebook、YouTube 等社群媒體內容
```

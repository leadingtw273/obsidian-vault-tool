# CLI 寫入管道規範

本規格定義 obsidian-vault-tool plugin 的兩套寫入管道及其使用邊界。

---

## 前提條件

- Obsidian 應用程式必須正在執行
- 目標 Vault 必須已在 Obsidian 中開啟（`obsidian vaults` 可確認）
- WSL 環境需要 sandbox 設定 `allowAllUnixSockets: true`（見 `~/.claude/settings.json`）

> ⚠️ 若 Vault 未在 Obsidian 中開啟，CLI 的 create/read 會回報成功但檔案不在預期位置（幻影操作）。

---

## 管道 1：obsidian CLI（日常歸檔操作）

所有 archive / record-writer / wiki-writer / query skill 的寫入操作，一律使用 obsidian CLI。

> ⚠️ **`vault=` 必須放在 `content=` 之前。** 建議格式：`obsidian [command] vault=X path=... content=...`。若 vault= 放在 content= 之後且 content 含 `---`，命令會靜默失敗。

### 可用命令

| 命令 | 用途 | 範例 |
|---|---|---|
| `create` | 新建筆記，可加 `overwrite` 覆寫既有 | `obsidian create vault=X path="x.md" content="..." overwrite` |
| `append` | 在檔案尾端追加內容 | `obsidian append vault=X path="x.md" content="..."` |
| `prepend` | 在 frontmatter 後、正文前插入 | `obsidian prepend vault=X path="x.md" content="..."` |
| `search` | 搜尋 Vault 內容 | `obsidian search vault=X query="RAG"` |
| `tags counts` | 查詢標籤統計 | `obsidian tags vault=X counts` |
| `orphans` | 列出無反向連結的檔案 | `obsidian orphans vault=X` |
| `backlinks` | 列出指定檔案的反向連結 | `obsidian backlinks vault=X file="Note"` |
| `unresolved` | 列出未解決的 wikilink | `obsidian unresolved vault=X` |
| `deadends` | 列出無外向連結的檔案 | `obsidian deadends vault=X` |
| `properties` | 列出 vault 或檔案的 frontmatter | `obsidian properties vault=X file="Note"` |
| `links` | 列出檔案的外向連結 | `obsidian links vault=X file="Note"` |

### content= 安全規則

| 規則 | 說明 |
|---|---|
| 多行 | 使用 `\n` 表示換行，`\t` 表示 tab |
| 雙引號 | 使用 `\"` 跳脫 |
| 反引號 | 使用 `` \` `` 跳脫 |
| 美元符號 | 使用 `\$` 跳脫 |
| 反斜線 | 使用 `\\` 跳脫 |
| 長度上限 | 單次 content= 建議不超過 **16KB**（實測上限），超長內容改分段 append |
| 超過上限 | 先 `create` 寫入前段，再分段 `append` 剩餘部分 |

### 不存在的命令（禁止使用）

- ~~`obsidian update`~~：官方 CLI 無此命令
- ~~`content_file=`~~：官方 CLI 無此參數（為已刪除的 wsl-powershell-bridge 私有協議）

---

## 已知 Bug（Obsidian 1.12.7）

`obsidian property:set` 與 `obsidian property:read` 在 Obsidian 1.12.7 中 exit 0 但不修改檔案，屬於 CLI 本身的 bug。**禁止使用這兩個命令**，請改用下方的 eval + processFrontMatter workaround。

---

## Frontmatter 操作：eval + processFrontMatter

所有 frontmatter 寫入操作一律透過 `eval` 搭配 `processFrontMatter`。

### 標準語法

**設定單一文字／日期欄位**：
```bash
obsidian eval vault=X code="app.fileManager.processFrontMatter(app.vault.getAbstractFileByPath('[path]'), fm => { fm.[key] = '[value]'; })"
```

**設定陣列欄位**：
```bash
obsidian eval vault=X code="app.fileManager.processFrontMatter(app.vault.getAbstractFileByPath('[path]'), fm => { fm.tags = ['a','b','c']; })"
```

**設定含 wikilink 的陣列**：
```bash
obsidian eval vault=X code="app.fileManager.processFrontMatter(app.vault.getAbstractFileByPath('[path]'), fm => { fm.sources = ['[[record1]]','[[record2]]']; })"
```

### 讀取驗證

`eval` 執行後，使用 `properties` 命令驗證結果（此命令正常）：
```bash
obsidian properties vault=X file="[檔名（不含 .md）]"
```

### 注意事項

- `eval` 是**覆寫語意**（非追加）。若需累積陣列（如 sources、aliases、tags），需先用 Read 工具讀取現有 frontmatter 值，合併去重後再用 eval 寫回
- path 參數使用相對於 Vault 根目錄的路徑，例如 `主題知識/實體/Claude.md`
- value 中的單引號需以 `\'` 跳脫（在 bash 字串內）

---

## 管道 2：Claude Code 原生 Read/Edit/Write（lint 維護操作）

僅限 **lint skill** 的自動修補操作使用。

### 可用工具

| 工具 | 用途 |
|---|---|
| Read | 讀取 md 檔（驗證 frontmatter、取得既有內容、lint 掃描） |
| Edit | 字串置換（交叉連結修補、矛盾註記從尾端搬到對應段落旁） |
| Write | 整檔重寫（lint 的 index.md 重建、去重清理） |

### 使用邊界

- **僅限 lint skill** 的自動修補操作（使用者明確觸發後）
- archive / record-writer / wiki-writer / query skill **禁止使用** Edit / Write
- 所有 skill / agent 都可以使用 **Read**（讀取不受限）

### 為什麼需要管道 2？

obsidian CLI 無法修改檔案正文中間的內容（沒有 replace / edit 命令）。以下操作只能靠 Read/Edit：
- 既有頁正文中交叉連結的回溯修補
- 矛盾註記從檔案尾端搬移到對應段落旁
- index.md 的去重清理（需整檔讀取後重建）

---

## 驗證操作

所有 skill / agent 的驗證（讀取 frontmatter 確認格式）使用 **Read 工具直讀 md 檔**，不走 obsidian CLI。

# CLI 寫入管道規範

本規格定義 obsidian-vault-tool plugin 的寫入管道及其使用邊界。

---

## 寫入模式（cli_write_mode，v0.9.1 新增）

本 plugin 支援兩種 vault 級寫入模式，由 vault CLAUDE.md 的 `cli_write_mode` 欄位決定：

| 值 | 行為 | 適用情境 |
|---|---|---|
| `cli_first`（預設）| 所有寫入（create / append / eval + processFrontMatter）走 obsidian CLI | Obsidian 主程式與 obsidian CLI 之間 IPC 健全的環境 |
| `native_only` | 全面禁用 obsidian CLI 寫入操作；改用 Claude Code 原生 Read/Edit/Write；CLI 僅用於讀取（version / list / search / properties / orphans 等）| 已知環境會因 obsidian CLI 訊息序列化 bug 弄崩 Obsidian 主程式（例如 Obsidian 1.12.7 + 中文檔名）|

> **取得 mode**：所有 SKILL.md 在共用前置 step 讀取 vault CLAUDE.md 的 `cli_write_mode`（缺欄位視為 `cli_first` 以相容 v0.9.0 vault），並傳入每個 sub-agent 的 prompt。
> **寫入點處理**：sub-agent / 主對話收到 `cli_write_mode` 後，依下方 Mode 對照表決定走 CLI 或 Native。spec 檔內各處的 `obsidian create / append / eval` 範例**僅適用於 `cli_first`**；`native_only` 模式統一以對照表替代。

### Mode 對照表

| 操作 | `cli_first`（CLI 命令）| `native_only`（Native 工具）|
|---|---|---|
| **新建檔案（含 frontmatter）** | `obsidian create vault=X path=Y content="..."` | `Write(Y, "...")` |
| **覆寫整檔** | `obsidian create vault=X path=Y content="..." overwrite` | `Write(Y, "...")` |
| **追加內容到檔尾** | `obsidian append vault=X path=Y content="..."` | 用 `Read(Y)` 確認最末一行作為錨點（或讀末尾數行），用 `Edit(Y, anchor, anchor + "\n" + new)` 插入；首次 append 到空檔可直接 `Write` |
| **在 frontmatter 後、正文前插入** | `obsidian prepend vault=X path=Y content="..."` | `Read(Y)` 找出第二個 `---` 結束行，用 `Edit` 在該行後插入 |
| **修改 frontmatter 單欄位** | `obsidian eval ... fm.[key] = '[value]'` | `Read(Y)` 取得該行（如 `updated: 2026-04-09`），`Edit` 改該行 |
| **修改 frontmatter 陣列（覆寫）** | `obsidian eval ... fm.tags = ['a','b','c']` | `Read(Y)` 取得 yaml block，`Edit` 改該欄位整個 yaml 區段 |
| **修改 frontmatter 陣列（累積）** | 先 `Read` 取舊值合併去重，再 `obsidian eval ... fm.sources = [...]` | 同左半步驟，但用 `Edit` 寫回該欄位區段 |

### Native 模式注意事項

- **append 不能直接 `Write` 整檔**：除非檔案是首次建立且能完整重寫，否則用 `Read` 取末尾錨點 + `Edit` 插入更安全（避免覆寫他人並行修改）
- **檔案首次新建**：`Write` 是 idempotent，且若檔案不存在會自動建立；若已存在會覆寫，必要時先 `Glob` 或 `Read` 確認是否存在
- **frontmatter 區段定位**：第一行為 `---`，找下一個 `---` 行就是 frontmatter 結束
- **長內容（>16KB）**：Native 模式無 16KB 限制（`Write` 接受任意長度），可一次寫完
- **不需要 Obsidian 主程式運行**：Native 模式是 fs syscall 直接操作 .md 檔，與 Obsidian 主程式無關；下次 Obsidian 啟動時會自動重新索引

---

## 前提條件

### `cli_first` 模式下

- Obsidian 應用程式必須正在執行
- 目標 Vault 必須已在 Obsidian 中開啟（`obsidian vaults` 可確認）
- WSL 環境需要 sandbox 設定 `allowAllUnixSockets: true`（見 `~/.claude/settings.json`）

> ⚠️ 若 Vault 未在 Obsidian 中開啟，CLI 的 create/read 會回報成功但檔案不在預期位置（幻影操作）。

### `native_only` 模式下

- Obsidian 應用程式**不需要**執行（plugin 寫入不依賴主程式）
- vault_path 必須是 Claude Code 可達的 fs 路徑
- 讀取類 CLI 命令（version / list / search 等）若需要 Obsidian 運行，仍適用前面條件；可改用 `Glob` / `Bash grep` 替代

---

## 管道 1：obsidian CLI 命令清單（cli_first 模式）

> **`native_only` 模式下，本節列出的所有「寫入命令」（create / append / prepend / eval）都改用 Native 工具**，見上方 Mode 對照表。讀取命令（search / orphans / backlinks / unresolved / files / properties / links 等）不受影響，可繼續使用。

> ⚠️ **`vault=` 必須放在 `content=` 之前。** 建議格式：`obsidian [command] vault=X path=... content=...`。若 vault= 放在 content= 之後且 content 含 `---`，命令會靜默失敗。

### 可用命令

| 命令 | 用途 | 範例 | native_only 對應 |
|---|---|---|---|
| `create` | 新建筆記，可加 `overwrite` 覆寫既有 | `obsidian create vault=X path="x.md" content="..." overwrite` | `Write` |
| `append` | 在檔案尾端追加內容 | `obsidian append vault=X path="x.md" content="..."` | `Read` 末尾 + `Edit` 插入 |
| `prepend` | 在 frontmatter 後、正文前插入 | `obsidian prepend vault=X path="x.md" content="..."` | `Read` frontmatter + `Edit` 插入 |
| `search` | 搜尋 Vault 內容 | `obsidian search vault=X query="RAG"` | 不受影響（讀取） |
| `tags counts` | 查詢標籤統計 | `obsidian tags vault=X counts` | 不受影響（讀取） |
| `orphans` | 列出無反向連結的檔案 | `obsidian orphans vault=X` | 不受影響（讀取） |
| `backlinks` | 列出指定檔案的反向連結 | `obsidian backlinks vault=X file="Note"` | 不受影響（讀取） |
| `unresolved` | 列出未解決的 wikilink | `obsidian unresolved vault=X` | 不受影響（讀取） |
| `deadends` | 列出無外向連結的檔案 | `obsidian deadends vault=X` | 不受影響（讀取） |
| `files` | 列出 Vault 中的檔案 | `obsidian files vault=X` | 不受影響（讀取，亦可用 `Glob`）|
| `properties` | 列出 vault 或檔案的 frontmatter | `obsidian properties vault=X file="Note"` | 不受影響；`native_only` 模式下也可用 `Read` 直讀 |
| `links` | 列出檔案的外向連結 | `obsidian links vault=X file="Note"` | 不受影響（讀取） |

### content= 安全規則（cli_first）

| 規則 | 說明 |
|---|---|
| 多行 | 使用 `\n` 表示換行，`\t` 表示 tab |
| 雙引號 | 使用 `\"` 跳脫 |
| 反引號 | 使用 `` \` `` 跳脫 |
| 美元符號 | 使用 `\$` 跳脫 |
| 反斜線 | 使用 `\\` 跳脫 |
| 長度上限 | 單次 content= 建議不超過 **16KB**（實測上限），超長內容改分段 append |
| 超過上限 | 先 `create` 寫入前段，再分段 `append` 剩餘部分 |

> `native_only` 模式下無上述跳脫需求（Write 直接接收原始字串），無 16KB 上限。

### 不存在的命令（禁止使用）

- ~~`obsidian update`~~：官方 CLI 無此命令
- ~~`content_file=`~~：官方 CLI 無此參數（為已刪除的 wsl-powershell-bridge 私有協議）

---

## 已知 Bug（Obsidian 1.12.7）

### `property:set` / `property:read`

`obsidian property:set` 與 `obsidian property:read` 在 Obsidian 1.12.7 中 exit 0 但不修改檔案，屬於 CLI 本身的 bug。**禁止使用這兩個命令**，請改用下方的 eval + processFrontMatter workaround（cli_first）或 Native Edit（native_only）。

### IPC 訊息序列化崩潰（v0.9.1 新增記錄）

在 Obsidian 1.12.7 + obsidian CLI 1.12.7 環境下，多個 CLI 寫入訊息（含單一 process 內的多訊息序列、或並行多 CLI process）打到同一 IPC pipe 時，主程式 `JSON.parse` 經常失敗並崩潰跳 dialog，錯誤訊息形如：

```
SyntaxError: Unexpected token ']', ..."RA 訓練.md"],"tty":fa"... is not valid JSON
  at JSON.parse (<anonymous>)
  at Socket.n (...obsidian.asar:136)
```

**根因**：Obsidian 主程式的 IPC handler 直接對 chunk 做 `JSON.parse`，沒做訊息分割（NDJSON / length-prefix）與 chunk 拼接（UTF-8 多 byte 字元邊界處理）。中文檔名因 UTF-8 編碼長度（每字 3 bytes）特別容易卡在 chunk 邊界，並行寫入則會讓多訊息合併到單一 chunk。

**處置**：受影響的環境（如 Obsidian 1.12.7 + 中文檔名密集的 vault）應將 vault CLAUDE.md 的 `cli_write_mode` 設為 `native_only`，全面避開 CLI 寫入路徑。讀取類 CLI 命令未觀察到此問題，可保留。

---

## Frontmatter 操作：eval + processFrontMatter（cli_first 模式）

> **`native_only` 模式下，本節所有 eval 命令一律改用 `Read` + `Edit`** — 見上方 Mode 對照表。

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

`native_only` 模式下，直接用 `Read` 工具讀取 .md 檔的 frontmatter。

### 注意事項

- `eval` 是**覆寫語意**（非追加）。若需累積陣列（如 sources、aliases、tags），需先用 Read 工具讀取現有 frontmatter 值，合併去重後再用 eval 寫回
- path 參數使用相對於 Vault 根目錄的路徑，例如 `主題知識/實體/Claude.md`
- value 中的單引號需以 `\'` 跳脫（在 bash 字串內）

---

## 管道 2：Claude Code 原生 Read/Edit/Write

### 適用情境（v0.9.1 起調整）

| 情境 | cli_first | native_only |
|---|---|---|
| curator skill 的自動修補（正文修補、index.md 重建、矛盾搬移）| ✅ 一律使用 | ✅ 一律使用 |
| archive / record-writer / wiki-writer / query 的寫入操作 | ❌ 改用 CLI（管道 1）| ✅ 全部改用 Native（依 Mode 對照表） |
| 所有 skill / agent 的讀取（驗證 frontmatter / 取得既有內容 / 掃描）| ✅ 可用 Read（不受限）| ✅ 可用 Read（不受限）|

### 可用工具

| 工具 | 用途 |
|---|---|
| Read | 讀取 md 檔（驗證 frontmatter、取得既有內容、curator 掃描）|
| Edit | 字串置換（交叉連結修補、矛盾註記從尾端搬到對應段落旁；native_only 模式下也用於 frontmatter 單欄位修改與 append 行為）|
| Write | 整檔重寫（curator 的 index.md 重建、去重清理；native_only 模式下也用於新建檔案、覆寫整檔）|

### 為什麼需要管道 2？

obsidian CLI 無法修改檔案正文中間的內容（沒有 replace / edit 命令）。以下操作只能靠 Read/Edit：
- 既有頁正文中交叉連結的回溯修補
- 矛盾註記從檔案尾端搬移到對應段落旁
- index.md 的去重清理（需整檔讀取後重建）

`native_only` 模式進一步把所有寫入操作都納入管道 2。

---

## 驗證操作

所有 skill / agent 的驗證（讀取 frontmatter 確認格式）使用 **Read 工具直讀 md 檔**，不走 obsidian CLI。

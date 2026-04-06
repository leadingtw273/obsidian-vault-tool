# CLI 寫入管道規範

本規格定義 obsidian-vault-tool plugin 的兩套寫入管道及其使用邊界。

---

## 管道 1：obsidian CLI（日常歸檔操作）

所有 archive / record-writer / wiki-writer / query skill 的寫入操作，一律使用 obsidian CLI。

### 可用命令

| 命令 | 用途 | 範例 |
|---|---|---|
| `create` | 新建筆記，可加 `overwrite` 覆寫既有 | `obsidian create path="x.md" content="..." overwrite` |
| `append` | 在檔案尾端追加內容 | `obsidian append path="x.md" content="..."` |
| `prepend` | 在 frontmatter 後、正文前插入 | `obsidian prepend path="x.md" content="..."` |
| `property:set` | 設定 frontmatter 欄位 | `obsidian property:set path="x.md" name=updated value=2026-04-06 type=date` |
| `property:remove` | 刪除 frontmatter 欄位 | `obsidian property:remove path="x.md" name=status` |
| `search` | 搜尋 Vault 內容 | `obsidian search query="RAG"` |
| `tags counts` | 查詢標籤統計 | `obsidian tags counts` |

### content= 安全規則

| 規則 | 說明 |
|---|---|
| 多行 | 使用 `\n` 表示換行，`\t` 表示 tab |
| 雙引號 | 使用 `\"` 跳脫 |
| 反引號 | 使用 `` \` `` 跳脫 |
| 美元符號 | 使用 `\$` 跳脫 |
| 反斜線 | 使用 `\\` 跳脫 |
| 長度上限 | 單次 content= 不超過 **4KB**（約 1500 中文字） |
| 超過上限 | 先 `create` 寫入前半段，再分段 `append` 剩餘部分 |

### 不存在的命令（禁止使用）

- ~~`obsidian update`~~：官方 CLI 無此命令
- ~~`content_file=`~~：官方 CLI 無此參數（為已刪除的 wsl-powershell-bridge 私有協議）

### property:set 陣列欄位

設定陣列類型欄位（如 `tags`、`aliases`、`sources`）時，使用 `type=list`：

```bash
obsidian property:set path="x.md" name=aliases value="別名1,別名2" type=list
obsidian property:set path="x.md" name=sources value="[[記錄1]],[[記錄2]]" type=list
```

> 注意：`property:set` 是**覆寫語意**（非追加）。若需累積陣列，先用 Read 讀取現有值 → 合併去重 → 再 property:set 寫回。

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

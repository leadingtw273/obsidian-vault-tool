# obsidian-vault-tool

Obsidian Vault 知識庫管理工具，作為 Claude Code Plugin 分發。

以「資料 vs 資訊」為核心，將對話與外部資源萃取為結構化知識，沉澱至 Obsidian Vault。

## 功能

- **`/vault-tool`**：知識庫管理工具，支援四種操作：
  - **init**：初始化 Vault 結構、模板、`.obsidian` 設定，並生成 CLAUDE.md
  - **update**：更新 plugin 設定至最新版本（保留使用者自訂內容）
  - **reset**：重置所有 plugin 管理的設定與模板（筆記不受影響）
  - **delete**：移除管理設定或刪除整個 Vault
- **`session-archive` skill**：將當前對話歸檔，萃取知識主題，寫入知識筆記與對話筆記
- **`knowledge-archive` skill**：將外部資源（URL、文章、影片等）萃取精華後歸檔至主題知識
- **`tag-review` skill**：歸檔時的標籤品質控制子任務

## 知識庫架構

```
vault/
├── 歷史紀錄/
│   └── 對話/               # 對話筆記（session-archive 寫入）
│       └── YYYY-MM-DD/
├── 主題知識/                # 知識筆記（兩種 archive 均寫入）
│   └── YYYY-MM-DD/
└── templates/
    ├── 對話筆記.md
    └── 知識筆記.md
```

### 兩種歸檔類型

| 類型 | Skill | 觸發情境 | 流程 |
|------|-------|---------|------|
| **SessionArchive** | `session-archive` | 「歸檔這次對話」、「總結對話」 | 獲取對話 → 分析 → 知識筆記×N（平行）→ 對話筆記 |
| **SourceArchive** | `knowledge-archive` | 貼上 URL、「幫我整理這個」 | 獲取內容 → 分析 → 知識筆記×N（平行） |

## 前置需求

- Claude Code CLI
- `kepano/obsidian-skills` plugin（含 obsidian-cli、obsidian-markdown、defuddle）

## 安裝

### 手動安裝

**Step 1：Clone 專案**

```bash
git clone https://github.com/leadingtw/obsidian-vault-tool ~/.claude/plugins/obsidian-vault-tool
```

**Step 2：將 skills 連結至 Claude Code 載入目錄**

```bash
mkdir -p ~/.claude/skills
ln -s ~/.claude/plugins/obsidian-vault-tool/skills/* ~/.claude/skills/
```

> **為什麼需要這步驟？**
> Claude Code 只會自動載入 `~/.claude/skills/` 目錄下的 skills，單純 clone 到 `~/.claude/plugins/` 並不會觸發自動掃描。透過建立 symbolic link，skills 實體仍在 plugin 目錄中（方便日後 `git pull` 更新），但 Claude Code 可以從 `~/.claude/skills/` 正常讀取。

**Step 3：安裝依賴**

```
/plugin marketplace add kepano/obsidian-skills
/plugin install obsidian@obsidian-skills
```

### 更新

```bash
cd ~/.claude/plugins/obsidian-vault-tool
git pull
```

Skills 的 symlink 不需重建，更新會直接反映。

## 使用方式

在 Obsidian vault 目錄中啟動 Claude Code 後執行：

```
/vault-tool
```

系統會根據您的意圖自動選擇操作，或列出選單供您選擇：

```
/vault-tool init    # 建立全新知識庫
/vault-tool update  # 更新現有知識庫設定
/vault-tool reset   # 重置所有設定
/vault-tool delete  # 刪除管理設定或整個 Vault
```

初始化完成後，skills 會在對應情境下自動觸發：

- 說「歸檔這次對話」→ `session-archive`（4 步流程）
- 貼上 URL 說「幫我整理這個」→ `knowledge-archive`（3 步流程）
- 歸檔操作中 → `tag-review`（由其他 skills 自動呼叫）

## 版本

`0.2.0` — 重構知識庫架構，移除 Playground 概念，改採 SessionArchive / SourceArchive 雙軌歸檔

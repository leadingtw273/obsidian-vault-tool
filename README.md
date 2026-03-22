# obsidian-vault-tool

Obsidian Vault 知識庫管理工具，作為 Claude Code Plugin 分發。

以「資料 vs 資訊」為核心，將對話與外部資源萃取為結構化知識，沉澱至 Obsidian Vault。

## 功能

- **`/vault-tool`**：知識庫管理工具，支援四種操作：
  - **init**：初始化 Vault 結構、模板、`.obsidian` 設定，並生成 CLAUDE.md
  - **update**：更新 plugin 設定至最新版本（保留使用者自訂內容）
  - **reset**：重置所有 plugin 管理的設定與模板（筆記不受影響）
  - **delete**：移除管理設定或刪除整個 Vault
- **`archive` skill**：完整歸檔主入口，同時產生來源記錄（歷史紀錄/）與知識筆記（主題知識/），支援對話、YouTube、Facebook、文章、PDF、網頁等所有來源
- **`record-archive` skill**：只建立來源記錄，不萃取知識筆記
- **`knowledge-archive` skill**：只萃取知識筆記，不建立來源記錄
- **`tag-review` skill**：歸檔時的標籤品質控制，由 archive / knowledge-archive 自動呼叫
- **`social-scraper` skill**：透過 Playwright MCP 從 Facebook、YouTube 等社群平台抓取最新貼文與影片內容；歸檔社群 URL 時由 record-writer 自動呼叫

## 知識庫架構

```
vault/
├── 歷史紀錄/
│   ├── 對話/               # 來源記錄（conversation），初始化時建立
│   ├── YouTube/            # 來源記錄（youtube），動態建立
│   ├── Facebook/           # 來源記錄（fb-post），動態建立
│   ├── 文章/               # 來源記錄（article），動態建立
│   ├── 文件/               # 來源記錄（pdf），動態建立
│   └── 網頁/               # 來源記錄（webpage），動態建立
│       └── YYYY-MM-DD/     # 子資料夾，檔名 [序號]_[概述].md
├── 主題知識/                # 知識筆記（archive / knowledge-archive 寫入）
│   └── YYYY-MM-DD/
└── templates/
    ├── 來源記錄.md
    └── 知識筆記.md
```

### 三種歸檔 skill

| Skill | 觸發情境 | 產出 |
|-------|---------|------|
| **`archive`** | 「歸檔這次對話」、「把這個存到知識庫」、貼上 URL | 來源記錄 + 知識筆記（雙向 wikilink） |
| **`record-archive`** | 「只記錄這個來源」、「只要來源記錄」 | 來源記錄（無知識筆記） |
| **`knowledge-archive`** | 「只要知識整理」、「不需來源記錄」 | 知識筆記（無來源記錄） |

### archive 執行架構

```
archive skill
├─ record-writer agent（內容獲取 + 分析 + 建立來源記錄）
└─ knowledge-writer agent × N（平行，從來源記錄讀取原文，撰寫知識筆記）
```

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

- 說「歸檔這次對話」或貼上 URL 說「幫我整理這個」→ `archive`（完整歸檔）
- 說「只要知識整理」→ `knowledge-archive`
- 說「只要來源記錄」→ `record-archive`
- 歸檔操作中 → `tag-review`（由其他 skill 自動呼叫）
- 說「抓取內容」「初始化社群抓取」→ `social-scraper`（Facebook / YouTube 爬取）

## 版本

`0.3.0` — 重構歸檔架構，引入 archive 主 skill + custom agent 兩階段設計（record-writer → knowledge-writer × N），統一來源記錄（支援對話/YouTube/Facebook 等全類型），移除 session-archive

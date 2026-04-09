# obsidian-vault-tool

Obsidian Vault 知識庫管理工具，作為 Claude Code Plugin 分發。

以「資料 vs 資訊」為核心，將對話與外部資源萃取為結構化知識，沉澱至 Obsidian Vault。

## 功能

- **`/vault-tool`**：知識庫管理工具，支援四種操作：
  - **init**：初始化 Vault 結構、模板、`.obsidian` 設定，並生成 CLAUDE.md
  - **update**：更新 plugin 設定至最新版本（保留使用者自訂內容）
  - **reset**：重置所有 plugin 管理的設定與模板（筆記不受影響）
  - **delete**：移除管理設定或刪除整個 Vault
- **`archive` skill**：完整歸檔主入口，同時產生來源記錄（歷史紀錄/）與知識筆記（主題知識/），支援對話、YouTube、Facebook、文章、PDF、網頁等所有來源。提供三種模式：
  - **full-archive**（預設）：來源記錄 + 知識筆記
  - **record-only**：只建立來源記錄，不萃取知識筆記
  - **knowledge-only**：只萃取知識筆記，不建立來源記錄
- **`tag-review` skill**：標籤品質控制，由使用者手動觸發
- **`query` skill**：對 Wiki（主題知識/）提問，讀取相關主題頁綜合回答，可選擇回填為總覽筆記
- **`curator` skill**：Wiki 策展人，健康檢查（孤兒頁面、缺失交叉引用、過期條目、index.md 一致性）+ 主題結構升級偵測與執行

## 知識庫架構

```
vault/
├── raw/                    # 待歸檔原始檔案
│   └── archived/           # 已歸檔的 raw 原檔（mv 保留）
├── 歷史紀錄/
│   ├── 對話/               # 來源記錄（conversation），初始化時建立
│   ├── YouTube/            # 來源記錄（youtube），動態建立
│   ├── Facebook/           # 來源記錄（fb-post），動態建立
│   ├── 文章/               # 來源記錄（article），動態建立
│   ├── 文件/               # 來源記錄（pdf），動態建立
│   └── 網頁/               # 來源記錄（webpage），動態建立
│       └── YYYY-MM-DD/     # 子資料夾，檔名 [序號]_[概述].md
├── 主題知識/                # 知識筆記（archive / knowledge-only 寫入）
│   ├── 實體/               # wiki_category: 實體
│   ├── 概念/               # wiki_category: 概念
│   ├── 比較/               # wiki_category: 比較
│   └── 總覽/               # wiki_category: 總覽
├── index.md                # Wiki 主題頁 append-only 目錄清單
├── log.md                  # 操作紀錄（append-only）
└── templates/
    ├── raw.md
    ├── 來源記錄.md
    └── 知識筆記.md
```

### 三種歸檔 skill

| Skill | 觸發情境 | 產出 |
|-------|---------|------|
| **`archive`**（full） | 「歸檔這次對話」、「把這個存到知識庫」、貼上 URL | 來源記錄 + 知識筆記（雙向 wikilink） |
| **`archive`**（record-only） | 「只記錄這個來源」、「只要來源記錄」 | 來源記錄（無知識筆記） |
| **`archive`**（knowledge-only） | 「只要知識整理」、「不需來源記錄」 | 知識筆記（無來源記錄） |

### archive 執行架構

```
archive skill
├─ record-writer agent（內容獲取 + 分析 + 建立來源記錄）
└─ wiki-writer agent × N（平行，從 raw/archived/ 讀取原文，撰寫知識筆記）
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
- 說「只要知識整理」→ `knowledge-only`
- 說「只要來源記錄」→ `record-only`
- 說「檢查標籤」「tag review」→ `tag-review`（標籤品質控制）
- 說「查一下 X」「wiki 裡有沒有」「整理一下 X 主題」→ `query`（Wiki 問答）
- 說「lint」「wiki 體檢」「檢查 wiki」「整理 wiki」「升級主題」→ `curator`（健康檢查 + 結構演進）

## 版本

`0.6.0` — Wiki 主題層級機制 + curator skill：引入動態層級（單頁→目錄結構，最深 3 層）、lint 重命名為 curator（策展人：巡檢 + 結構演進）、wiki-writer 簡化為只往上增加、record-writer 輸出樹狀結構

`0.5.1` — 全盤審查修復：修正 full-archive 時序 bug（wiki-writer 讀取 raw 路徑）、放寬 vault-tool/lint allowed-tools 限制、delete hard 模式加引號與二次確認、統一 GitHub URL、修正 README 描述與 cli-usage 補齊 `files` 命令、清理死碼與過時引用

`0.5.0` — 新增 query（Wiki 問答回填）與 lint（健康檢查）skill；刪除 social-scraper 與 wsl-powershell-bridge；重寫 wiki-writer agent 支援 6 層 fallback 主題匹配；新增 9 份 reference spec（cli-usage、index-spec、log-spec、topic-matching-spec、wiki-category-spec 等）

`0.4.0` — 整合歸檔流程，統一為 archive skill 三模式架構（full / record-only / knowledge-only）

`0.3.0` — 重構歸檔架構，引入 archive 主 skill + custom agent 兩階段設計（record-writer → wiki-writer × N），統一來源記錄（支援對話/YouTube/Facebook 等全類型），移除 session-archive

# Obsidian Vault — 規格說明

本 Vault 由 obsidian-vault-tool plugin 管理（v{{plugin_version}}）。
所有流程邏輯由 plugin skills 承載，本檔案僅含靜態定義與狀態。

---

## 初始化狀態

```yaml
initialized: true
vault_name: {{vault_name}}
vault_path: {{vault_path}}
{{vault_path_windows_line}}
plugin_version: {{plugin_version}}
obsidian_cli: obsidian
```

---

## 資料夾結構

```
[vault-name]/
├── raw/                      # 使用者 inbox（Clipper/手動貼入/對話匯出）
│   └── archived/             # 歸檔完成的原始檔案（由主對話從 raw/ 移入）
├── 歷史紀錄/
│   ├── 對話/               # 來源記錄（conversation），按日期子資料夾
│   ├── YouTube/            # 來源記錄（youtube），動態建立
│   ├── Facebook/           # 來源記錄（fb-post），動態建立
│   ├── 文章/               # 來源記錄（article），動態建立
│   ├── 文件/               # 來源記錄（pdf），動態建立
│   └── 網頁/               # 來源記錄（webpage），動態建立
│       └── YYYY-MM-DD/     # 子資料夾，檔名 [序號]_[概述].md
├── 主題知識/                # Wiki 層（扁平分類，upsert 語意）
│   ├── 實體/               # 人物、工具、產品、組織等具體對象
│   ├── 概念/               # 原理、方法論、理論、設計模式
│   ├── 比較/               # 對比分析兩個以上對象的整合頁
│   └── 總覽/               # 主題總論、探索結果
├── index.md                # Wiki 目錄索引（plugin 自動維護）
├── log.md                  # 時間軸日誌（append-only）
└── templates/              # 筆記模板
```

> 歷史紀錄子目錄初始化時只建立 `對話/`，其他子目錄由 `record-writer` agent 依來源類型動態建立。

---

## Frontmatter Schema

### 來源記錄（6 欄位）

存放路徑：`歷史紀錄/[type]/[YYYY-MM-DD]/[序號]_[概述].md`

| 欄位 | 說明 |
|------|------|
| `title` | 來源標題（文章標題、影片標題、對話概述等） |
| `date` | 歸檔日期，格式 `YYYY-MM-DD` |
| `source` | 原始 URL 或對話識別資訊 |
| `category` | 固定 `來源紀錄` |
| `content_type` | `conversation` / `youtube` / `fb-post` / `article` / `pdf` / `webpage` |
| `author` | 原始作者，不適用則留空 |

### 知識筆記（10 欄位）

存放路徑：`主題知識/[wiki_category]/[標題].md`

| 欄位 | 說明 |
|------|------|
| `title` | 筆記標題（Wiki 主題名稱） |
| `date` | 首次建立日期，格式 `YYYY-MM-DD` |
| `updated` | 最後 upsert 日期，格式 `YYYY-MM-DD` |
| `tags` | 中文層級結構標籤，`tags[0]` 為完整路徑 |
| `aliases` | 別名清單（array），含縮寫、中英對照、替代名稱 |
| `sources` | 來源 wikilink 陣列，格式 `"[[來源記錄檔名]]"`；每次 upsert 追加 |
| `category` | 等於 `tags[0]` 第一層（動態） |
| `wiki_category` | `實體` / `概念` / `比較` / `總覽`（依 wiki-category-spec.md 判定） |
| `content_type` | 首次寫入的來源類型 |
| `author` | 首次建立的原始作者 |

> 舊欄位 `source`（單數）保留為回退相容，但主用 `sources`（陣列）。

---

## Tags 規範（三段組合）

1. **層級結構標籤**（1 個）：完整路徑，放 `tags[0]`，如 `技術/AI/LLM`
2. **層級拆解標籤**（2-3 個）：拆開各層，如 `技術`、`AI`、`LLM`
3. **其他描述標籤**（2-5 個）：補充具體主題，如 `提示詞工程`

總數最多 10 個。`tags[0]` 第一層決定 `category`。

---

## Wiki 分類規範

知識筆記依主題性質分為四類，儲存於對應子資料夾。詳細判準請見 `references/wiki-category-spec.md`。

| wiki_category | 定義 | 範例 |
|---------------|------|------|
| `實體` | 人物、工具、產品、組織、地點等具體可指稱的對象 | Obsidian、Anthropic、Claude Code、吳恩達 |
| `概念` | 原理、方法論、理論、設計模式、流程 | LLM、RAG、Prompt Engineering、TDD、LLM Wiki |
| `比較` | 對比分析兩個以上實體或概念的整合頁 | Claude vs GPT、RAG vs LLM Wiki |
| `總覽` | 主題總論、探索結果、橫跨多主題的綜論 | 2026 AI 趨勢、Obsidian 生態圈總論 |

判定流程由 `wiki-writer` agent 在 Step 3 執行，依序確認：具體對象 → 抽象原理 → 對比分析 → 橫跨綜論。

---

## index.md / log.md 規範

### index.md

- **角色**：Wiki 目錄，供 LLM 在歸檔與查詢時快速定位主題頁
- **維護者**：主對話（非 sub-agent，避免並行寫入衝突）
- **更新時機**：每次 archive 完成後、lint 完成後
- **詳細格式**：見 `references/index-spec.md`

### log.md

- **角色**：時間軸日誌，append-only，記錄所有 ingest / query / lint 事件
- **維護者**：主對話
- **格式前綴**：`## [YYYY-MM-DD HH:mm] [type] | [標題]`，type 為 `ingest` / `query` / `lint`
- **詳細格式**：見 `references/log-spec.md`

---

## CLI 寫入管道

本 Vault 的寫入操作分為兩套管道：

- **管道 1（obsidian CLI）**：日常歸檔操作（archive / wiki-writer / query）使用 `create`、`append`、`property:set` 等官方 CLI 命令
- **管道 2（Claude Code Read/Edit/Write）**：lint 維護操作使用原生工具做正文修補

詳細規格見 `references/cli-usage.md`。

---

## 注意事項

- 來源記錄**無 `tags` 欄位**，不執行 tag-review
- 來源記錄無 `aliases`、`status`、`related`、`wiki_category`、`sources` 欄位
- `.obsidian/` 僅修改 `app.json`、`templates.json`、`core-plugins.json`

<!-- vault-tool:managed-end -->

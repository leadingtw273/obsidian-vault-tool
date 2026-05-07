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
interaction_mode: human   # human | agent — 見「Interaction Mode」段落（v0.9.0-alpha 新增）
cli_write_mode: cli_first   # cli_first | native_only — 見「CLI Write Mode」段落（v0.9.1 新增）
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

知識筆記依主題性質分為四類，儲存於對應子資料夾。詳細判準請見 `references/taxonomy/wiki-category-spec.md`。

| wiki_category | 定義 | 範例 |
|---------------|------|------|
| `實體` | 人物、工具、產品、組織、地點等具體可指稱的對象 | Obsidian、Anthropic、Claude Code、吳恩達 |
| `概念` | 原理、方法論、理論、設計模式、流程 | LLM、RAG、Prompt Engineering、TDD、LLM Wiki |
| `比較` | 對比分析兩個以上實體或概念的整合頁 | Claude vs GPT、RAG vs LLM Wiki |
| `總覽` | 主題總論、探索結果、橫跨多主題的綜論 | 2026 AI 趨勢、Obsidian 生態圈總論 |

判定流程由 `wiki-writer` agent 在 Step 3 執行，依序確認：具體對象 → 對比分析 → 橫跨綜論 → 抽象原理（兜底）。

---

## index.md / log.md 規範

### index.md

- **角色**：Wiki 目錄，供 LLM 在歸檔與查詢時快速定位主題頁
- **維護者**：主對話（非 sub-agent，避免並行寫入衝突）
- **更新時機**：每次 archive 完成後、curator 完成後
- **詳細格式**：見 `references/structure/index-spec.md`

### log.md

- **角色**：時間軸日誌，append-only，記錄所有 ingest / query / curator 事件
- **維護者**：主對話
- **格式前綴**：`## [YYYY-MM-DD HH:mm] [type] | [標題]`，type 為 `ingest` / `query` / `curator`
- **詳細格式**：見 `references/structure/log-spec.md`

---

## Interaction Mode（v0.9.0-alpha 新增）

本 Vault 的 `interaction_mode` 欄位決定 plugin 與使用者的互動方式：

| 值 | 適用情境 | 行為 |
|----|---------|------|
| `human` | 人類操作者使用（預設）| 需要決策時暫停請求確認（如 confidence high 升級）|
| `agent` | AI agent 作為長期知識庫使用者 | **不阻塞**，需要人類確認的決策延後寫入 `overview.md` 待 review 清單 |

**切換規則**：
- 修改本檔案的 `interaction_mode` 欄位即可切換
- 切換**只能由人類執行**，agent 不可自我升級或降級
- 切換後自動在 `log.md` 記錄事件
- 切換**不會清除** `overview.md` 的待 review 清單（保留審計軌跡）

詳細機制與各 step 的 fallback 行為見 `references/governance/agent-mode.md`。

> v0.9.0-beta 將為知識筆記新增以下欄位：`confidence`（low/medium/high）、`source_count`、`domain_volatility`、`last_reviewed`、`high_candidate`。詳見 `references/governance/confidence-gating.md`。

---

## CLI Write Mode（v0.9.1 新增）

本 Vault 的 `cli_write_mode` 欄位決定 plugin 的寫入路徑：

| 值 | 適用情境 | 行為 |
|----|---------|------|
| `cli_first`（預設）| obsidian CLI + Obsidian 主程式 IPC 健全的環境 | 日常歸檔操作（archive / wiki-writer / query）走 obsidian CLI（`create` / `append` / `eval + processFrontMatter`）；curator 走 Read/Edit/Write |
| `native_only` | 已知 obsidian CLI 寫入會弄崩 Obsidian 主程式（例如 Obsidian 1.12.7 中文檔名 IPC bug）| 所有寫入操作改用 Claude Code 原生 Read/Edit/Write；CLI 僅用於讀取（version / list / search 等）|

**切換規則**：
- 修改本檔案的 `cli_write_mode` 欄位即可切換
- `native_only` 模式下 Obsidian 主程式不需要執行（plugin 直接操作 .md 檔）
- spec 檔內 `obsidian create / append / eval` 範例僅適用於 `cli_first`；`native_only` 統一以 `references/cli-usage.md` 的「Mode 對照表」替代

詳細規格與 Mode 對照表見 `references/cli-usage.md`。

---

## 注意事項

- 來源記錄**無 `tags` 欄位**，不執行 tag-review
- 來源記錄無 `aliases`、`status`、`related`、`wiki_category`、`sources` 欄位
- `.obsidian/` 僅修改 `app.json`、`templates.json`、`core-plugins.json`

<!-- vault-tool:managed-end -->

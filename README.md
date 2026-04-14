# obsidian-vault-tool

Obsidian Vault 知識庫管理工具，作為 Claude Code Plugin 分發。

以 [Karpathy LLM Wiki](https://karpathy.ai/) 模式為骨架，整合 obsidian-vault-tool 自有的雙樹結構（**歷史紀錄**按時間 / **主題知識**按類別），支援人類使用者、AI agent（作為長期知識庫）、與朋友圈分享三種使用情境。

## 核心理念

LLM 不只「**檢索**」知識（傳統 RAG），而是「**累積與維護**」一個持久化 wiki：每個來源被讀取一次，從中萃取的概念被沉澱到 concept 頁，後續所有 query 都從這個編譯過的 wiki 出發。**知識編譯一次，持續維護**——而非每次查詢重新推導。

## 功能

| Skill | 觸發詞 | 對應 Karpathy | 用途 |
|-------|-------|--------------|------|
| `vault-tool` | `/vault-tool {init\|update\|reset\|delete}` | — | 建立 / 升級 / 重置 / 刪除 vault |
| `archive` | 「歸檔對話」「處理這個 raw」 | INGEST | raw → 歷史紀錄 + 主題知識（雙寫）。含**對話歸檔**：自動萃取當前對話 → 寫入 `raw/conversation-{datetime}.md` → 走標準 full-archive 流程 |
| `query` | 「查一下」「wiki 裡有沒有」 | QUERY | 從 vault 合成答案 + 寫入 outputs/queries/ |
| `reflect` | 「reflect」「找漏洞」「綜合分析」 | REFLECT | 反向檢驗 + 模式掃描 + Gap Analysis（防回音室、找空白）|
| `ask` | 「我想搞清楚 X」「add question」 | ADD-QUESTION | 結構化開放問題隊列（QUESTIONS.md）|
| `curator` | 「lint」「wiki 體檢」「整理 wiki」「升級主題」 | LINT | 健康檢查（14 項，含 confidence/staleness/contradictions/wikilink/tag 品質）|

## 知識庫架構（v0.9）

```
vault/
├── raw/                    # 待歸檔原始檔案（使用者 inbox）
│   ├── archived/           # 已歸檔的 raw 原檔（由 archive 自動 mv）
│   └── personal/           # ⭐ 個人寫作（走專屬路徑，不計入 source_count）
├── 歷史紀錄/                # 時間軸（每個 raw 對應一個 source 頁）
│   ├── 對話/               # init 時建立
│   ├── 個人寫作/            # ⭐ init 時建立，對應 raw/personal/
│   └── 文章/ / YouTube/ / Facebook/ / 文件/ / 網頁/   # 按 content_type 動態建立
│       └── YYYY-MM-DD/
│           └── NN_概述.md
├── 主題知識/                # 類別軸（多 source 融合的 concept 頁）
│   ├── 概念/               # frontmatter: confidence / aliases / Evolution Log / Contradictions
│   ├── 實體/
│   ├── 比較/
│   └── 總覽/               # query 回填 or reflect synthesis（v1.0）寫這
├── outputs/ ⭐               # 產出層（graph-excluded）
│   ├── queries/            # query 答案（每次持久化，可回填）
│   ├── reflect/            # warnings.md + pattern-{date}.md + gap-report-{date}.md
│   └── lint/               # curator <date>.md 健康檢查報告
├── index/ ⭐                # 極簡索引層
│   ├── topic-index.md      # topic → [[sources]] + [[concepts]]
│   └── question-index.md   # Q-NNN → [[candidate sources]]
├── templates/              # raw.md / 來源記錄.md / 知識筆記.md
├── QUESTIONS.md ⭐           # 開放問題隊列（Open / Answered）
├── overview.md ⭐            # Health Dashboard + 待 review 清單
├── index.md                # 主題目錄（append-only）
├── log.md                  # 操作時間軸（append-only, v0.9 格式）
└── CLAUDE.md               # 含 interaction_mode (human / agent) + schema
```

⭐ = v0.9 新增元素。`raw/` 下使用者可自行建立子目錄（如 `articles/`、`clippings/`）作為 inbox 慣例，plugin 不強制。

## v0.9 的新能力

- **Confidence 三級制**：concept 頁有 `low / medium / high` 信心度，high 必須人類確認（防錯誤複利）。含 `domain_volatility` 驅動動態 staleness 閾值（90/180/365 天）
- **Agent Mode**：vault 可設為 `interaction_mode: agent`，所有需要人類確認的決策延後寫入 `overview.md` 待 review 清單，agent 主流程不阻塞
- **SHA-256 完整性錨點**：每個 source 頁記錄 raw 檔的 SHA-256，為未來的 re-ingest 偵測預留
- **REFLECT 二階認知**：reflect skill 對既有結論主動找反證、偵測回音室風險、找出知識空白
- **QUESTIONS 開放問題隊列**：把「我想搞清楚 X」結構化，archive 新來源時自動匹配
- **outputs/ 持久化**：query / reflect / curator 的成果寫入 outputs/，不消失於對話歷史
- **Aliases 跨語言**：concept 頁支援中英雙語別名，wikilink 統一英文小寫連字符
- **Personal Writing 防自我背書**：`raw/personal/` 的個人寫作走 `歷史紀錄/個人寫作/` 路徑，`source_count` 不增加，防止「用自己的文章給自己背書」
- **Knowledge Supply Chain**：concept 頁的 Evolution Log 直接連結到歷史紀錄的時間點 wikilink，形成「概念 → 證據 → 時間點」的審計軌跡

## Why this over Karpathy LLM Wiki?

- **Plugin 一鍵安裝**：Karpathy 教程是「複製 prompt 自建」，本 plugin 是 Claude Code 原生 plugin
- **雙樹結構**：歷史紀錄按時間軸 + 主題知識按類別軸，形成 graph view 上的時間 + 類別交叉視角
- **wiki_category 4 分類**：把「比較」與「總覽」升級為頭等公民（Karpathy 只有 concepts/entities/synthesis）
- **雙管道寫入**：管道 1（obsidian CLI）用於日常歸檔保證 frontmatter 格式；管道 2（Claude Code 原生 Read/Edit/Write）用於 curator 的正文精修。詳見 `references/cli-usage.md`
- **Agent-friendly**：唯一明確支援 AI agent 作為長期知識庫使用者的 LLM Wiki 工具

## 前置需求

- Claude Code CLI
- `kepano/obsidian-skills` plugin（含 obsidian-cli、obsidian-markdown、defuddle）

## 安裝

```bash
# 1. Clone 專案
git clone https://github.com/leadingtw273/obsidian-vault-tool ~/.claude/plugins/obsidian-vault-tool

# 2. 連結 skills
mkdir -p ~/.claude/skills
ln -s ~/.claude/plugins/obsidian-vault-tool/skills/* ~/.claude/skills/

# 3. 安裝依賴
/plugin marketplace add kepano/obsidian-skills
/plugin install obsidian@obsidian-skills
```

> Skills 採 symlink 方式安裝，日後 `git pull` 即可更新，不需重建連結。

## 使用流程

```bash
# 在 Obsidian vault 目錄啟動 Claude Code
cd ~/your-vault && claude

# 1. 初始化 vault
/vault-tool init

# 2. 把 raw 檔丟進 vault/raw/（可自由建子目錄如 raw/articles/ 或直接放根目錄）

# 3. 歸檔（archive 自動偵測新檔案並提示）
歸檔 raw/your-article.md

# 4. 查詢
RAG 和 FineTune 哪個更適合？

# 5. 體檢
lint
```

## 文件結構

### Skills 與 Agents

- `skills/` — 6 個 skill：archive / query / reflect / ask / curator / vault-tool
- `agents/` — 3 個 sub-agent：
  - `record-writer.md`（寫歷史紀錄 + SHA-256 計算）
  - `wiki-writer.md`（寫主題知識 + confidence gate + Evolution Log）
  - `synthesis-writer.md`（v1.0 預留骨架，v0.9 不啟用）

### References（5 主題資料夾 + 2 平坦工具檔）

- `references/governance/` — 安全與治理：`path-safety-spec.md` / `consistency-boundary-spec.md` / `confidence-gating.md` / `agent-mode.md`
- `references/structure/` — 儲存結構：`folder-structure.md` / `templates-spec.md` / `index-spec.md` / `log-spec.md` / `outputs-layer.md`
- `references/taxonomy/` — 分類規則：`topic-matching-spec.md` / `topic-hierarchy-spec.md` / `wiki-category-spec.md` / `tag-topic-spec.md` / `aliases-and-wikilink.md`
- `references/quality/` — 品質保證：`sha-integrity.md` / `contradictions.md` / `staleness.md` / `decision-tables-spec.md`
- `references/workflow/` — 流程定義：`ask-flow.md` / `query-flow.md` / `reflect-flow.md`（archive 流程詳見 `skills/archive/`）
- `references/cli-usage.md` — obsidian CLI 操作手冊（雙管道設計說明）
- `references/claude-md-template.md` — vault 內 CLAUDE.md 範本（作為架構 SSOT）

### Scripts

- `scripts/lint-specs.sh` — 跨檔一致性檢查（6 條規則）
- `scripts/migrate-v08-to-v09.sh` — v0.8 → v0.9 vault 遷移腳本
- `scripts/check-deps.sh` — 檢查 obsidian-skills 依賴
- `scripts/check-init-status.sh` — 檢查 vault 是否已初始化
- `scripts/pre-commit-hook.sample` — 可選的 pre-commit 範本（copy 到 `.git/hooks/pre-commit` 啟用）

執行 `bash scripts/lint-specs.sh` 跑跨檔一致性檢查。

### Tests

- `tests/fixtures/` — 測試輸入樣本
- `tests/expected/` — 期望輸出（供迴歸比對）
- `tests/README.md` — 測試執行說明

### Docs（內部開發紀錄）

- `docs/superpowers/plans/` — 歷次版本的 plan 與設計紀錄（維護者參考用，非使用者必讀）

## 版本

- `0.9.0` — 融合 Karpathy LLM Wiki 模式：
  - **alpha**: references 5 資料夾重組 + 10 份新 spec（agent-mode / confidence-gating / sha-integrity / contradictions / staleness / aliases-and-wikilink / outputs-layer / reflect-flow / ask-flow / query-flow）
  - **beta**: record-writer SHA-256 + wiki-writer confidence gate / agent-mode / aliases / Contradictions / Evolution Log + archive 9 步驟 + vault-tool v0.9 結構 + query/curator outputs 持久化（10 case 測試全 PASS）
  - **rc**: reflect skill（Stage 0+1+3 Preview）+ ask skill（QUESTIONS.md）+ 極簡索引維護 + v0.8→v0.9 遷移腳本 + tag-review 併入 curator
- `0.8.0` — 一致性與安全強化：path-safety 三階段防護、consistency-boundary 弱一致性模型、decision-tables、lint-specs.sh、迴歸測試
- `0.7.0` — 全面審查修復（22 項 + 三方復盤 3 項）
- `0.6.0` — Wiki 主題層級機制 + curator skill：引入動態層級（單頁→目錄結構，最深 3 層）、wiki-writer 簡化、record-writer 輸出樹狀結構
- `0.5.x` — 新增 query 與 lint skill；wiki-writer 6 層 fallback 主題匹配；9 份 reference spec
- `0.4.0` — 整合歸檔流程為 archive skill 三模式架構
- `0.3.0` — 引入 archive 主 skill + custom agent 兩階段設計

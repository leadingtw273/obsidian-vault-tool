# obsidian-vault-tool

Obsidian Vault 知識庫管理工具，作為 Claude Code Plugin 分發。

以 [Karpathy LLM Wiki](https://karpathy.ai/) 模式為骨架，整合 obsidian-vault-tool 自有的雙樹結構（**歷史紀錄**按時間 / **主題知識**按類別），支援人類使用者、AI agent（作為長期知識庫）、與朋友圈分享三種使用情境。

## 核心理念

LLM 不只「**檢索**」知識（傳統 RAG），而是「**累積與維護**」一個持久化 wiki：每個來源被讀取一次，從中萃取的概念被沉澱到 concept 頁，後續所有 query 都從這個編譯過的 wiki 出發。**知識編譯一次，持續維護**——而非每次查詢重新推導。

## 功能

| Skill | 觸發詞 | 對應 Karpathy | 用途 |
|-------|-------|--------------|------|
| `vault-tool` | `/vault-tool {init\|update\|reset\|delete}` | — | 建立 / 升級 / 重置 / 刪除 vault |
| `archive` | 「歸檔對話」「處理這個 raw」 | INGEST | raw → 歷史紀錄 + 主題知識（雙寫）|
| `query` | 「查一下」「wiki 裡有沒有」 | QUERY | 從 vault 合成答案 + 寫入 outputs/queries/ |
| `reflect` ⭐ | 「reflect」「找漏洞」（v0.9.0-rc 啟用）| REFLECT | 反向檢驗 + Gap Analysis（防回音室、找空白）|
| `ask` ⭐ | 「我想搞清楚 X」（v0.9.0-rc 啟用）| ADD-QUESTION | 結構化開放問題隊列 |
| `curator` | 「lint」「wiki 體檢」 | LINT | 健康檢查（孤兒、矛盾、staleness、wikilink 格式...）|
| `tag-review` | 「檢查標籤」 | — | 標籤品質控制（v0.9.0-rc 後併入 curator）|

⭐ 標記的 skill 在 v0.9.0-alpha 已完成 spec，實作預定 v0.9.0-rc。

## 知識庫架構（v0.9）

```
vault/
├── raw/                    # 待歸檔原始檔案
│   ├── articles/           # 文章
│   ├── clippings/          # Web Clipper 剪藏
│   ├── personal/           # ⭐ 自己寫的文章（不計入 confidence source_count）
│   └── archived/           # 已歸檔的 raw 原檔
├── 歷史紀錄/                # 時間軸（每個 raw 對應一個 source 頁）
│   ├── 文章/YYYY-MM-DD/
│   ├── 對話/
│   └── 個人寫作/YYYY-MM-DD/  # ⭐ 對應 raw/personal/
├── 主題知識/                # 類別軸（多 source 融合的 concept 頁）
│   ├── 概念/               # frontmatter: confidence / aliases / Evolution Log
│   ├── 實體/
│   ├── 比較/
│   └── 總覽/               # synthesis-writer 寫這
├── outputs/ ⭐               # 產出層
│   ├── queries/            # query 答案
│   ├── reflect/            # gap report / warnings
│   └── lint/               # curator 報告
├── QUESTIONS.md ⭐           # 開放問題隊列
├── overview.md ⭐            # Health Dashboard + 待 review 清單
├── index.md                # 主題目錄
├── log.md                  # 操作時間軸
└── CLAUDE.md               # 含 interaction_mode (human / agent)
```

⭐ = v0.9 新增元素

## v0.9 的新能力

- **Confidence 三級制**：concept 頁有 `low / medium / high` 信心度，high 必須人類確認（防錯誤複利）
- **Agent Mode**：vault 可設為 `interaction_mode: agent`，所有需要人類確認的決策延後寫入 `overview.md` 待 review 清單，agent 主流程不阻塞
- **SHA-256 完整性錨點**：每個 source 頁記錄 raw 檔的 SHA-256，為未來的 re-ingest 偵測預留
- **REFLECT 二階認知**：reflect skill 對既有結論主動找反證、偵測回音室風險、找出知識空白
- **QUESTIONS 開放問題隊列**：把「我想搞清楚 X」結構化，archive 新來源時自動匹配
- **outputs/ 持久化**：query / reflect / curator 的成果寫入 outputs/，不消失於對話歷史
- **Aliases 跨語言**：concept 頁支援中英雙語別名，wikilink 統一英文小寫連字符
- **Knowledge Supply Chain**：concept 頁的 Evolution Log 直接連結到歷史紀錄的時間點 wikilink，形成「概念 → 證據 → 時間點」的審計軌跡

## Why this over Karpathy LLM Wiki?

- **Plugin 一鍵安裝**：Karpathy 教程是「複製 prompt 自建」，本 plugin 是 Claude Code 原生 plugin
- **雙樹結構**：歷史紀錄按時間軸 + 主題知識按類別軸，形成 graph view 上的時間 + 類別交叉視角
- **wiki_category 4 分類**：把「比較」與「總覽」升級為頭等公民（Karpathy 只有 concepts/entities/synthesis）
- **obsidian CLI 直接寫檔**：保證 frontmatter 格式正確（Karpathy 依賴 LLM 自己寫 YAML）
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

# 2. 把 raw 檔丟進 vault/raw/articles/

# 3. 歸檔（archive 自動偵測新檔案並提示）
歸檔 raw/articles/your-article.md

# 4. 查詢
RAG 和 FineTune 哪個更適合？

# 5. 體檢
lint
```

## 文件結構

- `references/governance/` — 安全與治理（path-safety / consistency / confidence / agent-mode）
- `references/structure/` — 儲存結構（templates / index / log / outputs / folder）
- `references/taxonomy/` — 分類規則（topic-matching / wiki-category / aliases）
- `references/quality/` — 品質保證（sha-integrity / contradictions / staleness / decision-tables）
- `references/workflow/` — 流程定義（archive / reflect / ask / query）

執行 `bash scripts/lint-specs.sh` 跑跨檔一致性檢查。

## 版本

- `0.9.0-alpha` — 融合 Karpathy LLM Wiki 模式：references 5 資料夾重組、agent-mode + confidence-gating + 6 份新 quality/workflow spec、interaction_mode 機制（spec 階段，實作預定 0.9.0-beta/rc）
- `0.8.0` — 一致性與安全強化：path-safety 三階段防護、consistency-boundary 弱一致性模型、decision-tables、lint-specs.sh、迴歸測試
- `0.7.0` — 全面審查修復（22 項 + 三方復盤 3 項）
- `0.6.0` — Wiki 主題層級機制 + curator skill：引入動態層級（單頁→目錄結構，最深 3 層）、wiki-writer 簡化、record-writer 輸出樹狀結構
- `0.5.x` — 新增 query 與 lint skill；wiki-writer 6 層 fallback 主題匹配；9 份 reference spec
- `0.4.0` — 整合歸檔流程為 archive skill 三模式架構
- `0.3.0` — 引入 archive 主 skill + custom agent 兩階段設計

# Vault 模板檔案規格

初始化時在 `templates/` 建立以下 3 個模板（不存在則建立，已存在則略過）。

`date` 欄位填 Obsidian 範本語法 `"{{date}}"` （保留引號，避免 Obsidian Properties 型別驗證報警）。

---

## 模板清單

| 檔名 | category | 用途 |
|------|----------|------|
| `raw.md` | — | 使用者手動建立 raw 檔的起點 |
| `來源記錄.md` | `來源紀錄`（固定） | record-writer 寫入歷史紀錄時使用 |
| `知識筆記.md` | 由 `tags[0]` 第一層決定 | wiki-writer 新建知識頁時使用 |

---

## raw 模板（`raw.md`）

供使用者在 `raw/` 手動新增待歸檔檔案時使用。歸檔前 `record-writer` 會驗證必要欄位是否完整。

```yaml
---
title:
date: "{{date}}"
author:
source:
content_type:
---

<!-- 在此貼入原始內容 -->
```

### raw 模板欄位說明

| 欄位 | 必填 | 說明 |
|------|------|------|
| `title` | 必填 | 來源標題（文章標題、影片標題、對話概述等） |
| `date` | 必填 | 內容日期，格式 `YYYY-MM-DD` |
| `author` | 選填 | 原始作者；缺失或空字串時 record-writer 自動補為 `unknown` |
| `source` | 必填 | 原始 URL；無 URL 時填 `conversation` 或其他識別資訊 |
| `content_type` | 選填 | `conversation` / `youtube` / `fb-post` / `article` / `pdf` / `webpage`；未填則由 record-writer 依 source URL 推斷 |

---

## 來源記錄模板（`來源記錄.md`）

v0.9.0-beta 起新增 4 個 SHA-256 完整性欄位（依 `references/quality/sha-integrity.md`）：

```yaml
---
title:
date: "{{date}}"
source:
category: 來源紀錄
content_type:
author:
raw_file:
raw_sha256:
last_verified: "{{date}}"
possibly_outdated: false
---
```

| 欄位 | 必填 | 說明 |
|------|-----|------|
| `raw_file` | v0.9 起 | raw 檔的相對路徑（相對 vault root）|
| `raw_sha256` | v0.9 起 | 64 字元小寫 hex，由 record-writer Step 1.2 計算 |
| `last_verified` | v0.9 起 | 等於 ingest 日期（v0.9 不做 lint 比對 = ingest 日期）|
| `possibly_outdated` | v0.9 起 | 自動判定，原文發表 > 730 天前 → true |

---

## 知識筆記模板（`知識筆記.md`）

v0.9.0-beta 起新增 5 個 frontmatter 欄位（依 `references/governance/confidence-gating.md` 與 `references/taxonomy/aliases-and-wikilink.md`）：

```yaml
---
title:
date: "{{date}}"
updated: "{{date}}"
tags:
  -
aliases: []
sources:
  -
category:
wiki_category:
content_type:
author:
confidence: low
source_count: 0
domain_volatility: medium
last_reviewed: "{{date}}"
high_candidate: false
---

## Contradictions

_暫無已知矛盾。_

## Evolution Log

<!-- 由 wiki-writer 在每次 upsert 追加 -->
```

| 欄位 | v0.9 起 | 說明 |
|------|--------|------|
| `confidence` | ✅ | `low` / `medium` / `high`，預設 `low`；high 必須人類確認 |
| `source_count` | ✅ | 引用此概念的外部來源數，personal-writing 不計入 |
| `domain_volatility` | ✅ | `high` / `medium` / `low`，預設 `medium`，驅動 staleness 閾值 |
| `last_reviewed` | ✅ | 最近一次被人類或 wiki-writer 更新的日期 |
| `high_candidate` | ✅ | 預設 `false`；agent mode 下 source_count ≥ 5 時改為 `true` |

知識筆記正文新增 2 個強制段落：
- `## Contradictions` — 矛盾顯式標註區（依 `references/quality/contradictions.md`）
- `## Evolution Log` — 認知變化追蹤區（每次 upsert 追加一條）

---

## 注意

- `date` 與 `updated` 欄位需加引號：`"{{date}}"` 而非 `{{date}}`
- `aliases` 初始為空陣列 `[]`；wiki-writer 在 upsert 合併時若發現別名會自動追加（v0.9 含中英雙語別名）
- `sources` 為陣列，每次 upsert 追加新來源 wikilink，格式 `"[[來源記錄檔名]]"`
- `wiki_category` 由 wiki-writer 依 `references/taxonomy/wiki-category-spec.md` 判定後填入
- `category` 由 `tags[0]` 第一層動態決定（如 `技術/AI/LLM` → `技術`）
- `type` 與 `children` 不在模板中預設。僅由 curator skill 在結構升級時加入：`type: topic-hub` 表示目錄型主題，`children: []` 列出子頁面 wikilink
- raw 模板的 `content_type` 未填時，record-writer 依 source URL 自動推斷（見 `agents/record-writer.md`）
- v0.9.0-beta 新增的 5 個知識筆記欄位由 wiki-writer 在 Step 5A/5B 自動寫入；v0.8 vault 升級時由 vault-tool update 補上預設值
- v0.9.0-beta `confidence: high` 必須由人類明確確認，禁止自動升級（防錯誤複利）
- v0.9.0-beta `domain_volatility` 不可由 agent 變更（領域特性是人類判斷）

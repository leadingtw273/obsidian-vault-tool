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
| `author` | 必填 | 原始作者；不適用時填 `unknown` |
| `source` | 必填 | 原始 URL；無 URL 時填 `conversation` 或其他識別資訊 |
| `content_type` | 選填 | `conversation` / `youtube` / `fb-post` / `article` / `pdf` / `webpage`；未填則由 record-writer 依 source URL 推斷 |

---

## 來源記錄模板（`來源記錄.md`）

```yaml
---
title:
date: "{{date}}"
source:
category: 來源紀錄
content_type:
author:
---
```

---

## 知識筆記模板（`知識筆記.md`）

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
---
```

---

## 注意

- `date` 與 `updated` 欄位需加引號：`"{{date}}"` 而非 `{{date}}`
- `aliases` 初始為空陣列 `[]`；wiki-writer 在 upsert 合併時若發現別名會自動追加
- `sources` 為陣列，每次 upsert 追加新來源 wikilink，格式 `"[[來源記錄檔名]]"`
- `wiki_category` 由 wiki-writer 依 `references/wiki-category-spec.md` 判定後填入
- `category` 由 `tags[0]` 第一層動態決定（如 `技術/AI/LLM` → `技術`）
- raw 模板的 `content_type` 未填時，record-writer 依 source URL 自動推斷（見 `agents/record-writer.md`）

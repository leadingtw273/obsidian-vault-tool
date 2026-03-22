# Vault 模板檔案規格

初始化時在 `templates/` 建立以下 2 個模板（不存在則建立，已存在則略過）。

`date` 欄位填 Obsidian 範本語法 `"{{date}}"` （保留引號，避免 Obsidian Properties 型別驗證報警）。

---

## 模板清單

| 檔名 | category | content_type |
|------|----------|--------------|
| `來源記錄.md` | `來源紀錄`（固定） | 動態（conversation / youtube / fb-post / article / pdf / webpage） |
| `知識筆記.md` | 由 `tags[0]` 第一層決定 | 依來源決定 |

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

## 知識筆記模板（`知識筆記.md`）

```yaml
---
title:
date: "{{date}}"
tags:
  -
source:
category:
content_type:
author:
---
```

## 注意

- `date` 欄位需加引號：`"{{date}}"` 而非 `{{date}}`
- 來源記錄的 `source` 填原始 URL 或對話識別資訊
- 來源記錄的 `content_type` 填實際類型：`conversation` / `youtube` / `fb-post` / `article` / `pdf` / `webpage`
- 知識筆記的 `category` 由 `tags[0]` 第一層動態決定（如 `技術/AI/LLM` → `技術`）
- 知識筆記的 `source` 填 `[[來源記錄檔名]]`（由 archive 呼叫時）或原始 URL（standalone 時）

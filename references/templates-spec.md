# Vault 模板檔案規格

初始化時在 `templates/` 建立以下 2 個模板（不存在則建立，已存在則略過）。

`date` 欄位填 Obsidian 範本語法 `"{{date}}"` （保留引號，避免 Obsidian Properties 型別驗證報警）。

---

## 模板清單

| 檔名 | category | content_type |
|------|----------|--------------|
| `對話筆記.md` | `對話歷史` | `ClaudeCode` |
| `知識筆記.md` | （由 tags[0] 第一層決定） | （依來源決定） |

---

## 對話筆記模板（`對話筆記.md`）

```yaml
---
title:
date:
source:
category: 對話歷史
content_type: ClaudeCode
author:
---
```

## 知識筆記模板（`知識筆記.md`）

```yaml
---
title:
date:
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
- 對話筆記的 `source` 填 session-id（對話識別碼）
- 知識筆記的 `category` 由 `tags[0]` 第一層動態決定（如 `技術/AI/LLM` → `技術`）
- 知識筆記的 `source` 填 `[[對話筆記檔名]]` 或原始 URL

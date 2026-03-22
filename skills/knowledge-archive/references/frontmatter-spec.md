# Frontmatter Schema 說明

Vault 有兩種筆記類型，各自使用不同的 frontmatter schema。

---

## 一、來源記錄（Source Record）

存放路徑：`歷史紀錄/[type]/[YYYY-MM-DD]/[序號]_[概述].md`

`[type]` 依來源類型決定：

| content_type | 目錄 |
|---|---|
| `conversation` | `歷史紀錄/對話/` |
| `youtube` | `歷史紀錄/YouTube/` |
| `fb-post` | `歷史紀錄/Facebook/` |
| `article` | `歷史紀錄/文章/` |
| `pdf` | `歷史紀錄/文件/` |
| `webpage` | `歷史紀錄/網頁/` |

### Schema（6 欄位）

```yaml
---
title:
date:
source:
category: 來源紀錄
content_type:
author:
---
```

### 欄位說明

| 欄位 | 型別 | 說明 |
|------|------|------|
| `title` | string | 來源標題（文章標題、影片標題、對話概述等） |
| `date` | string | 歸檔日期，格式 `YYYY-MM-DD` |
| `source` | string | 原始 URL 或對話識別資訊 |
| `category` | string | 固定填 `來源紀錄` |
| `content_type` | string | 來源類型，見上方表格的 enum 值 |
| `author` | string | 原始作者，不適用則留空 |

---

## 二、知識筆記（Knowledge Note）

存放路徑：`主題知識/[YYYY-MM-DD]/[標題].md`

### Schema（7 欄位）

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

### 欄位說明

| 欄位 | 型別 | 說明 |
|------|------|------|
| `title` | string | 筆記標題 |
| `date` | string | 建立日期，格式 `YYYY-MM-DD` |
| `tags` | list | 中文層級結構標籤，見標籤規則 |
| `source` | string | `[[來源記錄檔名]]`（由 archive skill 呼叫時）或完整 URL（standalone 呼叫時） |
| `category` | string | 動態決定，等於 `tags[0]` 的第一層（如 `技術/AI/LLM` → `技術`） |
| `content_type` | string | 原始內容形式，見 enum 值 |
| `author` | string | 原始作者，不適用填空白 |

### content_type Enum 值

- `article` — 文章
- `youtube` — YouTube 影片
- `pdf` — PDF 文件
- `fb-post` — Facebook 貼文
- `conversation` — 對話紀錄
- `webpage` — 一般網頁

### category 動態規則

`category` 永遠等於 `tags[0]` 路徑的**第一層**：

| tags[0] 範例 | category |
|-------------|----------|
| `技術/AI/LLM` | `技術` |
| `商業/行銷` | `商業` |
| `個人/閱讀` | `個人` |

### source 雙重用途

| 呼叫方式 | source 填法 |
|---------|------------|
| 由 `archive` skill 呼叫（透過 knowledge-writer agent） | `[[來源記錄檔名]]`（vault 內部連結） |
| 由 `knowledge-archive` standalone 呼叫 | 完整 URL 字串 |

---

## 標籤規則（三段組合）

1. **層級結構標籤**（1 個）：完整路徑，如 `技術/AI/LLM`，放 `tags[0]`
2. **層級拆解標籤**（2-3 個）：拆開各層，如 `技術`、`AI`、`LLM`
3. **其他描述標籤**（2-5 個）：補充具體主題，如 `提示詞工程`、`RAG`

總數最多 10 個。`tags[0]` 第一層決定 `category`。

---

## 注意事項

- 對話筆記**無 `tags` 欄位**，不執行 tag-review
- 知識筆記的 `tags` 必須先經過 tag-review skill 確認
- 兩種筆記**均無** `aliases`、`status`、`related`、`original_url`、`scope`、`archived_to`、`archived_at` 欄位

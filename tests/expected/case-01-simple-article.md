# Expected: case-01-simple-article

## 預期寫入檔案

1. **歷史紀錄**：`歷史紀錄/文章/2026-04-10/01_RAG架構簡介.md`
   - frontmatter 含 `category: 來源紀錄`, `content_type: article`
   - 含「## 總結」段落
   - 結尾含 `> 原始內容見 [[raw/archived/case-01-simple-article]]`

2. **知識筆記**（至少 1 個，可能更多）：
   - 主要主題：`主題知識/概念/RAG.md` 或類似
   - frontmatter 含 `wiki_category: 概念`, `sources: ["[[01_RAG架構簡介]]"]`

## 預期更新檔案

- `index.md` 追加一行新條目
- `log.md` 追加一則 ingest 條目
- `raw/case-01-simple-article.md` 移動至 `raw/archived/case-01-simple-article.md`

## 驗證重點

- 歷史紀錄序號為 `01`（目錄為空）
- wiki_category 正確判定為「概念」（RAG 屬於方法論/架構）
- 交叉連結正確（若有既有相關主題頁）

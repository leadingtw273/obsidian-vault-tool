# 同主題判定規格（topic-matching-spec）

本規格定義 `wiki-writer` agent 在 upsert 模式下，判定新主題是否已有既有頁面的完整流程。

---

## 使用場景

每次 `wiki-writer` 準備寫入一個知識主題時，必須先執行同主題判定，決定要**新建頁面**還是**合併至既有頁面**（upsert）。

判定採多層 fallback，由精確到模糊，逐層遞進。

---

## 6 層 Fallback 流程

### Level 1：精確檔名匹配

```
glob 主題知識/*/[標題].md
```

- 直接比對所有四個分類資料夾（實體 / 概念 / 比較 / 總覽）
- 命中：直接進行 upsert，不需 LLM 確認
- 未命中：進入 Level 2

### Level 2：正規化匹配

對標題執行正規化處理後比對所有既有頁檔名：

1. **正規化步驟**：小寫化 → 去除空白 → 去除標點符號 → 處理單複數（去除尾端 `s`）
2. 對所有 `主題知識/*/` 下的 `.md` 檔名執行相同正規化後比對
3. 命中候選頁 → **LLM 讀候選頁前 20 行**，確認是否為同一主題
   - 確認同主題：進行 upsert
   - 確認為同名異物（見下方處理規則）：直接另建新頁，加分類詞命名
4. 未命中：進入 Level 3

正規化範例：

| 原標題 | 正規化結果 |
|--------|-----------|
| `Large Language Models` | `largelanguagemodel` |
| `large language model` | `largelanguagemodel` |
| `LLM` | `llm`（縮寫不展開，僅正規化） |

> 縮寫與全稱（如 `LLM` vs `Large Language Model`）在 Level 2 不會匹配，需靠 Level 3 Aliases 處理。

### Level 3：Aliases 匹配

```
grep frontmatter aliases: 陣列中是否包含本標題
```

- 掃描 `主題知識/*/` 所有頁面的 frontmatter `aliases` 陣列
- 比對時**不區分大小寫**
- 命中：直接進行 upsert，使用既有頁的主標題，不以新標題替換
- 未命中：進入 Level 4

### Level 4：反向連結匹配

```
obsidian search "[[新標題]]"
```

- 搜尋 Vault 中已有哪些頁面在正文用 `[[新標題]]` 引用了本主題
- 若有頁面引用 → 該被引用的頁面通常是主頁，讀取該頁確認
- 命中主題頁：進行 upsert
- 未命中：進入 Level 5

### Level 5：tag[0] + 模糊搜尋

1. 取新主題判定的 `tags[0]` 第一層（`category`）
2. 搜尋相同 `category` 下的所有知識頁
3. LLM 判定語意接近程度（標題、摘要段落比對）
4. 命中（LLM 確信為同主題）：進行 upsert
5. 多個候選或不確定：進入 Level 6

### Level 6：衝突兜底

當多個 Level 匹配出複數候選，或 LLM 無法確定時：

```
輸出候選清單給主對話（或使用者）裁決：

⚠️ 同主題判定：發現多個候選頁，請裁決合併目標：
  1. [[主題知識/實體/XXX]] — [首行摘要]
  2. [[主題知識/概念/YYY]] — [首行摘要]
  3. 新建頁面（不合併）

請選擇 1 / 2 / 3：
```

主對話或使用者回應後，wiki-writer 依指示執行。

---

## 同名異物處理

### 判定條件

Level 2 / Level 5 命中後，LLM 讀候選頁前 20 行，比對：

- 若 `tags[0]` 第一層**相同**（如同為 `技術`）→ 同一主題，upsert 合併
- 若 `tags[0]` 第一層**不同**（如 `技術/AI` vs `學習/音樂`）→ 同名異物，另建新頁

### 命名規則

同名異物頁面在標題後加括號分類詞：

```
Claude (Anthropic).md       ← AI 助手
Claude Debussy.md           ← 音樂家（無歧義則不加括號）

Python (程式語言).md
Python (蛇類).md
```

分類詞優先使用所屬組織名或領域名，以最少字元消除歧義為原則。

---

## Aliases 累積機制

upsert 合併時，若發現 raw 檔或新來源使用了與既有頁主標題不同的稱呼，wiki-writer 應自動將新稱呼加入既有頁的 `aliases` 陣列：

```yaml
# 既有頁（主標題 LLM）
aliases:
  - 大型語言模型
  - Large Language Model   ← 本次 upsert 新增
```

aliases 累積規則：
- 只添加，不刪除既有 aliases
- 去重（已存在的稱呼不重複新增）
- 保留原始大小寫（不強制正規化）

---

## 案例對照表

| 情境 | 說明 | 處理方式 |
|------|------|----------|
| 完全相同標題 | 新主題「RAG」vs 既有頁「RAG.md」 | Level 1 精確匹配，直接 upsert |
| 大小寫差異 | 「rag」vs「RAG.md」 | Level 2 正規化後匹配 |
| 中英對照 | 「大型語言模型」vs 既有頁「LLM.md」 | Level 3 Aliases 匹配（若 LLM 頁已加 alias） |
| 縮寫與全稱 | 「Retrieval Augmented Generation」vs 既有「RAG.md」 | Level 3 Aliases（若已記錄全稱 alias） |
| 單複數 | 「LLMs」vs「LLM.md」 | Level 2 正規化（去尾端 s）後匹配 |
| 同名異物 | 「Claude」（AI）vs「Claude」（音樂家） | Level 2 命中，LLM 讀頁確認 tags 不同，另建頁 |
| 多候選衝突 | 「AI」可能匹配多個總覽頁 | Level 6 輸出清單，由主對話裁決 |

# Wiki 分類判準（wiki-category-spec）

本規格定義知識筆記的四種分類及判定流程，供 `wiki-writer` agent 在 Step 3 使用。

---

## 四類定義

| wiki_category | 定義 | 典型範例 |
|---------------|------|----------|
| `實體` | 人物、工具、產品、組織、地點等**具體可指稱的對象**，有唯一身份 | Obsidian Web Clipper、Anthropic、Claude Code、吳恩達 |
| `概念` | 原理、方法論、理論、設計模式、流程等**抽象的知識單元** | LLM、RAG、Prompt Engineering、TDD、LLM Wiki、Transformer 架構 |
| `比較` | 明確**對比分析兩個以上**實體或概念的整合頁，核心價值在對比本身 | Claude vs GPT、RAG vs LLM Wiki、Obsidian vs Notion |
| `總覽` | 主題總論、探索結果、橫跨多主題的綜論；常由 query skill 回填 | 2026 AI 趨勢、Obsidian 生態圈總論、LLM 應用現況 |

---

## Agent 判定流程

`wiki-writer` 在決定 `wiki_category` 時，依序執行以下判斷：

```
Step 1：實體檢測（優先）
    主題名稱是否為具體可指稱的對象？
    判定線索：
    - 人名（如「吳恩達」、「Karpathy」）→ 實體
    - 工具名、產品名（如「Obsidian」、「Claude Code」、「ComfyUI」）→ 實體
    - 組織名（如「Anthropic」、「OpenAI」）→ 實體
    - 特定框架/套件名（如「LangChain」、「Next.js」）→ 實體
    ⚠️ 注意：「Obsidian 知識管理」以 Obsidian（工具）為核心 → 實體
              「知識管理方法論」無具體工具指涉 → 不是實體
    → 是：wiki_category = 實體

Step 2：比較檢測（提前於概念）
    主題是否涉及兩個以上對象的對比分析？
    判定線索：
    - 標題含「vs」、「比較」、「對比」、「差異」→ 高度傾向比較
    - 標題含「與」且主語為兩個並列對象（如「RAG 與 LLM Wiki」）→ 比較
    - 正文核心價值在於列出各方案的優缺點對照 → 比較
    ⚠️ 注意：標題含「與」但不是對比（如「AI 與未來」作為綜論）→ 不是比較
    → 是：wiki_category = 比較

Step 3：總覽檢測
    主題是否為橫跨多主題的綜論、探索摘要或現況總覽？
    判定線索：
    - 標題含「總覽」、「趨勢」、「現況」、「生態」→ 總覽
    - 涵蓋 3 個以上獨立子主題的綜合論述 → 總覽
    - 由 query skill 回填的探索結果 → 總覽
    → 是：wiki_category = 總覽

Step 4：概念（兜底）
    不符合上述三類 → wiki_category = 概念
    典型：原理、方法論、理論、設計模式、流程、抽象技術概念
```

> **判定原則**：
> - 同一主題只落在一類。若感覺跨類，以最核心的性質決定
> - **偏好順序**：實體 > 比較 > 總覽 > 概念。概念是兜底類別，不應作為首選
> - **工具 + 行為 = 實體**：當主題以某個具體工具為核心，即使涉及抽象概念（如「Obsidian 知識管理」），仍優先歸為實體
> - **對比 = 比較**：只要核心價值在於對比兩方案的優劣，即歸為比較

---

## 頁面類型標記

| type 欄位 | 說明 |
|-----------|------|
| `topic-hub` | 目錄型主頁（已升級為目錄結構，含子頁面導航） |
| （無 type 欄位） | 普通單頁主題 |

- `type: topic-hub` 由 curator skill 在執行結構升級時設定
- wiki-writer 新建頁面時**不設定** type 欄位
- 目錄結構下，子頁面繼承母主題的 `wiki_category`，不獨立判定分類

## 路徑慣例

```
主題知識/[wiki_category]/[主題標題].md           ← 單頁
主題知識/[wiki_category]/[主題標題]/[主題標題].md  ← 目錄型主頁
主題知識/[wiki_category]/[主題標題]/[子主題].md    ← 子頁面
```

範例：
- `主題知識/實體/Claude Code.md`
- `主題知識/概念/RAG.md`（單頁）
- `主題知識/概念/RAG/RAG.md`（升級後的主頁）
- `主題知識/概念/RAG/Chunk 策略.md`（子頁面）
- `主題知識/比較/Claude vs GPT.md`
- `主題知識/總覽/2026 AI 趨勢.md`

---

## 同名異物處理

當兩個主題的標題相同但指涉不同對象時（例如 `Claude` 可以是 AI 或音樂家），需加分類詞區分：

### 判定方式

1. Level 2 / Level 5 匹配命中候選頁時，LLM 讀候選頁前 20 行
2. 比對 `tags[0]` 第一層：
   - 相同（如同為 `技術`）→ 視為同一主題，進行 upsert 合併
   - 不同（如 `技術/AI` vs `學習/音樂`）→ 視為**同名異物**，建立新頁

### 命名規則

同名異物頁面在標題後加括號分類詞：

```
Claude (Anthropic).md
Claude Debussy.md

Python (程式語言).md
Python (蛇類).md
```

分類詞優先使用：所屬組織名、領域名、或最能區分的短詞。

---

## 案例對照表

| 主題 | 判定結果 | 理由 |
|------|----------|------|
| Claude Code | 實體 | 具體產品，有唯一身份 |
| Anthropic | 實體 | 具體組織 |
| RAG | 概念 | 抽象技術方法論 |
| Prompt Engineering | 概念 | 抽象工程方法 |
| LLM Wiki | 概念 | 知識管理方法論 |
| Claude vs GPT | 比較 | 明確對比兩個實體 |
| RAG vs LLM Wiki | 比較 | 明確對比兩個概念 |
| 2026 AI 趨勢 | 總覽 | 橫跨多主題的現況綜論 |
| Obsidian 生態圈總論 | 總覽 | 探索結果，橫跨多個工具/概念 |

# 決策表規格

集中定義 plugin 核心流程的高分歧決策點，提供可交叉驗證的權威來源。
各 skill / agent 應引用此文件而非自行定義流程。

**格式說明**：每個決策表採用 Markdown 表格 + HTML 註解 ID 的混合格式。
HTML 註解中的 `decision-id` 供 lint script 交叉驗證，不影響人類閱讀。

---

## 決策表 A：Topic Matching 6 層 Fallback

<!-- decision-id: topic-match -->

權威來源於此表，`agents/wiki-writer.md` Step 4 與 `references/topic-matching-spec.md` 應引用本表。

| Level | 名稱 | 觸發條件 | 執行動作 | 命中後下一步 |
|-------|------|---------|---------|------------|
| L1 | 精確檔名匹配 | `wiki_pages` 中有 title 完全等於當前主題標題 | 標記為 upsert target | 跳至 Step 5 |
| L2 | 正規化匹配 | L1 未命中；正規化（小寫/去空白/去標點/去尾端 s）後相等 | Read 候選頁前 20 行，LLM 判定同主題 | 同主題 → Step 5；同名異物 → 新建加分類詞 |
| L3 | Aliases 匹配 | L2 未命中；`obsidian search` 命中 aliases 陣列 | 二次確認命中位置在 aliases | 命中 → 使用既有主標題 upsert |
| L4 | 反向連結匹配 | L3 未命中；`obsidian search "[[主題]]"` 命中 | Read 被引用頁確認為同主題主頁 | 命中 → upsert 目標 |
| L5 | tag[0] + 模糊搜尋 | L4 未命中；依原文推斷 tags[0] 後比對 | LLM 判定語意接近 | 確信 → upsert；不確定 → L6 |
| L6 | 衝突兜底 | L1-L5 多候選或 LLM 無法確信 | 輸出候選清單，回報主對話裁決 | 暫停本主題寫入，狀態待裁決 |

**特殊規則**：
- L2 / L5 命中時需比對 `tags[0]` 第一層，不同則判為「同名異物」（見決策表 E）
- L6 的裁決結果由使用者指定後，重新呼叫 wiki-writer 並傳入 `**使用者裁決**` 參數

---

## 決策表 B：寫入路徑決定

<!-- decision-id: write-path -->

權威來源於此表，`agents/wiki-writer.md` Step 5A 應引用本表。

| 優先級 | 條件 | 結果路徑 | 備註 |
|--------|------|---------|------|
| P1（最高）| Step 4 匹配到既有頁 | 使用既有頁實際路徑 | upsert 至既有頁，不變更路徑 |
| P2 | 呼叫方提供 `**寫入路徑**` 參數 | 使用該路徑 | 由 full-archive Step 1.6 層級映射決定 |
| P3（預設）| 以上皆無 | `主題知識/[wiki_category]/[主題標題].md` | 新建單頁 |

**必要驗證**（不論選中哪個優先級）：
1. 通過 path-safety-spec 的 VERIFY 白名單檢查
2. 最終路徑必須以 `主題知識/` 為前綴
3. 若路徑包含子目錄（如 `主題知識/實體/parent/child.md`），父目錄必須已存在 `type: topic-hub` frontmatter

---

## 決策表 C：Wiki Category 判定

<!-- decision-id: wiki-category -->

權威來源於 `references/wiki-category-spec.md`，本表為摘要便於快速查找。

| Step | 類別 | 判定問題 | 關鍵線索 | 命中後 |
|------|------|---------|---------|--------|
| 1 | 實體 | 是否為具體可指稱的對象？ | 人名、工具名、產品名、組織名、框架名 | wiki_category = 實體 |
| 2 | 比較 | 是否涉及兩個以上對象的對比？ | 標題含 vs / 比較 / 對比 / 差異；核心價值在優缺點對照 | wiki_category = 比較 |
| 3 | 總覽 | 是否為橫跨多主題的綜論？ | 標題含 總覽 / 趨勢 / 現況 / 生態；涵蓋 ≥3 獨立子主題 | wiki_category = 總覽 |
| 4 | 概念 | 不符合上述三類 | 原理、方法論、理論、設計模式 | wiki_category = 概念（兜底） |

**判定原則**：
- 同一主題只落在一類
- 偏好順序：實體 > 比較 > 總覽 > 概念
- 工具 + 行為 = 實體（如「Obsidian 知識管理」優先歸為實體）
- 對比 = 比較（只要核心價值在對比方案優劣）

---

## 決策表 D：Archive Mode 路由

<!-- decision-id: archive-mode -->

權威來源於 `skills/archive/SKILL.md`，本表為決策邏輯。

| Mode | 觸發關鍵字 | 執行流程 | 產出 |
|------|-----------|---------|------|
| full-archive（預設）| 「歸檔」「整理 raw」「處理 inbox」「存起來」「整理」 | record-writer → wiki-writer upsert → 更新 index/log → 移至 archived | 歷史紀錄 + 知識筆記 + log/index 更新 |
| record-only | 「只記錄來源」「不要知識筆記」「存個紀錄」 | 只呼叫 record-writer → 追加 log.md | 僅歷史紀錄（無知識筆記）|
| knowledge-only | 「只要知識」「從歷史紀錄再推主題」「不需要來源記錄」 | 從指定歷史紀錄直接呼叫 wiki-writer | 僅知識筆記（不移 raw 檔）|
| 對話歸檔（前置）| 「歸檔對話」「歸檔當前對話」「把剛剛聊的存起來」 | 先執行 Step -1 寫入 raw，再走 full-archive | 對話 → raw → 完整歸檔 |

**路由優先順序**：
1. 先判斷是否為對話歸檔意圖 → 執行 Step -1 預處理
2. 再判斷 full-archive / record-only / knowledge-only

---

## 決策表 E：同名異物處理

<!-- decision-id: same-name-different-thing -->

權威來源於 `references/topic-matching-spec.md`「同名異物處理」段落。

| 情境 | `tags[0]` 第一層比對 | 判定 | 命名規則 |
|------|-------------------|------|---------|
| 相同 | 如同為 `技術` | 同一主題，upsert 合併 | 使用既有頁主標題 |
| 不同 | 如 `技術/AI` vs `學習/音樂` | 同名異物，建立新頁 | `主題知識/[cat]/[主題] ([分類詞]).md` |

**分類詞選擇**：優先使用所屬組織名、領域名、或最能區分的短詞

**範例**：
- `Claude (Anthropic).md` vs `Claude Debussy.md`
- `Python (程式語言).md` vs `Python (蛇類).md`

---

## 決策表 F：Record-Writer 序號決定

<!-- decision-id: record-sequence -->

權威來源於 `agents/record-writer.md` Step 6，本表為決策邏輯。

| 優先級 | 條件 | 序號來源 |
|--------|------|---------|
| P1 | 呼叫方提供 `**指定序號**` 參數 | 直接使用該序號（補零至兩位）|
| P2（預設）| 無指定序號 | 查詢目錄現有檔案數 + 1（補零至兩位）|

**並行場景的競態解決**：
- full-archive Step 0.5 和 record-only Step 0.5 必須預分配序號並透過 P1 傳入
- 單檔歸檔場景可退回 P2（無競態風險）

---

## 與 lint script 整合

`scripts/lint-specs.sh` 可透過本文件的 `decision-id` 註解進行交叉驗證：

1. 掃描本文件取得權威 decision-id 清單
2. 在引用方（skill / agent）搜尋對應 ID
3. 確認引用方不重複定義決策邏輯，僅引用本文件

範例擴充規則（未來加入 lint-specs.sh）：

```bash
# R6: 決策表權威性檢查
AUTHORITY_IDS=$(grep -oP 'decision-id: \K[a-z-]+' references/decision-tables-spec.md)
for id in $AUTHORITY_IDS; do
    # 確認引用方只有引用，無重複定義
    ...
done
```

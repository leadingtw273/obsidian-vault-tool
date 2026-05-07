# Knowledge Only：僅建立知識筆記

從指定的既有歷史紀錄檔案直接呼叫 wiki-writer 進行 upsert，跳過 record-writer。
適用於「來源已歸檔、但想補充或重新推導知識主題」的維護情境。

> 本模式跳過 record-writer，不刪除任何 raw 檔，但會更新 index.md 與追加 log.md。

---

## Step 0：解析目標歷史紀錄檔案 + 讀取 interaction_mode

### 0.1 讀取 interaction_mode（v0.9.0-beta 新增）

依 `${CLAUDE_PLUGIN_ROOT}/references/governance/agent-mode.md` 規範，從 vault CLAUDE.md 讀取 `interaction_mode` 欄位。若欄位缺失 → 使用預設 `human`。

### 0.2 解析目標歷史紀錄路徑

從使用者輸入解析目標歷史紀錄路徑。若使用者未明確指定，提示：

```
請提供 歷史紀錄/ 下的來源記錄檔案路徑，例如：
  歷史紀錄/文章/2026-04-05/001_概述.md
  （或完整絕對路徑）
```

等待使用者提供路徑後繼續。

---

## Step 1：讀取歷史紀錄檔案，解析來源資訊

使用 Read 工具讀取指定的歷史紀錄檔案（完整內容）。

從 frontmatter 提取：
- `title`（來源標題）
- `source`（來源 URL 或識別碼）
- `content_type`（來源類型）
- `author`
- `date`

從正文中提取 **`raw_archived_path`**：

在歷史紀錄正文末尾找到 `> 原始內容見 [[raw/archived/[檔名]]]` 這行反向連結，從中提取 `raw/archived/[檔名].md` 作為 `raw_archived_path`。

例如：
```
> 原始內容見 [[raw/archived/20260405-some-article.md]]
```
→ `raw_archived_path = raw/archived/20260405-some-article.md`

若找不到此反向連結（舊版歷史紀錄含 `## 原始來源內容` 區塊），改用該區塊下的全文作為原文輸入（不傳 `raw_archived_path`，wiki-writer 將從 `## 總結` 讀摘要）。

**主題列表決策**：
主對話自行從 `## 總結` 段落中分析並列出主題（不委派 sub-agent）。

**確認主題列表**：將分析出的主題列表顯示給使用者確認或調整：
```
已解析歷史紀錄：[來源標題]（[content_type]）

識別出以下知識主題：
1. [主題一]
2. [主題二]
...

請確認主題列表（直接回覆「確認」，或修改後回覆）：
```

等待使用者確認後繼續。

---

## Step 2：並行呼叫 wiki-writer（upsert 模式）

依確認後的主題數量，平行呼叫 wiki-writer agents。

Agent tool，`subagent_type: "obsidian-vault-tool:wiki-writer"`。

**每個 agent 的 Prompt**：
```
**主題**：[主題標題]
**寫入路徑**：主題知識/[wiki_category]/[主題標題].md（預設路徑，wiki-writer 可依 Step 4 匹配結果調整）
**來源記錄檔名**：[序號_概述]（從歷史紀錄路徑提取）
**來源記錄路徑**：[歷史紀錄完整路徑]
**raw_archived_path**：[raw/archived/[原始檔名].md]（從 Step 1 反向連結提取；若無則省略此欄位）
**來源類型**：[content_type]
**Vault 路徑**：[vault_path]
**Vault 名稱**：[vault_name]
**今日日期**：[YYYY-MM-DD]
**interaction_mode**：[human|agent]（由 Step 0.1 讀取）
**personal_writing**：[true|false]（從歷史紀錄路徑判斷：若含「個人寫作/」→ true）
**cli_write_mode**：[cli_first|native_only]（由共用前置讀取）
**本批次其他主題**：[列出本批次所有其他主題標題，每行一個；若僅一個主題則省略此欄位]
```

**等待輸出並解析**：
- 寫入路徑（`主題知識/[類別]/[標題].md`）
- 寫入模式（`新建` / `merge` / `衝突待裁決`）
- `wiki_category`
- 同主題判定結果
- 執行紀錄（存為 `knowledge_writer_logs[]`）

**衝突待裁決處理**：與 full-archive 相同。所有 agents 完成後，對有衝突的主題依序顯示候選清單，等待使用者裁決後重新呼叫該主題的 wiki-writer。

---

## Step 3：驗證（主對話執行）

對每篇新建或 merge 的知識筆記，使用 Read 工具讀取前 30 行（確保涵蓋完整 frontmatter），確認：

1. 第 1 行為 `---`
2. 第 2 行之後存在第二個 `---`（frontmatter 結束標記）
3. `sources:` 陣列每項被雙引號包覆
4. `wiki_category:` 值有效（限：實體/概念/比較/總覽）
5. `updated:` 格式正確（`YYYY-MM-DD`）

若驗證失敗，重新呼叫該主題的 wiki-writer（最多 2 次外部重試）。每次重試前宣告：
```
[外部驗證重試 N/2] 主題：[主題標題]，失敗項目：[具體項目]
```

2 次重試後仍失敗，**對該篇記錄為失敗，繼續處理其他篇**，最後在完成通知統一回報。

> **重試預算說明**：wiki-writer 內部有自己的驗證重試（最多 3 次）。此處外部重試是「整個 wiki-writer agent 重新呼叫」，最壞情況總寫入上限 12 次（3 次呼叫 × 每次 4 次寫入）。

---

## Step 4：更新 index.md（主對話執行）

讀取 `${CLAUDE_PLUGIN_ROOT}/references/structure/index-spec.md` 了解更新規則。

執行流程：

對本次所有寫入的知識筆記（新建 + merge，驗證通過者），對每個主題使用 `obsidian append` 追加一行條目：

```bash
obsidian append vault=[vault_name] path="index.md" content="\n[YYYY-MM-DD] [[主題知識/[類別]/[標題]|[標題]]] — [一行摘要]（sources: N）[new]"
```

- **新建主題**：末尾標記 `[new]`
- **merge 主題**：末尾標記 `[updated]`
- 每個主題各自一次 append，條目格式：
  ```
  [YYYY-MM-DD] [[主題知識/[類別]/[標題]|[標題]]] — [一行摘要]（sources: N）[new|updated]
  ```

> 注意：index.md 採 append-only 模式，不讀取整檔、不覆寫。curator skill 負責定期清理重複條目。

---

## Step 5：追加 log.md（主對話執行）

讀取 `${CLAUDE_PLUGIN_ROOT}/references/structure/log-spec.md` 了解格式。

使用 `obsidian append` 直接追加 knowledge-only 類型的 ingest 條目。

**v0.9.0-beta**：依 `interaction_mode` 決定條目標題格式（同 full-archive Step 5）。

```bash
obsidian append vault=[vault_name] path="log.md" content="\n## [YYYY-MM-DD HH:mm] ingest [agent] | [來源標題] (knowledge-only)\nmode: knowledge-only\ninteraction_mode: [human|agent]\ntouched_specs: [confidence-gating, contradictions, aliases-and-wikilink]\nfail_reason: none\nmanual_fix: no\n- new: [[主題知識/[類別]/主題A]], [[主題知識/[類別]/主題B]]\n- updated: [[主題知識/[類別]/主題C]]\n- high_candidate_promoted: [[主題知識/[類別]/主題D]]\n- contradiction_added: [[主題知識/[類別]/主題E]]"
```

**時間戳記**：執行 `date '+%Y-%m-%d %H:%M'` 取得當前本地時間。

條目格式說明：
```markdown

## [YYYY-MM-DD HH:mm] ingest [agent] | [來源標題] (knowledge-only)
mode: knowledge-only
interaction_mode: agent
touched_specs: [confidence-gating, contradictions, aliases-and-wikilink]
fail_reason: none
manual_fix: no
- new: [[主題知識/[類別]/主題A]], [[主題知識/[類別]/主題B]]
- updated: [[主題知識/[類別]/主題C]]
- high_candidate_promoted: [[主題知識/[類別]/主題D]]
- contradiction_added: [[主題知識/[類別]/主題E]]
```

> 本模式無 `record:` 行（因為沿用既有歷史紀錄，非本次新建）。若無新建主題則省略 `- new:` 行；若無更新主題則省略 `- updated:` 行。
> log.md 採 append-only 模式，不讀取整檔、不覆寫。

> 注意：**不移動任何 raw 檔**（本模式不涉及 raw/，raw/archived/ 中的原檔維持不動）。

---

## Step 6：完成通知

```
已完成知識筆記更新（來源：[歷史紀錄路徑]）：

知識筆記（共 N 篇）：
- [[主題一]] → 主題知識/[類別]/[標題].md（[新建/merge]）
- [[主題二]] → 主題知識/[類別]/[標題].md（[新建/merge]）
```

> 若有驗證失敗的筆記，在完成通知末尾附加：
```
⚠️ 以下知識筆記驗證失敗（已放棄寫入）：
- [主題X]：[失敗原因]
```

> 在完成通知最末尾，附加執行紀錄摘要：
```
---
## 執行紀錄摘要

**wiki-writer × N**
- [主題一]：✓ 新建，Level X 命中
- [主題二]：✓ merge 至 [[既有頁]]，aliases +1
- [主題三]：⚠️ 衝突待裁決 → 使用者選擇合併至 [[候選A]]，已重新寫入

**index.md**：已追加 X 筆條目（新建 + merge）
**log.md**：已追加 1 個 knowledge-only ingest 條目
```

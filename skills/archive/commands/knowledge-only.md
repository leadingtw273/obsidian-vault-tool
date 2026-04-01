# Knowledge Only：僅建立知識筆記

不建立來源記錄，直接從內容產生知識筆記。適用於「只要知識、不需要來源記錄」的情境。

---

## Step 0：主對話分析主題

主對話從使用者提供的內容中分析並產出知識主題列表（不委派 sub-agent）。
記錄來源 URL（若有）與原文內容。

---

## Step 1：knowledge-writer agent × N（平行）

依主題數量，平行呼叫 knowledge-writer agents。`subagent_type: "obsidian-vault-tool:knowledge-writer"`。

此模式無來源記錄，每個 agent 的 Prompt 改為：
```
**主題**：[主題標題]
**來源類型**：[content_type]
**原文內容**：[摘要或全文]
**來源 URL**：[URL 或 N/A]
**Vault 路徑**：[vault_path]
**Vault 名稱**：[vault_name]
**今日日期**：[YYYY-MM-DD]
```

> `source` 欄位填 URL 而非 wikilink（無來源記錄檔案可連結）。

**解析執行紀錄**：從每個 agent 輸出中提取 `## 執行紀錄` 區塊，依主題順序暫存為 `knowledge_writer_logs[]`。

---

## Step 2：驗證（主對話執行）

對每篇知識筆記，讀取前 16 行確認：
1. frontmatter 有完整起止 `---`
2. `source:` 值被雙引號包覆

若驗證失敗，重新呼叫 knowledge-writer agent 重寫該篇。

#### 外部驗證熔斷規則

每篇筆記最多**重新呼叫 knowledge-writer agent 2 次**（共驗證 3 次：原始 + 2 次重試）。

每次重新呼叫前宣告：
```
[外部驗證重試 N/2] 主題：[主題標題]，失敗項目：[具體項目]
```

若 2 次重試後仍驗證失敗，**對該篇記錄為失敗，繼續處理其他篇，最後統一在完成通知中回報**。

---

## Step 3：完成通知

```
已完成知識筆記：

知識筆記（共 N 篇）：
- [[主題一]] → 主題知識/[date]/[標題].md
- [[主題二]] → 主題知識/[date]/[標題].md
```

> 若有驗證失敗的筆記，在完成通知末尾附加：
```
⚠️ 以下筆記驗證失敗（已放棄寫入）：
- [主題X]：[失敗原因]
```

> 在完成通知最末尾，附加執行紀錄摘要：
```
---
## 執行紀錄摘要

**knowledge-writer × N**
- [主題一]：✓ 成功（寫入 [N] 次，驗證通過）
- [主題二]：✓ 成功（寫入 [N] 次，驗證通過）
```

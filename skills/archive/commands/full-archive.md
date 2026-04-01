# Full Archive：完整歸檔

同時建立來源記錄與知識筆記，適用於完整歸檔任何來源。

---

## Step 1：record-writer agent

Agent tool，`subagent_type: "obsidian-vault-tool:record-writer"`。

**Prompt**：
```
**來源**：[URL / 對話原文 / 貼入文字]
**Vault 路徑**：[vault_path]
**Vault 名稱**：[vault_name]
**今日日期**：[YYYY-MM-DD]
```

**等待輸出**：
```
來源記錄路徑：[完整路徑]
來源記錄檔名：[序號_概述]
知識主題列表：
1. [主題一]
2. [主題二]
來源類型：[content_type]

## 執行紀錄
（結構化執行紀錄，見 agent 定義）
```

**解析執行紀錄**：從輸出中提取 `## 執行紀錄` 區塊，暫存為 `record_writer_log`。

---

## Step 2：knowledge-writer agent × N（平行）

依主題數量，平行呼叫 knowledge-writer agents。`subagent_type: "obsidian-vault-tool:knowledge-writer"`。

**每個 agent 的 Prompt**：
```
**主題**：[主題標題]
**來源記錄檔名**：[序號_概述]
**來源記錄路徑**：[完整路徑]
**來源類型**：[content_type]
**Vault 路徑**：[vault_path]
**Vault 名稱**：[vault_name]
**今日日期**：[YYYY-MM-DD]
```

**解析執行紀錄**：從每個 agent 輸出中提取 `## 執行紀錄` 區塊，依主題順序暫存為 `knowledge_writer_logs[]`。

---

## Step 3：驗證（主對話執行）

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

## Step 4：完成通知

```
已完成歸檔：

來源記錄：
- [[序號_概述]] → 歷史紀錄/[type]/[date]/[序號]_[概述].md

知識筆記（共 N 篇）：
- [[主題一]] → 主題知識/[date]/[標題].md
- [[主題二]] → 主題知識/[date]/[標題].md
```

> 若有驗證失敗的筆記，在完成通知末尾附加：
```
⚠️ 以下筆記驗證失敗（已放棄寫入）：
- [主題X]：[失敗原因]
```

> 在完成通知最末尾，附加執行紀錄摘要（從暫存的 `record_writer_log` 和 `knowledge_writer_logs[]` 整合）：
```
---
## 執行紀錄摘要

**record-writer**
- 狀態：✓ 成功
- 內容獲取：[方法]（[N] 次嘗試）
- 識別主題：[N] 個
- 寫入：[路徑]

**knowledge-writer × N**
- [主題一]：✓ 成功（寫入 [N] 次，驗證通過）
- [主題二]：✓ 成功（寫入 [N] 次，驗證通過）
```

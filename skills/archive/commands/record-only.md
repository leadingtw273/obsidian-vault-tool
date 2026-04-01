# Record Only：僅建立來源記錄

只記錄來源，不產生知識筆記。適用於「存個紀錄就好」的情境。

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
知識主題列表：（忽略，此模式不使用）
來源類型：[content_type]

## 執行紀錄
（結構化執行紀錄，見 agent 定義）
```

**解析執行紀錄**：從輸出中提取 `## 執行紀錄` 區塊，暫存為 `record_writer_log`。

---

## Step 2：完成通知

```
已完成記錄：

來源記錄：
- [[序號_概述]] → 歷史紀錄/[type]/[date]/[序號]_[概述].md
```

> 在完成通知末尾附加執行紀錄摘要：
```
---
## 執行紀錄摘要

**record-writer**
- 狀態：✓ 成功
- 內容獲取：[方法]（[N] 次嘗試）
- 寫入：[路徑]
```

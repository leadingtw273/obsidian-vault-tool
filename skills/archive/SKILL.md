---
name: archive
description: >
  將任何來源（對話、YouTube、Facebook 貼文、文章、PDF、網頁等）完整歸檔至 Obsidian Vault。
  同時產生來源記錄（歷史紀錄/）與主題知識筆記（主題知識/），形成雙向連結。
  觸發情境：使用者說「歸檔這次對話」、「總結對話」、「session 歸檔」、
  「把這次對話存起來」、「記錄這次討論」、「歸檔對話」、
  「歸檔這篇」、「把這個存到知識庫」、「幫我整理這篇文章」、「幫我記錄這個」、「存起來」、
  「整理這個連結」、「這個值得記錄」；或貼入 YouTube 連結、文章 URL、PDF、
  Facebook 貼文並要求整理或總結；或要求 Claude 讀取某網頁內容並歸檔時，
  必須使用此 skill。
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash(${CLAUDE_PLUGIN_ROOT}/skills/obsidian-wsl-cli/scripts/obsidian.sh:*)", "Agent"]
---

> **前置檢查**：
> 1. 確認 Vault 根目錄存在 `CLAUDE.md`。
>    若不存在，**停止並提示**：「知識庫尚未初始化，請說『幫我建立知識庫』開始設定。」
> 2. 確認 CLAUDE.md 中 `plugin_version` 與當前 plugin 版本一致。
>    若不一致，提醒使用者執行「更新知識庫」以同步設定。

# Archive（完整歸檔）

這個 skill 是所有歸檔操作的主流程，透過兩個 custom agent 完成完整的歸檔工作：
record-writer（獲取內容、建立來源記錄）與 knowledge-writer × N（平行撰寫知識筆記）。
知識筆記透過 `source: [[記錄檔名]]` 連結至來源記錄；record 那邊透過 Obsidian 反向連結自動呈現引用關係。

---

## 2 步流程

### 步驟 1：啟動 record-writer agent

**Prompt 格式**：
```
**本次任務輸入**：
[使用者提供的來源：URL、對話原文或貼入文字]

**Vault 路徑**：[vault_path，來自 CLAUDE.md]
**今日日期**：[YYYY-MM-DD]
```

**等待輸出**：
```
來源記錄路徑：[vault 內完整路徑]
來源記錄檔名：[序號_概述，不含副檔名，如 01_Python入門教學]
知識主題列表：
1. [主題一]
2. [主題二]
...
來源類型：[content_type]
```

---

### 步驟 2：啟動 knowledge-writer agent × N（平行）

**等步驟 1 完成後**：

依知識主題列表數量，使用 Agent tool **平行**呼叫 N 個 knowledge-writer agent，互不等待

**每個 agent 的 Prompt 格式**：
```
**本次任務輸入（模式 A：archive 模式）**：
- 主題標題：[負責的那一個主題]
- 來源記錄路徑：[來自步驟 1]
- 來源記錄檔名：[來自步驟 1，用於 source wikilink]
- 來源類型：[來自步驟 1]

**Vault 路徑**：[vault_path，來自 CLAUDE.md]
**今日日期**：[YYYY-MM-DD]
```

**等全部 agent 完成**，收集所有知識筆記完整路徑（供完成通知使用）。

---

## 完成通知

```
已完成歸檔：

📄 來源記錄：
- [[序號_概述]] → 歷史紀錄/[type]/[date]/[序號]_[概述].md

📚 知識筆記（共 N 篇）：
- [[主題一]] → 主題知識/[date]/[標題].md
- [[主題二]] → 主題知識/[date]/[標題].md
...
```

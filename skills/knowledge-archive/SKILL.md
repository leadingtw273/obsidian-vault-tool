---
name: knowledge-archive
description: >
  將外部資訊萃取精華後只歸檔至主題知識目錄，不建立來源記錄。
  觸發情境：使用者說「只要知識整理」、「幫我萃取知識」、「不需要來源記錄」時使用。
  完整歸檔（同時產生來源記錄）請使用 archive skill。
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash(${CLAUDE_PLUGIN_ROOT}/skills/obsidian-wsl-cli/scripts/obsidian.sh:*)", "Agent"]
---

> **前置檢查**：
> 1. 確認 Vault 根目錄存在 `CLAUDE.md`。
>    若不存在，**停止並提示**：「知識庫尚未初始化，請說『幫我建立知識庫』開始設定。」
> 2. 確認 CLAUDE.md 中 `plugin_version` 與當前 plugin 版本一致。
>    若不一致，提醒使用者執行「更新知識庫」以同步設定。

# Knowledge Archive（知識歸檔）

這個 skill 只萃取並寫入 `主題知識/` 知識筆記，不建立歷史紀錄。
完整的雙向歸檔（歷史紀錄 + 知識筆記）請使用 `archive` skill。

Frontmatter Schema 說明見 `references/frontmatter-spec.md`。

---

## 知識筆記格式

**knowledge-writer agent 的格式規範（agent 啟動時依此執行）。**

```markdown
---
title: [主題標題]
date: [YYYY-MM-DD]
tags:
  - [層級結構標籤，如 技術/AI/LLM]
  - [拆解標籤1]
  - [拆解標籤2]
  - [其他標籤...]
source: [URL 或 "[[來源記錄檔名]]"]
category: [tags[0] 第一層]
content_type: [article/youtube/pdf/fb-post/webpage/conversation]
author: [原始作者，不適用則留空]
---

[主題相關的深度整理正文]

> 來源：[URL 或 [[來源記錄檔名]]]
```

**說明**：
- **standalone 模式**（直接呼叫此 skill）：`source` 填原始 URL，`> 來源` 填原始 URL
- **由 archive skill 呼叫**（透過 knowledge-writer agent）：`source` 填 `"[[來源記錄檔名]]"`，`> 來源` 填 `[[來源記錄檔名]]`

---

## 3 步流程（standalone 使用）

### 步驟 1：內容獲取

- 若為 URL：獲取完整網頁/文章/影片內容
- 若為直接貼入文字：直接使用

**輸出**：來源完整內容

---

### 步驟 2：內容分析

**執行**：
- 產出完整總結（不限字數）
- 識別內容主題（1-5 個），預擬知識筆記標題（中文，簡潔明確）
- 確認來源類型（article / youtube / pdf / fb-post / webpage / conversation）

**輸出**：
```
總結：[完整總結]

主題列表：
1. [主題一標題]
2. [主題二標題]
...

來源類型：[content_type]
```

---

### 步驟 3：啟動 knowledge-writer agent × N（平行執行）

等步驟 2 完成後，使用 Agent tool 平行呼叫 N 個 knowledge-writer agent，每個主題一個，互不等待。

**每個 agent 傳入**（standalone 模式，直接傳入原文，無來源記錄）：
- 主題標題
- 來源完整內容（步驟 1 獲取的原文）
- 整體總結（步驟 2 產出）
- 來源 URL（用於 source 欄位）
- 來源類型

**注意**：standalone 模式下，knowledge-writer agent 的 source 欄填原始 URL（而非 wikilink）。

---

## 完成通知

```
已完成知識歸檔：

📚 知識筆記（共 N 篇）：
- [[主題一標題]] → 主題知識/[date]/[標題].md
- [[主題二標題]] → 主題知識/[date]/[標題].md
...
```

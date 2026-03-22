---
name: record-archive
description: >
  將任何來源快速歸檔至歷史紀錄目錄，只建立來源記錄，不萃取知識筆記。
  觸發情境：使用者說「只記錄這個來源」、「記錄一下這篇」、「存個來源記錄」、
  「不需要知識整理，只要留個紀錄」時使用。
  完整歸檔（同時產生知識筆記）請使用 archive skill。
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash(${CLAUDE_PLUGIN_ROOT}/skills/obsidian-wsl-cli/scripts/obsidian.sh:*)", "Agent"]
---

> **前置檢查**：
> 1. 確認 Vault 根目錄存在 `CLAUDE.md`。
>    若不存在，**停止並提示**：「知識庫尚未初始化，請說『幫我建立知識庫』開始設定。」
> 2. 確認 CLAUDE.md 中 `plugin_version` 與當前 plugin 版本一致。
>    若不一致，提醒使用者執行「更新知識庫」以同步設定。

# Record Archive（來源記錄）

這個 skill 只建立 `歷史紀錄/` 來源記錄，不萃取主題知識筆記。
完整的雙向歸檔（歷史紀錄 + 知識筆記）請使用 `archive` skill。

---

## 來源類型 → 歷史紀錄目錄對應

**record-writer agent 依此規則路由（格式規範來源）。**

| content_type | 目錄 |
|---|---|
| `conversation` | `歷史紀錄/對話/[YYYY-MM-DD]/` |
| `youtube` | `歷史紀錄/YouTube/[YYYY-MM-DD]/` |
| `fb-post` | `歷史紀錄/Facebook/[YYYY-MM-DD]/` |
| `article` | `歷史紀錄/文章/[YYYY-MM-DD]/` |
| `pdf` | `歷史紀錄/文件/[YYYY-MM-DD]/` |
| `webpage` | `歷史紀錄/網頁/[YYYY-MM-DD]/` |

**檔名**：`[序號]_[來源概述].md`（序號從 01 起，依當日同目錄現有筆記數累加）

---

## 來源記錄筆記格式

**record-writer agent 的格式規範（agent 啟動時依此執行）。**

```markdown
---
title: [來源標題]
date: [YYYY-MM-DD]
source: [原始 URL 或對話識別資訊]
category: 來源紀錄
content_type: [conversation/youtube/fb-post/article/pdf/webpage]
author: [原始作者，不適用則留空]
---

## 總結

[完整總結，不限字數]

---

## 原始來源內容

[完整原始文字]
```

---

## 流程

使用 Agent tool 呼叫 record-writer agent，傳入以下 prompt：

**Prompt 格式**：
```
**本次任務輸入**：
[使用者提供的來源：URL、對話原文或貼入文字]

**Vault 路徑**：[vault_path，來自 CLAUDE.md]
**今日日期**：[YYYY-MM-DD]
```

**等待輸出**：來源記錄路徑（知識主題列表忽略不用）

---

## 完成通知

```
已完成來源記錄：

📄 來源記錄：
- [[序號_概述]] → 歷史紀錄/[type]/[date]/[序號]_[概述].md
```

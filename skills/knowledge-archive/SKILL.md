---
name: knowledge-archive
description: >
  將外部資訊（URL、文章、影片等）萃取精華後歸檔至主題知識目錄（SourceArchive）。
  執行內容獲取、內容分析、多主題知識筆記平行寫入。
  觸發情境：使用者說「歸檔這篇」、「把這個存到知識庫」、「幫我整理這篇文章」、「幫我記錄這個」、「存起來」、
  「整理這個連結」、「這個值得記錄」；或貼入 YouTube 連結、文章 URL、PDF、
  Facebook 貼文並要求整理或摘要；或要求 Claude 讀取某網頁內容並歸檔時，
  必須使用此 skill。
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash(${CLAUDE_PLUGIN_ROOT}/skills/obsidian-wsl-cli/scripts/obsidian.sh:*)"]
---

> **前置檢查**：
> 1. 確認 Vault 根目錄存在 `CLAUDE.md`。
>    若不存在，**停止並提示**：「知識庫尚未初始化，請說『幫我建立知識庫』開始設定。」
> 2. 確認 CLAUDE.md 中 `plugin_version` 與當前 plugin 版本一致。
>    若不一致，提醒使用者執行「更新知識庫」以同步設定。

# Source Archive（外部資源歸檔）

這個 skill 處理來自外部的資訊（URL、文章、影片等），
分析後萃取多個知識主題，平行寫入 `主題知識/` 目錄。

Frontmatter Schema 說明見 `references/frontmatter-spec.md`。
標籤規範見 `references/frontmatter-spec.md` 中的「標籤規則」段落。

---

## 3 步流程

### 步驟 1：內容獲取 Agent

**輸入**：使用者提供的 URL 或貼入的內容

**執行**：
- 若為 URL：獲取完整網頁/文章/影片內容
- 若為直接貼入文字：直接使用

**輸出**：來源完整內容（原始文字）

---

### 步驟 2：內容分析 Agent

**輸入**：步驟 1 的來源完整內容

**執行**：
- 分析內容，產出 200 字以內的整體摘要
- 識別內容涵蓋的多個獨立主題（通常 2-5 個）
- 為每個主題預擬知識筆記標題
- 確認來源類型（article / youtube / pdf / fb-post / webpage）

**輸出**：
```
整體摘要：[200 字以內]

主題列表：
1. [主題一標題]
2. [主題二標題]
...

來源類型：[content_type]
```

---

### 步驟 3：知識筆記 Agent × N（平行執行）

每個主題各啟動一個 Agent，平行處理，互不等待。

**輸入（各 Agent 獨立）**：
- 負責的主題名稱與預定標題
- 來源完整內容（供深入萃取）
- 整體摘要（供上下文理解）
- 來源 URL 或識別資訊

**執行**：
1. 針對該主題深入萃取重點，撰寫知識筆記正文
2. 呼叫 `tag-review` skill 取得標籤建議
3. 確認 `category`（等於 `tags[0]` 第一層）
4. 確定存放路徑：`主題知識/[YYYY-MM-DD]/[標題].md`
   - 日期為當日（格式 `YYYY-MM-DD`）
   - 子資料夾不存在時動態建立
5. 寫入筆記

**筆記格式**：

```markdown
---
title: [主題標題]
date: [YYYY-MM-DD]
tags:
  - [層級結構標籤，如 技術/AI/LLM]
  - [拆解標籤1]
  - [拆解標籤2]
  - [其他標籤...]
source: [URL]
category: [tags[0] 第一層]
content_type: [article/youtube/pdf/fb-post/webpage]
author: [原始作者，不適用則留空]
---

[主題相關的深度整理正文]
```

**輸出**：已寫入的筆記路徑

---

## 完成通知

所有知識筆記寫入完成後，回報：

```
已完成 Source Archive：

📚 知識筆記（共 N 篇）：
- [[主題一標題]] → 主題知識/[date]/[標題].md
- [[主題二標題]] → 主題知識/[date]/[標題].md
...
```

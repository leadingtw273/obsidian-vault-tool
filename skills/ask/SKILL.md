---
name: ask
description: 管理 QUESTIONS.md 開放問題隊列。把「我想搞清楚 X」結構化，讓 archive 新來源時能自動匹配。
triggers:
  - ask
  - add question
  - 我想搞清楚
  - 我想知道
  - open question
  - 待回答
tools: Read, Glob, Grep, Bash, Write
---

# ask skill

## 觸發詞

| 觸發詞 | 動作 |
|-------|------|
| `ask <問題>` | 新增為 open question |
| `add question <問題>` | 同上 |
| 「我想搞清楚...」「我想知道...」 | 提示是否新增為 question |
| 「open question」「待回答」 | 列出 open questions 清單 |
| `ask --close <Q-NNN>` | 關閉一個 open question（僅 human mode）|
| `ask --list` | 列出所有 questions |

## 排他規則

以下觸發詞**不應**路由到 ask：
- 「查一下 X」「wiki 裡有沒有」「整理一下 X 主題」→ 路由到 `query`
- 「歸檔」「處理這個 raw」→ 路由到 `archive`
- 「reflect」「找漏洞」「綜合分析」→ 路由到 `reflect`
- 「lint」「wiki 體檢」→ 路由到 `curator`

**區分 ask vs query 的關鍵**：
- 「**我想搞清楚** X」→ ask（記錄問題，稍後回答）
- 「**查一下** X」→ query（現在就回答）

如果使用者的意圖模糊，**優先路由到 query**（即時價值更高）。只有使用者明確表達「記下來」「稍後看」「先存起來」才走 ask。

## 執行

讀取 `commands/add-question.md` 並按其流程執行。

> **CLI Write Mode 提醒（v0.9.1）**：執行前讀取 vault CLAUDE.md 的 `cli_write_mode`（缺欄位預設 `cli_first`）。
> 若為 `native_only`，commands 中所有 `obsidian append / eval` 一律改用 Read/Edit/Write，
> 對照表見 `${CLAUDE_PLUGIN_ROOT}/references/cli-usage.md` 的「Mode 對照表」段落。

## 版本

v0.9.1 — 依 `references/workflow/ask-flow.md` spec 實作；新增 cli_write_mode 支援。

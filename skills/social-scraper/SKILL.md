---
name: social-scraper
description: >
  社群媒體內容爬取工具。從 Facebook、YouTube 等平台抓取最新貼文與影片，以結構化格式回傳給使用者。
  抓取時機由使用者自行決定，plugin 不預設任何固定週期。

  觸發情境：
  - 使用者說「初始化社群抓取」「social scraper init」「設定 scraper」→ 執行初始化精靈
  - 使用者說「抓取內容」「scrape」「抓一下」「幫我抓」→ 執行抓取
  - 使用者說「刷新登入」「refresh auth」「session 過期了」「重新登入」→ 刷新 session
  - 使用者說「管理追蹤目標」「新增目標」「刪除目標」「修改追蹤」「設定追蹤」→ 執行目標管理精靈
category: automation
risk: medium
allowed-tools:
  - Read
  - Write
  - Bash
  - mcp__plugin_playwright_playwright__browser_navigate
  - mcp__plugin_playwright_playwright__browser_snapshot
  - mcp__plugin_playwright_playwright__browser_click
  - mcp__plugin_playwright_playwright__browser_evaluate
  - mcp__plugin_playwright_playwright__browser_run_code
  - mcp__plugin_playwright_playwright__browser_fill_form
  - mcp__plugin_playwright_playwright__browser_wait_for
  - mcp__plugin_playwright_playwright__browser_press_key
---

# Social Scraper

社群媒體內容爬取 plugin。透過 Playwright MCP 操作瀏覽器，從 Facebook、YouTube 抓取最新內容並回傳結構化資料。

## 設計原則

- **單一職責**：只負責爬取並呈現內容，資料後續用途由使用者決定
- **零外部腳本**：所有操作透過 Playwright MCP 工具完成，無需額外安裝 Node.js / Python 腳本
- **長效 session**：登入一次可持續使用，只有 session 真正過期才需刷新

## 使用前提

Playwright MCP plugin 必須已啟用。若尚未設定，請參考 `references/mcp-setup.md`。

## 路由邏輯

根據使用者意圖，讀取並執行對應的命令檔案：

| 使用者意圖 | 執行檔案 |
|-----------|---------|
| 初始化、首次設定 | `commands/init.md` |
| 抓取內容 | `commands/scrape.md` |
| 刷新登入、session 過期 | `commands/refresh-auth.md` |
| 管理追蹤目標、新增/刪除/修改目標 | `commands/manage-targets.md` |

## 執行方式

判斷使用者意圖後，讀取對應的 `commands/*.md` 檔案，並嚴格按照其中的步驟執行。

```
PLUGIN_ROOT 為此 SKILL.md 所在目錄：${CLAUDE_PLUGIN_ROOT}/skills/social-scraper
USER_DATA 為使用者資料目錄：~/.claude/social-scraper
```

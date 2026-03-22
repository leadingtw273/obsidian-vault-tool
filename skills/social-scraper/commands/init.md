# Init：初始化精靈

首次使用前執行，完成後即可開始抓取。整個過程只需執行一次。

---

## Step 0：前置確認

讀取 `~/.claude/settings.json`，確認 playwright plugin 已啟用（`enabledPlugins` 中存在 `playwright@...` 的條目）。

若未啟用，停止並告知使用者：
> Playwright MCP plugin 尚未啟用，請參考 `references/mcp-setup.md` 完成安裝後再執行初始化。

---

## Step 1：建立使用者資料目錄

```bash
mkdir -p ~/.claude/social-scraper/playwright-auth
mkdir -p ~/.claude/social-scraper/config
```

---

## Step 2：設定追蹤目標

詢問使用者要追蹤的帳號，逐一收集：

```
請輸入你想追蹤的 Facebook / YouTube 帳號。
每個目標需要：名稱、平台（facebook/youtube）、類型、URL。

Facebook 類型：
  - profile：個人帳號（https://www.facebook.com/username）
  - page：粉絲專頁（https://www.facebook.com/pagename）
  - group：社團（https://www.facebook.com/groups/groupname）

YouTube 類型：
  - channel：頻道（https://www.youtube.com/@channelname）

輸入完畢後說「完成」。
```

收集完成後，將目標寫入 `~/.claude/social-scraper/config/targets.json`，格式如下：

```json
{
  "targets": [
    {
      "name": "使用者輸入的名稱",
      "platform": "facebook",
      "type": "profile",
      "url": "https://www.facebook.com/..."
    }
  ]
}
```

若使用者不確定格式，可參考 `config/targets.example.json`。

---

## Step 3：Facebook 登入

告知使用者：
> 接下來會開啟 Facebook 登入頁面。請在瀏覽器中完成登入（包含 2FA）。

執行步驟：

1. `browser_navigate` → `https://www.facebook.com/login`
2. `browser_snapshot` 確認登入頁已載入
3. 告知使用者可以開始輸入帳密：
   > 請使用以下工具輸入你的帳號和密碼（或直接在瀏覽器視窗操作）。
4. 使用 `browser_fill_form` 填入使用者提供的 email 和密碼
5. `browser_click` 點擊登入按鈕
6. 等待 2FA（若有）：持續 `browser_snapshot` 偵測，最多等待 120 秒
7. 確認登入成功：URL 應不含 `/login`，或頁面出現首頁 feed 元素
8. 儲存 session：
   ```javascript
   // 透過 browser_run_code 執行（server-side Playwright context）
   const state = await context.storageState();
   // 回傳 JSON 字串
   JSON.stringify(state)
   ```
9. 用 Write tool 將回傳的 JSON 存到 `~/.claude/social-scraper/playwright-auth/facebook.json`

**若 browser_run_code 無法存取 context**（備援）：
- 改用 `browser_evaluate` 取得可存取的 cookies：`document.cookie`
- 取得 localStorage：`JSON.stringify(Object.entries(localStorage))`
- 將這些資料組合成簡化的 session JSON 存檔（注意：httpOnly cookies 無法用此方式取得，session 效期可能較短）

---

## Step 4：YouTube 登入

告知使用者：
> 接下來會開啟 Google 登入頁面。請在瀏覽器中完成登入。

執行步驟：

1. `browser_navigate` → `https://accounts.google.com/signin`
2. `browser_snapshot` 確認登入頁已載入
3. 使用 `browser_fill_form` 填入 email，點擊下一步
4. 填入密碼，點擊下一步
5. 等待 2FA（若有）：持續 `browser_snapshot` 偵測，最多等待 120 秒
6. 導覽確認：`browser_navigate` → `https://www.youtube.com`
7. `browser_snapshot` 確認 YouTube 已顯示登入狀態（右上角有頭像）
8. 儲存 session（同 Step 3 的方式）
9. 用 Write tool 存到 `~/.claude/social-scraper/playwright-auth/youtube.json`

---

## Step 5：完成

顯示設定摘要：

```
✅ 初始化完成

追蹤目標：
[列出 targets.json 中的所有目標]

Session 已儲存：
- Facebook：~/.claude/social-scraper/playwright-auth/facebook.json
- YouTube：~/.claude/social-scraper/playwright-auth/youtube.json

使用方式：
- 說「抓取內容」→ 開始爬取所有追蹤目標
- 說「刷新登入」→ 僅在 session 過期時才需要執行

注意：session 通常數月內有效，不需要定期重新登入。
```

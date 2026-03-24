# Scrape Target：抓取追蹤目標

從設定的追蹤目標中，收集指定時間區間內有更新的文章/影片連結。只收集連結，不爬取內容。

---

## Step 0：讀取設定與時間區間

讀取 `~/.claude/social-scraper/config/targets.json`。

若檔案不存在，停止並提示：
> 尚未完成初始化，請先說「初始化社群抓取」。

### 解析時間區間

使用者應以自然語言提供時間區間，例如：
- 「最近一週」「最近三天」
- 「3月1日到3月15日」
- 「上個月」「這個月」

將自然語言解析為具體的起始日期與結束日期。若使用者未提供時間區間，詢問：
> 請提供要查詢的時間區間（例如：最近一週、3月1日到3月15日）。

將 targets 按 `platform` 欄位分組：
- `facebook` 類型的目標 → 使用 `playwright-auth/facebook.json` session
- `youtube` 類型的目標 → 使用 `playwright-auth/youtube.json` session

---

## Step 1：載入 Session

### Facebook Session

若有 Facebook 目標，讀取 `~/.claude/social-scraper/playwright-auth/facebook.json`。

若檔案不存在，停止並提示：
> Facebook session 不存在，請先說「初始化社群抓取」完成登入。

透過 `browser_run_code` 注入 session（server-side Playwright）：

```javascript
const storageState = /* facebook.json 的內容 */;
await context.addCookies(storageState.cookies);
for (const origin of storageState.origins || []) {
  // 需導覽到該 origin 後再注入
}
```

**若 browser_run_code 無法存取 context**（備援）：
- `browser_navigate` → `https://www.facebook.com`
- `browser_evaluate` 注入 localStorage 條目

### YouTube Session

若有 YouTube 目標，讀取 `~/.claude/social-scraper/playwright-auth/youtube.json`。

若檔案不存在，停止並提示：
> YouTube session 不存在，請先說「初始化社群抓取」完成登入。

注入 session（同 Facebook 的方式）。

---

## Step 2：收集 Facebook 目標連結

對每個 `platform: "facebook"` 的 target 依序執行：

### 2a. 導覽到目標頁面

`browser_navigate` → target 的 `url`

`browser_snapshot` 確認頁面已載入。

**Session 過期偵測**：若頁面 URL 包含 `/login` 或快照中出現登入表單，立即停止並提示：
> Facebook session 已過期，請說「刷新登入」重新登入後再試。

### 2b. 提取貼文連結

依 target type（profile / page / group）找到貼文清單。

**group** 類型嘗試時序排序：`{url}?sorting_setting=CHRONOLOGICAL`

對每篇貼文只需提取：
- **時間**：發文時間（原始文字，如「3小時前」「昨天」「3月10日」）
- **連結**：貼文永久連結

### 2c. 時間篩選

根據貼文的時間文字，判斷是否落在使用者指定的時間區間內：
- 將相對時間（如「3小時前」「昨天」）轉換為絕對日期進行比較
- 只保留時間區間內的貼文連結
- 若某篇貼文的時間已超出區間（早於起始日期），停止繼續向下捲動

---

## Step 3：收集 YouTube 目標連結

對每個 `platform: "youtube"` 的 target 依序執行：

### 3a. 導覽到頻道影片頁

`browser_navigate` → `{target.url}/videos`（若 URL 已含 `/videos` 則直接使用）

`browser_snapshot` 確認頁面已載入。

**Session 過期偵測**：若頁面顯示登入提示，停止並提示：
> YouTube session 已過期，請說「刷新登入」重新登入後再試。

### 3b. 提取影片連結

從頁面快照中找到影片項目，提取：
- **標題**：影片標題
- **URL**：`https://www.youtube.com/watch?v=...`
- **發布時間**：原始文字（如「3小時前」「昨天」「2週前」）

### 3c. 時間篩選

根據影片的發布時間，判斷是否落在使用者指定的時間區間內：
- 將相對時間轉換為絕對日期進行比較
- 只保留時間區間內的影片連結
- 若某部影片的時間已超出區間，停止繼續向下捲動

---

## Step 4：回傳連結清單

將收集到的連結整理為精簡格式輸出：

```markdown
# 追蹤目標更新（{起始日期} ~ {結束日期}）

## Facebook

### {target.name}（{target.type}）
- [{時間}] {連結}
- [{時間}] {連結}

---

## YouTube

### {target.name}
- [{發布時間}] [{標題}]({URL})
- [{發布時間}] [{標題}]({URL})

---
```

若某個目標在時間區間內沒有任何更新，顯示：
> {target.name}：該時段無更新

完成後告知使用者共收集了多少個連結（FB 貼文 N 篇、YT 影片 N 部），並說明這些連結可供後續使用 `scrape` 指令逐一爬取內容。

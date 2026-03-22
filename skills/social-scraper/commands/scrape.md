# Scrape：抓取內容

從設定的追蹤目標抓取最新貼文與影片，全程自動執行，無需使用者介入。

---

## Step 0：讀取設定

讀取 `~/.claude/social-scraper/config/targets.json`。

若檔案不存在，停止並提示：
> 尚未完成初始化，請先說「初始化社群抓取」。

將 targets 按 `platform` 欄位分組：
- `facebook` 類型的目標 → 使用 `playwright-auth/facebook.json` session
- `youtube` 類型的目標 → 使用 `playwright-auth/youtube.json` session

---

## Step 1：載入 Facebook Session

讀取 `~/.claude/social-scraper/playwright-auth/facebook.json`。

若檔案不存在，停止並提示：
> Facebook session 不存在，請先說「初始化社群抓取」完成登入。

透過 `browser_run_code` 注入 session（server-side Playwright）：

```javascript
// 從檔案內容解析 cookies 並注入
const storageState = /* facebook.json 的內容 */;
await context.addCookies(storageState.cookies);
// 若有 origins（localStorage），逐一注入
for (const origin of storageState.origins || []) {
  // 需導覽到該 origin 後再注入
}
```

**若 browser_run_code 無法存取 context**（備援）：
- `browser_navigate` → `https://www.facebook.com`
- `browser_evaluate` 注入 localStorage 條目

---

## Step 2：爬取 Facebook 目標

對每個 `platform: "facebook"` 的 target 依序執行：

### 2a. 導覽到目標頁面

`browser_navigate` → target 的 `url`

`browser_snapshot` 確認頁面已載入。

**Session 過期偵測**：若頁面 URL 包含 `/login` 或快照中出現登入表單，立即停止並提示：
> Facebook session 已過期，請說「刷新登入」重新登入後再試。

### 2b. 依 type 抓取貼文

**profile / page**：
- 滾動頁面載入最新貼文
- 找到 `[role="article"]` 或類似的貼文容器元素
- `browser_snapshot` 擷取頁面結構

**group**：
- 導覽到社團 feed（`{url}?sorting_setting=CHRONOLOGICAL` 嘗試時序排序）
- 找到貼文清單

### 2c. 提取貼文資料

對每篇貼文提取：
- **作者**：發文者名稱
- **時間**：發文時間（原始文字，如「3小時前」「昨天」或具體日期）
- **內文**：貼文文字內容（若有「查看更多」則嘗試展開）
- **連結**：貼文永久連結（`/posts/` 或 `?story_fbid=` 格式）
- **媒體描述**：若有圖片/影片，描述其內容（使用截圖分析）

---

## Step 3：載入 YouTube Session

讀取 `~/.claude/social-scraper/playwright-auth/youtube.json`。

若檔案不存在，停止並提示：
> YouTube session 不存在，請先說「初始化社群抓取」完成登入。

注入 session（同 Step 1 的方式）。

---

## Step 4：爬取 YouTube 目標

對每個 `platform: "youtube"` 的 target 依序執行：

### 4a. 導覽到頻道影片頁

`browser_navigate` → `{target.url}/videos`

`browser_snapshot` 確認頁面已載入。

**Session 過期偵測**：若頁面顯示登入提示，停止並提示：
> YouTube session 已過期，請說「刷新登入」重新登入後再試。

### 4b. 提取影片清單

從頁面快照中找到影片項目，提取：
- **標題**：影片標題
- **URL**：`https://www.youtube.com/watch?v=...`
- **發布時間**：原始文字（如「3小時前」「昨天」）
- **描述摘要**：若頁面顯示摘要則納入

---

## Step 5：回傳結果

將所有爬取結果整理為結構化 Markdown 輸出：

```markdown
# 社群內容抓取結果

## Facebook

### {target.name}（{target.type}）

#### {作者} · {時間}
{內文}
[查看原文]({連結})

---

## YouTube

### {target.name}

#### {標題}
發布時間：{時間}
{描述摘要}
[觀看影片]({URL})

---
```

若某個目標沒有找到任何內容，顯示：
> {target.name}：目前沒有可抓取的內容（可能是頁面結構變更，或該帳號近期無更新）

完成後告知使用者共抓取了多少篇 FB 貼文和多少部 YT 影片，並說明資料可供後續自行處理。


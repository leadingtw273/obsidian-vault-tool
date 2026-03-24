# Scrape：抓取內容

使用者提供 URL，爬取該頁面的完整內容並以結構化格式回傳。

---

## Step 0：取得 URL

使用者應在觸發時提供要爬取的 URL。

若未提供，詢問：
> 請提供要爬取的網址。

---

## Step 1：判斷平台並載入 Session

根據 URL 判斷平台：

- **facebook.com** → Facebook
- **youtube.com** → YouTube
- **其他** → 通用網頁

### Facebook

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

### YouTube

讀取 `~/.claude/social-scraper/playwright-auth/youtube.json`。

若檔案不存在，停止並提示：
> YouTube session 不存在，請先說「初始化社群抓取」完成登入。

注入 session（同 Facebook 的方式）。

### 通用網頁

不需載入 session，直接進入 Step 2。

---

## Step 2：導覽並爬取內容

`browser_navigate` → 使用者提供的 URL

`browser_snapshot` 確認頁面已載入。

**Session 過期偵測**（僅限 Facebook/YouTube）：
- Facebook：若頁面 URL 包含 `/login` 或快照中出現登入表單，停止並提示：
  > Facebook session 已過期，請說「刷新登入」重新登入後再試。
- YouTube：若頁面顯示登入提示，停止並提示：
  > YouTube session 已過期，請說「刷新登入」重新登入後再試。

### 根據平台提取內容

**Facebook 貼文頁面**：
- **作者**：發文者名稱
- **時間**：發文時間（原始文字，如「3小時前」「昨天」或具體日期）
- **內文**：貼文文字內容（若有「查看更多」則嘗試展開）
- **連結**：貼文永久連結（`/posts/` 或 `?story_fbid=` 格式）
- **媒體描述**：若有圖片/影片，描述其內容（使用截圖分析）

**YouTube 影片頁面**：
- **標題**：影片標題
- **發布時間**：原始文字
- **描述**：影片描述內容
- **頻道名稱**：上傳者名稱

**通用網頁**：
- **標題**：頁面標題（`<title>` 或主標題）
- **主要內容**：頁面主要文字內容（排除導覽、側邊欄、頁尾等非核心區域）
- **連結**：頁面中的重要連結

---

## Step 3：回傳結果

將爬取結果整理為結構化 Markdown 輸出：

### Facebook 貼文

```markdown
# 爬取結果：Facebook

## {作者} · {時間}
{內文}

[查看原文]({連結})
```

### YouTube 影片

```markdown
# 爬取結果：YouTube

## {標題}
頻道：{頻道名稱}
發布時間：{時間}

{描述}

[觀看影片]({URL})
```

### 通用網頁

```markdown
# 爬取結果：{標題}

{主要內容}

來源：{URL}
```

完成後告知使用者爬取完成，資料可供後續自行處理。

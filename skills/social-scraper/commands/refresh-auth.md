# Refresh Auth：刷新 Session

**此命令僅在 session 真正過期時才需執行。** 正常情況下 session 可持續數月，不需定期刷新。

通常的觸發情境：
- 執行 scrape 時被偵測到已登出
- 長時間未使用導致 session 失效
- 平台強制登出（如密碼變更、安全性通知）

---

## Step 0：確認

告知使用者：
> 此操作會重新開啟瀏覽器進行登入，並覆蓋現有的 session。
>
> 請確認你要刷新哪個平台的 session？（Facebook / YouTube / 兩者）

根據使用者回應，決定要刷新哪些平台。

---

## Step 1：刷新 Facebook Session（若需要）

執行與 `init.md` Step 3 完全相同的流程：

1. `browser_navigate` → `https://www.facebook.com/login`
2. 使用者完成登入（包含 2FA）
3. 確認登入成功
4. `browser_run_code` → `context.storageState()` 取得 session
5. Write tool 覆寫 `~/.claude/social-scraper/playwright-auth/facebook.json`

---

## Step 2：刷新 YouTube Session（若需要）

執行與 `init.md` Step 4 完全相同的流程：

1. `browser_navigate` → `https://accounts.google.com/signin`
2. 使用者完成登入（包含 2FA）
3. 導覽到 YouTube 確認登入狀態
4. `browser_run_code` → `context.storageState()` 取得 session
5. Write tool 覆寫 `~/.claude/social-scraper/playwright-auth/youtube.json`

---

## Step 3：確認

告知使用者刷新完成，可以重新執行抓取。

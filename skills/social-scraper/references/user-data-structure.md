# Social Scraper 使用者資料目錄結構

使用者執行期資料存放於 `~/.claude/social-scraper/`，與 skill 原始定義（`${CLAUDE_PLUGIN_ROOT}/skills/social-scraper/`）分離。

---

## 目錄結構

```
~/.claude/social-scraper/
├── config/              # 使用者主動設定（手動管理）
│   └── targets.json     # 追蹤目標清單
├── learned/             # AI 運行時累積的經驗（自動管理）
│   └── platform-notes.json  # 平台爬取經驗筆記
└── playwright-auth/     # 瀏覽器 session 資料（自動管理）
    ├── facebook.json    # Facebook storageState
    └── youtube.json     # YouTube/Google storageState
```

---

## 各目錄說明

### `config/` — 使用者設定

由使用者透過初始化精靈或管理精靈主動設定的資料。

| 檔案 | 用途 | 建立時機 |
|------|------|---------|
| `targets.json` | 追蹤目標清單（name, platform, type, url） | `init` 或 `manage-targets` 時寫入 |

格式範本：`references/targets.example.json`

### `learned/` — AI 學習經驗

每次爬取完成後，若發現平台特性（如 CSS 混淆、需截圖才能讀取時間戳等），由 skill 自動寫入。後續爬取前應先讀取此檔案，選擇對應策略。

| 檔案 | 用途 | 建立時機 |
|------|------|---------|
| `platform-notes.json` | 各平台的爬取經驗與策略 | 爬取過程中發現新特性時自動更新 |

### `playwright-auth/` — 瀏覽器 Session

Playwright storageState，包含 cookies 及 localStorage。登入一次可持續數月，只有真正過期才需刷新。

| 檔案 | 用途 | 建立時機 |
|------|------|---------|
| `facebook.json` | Facebook session | `init` Step 3 或 `refresh-auth` |
| `youtube.json` | YouTube/Google session | `init` Step 4 或 `refresh-auth` |

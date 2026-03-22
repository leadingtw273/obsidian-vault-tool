# Playwright MCP 設定說明

social-scraper 需要 Playwright MCP plugin 來操作瀏覽器。以下說明如何確認或安裝。

---

## 確認是否已安裝

在 Claude Code 中執行：

```
/plugins
```

若清單中有 `playwright` 即代表已安裝，可直接使用。

---

## 安裝方式

在 Claude Code 中執行：

```
/install-plugin playwright@claude-plugins-official
```

安裝完成後重啟 Claude Code 使設定生效。

---

## 確認設定

安裝後，`~/.claude/settings.json` 中應包含：

```json
{
  "enabledPlugins": {
    "playwright@claude-plugins-official": true
  }
}
```

---

## 常見問題

**Q：需要安裝 Playwright 本體嗎？**
A：Playwright MCP plugin 已包含所需的瀏覽器驅動，通常不需要額外安裝。若遇到瀏覽器啟動失敗，可嘗試在終端執行：
```bash
npx playwright install chromium
```

**Q：可以使用現有的瀏覽器設定檔嗎？**
A：目前 social-scraper 使用獨立的 session 檔案（storageState），與瀏覽器本機設定檔分開管理，避免互相干擾。

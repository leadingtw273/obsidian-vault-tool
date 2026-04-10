# Expected: case-05-path-injection

## 預期行為

record-writer Step 2（欄位驗證 + 路徑安全檢查）偵測到 title 含 `../`，
立即熔斷並輸出以下格式：

```
⛔ 歸檔中斷：偵測到不安全路徑輸入

失敗步驟：record-writer Step 2
raw 檔：[絕對路徑]/tests/fixtures/test-vault/raw/case-05-path-injection.md
欄位：title
值：../../../etc/passwd
違反模式：P1（相對父路徑）

這可能是路徑穿越攻擊或輸入錯誤。請檢查 raw 檔內容後重新觸發歸檔。
```

## 禁止行為

- ❌ 不可寫入 `/etc/passwd` 或任何 Vault 外檔案
- ❌ 不可自動清洗為合法路徑後繼續（REJECT 不應降級為 SANITIZE）
- ❌ 不可移動 raw 檔至 raw/archived/（因為未成功歸檔）

## 驗證重點

- raw 檔必須**留在 raw/**（未被移動）
- `歷史紀錄/` 下不應出現任何新檔案
- `/etc/` 下不應被修改（安全關鍵）

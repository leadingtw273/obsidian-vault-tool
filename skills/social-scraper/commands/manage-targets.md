# Manage Targets：管理追蹤目標

互動式精靈，引導使用者新增、刪除或修改 `targets.json` 中的追蹤目標。

---

## Step 0：讀取現有設定

讀取 `~/.claude/social-scraper/config/targets.json`。

若檔案不存在：
> targets.json 尚未建立。將從空清單開始，完成後自動建立。

---

## Step 1：顯示現有目標

以編號清單呈現所有目標：

```
目前追蹤目標：
1. 我的 FB（facebook · profile）https://www.facebook.com/...
2. 某頻道（youtube · channel）https://www.youtube.com/@...
（共 2 個）
```

若清單為空，顯示：
> 目前沒有追蹤目標。

---

## Step 2：選擇操作

詢問使用者：

```
請選擇操作：
  新增 — 加入新的追蹤目標
  刪除 — 移除現有目標
  修改 — 編輯現有目標
  完成 — 儲存並結束
```

---

## [新增]

逐步引導輸入以下欄位：

1. **名稱**：自訂顯示名稱（例如：「我的 FB」「某某頻道」）
2. **平台**：`facebook` 或 `youtube`
3. **類型**：
   - facebook：`profile`（個人帳號）/ `page`（粉絲專頁）/ `group`（社團）
   - youtube：`channel`
4. **URL**：完整網址

URL 格式驗證：
- facebook profile/page：`https://www.facebook.com/...`
- facebook group：`https://www.facebook.com/groups/...`
- youtube channel：`https://www.youtube.com/@...`

加入後詢問是否繼續新增。回答「是」則重複此流程；回答「否」或「完成」則回到主選單。

---

## [刪除]

重新顯示目前目標（帶編號）。

```
請輸入要刪除的編號（多個請以空格分隔，例如：1 3）：
```

確認刪除前顯示目標名稱請使用者確認：

```
確認刪除以下目標？
- 我的 FB（facebook · profile）
輸入「是」確認，輸入任何其他內容取消。
```

確認後從清單中移除，回到主選單。

---

## [修改]

重新顯示目前目標（帶編號）。

```
請選擇要修改的目標編號：
```

顯示該目標的現有值，逐欄詢問是否修改：

```
名稱：我的 FB（直接 Enter 保持不變）
平台：facebook（直接 Enter 保持不變）
類型：profile（直接 Enter 保持不變）
URL：https://...（直接 Enter 保持不變）
```

修改完成後回到主選單。

---

## Step 3：儲存

使用者選擇「完成」後，將更新後的完整 targets 陣列寫入：

```
~/.claude/social-scraper/config/targets.json
```

---

## Step 4：顯示完成摘要

```
✅ 追蹤目標已更新（共 N 個）：
1. 名稱（platform · type）URL
2. ...
```

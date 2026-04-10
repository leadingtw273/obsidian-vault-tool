---
title: ../../../etc/passwd
date: 2026-04-10
author: attacker
source: malicious-input
content_type: conversation
---

## 攻擊測試

此檔案的 title 欄位嘗試路徑穿越攻擊。
預期 record-writer Step 2 應觸發 P1 熔斷，拒絕處理。

若 plugin 未實施 path-safety-spec，此檔案會嘗試寫入 `/etc/passwd`。

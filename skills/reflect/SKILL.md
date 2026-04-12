---
name: reflect
description: 二階認知活動 — 反向檢驗、模式掃描、Gap Analysis。定期審視知識庫，找出回音室風險、知識空白、隱性關聯。
triggers:
  - reflect
  - 二階分析
  - 綜合分析
  - 發現規律
  - 找漏洞
  - 找空白
  - 知識庫體檢
tools: Read, Glob, Grep, Bash, Write
---

# reflect skill

## 觸發詞

| 觸發詞 | 動作 |
|-------|------|
| `reflect` | 完整三階段（Stage 0 + Stage 1 + Stage 3）|
| `reflect --stage 0` | 只跑反向檢驗 |
| `reflect --stage 3` | 只跑 Gap Analysis |
| `reflect --topic <slug>` | 對特定 topic 跑反向檢驗 |
| 「二階分析」「綜合分析」「發現規律」 | 完整三階段 |
| 「找漏洞」「找空白」 | 跑 Stage 3 |

## 排他規則

以下觸發詞**不應**路由到 reflect：
- 「查一下 X」「wiki 裡有沒有」→ 路由到 `query`
- 「歸檔」「處理這個 raw」→ 路由到 `archive`
- 「我想搞清楚 X」→ 路由到 `ask`
- 「lint」「wiki 體檢」→ 路由到 `curator`

reflect 的核心語意是「**檢視知識庫自身的健康**」，不是「回答問題」也不是「歸檔來源」。

## 執行

讀取 `commands/reflect.md` 並按其流程執行。

## 版本

v0.9.0-rc — Preview 版本（Stage 0 + Stage 1 輕量 + Stage 3）。Stage 2 深度合成延 v1.0。

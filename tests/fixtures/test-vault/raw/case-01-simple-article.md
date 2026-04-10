---
title: RAG 架構簡介
date: 2026-04-10
author: test-author
source: https://example.com/rag-intro
content_type: article
---

## 內容

RAG（Retrieval-Augmented Generation）是一種結合檢索與生成的 LLM 架構。
它透過向量資料庫查詢相關文件，再將結果作為 LLM 的上下文輸入，提高回答品質。

核心組件：
- Embedding 模型
- 向量資料庫
- Chunk 切分策略
- 重排序演算法

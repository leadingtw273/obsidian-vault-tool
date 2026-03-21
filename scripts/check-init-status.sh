#!/bin/bash
# check-init-status.sh
# 檢查指定路徑是否已完成 vault 初始化
# 用法：check-init-status.sh [vault_path]
# 返回：ALREADY_INITIALIZED / NOT_INITIALIZED / PATH_NOT_EXIST

VAULT_PATH="${1:-$(pwd)}"

if [ ! -d "$VAULT_PATH" ]; then
  echo "PATH_NOT_EXIST: $VAULT_PATH does not exist"
  exit 1
fi

CLAUDE_MD="$VAULT_PATH/CLAUDE.md"

if [ ! -f "$CLAUDE_MD" ]; then
  echo "NOT_INITIALIZED: CLAUDE.md not found at $VAULT_PATH"
  exit 1
fi

if grep -q "plugin_version" "$CLAUDE_MD"; then
  echo "ALREADY_INITIALIZED: CLAUDE.md found with plugin_version at $VAULT_PATH"
  exit 0
else
  echo "NOT_INITIALIZED: CLAUDE.md exists but missing plugin_version"
  exit 1
fi

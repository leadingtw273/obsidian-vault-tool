#!/bin/bash
# 檢查 obsidian-skills plugin 是否已安裝
# 讀取 installed_plugins.json 並搜尋 key
# 返回 0 = 已安裝, 1 = 未安裝或找不到清單

PLUGINS_FILE="$HOME/.claude/plugins/installed_plugins.json"

if [ ! -f "$PLUGINS_FILE" ]; then
  echo "NOT_FOUND: installed_plugins.json does not exist at $PLUGINS_FILE"
  exit 1
fi

if grep -q "obsidian-skills" "$PLUGINS_FILE"; then
  echo "INSTALLED"
  exit 0
else
  echo "NOT_INSTALLED: obsidian-skills not found in installed_plugins.json"
  echo "Install with:"
  echo "  /plugin marketplace add kepano/obsidian-skills"
  echo "  /plugin install obsidian@obsidian-skills"
  exit 1
fi

#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BATS_CMD="${BATS_CMD:-}"

if [ -z "$BATS_CMD" ]; then
    if command -v bats >/dev/null 2>&1; then
        BATS_CMD="$(command -v bats)"
    elif [ -x "$HOME/.local/bin/bats" ]; then
        BATS_CMD="$HOME/.local/bin/bats"
    else
        echo "错误: 未找到 bats 命令。" >&2
        echo "请通过 BATS_CMD 指定 bats 可执行路径。" >&2
        echo "示例: BATS_CMD=$HOME/.local/bin/bats ./scripts/test.sh" >&2
        exit 1
    fi
fi

echo "使用 bats: $BATS_CMD"
echo "执行测试: $ROOT_DIR/tests/test_ocr.bats"

"$BATS_CMD" "$ROOT_DIR/tests/test_ocr.bats"

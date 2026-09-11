#!/usr/bin/env bash
# test_modal_lifecycle.sh - Lifecycle cleanup for every modal handle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "${SCRIPT_DIR}/.." && pwd)/src/main.c"

echo "=== Modal Lifecycle Contract ==="

python3 - "${SRC}" <<'PY'
import re
import sys

source = open(sys.argv[1], encoding="utf-8").read()
match = re.search(r"static void app_destroy\(void\)\s*\{(.*?)\n\}", source, re.S)
if not match:
    raise SystemExit("[FAIL] app_destroy not found")

body = match.group(1)
required = [
    "s_modal_open = false;",
    "s_modal = TAB5_UI_INVALID_OBJ;",
    "s_modal_backdrop = TAB5_UI_INVALID_OBJ;",
    "s_modal_card = TAB5_UI_INVALID_OBJ;",
    "s_cfg_url = TAB5_UI_INVALID_OBJ;",
    "s_cfg_token = TAB5_UI_INVALID_OBJ;",
    "s_cfg_model = TAB5_UI_INVALID_OBJ;",
    "s_cfg_max_tokens = TAB5_UI_INVALID_OBJ;",
    "s_btn_save = TAB5_UI_INVALID_OBJ;",
    "s_btn_cancel_cfg = TAB5_UI_INVALID_OBJ;",
]

missing = [statement for statement in required if statement not in body]
if missing:
    for statement in missing:
        print(f"[FAIL] app_destroy missing: {statement}")
    raise SystemExit(1)

print("[PASS] app_destroy resets s_modal_open")
print("[PASS] app_destroy invalidates all nine modal handles")
PY

echo "=== Modal Lifecycle Contract: PASSED ==="

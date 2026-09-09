#!/usr/bin/env bash
# test_build.sh - Build test for the Tab5 Chat App
# Verifies that the build process completes successfully
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_SCRIPT="${APP_DIR}/tools/build.sh"

echo "=== Build Test ==="
echo ""

# Check if build script exists
if [ ! -f "${BUILD_SCRIPT}" ]; then
    echo "[FAIL] Build script not found: ${BUILD_SCRIPT}"
    exit 1
fi

# Check if build script is executable
if [ ! -x "${BUILD_SCRIPT}" ]; then
    echo "[INFO] Making build script executable..."
    chmod +x "${BUILD_SCRIPT}"
fi

# Run the build
echo "[INFO] Running build script..."
if bash "${BUILD_SCRIPT}" 2>&1; then
    echo "[PASS] Build completed successfully"

    # Verify output artifacts
    if [ -f "${APP_DIR}/app.wasm" ]; then
        echo "[PASS] app.wasm generated"
    else
        echo "[FAIL] app.wasm not generated"
        exit 1
    fi

    if [ -f "${APP_DIR}/dist/com.tab5.chat.tab5pkg" ]; then
        echo "[PASS] Package generated: dist/com.tab5.chat.tab5pkg"
    else
        echo "[FAIL] Package not generated"
        exit 1
    fi

    echo ""
    echo "=== Build Test Results: ALL PASSED ==="
    exit 0
else
    echo "[FAIL] Build script failed with exit code $?"
    exit 1
fi

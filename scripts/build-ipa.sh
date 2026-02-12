#!/bin/bash
set -euo pipefail

# iOS IPA Build Script
# Usage: ./scripts/build-ipa.sh [--bundle-id <id>] [--export-options <plist>]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Defaults
BUNDLE_ID="${PRODUCT_BUNDLE_IDENTIFIER:-si.mox.mux-pod}"
DEFAULT_BUNDLE_ID="si.mox.mux-pod"
EXPORT_OPTIONS=""
BUILD_MODE="release"
SKIP_CLEAN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --bundle-id)
      BUNDLE_ID="$2"
      shift 2
      ;;
    --export-options)
      EXPORT_OPTIONS="$2"
      shift 2
      ;;
    --debug)
      BUILD_MODE="debug"
      shift
      ;;
    --skip-clean)
      SKIP_CLEAN=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --bundle-id <id>         Override Bundle Identifier (default: si.mox.mux-pod)"
      echo "  --export-options <plist> Path to ExportOptions.plist"
      echo "  --debug                  Build in debug mode"
      echo "  --skip-clean             Skip flutter clean"
      echo "  -h, --help               Show this help"
      echo ""
      echo "Environment variables:"
      echo "  PRODUCT_BUNDLE_IDENTIFIER  Bundle ID (same as --bundle-id)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

cd "$PROJECT_ROOT"

echo "=== iOS IPA Build ==="
echo "Bundle ID: $BUNDLE_ID"
echo "Build mode: $BUILD_MODE"
echo ""

# Update xcconfig files if bundle ID is different
XCCONFIG_FILES=(
  "ios/Flutter/Debug.xcconfig"
  "ios/Flutter/Release.xcconfig"
)

update_bundle_id() {
  local new_id="$1"
  for file in "${XCCONFIG_FILES[@]}"; do
    if [[ -f "$file" ]]; then
      # macOS (BSD sed) requires '' after -i, GNU sed does not
      if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s/^PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = $new_id/" "$file"
      else
        sed -i "s/^PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = $new_id/" "$file"
      fi
    fi
  done
}

restore_bundle_id() {
  update_bundle_id "$DEFAULT_BUNDLE_ID"
}

# Set trap to restore on exit
trap restore_bundle_id EXIT

# Update Bundle ID in xcconfig
if [[ "$BUNDLE_ID" != "$DEFAULT_BUNDLE_ID" ]]; then
  echo "Updating Bundle ID to: $BUNDLE_ID"
  update_bundle_id "$BUNDLE_ID"
fi

# Clean previous build
if [[ "$SKIP_CLEAN" == false ]]; then
  echo "Cleaning previous build..."
  flutter clean
fi

# Get dependencies
echo "Getting dependencies..."
flutter pub get

# Build IPA
echo "Building IPA..."
FLUTTER_ARGS=(build ipa)

# --release is default, only add flag for debug/profile
if [[ "$BUILD_MODE" != "release" ]]; then
  FLUTTER_ARGS+=("--$BUILD_MODE")
fi

if [[ -n "$EXPORT_OPTIONS" ]]; then
  FLUTTER_ARGS+=(--export-options-plist "$EXPORT_OPTIONS")
fi

# Version info via --dart-define
if [[ -n "${APP_VERSION:-}" ]]; then
  FLUTTER_ARGS+=(--dart-define "APP_VERSION=${APP_VERSION}")
fi
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "")
if [[ -n "$GIT_BRANCH" && -n "$GIT_HASH" ]]; then
  FLUTTER_ARGS+=(--dart-define "GIT_REF=${GIT_BRANCH}@${GIT_HASH}")
fi

flutter "${FLUTTER_ARGS[@]}"

# Output location
IPA_PATH="$PROJECT_ROOT/build/ios/ipa"
echo ""
echo "=== Build Complete ==="
echo "IPA location: $IPA_PATH"
ls -la "$IPA_PATH"/*.ipa 2>/dev/null || echo "No IPA file found"

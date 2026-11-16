#!/usr/bin/env bash
#
# build.sh — Build OneXray for all supported platforms.
#
# Usage:
#   ./build.sh [--release|--debug] [--arch amd64|arm64] <target>
#   Targets: windows linux macos android ios all
#
# Defaults: release build, host architecture, target=all.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BUILD_MODE="release"
BUILD_ARCH=""
TARGET="all"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --release)
            BUILD_MODE="release"
            shift
            ;;
        --debug)
            BUILD_MODE="debug"
            shift
            ;;
        --arch)
            BUILD_ARCH="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--release|--debug] [--arch amd64|arm64] <target>"
            echo "Targets: windows linux macos android ios all"
            exit 0
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

if ! command -v flutter &>/dev/null; then
    echo "ERROR: flutter not found on PATH" >&2
    exit 1
fi

# --- Version requirements from pubspec.yaml ---
REQUIRED_FLUTTER="3.50.0"
REQUIRED_DART="3.14.0"

version_ge() {
    # returns 0 if $1 >= $2 (semver, numeric components)
    local a="$1" b="$2"
    local IFS=.
    read -ra aa <<< "$a"
    read -ra bb <<< "$b"
    local i
    for i in 0 1 2; do
        local x="${aa[i]:-0}" y="${bb[i]:-0}"
        if (( 10#$x > 10#$y )); then return 0; fi
        if (( 10#$x < 10#$y )); then return 1; fi
    done
    return 0
}

echo "==> Flutter version check"
FLUTTER_VERSION="$(flutter --version 2>/dev/null | sed -n 's/.*Flutter \([0-9][^ ]*\).*/\1/p' | head -1)"
DART_VERSION="$(flutter --version 2>/dev/null | sed -n 's/.*Dart \([0-9][^ ]*\).*/\1/p' | head -1)"

echo "  Flutter: ${FLUTTER_VERSION:-unknown} (need >= ${REQUIRED_FLUTTER})"
echo "  Dart:    ${DART_VERSION:-unknown} (need >= ${REQUIRED_DART})"

if [[ -n "${FLUTTER_VERSION:-}" ]] && ! version_ge "$FLUTTER_VERSION" "$REQUIRED_FLUTTER"; then
    echo "ERROR: Flutter $FLUTTER_VERSION is too old; pubspec.yaml requires >= $REQUIRED_FLUTTER" >&2
    echo "  Upgrade Flutter: flutter upgrade" >&2
    exit 1
fi

if [[ -n "${DART_VERSION:-}" ]] && ! version_ge "$DART_VERSION" "$REQUIRED_DART"; then
    echo "ERROR: Dart SDK $DART_VERSION is too old; pubspec.yaml requires >= $REQUIRED_DART" >&2
    echo "  Upgrade Flutter: flutter upgrade" >&2
    exit 1
fi

echo "==> Flutter doctor (informational)"
flutter doctor || true

echo "==> flutter pub get"
flutter pub get

echo "==> Code generation"
dart run build_runner build --delete-conflicting-outputs
dart run pigeon --input pigeon/message.dart
dart run tool/ffigen.dart

build_windows() {
    local mode_flag=""
    [[ "$BUILD_MODE" == "release" ]] && mode_flag="--release"
    local arch_flag=""
    if [[ -n "$BUILD_ARCH" ]]; then
        case "$BUILD_ARCH" in
            amd64|x64) arch_flag="--target-platform windows_x64" ;;
            arm64) arch_flag="--target-platform windows_arm64" ;;
            *) echo "WARNING: unknown arch $BUILD_ARCH for windows, using host" ;;
        esac
    fi
    echo "==> Building Windows ($BUILD_MODE $arch_flag)"
    flutter build windows $mode_flag $arch_flag
}

build_linux() {
    local mode_flag=""
    [[ "$BUILD_MODE" == "release" ]] && mode_flag="--release"
    local arch_flag=""
    if [[ -n "$BUILD_ARCH" ]]; then
        case "$BUILD_ARCH" in
            amd64|x64) arch_flag="--target-platform linux_x64" ;;
            arm64|aarch64) arch_flag="--target-platform linux_arm64" ;;
            *) echo "WARNING: unknown arch $BUILD_ARCH for linux, using host" ;;
        esac
    fi
    echo "==> Building Linux ($BUILD_MODE $arch_flag)"
    flutter build linux $mode_flag $arch_flag
}

build_macos() {
    local mode_flag=""
    [[ "$BUILD_MODE" == "release" ]] && mode_flag="--release"
    echo "==> Building macOS ($BUILD_MODE)"
    flutter build macos $mode_flag
}

build_android() {
    local mode_flag=""
    [[ "$BUILD_MODE" == "release" ]] && mode_flag="--release"
    echo "==> Building Android APK ($BUILD_MODE)"
    flutter build apk $mode_flag
    echo "==> Building Android AAB ($BUILD_MODE)"
    flutter build appbundle $mode_flag
}

build_ios() {
    local mode_flag=""
    [[ "$BUILD_MODE" == "release" ]] && mode_flag="--release"
    echo "==> Building iOS IPA ($BUILD_MODE)"
    flutter build ipa $mode_flag
}

case "$TARGET" in
    windows)
        build_windows
        ;;
    linux)
        build_linux
        ;;
    macos)
        build_macos
        ;;
    android)
        build_android
        ;;
    ios)
        build_ios
        ;;
    all)
        build_windows
        build_linux
        build_macos
        build_android
        build_ios
        ;;
    *)
        echo "ERROR: unknown target '$TARGET'" >&2
        echo "Valid targets: windows linux macos android ios all" >&2
        exit 1
        ;;
esac

echo "==> Build complete: $TARGET ($BUILD_MODE)"

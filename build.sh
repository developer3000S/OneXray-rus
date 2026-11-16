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

echo "==> Flutter doctor"
flutter doctor

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

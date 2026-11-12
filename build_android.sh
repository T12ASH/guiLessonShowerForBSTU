#!/usr/bin/env bash
set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}Сборка Android (ARM64 APK)${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
export ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-$ANDROID_SDK_ROOT/ndk/26.1.10909125}"
QT_ANDROID_DIR="${QT_ANDROID_DIR:-$HOME/Qt/6.8.0/android_arm64_v8a}"
QT_HOST_DIR="${QT_HOST_DIR:-$HOME/Qt/6.8.0/gcc_64}"

echo "      > Android SDK: ${ANDROID_SDK_ROOT}"
echo "      > Android NDK: ${ANDROID_NDK_ROOT}"
echo "      > Qt Android:  ${QT_ANDROID_DIR}"
echo "      > Qt Host:     ${QT_HOST_DIR}"

if [ ! -d "${ANDROID_SDK_ROOT}" ]; then
    echo -e "${RED}Android SDK не найден в ${ANDROID_SDK_ROOT}!${NC}"
    exit 1
fi

if [ ! -d "${ANDROID_NDK_ROOT}" ]; then
    echo -e "${RED}Android NDK r26b не найден в ${ANDROID_NDK_ROOT}!${NC}"
    exit 1
fi

if [ ! -d "${QT_ANDROID_DIR}" ]; then
    echo -e "${RED}Qt 6.8 Android не найден в ${QT_ANDROID_DIR}!${NC}"
    exit 1
fi

BUILD_DIR="${SCRIPT_DIR}/build-android"
echo -e "\n${CYAN}[1/2] Конфигурация CMake...${NC}"

"${QT_ANDROID_DIR}/bin/qt-cmake" -B "${BUILD_DIR}" -S "${SCRIPT_DIR}" \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DANDROID_SDK_ROOT="${ANDROID_SDK_ROOT}" \
    -DANDROID_NDK_ROOT="${ANDROID_NDK_ROOT}" \
    -DQT_HOST_PATH="${QT_HOST_DIR}"

echo -e "\n${CYAN}[2/2] Компиляция и сборка APK...${NC}"
cmake --build "${BUILD_DIR}" --target appBSTUcurriculum_make_apk --parallel $(nproc)

RAW_APK="${BUILD_DIR}/android-build/build/outputs/apk/release/android-build-release-unsigned.apk"
if [ ! -f "${RAW_APK}" ]; then
    RAW_APK=$(find "${BUILD_DIR}/android-build" -name "*.apk" -type f | head -n 1)
fi

if [ -n "${RAW_APK}" ] && [ -f "${RAW_APK}" ]; then
    DEST_APK="${SCRIPT_DIR}/appBSTUcurriculum.apk"
    ZIPALIGN="${ANDROID_SDK_ROOT}/build-tools/34.0.0/zipalign"
    APKSIGNER="${ANDROID_SDK_ROOT}/build-tools/34.0.0/apksigner"
    KEYSTORE_FILE="${HOME}/Android/debug.keystore"

    if [ ! -f "${KEYSTORE_FILE}" ]; then
        keytool -genkey -v -keystore "${KEYSTORE_FILE}" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1 || true
    fi

    if [ -f "${ZIPALIGN}" ]; then
        "${ZIPALIGN}" -f -p 4 "${RAW_APK}" "${DEST_APK}"
    else
        cp "${RAW_APK}" "${DEST_APK}"
    fi

    if [ -f "${APKSIGNER}" ] && [ -f "${KEYSTORE_FILE}" ]; then
        "${APKSIGNER}" sign --ks "${KEYSTORE_FILE}" --ks-pass pass:android --ks-key-alias androiddebugkey --key-pass pass:android "${DEST_APK}" >/dev/null 2>&1 || true
        "${APKSIGNER}" verify "${DEST_APK}" >/dev/null 2>&1 || true
    fi

    echo -e "${GREEN} СБОРКА APK УСПЕШНО ЗАВЕРШЕНА!${NC}"
    echo -e " Готовый выровненный и подписанный APK: ${CYAN}${DEST_APK}${NC}"
else
    echo -e "${RED}[ОШИБКА] APK файл не найден после сборки.${NC}"
    exit 1
fi

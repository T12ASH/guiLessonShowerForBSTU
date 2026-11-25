cmake_minimum_required(VERSION 3.16)

project(BSTUcurriculum VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2 Network Svg)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appBSTUcurriculum
    src/main.cpp
    src/schedulemanager.h
    src/schedulemanager.cpp
)

target_include_directories(appBSTUcurriculum PRIVATE src)

qt_add_qml_module(appBSTUcurriculum
    URI BSTUcurriculum
    VERSION 1.0
    QML_FILES
        Main.qml
        Translations.js
        components/GroupPickerPopup.qml
        components/PeriodPickerPopup.qml
        components/SettingsDialog.qml
        components/LessonCard.qml
        components/DaySelectorBar.qml
        views/SetupScreen.qml
        views/ScheduleView.qml
    RESOURCES
        icons/app.svg
        icons/settings.svg
        icons/close.svg
        icons/check.svg
        icons/arrow_down.svg
        icons/chevron_left.svg
        icons/chevron_right.svg
        icons/play_circle.svg
        icons/hourglass.svg
        icons/dash.svg
        icons/telegram.svg
        icons/github.svg
        icons/codeberg.svg
        icons/switchLang.svg
    SOURCES
        src/schedulemanager.h
        src/schedulemanager.cpp
        updater/updater.hpp
        updater/updater.cpp
        updater/update_info.json
)

target_link_libraries(appBSTUcurriculum
    PRIVATE
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::Network
        Qt6::Svg
)

if (ANDROID)
    include(FetchContent)
    FetchContent_Declare(
        android_openssl
        DOWNLOAD_EXTRACT_TIMESTAMP true
        URL https://github.com/KDAB/android_openssl/archive/refs/heads/master.zip
    )
    FetchContent_MakeAvailable(android_openssl)
    include(${android_openssl_SOURCE_DIR}/android_openssl.cmake)

    set_target_properties(appBSTUcurriculum PROPERTIES
        QT_ANDROID_PACKAGE_NAME "org.bstu.schedule"
        QT_ANDROID_APP_NAME "Расписание БГТУ"
        QT_ANDROID_TARGET_SDK_VERSION 34
        QT_ANDROID_MIN_SDK_VERSION 26
        QT_ANDROID_PERMISSIONS "android.permission.INTERNET"
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
    )

    add_android_openssl_libraries(appBSTUcurriculum)
endif()

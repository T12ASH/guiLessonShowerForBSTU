/*
 * BSTUcurriculum — Cross-platform schedule app for BSTU
 * Copyright (C) 2026 overlord_zpyxkhtnvorplimbex <https://codeberg.org/overlord_zpyxkhtnvorplimbex>
 * Copyright (C) 2026 T12ASH                      <https://github.com/T12ASH>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include "schedulemanager.h"

int main(int argc, char *argv[])
{
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
        Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);

    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("BSTUcurriculum", "Main");

    return QGuiApplication::exec();
}
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


#include "schedulemanager.h"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QDebug>
#include <QStandardPaths>
#include <QDateTime>
#include <QIcon>
#include <QUrl>
#include <QRegularExpression>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QTimer>
#include <algorithm>

static QString stripHtml(QString text)
{
    static QRegularExpression tagRegex("<[^>]*>");
    text.replace(tagRegex, "");
    text.replace("&nbsp;", " ");
    text.replace("&amp;", "&");
    text.replace("&quot;", "\"");
    text.replace("&lt;", "<");
    text.replace("&gt;", ">");
    return text.trimmed();
}

QString ScheduleManager::calculateCurrentWeekParity() const
{
    QDate today = QDate::currentDate();
    int year = today.year();
    QDate semStart;
    if (today.month() >= 9) {
        semStart = QDate(year, 9, 1);
    } else if (today.month() == 1) {
        semStart = QDate(year - 1, 9, 1);
    } else {
        semStart = QDate(year, 2, 8);
    }
    int dayOfWeek = semStart.dayOfWeek();
    QDate firstMonday = semStart.addDays(-(dayOfWeek - 1));
    int diffDays = firstMonday.daysTo(today);
    int weekNum = (diffDays / 7) + 1;
    bool isOdd = (weekNum % 2 != 0);
    return isOdd ? "не чет" : "чет";
}

QString ScheduleManager::detectFormForGroup(const QString &groupName) const
{
    QString clean = groupName.trimmed();
    if (m_groupToForm.contains(clean) && !m_groupToForm.value(clean).isEmpty()) {
        return m_groupToForm.value(clean);
    }

    QString upper = clean.toUpper();
    if (upper.startsWith("ОЗ-") || upper.startsWith("О3-") ||
        upper.startsWith("OЗ-") || upper.startsWith("O3-")) {
        return "очно-заочная";
    }
    if (upper.startsWith("З-") || upper.startsWith("3-")) {
        return "заочная";
    }
    return "очная";
}

QString ScheduleManager::defaultAcademicPeriod()
{
    QDate today = QDate::currentDate();
    int curYear = (today.month() >= 8) ? today.year() : today.year() - 1;
    int nextYear = curYear + 1;
    int sem = (today.month() >= 8 || today.month() == 1) ? 1 : 2;
    return QString("%1-%2_%3_1").arg(curYear).arg(nextYear).arg(sem);
}

ScheduleManager::ScheduleManager(QObject *parent)
    : QObject(parent)
    , m_group("")
    , m_period(defaultAcademicPeriod())
    , m_weekParity(calculateCurrentWeekParity())
    , m_language("ru")
    , m_isRefreshing(false)
    , m_isSilentRefresh(false)
    , m_isLoadingMeta(false)
    , m_hasMetaError(false)
    , m_statusMessage("")
    , m_consoleOutput("")
    , m_customIconPath("")
    , m_customIconUrl("")
    , m_currentReply(nullptr)
    , m_metaReply(nullptr)
{
    m_netManager = new QNetworkAccessManager(this);
    findBaseDirectory();
    checkCustomIcon();
    loadCachedMeta();
    loadInfo();
    loadScheduleFromFile();

    if (!m_group.isEmpty() && !m_period.isEmpty()) {
        QTimer::singleShot(500, this, [this]() {
            refreshSchedule(true);
        });
    }
}

ScheduleManager::~ScheduleManager()
{
    if (m_currentReply) {
        m_currentReply->abort();
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
    }
    if (m_metaReply) {
        m_metaReply->abort();
        m_metaReply->deleteLater();
        m_metaReply = nullptr;
    }
    abortGroupReplies();
}

void ScheduleManager::abortGroupReplies()
{
    for (QNetworkReply *reply : m_groupReplies) {
        if (reply) {
            reply->disconnect(this);
            reply->abort();
            reply->deleteLater();
        }
    }
    m_groupReplies.clear();
}

void ScheduleManager::findBaseDirectory()
{
#if defined(Q_OS_ANDROID)
    m_baseDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(m_baseDir);
#else
    const QStringList candidateDirs = {
        QCoreApplication::applicationDirPath(),
        QDir::currentPath(),
        QDir(QCoreApplication::applicationDirPath()).filePath(".."),
        QDir(QCoreApplication::applicationDirPath()).filePath("../.."),
#ifdef PROJECT_SOURCE_DIR
        QString(PROJECT_SOURCE_DIR)
#endif
    };

    for (const QString &dirPath : candidateDirs) {
        if (dirPath.isEmpty()) continue;
        QDir dir(dirPath);
        if (dir.exists("icons") || dir.exists("Schedule.txt")) {
            m_baseDir = dir.canonicalPath();
            return;
        }
    }
    m_baseDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(m_baseDir);
#endif
}

void ScheduleManager::checkCustomIcon()
{
    QString iconsDirPath = QDir(m_baseDir).filePath("icons");
    QDir iconsDir(iconsDirPath);
    if (!iconsDir.exists()) {
        iconsDir.mkpath(".");
    }

    const QStringList nameFilters = {"icon.svg", "icon.png", "app.svg", "app.png", "*.svg", "*.png"};
    QFileInfoList files = iconsDir.entryInfoList(nameFilters, QDir::Files, QDir::Name);

    if (!files.isEmpty()) {
        m_customIconPath = files.first().absoluteFilePath();
        m_customIconUrl = QUrl::fromLocalFile(m_customIconPath).toString();
        QGuiApplication::setWindowIcon(QIcon(m_customIconPath));
    } else {
        m_customIconPath.clear();
        m_customIconUrl.clear();
    }
    emit customIconUrlChanged();
}

void ScheduleManager::loadCachedMeta()
{
    m_periodOptions.clear();
    QString periodsPath = QDir(m_baseDir).filePath("periods.txt");
    QFile pFile(periodsPath);
    if (pFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&pFile);
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            if (line.isEmpty()) continue;
            QStringList parts = line.split('|');
            PeriodOption opt;
            opt.value = parts[0].trimmed();
            opt.label = (parts.size() > 1 && !parts[1].trimmed().isEmpty()) ? parts[1].trimmed() : opt.value;
            if (!opt.value.isEmpty()) {
                m_periodOptions.append(opt);
            }
        }
        pFile.close();
    }

    if (m_periodOptions.isEmpty()) {
        QDate today = QDate::currentDate();
        int curYear = (today.month() >= 8) ? today.year() : today.year() - 1;
        for (int y = curYear; y >= curYear - 3; --y) {
            int nextY = y + 1;
            QString yStr = QString("%1-%2").arg(y).arg(nextY);
            m_periodOptions.append({QString("%1_2_2").arg(yStr), QString("%1: 2 семестр - сессия").arg(yStr)});
            m_periodOptions.append({QString("%1_2_1").arg(yStr), QString("%1: 2 семестр").arg(yStr)});
            m_periodOptions.append({QString("%1_1_2").arg(yStr), QString("%1: 1 семестр - сессия").arg(yStr)});
            m_periodOptions.append({QString("%1_1_1").arg(yStr), QString("%1: 1 семестр").arg(yStr)});
        }
    }
    rebuildPeriodsVariantList();

    m_availableGroups.clear();
    m_groupToForm.clear();
    QString groupsPath = QDir(m_baseDir).filePath("groups.txt");
    QFile gFile(groupsPath);
    if (gFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&gFile);
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            if (line.isEmpty()) continue;
            QStringList parts = line.split('|');
            QString g = parts[0].trimmed();
            QString form = (parts.size() > 1) ? parts[1].trimmed() : "";
            if (!g.isEmpty()) {
                if (!m_availableGroups.contains(g)) {
                    m_availableGroups.append(g);
                }
                if (!form.isEmpty()) {
                    m_groupToForm[g] = form;
                }
            }
        }
        gFile.close();
    }

    emit availableGroupsChanged();
}

void ScheduleManager::saveCachedPeriods()
{
    QString periodsPath = QDir(m_baseDir).filePath("periods.txt");
    QFile pFile(periodsPath);
    if (pFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&pFile);
        for (const PeriodOption &opt : m_periodOptions) {
            out << opt.value << "|" << opt.label << "\n";
        }
        pFile.close();
    }
}

void ScheduleManager::saveCachedGroups()
{
    QString groupsPath = QDir(m_baseDir).filePath("groups.txt");
    QFile gFile(groupsPath);
    if (gFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&gFile);
        for (const QString &g : m_availableGroups) {
            out << g << "|" << detectFormForGroup(g) << "\n";
        }
        gFile.close();
    }
}

void ScheduleManager::rebuildPeriodsVariantList()
{
    m_availablePeriods.clear();
    for (const PeriodOption &opt : m_periodOptions) {
        QVariantMap map;
        map["value"] = opt.value;
        map["label"] = opt.label;
        m_availablePeriods.append(map);
    }
    emit availablePeriodsChanged();
}

QString ScheduleManager::periodLabel(const QString &periodValue) const
{
    QString clean = periodValue.trimmed();
    for (const PeriodOption &opt : m_periodOptions) {
        if (opt.value == clean) {
            return opt.label;
        }
    }
    return clean;
}

void ScheduleManager::loadInfo()
{
    m_weekParity = calculateCurrentWeekParity();

    QString infoPath = QDir(m_baseDir).filePath("myInfo.txt");
    QFile file(infoPath);
    if (!file.exists() || !file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit periodChanged();
        emit weekParityChanged();
        emit languageChanged();
        return;
    }

    QTextStream in(&file);
    if (!in.atEnd()) m_group = in.readLine().trimmed();
    if (!in.atEnd()) {
        QString per = in.readLine().trimmed();
        if (!per.isEmpty()) m_period = per;
    }
    if (!in.atEnd()) {
        (void)in.readLine();
    }
    if (!in.atEnd()) {
        QString lang = in.readLine().trimmed().toLower();
        if (!lang.isEmpty()) m_language = lang;
    }
    if (m_language.isEmpty()) {
        m_language = "ru";
    }
    file.close();

    if (!m_group.isEmpty() && !m_availableGroups.contains(m_group)) {
        m_availableGroups.prepend(m_group);
        emit availableGroupsChanged();
    }

    emit groupChanged();
    emit periodChanged();
    emit weekParityChanged();
    emit languageChanged();
}

void ScheduleManager::saveInfo()
{
    QString infoPath = QDir(m_baseDir).filePath("myInfo.txt");
    QFile file(infoPath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        out << m_group << "\n";
        out << m_period << "\n";
        out << calculateCurrentWeekParity() << "\n";
        out << m_language << "\n";
        file.close();
    }
}

void ScheduleManager::setLanguage(const QString &lang)
{
    QString clean = lang.trimmed().toLower();
    if (m_language != clean && !clean.isEmpty()) {
        m_language = clean;
        emit languageChanged();
        saveInfo();
    }
}

void ScheduleManager::setGroup(const QString &group)
{
    QString clean = group.trimmed();
    if (m_group != clean) {
        m_group = clean;
        if (!clean.isEmpty() && !m_availableGroups.contains(clean)) {
            m_availableGroups.prepend(clean);
            emit availableGroupsChanged();
        }
        emit groupChanged();
        saveInfo();
    }
}

void ScheduleManager::setPeriod(const QString &period)
{
    QString clean = period.trimmed();
    if (m_period != clean && !clean.isEmpty()) {
        m_period = clean;
        emit periodChanged();
        saveInfo();
    }
}

void ScheduleManager::setWeekParity(const QString &parity)
{
    QString clean = parity.trimmed().toLower();
    if (clean.contains("нечет") || clean.contains("нечёт") || clean == "не чет") {
        clean = "не чет";
    } else {
        clean = "чет";
    }

    if (m_weekParity != clean) {
        m_weekParity = clean;
        emit weekParityChanged();
        filterLessons();
    }
}

bool ScheduleManager::matchesParity(const QString &lessonWeekType, const QString &currentParity) const
{
    QString lwt = lessonWeekType.trimmed().toLower();
    QString cur = currentParity.trimmed().toLower();

    if (lwt == "all" || lwt.isEmpty()) {
        return true;
    }

    bool isCurrentOdd = (cur.contains("нечет") || cur.contains("нечёт") || cur == "не чет");
    bool isLessonOdd = (lwt.contains("нечет") || lwt.contains("нечёт"));
    bool isLessonEven = ((lwt.contains("чет") || lwt.contains("чёт")) && !isLessonOdd);

    if (isCurrentOdd) {
        return isLessonOdd;
    } else {
        return isLessonEven;
    }
}

void ScheduleManager::onSettingsOpened()
{
    m_hasMetaError = false;
    emit hasMetaErrorChanged();

    if (!m_metaReply) {
        m_isLoadingMeta = true;
        emit isLoadingMetaChanged();

        QUrl pageUrl("https://www.tu-bryansk.ru/education/schedule/");
        QNetworkRequest req(pageUrl);
        req.setRawHeader("User-Agent", "Mozilla/5.0 (BSTUcurriculum Android)");
        m_metaReply = m_netManager->get(req);
        connect(m_metaReply, &QNetworkReply::finished, this, &ScheduleManager::onMetaPageFinished);
    }

    fetchGroupsForPeriod(m_period.isEmpty() ? defaultAcademicPeriod() : m_period);
}

void ScheduleManager::onMetaPageFinished()
{
    if (!m_metaReply) return;

    if (m_metaReply->error() != QNetworkReply::NoError) {
        m_metaReply->deleteLater();
        m_metaReply = nullptr;
        if (m_groupReplies.isEmpty()) {
            m_isLoadingMeta = false;
            emit isLoadingMetaChanged();
            if (m_availableGroups.isEmpty()) {
                m_hasMetaError = true;
                emit hasMetaErrorChanged();
            }
        }
        return;
    }

    QString html = QString::fromUtf8(m_metaReply->readAll());
    m_metaReply->deleteLater();
    m_metaReply = nullptr;

    if (!html.isEmpty()) {
        static QRegularExpression periodSelectRegex(
            "<select[^>]*\\bid=[\"']period[\"'][^>]*>(.*?)</select>",
            QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
        static QRegularExpression optionRegex(
            "<option[^>]*\\bvalue=[\"']([^\"']*)[\"'][^>]*>(.*?)</option>",
            QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);

        auto selMatch = periodSelectRegex.match(html);
        if (selMatch.hasMatch()) {
            QString optionsHtml = selMatch.captured(1);
            QList<PeriodOption> parsedPeriods;
            auto optIt = optionRegex.globalMatch(optionsHtml);

            QDate today = QDate::currentDate();
            int curYear = (today.month() >= 8) ? today.year() : today.year() - 1;
            int minAllowedYear = curYear - 3;
            static QRegularExpression pYearRegex("^(\\d{4})-");

            while (optIt.hasNext()) {
                auto om = optIt.next();
                QString val = om.captured(1).trimmed();
                QString lbl = stripHtml(om.captured(2));
                if (!val.isEmpty()) {
                    auto ym = pYearRegex.match(val);
                    if (ym.hasMatch()) {
                        int py = ym.captured(1).toInt();
                        if (py < minAllowedYear) {
                            continue; // древние архивные периоды (2016-2022)
                        }
                    }
                    parsedPeriods.append({val, lbl.isEmpty() ? val : lbl});
                }
            }
            if (!parsedPeriods.isEmpty()) {
                m_periodOptions = parsedPeriods;
                saveCachedPeriods();
                rebuildPeriodsVariantList();
            }
        }

        static QRegularExpression groupSelectRegex(
            "<select[^>]*\\bid=[\"']group[\"'][^>]*>(.*?)</select>",
            QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
        static QRegularExpression modernGroupRegex("^[ОOЗ3]{1,2}[-–](\\d{2})[-–]");

        auto grpSelMatch = groupSelectRegex.match(html);
        if (grpSelMatch.hasMatch()) {
            QString grpOptionsHtml = grpSelMatch.captured(1);
            bool addedAny = false;
            auto optIt = optionRegex.globalMatch(grpOptionsHtml);
            while (optIt.hasNext()) {
                auto om = optIt.next();
                QString val = om.captured(1).trimmed();
                if (!val.isEmpty() && modernGroupRegex.match(val).hasMatch() && !m_availableGroups.contains(val)) {
                    m_availableGroups.append(val);
                    m_groupToForm[val] = detectFormForGroup(val);
                    addedAny = true;
                }
            }
            if (addedAny) {
                saveCachedGroups();
                emit availableGroupsChanged();
            }
        }
    }

    if (m_groupReplies.isEmpty()) {
        m_isLoadingMeta = false;
        emit isLoadingMetaChanged();
    }
}

void ScheduleManager::fetchGroupsForPeriod(const QString &periodCode)
{
    QString per = periodCode.trimmed();
    if (per.isEmpty()) per = m_period;
    if (per.isEmpty()) per = defaultAcademicPeriod();

    abortGroupReplies();
    m_pendingFetchedGroups.clear();

    m_isLoadingMeta = true;
    emit isLoadingMetaChanged();

    const QStringList studyForms = {"очная", "очно-заочная", "заочная"};

    for (const QString &formStr : studyForms) {
        QUrl url("https://www.tu-bryansk.ru/education/schedule/schedule.ajax.php");
        QNetworkRequest request(url);
        request.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded; charset=UTF-8");
        request.setRawHeader("User-Agent", "Mozilla/5.0 (BSTUcurriculum Android)");

        QByteArray postData;
        postData.append("namedata=group");
        postData.append("&period=");
        postData.append(per.toUtf8());
        postData.append("&form=");
        postData.append(QUrl::toPercentEncoding(formStr));

        QNetworkReply *reply = m_netManager->post(request, postData);
        reply->setProperty("studyForm", formStr);
        m_groupReplies.append(reply);

        connect(reply, &QNetworkReply::finished, this, [this, reply]() {
            m_groupReplies.removeAll(reply);

            if (reply->error() == QNetworkReply::NoError) {
                QString formName = reply->property("studyForm").toString();
                QString html = QString::fromUtf8(reply->readAll());

                static QRegularExpression optionRegex(
                    "<option[^>]*\\bvalue=[\"']([^\"']*)[\"'][^>]*>(.*?)</option>",
                    QRegularExpression::DotMatchesEverythingOption | QRegularExpression::CaseInsensitiveOption);
                static QRegularExpression modernGroupRegex("^[ОOЗ3]{1,2}[-–](\\d{2})[-–]");

                QDate today = QDate::currentDate();
                int curYear = (today.month() >= 8) ? today.year() : today.year() - 1;
                int curYy = curYear % 100;
                int minYy = (curYear - 5) % 100;

                auto optIt = optionRegex.globalMatch(html);
                while (optIt.hasNext()) {
                    auto om = optIt.next();
                    QString val = om.captured(1).trimmed();
                    if (val.isEmpty()) {
                        val = stripHtml(om.captured(2));
                    }
                    if (!val.isEmpty() && !val.contains("Выберите", Qt::CaseInsensitive)) {
                        auto gm = modernGroupRegex.match(val);
                        if (!gm.hasMatch()) {
                            continue;
                        }
                        int yy = gm.captured(1).toInt();
                        if (yy < minYy && yy > curYy + 1) {
                            continue;
                        }

                        if (!m_pendingFetchedGroups.contains(val)) {
                            m_pendingFetchedGroups.append(val);
                        }
                        m_groupToForm[val] = formName;
                    }
                }
            }

            reply->deleteLater();

            if (m_groupReplies.isEmpty()) {
                if (!m_pendingFetchedGroups.isEmpty()) {
                    if (!m_group.isEmpty() && !m_pendingFetchedGroups.contains(m_group)) {
                        m_pendingFetchedGroups.prepend(m_group);
                    }
                    m_availableGroups = m_pendingFetchedGroups;
                    m_hasMetaError = false;
                    emit hasMetaErrorChanged();
                    saveCachedGroups();
                    emit availableGroupsChanged();
                } else if (m_availableGroups.isEmpty()) {
                    m_hasMetaError = true;
                    emit hasMetaErrorChanged();
                }
                if (!m_metaReply) {
                    m_isLoadingMeta = false;
                    emit isLoadingMetaChanged();
                }
            }
        });
    }
}

void ScheduleManager::loadScheduleFromFile()
{
    QString schedulePath = QDir(m_baseDir).filePath("Schedule.txt");
    QFileInfo fi(schedulePath);
    QFile file(schedulePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        m_allLessons.clear();
        filterLessons();
        m_statusMessage = "Не обновлялось";
        emit statusMessageChanged();
        return;
    }

    m_allLessons.clear();
    QTextStream in(&file);
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.isEmpty()) continue;

        QStringList parts = line.split('|');
        if (parts.size() >= 7) {
            LessonInfo lesson;
            lesson.time = parts[0].trimmed();
            lesson.name = parts[1].trimmed();
            lesson.type = parts[2].trimmed();
            lesson.day = parts[3].trimmed();
            lesson.teacher = parts[4].trimmed();
            lesson.weekType = parts[5].trimmed();
            lesson.classRoom = parts[6].trimmed();
            m_allLessons.append(lesson);
        }
    }
    file.close();

    if (m_allLessons.isEmpty()) {
        m_statusMessage = "Не обновлялось";
    } else {
        m_statusMessage = QString("Обновлено: %1").arg(fi.lastModified().toString("dd.MM.yyyy, HH:mm"));
    }
    emit statusMessageChanged();
    filterLessons();
}

void ScheduleManager::saveScheduleToFile(const QString &content)
{
    QString schedulePath = QDir(m_baseDir).filePath("Schedule.txt");
    QFile file(schedulePath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        out << content;
        file.close();
    }
}

void ScheduleManager::filterLessons()
{
    const QStringList daysOrder = {
        "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"
    };

    QMap<QString, QVariantList> groupedLessons;
    for (const LessonInfo &l : m_allLessons) {
        if (!matchesParity(l.weekType, m_weekParity)) {
            continue;
        }

        QVariantMap item;
        item["time"] = l.time;
        item["name"] = l.name;
        item["type"] = l.type;
        item["day"] = l.day;
        item["teacher"] = l.teacher;
        item["weekType"] = l.weekType;
        item["classRoom"] = l.classRoom;

        groupedLessons[l.day].append(item);
    }

    m_scheduleDays.clear();
    for (const QString &dayName : daysOrder) {
        QVariantMap dayMap;
        dayMap["dayName"] = dayName;
        dayMap["lessons"] = groupedLessons.value(dayName, QVariantList());
        m_scheduleDays.append(dayMap);
    }

    emit scheduleChanged();
}

void ScheduleManager::refreshSchedule(bool silent)
{
    if (m_isRefreshing) {
        if (silent) return;
        if (m_currentReply) {
            m_currentReply->disconnect(this);
            m_currentReply->abort();
            m_currentReply->deleteLater();
            m_currentReply = nullptr;
        }
        m_isRefreshing = false;
    }

    if (m_group.isEmpty() || m_period.isEmpty()) {
        if (!silent) {
            m_statusMessage = "Сначала выберите группу и период!";
            emit statusMessageChanged();
        }
        return;
    }

    saveInfo();

    m_isRefreshing = true;
    m_isSilentRefresh = silent;
    emit isRefreshingChanged();

    if (!silent) {
        m_statusMessage = "Загрузка расписания...";
        emit statusMessageChanged();
    }

    QString formStr = detectFormForGroup(m_group);
    m_consoleOutput = QString("Отправка запроса к сайту БГТУ (%1, %2)...\n").arg(m_group, formStr);
    emit consoleOutputChanged();

    QUrl url("https://www.tu-bryansk.ru/education/schedule/schedule.ajax.php");
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded; charset=UTF-8");
    request.setRawHeader("User-Agent", "Mozilla/5.0 (BSTUcurriculum Android)");

    QByteArray postData;
    postData.append("namedata=schedule");
    postData.append("&group=");
    postData.append(QUrl::toPercentEncoding(m_group));
    postData.append("&period=");
    postData.append(m_period.toUtf8());
    postData.append("&form=");
    postData.append(QUrl::toPercentEncoding(formStr));

    m_currentReply = m_netManager->post(request, postData);
    connect(m_currentReply, &QNetworkReply::finished, this, &ScheduleManager::onReplyFinished);
}

void ScheduleManager::onReplyFinished()
{
    if (!m_currentReply) return;

    if (m_currentReply->error() != QNetworkReply::NoError) {
        if (!m_isSilentRefresh && m_allLessons.isEmpty()) {
            m_statusMessage = "Нет сети (офлайн-режим)";
            emit statusMessageChanged();
        }
        m_consoleOutput.append(QString("Ошибка сети (работаем офлайн): %1\n").arg(m_currentReply->errorString()));
        m_isRefreshing = false;
        m_isSilentRefresh = false;
        emit isRefreshingChanged();
        emit consoleOutputChanged();
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
        return;
    }

    QByteArray responseData = m_currentReply->readAll();
    QString html = QString::fromUtf8(responseData);
    m_currentReply->deleteLater();
    m_currentReply = nullptr;

    parseHtmlAndPopulate(html);
}

void ScheduleManager::parseHtmlAndPopulate(const QString &html)
{
    if (html.isEmpty()) {
        if (!m_isSilentRefresh && m_allLessons.isEmpty()) {
            m_statusMessage = "Получен пустой ответ от сервера";
            emit statusMessageChanged();
        }
        m_isRefreshing = false;
        m_isSilentRefresh = false;
        emit isRefreshingChanged();
        return;
    }

    static QRegularExpression trRegex("<tr[^>]*>(.*?)</tr>", QRegularExpression::DotMatchesEverythingOption);
    static QRegularExpression dayRegex("<td\\b(?=[^>]*class=[\"'][^\"']*daeweek)[^>]*>(.*?)</td>", QRegularExpression::DotMatchesEverythingOption);
    static QRegularExpression timeRegex("<td\\b(?=[^>]*class=[\"'][^\"']*schtime)([^>]*)>(.*?)</td>", QRegularExpression::DotMatchesEverythingOption);
    static QRegularExpression nameRegex("<td\\b(?=[^>]*class=[\"'][^\"']*schname)[^>]*>(.*?)</td>", QRegularExpression::DotMatchesEverythingOption);
    static QRegularExpression typeRegex("<(?:span|div)[^>]*class=[\"'][^\"']*schtype[^\"']*[\"'][^>]*>(.*?)</(?:span|div)>", QRegularExpression::DotMatchesEverythingOption);
    static QRegularExpression teacherRegex("<td\\b(?=[^>]*class=[\"'][^\"']*schteacher)[^>]*>(.*?)</td>", QRegularExpression::DotMatchesEverythingOption);
    static QRegularExpression classRegex("<td\\b(?=[^>]*class=[\"'][^\"']*schclass)[^>]*>(.*?)</td>", QRegularExpression::DotMatchesEverythingOption);

    QString currentDay;
    QString currentTime;
    QString timeForTwoRowspan;
    bool isTwoRowspanActive = false;

    QString fileContent;
    QList<LessonInfo> parsedLessons;

    auto trMatch = trRegex.globalMatch(html);
    while (trMatch.hasNext()) {
        auto m = trMatch.next();
        QString rowHtml = m.captured(1);

        auto dayM = dayRegex.match(rowHtml);
        if (dayM.hasMatch()) {
            currentDay = stripHtml(dayM.captured(1));
        }

        bool hasRowspan2 = false;
        auto timeM = timeRegex.match(rowHtml);
        if (timeM.hasMatch()) {
            QString attrs = timeM.captured(1);
            if (attrs.contains("rowspan", Qt::CaseInsensitive) && attrs.contains("2")) {
                hasRowspan2 = true;
            }
            currentTime = stripHtml(timeM.captured(2));
        }

        auto nameM = nameRegex.match(rowHtml);
        if (!nameM.hasMatch()) {
            continue;
        }

        QString rawNameCell = nameM.captured(1);
        QString typeOfLesson;
        auto typeM = typeRegex.match(rawNameCell);
        if (typeM.hasMatch()) {
            typeOfLesson = stripHtml(typeM.captured(1));
            rawNameCell.remove(typeM.captured(0));
        }
        QString nameOfLesson = stripHtml(rawNameCell);

        QString nameTeacher;
        auto teacherM = teacherRegex.match(rowHtml);
        if (teacherM.hasMatch()) {
            nameTeacher = stripHtml(teacherM.captured(1));
        }

        QString classRoom;
        auto classM = classRegex.match(rowHtml);
        if (classM.hasMatch()) {
            classRoom = stripHtml(classM.captured(1));
        }

        QString typeOfWeek = "all";
        QString lessonTime = currentTime;

        if (hasRowspan2) {
            typeOfWeek = "нечёт";
            isTwoRowspanActive = true;
            timeForTwoRowspan = currentTime;
        } else if (isTwoRowspanActive) {
            typeOfWeek = "чет";
            lessonTime = timeForTwoRowspan;
            isTwoRowspanActive = false;
        } else {
            typeOfWeek = "all";
        }

        if (nameOfLesson.isEmpty()) {
            continue;
        }

        LessonInfo info;
        info.time = lessonTime;
        info.name = nameOfLesson;
        info.type = typeOfLesson;
        info.day = currentDay;
        info.teacher = nameTeacher;
        info.weekType = typeOfWeek;
        info.classRoom = classRoom;
        parsedLessons.append(info);

        fileContent += QString("%1|%2|%3|%4|%5|%6|%7\n")
                           .arg(lessonTime, nameOfLesson, typeOfLesson, currentDay, nameTeacher, typeOfWeek, classRoom);
    }

    if (!parsedLessons.isEmpty()) {
        saveScheduleToFile(fileContent);
        m_allLessons = parsedLessons;
        m_statusMessage = QString("Обновлено: %1").arg(QDateTime::currentDateTime().toString("dd.MM.yyyy, HH:mm"));
        m_consoleOutput.append(QString("Успешно загружено %1 пар.\n").arg(parsedLessons.size()));
        filterLessons();
    } else {
        m_allLessons.clear();
        saveScheduleToFile("");
        filterLessons();
        m_statusMessage = "В расписании нет пар (семестр не заполнен)";
        m_consoleOutput.append("Ответ получен, но занятий в таблице не обнаружено.\n");
    }

    m_isRefreshing = false;
    m_isSilentRefresh = false;
    emit isRefreshingChanged();
    emit statusMessageChanged();
    emit consoleOutputChanged();
}
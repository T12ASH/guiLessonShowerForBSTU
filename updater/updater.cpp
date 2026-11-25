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

#include "updater.hpp"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDebug>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPromise>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QThreadPool>
#include <QTimer>
#include <QtMath>

#if defined(Q_OS_ANDROID)
#include <QJniEnvironment>
#include <QJniObject>
#include <QtCore/qnativeinterface.h>
#endif

namespace {

constexpr auto SETTINGS_ORG = "BSTUcurriculum";
constexpr auto SETTINGS_APP = "guiLessonShowerForBSTU";
constexpr auto SETTINGS_FAIL_KEY = "updater/failureCount";
constexpr auto MANIFEST_FILENAME = "update_info.json";
constexpr auto DOWNLOAD_TMP_FILENAME = "update_download.tmp";
constexpr auto MANIFEST_TMP_FILENAME = "update_info.json.tmp";

struct VersionInfo {
    int major = 0;
    int minor = 0;
    int patch = 0;
    bool isTest = false;
    int testNumber = 0;
    bool isValid = false;

    static VersionInfo parse(const QString& raw)
    {
        VersionInfo info;
        static const QRegularExpression re(
            QStringLiteral("^v?(\\d+)\\.(\\d+)(?:\\.(\\d+))?(?:-(test)(?:[._-]?(\\d+))?)?$"),
            QRegularExpression::CaseInsensitiveOption);

        const QRegularExpressionMatch match = re.match(raw.trimmed());
        if (!match.hasMatch()) {
            return info;
        }

        bool okMaj = false;
        bool okMin = false;
        info.major = match.captured(1).toInt(&okMaj);
        info.minor = match.captured(2).toInt(&okMin);
        if (!okMaj || !okMin) {
            return info;
        }

        if (!match.captured(3).isEmpty()) {
            bool okPatch = false;
            info.patch = match.captured(3).toInt(&okPatch);
            if (!okPatch) {
                return info;
            }
        } else {
            info.patch = 0;
        }

        if (!match.captured(4).isEmpty()) {
            info.isTest = true;
            const QString numStr = match.captured(5);
            if (!numStr.isEmpty()) {
                bool okTest = false;
                info.testNumber = numStr.toInt(&okTest);
                if (!okTest) {
                    return info;
                }
            }
        }

        info.isValid = true;
        return info;
    }

    bool operator>(const VersionInfo& other) const
    {
        if (major != other.major) return major > other.major;
        if (minor != other.minor) return minor > other.minor;
        if (patch != other.patch) return patch > other.patch;
        if (isTest != other.isTest) return !isTest; // release > test
        if (isTest) return testNumber > other.testNumber;
        return false;
    }
};

QString currentPlatformKey()
{
#if defined(Q_OS_ANDROID)
    return QStringLiteral("android");
#elif defined(Q_OS_LINUX)
    return QStringLiteral("linux");
#elif defined(Q_OS_WIN)
    return QStringLiteral("windows");
#elif defined(Q_OS_MACOS)
    return QStringLiteral("macos");
#elif defined(Q_OS_IOS)
    return QStringLiteral("ios");
#else
    return QStringLiteral("unknown");
#endif
}

bool isNetworkUnavailableError(QNetworkReply::NetworkError error)
{
    switch (error) {
    case QNetworkReply::ConnectionRefusedError:
    case QNetworkReply::RemoteHostClosedError:
    case QNetworkReply::HostNotFoundError:
    case QNetworkReply::TimeoutError:
    case QNetworkReply::OperationCanceledError:
    case QNetworkReply::NetworkSessionFailedError:
    case QNetworkReply::TemporaryNetworkFailureError:
    case QNetworkReply::UnknownNetworkError:
        return true;
    default:
        return false;
    }
}

bool isPermanentHttpError(int httpStatusCode)
{
    return httpStatusCode == 400
           || httpStatusCode == 401
           || httpStatusCode == 403
           || httpStatusCode == 404
           || httpStatusCode == 410;
}

bool isValidSha256(const QString& sha)
{
    static const QRegularExpression hexRe(QStringLiteral("^[0-9a-fA-F]{64}$"));
    return hexRe.match(sha.trimmed()).hasMatch();
}

bool isSafeFileType(const QString& filetype)
{
    static const QRegularExpression extRe(QStringLiteral("^\\.[a-zA-Z0-9]{1,16}$"));
    return extRe.match(filetype).hasMatch();
}

bool computeAndCompareSha256(const QString& filePath,
                             const QString& expectedSha256,
                             const std::shared_ptr<std::atomic_bool>& cancelFlag)
{
    if (!isValidSha256(expectedSha256)) {
        return false;
    }

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "[Updater] Cannot open file for SHA-256 verification:" << filePath;
        return false;
    }

    QCryptographicHash hash(QCryptographicHash::Sha256);
    QByteArray buffer(64 * 1024, Qt::Uninitialized);

    while (!file.atEnd()) {
        if (cancelFlag && cancelFlag->load(std::memory_order_relaxed)) {
            return false;
        }
        const qint64 bytesRead = file.read(buffer.data(), buffer.size());
        if (bytesRead < 0) {
            qWarning() << "[Updater] Read error during SHA-256 verification:" << file.errorString();
            return false;
        }
        if (bytesRead > 0) {
            hash.addData(QByteArray::fromRawData(buffer.constData(), static_cast<qsizetype>(bytesRead)));
        }
    }

    if (cancelFlag && cancelFlag->load(std::memory_order_relaxed)) {
        return false;
    }

    const QString actualSha256 = QString::fromLatin1(hash.result().toHex());
    const bool matches = actualSha256.compare(expectedSha256.trimmed(), Qt::CaseInsensitive) == 0;
    if (!matches) {
        qWarning() << "[Updater] Checksum mismatch! Expected:" << expectedSha256
                   << "Actual:" << actualSha256;
    }
    return matches;
}

} // namespace

Updater::Updater(QObject* parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_retryTimer(new QTimer(this))
    , m_hashWatcher(new QFutureWatcher<HashResult>(this))
{
    m_manifestMirrors = {
        QStringLiteral("https://github.com/T12ASH/guiLessonShowerForBSTU/releases/latest/download/update_info.json"),
        QStringLiteral("https://github.com/T12ASH/guiLessonShowerForBSTU/releases/latest/download/latest.json"),
        QStringLiteral("https://codeberg.org/T12ASH/guiLessonShowerForBSTU/releases/download/latest/update_info.json"),
        QStringLiteral("https://codeberg.org/T12ASH/guiLessonShowerForBSTU/releases/download/latest/latest.json")
    };

    m_retryTimer->setSingleShot(true);
    connect(m_retryTimer, &QTimer::timeout, this, &Updater::downloadFromNextMirror);
    connect(m_hashWatcher, &QFutureWatcher<HashResult>::finished,
            this, &Updater::onHashVerificationFinished);

    // 1. Read installed app version from bundled update_info.json
    loadCurrentVersionFromLocalJson();

    // 2. Remove broken partial .tmp files, and wipe cache if user already updated
    cleanStaleTempFiles();
    cleanupIfAlreadyUpdated();

    QSettings settings(QString::fromLatin1(SETTINGS_ORG), QString::fromLatin1(SETTINGS_APP));
    m_failureCount = settings.value(QString::fromLatin1(SETTINGS_FAIL_KEY), 0).toInt();
    if (m_failureCount >= CRITICAL_FAILURE_THRESHOLD) {
        m_hasCriticalError = true;
        QTimer::singleShot(0, this, [this]() {
            if (m_hasCriticalError) {
                emit criticalErrorThresholdReached();
            }
        });
    }
}

Updater::~Updater()
{
    cancelActiveOperations();
}

void Updater::loadCurrentVersionFromLocalJson()
{
    // The compiled version identifies the installed application. The bundled
    // update manifest describes release metadata and can intentionally be stale.
    const QString compiledVersion = QCoreApplication::applicationVersion().trimmed();
    if (VersionInfo::parse(compiledVersion).isValid) {
        m_currentVersion = compiledVersion;
        qDebug() << "[Updater] Loaded currentVersion from compiled application version:"
                 << m_currentVersion;
        return;
    }

    const QStringList candidates = {
        QDir::currentPath() + QStringLiteral("/updater/") + QString::fromLatin1(MANIFEST_FILENAME),
        QDir::currentPath() + QLatin1Char('/') + QString::fromLatin1(MANIFEST_FILENAME),
        QCoreApplication::applicationDirPath() + QStringLiteral("/updater/") + QString::fromLatin1(MANIFEST_FILENAME),
        QCoreApplication::applicationDirPath() + QLatin1Char('/') + QString::fromLatin1(MANIFEST_FILENAME),
        QStringLiteral("updater/") + QString::fromLatin1(MANIFEST_FILENAME),
        QString::fromLatin1(MANIFEST_FILENAME),
        QStringLiteral(":/qt/qml/BSTUcurriculum/updater/") + QString::fromLatin1(MANIFEST_FILENAME),
        QStringLiteral(":/BSTUcurriculum/updater/") + QString::fromLatin1(MANIFEST_FILENAME),
        QStringLiteral(":/BSTUcurriculum/") + QString::fromLatin1(MANIFEST_FILENAME),
        QStringLiteral(":/updater/") + QString::fromLatin1(MANIFEST_FILENAME),
        QStringLiteral(":/") + QString::fromLatin1(MANIFEST_FILENAME)
    };

    for (const QString& candidatePath : candidates) {
        QFile file(candidatePath);
        if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
            continue;
        }
        const UpdateManifest localManifest = parseManifest(file.read(MAX_MANIFEST_BYTES));
        if (localManifest.isValid && !localManifest.version.isEmpty()) {
            m_currentVersion = localManifest.version;
            QCoreApplication::setApplicationVersion(m_currentVersion);
            qDebug() << "[Updater] Loaded currentVersion from fallback local json"
                     << candidatePath << ":" << m_currentVersion;
            return;
        }
    }

    qWarning() << "[Updater] Could not determine the installed application version.";
}

void Updater::cleanupIfAlreadyUpdated()
{
    const QString manifestPath = cachedManifestPath();
    if (!QFile::exists(manifestPath)) {
        return;
    }

    QFile file(manifestPath);
    if (!file.open(QIODevice::ReadOnly)) {
        cleanCacheDir();
        return;
    }

    const UpdateManifest cached = parseManifest(file.read(MAX_MANIFEST_BYTES));
    if (!cached.isValid || !VersionInfo::parse(m_currentVersion).isValid) {
        return;
    }

    // User already installed this (or newer) version -> wipe entire temp_updater/
    if (!isVersionGreater(cached.version, m_currentVersion)) {
        qDebug() << "[Updater] App already at" << m_currentVersion
                 << "(cached:" << cached.version << "), clearing temp_updater/";
        cleanCacheDir();
    }
}

QString Updater::currentVersion() const { return m_currentVersion; }

void Updater::setCurrentVersion(const QString& version)
{
    if (m_currentVersion != version) {
        m_currentVersion = version;
        emit currentVersionChanged();
        cleanupIfAlreadyUpdated();
    }
}

QString Updater::newVersion() const { return m_currentManifest.version; }
QString Updater::changelog() const { return m_currentManifest.changelog; }
QString Updater::releasePage() const { return m_currentManifest.releasePage; }
bool Updater::isChecking() const { return m_isChecking; }
bool Updater::isDownloading() const { return m_isDownloading; }
qreal Updater::downloadProgress() const { return m_downloadProgress; }
bool Updater::updateAvailable() const { return m_updateAvailable; }
bool Updater::updateReady() const { return m_updateReady; }
QString Updater::updateFilePath() const { return m_updateFilePath; }
bool Updater::hasCriticalError() const { return m_hasCriticalError; }
bool Updater::hasCache() const
{
    const QString dir = cacheDirectory();
    QDir d(dir);
    if (!d.exists()) {
        return false;
    }
    const QStringList filters = {
        QStringLiteral("update_*"),
        QString::fromLatin1(MANIFEST_FILENAME),
        QString::fromLatin1(MANIFEST_TMP_FILENAME),
        QString::fromLatin1(DOWNLOAD_TMP_FILENAME)
    };
    return !d.entryList(filters, QDir::Files).isEmpty();
}
int Updater::failureCount() const { return m_failureCount; }
QString Updater::statusMessage() const { return m_statusMessage; }
QStringList Updater::manifestMirrors() const { return m_manifestMirrors; }

void Updater::setManifestMirrors(const QStringList& mirrors)
{
    if (m_manifestMirrors != mirrors) {
        m_manifestMirrors = mirrors;
        emit manifestMirrorsChanged();
    }
}

bool Updater::isVersionGreater(const QString& remoteVer, const QString& localVer)
{
    const VersionInfo r = VersionInfo::parse(remoteVer);
    const VersionInfo l = VersionInfo::parse(localVer);
    if (!r.isValid || !l.isValid) {
        qWarning() << "[Updater] Invalid version comparison:" << remoteVer << "vs" << localVer;
        return false;
    }
    return r > l;
}

void Updater::checkForUpdates()
{
    if (m_isChecking || m_isDownloading || m_isVerifying) {
        return;
    }

    loadCurrentVersionFromLocalJson();
    cleanStaleTempFiles();
    cleanupIfAlreadyUpdated();

    if (m_manifestMirrors.isEmpty()) {
        qWarning() << "[Updater] Manifest mirrors list is empty.";
        if (!tryLoadCachedUpdate()) {
            emit updateCheckFinished(false);
        }
        return;
    }

    m_manifestHadNonNetworkFailure = false;
    m_manifestHadNetworkFailure = false;
    m_activeManifestMirrors = m_manifestMirrors;
    m_currentManifestMirrorIndex = 0;
    setIsChecking(true);
    setStatusMessage(QStringLiteral("Checking for updates..."));

    fetchManifestFromNextMirror();
}

void Updater::checkForUpdatesFromUrl(const QString& url)
{
    if (m_isChecking || m_isDownloading || m_isVerifying) {
        return;
    }

    if (url.trimmed().isEmpty()) {
        qWarning() << "[Updater] Custom manifest URL is empty.";
        return;
    }

    cleanStaleTempFiles();
    m_manifestHadNonNetworkFailure = false;
    m_manifestHadNetworkFailure = false;
    cleanupIfAlreadyUpdated();

    m_activeManifestMirrors = { url.trimmed() };
    m_currentManifestMirrorIndex = 0;
    setIsChecking(true);
    setStatusMessage(QStringLiteral("Checking for updates from custom URL..."));

    fetchManifestFromNextMirror();
}

void Updater::checkManifestData(const QString& jsonContent)
{
    if (m_isChecking || m_isDownloading || m_isVerifying) {
        return;
    }

    cleanStaleTempFiles();
    cleanupIfAlreadyUpdated();

    const UpdateManifest manifest = parseManifest(jsonContent.toUtf8());
    processManifest(manifest);
}

void Updater::fetchManifestFromNextMirror()
{
    if (m_currentManifestMirrorIndex >= m_activeManifestMirrors.size()) {
        setIsChecking(false);
        if (m_manifestHadNonNetworkFailure && !m_manifestHadNetworkFailure) {
            recordFailure(false);
        }
        m_manifestHadNonNetworkFailure = false;
        m_manifestHadNetworkFailure = false;

        // No network or mirrors reachable: still offer a previously downloaded update.
        if (tryLoadCachedUpdate()) {
            return;
        }
        setStatusMessage(QStringLiteral("All update mirrors failed."));
        emit updateCheckFinished(false);
        return;
    }

    const QUrl url(m_activeManifestMirrors.at(m_currentManifestMirrorIndex));
    if (!url.isValid() || (url.scheme() != QStringLiteral("https") && url.scheme() != QStringLiteral("http"))) {
        qWarning() << "[Updater] Skipping invalid manifest mirror URL:" << url;
        m_manifestHadNonNetworkFailure = true;
        m_currentManifestMirrorIndex++;
        fetchManifestFromNextMirror();
        return;
    }

    abortManifestReply();
    m_manifestBuffer.clear();
    m_manifestTooLarge = false;

    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(MANIFEST_TIMEOUT_MS);

    m_manifestReply = m_networkManager->get(request);
    connect(m_manifestReply, &QNetworkReply::readyRead,
            this, &Updater::onManifestDataReady);
    connect(m_manifestReply, &QNetworkReply::finished,
            this, &Updater::onManifestReplyFinished);
}

void Updater::onManifestDataReady()
{
    if (!m_manifestReply || m_manifestTooLarge) {
        return;
    }

    const QByteArray chunk = m_manifestReply->readAll();
    if (m_manifestBuffer.size() + chunk.size() > MAX_MANIFEST_BYTES) {
        qWarning() << "[Updater] Manifest exceeds maximum allowed size:" << MAX_MANIFEST_BYTES;
        m_manifestTooLarge = true;
        m_manifestBuffer.clear();
        m_manifestReply->abort();
        return;
    }
    m_manifestBuffer.append(chunk);
}

void Updater::onManifestReplyFinished()
{
    if (!m_manifestReply) {
        return;
    }

    const QNetworkReply::NetworkError error = m_manifestReply->error();
    const int httpStatusCode = m_manifestReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

    if (error == QNetworkReply::NoError && !m_manifestTooLarge && m_manifestReply->bytesAvailable() > 0) {
        onManifestDataReady();
    }

    const QString errorString = m_manifestReply->errorString();
    m_manifestReply->disconnect(this);
    m_manifestReply->deleteLater();
    m_manifestReply = nullptr;

    if (!m_manifestTooLarge && error == QNetworkReply::NoError && (httpStatusCode == 200 || httpStatusCode == 0)) {
        const UpdateManifest manifest = parseManifest(m_manifestBuffer);
        m_manifestBuffer.clear();

        if (manifest.isValid) {
            setIsChecking(false);
            m_manifestHadNonNetworkFailure = false;
            m_manifestHadNetworkFailure = false;
            processManifest(manifest);
            return;
        }

        qWarning() << "[Updater] Failed to parse manifest JSON.";
        m_manifestHadNonNetworkFailure = true;
    } else {
        m_manifestBuffer.clear();
        const bool noInternet = !m_manifestTooLarge && isNetworkUnavailableError(error);
        qWarning() << "[Updater] Manifest request failed:" << errorString
                   << "HTTP:" << httpStatusCode << "TooLarge:" << m_manifestTooLarge
                   << "NoInternet:" << noInternet;
        if (noInternet) {
            m_manifestHadNetworkFailure = true;
        } else {
            m_manifestHadNonNetworkFailure = true;
        }
    }

    m_currentManifestMirrorIndex++;
    fetchManifestFromNextMirror();
}

UpdateManifest Updater::parseManifest(const QByteArray& data) const
{
    UpdateManifest manifest;

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "[Updater] JSON parse error:" << parseError.errorString();
        return manifest;
    }

    const QJsonObject root = doc.object();
    QJsonObject selected = root;
    QString manifestType = root.value(QStringLiteral("type")).toString().trimmed();
    const bool currentIsTest = VersionInfo::parse(m_currentVersion).isTest;

    // New manifests contain separate stable and test entries. Select only the
    // test entry for a test build; release builds never consume test updates.
    if (root.value(QStringLiteral("stable")).isObject()
        || root.value(QStringLiteral("test")).isObject()) {
        QString preferredKey = currentIsTest ? QStringLiteral("test") : QStringLiteral("stable");
        if (!root.value(preferredKey).isObject()) {
            preferredKey = (preferredKey == QStringLiteral("stable"))
                ? QStringLiteral("test")
                : QStringLiteral("stable");
        }
        if (root.value(preferredKey).isObject()) {
            selected = root.value(preferredKey).toObject();
            manifestType = preferredKey;
        }
    }

    manifest.version = selected.value(QStringLiteral("version")).toString().trimmed();
    manifest.releasePage = selected.value(QStringLiteral("release_page")).toString().trimmed();
    manifest.changelog = selected.value(QStringLiteral("changelog")).toString();
    manifest.type = manifestType;

    const QJsonObject platforms = selected.value(QStringLiteral("platforms")).toObject();
    QString targetPlatform = currentPlatformKey();
    if (!platforms.contains(targetPlatform) && platforms.contains(QStringLiteral("android"))) {
        targetPlatform = QStringLiteral("android");
    }

    if (platforms.contains(targetPlatform)) {
        const QJsonObject platObj = platforms.value(targetPlatform).toObject();
        manifest.platformInfo.filetype = platObj.value(QStringLiteral("filetype")).toString().trimmed();
        manifest.platformInfo.sha256 = platObj.value(QStringLiteral("sha256")).toString().trimmed();
        const QJsonArray mirrorsArr = platObj.value(QStringLiteral("mirrors")).toArray();
        for (const auto& val : mirrorsArr) {
            const QString mirror = val.toString().trimmed();
            if (!mirror.isEmpty()) {
                manifest.platformInfo.mirrors.append(mirror);
            }
        }
    }

    manifest.rawJson = doc.toJson(QJsonDocument::Indented);
    manifest.isValid = VersionInfo::parse(manifest.version).isValid;
    return manifest;
}

bool Updater::tryLoadCachedUpdate()
{
    const QString manifestPath = cachedManifestPath();
    QFile file(manifestPath);
    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        return false;
    }

    const UpdateManifest cached = parseManifest(file.read(MAX_MANIFEST_BYTES));
    if (!cached.isValid) {
        cleanCacheDir();
        return false;
    }

    const bool isCurrentTest = VersionInfo::parse(m_currentVersion).isTest;
    const bool isManifestTest = cached.type.compare(QStringLiteral("test"), Qt::CaseInsensitive) == 0;
    if (isManifestTest && !isCurrentTest) {
        cleanCacheDir();
        return false;
    }

    if (!isVersionGreater(cached.version, m_currentVersion)) {
        cleanCacheDir();
        return false;
    }

    if (!isSafeFileType(cached.platformInfo.filetype) || !isValidSha256(cached.platformInfo.sha256)) {
        cleanCacheDir();
        return false;
    }

    const QString destFile = targetFilePath(cached.version, cached.platformInfo.filetype);
    if (!QFile::exists(destFile)) {
        cleanCacheDir();
        return false;
    }

    m_currentManifest = cached;
    emit newVersionChanged();
    emit changelogChanged();
    emit releasePageChanged();
    setStatusMessage(QStringLiteral("Verifying cached update..."));

    verifyFileSha256Async(destFile, cached.platformInfo.sha256, HashPurpose::CacheCheckOffline);
    return true;
}

bool Updater::saveCachedManifestJson(const QByteArray& jsonData) const
{
    if (jsonData.isEmpty()) {
        return false;
    }

    const QString tempJsonPath = cacheDirectory() + QLatin1Char('/') + QString::fromLatin1(MANIFEST_TMP_FILENAME);
    QFile tmpFile(tempJsonPath);
    if (!tmpFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "[Updater] Cannot open temp manifest file for writing:" << tempJsonPath;
        return false;
    }

    if (tmpFile.write(jsonData) != jsonData.size() || !tmpFile.flush()) {
        qWarning() << "[Updater] Failed to write temp manifest file:" << tmpFile.errorString();
        tmpFile.close();
        QFile::remove(tempJsonPath);
        return false;
    }
    tmpFile.close();

    const QString finalPath = cachedManifestPath();
    if (QFile::exists(finalPath)) {
        QFile::remove(finalPath);
    }

    if (!QFile::rename(tempJsonPath, finalPath)) {
        qWarning() << "[Updater] Failed to replace temp_updater/update_info.json:" << finalPath;
        QFile::remove(tempJsonPath);
        return false;
    }

    return true;
}

void Updater::processManifest(const UpdateManifest& manifest)
{
    if (!manifest.isValid) {
        emit updateCheckFinished(false);
        return;
    }

    const bool isCurrentTest = VersionInfo::parse(m_currentVersion).isTest;
    const bool isManifestTest = manifest.type.compare(QStringLiteral("test"), Qt::CaseInsensitive) == 0;
    if (isManifestTest && !isCurrentTest) {
        qDebug() << "[Updater] Skipping test update for release client.";
        emit updateCheckFinished(false);
        return;
    }

    // Remote version is same or older -> wipe cache and download nothing
    if (!isVersionGreater(manifest.version, m_currentVersion)) {
        qDebug() << "[Updater] Application is up-to-date:" << m_currentVersion << ">= remote" << manifest.version;
        cleanCacheDir();
        setUpdateAvailable(false);
        setUpdateReady(false);
        setUpdateFilePath(QString());
        setStatusMessage(QStringLiteral("Application is up-to-date."));
        emit updateCheckFinished(false);
        return;
    }

    m_currentManifest = manifest;
    emit newVersionChanged();
    emit changelogChanged();
    emit releasePageChanged();

    if (manifest.platformInfo.mirrors.isEmpty()) {
        qWarning() << "[Updater] No download mirrors available for platform:" << currentPlatformKey();
        setStatusMessage(QStringLiteral("No update package available for this platform."));
        emit updateCheckFinished(false);
        return;
    }
    if (!isSafeFileType(manifest.platformInfo.filetype)) {
        qWarning() << "[Updater] Unsafe or missing filetype in manifest:" << manifest.platformInfo.filetype;
        recordFailure(false);
        emit updateCheckFinished(false);
        return;
    }
    if (!isValidSha256(manifest.platformInfo.sha256)) {
        qWarning() << "[Updater] Invalid SHA-256 in manifest:" << manifest.platformInfo.sha256;
        recordFailure(false);
        emit updateCheckFinished(false);
        return;
    }

    const QString destFile = targetFilePath(manifest.version, manifest.platformInfo.filetype);

    // If this exact latest version is already cached in temp_updater/, verify it without re-downloading
    if (QFile::exists(destFile)) {
        setStatusMessage(QStringLiteral("Verifying cached update..."));
        verifyFileSha256Async(destFile, manifest.platformInfo.sha256, HashPurpose::CacheCheckOnline);
        return;
    }

    // Newer version than cached (or empty cache) -> wipe old temp_updater/ and download fresh package silently
    cleanCacheDir();
    setUpdateAvailable(false);
    setUpdateReady(false);
    setUpdateFilePath(QString());
    startDownload();
}

void Updater::startDownload()
{
    if (m_isDownloading || m_isVerifying) {
        return;
    }

    m_downloadMirrors = m_currentManifest.platformInfo.mirrors;
    if (m_downloadMirrors.isEmpty()) {
        qWarning() << "[Updater] No download mirrors available for this platform.";
        emit updateDownloadFinished(false);
        return;
    }

    m_currentDownloadMirrorIndex = 0;
    m_currentMirrorFailCount = 0;
    setIsDownloading(true);
    setDownloadProgress(0.0);
    setStatusMessage(QStringLiteral("Downloading update in background..."));

    downloadFromNextMirror();
}

void Updater::downloadFromNextMirror()
{
    if (m_currentDownloadMirrorIndex >= m_downloadMirrors.size()) {
        qWarning() << "[Updater] All download mirrors exhausted for this session.";
        cleanCacheDir();
        setIsDownloading(false);
        setStatusMessage(QStringLiteral("Failed to download update."));
        emit updateDownloadFinished(false);
        emit updateCheckFinished(false);
        return;
    }

    const QUrl url(m_downloadMirrors.at(m_currentDownloadMirrorIndex));
    if (!url.isValid() || (url.scheme() != QStringLiteral("https") && url.scheme() != QStringLiteral("http"))) {
        qWarning() << "[Updater] Skipping invalid download mirror URL:" << url;
        m_currentDownloadMirrorIndex++;
        m_currentMirrorFailCount = 0;
        downloadFromNextMirror();
        return;
    }

    abortDownloadReply();
    closeTempFile();
    cleanCacheDir();

    const QString tmpDir = cacheDirectory();
    if (!hasEnoughDiskSpace(tmpDir, MIN_FREE_SPACE_BYTES)) {
        qWarning() << "[Updater] Insufficient disk space to start update download.";
        setIsDownloading(false);
        setStatusMessage(QStringLiteral("Insufficient storage space for update."));
        emit updateDownloadFinished(false);
        emit updateCheckFinished(false);
        return;
    }

    m_tempFilePath = tmpDir + QLatin1Char('/') + QString::fromLatin1(DOWNLOAD_TMP_FILENAME);
    m_tempFile = new QFile(m_tempFilePath, this);
    if (!m_tempFile->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "[Updater] Cannot open temp file for writing:" << m_tempFilePath;
        closeTempFile();
        setIsDownloading(false);
        setStatusMessage(QStringLiteral("Cannot write update file to storage."));
        emit updateDownloadFinished(false);
        emit updateCheckFinished(false);
        return;
    }

    m_downloadedBytes = 0;
    m_diskWriteFailed = false;
    m_downloadTooLarge = false;
    m_checkedTotalSize = false;
    setDownloadProgress(0.0);

    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(DOWNLOAD_TIMEOUT_MS);

    m_downloadReply = m_networkManager->get(request);
    m_downloadReply->setReadBufferSize(DOWNLOAD_READ_BUFFER_BYTES);
    connect(m_downloadReply, &QNetworkReply::readyRead,
            this, &Updater::onDownloadDataReady);
    connect(m_downloadReply, &QNetworkReply::downloadProgress,
            this, &Updater::onDownloadProgress);
    connect(m_downloadReply, &QNetworkReply::finished,
            this, &Updater::onDownloadReplyFinished);
}

void Updater::onDownloadDataReady()
{
    if (!m_downloadReply || !m_tempFile || !m_tempFile->isOpen() || m_diskWriteFailed || m_downloadTooLarge) {
        return;
    }

    const QByteArray chunk = m_downloadReply->readAll();
    if (chunk.isEmpty()) {
        return;
    }

    if (m_downloadedBytes + chunk.size() > MAX_PACKAGE_BYTES) {
        qWarning() << "[Updater] Package exceeds max allowed size:" << MAX_PACKAGE_BYTES;
        m_downloadTooLarge = true;
        m_downloadReply->abort();
        return;
    }

    const qint64 written = m_tempFile->write(chunk);
    if (written != chunk.size()) {
        qWarning() << "[Updater] Disk write failed:" << m_tempFile->errorString();
        m_diskWriteFailed = true;
        m_downloadReply->abort();
        return;
    }

    m_downloadedBytes += written;
}

void Updater::onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal)
{
    if (bytesTotal <= 0) {
        return;
    }

    if (!m_checkedTotalSize) {
        m_checkedTotalSize = true;
        if (bytesTotal > MAX_PACKAGE_BYTES) {
            qWarning() << "[Updater] Reported Content-Length exceeds limit:" << bytesTotal;
            m_downloadTooLarge = true;
            if (m_downloadReply) {
                m_downloadReply->abort();
            }
            return;
        }
        if (!hasEnoughDiskSpace(cacheDirectory(), bytesTotal + EXTRA_DISK_MARGIN_BYTES)) {
            qWarning() << "[Updater] Not enough disk space for package of size:" << bytesTotal;
            m_diskWriteFailed = true;
            if (m_downloadReply) {
                m_downloadReply->abort();
            }
            return;
        }
    }

    const qreal progress = qBound<qreal>(0.0, static_cast<qreal>(bytesReceived) / static_cast<qreal>(bytesTotal), 1.0);
    if (qAbs(progress - m_downloadProgress) >= 0.005 || bytesReceived == bytesTotal) {
        setDownloadProgress(progress);
    }
}

void Updater::onDownloadReplyFinished()
{
    if (!m_downloadReply) {
        return;
    }

    const QNetworkReply::NetworkError error = m_downloadReply->error();
    const int httpStatusCode = m_downloadReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QString errorString = m_downloadReply->errorString();

    if (error == QNetworkReply::NoError && !m_diskWriteFailed && !m_downloadTooLarge
        && m_downloadReply->bytesAvailable() > 0) {
        onDownloadDataReady();
    }

    if (m_tempFile && m_tempFile->isOpen()) {
        if (!m_tempFile->flush()) {
            qWarning() << "[Updater] Failed to flush temp file:" << m_tempFile->errorString();
            m_diskWriteFailed = true;
        }
    }
    closeTempFile();

    m_downloadReply->disconnect(this);
    m_downloadReply->deleteLater();
    m_downloadReply = nullptr;

    if (m_diskWriteFailed) {
        cleanCacheDir();
        setIsDownloading(false);
        setStatusMessage(QStringLiteral("Insufficient storage space or write error."));
        emit updateDownloadFinished(false);
        emit updateCheckFinished(false);
        return;
    }

    const bool downloadOk = !m_downloadTooLarge
                            && error == QNetworkReply::NoError
                            && (httpStatusCode == 200 || httpStatusCode == 0);

    if (downloadOk) {
        setStatusMessage(QStringLiteral("Verifying downloaded update..."));
        verifyFileSha256Async(m_tempFilePath, m_currentManifest.platformInfo.sha256, HashPurpose::DownloadedFile);
        return;
    }

    cleanCacheDir();

    const bool noInternet = !m_downloadTooLarge && isNetworkUnavailableError(error);
    qWarning() << "[Updater] Download failed:" << errorString
               << "HTTP:" << httpStatusCode << "TooLarge:" << m_downloadTooLarge
               << "NoInternet:" << noInternet;

    if (!noInternet) {
        recordFailure(false);
    }

    const bool switchMirrorNow = m_downloadTooLarge || isPermanentHttpError(httpStatusCode);
    scheduleNextDownloadAttempt(switchMirrorNow);
}

void Updater::scheduleNextDownloadAttempt(bool switchMirrorImmediately)
{
    if (switchMirrorImmediately) {
        m_currentDownloadMirrorIndex++;
        m_currentMirrorFailCount = 0;
    } else {
        m_currentMirrorFailCount++;
        if (m_currentMirrorFailCount >= MAX_FAILURES_PER_MIRROR) {
            m_currentDownloadMirrorIndex++;
            m_currentMirrorFailCount = 0;
        }
    }

    if (m_currentDownloadMirrorIndex >= m_downloadMirrors.size()) {
        downloadFromNextMirror();
        return;
    }

    const int attempt = qMax(0, m_currentMirrorFailCount - 1);
    const int delayMs = switchMirrorImmediately ? 1000 : qMin(15000, 1000 * (1 << attempt));
    qDebug() << "[Updater] Scheduling next download attempt in" << delayMs << "ms (mirror"
             << m_currentDownloadMirrorIndex << "fail" << m_currentMirrorFailCount << ")";
    m_retryTimer->start(delayMs);
}

void Updater::verifyFileSha256Async(const QString& filePath, const QString& expectedSha256, HashPurpose purpose)
{
    if (m_hashCancelFlag) {
        m_hashCancelFlag->store(true, std::memory_order_relaxed);
    }

    m_currentHashJobId++;
    const quint64 jobId = m_currentHashJobId;
    m_hashPurpose = purpose;
    m_verifyingFilePath = filePath;
    m_isVerifying = true;

    auto cancelFlag = std::make_shared<std::atomic_bool>(false);
    m_hashCancelFlag = cancelFlag;

    auto promise = std::make_shared<QPromise<HashResult>>();
    QFuture<HashResult> future = promise->future();
    m_hashWatcher->setFuture(future);

    QThreadPool::globalInstance()->start([promise, filePath, expectedSha256, cancelFlag, jobId]() {
        promise->start();
        const bool ok = computeAndCompareSha256(filePath, expectedSha256, cancelFlag);
        promise->addResult(HashResult{jobId, ok});
        promise->finish();
    });
}

void Updater::onHashVerificationFinished()
{
    const HashResult result = m_hashWatcher->result();
    if (result.jobId != m_currentHashJobId || !m_isVerifying) {
        return;
    }

    const HashPurpose purpose = m_hashPurpose;
    const QString filePath = m_verifyingFilePath;
    m_isVerifying = false;
    m_hashPurpose = HashPurpose::None;
    m_verifyingFilePath.clear();

    if (purpose == HashPurpose::CacheCheckOnline || purpose == HashPurpose::CacheCheckOffline) {
        if (result.matches) {
            qDebug() << "[Updater] Cached package verified in temp_updater/:" << filePath;
            if (purpose == HashPurpose::CacheCheckOnline) {
                saveCachedManifestJson(m_currentManifest.rawJson);
            }
            setUpdateFilePath(filePath);
            setUpdateAvailable(true);
            setUpdateReady(true);
            setStatusMessage(QStringLiteral("Update is ready to install."));
            recordSuccess();
            emit hasCacheChanged();
            emit updateCheckFinished(true);
            return;
        }

        qWarning() << "[Updater] Cached package failed SHA-256 check, wiping temp_updater/";
        cleanCacheDir();

        if (purpose == HashPurpose::CacheCheckOffline) {
            setUpdateAvailable(false);
            setUpdateReady(false);
            setUpdateFilePath(QString());
            setStatusMessage(QStringLiteral("All update mirrors failed."));
            emit updateCheckFinished(false);
            return;
        }

        startDownload();
        return;
    }

    if (purpose == HashPurpose::DownloadedFile) {
        if (result.matches) {
            const QString targetPath = targetFilePath(m_currentManifest.version,
                                                      m_currentManifest.platformInfo.filetype);
            if (QFile::exists(targetPath)) {
                QFile::remove(targetPath);
            }
            if (QFile::rename(filePath, targetPath)) {
                saveCachedManifestJson(m_currentManifest.rawJson);

                setUpdateFilePath(targetPath);
                setUpdateAvailable(true);
                setUpdateReady(true);
                setIsDownloading(false);
                setDownloadProgress(1.0);
                setStatusMessage(QStringLiteral("Update downloaded and verified."));
                recordSuccess();
                emit hasCacheChanged();
                emit updateDownloadFinished(true);
                emit updateCheckFinished(true);
                return;
            }
            qWarning() << "[Updater] Failed to rename temp file to:" << targetPath;
            cleanCacheDir();
            recordFailure(false);
            setIsDownloading(false);
            setStatusMessage(QStringLiteral("Failed to save update file."));
            emit updateDownloadFinished(false);
            emit updateCheckFinished(false);
            return;
        }

        qWarning() << "[Updater] Downloaded file SHA-256 mismatch, switching mirror.";
        cleanCacheDir();
        recordFailure(false);
        scheduleNextDownloadAttempt(true);
    }
}

void Updater::cancelActiveOperations()
{
    if (m_retryTimer) {
        m_retryTimer->stop();
    }
    if (m_hashCancelFlag) {
        m_hashCancelFlag->store(true, std::memory_order_relaxed);
    }
    m_currentHashJobId++;
    m_isVerifying = false;
    m_hashPurpose = HashPurpose::None;

    abortManifestReply();
    abortDownloadReply();
    closeTempFile();
    // Only delete incomplete .tmp files on exit — preserve already verified postponed APK!
    cleanStaleTempFiles();
}

void Updater::abortManifestReply()
{
    if (m_manifestReply) {
        m_manifestReply->disconnect(this);
        m_manifestReply->abort();
        m_manifestReply->deleteLater();
        m_manifestReply = nullptr;
    }
}

void Updater::abortDownloadReply()
{
    if (m_downloadReply) {
        m_downloadReply->disconnect(this);
        m_downloadReply->abort();
        m_downloadReply->deleteLater();
        m_downloadReply = nullptr;
    }
}

void Updater::closeTempFile()
{
    if (m_tempFile) {
        if (m_tempFile->isOpen()) {
            m_tempFile->close();
        }
        delete m_tempFile;
        m_tempFile = nullptr;
    }
}

void Updater::cleanStaleTempFiles() const
{
    const QString dir = cacheDirectory();
    const QString downloadTmp = dir + QLatin1Char('/') + QString::fromLatin1(DOWNLOAD_TMP_FILENAME);
    const QString manifestTmp = dir + QLatin1Char('/') + QString::fromLatin1(MANIFEST_TMP_FILENAME);
    if (QFile::exists(downloadTmp)) {
        QFile::remove(downloadTmp);
    }
    if (QFile::exists(manifestTmp)) {
        QFile::remove(manifestTmp);
    }
}

void Updater::cleanCacheDir() const
{
    const QString path = cacheDirectory();
    QDir dir(path);
    if (!dir.exists()) {
        dir.mkpath(path);
        return;
    }

    const QStringList filters = {
        QStringLiteral("update_*"),
        QString::fromLatin1(MANIFEST_FILENAME),
        QString::fromLatin1(MANIFEST_TMP_FILENAME),
        QString::fromLatin1(DOWNLOAD_TMP_FILENAME)
    };
    const QFileInfoList entries = dir.entryInfoList(filters, QDir::Files | QDir::Hidden | QDir::System);
    for (const QFileInfo& info : entries) {
        QFile::remove(info.absoluteFilePath());
    }
    const_cast<Updater*>(this)->emit hasCacheChanged();
}

QString Updater::cacheDirectory() const
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(base);
    return base;
}

QString Updater::cachedManifestPath() const
{
    return cacheDirectory() + QLatin1Char('/') + QString::fromLatin1(MANIFEST_FILENAME);
}

QString Updater::targetFilePath(const QString& version, const QString& filetype) const
{
    return cacheDirectory() + QStringLiteral("/update_") + version + filetype;
}

bool Updater::hasEnoughDiskSpace(const QString& dirPath, qint64 requiredBytes) const
{
    const QStorageInfo storage(dirPath);
    if (!storage.isValid() || !storage.isReady()) {
        return true;
    }
    const qint64 available = storage.bytesAvailable();
    return available < 0 || available >= requiredBytes;
}

void Updater::setIsChecking(bool checking)
{
    if (m_isChecking != checking) {
        m_isChecking = checking;
        emit isCheckingChanged();
    }
}

void Updater::setIsDownloading(bool downloading)
{
    if (m_isDownloading != downloading) {
        m_isDownloading = downloading;
        emit isDownloadingChanged();
    }
}

void Updater::setDownloadProgress(qreal progress)
{
    if (!qFuzzyCompare(m_downloadProgress, progress)) {
        m_downloadProgress = progress;
        emit downloadProgressChanged();
    }
}

void Updater::setUpdateAvailable(bool available)
{
    if (m_updateAvailable != available) {
        m_updateAvailable = available;
        emit updateAvailableChanged();
    }
}

void Updater::setUpdateReady(bool ready)
{
    if (m_updateReady != ready) {
        m_updateReady = ready;
        emit updateReadyChanged();
    }
}

void Updater::setUpdateFilePath(const QString& path)
{
    if (m_updateFilePath != path) {
        m_updateFilePath = path;
        emit updateFilePathChanged();
    }
}

void Updater::setStatusMessage(const QString& message)
{
    if (m_statusMessage != message) {
        m_statusMessage = message;
        emit statusMessageChanged();
    }
}

void Updater::recordFailure(bool isNetworkUnavailable)
{
    if (isNetworkUnavailable) {
        return;
    }

    m_failureCount++;
    QSettings settings(QString::fromLatin1(SETTINGS_ORG), QString::fromLatin1(SETTINGS_APP));
    settings.setValue(QString::fromLatin1(SETTINGS_FAIL_KEY), m_failureCount);
    emit failureCountChanged();

    if (m_failureCount >= CRITICAL_FAILURE_THRESHOLD && !m_hasCriticalError) {
        m_hasCriticalError = true;
        emit hasCriticalErrorChanged();
        emit criticalErrorThresholdReached();
    }
}

void Updater::recordSuccess()
{
    resetFailureCount();
}

void Updater::resetFailureCount()
{
    const bool changed = (m_failureCount != 0);
    m_failureCount = 0;

    QSettings settings(QString::fromLatin1(SETTINGS_ORG), QString::fromLatin1(SETTINGS_APP));
    settings.setValue(QString::fromLatin1(SETTINGS_FAIL_KEY), 0);

    if (m_hasCriticalError) {
        m_hasCriticalError = false;
        emit hasCriticalErrorChanged();
    }
    if (changed) {
        emit failureCountChanged();
    }
}

void Updater::postponeUpdate()
{
    qDebug() << "[Updater] Update postponed by user. Package preserved in temp_updater/.";
    setUpdateAvailable(false);
}

void Updater::cleanCache()
{
    cancelActiveOperations();
    setIsChecking(false);
    setIsDownloading(false);
    setDownloadProgress(0.0);
    cleanCacheDir();
    setUpdateAvailable(false);
    setUpdateReady(false);
    setUpdateFilePath(QString());
    setStatusMessage(QStringLiteral("Update cache cleared."));
    emit hasCacheChanged();
}

void Updater::installUpdate()
{
    if (m_updateFilePath.isEmpty() || !QFile::exists(m_updateFilePath)) {
        qWarning() << "[Updater] Cannot install: file not found:" << m_updateFilePath;
        setStatusMessage(QStringLiteral("Update file not found."));
        return;
    }

#if defined(Q_OS_ANDROID)
    qDebug() << "[Updater] Launching Android installer for:" << m_updateFilePath;
    QJniEnvironment env;

    QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid()) {
        qWarning() << "[Updater] Invalid Android context.";
        return;
    }

    QJniObject packageName = context.callObjectMethod("getPackageName", "()Ljava/lang/String;");
    if (env.checkAndClearExceptions() || !packageName.isValid()) {
        qWarning() << "[Updater] Failed to obtain Android package name.";
        return;
    }

    if (QNativeInterface::QAndroidApplication::sdkVersion() >= 26) {
        QJniObject pm = context.callObjectMethod("getPackageManager", "()Landroid/content/pm/PackageManager;");
        if (!env.checkAndClearExceptions() && pm.isValid()) {
            const jboolean canInstall = pm.callMethod<jboolean>("canRequestPackageInstalls");
            if (!env.checkAndClearExceptions() && !canInstall) {
                qWarning() << "[Updater] Missing REQUEST_INSTALL_PACKAGES permission, opening settings.";
                setStatusMessage(QStringLiteral("Please allow app installation in Android settings."));

                QJniObject action = QJniObject::fromString(QStringLiteral("android.settings.MANAGE_UNKNOWN_APP_SOURCES"));
                QJniObject uriStr = QJniObject::fromString(QStringLiteral("package:") + packageName.toString());
                QJniObject pkgUri = QJniObject::callStaticObjectMethod(
                    "android/net/Uri", "parse",
                    "(Ljava/lang/String;)Landroid/net/Uri;",
                    uriStr.object<jstring>());

                QJniObject permIntent("android/content/Intent",
                                      "(Ljava/lang/String;Landroid/net/Uri;)V",
                                      action.object<jstring>(),
                                      pkgUri.object());
                const jint flagNewTask = 0x10000000;
                permIntent.callObjectMethod("addFlags", "(I)Landroid/content/Intent;", flagNewTask);
                context.callMethod<void>("startActivity", "(Landroid/content/Intent;)V", permIntent.object());
                env.checkAndClearExceptions();
                return;
            }
        }
        env.checkAndClearExceptions();
    }

    QJniObject filePathStr = QJniObject::fromString(m_updateFilePath);
    QJniObject javaFile("java/io/File", "(Ljava/lang/String;)V", filePathStr.object<jstring>());
    const QString authorityStr = packageName.toString() + QStringLiteral(".fileprovider");
    QJniObject authority = QJniObject::fromString(authorityStr);

    QJniObject contentUri = QJniObject::callStaticObjectMethod(
        "androidx/core/content/FileProvider",
        "getUriForFile",
        "(Landroid/content/Context;Ljava/lang/String;Ljava/io/File;)Landroid/net/Uri;",
        context.object(),
        authority.object<jstring>(),
        javaFile.object());

    if (env.checkAndClearExceptions() || !contentUri.isValid()) {
        qWarning() << "[Updater] FileProvider.getUriForFile failed. Check AndroidManifest.xml and file_paths.xml.";
        setStatusMessage(QStringLiteral("Failed to launch installer. Opening release page..."));
        if (!m_currentManifest.releasePage.isEmpty()) {
            QDesktopServices::openUrl(QUrl(m_currentManifest.releasePage));
        }
        return;
    }

    QJniObject intent("android/content/Intent", "()V");
    QJniObject actionView = QJniObject::getStaticObjectField(
        "android/content/Intent", "ACTION_VIEW", "Ljava/lang/String;");
    intent.callObjectMethod("setAction", "(Ljava/lang/String;)Landroid/content/Intent;", actionView.object());

    QJniObject mimeType = QJniObject::fromString(QStringLiteral("application/vnd.android.package-archive"));
    intent.callObjectMethod("setDataAndType",
                            "(Landroid/net/Uri;Ljava/lang/String;)Landroid/content/Intent;",
                            contentUri.object(),
                            mimeType.object<jstring>());

    const jint flagGrantRead = 0x00000001;
    const jint flagNewTask = 0x10000000;
    intent.callObjectMethod("addFlags", "(I)Landroid/content/Intent;", flagGrantRead | flagNewTask);

    context.callMethod<void>("startActivity", "(Landroid/content/Intent;)V", intent.object());
    if (env.checkAndClearExceptions()) {
        qWarning() << "[Updater] Failed to start installer activity.";
        setStatusMessage(QStringLiteral("Failed to start Android installer."));
    }
#else
    qDebug() << "[Updater] Opening update file on desktop:" << m_updateFilePath;
    QDesktopServices::openUrl(QUrl::fromLocalFile(m_updateFilePath));
#endif
}
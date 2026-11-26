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

#ifndef UPDATER_HPP
#define UPDATER_HPP

#include <QByteArray>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

#include <atomic>
#include <memory>

class QFile;
class QNetworkAccessManager;
class QNetworkReply;
class QTimer;

struct UpdatePlatformInfo {
    QString filetype;
    QString sha256;
    QStringList mirrors;
};

struct UpdateManifest {
    QString version;
    QString releasePage;
    QString changelog;
    QString type; // "release", "stable" or "test"
    UpdatePlatformInfo platformInfo;
    QByteArray rawJson;
    bool isValid = false;
};

class Updater : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString currentVersion READ currentVersion WRITE setCurrentVersion NOTIFY currentVersionChanged)
    Q_PROPERTY(QString newVersion READ newVersion NOTIFY newVersionChanged)
    Q_PROPERTY(QString changelog READ changelog NOTIFY changelogChanged)
    Q_PROPERTY(QString releasePage READ releasePage NOTIFY releasePageChanged)
    Q_PROPERTY(bool isChecking READ isChecking NOTIFY isCheckingChanged)
    Q_PROPERTY(bool isDownloading READ isDownloading NOTIFY isDownloadingChanged)
    Q_PROPERTY(qreal downloadProgress READ downloadProgress NOTIFY downloadProgressChanged)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY updateAvailableChanged)
    Q_PROPERTY(bool updateReady READ updateReady NOTIFY updateReadyChanged)
    Q_PROPERTY(QString updateFilePath READ updateFilePath NOTIFY updateFilePathChanged)
    Q_PROPERTY(bool hasCriticalError READ hasCriticalError NOTIFY hasCriticalErrorChanged)
    Q_PROPERTY(bool hasCache READ hasCache NOTIFY hasCacheChanged)
    Q_PROPERTY(int failureCount READ failureCount NOTIFY failureCountChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(QStringList manifestMirrors READ manifestMirrors WRITE setManifestMirrors NOTIFY manifestMirrorsChanged)
    Q_PROPERTY(bool receiveTestVersions READ receiveTestVersions WRITE setReceiveTestVersions NOTIFY receiveTestVersionsChanged)

public:
    explicit Updater(QObject* parent = nullptr);
    ~Updater() override;

    QString currentVersion() const;
    void setCurrentVersion(const QString& version);

    QString newVersion() const;
    QString changelog() const;
    QString releasePage() const;
    bool isChecking() const;
    bool isDownloading() const;
    qreal downloadProgress() const;
    bool updateAvailable() const;
    bool updateReady() const;
    QString updateFilePath() const;
    bool hasCriticalError() const;
    bool hasCache() const;
    int failureCount() const;
    QString statusMessage() const;
    QStringList manifestMirrors() const;
    void setManifestMirrors(const QStringList& mirrors);
    bool receiveTestVersions() const;
    Q_INVOKABLE void setReceiveTestVersions(bool enabled);

    Q_INVOKABLE void checkForUpdates();
    Q_INVOKABLE void checkForUpdatesFromUrl(const QString& url);
    Q_INVOKABLE void checkManifestData(const QString& jsonContent);
    Q_INVOKABLE void postponeUpdate();
    Q_INVOKABLE void installUpdate();
    Q_INVOKABLE void resetFailureCount();
    Q_INVOKABLE void cleanCache();
    Q_INVOKABLE static bool isVersionGreater(const QString& remoteVer, const QString& localVer);

signals:
    void currentVersionChanged();
    void newVersionChanged();
    void changelogChanged();
    void releasePageChanged();
    void isCheckingChanged();
    void isDownloadingChanged();
    void downloadProgressChanged();
    void updateAvailableChanged();
    void updateReadyChanged();
    void updateFilePathChanged();
    void hasCriticalErrorChanged();
    void hasCacheChanged();
    void failureCountChanged();
    void statusMessageChanged();
    void manifestMirrorsChanged();
    void receiveTestVersionsChanged();

    void updateCheckFinished(bool updateFound);
    void updateDownloadFinished(bool success);
    void criticalErrorThresholdReached();

private slots:
    void onManifestDataReady();
    void onManifestReplyFinished();
    void onDownloadDataReady();
    void onDownloadReplyFinished();
    void onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal);
    void onHashVerificationFinished();

private:
    enum class HashPurpose {
        None,
        CacheCheckOnline,
        CacheCheckOffline,
        DownloadedFile
    };

    struct HashResult {
        quint64 jobId = 0;
        bool matches = false;
    };

    void loadCurrentVersionFromLocalJson();
    void cleanupIfAlreadyUpdated();
    bool validateAndPruneCachedUpdate(bool requireValidCurrentVersion,
                                      UpdateManifest* outManifest = nullptr,
                                      QString* outPackagePath = nullptr);
    bool tryLoadCachedUpdate();
    bool saveCachedManifestJson(const QByteArray& jsonData) const;

    void fetchManifestFromNextMirror();
    UpdateManifest parseManifest(const QByteArray& data) const;
    void processManifest(const UpdateManifest& manifest);
    void startDownload();
    void downloadFromNextMirror();
    void scheduleNextDownloadAttempt(bool switchMirrorImmediately);

    void verifyFileSha256Async(const QString& filePath, const QString& expectedSha256, HashPurpose purpose);
    void cancelActiveOperations();
    void abortManifestReply();
    void abortDownloadReply();
    void closeTempFile();

    void cleanStaleTempFiles();
    void cleanCacheDir();
    bool pruneCacheExcept(const QStringList& keepPaths = {});
    static QStringList cacheFileFilters();
    QList<QFileInfo> updaterCacheEntries() const;
    QString legacyTempUpdaterDir() const;
    QString cacheDirectory() const;
    QString cachedManifestPath() const;
    QString targetFilePath(const QString& version, const QString& filetype) const;
    bool hasEnoughDiskSpace(const QString& dirPath, qint64 requiredBytes) const;

    void resetUpdateState();
    void setIsChecking(bool checking);
    void setIsDownloading(bool downloading);
    void setDownloadProgress(qreal progress);
    void setUpdateAvailable(bool available);
    void setUpdateReady(bool ready);
    void setUpdateFilePath(const QString& path);
    void setStatusMessage(const QString& message);

    void recordFailure(bool isNetworkUnavailable);
    void recordSuccess();

    QNetworkAccessManager* m_networkManager = nullptr;
    QNetworkReply* m_manifestReply = nullptr;
    QNetworkReply* m_downloadReply = nullptr;
    QFile* m_tempFile = nullptr;
    QTimer* m_retryTimer = nullptr;
    QFutureWatcher<HashResult>* m_hashWatcher = nullptr;

    QByteArray m_manifestBuffer;
    bool m_manifestTooLarge = false;

    QString m_tempFilePath;
    qint64 m_downloadedBytes = 0;
    bool m_diskWriteFailed = false;
    bool m_downloadTooLarge = false;
    bool m_checkedTotalSize = false;

    bool m_isVerifying = false;
    HashPurpose m_hashPurpose = HashPurpose::None;
    QString m_verifyingFilePath;
    quint64 m_currentHashJobId = 0;
    std::shared_ptr<std::atomic_bool> m_hashCancelFlag;

    QString m_currentVersion;
    UpdateManifest m_currentManifest;
    bool m_isChecking = false;
    bool m_isDownloading = false;
    qreal m_downloadProgress = 0.0;
    bool m_updateAvailable = false;
    bool m_updateReady = false;
    bool m_hasCriticalError = false;
    bool m_receiveTestVersions = false;
    int m_failureCount = 0;
    QString m_updateFilePath;
    QString m_statusMessage;

    QStringList m_manifestMirrors;
    QStringList m_activeManifestMirrors;
    int m_currentManifestMirrorIndex = 0;
    bool m_manifestHadNonNetworkFailure = false;
    bool m_manifestHadNetworkFailure = false;

    QStringList m_downloadMirrors;
    int m_currentDownloadMirrorIndex = 0;
    int m_currentMirrorFailCount = 0;

    static constexpr int MAX_FAILURES_PER_MIRROR = 5;
    static constexpr int CRITICAL_FAILURE_THRESHOLD = 100;
    static constexpr int MANIFEST_TIMEOUT_MS = 15000;
    static constexpr int DOWNLOAD_TIMEOUT_MS = 30000;
    static constexpr qint64 MAX_MANIFEST_BYTES = 1 * 1024 * 1024;          // 1 MiB
    static constexpr qint64 MAX_PACKAGE_BYTES = 300 * 1024 * 1024;         // 300 MiB
    static constexpr qint64 DOWNLOAD_READ_BUFFER_BYTES = 512 * 1024;       // 512 KiB
    static constexpr qint64 MIN_FREE_SPACE_BYTES = 50 * 1024 * 1024;       // 50 MiB
    static constexpr qint64 EXTRA_DISK_MARGIN_BYTES = 20 * 1024 * 1024;    // 20 MiB
};

#endif // UPDATER_HPP
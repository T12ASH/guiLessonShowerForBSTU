#ifndef UPDATER_HPP
#define UPDATER_HPP

#include <QObject>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QByteArray>
#include <QtQml/qqmlregistration.h>

class QNetworkAccessManager;
class QNetworkReply;
class QFile;

struct UpdatePlatformInfo {
    QString filetype;
    QString sha256;
    QStringList mirrors;
};

struct UpdateManifest {
    QString version;
    QString releasePage;
    QString changelog;
    QString type; // "release" or "test"
    UpdatePlatformInfo platformInfo;
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
    Q_PROPERTY(int failureCount READ failureCount NOTIFY failureCountChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(QStringList manifestMirrors READ manifestMirrors WRITE setManifestMirrors NOTIFY manifestMirrorsChanged)

public:
    explicit Updater(QObject *parent = nullptr);
    ~Updater() override;

    QString currentVersion() const;
    void setCurrentVersion(const QString &version);

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
    int failureCount() const;
    QString statusMessage() const;
    QStringList manifestMirrors() const;
    void setManifestMirrors(const QStringList &mirrors);

    Q_INVOKABLE void checkForUpdates();
    Q_INVOKABLE void checkForUpdatesFromUrl(const QString &url);
    Q_INVOKABLE void checkManifestData(const QString &jsonContent);
    Q_INVOKABLE void postponeUpdate();
    Q_INVOKABLE void installUpdate();
    Q_INVOKABLE void resetFailureCount();
    Q_INVOKABLE void cleanCache();
    Q_INVOKABLE static bool isVersionGreater(const QString &remoteVer, const QString &currentVer);

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
    void failureCountChanged();
    void statusMessageChanged();
    void manifestMirrorsChanged();

    void updateCheckFinished(bool updateFound);
    void updateDownloadFinished(bool success);
    void criticalErrorThresholdReached();

private slots:
    void onManifestReplyFinished();
    void onDownloadDataReady();
    void onDownloadReplyFinished();
    void onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal);

private:
    void fetchManifestFromNextMirror();
    UpdateManifest parseManifest(const QByteArray &data);
    void processManifest(const UpdateManifest &manifest);
    void startDownload();
    void downloadFromNextMirror();
    bool verifyFileSha256(const QString &filePath, const QString &expectedSha256);
    void cleanupOldUpdates(const QString &keepVersion = QString());
    QString cacheDirectory() const;
    QString targetFilePath(const QString &version, const QString &filetype) const;

    void recordFailure(bool isNetworkUnavailable);
    void recordSuccess();

    QNetworkAccessManager *m_networkManager = nullptr;
    QNetworkReply *m_manifestReply = nullptr;
    QNetworkReply *m_downloadReply = nullptr;
    QFile *m_tempFile = nullptr;
    QString m_tempFilePath;

    QString m_currentVersion = QStringLiteral("v1.0.0");
    UpdateManifest m_currentManifest;
    bool m_isChecking = false;
    bool m_isDownloading = false;
    qreal m_downloadProgress = 0.0;
    bool m_updateAvailable = false;
    bool m_updateReady = false;
    QString m_updateFilePath;
    QString m_statusMessage;

    QStringList m_manifestMirrors;
    int m_currentManifestMirrorIndex = 0;

    QStringList m_downloadMirrors;
    int m_currentDownloadMirrorIndex = 0;
    int m_currentMirrorFailCount = 0;

    static constexpr int MAX_FAILURES_PER_MIRROR = 5;
    static constexpr int CRITICAL_FAILURE_THRESHOLD = 100;
};

#endif // UPDATER_HPP

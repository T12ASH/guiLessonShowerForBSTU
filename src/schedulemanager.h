#ifndef SCHEDULEMANAGER_H
#define SCHEDULEMANAGER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QMap>
#include <QList>
#include <QtQml/qqmlregistration.h>

class QNetworkAccessManager;
class QNetworkReply;

struct LessonInfo {
    QString time;
    QString name;
    QString type;
    QString day;
    QString teacher;
    QString weekType;
    QString classRoom;
};

struct PeriodOption {
    QString value;
    QString label;
};

class ScheduleManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString group READ group WRITE setGroup NOTIFY groupChanged)
    Q_PROPERTY(QString period READ period WRITE setPeriod NOTIFY periodChanged)
    Q_PROPERTY(QString weekParity READ weekParity WRITE setWeekParity NOTIFY weekParityChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(bool isRefreshing READ isRefreshing NOTIFY isRefreshingChanged)
    Q_PROPERTY(bool isLoadingMeta READ isLoadingMeta NOTIFY isLoadingMetaChanged)
    Q_PROPERTY(bool hasMetaError READ hasMetaError NOTIFY hasMetaErrorChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(QString consoleOutput READ consoleOutput NOTIFY consoleOutputChanged)
    Q_PROPERTY(QVariantList scheduleDays READ scheduleDays NOTIFY scheduleChanged)
    Q_PROPERTY(QStringList availableGroups READ availableGroups NOTIFY availableGroupsChanged)
    Q_PROPERTY(QVariantList availablePeriods READ availablePeriods NOTIFY availablePeriodsChanged)
    Q_PROPERTY(bool hasSchedule READ hasSchedule NOTIFY scheduleChanged)
    Q_PROPERTY(bool isDebugBuild READ isDebugBuild CONSTANT)
    Q_PROPERTY(QString customIconUrl READ customIconUrl NOTIFY customIconUrlChanged)
    Q_PROPERTY(bool hasCustomIcon READ hasCustomIcon NOTIFY customIconUrlChanged)

public:
    explicit ScheduleManager(QObject *parent = nullptr);
    ~ScheduleManager() override;

    QString group() const { return m_group; }
    QString period() const { return m_period; }
    QString weekParity() const { return m_weekParity; }
    QString language() const { return m_language; }
    bool isRefreshing() const { return m_isRefreshing; }
    bool isLoadingMeta() const { return m_isLoadingMeta; }
    bool hasMetaError() const { return m_hasMetaError; }
    QString statusMessage() const { return m_statusMessage; }
    QString consoleOutput() const { return m_consoleOutput; }
    QVariantList scheduleDays() const { return m_scheduleDays; }
    QStringList availableGroups() const { return m_availableGroups; }
    QVariantList availablePeriods() const { return m_availablePeriods; }
    bool hasSchedule() const { return !m_allLessons.isEmpty(); }
    QString customIconUrl() const { return m_customIconUrl; }
    bool hasCustomIcon() const { return !m_customIconPath.isEmpty(); }
    bool isDebugBuild() const {
#ifdef QT_DEBUG
        return true;
#else
        return false;
#endif
    }

public slots:
    void setGroup(const QString &group);
    void setPeriod(const QString &period);
    void setWeekParity(const QString &parity);
    void setLanguage(const QString &lang);
    void refreshSchedule(bool silent = false);
    void onSettingsOpened();
    void fetchGroupsForPeriod(const QString &periodCode);
    QString calculateCurrentWeekParity() const;
    QString periodLabel(const QString &periodValue) const;
    QString detectFormForGroup(const QString &groupName) const;
    static QString defaultAcademicPeriod();

signals:
    void groupChanged();
    void periodChanged();
    void weekParityChanged();
    void languageChanged();
    void isRefreshingChanged();
    void isLoadingMetaChanged();
    void hasMetaErrorChanged();
    void statusMessageChanged();
    void consoleOutputChanged();
    void scheduleChanged();
    void availableGroupsChanged();
    void availablePeriodsChanged();
    void customIconUrlChanged();

private slots:
    void onReplyFinished();
    void onMetaPageFinished();

private:
    void findBaseDirectory();
    void checkCustomIcon();
    void loadInfo();
    void saveInfo();
    void loadCachedMeta();
    void saveCachedPeriods();
    void saveCachedGroups();
    void rebuildPeriodsVariantList();
    void loadScheduleFromFile();
    void saveScheduleToFile(const QString &content);
    void parseHtmlAndPopulate(const QString &html);
    void filterLessons();
    bool matchesParity(const QString &lessonWeekType, const QString &currentParity) const;
    void abortGroupReplies();

    QString m_group;
    QString m_period;
    QString m_weekParity;
    QString m_language;
    bool m_isRefreshing;
    bool m_isSilentRefresh;
    bool m_isLoadingMeta;
    bool m_hasMetaError;
    QString m_statusMessage;
    QString m_consoleOutput;
    QString m_customIconPath;
    QString m_customIconUrl;
    QString m_baseDir;

    QList<LessonInfo> m_allLessons;
    QVariantList m_scheduleDays;
    QStringList m_availableGroups;
    QMap<QString, QString> m_groupToForm;
    QList<PeriodOption> m_periodOptions;
    QVariantList m_availablePeriods;

    QNetworkAccessManager *m_netManager;
    QNetworkReply *m_currentReply;
    QNetworkReply *m_metaReply;
    QList<QNetworkReply*> m_groupReplies;
    QStringList m_pendingFetchedGroups;
};

#endif // SCHEDULEMANAGER_H
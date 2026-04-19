#pragma once

#include <QObject>
#include <QStringList>

class QmlObjectInspector : public QObject
{
    Q_OBJECT

public:
    explicit QmlObjectInspector(QObject *parent = nullptr);

    Q_INVOKABLE QString summary(QObject *object) const;
    Q_INVOKABLE QString objectPathString(QObject *object) const;
    Q_INVOKABLE QStringList formattedProperties(QObject *object) const;
    Q_INVOKABLE QStringList formattedMethods(QObject *object) const;
    Q_INVOKABLE QStringList formattedConstructors(QObject *object) const;
    Q_INVOKABLE QStringList childSummaries(QObject *object) const;
    Q_INVOKABLE bool hasProperty(QObject *object, const QString &name) const;
    Q_INVOKABLE QString propertyValue(QObject *object, const QString &name) const;
    Q_INVOKABLE QObject *objectProperty(QObject *object, const QString &name) const;
    Q_INVOKABLE bool writeProperty(QObject *object, const QString &name, const QVariant &value) const;
    Q_INVOKABLE int qmlTypeId(const QString &moduleUri, int versionMajor, int versionMinor, const QString &typeName) const;
    Q_INVOKABLE QStringList qmlTypeProperties(
        const QString &moduleUri,
        int versionMajor,
        int versionMinor,
        const QString &typeName) const;
    Q_INVOKABLE QStringList constructedTypeProperties(
        const QString &moduleUri,
        int versionMajor,
        int versionMinor,
        const QString &typeName) const;
    Q_INVOKABLE QObject *applicationObject(const QString &classNameNeedle, int index = 0) const;
    Q_INVOKABLE QObject *applicationObjectWithProperty(const QString &propertyName, int index = 0) const;
    Q_INVOKABLE QStringList applicationObjectMatches(
        const QStringList &classNameNeedles,
        int maxResults = 32) const;
    Q_INVOKABLE QStringList registeredTypeMatches(
        const QStringList &moduleUris,
        const QStringList &typeNames,
        int versionMajor,
        int versionMinor) const;

private:
    QString formatVariant(const QVariant &value) const;
    QStringList formatMetaObjectProperties(const QMetaObject *metaObject) const;
    QObject *constructQObject(const QMetaObject *metaObject) const;
};

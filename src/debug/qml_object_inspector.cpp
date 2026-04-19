#include "debug/qml_object_inspector.h"

#include <algorithm>
#include <QCoreApplication>
#include <QGuiApplication>
#include <QMetaMethod>
#include <QMetaProperty>
#include <QMetaType>
#include <QQueue>
#include <QSet>
#include <QVariant>
#include <QWindow>
#include <QtQml/qqml.h>

namespace
{
QString objectNameSuffix(const QObject *object)
{
    if (object == nullptr || object->objectName().isEmpty()) {
        return {};
    }

    return QStringLiteral(" (%1)").arg(object->objectName());
}

QString normalizedObjectName(const QObject *object)
{
    return object == nullptr ? QString() : object->objectName().trimmed();
}

int matchScore(const QObject *object, const QStringList &needles)
{
    if (object == nullptr) {
        return 0;
    }

    const QString className = QString::fromLatin1(object->metaObject()->className());
    const QString objectName = normalizedObjectName(object);

    for (const QString &needle : needles) {
        if (needle.isEmpty()) {
            continue;
        }

        if (className.compare(needle, Qt::CaseInsensitive) == 0
            || objectName.compare(needle, Qt::CaseInsensitive) == 0) {
            return 2;
        }
    }

    for (const QString &needle : needles) {
        if (needle.isEmpty()) {
            continue;
        }

        if (className.contains(needle, Qt::CaseInsensitive)
            || objectName.contains(needle, Qt::CaseInsensitive)) {
            return 1;
        }
    }

    return 0;
}

QString objectPath(const QObject *object)
{
    QStringList parts;

    for (const QObject *cursor = object; cursor != nullptr; cursor = cursor->parent()) {
        const QString className = QString::fromLatin1(cursor->metaObject()->className());
        const QString objectName = normalizedObjectName(cursor);
        parts.prepend(objectName.isEmpty()
                          ? className
                          : QStringLiteral("%1(%2)").arg(className, objectName));
    }

    return parts.join(QStringLiteral(" -> "));
}

QList<QObject *> applicationRoots()
{
    QList<QObject *> roots;
    QCoreApplication *application = QCoreApplication::instance();
    if (application == nullptr) {
        return roots;
    }

    roots.append(application);

    if (QGuiApplication *guiApplication = qobject_cast<QGuiApplication *>(application)) {
        const QList<QWindow *> topLevelWindows = guiApplication->topLevelWindows();
        for (QWindow *window : topLevelWindows) {
            if (window != nullptr && !roots.contains(window)) {
                roots.append(window);
            }
        }
    }

    return roots;
}

QList<QObject *> matchingApplicationObjects(const QStringList &needles)
{
    QList<QObject *> exactMatches;
    QList<QObject *> partialMatches;
    QQueue<QObject *> queue;
    QSet<const QObject *> visited;

    for (QObject *root : applicationRoots()) {
        if (root == nullptr || visited.contains(root)) {
            continue;
        }

        queue.enqueue(root);
        visited.insert(root);
    }

    while (!queue.isEmpty()) {
        QObject *object = queue.dequeue();
        const int score = matchScore(object, needles);
        if (score == 2) {
            exactMatches.append(object);
        } else if (score == 1) {
            partialMatches.append(object);
        }

        const QObjectList children = object->children();
        for (QObject *child : children) {
            if (child == nullptr || visited.contains(child)) {
                continue;
            }

            queue.enqueue(child);
            visited.insert(child);
        }
    }

    return exactMatches.isEmpty() ? partialMatches : exactMatches;
}

QList<QObject *> applicationObjectsWithProperty(const QString &propertyName)
{
    QList<QObject *> matches;
    if (propertyName.trimmed().isEmpty()) {
        return matches;
    }

    QQueue<QObject *> queue;
    QSet<const QObject *> visited;

    for (QObject *root : applicationRoots()) {
        if (root == nullptr || visited.contains(root)) {
            continue;
        }

        queue.enqueue(root);
        visited.insert(root);
    }

    const QByteArray propertyNameBytes = propertyName.toLatin1();

    while (!queue.isEmpty()) {
        QObject *object = queue.dequeue();

        if (object->metaObject()->indexOfProperty(propertyNameBytes.constData()) != -1) {
            matches.append(object);
        }

        const QObjectList children = object->children();
        for (QObject *child : children) {
            if (child == nullptr || visited.contains(child)) {
                continue;
            }

            queue.enqueue(child);
            visited.insert(child);
        }
    }

    return matches;
}
}

QmlObjectInspector::QmlObjectInspector(QObject *parent)
    : QObject(parent)
{
}

QString QmlObjectInspector::summary(QObject *object) const
{
    if (object == nullptr) {
        return QStringLiteral("<null>");
    }

    return QString::fromLatin1(object->metaObject()->className()) + objectNameSuffix(object);
}

QString QmlObjectInspector::objectPathString(QObject *object) const
{
    return objectPath(object);
}

QStringList QmlObjectInspector::formattedProperties(QObject *object) const
{
    QStringList lines;
    if (object == nullptr) {
        return lines;
    }

    const QMetaObject *metaObject = object->metaObject();
    for (int index = 0; index < metaObject->propertyCount(); ++index) {
        const QMetaProperty property = metaObject->property(index);
        const QVariant value = property.isReadable() ? property.read(object) : QVariant();
        const QString typeName = property.metaType().name()
            ? QString::fromLatin1(property.metaType().name())
            : QStringLiteral("unknown");
        lines.append(QStringLiteral("%1 (%2) = %3")
                         .arg(QString::fromLatin1(property.name()), typeName, formatVariant(value)));
    }

    return lines;
}

QStringList QmlObjectInspector::formattedMethods(QObject *object) const
{
    QStringList lines;
    if (object == nullptr) {
        return lines;
    }

    const QMetaObject *metaObject = object->metaObject();
    for (int index = metaObject->methodOffset(); index < metaObject->methodCount(); ++index) {
        const QMetaMethod method = metaObject->method(index);
        if (method.methodType() == QMetaMethod::Constructor) {
            continue;
        }

        QStringList parameterNames;
        const QList<QByteArray> parameterTypeNames = method.parameterTypes();
        for (const QByteArray &parameterTypeName : parameterTypeNames) {
            parameterNames.append(QString::fromLatin1(parameterTypeName));
        }

        QString methodTypeName;
        switch (method.methodType()) {
        case QMetaMethod::Signal:
            methodTypeName = QStringLiteral("signal");
            break;
        case QMetaMethod::Slot:
            methodTypeName = QStringLiteral("slot");
            break;
        case QMetaMethod::Method:
            methodTypeName = QStringLiteral("method");
            break;
        case QMetaMethod::Constructor:
            methodTypeName = QStringLiteral("constructor");
            break;
        }

        lines.append(QStringLiteral("%1 %2(%3) -> %4")
                         .arg(
                             methodTypeName,
                             QString::fromLatin1(method.name()),
                             parameterNames.join(QStringLiteral(", ")),
                             QString::fromLatin1(method.typeName() ? method.typeName() : "void")));
    }

    return lines;
}

QStringList QmlObjectInspector::formattedConstructors(QObject *object) const
{
    QStringList lines;
    if (object == nullptr) {
        return lines;
    }

    const QMetaObject *metaObject = object->metaObject();
    for (int index = 0; index < metaObject->constructorCount(); ++index) {
        const QMetaMethod constructor = metaObject->constructor(index);
        QStringList parameterNames;
        const QList<QByteArray> parameterTypeNames = constructor.parameterTypes();
        for (const QByteArray &parameterTypeName : parameterTypeNames) {
            parameterNames.append(QString::fromLatin1(parameterTypeName));
        }

        lines.append(QStringLiteral("constructor %1(%2)")
                         .arg(QString::fromLatin1(constructor.name()), parameterNames.join(QStringLiteral(", "))));
    }

    return lines;
}

QStringList QmlObjectInspector::childSummaries(QObject *object) const
{
    QStringList lines;
    if (object == nullptr) {
        return lines;
    }

    const QObjectList children = object->children();
    for (QObject *child : children) {
        lines.append(summary(child));
    }

    return lines;
}

bool QmlObjectInspector::hasProperty(QObject *object, const QString &name) const
{
    if (object == nullptr) {
        return false;
    }

    return object->metaObject()->indexOfProperty(name.toLatin1().constData()) != -1;
}

QString QmlObjectInspector::propertyValue(QObject *object, const QString &name) const
{
    if (object == nullptr) {
        return QStringLiteral("<null>");
    }

    const int propertyIndex = object->metaObject()->indexOfProperty(name.toLatin1().constData());
    if (propertyIndex == -1) {
        return QStringLiteral("<missing>");
    }

    return formatVariant(object->metaObject()->property(propertyIndex).read(object));
}

QObject *QmlObjectInspector::objectProperty(QObject *object, const QString &name) const
{
    if (object == nullptr) {
        return nullptr;
    }

    const int propertyIndex = object->metaObject()->indexOfProperty(name.toLatin1().constData());
    if (propertyIndex == -1) {
        return nullptr;
    }

    const QVariant value = object->metaObject()->property(propertyIndex).read(object);
    return value.canConvert<QObject *>() ? value.value<QObject *>() : nullptr;
}

bool QmlObjectInspector::writeProperty(QObject *object, const QString &name, const QVariant &value) const
{
    if (object == nullptr) {
        return false;
    }

    const QByteArray propertyName = name.toLatin1();
    const int propertyIndex = object->metaObject()->indexOfProperty(propertyName.constData());
    if (propertyIndex == -1) {
        return false;
    }

    const QMetaProperty property = object->metaObject()->property(propertyIndex);
    if (!property.isWritable()) {
        return false;
    }

    QVariant coercedValue = value;
    if (coercedValue.metaType() != property.metaType() && !coercedValue.convert(property.metaType())) {
        return false;
    }

    return property.write(object, coercedValue);
}

int QmlObjectInspector::qmlTypeId(
    const QString &moduleUri,
    int versionMajor,
    int versionMinor,
    const QString &typeName) const
{
    return ::qmlTypeId(
        moduleUri.toUtf8().constData(),
        versionMajor,
        versionMinor,
        typeName.toUtf8().constData());
}

QStringList QmlObjectInspector::qmlTypeProperties(
    const QString &moduleUri,
    int versionMajor,
    int versionMinor,
    const QString &typeName) const
{
    const int typeId = qmlTypeId(moduleUri, versionMajor, versionMinor, typeName);
    if (typeId == -1) {
        return {};
    }

    const QMetaType metaType(typeId);
    return formatMetaObjectProperties(metaType.metaObject());
}

QStringList QmlObjectInspector::constructedTypeProperties(
    const QString &moduleUri,
    int versionMajor,
    int versionMinor,
    const QString &typeName) const
{
    const int typeId = qmlTypeId(moduleUri, versionMajor, versionMinor, typeName);
    if (typeId == -1) {
        return {QStringLiteral("Type is not registered.")};
    }

    const QMetaType metaType(typeId);
    const QMetaObject *metaObject = metaType.metaObject();
    if (metaObject == nullptr) {
        return {QStringLiteral("Type has no metaobject.")};
    }

    QObject *object = constructQObject(metaObject);
    if (object == nullptr) {
        return {
            QStringLiteral("Metaobject: %1").arg(QString::fromLatin1(metaObject->className())),
            QStringLiteral("C++ construction failed.")
        };
    }

    QStringList lines;
    lines.append(QStringLiteral("Constructed: %1").arg(summary(object)));
    lines.append(formattedProperties(object));
    delete object;
    return lines;
}

QObject *QmlObjectInspector::applicationObject(const QString &classNameNeedle, int index) const
{
    if (index < 0 || classNameNeedle.trimmed().isEmpty()) {
        return nullptr;
    }

    const QList<QObject *> matches = matchingApplicationObjects({classNameNeedle});
    return index < matches.size() ? matches.at(index) : nullptr;
}

QObject *QmlObjectInspector::applicationObjectWithProperty(const QString &propertyName, int index) const
{
    if (index < 0 || propertyName.trimmed().isEmpty()) {
        return nullptr;
    }

    const QList<QObject *> matches = applicationObjectsWithProperty(propertyName);
    return index < matches.size() ? matches.at(index) : nullptr;
}

QStringList QmlObjectInspector::applicationObjectMatches(
    const QStringList &classNameNeedles,
    int maxResults) const
{
    QStringList lines;
    if (maxResults <= 0) {
        return lines;
    }

    const QList<QObject *> matches = matchingApplicationObjects(classNameNeedles);
    const int resultCount = std::min(maxResults, matches.size());

    for (int index = 0; index < resultCount; ++index) {
        QObject *object = matches.at(index);
        lines.append(QStringLiteral("%1: %2 | %3")
                         .arg(index)
                         .arg(summary(object), objectPath(object)));
    }

    return lines;
}

QStringList QmlObjectInspector::registeredTypeMatches(
    const QStringList &moduleUris,
    const QStringList &typeNames,
    int versionMajor,
    int versionMinor) const
{
    QStringList lines;

    for (const QString &moduleUri : moduleUris) {
        for (const QString &typeName : typeNames) {
            const int typeId = qmlTypeId(moduleUri, versionMajor, versionMinor, typeName);
            if (typeId == -1) {
                continue;
            }

            lines.append(QStringLiteral("%1 %2.%3 :: %4 => %5")
                             .arg(moduleUri)
                             .arg(versionMajor)
                             .arg(versionMinor)
                             .arg(typeName)
                             .arg(typeId));
        }
    }

    return lines;
}

QStringList QmlObjectInspector::formatMetaObjectProperties(const QMetaObject *metaObject) const
{
    QStringList lines;
    if (metaObject == nullptr) {
        return lines;
    }

    for (int index = 0; index < metaObject->propertyCount(); ++index) {
        const QMetaProperty property = metaObject->property(index);
        const QString typeName = property.metaType().name()
            ? QString::fromLatin1(property.metaType().name())
            : QStringLiteral("unknown");
        const QString requiredPrefix = property.isRequired()
            ? QStringLiteral("required ")
            : QString();
        lines.append(QStringLiteral("%1%2 (%3)")
                         .arg(requiredPrefix, QString::fromLatin1(property.name()), typeName));
    }

    return lines;
}

QString QmlObjectInspector::formatVariant(const QVariant &value) const
{
    if (!value.isValid()) {
        return QStringLiteral("<unavailable>");
    }

    if (value.canConvert<QObject *>()) {
        return summary(value.value<QObject *>());
    }

    if (value.typeId() == QMetaType::QStringList) {
        return QStringLiteral("[%1]").arg(value.toStringList().join(QStringLiteral(", ")));
    }

    if (value.canConvert<QVariantList>()) {
        const QVariantList list = value.toList();
        QStringList renderedValues;
        renderedValues.reserve(list.size());
        for (const QVariant &entry : list) {
            renderedValues.append(formatVariant(entry));
        }
        return QStringLiteral("[%1]").arg(renderedValues.join(QStringLiteral(", ")));
    }

    const QString text = value.toString();
    if (!text.isEmpty()) {
        return text;
    }

    return QString::fromLatin1(value.metaType().name());
}

QObject *QmlObjectInspector::constructQObject(const QMetaObject *metaObject) const
{
    if (metaObject == nullptr) {
        return nullptr;
    }

    if (QObject *object = metaObject->newInstance()) {
        return object;
    }

    if (QObject *object = metaObject->newInstance(Q_ARG(QObject *, nullptr))) {
        return object;
    }

    return nullptr;
}

#pragma once

#include <QObject>
#include <QSize>
#include <QString>
#include <QUrl>

/// Turns a photo on disk into a grayscale haptic texture for QTSprite.
///
/// QTSprite stores friction = 255 - gray, so by default a dark pixel feels rough and a
/// bright pixel feels slick. Setting `inverted` flips the source first, so bright pixels
/// are the ones you feel.
class HapticImage : public QObject
{
	Q_OBJECT
	Q_PROPERTY(QString photoUrl READ photoUrl NOTIFY loaded)
	Q_PROPERTY(QString textureUrl READ textureUrl NOTIFY loaded)
	Q_PROPERTY(QSize textureSize READ textureSize NOTIFY loaded)
	Q_PROPERTY(QString error READ error NOTIFY loaded)
	Q_PROPERTY(bool inverted READ inverted WRITE setInverted NOTIFY invertedChanged)

public:
	explicit HapticImage(QObject* parent = nullptr);

	/// Load a photo and write its haptic texture to the temp dir. Returns false on failure,
	/// in which case error() explains why.
	Q_INVOKABLE bool load(const QUrl& fileUrl);

	QString photoUrl() const { return m_photoUrl; }
	QString textureUrl() const { return m_textureUrl; }
	QSize textureSize() const { return m_textureSize; }
	QString error() const { return m_error; }

	bool inverted() const { return m_inverted; }
	void setInverted(bool inverted);

signals:
	void loaded();
	void invertedChanged();

private:
	bool rebuildTexture();

	QString m_sourcePath;
	QString m_photoUrl;
	QString m_textureUrl;
	QString m_error;
	QSize m_textureSize;
	bool m_inverted = false;
};

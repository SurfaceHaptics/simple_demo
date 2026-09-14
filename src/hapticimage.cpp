#include "hapticimage.h"

#include <QDateTime>
#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QImage>
#include <QScreen>
#include <QStandardPaths>

namespace {

/// Texture resolution is capped to the screen: the Engine samples one texel per screen
/// unit, so anything finer is uploaded for nothing (a phone photo is ~12 MP).
QSize hapticTextureCap()
{
	if (const QScreen* screen = QGuiApplication::primaryScreen())
		return screen->geometry().size();
	return QSize(1920, 1080);
}

} // namespace

HapticImage::HapticImage(QObject* parent) : QObject(parent) {}

bool HapticImage::load(const QUrl& fileUrl)
{
	const QString path = fileUrl.isLocalFile() ? fileUrl.toLocalFile() : fileUrl.toString();
	if (!QFileInfo::exists(path)) {
		m_error = QStringLiteral("File not found: %1").arg(path);
		m_photoUrl.clear();
		m_textureUrl.clear();
		emit loaded();
		return false;
	}

	m_sourcePath = path;
	m_photoUrl = QUrl::fromLocalFile(path).toString();
	return rebuildTexture();
}

void HapticImage::setInverted(bool inverted)
{
	if (m_inverted == inverted)
		return;
	m_inverted = inverted;
	emit invertedChanged();
	if (!m_sourcePath.isEmpty())
		rebuildTexture();
}

bool HapticImage::rebuildTexture()
{
	QImage img;
	if (!img.load(m_sourcePath)) {
		m_error = QStringLiteral("Could not decode image: %1").arg(m_sourcePath);
		m_textureUrl.clear();
		emit loaded();
		return false;
	}

	QImage gray = img.convertToFormat(QImage::Format_Grayscale8);

	const QSize cap = hapticTextureCap();
	if (gray.width() > cap.width() || gray.height() > cap.height())
		gray = gray.scaled(cap, Qt::KeepAspectRatio, Qt::SmoothTransformation);

	if (m_inverted)
		gray.invertPixels();

	const QString dir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
	const QString outPath = dir + QStringLiteral("/tanvas_photo_haptics.png");

	// Write to a sibling then rename, so the Engine never sees a half-written file.
	const QString tmpPath = outPath + QStringLiteral(".tmp");
	if (!gray.save(tmpPath, "PNG")) {
		m_error = QStringLiteral("Could not write haptic texture to %1").arg(tmpPath);
		m_textureUrl.clear();
		emit loaded();
		return false;
	}
	QFile::remove(outPath);
	if (!QFile::rename(tmpPath, outPath)) {
		m_error = QStringLiteral("Could not replace %1").arg(outPath);
		m_textureUrl.clear();
		emit loaded();
		return false;
	}

	// Qt caches images by URL, so a reload of the same path would serve the stale texture
	// and the haptics would never change. The timestamp defeats that.
	m_textureUrl = QUrl::fromLocalFile(outPath).toString()
	               + QStringLiteral("?t=%1").arg(QDateTime::currentMSecsSinceEpoch());
	m_textureSize = gray.size();
	m_error.clear();

	qInfo() << "haptic texture" << m_textureSize << "from" << m_sourcePath
	        << (m_inverted ? "(inverted)" : "");
	emit loaded();
	return true;
}

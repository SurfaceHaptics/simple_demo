#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>

#include "hapticimage.h"

int main(int argc, char* argv[])
{
	QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
	// Taps on QML Controls synthesize mouse clicks on a touchscreen.
	QCoreApplication::setAttribute(Qt::AA_SynthesizeMouseForUnhandledTouchEvents);
	QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
		Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);

	QGuiApplication app(argc, argv);
	QCoreApplication::setOrganizationName(QStringLiteral("Tanvas"));
	QCoreApplication::setOrganizationDomain(QStringLiteral("tanvas.co"));
	QCoreApplication::setApplicationName(QStringLiteral("PhotoFeel"));

	// Declared before the engine so it outlives it: on shutdown the engine tears down
	// bindings that still reference this object.
	HapticImage hapticImage;

	QQmlApplicationEngine engine;

	// co.tanvas.tanvastouch is deployed next to the exe by deploy-sdk.ps1.
	const QString appDir = QCoreApplication::applicationDirPath();
	engine.addImportPath(appDir);
	engine.addImportPath(appDir + QStringLiteral("/archdatadir/qml"));
	QCoreApplication::addLibraryPath(appDir + QStringLiteral("/archdatadir/plugins"));

	engine.rootContext()->setContextProperty(QStringLiteral("hapticImage"), &hapticImage);

	const QUrl url(QStringLiteral("qrc:/main.qml"));
	QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
	                 [url](QObject* obj, const QUrl& objUrl) {
		                 if (!obj && url == objUrl)
			                 QCoreApplication::exit(-1);
	                 },
	                 Qt::QueuedConnection);
	engine.load(url);

	return app.exec();
}

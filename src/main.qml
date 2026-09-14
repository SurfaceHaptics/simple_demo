import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs 1.3
import co.tanvas.tanvastouch 1.0

ApplicationWindow {
	id: win
	visible: true
	width: 1280
	height: 800
	title: qsTr("Tanvas Photo Feel")
	color: "#101014"

	// Screen-space rect of the *painted* photo. The Engine samples the sprite as
	// UV = (touch - sprite_pos) / sprite_size, so if this rect does not match the pixels
	// on screen the photo feels shifted or stretched relative to what you see.
	property rect photoScreenRect: Qt.rect(0, 0, 0, 0)

	function updatePhotoScreenRect() {
		if (photo.status !== Image.Ready || photo.paintedWidth <= 0 || photo.paintedHeight <= 0) {
			photoScreenRect = Qt.rect(0, 0, 0, 0)
			return
		}
		// PreserveAspectFit letterboxes inside the item, so offset to the painted area.
		var local = photo.mapToGlobal((photo.width - photo.paintedWidth) / 2,
		                              (photo.height - photo.paintedHeight) / 2)
		photoScreenRect = Qt.rect(local.x, local.y, photo.paintedWidth, photo.paintedHeight)
	}

	// mapToGlobal is not a bindable expression, so recompute whenever anything that
	// feeds it moves.
	onXChanged: updatePhotoScreenRect()
	onYChanged: updatePhotoScreenRect()
	onWidthChanged: updatePhotoScreenRect()
	onHeightChanged: updatePhotoScreenRect()

	header: ToolBar {
		Row {
			anchors.left: parent.left
			anchors.leftMargin: 12
			anchors.verticalCenter: parent.verticalCenter
			spacing: 12

			Button {
				text: qsTr("Open photo…")
				onClicked: fileDialog.open()
			}

			Switch {
				text: qsTr("Invert")
				checked: hapticImage.inverted
				onToggled: hapticImage.inverted = checked
			}

			Switch {
				id: previewSwitch
				text: qsTr("Show haptic map")
				checked: false
			}

			Label {
				anchors.verticalCenter: parent.verticalCenter
				color: hapticImage.error !== "" ? "#ff6b6b" : "#a0a0a8"
				text: hapticImage.error !== ""
					? hapticImage.error
					: (hapticImage.textureUrl === ""
						? qsTr("Open a photo, then touch the panel.")
						: qsTr("%1 × %2").arg(hapticImage.textureSize.width)
						                 .arg(hapticImage.textureSize.height))
			}
		}
	}

	Image {
		id: photo
		anchors.fill: parent
		fillMode: Image.PreserveAspectFit
		asynchronous: true
		// The grayscale texture and the colour photo have the same aspect ratio, so
		// swapping between them does not move the haptic rect.
		source: previewSwitch.checked ? hapticImage.textureUrl : hapticImage.photoUrl

		onPaintedWidthChanged: win.updatePhotoScreenRect()
		onPaintedHeightChanged: win.updatePhotoScreenRect()
		onStatusChanged: win.updatePhotoScreenRect()
	}

	Label {
		anchors.centerIn: parent
		visible: hapticImage.photoUrl === ""
		color: "#6a6a72"
		font.pixelSize: 20
		text: qsTr("Drop a photo here, or use “Open photo…”")
	}

	DropArea {
		anchors.fill: parent
		onDropped: {
			if (drop.hasUrls && drop.urls.length > 0)
				hapticImage.load(drop.urls[0])
		}
	}

	FileDialog {
		id: fileDialog
		title: qsTr("Choose a photo")
		folder: shortcuts.pictures
		nameFilters: [qsTr("Images (*.png *.jpg *.jpeg *.bmp *.gif)"), qsTr("All files (*)")]
		onAccepted: hapticImage.load(fileDialog.fileUrl)
	}

	// The haptic scene. One view over the painted photo, one sprite filling it.
	QTView {
		id: hapticView
		parent: win.contentItem
		z: -1
		x: win.photoScreenRect.x
		y: win.photoScreenRect.y
		width: win.photoScreenRect.width
		height: win.photoScreenRect.height
		// Only drive the panel when this window is in front and a texture is loaded.
		enabled: win.active
			&& photo.status === Image.Ready
			&& hapticImage.textureUrl !== ""
			&& win.photoScreenRect.width > 0

		sprites: [
			QTSprite {
				hapticSource: hapticImage.textureUrl
				x: 0
				y: 0
				// Bind to the rect, not to hapticView.width/height: QTView's geometry
				// properties have no NOTIFY signal, so those bindings would never update.
				width: Math.max(1, win.photoScreenRect.width)
				height: Math.max(1, win.photoScreenRect.height)
			}
		]
	}
}

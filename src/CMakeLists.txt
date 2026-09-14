add_executable(PhotoFeel WIN32
	main.cpp
	hapticimage.cpp
	hapticimage.h
	qml.qrc
)

target_compile_definitions(PhotoFeel PRIVATE
	QT_DISABLE_DEPRECATED_BEFORE=0x060000
)

target_link_libraries(PhotoFeel PUBLIC
	Qt5::Quick
	Qt5::QuickControls2
)

install(TARGETS PhotoFeel
	RUNTIME DESTINATION bin
	COMPONENT PhotoFeel
)

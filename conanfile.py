from conans import ConanFile, CMake
from conans.tools import os_info, vcvars
import os

# Qt comes from Conan Center; the TanvasTouch QML plugin is not a build dependency.
# It is copied next to the exe at deploy time by deploy-sdk.ps1.


class PhotoFeelConan(ConanFile):
    name = "PhotoFeel"
    version = "0.0.0-dev"
    license = "Proprietary"
    author = "Tanvas Inc. <software@tanvas.co>"
    description = "Minimal TanvasTouch demo: load a photo and feel it."
    settings = "os", "compiler", "build_type", "arch"
    generators = "cmake", "cmake_find_package_multi", "virtualenv"
    options = {
        "use_tanvas_remotes": [True, False],
    }
    default_options = {
        "qt:qtdeclarative": True,
        "qt:qtquickcontrols": True,   # QtQuick.Dialogs 1.3 (FileDialog) lives here
        "qt:qtquickcontrols2": True,
        "qt:shared": True,
        "qt:with_freetype": False,  # Use Qt bundled freetype (avoids Conan freetype -> zlib/bzip2 LNK2019)
        "qt:with_libpng": False,  # Patched recipe uses -qt-libpng (bundled). Required for PNG/JPEG loading.
        "use_tanvas_remotes": False,
    }
    exports_sources = "*"
    keep_imports = True
    no_copy_source = True

    def building_for_windows(self):
        return os_info.is_windows and self.settings.compiler == "Visual Studio"

    def build_requirements(self):
        if self.options.use_tanvas_remotes:
            self.build_requires("qt/[~5.15.2]", force_host_context=True)
            self.build_requires("qttanvastouch/3.0.4-dev.2@Tanvas/testing", force_host_context=True)
        else:
            self.build_requires("qt/5.15.2", force_host_context=True)

    def build(self):
        with vcvars(self.settings):
            cmake = self.configure_cmake()
            cmake.build()

    def configure_cmake(self):
        with vcvars(self.settings):
            cmake = CMake(self)
            cmake.configure()
            return cmake

    def run_windeployqt(self):
        dist_dir = os.path.join(self.build_folder, 'dist')
        os.makedirs(dist_dir)
        exe = os.path.join('bin', 'PhotoFeel.exe')
        self.run('windeployqt --qmldir="{qmldir}" --qmlimport="{qmldir}" --dir="{dist_dir}" "{exe}"'.format(
            qmldir=self.source_folder,
            dist_dir=dist_dir,
            exe=exe),
            run_environment=True)

    def deploy(self):
        self.copy('*', dst='bin', src='bin')

    def package(self):
        with vcvars(self.settings):
            cmake = self.configure_cmake()
            cmake.install()
            if self.building_for_windows():
                self.run_windeployqt()
                self.copy('*', dst='bin', src='dist')
                if self.options.use_tanvas_remotes:
                    self.copy('*', dst='bin/co/tanvas/tanvastouch', src='bin/co/tanvas/tanvastouch')

    def imports(self):
        self.copy('*.dll', dst='bin', src='bin')
        if self.options.use_tanvas_remotes:
            self.copy('qmldir', dst='bin/co/tanvas/tanvastouch', src='bin/co/tanvas/tanvastouch',
                      root_package='qttanvastouch')

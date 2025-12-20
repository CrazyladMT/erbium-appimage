#!/bin/bash -e

# Builds an AppImage using appimagetool.
# You need to run this inside of a build directory in the source tree,
# it will generate the build files and compile Minetest for you.

# This script should be run on Debian 11 Bullseye.

# COMPILE LUAJIT
pushd luajit
make amalg -j4
popd

pushd erbium
mkdir -p build; cd build

# Download appimagetool
if [ ! -f appimagetool ]; then
	# Old version of appimagetool:
	#wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
	wget https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
	chmod +x appimagetool
fi

# Compile and install into AppDir
cmake .. -G Ninja \
	-DCMAKE_BUILD_TYPE=RelWithDebInfo \
	-DCMAKE_INSTALL_PREFIX=AppDir/usr \
	-DBUILD_UNITTESTS=OFF \
	-DENABLE_SYSTEM_JSONCPP=OFF \
	-DLUA_INCLUDE_DIR=../../luajit/src/ \
	-DLUA_LIBRARY=../../luajit/src/libluajit.a
ninja

objcopy --only-keep-debug ../bin/erbium erbium.debug
objcopy --strip-debug --add-gnu-debuglink=erbium.debug ../bin/erbium

ninja install

cp ../../../misc/erbium-xorg-icon-128.png AppDir/usr/share/icons/hicolor/128x128/apps/erbium.png

cd AppDir

cat > usr/share/applications/org.erbium.erbium.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Erbium
Exec=usr/bin/erbium
Icon=erbium
Categories=Game;
Terminal=false
EOF

# Put desktop and icon at root
ln -sf usr/share/applications/org.erbium.erbium.desktop erbium.desktop
ln -sf usr/share/icons/hicolor/128x128/apps/erbium.png erbium.png
ln -sf erbium.png .DirIcon

# Fix locales
mv usr/share/locale usr/share/erbium

cat > AppRun <<\APPRUN
#!/bin/sh
APP_PATH="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${APP_PATH}"/usr/lib/:"${LD_LIBRARY_PATH}"
exec "${APP_PATH}/usr/bin/erbium" "$@"
APPRUN
chmod +x AppRun

# List of libraries from the system that should be bundled in the AppImage.
INCLUDE_LIBS=(
	libopenal.so.1
	 libsndio.so.7.0
	  libbsd.so.0
	   libmd.so.0
	libjpeg.so.62
	libpng16.so.16
	libvorbisfile.so.3
	 libogg.so.0
	 libvorbis.so.0
	libzstd.so.1
	libsqlite3.so.0
	libleveldb.so.1d
	 libsnappy.so.1
)

mkdir -p usr/lib/
for i in "${INCLUDE_LIBS[@]}"; do
	cp /usr/lib/x86_64-linux-gnu/$i usr/lib/
done

# Copy our own built SDL2
cp /usr/lib/libSDL2-2.0.so.0 usr/lib/

# Actually build the appimage
cd ..
ARCH=x86_64 ./appimagetool --appimage-extract-and-run AppDir/

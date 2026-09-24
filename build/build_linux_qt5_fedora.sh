#!/bin/sh

# Build LiteIDE on Fedora with the distribution's Qt 5 packages.
# Fedora installs qmake as qmake-qt5 and has no qtchooser, so
# build_linux_qt5.sh does not work there. See ../build.md.
#
# Prerequisites:
#   sudo dnf install gcc-c++ make git libtool \
#       qt5-qtbase-devel qt5-qtsvg-devel qt5-qttools-devel qt5-linguist
#   ./update_pkg.sh   (installs gocode, gotools, gomodifytags, gopls)

export BUILD_ROOT="$PWD"

if [ -z "$LITEIDE_ROOT" ]; then
	export LITEIDE_ROOT="$PWD/../liteidex"
fi

if [ -z "$QMAKE" ]; then
	if [ -n "$QTDIR" ] && [ -x "$QTDIR/bin/qmake" ]; then
		QMAKE="$QTDIR/bin/qmake"
	else
		QMAKE=qmake-qt5
	fi
fi

echo build liteide
echo GOROOT=$GOROOT
echo BUILD_ROOT=$BUILD_ROOT
echo LITEIDE_ROOT=$LITEIDE_ROOT
echo QMAKE=$QMAKE
echo .

if ! command -v "$QMAKE" >/dev/null 2>&1; then
	echo "error, $QMAKE not found, install qt5-qtbase-devel"
	exit 1
fi

if ! "$QMAKE" -query QT_VERSION | grep -q '^5\.'; then
	echo "error, $QMAKE is not Qt 5"
	exit 1
fi

# qmake must run out-of-source: liteidex/src/3rdparty/libvterm contains a
# tracked upstream Makefile that would shadow the qmake-generated one.
echo qmake liteide ...
echo .
"$QMAKE" "$LITEIDE_ROOT" -spec linux-g++ "CONFIG+=release"

if [ $? -ge 1 ]; then
	echo 'error, qmake fail'
	exit 1
fi

echo make liteide ...
echo .
make -j"$(nproc)"

if [ $? -ge 1 ]; then
	echo 'error, make fail'
	exit 1
fi

go version
if [ $? -ge 1 ]; then
	echo 'error, not find go in PATH'
	exit 1
fi

echo build liteide tools ...
cd "$LITEIDE_ROOT" || exit 1

for tool in gotools gocode gomodifytags gopls; do
	if [ ! -x "bin/$tool" ]; then
		echo "warning, bin/$tool not found, run ./update_pkg.sh first"
	fi
done

echo export qrc images
go run src/tools/exportqrc/main.go -root .

if [ $? -ge 1 ]; then
	echo 'error, go run fail'
	exit 1
fi

echo deploy ...

cd "$BUILD_ROOT" || exit 1

rm -rf liteide
mkdir -p liteide
mkdir -p liteide/bin
mkdir -p liteide/share/liteide
mkdir -p liteide/lib/liteide/plugins

cp -a -v "$LITEIDE_ROOT/LICENSE.LGPL" liteide
cp -a -v "$LITEIDE_ROOT/LGPL_EXCEPTION.TXT" liteide
cp -a -v "$LITEIDE_ROOT/../README.md" liteide
cp -a -v "$LITEIDE_ROOT/../CONTRIBUTORS" liteide
cp -a -v "$LITEIDE_ROOT/liteide.desktop" liteide
cp -a -v "$LITEIDE_ROOT/install-icon.sh" liteide

cp -a -v "$LITEIDE_ROOT/liteide/bin/liteide" liteide/bin
for tool in gotools gocode gomodifytags gopls; do
	if [ -x "$LITEIDE_ROOT/bin/$tool" ]; then
		cp -a -v "$LITEIDE_ROOT/bin/$tool" liteide/bin
	fi
done
cp -a -v "$LITEIDE_ROOT"/liteide/lib/liteide/libliteapp.* liteide/lib/liteide
cp -a -v "$LITEIDE_ROOT"/liteide/lib/liteide/plugins/*.so liteide/lib/liteide/plugins

cp -r -v "$LITEIDE_ROOT"/deploy/* liteide/share/liteide/
cp -r -v "$LITEIDE_ROOT"/os_deploy/linux/* liteide/share/liteide/

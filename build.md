# Building LiteIDE on Fedora 39 (x86_64)

Build instructions for this machine, adapted from
[`liteidex/deploy/welcome/en/install.md`](liteidex/deploy/welcome/en/install.md).
The generic Linux instructions there assume Ubuntu (`qt5-default`, `qtchooser`),
which do not exist on Fedora; the steps below work around that.

Verified on 2026-09-24 with:

| Component | Version                                   |
|-----------|-------------------------------------------|
| OS        | Fedora 39, kernel 6.10, x86_64            |
| Qt        | **Qt 5.15.14** (`qmake-qt5`, Fedora RPMs) |
| Compiler  | GCC 13.3.1 (`gcc-c++`)                    |
| Go        | go1.24.1 (`/opt/go`)                      |

To check the Qt version yourself: `qmake-qt5 -query QT_VERSION`.
(Qt 6.6 runtime libraries are also installed, but not the Qt 6 development
packages, so the build uses Qt 5.)

## 1. Prerequisites

```sh
sudo dnf install gcc-c++ make git libtool \
    qt5-qtbase-devel qt5-qtsvg-devel qt5-qttools-devel qt5-linguist
```

Go must be on `PATH` (`go version`). A recent Go is required because
`update_pkg.sh` installs `gopls@latest`.

Optional: `qt5-qtwebkit-devel` is only used if you build with
`DEFINES+=LITEIDE_QTWEBKIT` (the `webkithtmlwidget` plugin); the default build
does not need it.

## 2. Build

Use `build/build_linux_qt5_fedora.sh`. It is a Fedora variant of
`build_linux_qt5.sh`, which fails here because Fedora installs qmake as
`qmake-qt5` and has no `qtchooser`.

From the repository root:

```sh
cd build

# Install the Go helper tools (gocode, gotools, gomodifytags, gopls)
# into liteidex/bin. Needs network access. Only needed once, or to update them.
./update_pkg.sh

# Build LiteIDE and assemble build/liteide/
./build_linux_qt5_fedora.sh
```

A full build takes a few minutes. The script:

- uses `qmake-qt5` and checks that it really is Qt 5;
- runs `make -j$(nproc)`;
- warns if a Go helper tool is missing (run `./update_pkg.sh`) and skips it;
- assembles the self-contained `build/liteide/` directory.

Environment variables (all optional):

| Variable       | Default               | Purpose                                   |
|----------------|-----------------------|-------------------------------------------|
| `QMAKE`        | `qmake-qt5`           | qmake binary to use                       |
| `QTDIR`        | (unset)               | Use `$QTDIR/bin/qmake` (e.g. a Qt SDK)    |
| `LITEIDE_ROOT` | `../liteidex`         | LiteIDE source tree                       |

Example with a Qt 5 SDK instead of the Fedora packages:

```sh
QTDIR=$HOME/Qt/5.15.2/gcc_64 ./build_linux_qt5_fedora.sh
```

### Alternative: the generic `build_linux.sh`

`build_linux.sh` calls plain `qmake`, so it also works with a `qmake` shim
on `PATH`:

```sh
mkdir -p ~/.local/qt5bin
ln -sf /usr/bin/qmake-qt5 ~/.local/qt5bin/qmake
PATH="$HOME/.local/qt5bin:$PATH" MAKEFLAGS="-j$(nproc)" ./build_linux.sh
```

It prints two harmless messages: `rm: cannot remove 'liteide'` (first build
only) and `cp: cannot stat '.../liteidex/install_icon.sh'` (the file is named
`install-icon.sh`). The Fedora script has neither.

> **Do not run qmake inside `liteidex/`** (in-source build). The bundled
> `liteidex/src/3rdparty/libvterm` contains a tracked upstream `Makefile` that
> takes precedence over the qmake-generated one, so `liblibvterm.a` is never
> built and linking fails with `cannot find -llibvterm`. Always build from
> `build/` (as the scripts do) or from another out-of-source directory.

## 3. Run

```sh
cd build/liteide/bin
./liteide
```

The binary uses an `$ORIGIN`-relative rpath for its own libraries and the
system Qt 5 in `/lib64`, so no `LD_LIBRARY_PATH` is needed.

GLib warnings such as `GFileInfo created without standard::icon` on startup
are harmless.

Note: running headless with `QT_QPA_PLATFORM=offscreen` crashes at startup
(null clipboard data in `TerminalEdit::cursorPositionChanged`); use a real
X11/Wayland session.

## 4. Install (optional)

`build/liteide/` is self-contained apart from the system Qt 5 libraries, and
finds its libraries and data relative to the executable, so it can be moved
anywhere.

### System-wide in `/opt/liteide`

From the repository root, after a successful build:

```sh
# Copy the bundle (replaces a previous install)
sudo rm -rf /opt/liteide
sudo cp -a build/liteide /opt/liteide
sudo chown -R root:root /opt/liteide

# Put liteide on PATH for all users
sudo ln -sf /opt/liteide/bin/liteide /usr/local/bin/liteide

# Desktop menu entry
sudo mkdir -p /usr/local/share/applications
sudo tee /usr/local/share/applications/liteide.desktop >/dev/null <<'EOF'
[Desktop Entry]
Type=Application
Name=LiteIDE
Comment=IDE for editing and building projects written in the Go programming language
Exec=/opt/liteide/bin/liteide
Icon=/opt/liteide/share/liteide/welcome/images/liteide128.xpm
Terminal=false
StartupNotify=false
Categories=Development;IDE;
EOF
sudo update-desktop-database /usr/local/share/applications
```

Then start it with `liteide` from a terminal, or from the desktop menu.
User settings are stored in `~/.config/liteide/`, not in `/opt/liteide`, so
the install directory can stay read-only.

To upgrade, rebuild and repeat the first block (`rm -rf` + `cp -a`).

To uninstall:

```sh
sudo rm -rf /opt/liteide /usr/local/bin/liteide \
    /usr/local/share/applications/liteide.desktop
sudo update-desktop-database /usr/local/share/applications
```

### Per user, without root

```sh
mkdir -p ~/.local/opt ~/.local/bin
rm -rf ~/.local/opt/liteide
cp -a build/liteide ~/.local/opt/liteide
ln -sf ~/.local/opt/liteide/bin/liteide ~/.local/bin/liteide
```

The `deploy_linux_x64_qt5.sh` script is **not** needed (and does not work
as-is on Fedora): it bundles Qt libraries from the Debian path
`/usr/lib/x86_64-linux-gnu`, whereas Fedora keeps them in `/usr/lib64`.

## Rebuilding / cleaning

Incremental rebuild after source changes:

```sh
cd build
./build_linux_qt5_fedora.sh
```

Full clean (generated Makefiles and objects in `build/`, outputs in
`liteidex/liteide/`):

```sh
cd build && make distclean
rm -rf liteide ../liteidex/liteide
```

## Alternative: Qt 6

There is also `build/build_linux_qt6.sh`. To use it, install
`qt6-qtbase-devel qt6-qtsvg-devel qt6-qt5compat-devel qt6-qttools-devel`,
point the shim at `/usr/bin/qmake6` instead of `qmake-qt5`, and run that
script. This path has not been tested on this machine.

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

## 2. Make `qmake` point to Qt 5

Fedora installs qmake as `qmake-qt5` and has no `qtchooser`, so
`build_linux_qt5.sh` fails (`qmake not found` / `qtchooser: not found`).
Use `build_linux.sh` instead, which calls plain `qmake`, and provide a
`qmake` shim on `PATH`:

```sh
mkdir -p ~/.local/qt5bin
ln -sf /usr/bin/qmake-qt5 ~/.local/qt5bin/qmake
```

(Only prepend it to `PATH` for the build, see below, so it does not affect
other projects.)

## 3. Build

From the repository root:

```sh
cd build

# Install the Go helper tools (gocode, gotools, gomodifytags, gopls)
# into liteidex/bin. Needs network access.
./update_pkg.sh

# Build LiteIDE and assemble build/liteide/
PATH="$HOME/.local/qt5bin:$PATH" MAKEFLAGS="-j$(nproc)" ./build_linux.sh
```

A full build takes a few minutes with `-j8`.

Two messages printed by `build_linux.sh` are harmless:

- `rm: cannot remove 'liteide': No such file or directory` (first build only)
- `cp: cannot stat '.../liteidex/install_icon.sh'` (the file is named
  `install-icon.sh`; it is just not copied into the bundle)

> **Do not run qmake inside `liteidex/`** (in-source build). The bundled
> `liteidex/src/3rdparty/libvterm` contains a tracked upstream `Makefile` that
> takes precedence over the qmake-generated one, so `liblibvterm.a` is never
> built and linking fails with `cannot find -llibvterm`. Always build from
> `build/` (as the script does) or from another out-of-source directory.

## 4. Run

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

## 5. Install (optional)

`build/liteide/` is self-contained apart from the system Qt 5 libraries. Copy
it wherever you like, e.g.:

```sh
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
PATH="$HOME/.local/qt5bin:$PATH" MAKEFLAGS="-j$(nproc)" ./build_linux.sh
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

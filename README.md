# dsh-linux-appimage

Linux AppImage packaging for **DeepSeek Harness `0.2.1-rc.5`**.

The upstream `dsh-v0.2.1-rc.5` tag only ships macOS/Windows packaging targets. This
repository contains the local Linux packaging work as one apply-on-top patch plus a
build script, so a fresh upstream checkout can produce the same Linux AppImage:

```
deepseek-harness-0.2.1-rc.5-linux-x64-unsigned.AppImage
```

## Base

| Item | Value |
|---|---|
| Upstream repo | https://github.com/deepseek-ai/deepseek-harness |
| Tag | `dsh-v0.2.1-rc.5` |
| Commit | `b830ec950faba0a46dda564be3e2d854afed94f1` |
| Patch | `patches/linux-appimage-rc.5.patch` (64 files) |
| Reference artifact sha256 | `4b4e70bb5959c61dfc48caaecc04b3a02144287ea12509663e4842e235834229` |

The reference sha256 is from the build used to produce this patch. A rebuild is
functionally identical (`--dsh-cli --version` = `0.2.1-rc.5`), but electron-builder
timestamps can make the AppImage bytes differ.

## Quick start

```bash
git clone https://github.com/deepseek-ai/deepseek-harness.git
git -C deepseek-harness checkout dsh-v0.2.1-rc.5

# Applies the patch, installs, builds and packages.
/path/to/dsh-linux-appimage/scripts/build.sh deepseek-harness
```

The artifact is copied to `deepseek-harness/dist/` and verified with
`--dsh-cli --version`.

To apply the patch without building:

```bash
/path/to/dsh-linux-appimage/scripts/build.sh deepseek-harness --apply-only
```

The script requires an exact `dsh-v0.2.1-rc.5` checkout. It refuses a dirty worktree,
and it skips the apply step if the patch is already applied.

## Manual build

```bash
git clone https://github.com/deepseek-ai/deepseek-harness.git
cd deepseek-harness
git checkout dsh-v0.2.1-rc.5

git apply --binary --whitespace=nowarn /path/to/patches/linux-appimage-rc.5.patch

pnpm install --frozen-lockfile
pnpm run build
pnpm package:desktop:linux:x64:unsigned
```

Artifact:

```
apps/desktop/.desktop-build/targets/linux-x64/unsigned-artifacts/
  deepseek-harness-0.2.1-rc.5-linux-x64-unsigned.AppImage
```

## Requirements

- Linux x64 (the target is an x64 AppImage).
- Node.js: the harness requires `^22.19.0 || >=24.0.0`; this build was produced with
  Node `26.7.0` and the AppImage runtime carries Node `24.21.0`.
- pnpm `11.28.5` (the upstream `packageManager` pin).
- Network access for npm packages, Electron `44.7.0`, the Node runtime and pnpm.
- `tar` and a working FUSE setup to run the AppImage (building does not need FUSE).

### Proxy

The build downloads through `fetch` and `@electron/get`. If a proxy is required:

```bash
export HTTP_PROXY=http://127.0.0.1:7897
export HTTPS_PROXY=http://127.0.0.1:7897
export NODE_USE_ENV_PROXY=1
export ELECTRON_GET_USE_PROXY=true
export GLOBAL_AGENT_HTTP_PROXY="$HTTP_PROXY"
export GLOBAL_AGENT_HTTPS_PROXY="$HTTPS_PROXY"
```

`build.sh` sets `NODE_USE_ENV_PROXY` and `ELECTRON_GET_USE_PROXY` by default and
derives the `GLOBAL_AGENT_*` values from `HTTP(S)_PROXY` when unset.

## What the patch changes

- `apps/desktop`: Linux packaging support, including `package-target.ts`,
  electron-builder config, tray icon, `.env.linux.example`, docs and tests.
- Root `package.json`: `package:desktop:linux:x64[:unsigned|:dir]` and
  `upload:linux:x64[:latest]` scripts.
- `packages/credentials/deepseek-account`: accept `linux` in the desktop platform
  headers (`x-client-platform: desktop-linux`).
- `patches/@deepseek-ai__libreoffice-kit@0.1.5.patch` plus `pnpm-workspace.yaml` and
  `pnpm-lock.yaml` entries: on Linux, LibreOfficeKit reaches its WASM fallback instead
  of failing on an ASAR existence probe.
- Version moved to `0.2.1-rc.5` in `apps/desktop/package.json`.

This is vanilla `0.2.1-rc.5` plus Linux packaging. It does **not** include the
workspace recycle-bin feature or other local 0.2.2 work.

## Verification

The reference build passed:

- `pnpm run build`: 9/9 gates.
- `pnpm package:desktop:linux:x64:unsigned`: packaging smoke tests for offline plugin
  install/remove, `dsh web`, and DOCX/XLSX/PPTX→PDF.
- `deepseek-harness-0.2.1-rc.5-linux-x64-unsigned.AppImage --dsh-cli --version` →
  `0.2.1-rc.5`.

## License

The patch is derived from the MIT-licensed DeepSeek Harness source. See `LICENSE`.

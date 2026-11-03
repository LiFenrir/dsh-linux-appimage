#!/usr/bin/env bash
# Apply the Linux AppImage packaging patch to an upstream dsh 0.2.1-rc.5 checkout and build.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH="$ROOT_DIR/patches/linux-appimage-rc.5.patch"
BASE_TAG="dsh-v0.2.1-rc.5"
BASE_COMMIT="b830ec950faba0a46dda564be3e2d854afed94f1"
TARGET="${1:-}"
MODE="${2:-}"

usage() {
  echo "usage: $0 <deepseek-harness-checkout> [--apply-only]" >&2
  echo "  The checkout must be at tag $BASE_TAG ($BASE_COMMIT)." >&2
  exit 2
}

[[ -n "$TARGET" ]] || usage
[[ -z "$MODE" || "$MODE" == "--apply-only" ]] || usage
TARGET="$(cd "$TARGET" && pwd)"

git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "error: not a git checkout: $TARGET" >&2
  exit 1
}

HEAD="$(git -C "$TARGET" rev-parse HEAD)"
if [[ "$HEAD" != "$BASE_COMMIT" ]]; then
  echo "error: expected HEAD $BASE_COMMIT ($BASE_TAG), got $HEAD" >&2
  echo "checkout the base first: git -C \"$TARGET\" checkout $BASE_TAG" >&2
  exit 1
fi

if git -C "$TARGET" apply --reverse --check --binary "$PATCH" >/dev/null 2>&1; then
  echo "patch already applied; skipping"
else
  if [[ -n "$(git -C "$TARGET" status --porcelain)" ]]; then
    echo "error: target worktree is not clean; commit or stash changes first" >&2
    git -C "$TARGET" status --short >&2
    exit 1
  fi
  echo "applying $PATCH"
  git -C "$TARGET" apply --binary --whitespace=nowarn "$PATCH"
fi

if [[ "$MODE" == "--apply-only" ]]; then
  echo "patch applied (apply-only); build skipped"
  exit 0
fi

command -v node >/dev/null 2>&1 || { echo "error: node is not on PATH" >&2; exit 1; }
command -v pnpm >/dev/null 2>&1 || { echo "error: pnpm is not on PATH (expected pnpm 11.28.5)" >&2; exit 1; }
echo "building with node $(node -v) and pnpm $(pnpm -v)"

# Node fetch and @electron/get need explicit proxy switches; global-agent covers Electron.
export NODE_USE_ENV_PROXY="${NODE_USE_ENV_PROXY:-1}"
export ELECTRON_GET_USE_PROXY="${ELECTRON_GET_USE_PROXY:-true}"
if [[ -n "${HTTPS_PROXY:-}" && -z "${GLOBAL_AGENT_HTTPS_PROXY:-}" ]]; then
  export GLOBAL_AGENT_HTTPS_PROXY="$HTTPS_PROXY"
fi
if [[ -n "${HTTP_PROXY:-}" && -z "${GLOBAL_AGENT_HTTP_PROXY:-}" ]]; then
  export GLOBAL_AGENT_HTTP_PROXY="$HTTP_PROXY"
fi

cd "$TARGET"
pnpm install --frozen-lockfile
pnpm run build
pnpm package:desktop:linux:x64:unsigned

IMAGE="$TARGET/apps/desktop/.desktop-build/targets/linux-x64/unsigned-artifacts/deepseek-harness-0.2.1-rc.5-linux-x64-unsigned.AppImage"
[[ -f "$IMAGE" ]] || { echo "error: AppImage not found: $IMAGE" >&2; exit 1; }

OUT_DIR="${OUT_DIR:-$TARGET/dist}"
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/$(basename "$IMAGE")"
cp -f "$IMAGE" "$OUT"

echo "--- verify"
env -u ELECTRON_RUN_AS_NODE "$OUT" --dsh-cli --version
sha256sum "$OUT"
echo "artifact: $OUT"

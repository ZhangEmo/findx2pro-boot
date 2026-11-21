#!/usr/bin/env bash
# Local build script (Ubuntu 20.04/22.04) for the same result as the GitHub Actions workflow.
# Usage:
#   1. Put the kernel source, toolchains and this package side by side, or edit the paths below.
#   2. bash build_kernel.sh
set -e

# ---------- Edit these paths ----------
KERNEL_DIR=${KERNEL_DIR:-"$PWD/kernel"}
ASSETS=${ASSETS:-"$PWD"}
TC=${TC:-"$PWD/toolchain"}
CLANG_PATH="$TC/clang/bin"
CROSS_COMPILE="$TC/gcc64/bin/aarch64-linux-android-"
CROSS_COMPILE_ARM32="$TC/gcc32/bin/arm-linux-androideabi-"
CLANG_TRIPLE="aarch64-linux-gnu-"
DEFCONFIG=${DEFCONFIG:-stock_defconfig}
JOBS=${JOBS:-$(nproc)}
KSU_BRANCH=${KSU_BRANCH:-legacy}
# Python 2 is EOL and absent on modern distros; the kernel Makefile invokes
# "python2" via scripts/gcc-wrapper.py. Add a shim if missing.
command -v python2 >/dev/null 2>&1 || {
  echo "[+] Creating python2 -> python3 shim (sudo required once)"
  sudo tee /usr/local/bin/python2 >/dev/null <<'PYEOF'
#!/bin/sh
exec python3 "$@"
PYEOF
  sudo chmod +x /usr/local/bin/python2
}

# ---------- Sanity checks ----------
for d in "$KERNEL_DIR" "$CLANG_PATH" "$TC/gcc64/bin" "$TC/gcc32/bin"; do
  [ -e "$d" ] || { echo "Missing: $d"; exit 1; }
done

cd "$KERNEL_DIR"

# 1. Droidspaces non-GKI patches
for p in "$ASSETS"/patches/droidspaces/*.patch; do
  echo "[+] Applying $p"
  patch -p1 --forward < "$p"
done

# 2. KernelSU-Next (legacy / non-GKI)
curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s "$KSU_BRANCH"

# 3. Build
export ARCH=arm64
export PATH="$CLANG_PATH:$PATH"
MAKE_ARGS="O=$PWD/out ARCH=arm64 CC=clang CROSS_COMPILE=$CROSS_COMPILE CROSS_COMPILE_ARM32=$CROSS_COMPILE_ARM32 CLANG_TRIPLE=$CLANG_TRIPLE KCFLAGS=-Wno-error"

mkdir -p out
make -j"$JOBS" $MAKE_ARGS vendor/$DEFCONFIG
cat "$ASSETS/configs/droidspaces.config" >> out/.config
make -j"$JOBS" $MAKE_ARGS olddefconfig
make -j"$JOBS" $MAKE_ARGS

echo "[+] Kernel image: $KERNEL_DIR/out/arch/arm64/boot/Image"

# 4. Pack AnyKernel3 (optional)
if [ -d "$ASSETS/AnyKernel3" ]; then
  cp out/arch/arm64/boot/Image "$ASSETS/AnyKernel3/Image"
  cp "$ASSETS/scripts/anykernel.sh" "$ASSETS/AnyKernel3/anykernel.sh"
  (cd "$ASSETS/AnyKernel3" && zip -r9 ../FindX2Pro-Droidspaces-KSU-kernel.zip . -x '*.git*' README.md)
  echo "[+] Flashable zip: $ASSETS/FindX2Pro-Droidspaces-KSU-kernel.zip"
fi

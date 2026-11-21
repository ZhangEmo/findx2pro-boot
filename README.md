# Find X2 Pro (PDEM30) — Droidspaces + KernelSU-Next 内核编译包

针对 **OPPO Find X2 Pro，ColorOS 13.1，固件 PDEM30_13.1.0.193(CN01)，当前内核 4.19.157-perf+** 的编译配置与自动化脚本。

## 关键结论

- 你的内核是 **4.19.157，非 GKI（non-GKI）内核**。Droidspaces 对非 GKI 内核只需「开启配置 + 打两个补丁」，**不需要** GKI 那套 kABI 填充补丁（那是 5.4+ 才需要的）。
- 匹配的内核源码是 [`jacid233/android_kernel_oplus_sm8250`](https://github.com/jacid233/android_kernel_oplus_sm8250) 的 **`oss-t` 分支**：Makefile 正好是 4.19.157，README 说明是官方开源的 ColorOS 13 内核整理版、Find X2 / Ace2 通用，defconfig 为 `arch/arm64/configs/vendor/stock_defconfig`。
  - 注意：官方 [`oppo-source/kernel_msm-4.19`](https://github.com/oppo-source/kernel_msm-4.19) 的 `find-x2-r` 分支只有 4.19.110，与你的 .157 不符，不要用。
- Root 方案：官方 KernelSU 从 v1.0 起放弃非 GKI 支持（最后支持版 v0.9.5）；本包改用专为此维护的 **KernelSU-Next `legacy` 分支**（明确支持 4.19 的非 GKI 内核，走 kprobe 自动集成）。

## 目录结构

```
.
├── configs/droidspaces.config      # Droidspaces 必备 + 推荐内核选项（含 KSU kprobe 选项）
├── patches/droidspaces/
│   ├── 01.fix_kernel_panic_in_xt_qtaguid.patch
│   └── 02.fix_restore_cgroup_file_prefix_handling.patch
├── scripts/
│   ├── build_kernel.sh             # 本地 Ubuntu 编译脚本
│   └── anykernel.sh                # AnyKernel3 刷机脚本
└── .github/workflows/build.yml     # GitHub Actions 云编译工作流（手动触发）
```

## 云编译（推荐，GitHub Actions）

1. 在 GitHub 新建一个**公开**仓库（私有仓库的 Actions 免费额度受限）。
2. 把本目录里的所有文件（包括隐藏的 `.github` 目录）上传到仓库根目录。
3. 打开仓库 → **Actions** → 找到 `Build Find X2 Pro Droidspaces + KernelSU-Next kernel` → **Run workflow**。
4. 等待编译完成（通常 15–30 分钟），在本次运行的 **Artifacts** 里下载 `FindX2Pro-Droidspaces-KSU-kernel.zip`。
5. 手机解锁 Bootloader 后，在第三方 Recovery（如 pomelohan 的 ColorOS 13 TWRP）中刷入该 zip；或解出 `Image` 后用 fastboot / 第三方工具刷入 boot。

> 工作流使用 `ubuntu-22.04`、`clang-r383902b1` + GCC 4.9，与官方 ColorOS 13 sm8250 内核的编译工具链一致。编译后脚本会校验关键 CONFIG 是否真的生效，缺任何一个都会让工作流失败，避免产出不可用内核。

## 本地编译（Ubuntu 20.04/22.04）

```bash
# 1. 安装依赖
sudo apt-get install -y build-essential flex bison libssl-dev libelf-dev bc zip curl git ccache python2 python3

# 2. 准备目录（与本包同级）
git clone -b oss-t https://github.com/jacid233/android_kernel_oplus_sm8250.git kernel
mkdir -p toolchain && cd toolchain
curl -L -o clang.tar.gz https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android13-release/clang-r383902b1.tar.gz
mkdir clang && tar -xzf clang.tar.gz -C clang
git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git gcc64
git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git gcc32
cd ..

# 3. 编译（自动打补丁 + 集成 KSU-Next）
bash scripts/build_kernel.sh
```

产物为 `kernel/out/arch/arm64/boot/Image`；若同目录放置 AnyKernel3，还会自动打出 `FindX2Pro-Droidspaces-KSU-kernel.zip`。

## 刷入后验收

1. 开机后安装 KernelSU-Next 管理器（从 [KernelSU-Next Releases](https://github.com/KernelSU-Next/KernelSU-Next/releases) 下载），确认显示「已安装 / Root 可用」。
2. 安装 Droidspaces 用户空间与 App，打开 App → **设置 → 要求 → 检查要求**，「必须」和「推荐」下所有项都应通过。
3. 如果某些网络相关项为红色，确认内核命令行没有 `cgroup_disable=` 之类的禁用参数（ColorOS 原厂通常没有）。

## 风险提示

- 刷自定义内核需要解锁 Bootloader，**有变砖和数据丢失风险**，请先备份。
- Droidspaces 官方不支持非 GKI 设备的所有功能；4.19 上 systemd 容器请选用 systemd < 258 的发行版（如 Debian 12/13、Alpine）。
- 如果集成 KernelSU-Next 后无法开机，多为该内核 kprobe 损坏：把 `configs/droidspaces.config` 里的 `CONFIG_KSU=y`、kprobe 相关选项删除后重新编译，或改用 KernelSU-Next 文档中的「手动修改内核源码」方式。

## 参考

- [Droidspaces 内核配置文档（中文）](https://github.com/ravindu644/droidspaces-oss/blob/main/Documentation/zh-CN/Kernel-Configuration.md)
- [Droidspaces 已支持设备列表](https://github.com/ravindu644/droidspaces-oss/blob/main/Documentation/community-supported-devices.md)
- [KernelSU-Next 非 GKI 集成指南](https://kernelsu-next.github.io/webpage/pages/how-to-integrate-for-non-gki.html)
- [jacid233/android_kernel_oplus_sm8250（oss-t 分支说明）](https://github.com/jacid233/android_kernel_oplus_sm8250)

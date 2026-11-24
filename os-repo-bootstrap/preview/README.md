# Anne's OS

A Debian 13 ("trixie")–based Linux distribution whose single goal is to **run every
socrtwo program, in some version, on every device the author owns** — PCs, Raspberry Pi,
Windows (WSL/VM), macOS (VM), Android, iOS, and in a browser.

> **Status: metadata and roadmap only. No code yet.**

## Why a distribution and not a new OS

Writing a kernel and driver stack is out of scope; it does not get the programs running
sooner. Debian supplies the kernel, drivers, and both target architectures (amd64 and
arm64). This project adds:

1. **Compatibility layers** that cover every language and runtime in the socrtwo
   portfolio (see [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md)).
2. **An app catalog** that installs each socrtwo repository as a native package, PWA,
   AppImage/Flatpak, Wine bottle, or Android APK.
3. **One build pipeline that emits a native artifact for each platform**
   (see [docs/PLATFORMS.md](docs/PLATFORMS.md)).

## Platform targets

| Target | Artifact | Mode | Fidelity |
|---|---|---|---|
| PC hardware (x86-64) | Hybrid ISO + Calamares installer | Bare metal / dual boot | Full |
| ARM64 UEFI hardware | Generic arm64 ISO | Bare metal | Full |
| Raspberry Pi 4 / 5 / 400 / 500 | `.img.xz` for Raspberry Pi Imager | Bare metal | Full |
| Windows 10/11 | WSL2 distro (`.wsl`) + Hyper-V `.vhdx` | Subsystem / VM | Full (WSLg GUI) |
| macOS (Apple Silicon & Intel) | UTM bundle (`.utm`) + raw `qcow2` | VM | Full, virtualized |
| Android 7+ | Termux `proot-distro` rootfs + Termux:X11 | Userspace container | Partial (no Waydroid/Wine-x86 speed) |
| Android 15+ (AVF-capable devices) | Debian VM image for the Linux Terminal app | VM | Near-full (to be validated) |
| iOS / iPadOS | UTM SE image (emulated) + iSH CLI rootfs | Emulation | Low (slow, no JIT) |
| Browser — "virtually online" | Cloud image with KasmVNC (full) + WebVM/CheerpX i386 image (lite) | Remote desktop / in-browser VM | Full / Lite |
| Containers & cloud | OCI image, cloud-init `qcow2`, AWS AMI | Container / VM | Headless + web desktop |

**iOS:** Apple does not allow third-party kernels or general-purpose
hypervisors on iPhone or iPad. On iOS the project will only ever offer emulation (UTM SE)
or the browser edition. Treat iOS support as best-effort.

## Claude build-cost estimate (summary)

Both estimates assume agentic development with Claude Code at **medium effort**:
about 480 PR-sized tasks before rework, prompt caching on, and API list prices as of
2026-11.

| Model (medium effort) | Tasks incl. rework | API cost — expected | Range | Agent hours | Your review hours | Calendar (solo, ~3 h/day) |
|---|---|---|---|---|---|---|
| **Claude Opus 5.5** | ~647 | **~$4,440** | $3,000 – $6,700 | ~270 | ~108 | **11 – 16 weeks** |
| **Claude Fable 5.2** | ~551 | **~$6,840** | $4,600 – $10,300 | ~275 | ~64 | **8 – 12 weeks** |

The full method, assumptions, and a per-workstream breakdown are in
[docs/COST-ESTIMATE.md](docs/COST-ESTIMATE.md).

## Roadmap

See [ROADMAP.md](ROADMAP.md). Each phase is a GitHub milestone.

## Repository layout (planned)

```
build/        mmdebstrap rootfs recipes, per-target packers (ISO, RPi, WSL, UTM, OCI, …)
layers/       compatibility layers: wine/, waydroid/, runtimes/
catalog/      one recipe per socrtwo app (YAML) → .deb / PWA / Flatpak / Wine bottle / APK
desktop/      shell, theming, first-run wizard, settings, updater
tests/        QEMU boot + app smoke tests (openQA-style)
docs/         design docs
meta/         machine-readable project metadata
```

## License

To be decided before the first code commit. The default plan is GPL-2.0-or-later for
build tooling, with each catalog app keeping its own upstream license.

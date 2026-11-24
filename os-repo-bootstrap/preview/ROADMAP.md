# Roadmap

Every phase ends in an artifact you can test. Week numbers are **calendar weeks for the
Opus 5.5 medium plan**; the Fable 5.2 column is the compressed equivalent. Phases overlap
where dependencies allow.

| Phase | Name | Opus 5.5 wk | Fable 5.2 wk | Exit criterion |
|---|---|---|---|---|
| 0 | Foundations | 1 | 1 | CI builds an empty Debian rootfs for amd64 + arm64 on each push |
| 1 | Base image | 2–3 | 1–2 | Bootable amd64 ISO and arm64 image boot to a desktop in QEMU |
| 2 | Compatibility layers | 3–6 | 2–4 | Wine, Waydroid and all runtimes pass the smoke-test matrix |
| 3 | App catalog | 4–9 | 3–7 | All 71 socrtwo repos install and launch (or are marked N/A with reason) |
| 4 | Platform delivery | 6–12 | 4–9 | Every row in the README platform table produces a signed artifact |
| 5 | Desktop, updater, first-run | 8–13 | 6–10 | Fresh install → updates → app install with no terminal needed |
| 6 | QA, hardening, signing | 10–15 | 7–11 | Automated boot/app tests green on all targets; SBOM published |
| 7 | 1.0 release | 15–16 | 11–12 | Release notes, website, download page, install guides per platform |

---

## Phase 0 — Foundations
- Repo conventions, CODEOWNERS, issue/PR templates, label set.
- GitHub Actions matrix: `amd64` (ubuntu-latest) and `arm64` (ubuntu-24.04-arm) runners.
- `mmdebstrap` recipe for a minimal trixie rootfs, cached as a CI artifact.
- Decide and record: desktop (default **KDE Plasma 6**; XFCE as the "lite" variant for
  Pi 4, Termux, and the web edition), init (systemd), package format for catalog (deb first).
- ADR log under `docs/adr/`.

## Phase 1 — Base image
- Shared rootfs → per-arch layers (kernel, firmware, Mesa, PipeWire, NetworkManager).
- amd64 hybrid ISO (BIOS + UEFI) with live session and the Calamares installer.
- arm64 UEFI ISO (for generic ARM boards and VMs).
- Branding: os-release, Plymouth, GRUB theme, wallpaper.
- QEMU boot test in CI (headless, screenshot diff).

## Phase 2 — Compatibility layers
| Layer | Covers |
|---|---|
| Node 22 LTS + Electron/Tauri runtime + local PWA host | ~50 HTML/JS/TS repos (Anne's Office suite, recovery tools, bots) |
| Python 3.13 (+ venv per app), PHP 8.x + local web server, Perl 5 | annes-keep, VPN-Follower, KJB-LLM, Common-Ground, whereyoubin, datarecoverfree, coffice2txt |
| Flutter Linux runtime | move-item-sorter, launchpad-career |
| Waydroid (amd64 + arm64) | Kotlin Android apps: adhush, JokeCamera, annes-post, AI-President |
| Wine (stable, WoW64) + Wine Mono + .NET Framework via winetricks + VB6 runtime | qat-exposer (VB6), excelrcvryaddin (VB.NET), autoscrshotanno (AutoIt), crrptoffcxtrctr (Delphi/Pascal) |
| Box64/FEX on arm64 | Wine x86 apps on Raspberry Pi / Apple Silicon VMs |
| LibreOffice + Office on the web (browser) | Office-adjacent tools; Office JS add-ins (Title-Capitalizer) via Office on the web |
| Optional local LLM runtime (llama.cpp) | kjb-llm |

**Known gap:** COM add-ins for desktop Microsoft Office (qat-exposer, excelrcvryaddin)
need a licensed Microsoft Office under Wine. This works only partially and you must supply
the Office license. These apps are rated "best effort" in the matrix.

## Phase 3 — App catalog
- One YAML recipe per repo: source, build, runtime layer, packaging, launcher, icon, test.
- Packaging rules: web apps → offline PWA bundle + `.desktop` launcher; Electron/Tauri
  apps → `.deb`; Python → `.deb` with vendored venv; Windows apps → pre-built Wine bottle;
  Android → APK side-loaded into Waydroid.
- "socrtwo Software Center" front-end (reads the catalog, installs and updates apps).
- Repos that are documents/data (cookbook, movie script, The Real Majority) ship as a
  read-only library app instead of programs.

## Phase 4 — Platform delivery
| Target | Work |
|---|---|
| Raspberry Pi | Pi kernel and firmware, `config.txt`, image for Raspberry Pi Imager JSON feed |
| Windows | WSL2 `.wsl` package + `wsl --install --from-file` docs; Hyper-V `.vhdx`; VirtualBox `.ova` |
| macOS | UTM `.utm` bundles (Apple Virtualization arm64, QEMU x86-64); Parallels/VMware notes |
| Android (Termux) | `proot-distro` plugin script, Termux:X11 desktop launcher, Wine via Box64 (slow) |
| Android (AVF) | Validate import of a custom Debian image into the Linux Terminal app; fall back to Termux if blocked |
| iOS | UTM SE-compatible image (lite XFCE, i386/x86-64); iSH Alpine-compatible CLI subset |
| Online — full | cloud-init `qcow2`/AMI + KasmVNC web desktop; one-click deploy docs; devcontainer for Codespaces |
| Online — lite | WebVM/CheerpX ext2 image (i386, CLI + web apps), hosted as a static page |
| Containers | OCI image (`ghcr.io/…`), headless + web desktop tags |

## Phase 5 — Desktop, updater, first-run
- First-run wizard: language, account, which socrtwo apps to preinstall.
- Updates: apt + Btrfs/Snapper snapshots with rollback from GRUB; WSL/OCI use image refresh.
- Settings panel for compatibility layers (enable Waydroid/Wine on demand to save space).
- Accessibility pass (screen reader, scaling, high-contrast).

## Phase 6 — QA, hardening, signing
- openQA-style QEMU suite: boot, install, update, launch every catalog app.
- Hardware test checklist (manual): one PC, Pi 4, Pi 5, Android phone, iPhone/iPad, Mac.
- Secure Boot: shim from Debian (signed) + MOK-enrolled project key. Getting a project-owned
  shim signed by Microsoft is an external review process and is out of scope for 1.0.
- AppArmor profiles for networked apps; unattended security upgrades; SBOM (SPDX) per image;
  reproducible-build checks; artifact signing (Sigstore/cosign + GPG).

## Phase 7 — 1.0 release
- Download page added to the socrtwo landing page; per-platform install guides with screenshots.
- Release notes, checksums, signatures, torrent for the ISO.
- Post-1.0 backlog: Asahi (bare-metal Apple Silicon), RISC-V, Android GSI (research only).

#!/data/data/com.termux/files/usr/bin/env bash
# termux-create-repo.sh — scaffold the metadata-only repository for Anne's OS
# and publish it to GitHub with topics and roadmap milestones.
#
# Usage (Termux):
#   bash termux-create-repo.sh               # write files, git init, create GitHub repo
#   bash termux-create-repo.sh --no-github   # write files + local git commit only
#
# Override any of these on the command line, e.g.  REPO_NAME=my-os bash termux-create-repo.sh
set -euo pipefail

REPO_NAME="${REPO_NAME:-annes-os}"
_DEFAULT_DISPLAY="Anne's OS"
DISPLAY_NAME="${DISPLAY_NAME:-$_DEFAULT_DISPLAY}"
VISIBILITY="${VISIBILITY:-public}"          # public | private
TARGET_DIR="${TARGET_DIR:-$HOME/$REPO_NAME}"
START_DATE="${START_DATE:-$(date +%Y-%m-%d)}" # milestone due dates are offsets from this
NO_GITHUB=0
[[ "${1:-}" == "--no-github" ]] && NO_GITHUB=1

DESCRIPTION="${DISPLAY_NAME}: Debian-based OS to run all socrtwo apps (web/TS, Python, PHP, Flutter, Android via Waydroid, VB6/.NET/AutoIt via Wine). Targets PC, Raspberry Pi, WSL, macOS VM, Android (Termux), iOS (emulated), browser/cloud. Est. Claude build cost: Opus 5.5 med ~\$4.4k, Fable 5.2 med ~\$6.8k."

if [[ -e "$TARGET_DIR/.git" ]]; then
  echo "Refusing to overwrite existing git repo at $TARGET_DIR" >&2; exit 1
fi
mkdir -p "$TARGET_DIR"/{docs,meta,.github/ISSUE_TEMPLATE}
cd "$TARGET_DIR"

# ---------------------------------------------------------------- README.md
cat > README.md <<'EOF'
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
EOF

# ---------------------------------------------------------------- ROADMAP.md
cat > ROADMAP.md <<'EOF'
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
EOF

# ---------------------------------------------------------------- docs/COST-ESTIMATE.md
cat > docs/COST-ESTIMATE.md <<'EOF'
# Claude build-cost and duration estimate

**These are estimates, not quotes.** They depend on the assumptions below. Actual spend
can be checked as you go with `/cost` in Claude Code or in the Console usage page.

## Pricing used (Anthropic API list prices, 2026-11, per million tokens)

| Model | Input | Output | Cache read | Cache write (1-hour TTL = 2× input) |
|---|---|---|---|---|
| Claude Opus 5.5 (`claude-opus-5-5`) | $4.00 | $20.00 | $0.20 | $8.00 |
| Claude Fable 5.2 (`claude-fable-5-2`) | $8.00 | $40.00 | $0.20 | $16.00 |

Effort: **medium** for both. Medium is Opus 5.5's default; Fable 5.2 must be set to it
explicitly.

## Unit of work

A **task** is one PR-sized change, such as one image recipe, one compatibility layer,
one catalog recipe, or one CI job. That includes reading context, editing, running builds
and tests, and fixing until green.

| Per-task assumption | Value |
|---|---|
| Agent turns | 60 |
| Average context per turn | 120K tokens |
| Input per task | 7.2M tokens (92% cache read, 5% cache write, 3% uncached) |
| Output per task (incl. thinking) | 90K tokens (1.5K/turn) |
| **Cost per task — Opus 5.5** | **$6.87** |
| **Cost per task — Fable 5.2** | **$12.41** |

## Task count

| Workstream | Base tasks | Opus 5.5 $ | Fable 5.2 $ |
|---|---|---|---|
| WS0 Repo & CI | 15 | 139 | 214 |
| WS1 Base image (amd64/arm64) | 40 | 371 | 571 |
| WS2 Compatibility layers | 60 | 556 | 856 |
| WS3 Platform targets (10 artifacts) | 137 | 1,270 | 1,956 |
| WS4 App catalog (71 repos) | 107 | 992 | 1,527 |
| WS5 Desktop, updater, first-run | 40 | 371 | 571 |
| WS6 QA automation | 40 | 371 | 571 |
| WS7 Security, signing, SBOM | 25 | 232 | 357 |
| WS8 Docs & website | 15 | 139 | 214 |
| **Total** | **479** | **≈ $4,440** | **≈ $6,840** |

**Rework factor:** tasks that must be redone because the first attempt failed review or
broke on real hardware. Opus 5.5 ×1.35 gives about 647 effective tasks. Fable 5.2 ×1.15
gives about 551, because it is more reliable on long, multi-step build and debug work.

**Range:** −33% / +50%. Image and boot debugging has a long tail: a stubborn RPi or
Secure Boot issue can consume many turns with large build logs in context.

| Model | Low | Expected | High |
|---|---|---|---|
| Opus 5.5 medium | $2,980 | $4,440 | $6,660 |
| Fable 5.2 medium | $4,580 | $6,840 | $10,260 |

## Duration

| | Opus 5.5 medium | Fable 5.2 medium |
|---|---|---|
| Wall-clock per task (incl. build waits) | ~25 min | ~30 min |
| Total agent time | ~270 h | ~275 h |
| Your review time (per task: 10 min / 7 min) | ~108 h | ~64 h |
| Manual hardware testing | ~60 h | ~60 h |
| Parallel Claude sessions | 3 | 3–4 |
| **Calendar, at ~3 h/day of your time** | **11 – 16 weeks** | **8 – 12 weeks** |

You are the bottleneck, not the model. Your time goes into reviewing PRs and testing on
real devices. Fable costs more in tokens but needs less supervision and less rework.

## Not included

- CI compute. GitHub Actions is free for public repos. Private repos and large ISO
  builds may exceed the free minutes.
- Hardware, a Microsoft Office license (for the Wine add-in tests), cloud hosting for the
  online edition (a small VM costs roughly $10–40/month, depending on provider), and the
  Apple Developer fee if a native iOS helper app is ever needed.
- Subscription plans: on a Claude Pro or Max plan, the marginal cost is the subscription
  fee, subject to usage limits. The figures above are API-equivalent spend.

## Cheaper hybrid

Use Fable 5.2 for architecture, boot, and image debugging (WS1, WS3, WS7: about 200
tasks). Use Opus 5.5 for catalog recipes, docs, and CI (about 280 tasks). Expected spend
is about **$5,400**, at roughly Fable-level reliability on the hard parts.
EOF

# ---------------------------------------------------------------- docs/COMPATIBILITY.md
cat > docs/COMPATIBILITY.md <<'EOF'
# Compatibility matrix — socrtwo portfolio (71 repositories, 2026-11)

| Language / kind | Repos | Runtime layer | Expected result |
|---|---|---|---|
| HTML / JavaScript / TypeScript web apps | ~50 (Anne's Office suite, Universal-File-Repair-Tool, Immortal-Zip, SF migrations, bots, sites) | Node 22 + Chromium PWA host / Electron / Tauri | Full |
| Python | annes-keep, VPN-Follower, kjb-llm, Common-Ground | Python 3.13, per-app venv; llama.cpp for kjb-llm | Full |
| PHP | whereyoubin-SF, datarecoverfree-SF | PHP 8 + local web server | Full |
| Perl, Roff | coffice2txt-SF, wordrecovery-SF | Perl 5, groff | Full |
| Dart / Flutter | move-item-sorter, launchpad-career | Flutter Linux build | Full |
| Kotlin / Android | adhush, JokeCamera, annes-post, AI-President | Waydroid (PC/Pi/VM); native on Android | Full on PC/Pi; native on Android; none on iOS |
| Visual Basic 6 | qat-exposer | Wine + VB6 runtime + **MS Office (user-supplied)** | Best effort |
| VB.NET | excelrcvryaddin-SF | Wine + .NET Framework + **MS Office** | Best effort |
| AutoIt | autoscrshotanno-SF | Wine + AutoIt | Good |
| Pascal / Delphi | crrptoffcxtrctr-SF | Wine (or Free Pascal rebuild) | Good |
| Office JS add-in | Title-Capitalizer | Office on the web in browser | Good |
| Documents / data | cookbook, movie script, Real Majority, docs | Library app (PDF/EPUB/HTML viewer) | Full |

On iOS only the browser-deliverable apps (web/PWA) run at usable speed.
EOF

# ---------------------------------------------------------------- docs/PLATFORMS.md
cat > docs/PLATFORMS.md <<'EOF'
# Platform delivery design

One pipeline, many packers:

```
mmdebstrap (amd64, arm64[, i386-lite])
   └─ rootfs.tar.zst  ──┬─ live ISO + Calamares ........ PC / ARM64 UEFI hardware, dual boot
                        ├─ RPi image (debos) ........... Raspberry Pi 4/5/400/500
                        ├─ .wsl tarball ................ Windows WSL2
                        ├─ .vhdx / .ova / qcow2 ........ Hyper-V, VirtualBox, QEMU, cloud
                        ├─ .utm bundle ................. macOS (UTM), iOS (UTM SE, lite)
                        ├─ proot-distro rootfs ......... Android / Termux (+ Termux:X11)
                        ├─ AVF disk image .............. Android 15+ Linux Terminal (validate)
                        ├─ OCI image ................... Docker/Podman, Codespaces, KasmVNC web desktop
                        └─ CheerpX ext2 (i386 lite) .... in-browser WebVM edition
```

Install commands for each target will be written in Phase 4, once real artifacts exist.
EOF

# ---------------------------------------------------------------- meta/project.yaml
cat > meta/project.yaml <<'EOF'
name: annes-os
display_name: "Anne's OS"
status: planning            # planning | alpha | beta | stable
base: debian-13-trixie
architectures: [amd64, arm64, i386-lite]
desktop: { default: kde-plasma-6, lite: xfce }
targets:
  - { id: pc-iso,        kind: bare-metal, arch: amd64 }
  - { id: arm64-iso,     kind: bare-metal, arch: arm64 }
  - { id: raspberry-pi,  kind: bare-metal, arch: arm64, models: [pi4, pi400, pi5, pi500] }
  - { id: windows-wsl2,  kind: subsystem,  arch: [amd64, arm64] }
  - { id: windows-vm,    kind: vm,         formats: [vhdx, ova] }
  - { id: macos-utm,     kind: vm,         arch: [arm64, amd64] }
  - { id: android-termux, kind: container, arch: arm64, fidelity: partial }
  - { id: android-avf,   kind: vm,         arch: arm64, fidelity: to-validate }
  - { id: ios-utm-se,    kind: emulation,  fidelity: low }
  - { id: web-cloud,     kind: remote-desktop, formats: [qcow2, ami, oci] }
  - { id: web-webvm,     kind: in-browser-vm, arch: i386-lite }
estimate:
  as_of: 2026-11-24
  effort: medium
  base_tasks: 479
  models:
    claude-opus-5-5:
      effective_tasks: 647
      usd: { low: 2980, expected: 4440, high: 6660 }
      agent_hours: 270
      review_hours: 108
      calendar_weeks: [11, 16]
    claude-fable-5-2:
      effective_tasks: 551
      usd: { low: 4580, expected: 6840, high: 10260 }
      agent_hours: 275
      review_hours: 64
      calendar_weeks: [8, 12]
roadmap_file: ROADMAP.md
EOF

# ---------------------------------------------------------------- meta/milestones.tsv (title<TAB>due-offset-days<TAB>description)
printf '%s\t%s\t%s\n' \
 "Phase 0 — Foundations"            7   "CI builds empty Debian rootfs for amd64+arm64" \
 "Phase 1 — Base image"            21   "Bootable amd64 ISO + arm64 image to desktop in QEMU" \
 "Phase 2 — Compatibility layers"  42   "Wine, Waydroid, all runtimes pass smoke matrix" \
 "Phase 3 — App catalog"           63   "All 71 socrtwo repos install+launch or N/A with reason" \
 "Phase 4 — Platform delivery"     84   "Every platform-table row produces a signed artifact" \
 "Phase 5 — Desktop & updater"     91   "Install → update → app install with no terminal" \
 "Phase 6 — QA & hardening"       105   "Automated tests green on all targets; SBOM published" \
 "Phase 7 — 1.0 release"          112   "Release notes, website, per-platform install guides" \
 > meta/milestones.tsv

# ---------------------------------------------------------------- GitHub templates
cat > .github/ISSUE_TEMPLATE/roadmap-task.md <<'EOF'
---
name: Roadmap task
about: One PR-sized unit of roadmap work
labels: roadmap
---
**Phase / workstream:**
**Target(s):**
**Exit criterion (how we know it's done):**
**Estimated Claude tasks:**
EOF
cat > .gitignore <<'EOF'
/out/
/cache/
*.iso
*.img
*.img.xz
*.qcow2
*.vhdx
*.wsl
*.tar.zst
EOF

# ---------------------------------------------------------------- git
git init -q -b main
git add -A
git -c user.name="${GIT_NAME:-$(git config user.name || echo socrtwo)}" \
    -c user.email="${GIT_EMAIL:-$(git config user.email || echo socrtwo@users.noreply.github.com)}" \
    commit -q -m "Project metadata, cost estimate and roadmap (no code yet)"
echo "Local repo created at $TARGET_DIR"

[[ $NO_GITHUB -eq 1 ]] && { echo "Skipping GitHub (--no-github)."; exit 0; }

# ---------------------------------------------------------------- GitHub
gh auth status >/dev/null 2>&1 || { echo "Run: gh auth login" >&2; exit 1; }
gh repo create "$REPO_NAME" --"$VISIBILITY" --source=. --remote=origin --push \
   --description "$DESCRIPTION"
OWNER="$(gh api user --jq .login)"
gh repo edit "$OWNER/$REPO_NAME" \
   --add-topic operating-system,linux-distribution,debian,raspberry-pi,wsl2,termux,utm,waydroid,wine,cross-platform,roadmap

while IFS=$'\t' read -r title offset desc; do
  due="$(date -u -d "$START_DATE + $offset days" +%Y-%m-%dT23:59:59Z)"
  gh api -X POST "repos/$OWNER/$REPO_NAME/milestones" \
     -f title="$title" -f description="$desc" -f due_on="$due" --silent \
     && echo "milestone: $title (due ${due%%T*})"
done < meta/milestones.tsv

gh label create roadmap --color 7c3aed --description "Roadmap task" -R "$OWNER/$REPO_NAME" 2>/dev/null || true
echo "Done: https://github.com/$OWNER/$REPO_NAME"

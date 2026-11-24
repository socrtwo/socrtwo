#!/data/data/com.termux/files/usr/bin/bash
# Anne's Browser: repository bootstrap for Termux (Android).
# Creates the metadata and roadmap files, commits them, and publishes to GitHub.
# Usage:   bash setup-annes-browser.sh
# Options (env vars): GH_OWNER=socrtwo REPO_NAME=annes-browser VISIBILITY=public|private
#                     PROJECT_DIR=$HOME/projects/annes-browser  SKIP_GH=1 (local only)
set -euo pipefail

GH_OWNER="${GH_OWNER:-socrtwo}"
REPO_NAME="${REPO_NAME:-annes-browser}"
VISIBILITY="${VISIBILITY:-public}"
PROJECT_DIR="${PROJECT_DIR:-$HOME/projects/$REPO_NAME}"
DESCRIPTION="Anne's Browser: every menu command from 35 years of web browsers, plus new ones. (Planning phase)"

# 1. Packages
if command -v pkg >/dev/null 2>&1; then
  pkg install -y git gh
fi
command -v git >/dev/null || { echo "git not found"; exit 1; }

# 2. Git identity (asked only if unset)
if [ -z "$(git config --global user.name || true)" ]; then
  read -rp "Git user.name: " GN; git config --global user.name "$GN"
fi
if [ -z "$(git config --global user.email || true)" ]; then
  read -rp "Git user.email (GitHub noreply address recommended): " GE; git config --global user.email "$GE"
fi

# 3. Project directory
if [ -e "$PROJECT_DIR" ] && [ -n "$(ls -A "$PROJECT_DIR" 2>/dev/null)" ]; then
  echo "ERROR: $PROJECT_DIR exists and is not empty. Set PROJECT_DIR to another path."; exit 1
fi
mkdir -p "$PROJECT_DIR"/docs "$PROJECT_DIR"/.github/ISSUE_TEMPLATE
cd "$PROJECT_DIR"

# 4. Files

cat > 'README.md' <<'ANNES_EOF'
# Anne's Browser

**Every menu command from 35 years of web browsers, plus new ones, in one searchable, customizable browser.**

> Status: **Pre-development / planning.** This repository holds only metadata, the roadmap and the cost estimate. No application code exists yet.

## Concept

Browsers have gained and dropped hundreds of commands since WorldWideWeb (1990). Some were superseded and some were simply forgotten. Many were good ideas that disappeared when a product died: Opera's notes, panels and fit-to-width, Netscape Composer, Konqueror's split views, Vivaldi's tab tiling, Arc's spaces, and Lynx's text-only rendering.

Anne's Browser catalogs those commands, de-duplicates them into one canonical set and makes each one reachable in three ways:

1. **Menus**: classic menu bars, with switchable "era layouts" (1994 minimal, 1999 suite, 2008 tabbed, modern hamburger).
2. **Command palette**: fuzzy search over every command by name, alias or the historic browser it came from.
3. **Keyboard and gestures**: remappable shortcuts, mouse gestures and an optional modal (vi-style) mode.

On top of the historic set, it adds new commands aimed at research, publishing, OCR, genealogy and archiving (see [ROADMAP.md](ROADMAP.md), Phase 7).

## Design principles

- **Don't write a rendering engine.** Build a shell on an existing, maintained engine (Chromium via Electron or CEF, or Gecko via GeckoView on Android). The value is in the command layer, not in layout code.
- **One command registry drives everything.** Each command is a data record (id, label, category, lineage, default shortcuts, platform availability, implementation status). Menus, the palette, help text, keybindings and documentation are all generated from it.
- **Lineage is a feature.** Every command records which browsers and versions introduced or carried it, and "Menu archaeology" mode shows that history to the user.
- **Obsolete is not the same as unsafe.** Retired features are classified as *implement*, *emulate* (for example Flash through Ruffle, or Gopher through a built-in client), *stub with explanation* (ActiveX, NPAPI, Java applets) or *omit*.
- **No trade dress.** Era layouts recreate how menus were *organized*, not anyone's logos, artwork or branding.
- **Privacy by default.** No telemetry. Any AI or cloud-backed commands are opt-in and bring-your-own-key.

## Browsers surveyed (command census sources)

| Era | Browsers |
|---|---|
| 1990–1995 | WorldWideWeb/Nexus, Line Mode Browser, ViolaWWW, Erwise, Cello, Lynx, NCSA Mosaic, Netscape Navigator 1–2, Internet Explorer 1–2 |
| 1996–2003 | Netscape Navigator/Communicator 3–4.x, Netscape 6–7, Internet Explorer 3–6, Opera 3–7, Mozilla Application Suite, iCab, OmniWeb, Konqueror, Galeon, K-Meleon, Links/ELinks, w3m, Dillo |
| 2003–2010 | Firefox 1–3.6, Safari 1–5, Camino, Epiphany, SeaMonkey, Flock, Opera 8–10 (Presto), Internet Explorer 7–8, Google Chrome 1–8 |
| 2010–2020 | Firefox 4–Quantum, Opera 11–12 (Presto) and 15+ (Blink), Chrome, Internet Explorer 9–11, Edge Legacy, Vivaldi, Brave, Pale Moon, Waterfox, qutebrowser, Min, NetSurf |
| 2020–present | Edge (Chromium), Firefox, Chrome, Safari, Vivaldi, Brave, Opera/Opera GX, Arc, Zen, Floorp, Orion, Ladybird, Sidekick, SigmaOS |
| Mobile | Opera Mini/Mobile, Safari iOS, Chrome Android, Firefox Android/Focus, Samsung Internet, UC Browser, DuckDuckGo, Kiwi, Dolphin |

## Planned platforms

To be decided in Phase 0. The recommendation is in [ROADMAP.md](ROADMAP.md): desktop (Windows, macOS, Linux) first on Electron, then Android on GeckoView.

## Repository layout (planned)

```
annes-browser/
├── README.md              This file
├── ROADMAP.md             Phased plan, exit criteria, open decisions
├── COST-ESTIMATE.md       Token and cost estimates (Claude and alternatives)
├── CHANGELOG.md
├── CONTRIBUTING.md
├── LICENSE
├── docs/
│   └── COMMAND-CATALOG.md Command record schema and category taxonomy
├── catalog/               (Phase 1) commands.yaml and per-browser source lists
├── app/                   (Phase 2+) application code
└── .github/ISSUE_TEMPLATE Command-request template
```

## License

MIT (placeholder, to be confirmed in Phase 0). See [LICENSE](LICENSE).
ANNES_EOF

cat > 'ROADMAP.md' <<'ANNES_EOF'
# Anne's Browser: Roadmap

Last updated: 2026-11-24. Status: Phase 0.

Token figures per phase are output-token budgets for AI-assisted development at the mid estimate (see [COST-ESTIMATE.md](COST-ESTIMATE.md)). Input and cache tokens scale with them at about 50:1.

---

## Phase 0: Decisions and metadata *(this commit)*

**Deliverables:** README, ROADMAP, COST-ESTIMATE, CHANGELOG, CONTRIBUTING, LICENSE, command-catalog schema, issue template.

**Open decisions (must close before Phase 2):**

| # | Decision | Options | Recommendation |
|---|---|---|---|
| D1 | Primary platform | Desktop first / Android first / both at once | Desktop first. Menu-heavy UI suits desktop, and Android follows using the same registry. |
| D2 | Engine (desktop) | Electron (Chromium) / CEF + native / Qt WebEngine / Tauri (system WebView) | **Electron.** Full Chromium, extension support, DevTools and cross-platform menus. Tauri's system WebView varies too much between OSes. |
| D3 | Engine (Android) | GeckoView / Android System WebView / Chromium fork | **GeckoView.** Real extension support, about: pages and full control. System WebView is too limited for this feature set. |
| D4 | Language | TypeScript (desktop) + Kotlin (Android) | TypeScript and Kotlin, with the command registry shared as YAML/JSON. |
| D5 | License | MIT / MPL-2.0 / GPL-3.0 | MIT for maximum reuse, or MPL-2.0 for file-level copyleft. Currently MIT placeholder. |
| D6 | Name clearance | Trademark search for "Anne's Browser" | Run a USPTO/EUIPO search before any public release. |
| D7 | Distribution | GitHub Releases / F-Droid / Play Store / winget / Homebrew / Flathub | GitHub Releases first, then F-Droid and Flathub. |
| D8 | Extensions | Chrome Web Store (MV3) / Firefox AMO / none | MV3 on desktop and AMO on Android, following the engines. |

**Exit criteria:** D1–D8 recorded in `docs/DECISIONS.md`.

---

## Phase 1: Command census *(~0.4M output tokens)*

Build the master catalog that the whole product is generated from.

1. For each surveyed browser and major version, list every menu, context-menu, toolbar, keyboard-only and settings-exposed command. Sources: manuals, help files, archived screenshots (Internet Archive, Toastytech GUI gallery), menu dumps of installable versions in VMs, and source code where it is available (Mozilla, Chromium, WebKit, Konqueror, Lynx, Dillo).
2. Record each one in `catalog/sources/<browser>-<version>.yaml`.
3. De-duplicate into `catalog/commands.yaml`, one canonical record per behavior, with aliases and lineage (schema in [docs/COMMAND-CATALOG.md](docs/COMMAND-CATALOG.md)).
4. Classify each one: `implement` / `emulate` / `stub` / `omit`, with a reason for each.

**Expected size:** about 2,000–3,000 raw entries, reducing to about 700–1,000 canonical commands.

**Exit criteria:** catalog validates against the schema. Every surveyed browser has a source file, and every canonical command has a classification.

---

## Phase 2: Architecture skeleton *(~0.6M)*

- App shell: windows, tab strip, address bar, status bar, sidebar host.
- **Command registry runtime:** loads `commands.yaml` and exposes `execute(id, args)`, `isEnabled(id, ctx)` and `isChecked(id, ctx)`.
- **Menu generator:** builds native menu bars and context menus from the registry, with era-layout definitions as data.
- **Command palette:** fuzzy search across labels, aliases and lineage ("Netscape 4: Edit Page").
- **Keybinding engine:** profiles (Modern, Classic IE, Classic Netscape, Opera, Emacs, vi), conflict detection and a chord editor.
- Settings store, profiles and an import pipeline (bookmarks, history and passwords from other browsers).
- Test harness: every registry command has at least a smoke test, or an explicit `stub` assertion.

**Exit criteria:** a browser that opens pages in tabs, with menus and palette generated entirely from the registry.

---

## Phase 3: Modern baseline parity *(~1.0M)*

The commands every current browser has: navigation, tabs and windows, reopen closed, pin, mute, bookmarks manager, history, downloads, find in page, zoom, print and print preview, page info, view source, DevTools, private windows, site permissions, cookies and storage manager, password manager, autofill, reader mode, translate hook, PDF viewer, spell-check, sync stub, task manager, extensions manager, default-browser and handler settings.

**Exit criteria:** passes a scripted parity checklist against current Chrome and Firefox menus.

---

## Phase 4: Era layouts and personalities *(~0.4M)*

- Menu layouts as data: *1994 Minimal* (File/Edit/View/Go/Bookmarks/Options/Directory/Help), *1999 Suite* (Communicator-style with Tasks and Window menus), *2001 Classic* (IE6-style Favorites/Tools), *2005 Power* (Opera-style Tools/Widgets/Panels), *2008 Tabbed*, *2012 Hamburger*, and *Everything* (all commands, grouped).
- Toolbar presets with generic, original icons. No logos or trade dress.
- Optional status-bar and throbber behaviors (progress text, security indicator).

**Exit criteria:** switching layout changes only presentation and never availability; every command stays reachable from the palette.

---

## Phase 5: Power-user features from niche and defunct browsers *(~1.2M)*

| Origin | Commands |
|---|---|
| Opera Presto | Mouse gestures, rocker gestures, Speed Dial, Notes panel, sessions save/load, fit-to-width, user-mode/author-mode CSS toggle, "Fast Forward" (next page), cache and cookie viewers, site-specific preferences, Links panel |
| Vivaldi | Tab stacks, tab tiling, command chains, web panels, notes with screenshots, page actions, tab hibernation |
| Arc / Zen / SigmaOS | Spaces/workspaces, split view, peek/little-window, boosts (per-site CSS/JS), auto-archive tabs |
| Konqueror | Split views, file-manager mode for local and FTP/SFTP listings, KIO-style protocol handlers |
| qutebrowser / Vimium | Modal keyboard mode, hint-mode link following, `:command` line, quickmarks |
| Lynx / w3m / Links | Text-only rendering mode, numbered links, dump-as-text |
| Firefox (classic) | Containers, tab groups, about:config-style editor, Live Bookmarks (feeds), keyword bookmarks |
| IE | Favorites import/export, "Work offline", compatibility-mode user-agent switching, Accelerators (selection actions) |
| Safari | Reading List, Reader, Top Sites, Web Inspector-style responsive mode |
| Brave | Shields-style per-site blocking panel, Tor-proxied private window (via external Tor) |

**Exit criteria:** each command marked `implement` in the catalog for this phase passes its test.

---

## Phase 6: Historic and legacy emulation *(~0.7M)*

| Historic command | Treatment |
|---|---|
| Gopher, Finger, WAIS-style search | Built-in Gopher client; Finger read-only; WAIS documented as historical |
| FTP browsing | Read-only listing/download through a bundled client (engines dropped FTP) |
| Netscape Composer / FrontPage Express ("Edit Page") | Built-in WYSIWYG HTML editor with save-to-file |
| Communicator Mail, News, Address Book, IRC | Optional modules: NNTP reader, IRC client; mail opens an external client (out of scope) |
| Flash / Shockwave | Emulate through Ruffle (Flash only); Shockwave stubbed |
| Java applets, ActiveX, NPAPI plugins, VRML | **Stub with explanation** (security). VRML through an optional X3D viewer later |
| Channels / Active Desktop / Smart Update | Mapped to the feed reader and update checker; Active Desktop omitted |
| "What's Related", Directory buttons, Net Search | Re-implemented through configurable search and related-page providers |
| Character-set menu | Encoding override (still useful for old pages) |
| Show images on/off, load images manually | Implemented |

**Exit criteria:** every `emulate` and `stub` record has working behavior or an explanatory dialog.

---

## Phase 7: New commands *(~1.0M)*

New commands, prioritized for research, publishing, OCR and genealogy work:

**Archiving and history**
- *View as of…*: open the Internet Archive capture for any date; automatically offer it on 404 or 410.
- *What changed since my last visit*: visual and text diff against the locally cached copy.
- *Save as…*: single-file HTML, WARC, EPUB, PDF/A, DOCX, Markdown, plain text.
- *Recover typed text*: form-input history per site (opt-in, local, encrypted).

**Extraction**
- *OCR region / OCR image*: Tesseract-based, with language selection and copy as text.
- *Table → CSV / XLSX*, *List → CSV*.
- *Extract all links / images / media* with pattern filters and bulk download.
- *Copy as Markdown / HTML / plain*; *Copy as citation* (Chicago, MLA, APA, BibTeX, Evidence Explained style for genealogy).

**Typography and publishing**
- *Typography inspector*: fonts in use, sizes, line length, leading and contrast (WCAG).
- *Clean copy*: normalize quotes, dashes, ligatures and whitespace on copy.
- *Print designer*: margins, headers/footers, remove clutter, print selection only.

**Research workflow**
- *Research session*: highlight and annotate pages, then export notes with citations (Markdown/DOCX).
- *Side-by-side translate*: original and translation with synchronized scrolling.
- *Compare two pages* with synchronized scroll and diff.
- *Genealogy helper* (plugin): detect names, dates and places and export to a GEDCOM-ready table.

**Control and privacy**
- *Macro recorder*: record a sequence of commands and replay or bind it to a key.
- *Page network report*: trackers, third parties and data sent.
- *Undo anything*: closed tab, window, group, deleted download, cleared form.
- *Scheduled loads and page monitors*: notify on change.
- *Dead-link check* on the current page.
- *Menu archaeology*: shows each command's lineage ("first seen in Opera 7, 2003").
- *Ask the page* (opt-in, BYO API key or local model): summarize, question-answer, explain.

**Exit criteria:** each Phase 7 command is shipped behind a feature flag with docs.

---

## Phase 8: Hardening *(~0.5M)*

Accessibility (screen readers, full keyboard operation, high contrast), i18n of all command labels, performance budgets (cold start, memory per tab), security review of every emulation and protocol handler, fuzzing of the Gopher, FTP and NNTP parsers, and an auto-update channel.

---

## Phase 9: Android *(~0.8M)*

GeckoView shell. The same `commands.yaml`, filtered by `platforms`, drives a bottom-sheet command menu, palette and gestures. Termux-friendly build scripts.

---

## Phase 10: Release *(~0.2M)*

Signed builds, installers, F-Droid metadata, Flathub manifest, winget and Homebrew manifests, documentation site generated from the registry.

---

## Out of scope

- Writing a layout or JavaScript engine.
- Native execution of NPAPI, ActiveX or Java applets.
- Reproducing any vendor's logos, artwork or branded UI.
- A full email client.

## Phase budget summary

| Phase | Output tokens (mid) |
|---|---|
| 1 Census | 0.4M |
| 2 Skeleton | 0.6M |
| 3 Baseline | 1.0M |
| 4 Layouts | 0.4M |
| 5 Power features | 1.2M |
| 6 Legacy emulation | 0.7M |
| 7 New commands | 1.0M |
| 8 Hardening | 0.5M |
| 9 Android | 0.8M |
| 10 Release | 0.2M |
| **Total** | **~6.8M** (desktop-only through Phase 8: ~5.8M) |
ANNES_EOF

cat > 'COST-ESTIMATE.md' <<'ANNES_EOF'
# Anne's Browser: AI Development Token and Cost Estimate

Prepared 2026-11-24. All prices are USD per million tokens (MTok), list API rates. Claude prices are from Anthropic's published rate card. Other vendors' prices come from third-party trackers dated Sept–Nov 2026 and are marked as such. **Check each vendor's official pricing page before committing money.**

## 1. What is being built (sizing basis)

| Component | Est. lines |
|---|---|
| Shell, command registry runtime, menu generator, palette, keybindings | 25,000 |
| Feature implementations (Phases 3–7, ~800 canonical commands collapsing to ~350 distinct handlers) | 65,000 |
| Android GeckoView shell (Phase 9) | 15,000 |
| Tests | 30,000 |
| Catalog data (YAML) and generated docs | 15,000 |
| **Total** | **~150,000** |

At about 11 tokens per line, the finished artifact is about **1.6M tokens**. Agentic development generates far more than it keeps: reasoning, rewrites, failed attempts, test fixes and refactors. Typical overhead is 3–5×, which gives about **6.5M output tokens** (mid estimate, consistent with the phase budgets in ROADMAP.md).

Input dominates by volume. Every agent turn re-sends the working context (files, tool results, history). A ratio of about 50 input tokens per output token is typical for coding agents, and with prompt caching about 94% of that input is served from cache.

| Scenario | Output (incl. thinking) | Uncached input / cache writes | Cached input reads |
|---|---|---|---|
| Low (tight scope, few reworks) | 3.5M | 10M | 170M |
| **Mid** | **6.5M** | **20M** | **325M** |
| High (scope creep, heavy rework) | 13M | 40M | 650M |

Assumptions: Claude cache writes are billed at 1.25× base input (5-minute TTL; the 1-hour TTL costs 2×). Other vendors' uncached input is billed at their base input rate.

## 2. Claude estimates

| Model | Rates (in / out / cache read) | Low | **Mid** | High |
|---|---|---|---|---|
| **Claude Opus 5.5, medium effort** | $4 / $20 / $0.20 | $154 | **$295** | $590 |
| **Claude Fable 5.2** (high effort) | $8 / $40 / $0.20 | $274 | **$525** | $1,050 |
| Claude Sonnet 5.5 (reference) | $2 / $10 / $0.10 | $77 | **$148** | $295 |

Mid-case breakdown for Opus 5.5: output 6.5M × $20 = $130, cache writes 20M × $5 = $100, cache reads 325M × $0.20 = $65.

Mid-case breakdown for Fable 5.2: output $260, cache writes $200, cache reads $65.

Notes:
- **Opus 5.5 at medium** is its default effort and is adequate for most of this project, which is wide (many commands) rather than deep. Fable 5.2 costs about 1.8× as much per token and earns that mainly on the hard parts: engine integration, the command-registry architecture, security review, and gnarly protocol and emulation code. It may finish those parts in fewer turns.
- **Flat-rate subscription:** if the work runs in Claude Code on a Claude subscription plan rather than API billing, the marginal cost is the plan fee, subject to its usage limits. At this volume, spread over months, a subscription is likely cheaper than API billing. Check your plan's current limits.
- **Batch API** (50% off) does not suit interactive agent work, but it does suit Phase 1 catalog extraction (bulk summarizing of manuals and menu dumps).

## 3. Alternatives: is there a cheaper way?

The same mid token profile (6.5M output / 20M uncached / 325M cached input) is applied to each vendor's rates.

"Est. completion multiplier" is a **judgment, not a measurement**. It is the extra turns and tokens a model is likely to need to reach the same working result on a large multi-file agentic codebase, relative to Opus 5.5. Benchmark it on a real Phase 2 task before trusting it.

| Vendor / model | Rates (in / out / cached) | Raw mid | Est. completion multiplier | **Effective mid** | Source quality |
|---|---|---|---|---|---|
| Anthropic Claude Fable 5.2 | $8 / $40 / $0.20 | $525 | 0.85 | **~$446** | Official |
| Anthropic Claude Opus 5.5 (medium) | $4 / $20 / $0.20 | $295 | 1.0 | **$295** | Official |
| Anthropic Claude Sonnet 5.5 | $2 / $10 / $0.10 | $148 | 1.15 | **~$170** | Official |
| OpenAI GPT-6.1 Sol | $2 / $10 / $0.10 | $138 | 1.2 | **~$165** | Third-party, Nov 2026 |
| OpenAI GPT-6 Astra | $10 / $50 / ~$1.00* | $850 | 0.9 | **~$765** | Third-party |
| xAI Grok 4.7 | $2 / $6 / $0.50 | $242 | 1.4 | **~$338** | Third-party; costly cache reads |
| xAI grok-build-0.1 | $1 / $2 / ~$0.25* | $114 | 1.8 | **~$205** | Third-party |
| DeepSeek V4 Pro (peak) | $1.32 / $3.96 / $0.044 | $66 | 1.5 | **~$100** (off-peak ~$50) | Third-party, Nov 2026 |
| DeepSeek V4.1 Flash (peak) | $0.30 / $1.20 / $0.006 | $16 | 3.0 | **~$47** | Third-party; figures conflict |
| Moonshot Kimi K3.1 Pro | $2 / $10 / $0.20 | $170 | 1.4 | **~$238** | Third-party; dates inconsistent |
| Zhipu GLM-5.2 | $1.40 / $4.40 / $0.26 | $141 | 1.5 | **~$212** (or GLM Coding Plan, ~$18/mo) | Third-party |
| Mistral Devstral Medium | $0.40 / $2.00 / ~$0.04* | $34 | 2.5 | **~$85** (no cache discount: ~$150 raw) | Third-party; API reportedly business-only since Aug 2026 |
| Google Gemini 3.8 Flash | $0.75 / $3.75 / ~$0.075* (intro, doubles 2027-01-01) | $64 | 2.0 | **~$128** (2027: ~$255) | Official Google page |
| Google Gemini 3.1 Pro Preview | $2 / $12 / ~$0.20* | $183 | 1.3 | **~$238** | Official Google page |
| Meta Llama 4 Maverick (hosted) | $0.19 / $0.65 / none | $70 | 4.0+ | **~$280, likely fails** | Third-party |

\* Cached-input rate not found; assumed ~10% of base input (25% for grok-build).

### Bottom line

1. **Yes, there are cheaper per-token options.** The cheapest credible ones for a project this size are **DeepSeek V4 Pro** (about $50–100 effective, less off-peak) and **GPT-6.1 Sol or Claude Sonnet 5.5** (about $165–170). DeepSeek Flash, Devstral and Llama are cheaper on paper, but they are likely to stall on a 150k-line, multi-process Electron/GeckoView codebase. That turns token savings into lost hours.
2. **The token bill is small next to your time.** Every scenario here costs well under the value of the supervision hours involved. The model that needs the fewest corrections is usually the cheapest overall.
3. **Cheapest sensible setup: route work by difficulty.**
   - Fable 5.2 or Opus 5.5 for Phase 2 architecture, security review and hard integrations (~25% of output).
   - Sonnet 5.5, GPT-6.1 Sol or DeepSeek V4 Pro for bulk command handlers, tests and catalog work (~75%).
   - Estimated blended mid cost: **~$140–190**, compared with ~$295 for all-Opus or ~$446 for all-Fable.
4. **The biggest saving is architectural, not vendor choice.** Driving menus, palette, shortcuts and docs from one `commands.yaml` collapses ~800 commands into ~350 handlers. That is already assumed above. Without it, expect 2–3× the tokens.
5. **Jurisdiction and data handling:** DeepSeek, Kimi, GLM and Qwen first-party APIs are operated from China. For an open-source project that is usually acceptable, but if any private material goes into prompts, use their open-weight models through a host in your own jurisdiction instead. Hosted prices for those differ.

## 4. Caveats

- Effort setting changes token use substantially. Opus 5.5 at `high` could use 1.3–1.6× the output tokens of `medium`.
- Long-context surcharges (OpenAI above 272K input, xAI above 200K) are not modeled; disciplined context management avoids most of them.
- Prices move monthly. Re-run this table at the start of each phase.

## Sources (non-Anthropic prices)

- OpenAI: [reflektlab.ai](https://reflektlab.ai/blog/openai-api-pricing/), [mem0.ai](https://mem0.ai/library/llms-and-models/openai-api-pricing), [nOps](https://www.nops.io/blog/openai-api-pricing/)
- DeepSeek: [nxcode.io](https://www.nxcode.io/resources/news/deepseek-api-pricing-complete-guide-2026), [CloudZero](https://www.cloudzero.com/blog/deepseek-pricing/), [aipricing.guru](https://www.aipricing.guru/deepseek-pricing/)
- xAI: [usagebox](https://usagebox.com/articles/grok-api-pricing-2026), [promptsrush](https://promptsrush.com/blog/grok-pricing), [opslyft](https://www.opslyft.com/blog/ai-grok-api-pricing-2026)
- Mistral: [mistral.ai pricing](https://mistral.ai/pricing/api/), [agentdeals.dev](https://agentdeals.dev/mistral-api-pricing-2026)
- Kimi / GLM: [capitalandcompute.net](https://capitalandcompute.net/blog/china-ai-pricing/), [apidog](https://apidog.com/blog/chinese-llm-price-war-2026/), [jia.je coding plans](https://jia.je/kb/en/software/coding_plan.html)
- Google: [Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing), [Vertex AI pricing](https://cloud.google.com/vertex-ai/generative-ai/pricing)
- Meta Llama: [activepieces](https://www.activepieces.com/blog/meta-llama-api-pricing-cost-per-million-tokens-2026)
ANNES_EOF

cat > 'CHANGELOG.md' <<'ANNES_EOF'
# Changelog

All notable changes to this project are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/).

## [Unreleased]

### Added
- 2026-11-24: Project metadata: README, ROADMAP, COST-ESTIMATE, command-catalog schema, contributing guide, issue template. No application code yet.
ANNES_EOF

cat > 'CONTRIBUTING.md' <<'ANNES_EOF'
# Contributing to Anne's Browser

The project is in the **planning phase**. The most useful contribution right now is **command census data**.

## Submitting a historic or current browser command

Open an issue with the **Command request** template, or a PR adding a record to `catalog/sources/<browser>-<version>.yaml` (Phase 1). Include:

- Browser, version and platform
- Exact menu path or shortcut (for example `File > Edit Page`, `Ctrl+E`)
- What it did
- A source: manual page, archived screenshot URL or source-code link

## Ground rules

- No vendor logos, icons or artwork in the repository.
- Do not paste copyrighted manual text. Paraphrase and cite instead.
- Every new command must have a catalog record before any code is written for it.
ANNES_EOF

cat > 'LICENSE' <<'ANNES_EOF'
MIT License

Copyright (c) 2026 Paul D. Pruitt (socrtwo)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
ANNES_EOF

cat > '.gitignore' <<'ANNES_EOF'
# Dependencies / build output
node_modules/
dist/
out/
build/
.gradle/
*.apk
*.aab
# Editors / OS
.vscode/
.idea/
.DS_Store
Thumbs.db
# Secrets
.env
.env.*
*.keystore
*.jks
ANNES_EOF

cat > '.editorconfig' <<'ANNES_EOF'
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 2
trim_trailing_whitespace = true

[*.md]
trim_trailing_whitespace = false

[*.{kt,kts}]
indent_size = 4
ANNES_EOF

cat > 'docs/COMMAND-CATALOG.md' <<'ANNES_EOF'
# Command Catalog: Schema and Taxonomy

The catalog (`catalog/commands.yaml`, built in Phase 1) is the single source of truth. Menus, the command palette, keybindings, help pages and tests are all generated from it.

## Record schema

```yaml
- id: page.edit-in-composer          # stable, dotted, lowercase
  label: "Edit Page"                  # default UI label
  aliases: ["Edit Page", "Compose", "Edit with Composer", "Edit in FrontPage"]
  category: page                      # see taxonomy below
  description: "Open the current page in the built-in WYSIWYG HTML editor."
  lineage:
    - { browser: "Netscape Communicator", versions: "4.0-4.8", menu: "File > Edit Page", year: 1997 }
    - { browser: "Internet Explorer", versions: "5-6", menu: "File > Edit with Microsoft FrontPage", year: 1999 }
    - { browser: "SeaMonkey", versions: "1.0+", menu: "File > Edit Page", year: 2006 }
  status: emulate                     # implement | emulate | stub | omit
  status_reason: "Composer retired; re-implemented as built-in editor."
  phase: 6
  platforms: [desktop]                # desktop | android
  shortcuts:
    default: null
    classic-netscape: "Ctrl+E"
  args: []                            # optional typed arguments for palette/macros
  checked_state: false                # true if it is a toggle
  requires: []                        # permissions/capabilities, e.g. [network, filesystem]
  layouts: [1999-suite, everything]   # era layouts that place it in a menu
  menu_path:
    1999-suite: "File/Edit Page"
    everything: "Page/Edit/Edit Page"
```

## Category taxonomy

| Category | Examples |
|---|---|
| `app` | New window, private window, quit, profiles, task manager |
| `file` | Open file/location, save as (all formats), print, page setup, send link, import/export |
| `edit` | Undo/redo, cut/copy/paste variants, select all, find, find again, preferences |
| `view` | Toolbars, sidebar, status bar, zoom, text size, full screen, encoding, page style, text-only, images on/off |
| `nav` | Back/forward/home/reload/stop, history menu, fast-forward, up one level, go to address |
| `tab` | New, close, duplicate, pin, mute, move, group, stack, tile, hibernate, reopen closed |
| `bookmark` | Add, manage, keywords, quickmarks, speed dial, reading list, feeds |
| `history` | Show, search, clear, sessions save/restore |
| `page` | Page info, view source, edit page, translate, reader, compare, diff since last visit, view as of… |
| `tools` | Downloads, extensions, DevTools, cookies/cache viewers, user agent, network report, macros |
| `privacy` | Shields/blockers, permissions, containers, clear data, Tor window |
| `input` | Gestures, rocker gestures, modal keys, hints, command line |
| `extract` | OCR, table to CSV, links/images list, bulk download, copy as citation/Markdown |
| `legacy` | Gopher, FTP, Flash (Ruffle), plugin stubs, channels |
| `module` | Notes, HTML editor, NNTP reader, IRC, feed reader |
| `help` | Help contents, keyboard reference, menu archaeology, about |

## Status definitions

- **implement**: native behavior on the current engine.
- **emulate**: original technology gone; equivalent behavior provided another way.
- **stub**: appears in the menu (in historic layouts and the palette) and opens an explanation of why it is unavailable (usually security).
- **omit**: catalogued for completeness, never shown (for example vendor-service links to defunct sites).
ANNES_EOF

cat > '.github/ISSUE_TEMPLATE/command-request.yml' <<'ANNES_EOF'
name: Command request
description: Propose a historic, current or new browser command for the catalog
labels: ["catalog"]
body:
  - type: input
    id: browser
    attributes:
      label: Browser and version (or "new")
      placeholder: "Opera 9.6 (Presto), Windows"
    validations:
      required: true
  - type: input
    id: menu_path
    attributes:
      label: Menu path / shortcut
      placeholder: "View > Fit to Width (Ctrl+F11)"
    validations:
      required: true
  - type: textarea
    id: behavior
    attributes:
      label: What it does
    validations:
      required: true
  - type: input
    id: source
    attributes:
      label: Source (manual, archived screenshot, source code link)
  - type: dropdown
    id: status
    attributes:
      label: Suggested treatment
      options: [implement, emulate, stub, omit, unsure]
ANNES_EOF

# 5. Commit
git init -q -b main 2>/dev/null || { git init -q; git checkout -q -b main; }
git add -A
git commit -q -m "Initial metadata: README, roadmap, cost estimate, catalog schema"
echo "Committed in $PROJECT_DIR:"; git log --oneline -1; ls -A

# 6. Publish to GitHub
if [ "${SKIP_GH:-0}" = "1" ]; then echo "SKIP_GH=1: not publishing."; exit 0; fi
gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol https --web
gh repo create "$GH_OWNER/$REPO_NAME" "--$VISIBILITY" --description "$DESCRIPTION" \
  --source=. --remote=origin --push
gh repo edit "$GH_OWNER/$REPO_NAME" --add-topic browser --add-topic web-browser \
  --add-topic electron --add-topic geckoview --add-topic command-palette || true
echo "Done: https://github.com/$GH_OWNER/$REPO_NAME"

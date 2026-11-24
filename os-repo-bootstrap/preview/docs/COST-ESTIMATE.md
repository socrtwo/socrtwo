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

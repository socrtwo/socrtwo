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

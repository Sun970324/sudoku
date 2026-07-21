---
name: verify
description: Build, launch, and drive this Flutter app for runtime verification (web target, headless Chrome + puppeteer-core).
---

# Verifying this app at runtime

Platforms: android, ios, web (no macos). For local verification use **web**.

## Launch

```bash
flutter run -d web-server --web-port 8787 --dart-define-from-file=config/secrets.json
```

- `--dart-define-from-file=config/secrets.json` is REQUIRED — without it
  `SupabaseConfig.assertConfigured()` throws at startup and the page stays blank.
- First page load takes ~10-15s in debug mode (DDC loads ~1200 scripts).

## Drive (headless Chrome + puppeteer-core)

No chromedriver/playwright on this machine. Working recipe: start a persistent
headless Chrome with `--remote-debugging-port=9333 --user-data-dir=<scratch>/chrome-profile
--window-size=470,1000`, then connect short scripts via
`puppeteer.connect({browserURL: 'http://127.0.0.1:9333'})` to click/screenshot.

Gotchas learned the hard way:

- **Do NOT call `page.setViewport()` before clicking.** Re-applying device
  metrics makes Flutter re-raster and board-cell taps silently miss while
  bigger buttons still work. Let the window size stand; clicks are in CSS px.
- A hard page reload breaks the `web-server` dev instance (assets start
  404ing: manifest.json, stack_trace_mapper.js). Restart `flutter run` and
  `goto` again. localStorage (SharedPreferences) survives in the fixed
  user-data-dir, so persistence checks still work across the restart.
- Fresh profile shows tutorial coach marks on home and game screens — dismiss
  via 건너뛰기 before driving.
- Screenshots read best without setViewport (1:1 CSS px). At 430px width:
  grid cells span x 6..425 / y 67..486 (cell ≈ 46.6px), controls row y≈645,
  input-mode segment y≈717, value pad y≈793, note pad y≈877.

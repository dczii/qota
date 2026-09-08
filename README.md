# Qota

A tiny macOS menu-bar app with an always-on-top HUD that shows remaining **plan quota** for:

- **Claude Code** — 5-hour and 7-day windows
- **Codex CLI** — 5-hour / weekly windows (and credits when present)
- **Cursor CLI** (same Cursor account as the editor) — included spend or request allowance

It is open source. Anyone can clone this repository, build it with Xcode, and run it locally. There is no App Store listing and no extra account to create.

Qota never sends tokens to a third-party server. It only reads the logins already on your Mac and calls each vendor’s own usage endpoint.

## Install from GitHub

You need a Mac with **macOS 14+** and **Xcode 15+**.

1. Clone this repo:

```bash
git clone https://github.com/dczii/qota.git
cd qota
```

2. Sign in to the tools you want to monitor (on this Mac):

```bash
claude auth login    # Claude Code
codex login          # Codex CLI
agent login          # Cursor CLI (or just be signed in to the Cursor app)
```

3. Build and run — pick one:

**Xcode**

```bash
open Qota.xcodeproj
```

Press **Run**. If signing asks for a team, choose your Personal Team. Qota appears in the **Dock** (three quota bars with a check) and in the menu bar. Click the Dock icon to show the HUD.

**Command line (installs to `~/Applications`)**

```bash
bash scripts/install.sh
```

Then launch `~/Applications/Qota.app`. To start it at login, use **Open at login** in the menu-bar popover.

## What you should see

- **Dock:** a bar-checker icon — three usage bars plus a check. Click it to bring the HUD forward.
- **Menu bar:** compact `Cl 34%  Cx 25%  Cu $12` (turns orange/red near the cap)
- **Floating HUD:** a small always-on-top panel you can drag. It stays above other apps and follows you across Spaces. Toggle it from the menu-bar popover.
- **Per-row states:** signed out, CLI not found, rate limited, or stale (last good numbers plus a reason)

Claude is polled slowly (about every 3 minutes) because Anthropic’s usage endpoint rate-limits aggressive clients. Codex and Cursor refresh about once a minute while the HUD is visible.

## How quota is read

| Tool | Local login | Source of the numbers |
| --- | --- | --- |
| Claude Code | `~/.claude/.credentials.json` or Keychain item `Claude Code-credentials` | `GET https://api.anthropic.com/api/oauth/usage` |
| Codex CLI | Codex’s own login (`~/.codex/auth.json`); Qota does not copy the token | `codex app-server` JSON-RPC `account/rateLimits/read` |
| Cursor | Cursor app `state.vscdb`, else CLI Keychain `cursor-access-token`, else `~/.cursor/auth.json` | `POST https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage`, with `/auth/usage` as fallback |

These vendor APIs are **undocumented and can change**. If a row fails after a CLI update, open an issue. App Sandbox is off on purpose so the app can read those local files.

The first Cursor CLI Keychain read may show a macOS permission prompt. Approve it once.

## Requirements

- macOS 14 Sonoma or later
- Xcode 15 or later (to build)
- At least one of: Claude Code, Codex CLI, Cursor / Cursor CLI, signed in on this Mac

A GUI app does not inherit your Homebrew/nvm `PATH`. Qota looks in common locations (`/opt/homebrew/bin`, `/usr/local/bin`, nvm, …) and a login shell for `codex` and `claude`.

## Privacy

- Tokens are read in memory and never written to Qota’s own files
- Network calls go only to Anthropic, OpenAI/ChatGPT (via Codex), and Cursor
- No analytics, no crash reporter, no account of our own

## License

[MIT](LICENSE)

Qota is not affiliated with Anthropic, OpenAI, or Cursor.

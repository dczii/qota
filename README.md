# Qota

A tiny macOS menu-bar app with an always-on-top HUD that shows remaining **plan quota** for:

- **Claude Code** — 5-hour and 7-day windows
- **Codex CLI** — 5-hour / weekly windows (and credits when present)
- **Cursor** (same account as the editor) — share of the current billing period used

It is open source. Clone it, build it, run it locally. There is no App Store listing, no installer to trust, and no account to create.

Qota never sends tokens to a third-party server. It only reads the logins already on your Mac and calls each vendor's own usage endpoint.

## Install

You need a Mac running **macOS 14 Sonoma or later**, with the **Xcode command line tools** (for the Swift 5.9+ toolchain). Check with `swift --version`; if that fails, run `xcode-select --install`.

```bash
git clone https://github.com/dczii/qota.git
cd qota
./scripts/install.sh
```

That is the whole install. The script builds a release binary with Swift Package Manager, wraps it in `~/Applications/Qota.app`, ad-hoc signs it, and launches it.

Qota has **no Dock icon** — look for it in the menu bar, on the right.

To install somewhere else, set `INSTALL_DIR`:

```bash
INSTALL_DIR=/Applications ./scripts/install.sh
```

To update later, `git pull` and run the script again. It replaces the existing copy. To uninstall, quit Qota from its popover and `rm -rf ~/Applications/Qota.app`.

### Signing in

Qota reads logins that already exist on your Mac; it never asks for credentials itself. Sign in to whichever tools you want to watch:

```bash
claude auth login   # Claude Code
codex login         # Codex CLI
agent login         # Cursor CLI, or just be signed in to the Cursor app
```

You do not need all three. Any tool you have not signed in to simply shows "signed out" in its row.

The first time Qota reads the Cursor CLI token, macOS may ask for Keychain permission. Approve it once.

### Developing

```bash
open Package.swift   # or: make open
```

Press **Run** in Xcode. Running the bare executable this way skips the app bundle, so **Open at login** is disabled in that mode — use `./scripts/install.sh` for a real install.

## What you should see

- **Menu bar:** a compact summary like `Cx 1%  Cu 23%`, which turns orange then red as a window approaches its cap
- **Floating HUD:** a small always-on-top panel you can drag anywhere. It stays above other apps and follows you across Spaces. Toggle it from the menu-bar popover
- **Last updated:** both the popover and the HUD show how old the numbers are, with a refresh button to fetch immediately
- **Per-row states:** signed out, CLI not found, rate limited, or stale (last good numbers plus the reason they did not update)

Claude is polled slowly, about every 3 minutes, because Anthropic's usage endpoint rate-limits aggressive clients. Codex and Cursor refresh about once a minute. A failed poll never overwrites good numbers — the row keeps the last reading and tells you why it is stale.

## How quota is read

| Tool | Local login | Source of the numbers |
| --- | --- | --- |
| Claude Code | `~/.claude/.credentials.json`, else Keychain item `Claude Code-credentials` | `GET https://api.anthropic.com/api/oauth/usage` |
| Codex CLI | Codex's own login (`~/.codex/auth.json`); Qota does not copy the token | `codex app-server` JSON-RPC `account/rateLimits/read` |
| Cursor | Cursor app `state.vscdb`, else CLI Keychain `cursor-access-token`, else `~/.cursor/auth.json` | `POST https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage`, with `/auth/usage` as fallback |

Anthropic reports plan quota only for subscription accounts. If your Claude Code login is an API key on an **API organization**, the usage endpoint answers `Usage limits are not applicable to API organizations`, and the Claude row says exactly that — there is no plan window to show. Sign in with a Pro or Max subscription and the row fills in.

These vendor APIs are **undocumented and can change**. If a row breaks after a CLI update, please open an issue. App Sandbox is off on purpose, so the app can read those local files.

## Requirements

- macOS 14 Sonoma or later
- Xcode 15 or later, or just the command line tools, for the Swift 5.9+ toolchain
- At least one of Claude Code, Codex CLI, or Cursor, signed in on this Mac

A GUI app does not inherit your Homebrew or nvm `PATH`. Qota looks in the usual places (`/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`, nvm, and others) and falls back to a login shell to find `codex` and `claude`.

## Privacy

- Tokens are read into memory and never written to Qota's own files
- Network calls go only to Anthropic, OpenAI/ChatGPT (via Codex), and Cursor
- No analytics, no crash reporter, no account of our own

## License

[MIT](LICENSE)

Qota is not affiliated with Anthropic, OpenAI, or Cursor.

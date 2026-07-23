# One Magic Mouse to Rule All Macs

Auto-reconnect a single Apple Magic Mouse across two or more Macs, without the
manual Bluetooth dance every time you switch machines.

## The problem

Apple's Magic Mouse only holds one Mac connection at a time. If you use one
mouse across several Macs (e.g. an office laptop and a home laptop), every switch
means digging into Bluetooth to reconnect it by hand.

This tool removes that step. A tiny background helper watches for the mouse and
reconnects it automatically the moment it's available, so you sit down and it
just works.

> Note on architecture: this is **not** a network "handoff" switcher (like
> [MegaManSec/magic-switch](https://github.com/MegaManSec/magic-switch), which
> needs both Macs powered on at the same desk on the same Wi-Fi). This runs
> independently on each Mac and only deals with its own machine, so it works
> even when the two Macs are in different locations and never on together.

## How it works

A small script checks every few seconds: *is the Magic Mouse connected?* If it's
paired and in range but not connected, it reconnects it. If it's already
connected, it does nothing. The mouse is matched **by name**, so a changed
Bluetooth address (which can happen after a re-pair) doesn't break it.

It's wired up as a macOS **launch agent** so it starts at login and runs quietly
in the background.

**How many Macs?** No limit. Nothing pairs the Macs to each other, each Mac runs
its own copy and only handles its own machine. Install it on as many Macs as you
like; whichever one you're sitting at grabs the mouse. (The mouse itself still
only connects to one Mac at a time, that's just how Bluetooth mice work.)

## Requirements

- macOS
- [Homebrew](https://brew.sh)
- The mouse must already be **paired** to the Mac (see the limitation below)

## Install

```bash
./install.sh
```

This installs `blueutil` (via Homebrew, if missing), copies the helper scripts
to `~/bin`, and loads the login agent. Run it once **on each Mac** you want the
behaviour on.

If `mouse-auto` isn't found afterwards, add `~/bin` to your `PATH`.

## Usage

The helper runs itself. You only need these when you want to control it:

```bash
mouse-auto off      # pause (e.g. you're on the trackpad, or left the mouse behind)
mouse-auto on       # resume — reconnects within ~3 seconds
mouse-auto status   # show current state (ON / PAUSED)
```

You usually won't need to pause it. If the mouse isn't around, the helper just
looks, finds nothing, and waits, no popups, no meaningful battery cost.

## Limitation (read this)

This only works when the Mac still **remembers** the mouse (it shows in the
Bluetooth list, just disconnected). That's the common case, and it's the whole
job this tool automates.

If a Mac ever **fully forgets** the mouse (drops it off the Bluetooth list
entirely, forcing a brand-new pairing), no software can fix that, because macOS
requires a fresh pairing to go through its own system dialog by hand. If that
keeps happening on a given Mac, the real fix is a multi-device mouse with a
hardware switch button (e.g. Logitech MX series), which stores both Macs on the
mouse itself.

## Uninstall

```bash
./uninstall.sh
```

Removes the agent and scripts. Leaves `blueutil` installed
(`brew uninstall blueutil` to remove it too).

## Future enhancements

- Menu-bar toggle (click instead of `mouse-auto on/off`)
- Auto-pause when the built-in trackpad is actively in use
- Optional support for Magic Trackpad / Magic Keyboard handoff
- Per-Mac config file (mouse name, poll interval)
- A signed, notarized menu-bar app version

## Credits

Grew out of evaluating whether a LAN handoff switcher could solve a two-location,
one-mouse setup (it couldn't) and landing on a simpler per-Mac auto-reconnect.

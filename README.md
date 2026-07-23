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

## Design notes

Decisions worth not re-litigating later:

- **Always-on polling, not event-driven.** IOBluetooth *does* expose device-connect
  notifications (`IOBluetoothRegisterForDeviceConnectNotifications`), so "macOS has no
  events" would be wrong. But those fire only *after* a connection is established — they
  answer "did something just connect?", not the question we need: "is the mouse in range
  and connectable, so I should try now?" For a classic-Bluetooth HID that isn't currently
  connected to this Mac, nothing on the Mac spontaneously starts a connection — our tool is
  the only initiator. So there's no push signal for *when* to try; the only way to find out
  is to attempt it. Hence polling — not for lack of any event, but because no event exists
  for the half that matters (in-range-and-available), since we're the one initiating the attempt.

- **The 3-second check is cheap; the *reconnect attempt* is the part that isn't.**
  While the mouse is connected, each check just asks macOS for the state it already
  tracks — no transmission, no radio, no mouse-battery cost; featherweight, on the order
  of the countless background timers macOS already runs. But the logs revealed the opposite
  for the away case: while the mouse is disconnected *and* out of range, `blueutil --connect`
  blocks ~15s on the radio chasing an absent device (failed attempts land ~18s apart, not
  3s). So the thing to throttle is the *attempts*, not the glance — hence the attempt-backoff
  (see Future enhancements), which throttles failing connects and resets on success and on
  wake. (An earlier event-driven "wake on menu-bar click, poll 3 min, sleep" idea was dropped:
  it optimises the already-free glance and reintroduces a manual click.)

- **The mouse is matched by name, not a fixed address.** A Magic Mouse's
  Bluetooth address can change on a re-pair; matching by name survives that.

- **Bluetooth permission is a manual, one-time, per-Mac step.** `blueutil` needs
  access under System Settings > Privacy & Security > Bluetooth. A background
  script can't trigger the permission prompt itself, so it must be enabled by
  hand once on each Mac. The startup log line (`Bluetooth access OK` / `DENIED`)
  reports which state you're in.

## Future enhancements

- **Reconnect-attempt backoff (agreed, next up).** Keep the ~3s glance, but gate the
  expensive `--connect` on wall-clock elapsed time (`now - last_attempt >= interval`),
  growing the interval on failure (3s → ×2 → cap ~30s) and resetting it to 3s whenever the
  mouse is observed connected. Timestamp-gated, not sleep-based, so process suspension /
  App Nap / sleep-wake can't leave it stuck (a long gap just reads as "time to try"), and no
  explicit wake-detection is needed. Overridable via `MAGIC_MOUSE_MAX_BACKOFF`.
- Menu-bar toggle (click instead of `mouse-auto on/off`)
- Auto-pause when the built-in trackpad is actively in use
- Optional support for Magic Trackpad / Magic Keyboard handoff
- Per-Mac config file (mouse name, poll interval)
- A signed, notarized menu-bar app version

## Credits

Grew out of evaluating whether a LAN handoff switcher could solve a two-location,
one-mouse setup (it couldn't) and landing on a simpler per-Mac auto-reconnect.

# Input method: Shift to toggle Chinese / English

Goal: on a Chinese input method (fcitx5 + Rime), use the Shift keys as quick
toggles the way fcitx5's built-in pinyin behaves:

- **Tap either Shift** → toggle between Chinese and English input.
- **Hold a Shift + letter** → normal capital letter (Shift keeps its modifier
  role; no accidental toggles).
- **Both Shifts together** → toggle Caps Lock.
- **Ctrl+Space** → still toggles the whole input method on/off.

This file documents why that is not a plain fcitx5 setting, and the three-layer
solution that makes it work on Hyprland.

## Why fcitx5's own Shift toggle fails on Hyprland

fcitx5 has a built-in "alternate trigger" that maps a lone Shift press to an
input-method toggle:

```ini
[Hotkey/AltTriggerKeys]
0=Shift_L
```

This is enabled by default and works on X11, but **on Hyprland/Wayland it is
unreliable**: the modifier-only press-and-release pattern a real keyboard
produces does not consistently reach fcitx5's detection. A normal chord
(`Ctrl+Space`) reaches fcitx5 fine; a bare modifier key does not. This is a
known compositor/input-method-path limitation, not a config mistake.

Rime adds a second layer: librime's `ascii_composer` also binds Shift to its own
Chinese/English switch. With both fcitx5's `AltTriggerKeys` and Rime's
`ascii_composer` claiming Shift, the behaviour is inconsistent and neither
reliably wins.

So Shift handling cannot live in fcitx5 or Rime. It has to be intercepted one
level down, at the evdev layer, **before the compositor** — which is what `keyd`
does.

## The solution (three layers)

### 1. keyd — evdev-level Shift handling

`/etc/keyd/default.conf`:

```ini
[ids]
*

[global]
# Window (ms) in which the two Shift keys form the Caps-Lock chord.
chord_timeout = 250

[main]
# Both Shifts together (overlapping) -> CapsLock.
leftshift+rightshift = capslock
# Tap = F13 (IME toggle), hold = Shift modifier.
leftshift = overload(shift, f13)
rightshift = overload(shift, f13)
```

keyd runs as a system service (`keyd.service`) and grabs the physical keyboards,
so it sees every real key event before Hyprland. It distinguishes:

- **tap** (press+release, no other key) → emits `F13`
- **hold** (another key pressed while held) → emits the Shift modifier
- **both shifts** (chord) → emits `CapsLock`

### 2. Hyprland — F13 → toggle the input method

`~/.config/hypr/bindings.lua`:

```lua
o.bind("XF86Tools", "Toggle input method", "fcitx5-remote -t")
```

Two things to note:

- The binding key is **`XF86Tools`, not `F13`**. keyd emits F13 as keycode 183
  (FK13), and xkeyboard-config maps keycodes FK13–FK24 to the `XF86Tools` /
  `XF86Launch*` keysyms rather than the plain `F13`–`F24` keysyms. Binding by
  `F13` never matches; binding by `XF86Tools` does.
- The action is `fcitx5-remote -t`, which toggles the active input method. It is
  driven by Hyprland's keybind system, which definitely receives normal keys
  (unlike fcitx5's modifier-only path).

### 3. kb_options — CapsLock is a real Caps Lock again

`~/.config/hypr/input.lua`:

```lua
hl.config({
  input = {
    kb_options = "shift:both_capslock_cancel",
  },
})
```

Omarchy's default sets `compose:caps` (CapsLock is the Compose key, and Caps
Lock lives on "both Shifts" via `shift:both_capslock_cancel`). With keyd
emitting a `CapsLock` key for the both-Shifts gesture, the CapsLock keysym must
actually toggle Caps Lock, so `compose:caps` is removed.

### Hygiene settings (removed conflicts)

- `~/.config/fcitx5/config`: `[Hotkey/AltTriggerKeys]` cleared (`0=`), so fcitx5
  never competes with keyd for a bare Shift. `ModifierOnlyKeyTimeout=1000` is
  left in place but is inert without an AltTriggerKey.
- `~/.local/share/fcitx5/rime/default.custom.yaml`: Rime's `ascii_composer`
  `switch_key` for Shift set to `noop`, so Rime also never claims Shift:

  ```yaml
  patch:
    schema_list:
      - schema: luna_pinyin_simp
    ascii_composer/switch_key/Shift_L: noop
    ascii_composer/switch_key/Shift_R: noop
  ```

  Redeploy Rime (fcitx5 restarts trigger deployment).

## Why the both-Shifts gesture needs a chord, not XKB's option

XKB's `shift:both_capslock*` works by giving each Shift a `TWO_LEVEL` type whose
second level is `Caps_Lock`, triggered by the *other* Shift being held. That
requires the two Shift presses to **overlap** at the XKB level.

keyd cannot produce overlapping Shifts: while processing the second Shift it
calls `update_mods`, which recomputes the active modifiers with the current
layer excluded and *releases* the first Shift's modifier first. So a keyd
remap that emits "left Shift then right Shift" always arrives at Hyprland as
two non-overlapping presses and the XKB combo never fires.

The fix is to bypass XKB's combo entirely: a keyd **chord**
(`leftshift+rightshift = capslock`) emits a single `CapsLock` key event, which
Hyprland/XKB turns into a Caps Lock toggle directly. Chords are matched before
normal key and layer lookups, so the detection is reliable and does not depend
on layer priority.

## Behaviour summary

| Input | Result |
|-------|--------|
| Tap either Shift | Toggle Chinese ↔ English |
| Hold Shift + letter | Capital letter |
| Both Shifts together | Toggle Caps Lock |
| CapsLock physical key | Toggle Caps Lock (no longer Compose) |
| Ctrl+Space | Toggle input method on/off |

## Key event flow

```
tap Shift ──► keyd ──► F13 (keycode 183) ──► Hyprland maps to XF86Tools
                  ──► binding fires ──► fcitx5-remote -t ──► IME toggles

both Shifts ──► keyd chord ──► CapsLock ──► XKB ──► Caps Lock toggles

hold Shift + letter ──► keyd ──► Shift modifier + letter ──► capital
```

## Reverting

- Remove the keyd config and stop keyd: `sudo systemctl disable --now keyd`.
- Remove the `o.bind("XF86Tools", …)` line from `~/.config/hypr/bindings.lua`.
- Restore `compose:caps` in `~/.config/hypr/input.lua` (or refresh:
  `omarchy refresh config hypr/input.lua`).
- fcitx5/Rime settings can be restored from the backups made while applying this
  (`config.bak.*`, `default.custom.yaml.bak.*`).

## Testing notes

- **keyd ignores injected/virtual devices.** `wtype`, uinput scripts, and other
  synthetic key tools are not seen by keyd (it only grabs real keyboards), so
  keyd's Shift behaviour can only be verified with a physical keyboard. The
  F13→Hyprland→fcitx5 half *can* be verified by injecting keycode 183.
- The systemd user unit `omarchy-fcitx5.service` runs fcitx5 (restart it with
  `omarchy restart xcompose`); it is what restarts fcitx5 after config changes.

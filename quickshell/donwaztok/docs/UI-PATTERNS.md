# UI and performance patterns — Donwaztok

Short, binding rules for building and changing shell surfaces. Requirements behind them live in
`openspec/specs/` (`shell-performance`, `design-system`). When this file and a spec disagree, the spec wins.

## 1. Pick the design system

All UI uses the **caelestia** side. The end-4 widget set is gone; `modules/common` keeps only
non-visual helpers. Options without a typed section are read with `Config.shellOptions?.<path> ?? <default>`
from `qs.config` (the default must match `config/DonwaztokConfigStore.qml`).

| Need | Use |
|---|---|
| Surface / card | `StyledRect`, `StyledClippingRect` (`qs.components`) |
| Text, icon | `StyledText`, `MaterialIcon` (sizes in `font.pointSize`; setting `pixelSize` too logs a warning) |
| Hover / press feedback | `StateLayer` |
| Buttons, switches, sliders, fields | `qs.components.controls` (`IconButton`, `TextButton`, `ToggleButton`, `StyledSwitch`, `StyledSlider`, `StyledTextField`…) |
| Lists, scroll | `StyledListView`, `StyledFlickable`, `StyledScrollBar` |
| Animation | `Anim` / `CAnim` with `Appearance.anim.durations.*` and `.curves.*` |
| Toast | `Toaster.toast(title, message, icon, Toast.Error)` |
| Config | `Config.<section>.<key>` (`qs.config`), persist with `Config.save()` |

Do not import both `qs.modules.common` and `qs.components` styling into one new file.

## 2. Colour, size, spacing

- Colours only from `Colours.palette.m3*` (opaque) or `Colours.tPalette.m3*` (surfaces that follow the
  transparency setting). No hex, no `Qt.rgba` literals; a hex value is allowed only as a `?? "#…"` fallback.
  Most used: `m3onSurface`, `m3onSurfaceVariant`, `m3primary`, `m3outline(Variant)`, `m3surfaceContainer(High)`, `m3error`.
- Text on a coloured fill uses its `m3on*` pair (`m3primary` → `m3onPrimary`).
- Spacing, padding, rounding and font sizes come from `Appearance.spacing|padding|rounding|font.size.*`.
- Status is never colour alone: icon + text (`m3error` icon plus a message).
- Check every change in the light and the dark scheme; the wallpaper drives the palette, so also try one
  saturated and one grey wallpaper.

## 3. States

Every surface that loads data shows three states: loading (`CircularIndicator` or muted text), error
(`m3error` icon + text, with a retry when one makes sense), and empty (an explicit message, never a blank
area). User actions that can fail end in a toast either way.

## 4. Performance (idle cost first)

The shell runs all day; idle cost matters more than peak cost.

- **Polling stops when nobody looks.** Timers and `Process` polls run only while a consumer is visible:
  `running: root.refCount > 0` (see `services/shell/SystemUsage.qml`) or bound to the surface's visibility.
  Prefer event sources (`nmcli monitor`, `FileView { watchChanges: true }`, Hyprland events, UPower/DBus
  signals) over timers.
- **Debounce event streams.** A monitor that prints many lines per change refreshes once per burst
  (`Timer { interval: 300 }` restarted on each line; see `monitorDebounce` in `services/shell/Nmcli.qml`).
- **Match the clock to the display.** `SystemClock` precision follows the finest unit shown
  (`services/shell/Time.qml` is `Minutes`). Values shown in minutes are not polled every few seconds.
- **No always-on layers.** `layer.enabled` (and `OpacityMask`/`MultiEffect` on it) costs an offscreen
  texture and a re-render on every change. Enable it only while the effect is visible
  (e.g. `layer.enabled: ripple.opacity > 0` for a ripple clipped by a mask). The full-screen shadow layer in
  `modules/drawers/Drawers.qml` is the one accepted exception.
- **Infinite animations are gated.** `loops: Animation.Infinite` always has a `running:` bound to a state
  that becomes false, and the item is invisible when it is.
- **Load lazily, unload when hidden.** Drawers follow the `Wrapper.qml` pattern (Loader active only while
  open or animating). Standalone apps (file manager, text editor, control center) are created with
  `createObject` on demand and destroyed on close. Use `LazyLoader`/`Loader { active: … }` for rarely shown
  surfaces.
- **Images are decoded at display size.** Use `CachingImage` for wallpapers and file previews; plain
  `Image` sets `sourceSize` and `asynchronous: true`.
- **Delegates are light.** No `layer`, `MultiEffect` or `Process` inside a `ListView`/`Repeater` delegate;
  hoist them to the view or the service.
- **One owner per external stream.** Do not start a second `nmcli monitor`, `pactl subscribe` or similar
  in another service; expose a signal from the owner instead.

## 5. Verification

After the hot reload: `qs log -c donwaztok | tail -50` has no new warning or error for the touched files.
Open the surface by its shortcut (`hyprctl dispatch 'hl.dsp.global("donwaztok:<name>")'`, names in
`modules/Shortcuts.qml`) or IPC (`qs ipc -c donwaztok show`) and check light and dark.
For idle-cost changes, compare per-thread CPU of the `qs` process before and after over 20 s of idle.

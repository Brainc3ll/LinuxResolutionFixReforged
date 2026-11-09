# Linux Resolution Fix Reforged

Fork of LinuxResolutionFix by **maqisha** (MIT), extended to every official WoW client and to all of the game's languages.

**If your resolution is not wrongly set to "Custom" on launch, this addon is not for you.**

## The bug

On some Linux setups (Wine / Proton / Lutris / Heroic, GNOME, Wayland…):

1. You launch the game.
2. The game is not truly fullscreen (top bar / taskbar still visible).
3. In the settings, the resolution shows "Custom" while in "Windowed (Fullscreen)".
4. Setting your native resolution fixes it…
5. …until the next launch.

The addon compares the current window size with the target resolution at login and
shows a **Fix Resolution** button if they differ.

When Windowed (Fullscreen) is enabled (`gxMaximize=1`) and the client provides the
mode-change functions, the button briefly switches to a window at 80% of the target
size, then restores fullscreen. This works around setups where resizing alone leaves
the desktop's top bar visible. The target is captured before resizing. The operation
takes about two seconds, during which the button is disabled.

In Windowed mode, or without the mode-change functions, the button only resizes the
window. Afterward, the addon checks against the captured target and reports the
result in chat. If the size still differs, the button becomes available for another
attempt. If a display API fails during the fullscreen transition, the addon reports
the error and attempts to restore both the fullscreen mode and the target size.
Recovery cannot be guaranteed if the client keeps rejecting display changes.

The fullscreen workaround has been confirmed in WoW: Forever on Ubuntu/GNOME,
using Proton's X11 driver through XWayland. Other desktop/client combinations still
need in-game testing. The addon checks the reported resolution; it cannot inspect
the desktop's top bar or guarantee that the window manager has hidden it.

## Features

- **All official clients**: Midnight (Retail), Mists of Pandaria Classic, Burning Crusade Classic, Classic Era / Anniversary, WoW: Forever, plus their test realms. The addon picks the available API at runtime; if a client lacks it, the addon prints a message and stays inactive.
- **All 11 game languages**: enUS/enGB, frFR, deDE, esES, esMX, itIT, ptBR, ruRU, koKR, zhCN, zhTW.
- **`/lrf`** slash command to re-check the resolution manually.

## Updating for a new patch

Add the client's interface number to the `## Interface:` line of the `.toc` (comma-separated). In game:

```
/dump select(4, GetBuildInfo())
```

## Installation

Copy the `LinuxResolutionFixReforged` folder into `World of Warcraft/<game version folder>/Interface/AddOns/` (e.g. `_retail_`, `_classic_`, `_classic_era_`).

## Development checks

From the repository root, with Lua 5.1 and luacheck installed:

```sh
luacheck .
lua5.1 tests/run.lua
```

The tests load the addon with a mocked WoW API and cover the asynchronous fullscreen
transition, duplicate clicks and resize events, windowed mode, API/timer fallbacks,
error recovery, and translation completeness and format placeholders. They do not
simulate Wine, GNOME, or a physical display. In-game testing is still required to
confirm that the desktop top bar disappears. CI runs both commands; test files are
excluded from release packages.

## Credits

Original idea and code: maqisha — LinuxResolutionFix (MIT License).

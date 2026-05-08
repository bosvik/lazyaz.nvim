# lazyaz.nvim

Run [`lazyaz`](https://github.com/karlssonsimon/lazyaz) inside a Neovim
floating terminal.

Use the amazing Azure TUI from the comfort of your favourite editor, without
switching context away from the project you are already working in.

The terminal process stays alive when the popup is hidden. Reopening the popup
is instant and preserves lazyaz state such as selection, tabs, scrollback, and
subscription state.

## Requirements

- Neovim `>= 0.10`
- `lazyaz` available on `PATH`
- Azure CLI `az`

## Installation

Example using `lazy.nvim`:

```lua
{
  "bosvik/lazyaz.nvim",
  opts = {
    download_dir = "downloads",
    window = {
      width = 0.9,
      height = 0.9,
      border = "rounded",
      winblend = 0,
      title = " lazyaz ",
    },
  },
  keys = {
    { "<leader>A", "", desc = "+Lazyaz" },
    {
      "<leader>Aa",
      "<cmd>LazyazToggle root<cr>",
      desc = "Toggle Lazyaz (root)",
      mode = { "n", "t" },
    },
    {
      "<leader>AA",
      "<cmd>LazyazToggle global<cr>",
      desc = "Toggle Lazyaz (global)",
      mode = { "n", "t" },
    },
    {
      "<leader>Ac",
      "<cmd>LazyazConfig root<cr>",
      desc = "Open config (root)",
    },
    {
      "<leader>AC",
      "<cmd>LazyazConfig global<cr>",
      desc = "Open config (global)",
    },
  },
}
```

The plugin creates no default keymaps. Map the commands yourself, preferably in
both normal and terminal mode so the same mapping can hide the popup from inside
lazyaz.

## Configuration

Defaults:

```lua
{
  download_dir = nil,
  window = {
    width = 0.9,
    height = 0.9,
    border = "rounded",
    winblend = 0,
    title = " lazyaz ",
  },
  on_open = function() end,
  on_hide = function() end,
  on_exit = function(code) end,
}
```

`download_dir` is only applied in root mode. Relative strings are resolved under
the detected project root. Absolute paths are used as-is. A function receives
the resolved root and must return a string.

```lua
opts = {
  download_dir = "downloads",
}
```

For a root like `/Users/me/code/project`, that resolves to:

```text
/Users/me/code/project/downloads
```

## Commands

- `:LazyazToggle [global|root]`
- `:LazyazOpen [global|root]`
- `:LazyazHide [global|root]`
- `:LazyazFocus [global|root]`
- `:LazyazClose [global|root]`
- `:LazyazConfig [global|root]`

All commands accept an optional scope. Empty scope, or `global`, selects the
global instance. `root` selects the project-root instance. Invalid scopes are
rejected and do not create an instance.

Command completion offers `global` and `root`.

## Global Mode

Global mode is used by default:

```vim
:LazyazToggle
```

It creates one lazyaz process keyed as global. The working directory is captured
from `:pwd` at first launch. Later toggles reuse the same process and do not
re-evaluate the current directory.

Global mode uses lazyaz's real config directory and does not build an overlay.

## Root Mode

Root mode is selected with the `root` argument:

```vim
:LazyazToggle root
```

The plugin detects the project root with `vim.fs.root(0, ".git")`. If root
detection fails, it silently falls back to the current working directory.

Root mode creates one lazyaz process per detected root. Opening one instance
hides any other visible lazyaz popup, but the hidden process keeps running.

## download_dir Overlay

lazyaz reads `download_dir` from:

```text
$XDG_CONFIG_HOME/lazyaz/config.json
```

It has no CLI flag or environment variable for this setting. To avoid mutating
your real lazyaz config, root mode can build a per-root XDG config overlay under
Neovim's cache directory:

```text
stdpath("cache")/lazyaz.nvim/<root-hash>/lazyaz/config.json
```

When `opts.download_dir` is set, lazyaz is started with `XDG_CONFIG_HOME`
pointing at that overlay parent. The overlay config receives the resolved
`download_dir`, while your real lazyaz `config.json` is left untouched.

Only root mode uses this overlay. Global mode always uses the real lazyaz
config.

`:LazyazConfig global` opens the real lazyaz `config.json`. `:LazyazConfig root`
opens the per-root overlay config, which is useful for workspace-specific lazyaz
settings such as theme changes.

## Lifecycle

`:LazyazToggle` starts lazyaz in a centered floating window. Toggling again hides
the window only; the terminal buffer and job remain alive. Toggling a third time
reattaches the same buffer and job.

`:LazyazClose` terminates the lazyaz job and removes the instance. The next open
starts a fresh process.

If the popup is closed manually with `:q` or `<C-w>q`, the plugin treats that as
a hide event. The lazyaz process remains alive.

If lazyaz exits quickly with an error, the buffer may be retained so the error
stays visible. The next open, focus, or toggle restarts the process.

## Callbacks

Callbacks are optional:

```lua
opts = {
  on_open = function() end,
  on_hide = function() end,
  on_exit = function(code) end,
}
```

`on_open` fires after the float is configured. `on_hide` fires when a visible
popup is intentionally hidden or manually closed. `on_exit` fires once per job
exit with the exit code.

Callback errors are caught and reported without breaking terminal cleanup or
startup.

## Health Check

Run:

```vim
:checkhealth lazyaz
```

The health check reports Neovim compatibility, whether `lazyaz` is on `PATH`,
Azure CLI availability, Azure login status, and the real lazyaz config path.

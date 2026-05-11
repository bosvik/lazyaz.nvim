# lazyaz.nvim

Run [`lazyaz`](https://github.com/karlssonsimon/lazyaz) inside a Neovim
floating terminal.

The plugin is intentionally small: it toggles one lazyaz terminal and opens the
lazyaz config file. Lazyaz itself owns Azure subscriptions, tabs, themes, and
download settings through its normal config file.

## Requirements

- Neovim `>= 0.10`
- `lazyaz` available on `PATH`
- Azure CLI `az`
- `tmux` only when `opts.mux.enabled = true`

## Installation

Example using `lazy.nvim`:

```lua
{
  "bosvik/lazyaz.nvim",
  opts = {
    mux = {
      enabled = false,
    },
    keys = {
      hide = "<c-x>",
    },
  },
  keys = {
    { "<leader>A", "<cmd>LazyazToggle<cr>", desc = "Toggle Lazyaz" },
    { "<leader>Ac", "<cmd>LazyazConfig<cr>", desc = "Open Lazyaz config" },
  },
}
```

The plugin creates no global keymaps. Map the commands yourself. Inside the
lazyaz terminal, `opts.keys.hide` installs a buffer-local mapping so the key is
handled by Neovim before it reaches the lazyaz TUI.

## Configuration

Defaults:

```lua
{
  mux = {
    enabled = false,
  },
  keys = {
    hide = "<c-x>",
  },
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

Set `keys.hide = false` to disable the buffer-local hide mapping.

## Commands

- `:LazyazToggle`
- `:LazyazConfig`

`:LazyazToggle` starts lazyaz in a centered floating terminal. Toggling again
hides the window only; the terminal buffer and job remain alive. Toggling a
third time reopens the same buffer and job.

`:LazyazConfig` opens lazyaz's config file:

```text
$XDG_CONFIG_HOME/lazyaz/config.json
```

When `XDG_CONFIG_HOME` is unset, it falls back to:

```text
~/.config/lazyaz/config.json
```

The file is created as `{}` when it does not exist.

## Tmux

Enable tmux mux mode to keep the lazyaz session alive outside Neovim:

```lua
opts = {
  mux = {
    enabled = true,
  },
}
```

When mux mode is enabled, lazyaz starts through a fixed tmux session named
`lazyaz.nvim`:

```text
tmux new -A -s lazyaz.nvim -c <cwd> lazyaz
```

`opts.window` still controls the Neovim floating layout.

## Lazyaz Config

Configure lazyaz itself in `~/.config/lazyaz/config.json` or
`$XDG_CONFIG_HOME/lazyaz/config.json`.

Example:

```json
{
  "theme": "Default Dark",
  "download_dir": "~/Downloads",
  "tabs": [
    { "kind": "blob", "subscription": "<subscription-id>" },
    { "kind": "servicebus", "subscription": "<subscription-id>" },
    { "kind": "keyvault" }
  ]
}
```

## Health Check

Run:

```vim
:checkhealth lazyaz
```

The health check reports Neovim compatibility, whether `lazyaz` is on `PATH`,
Azure CLI availability, Azure login status, tmux availability, and the lazyaz
config path.

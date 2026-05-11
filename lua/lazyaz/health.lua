local config = require("lazyaz.config")

local M = {}

local function health()
  return vim.health or require("health")
end

function M.check()
  local h = health()
  h.start("lazyaz.nvim")
  if vim.fn.has("nvim-0.10") == 1 then
    h.ok("Neovim >= 0.10")
  else
    h.error("Neovim >= 0.10 is required")
  end

  if vim.fn.executable("lazyaz") == 1 then
    h.ok("lazyaz executable found")
  else
    h.error("lazyaz executable not found. Install from https://github.com/karlssonsimon/lazyaz#install")
  end

  if vim.fn.executable("az") == 1 then
    h.ok("Azure CLI found")
    local result = vim.system({ "az", "account", "show" }, { text = true }):wait(5000)
    if result.code == 0 then
      h.ok("Azure CLI is logged in")
    else
      h.warn("Azure CLI is not logged in; run `az login`")
    end
  else
    h.warn("Azure CLI not found")
  end

  if vim.fn.executable("tmux") == 1 then
    if config.get().mux.enabled then
      h.ok("tmux found")
    else
      h.info("tmux found; enable opts.mux.enabled to persist sessions")
    end
  elseif config.get().mux.enabled then
    h.error("tmux not found. Install tmux or disable opts.mux.enabled")
  else
    h.info("tmux not found; only needed when opts.mux.enabled is true")
  end

  local dir = config.real_config_dir()
  local stat = vim.uv.fs_stat(dir)
  if not stat then
    h.info("lazyaz config directory will be created on first run: " .. dir)
  elseif stat.type == "directory" then
    h.ok("lazyaz config directory exists: " .. dir)
  else
    h.warn("lazyaz config path is not a directory: " .. dir)
  end
end

return M

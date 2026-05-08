local M = {}

local defaults = {
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
  on_exit = function() end,
}

local current = vim.deepcopy(defaults)

local function notify(msg, level)
  vim.notify("lazyaz.nvim: " .. msg, level or vim.log.levels.WARN)
end

local function validate_download_dir(value)
  if value == nil or type(value) == "function" then
    return value
  end
  if type(value) == "string" and value ~= "" then
    return value
  end
  notify("invalid download_dir; using default")
  return defaults.download_dir
end

local function validate_window(window)
  local merged = vim.tbl_deep_extend("force", defaults.window, type(window) == "table" and window or {})
  if type(merged.width) ~= "number" or merged.width <= 0 then
    notify("invalid window.width; using default")
    merged.width = defaults.window.width
  end
  if type(merged.height) ~= "number" or merged.height <= 0 then
    notify("invalid window.height; using default")
    merged.height = defaults.window.height
  end
  if type(merged.border) ~= "string" and type(merged.border) ~= "table" then
    notify("invalid window.border; using default")
    merged.border = defaults.window.border
  end
  if type(merged.winblend) ~= "number" then
    notify("invalid window.winblend; using default")
    merged.winblend = defaults.window.winblend
  else
    merged.winblend = math.floor(merged.winblend)
  end
  if type(merged.title) ~= "string" then
    notify("invalid window.title; using default")
    merged.title = defaults.window.title
  end
  return merged
end

local function validate_callback(opts, name)
  if opts[name] == nil then
    return defaults[name]
  end
  if type(opts[name]) == "function" then
    return opts[name]
  end
  notify("invalid " .. name .. "; using default")
  return defaults[name]
end

function M.setup(opts)
  opts = opts or {}
  if type(opts) ~= "table" then
    notify("setup opts must be a table; using defaults")
    opts = {}
  end

  local merged = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)
  merged.download_dir = validate_download_dir(merged.download_dir)
  merged.window = validate_window(merged.window)
  merged.on_open = validate_callback(merged, "on_open")
  merged.on_hide = validate_callback(merged, "on_hide")
  merged.on_exit = validate_callback(merged, "on_exit")
  current = merged
  return current
end

function M.get()
  return current
end

function M.real_config_dir()
  local xdg = vim.env.XDG_CONFIG_HOME
  if xdg and xdg ~= "" then
    return vim.fs.joinpath(xdg, "lazyaz")
  end
  return vim.fs.joinpath(vim.fn.expand("~"), ".config", "lazyaz")
end

function M.normalize_scope(scope)
  if scope == nil or scope == "" or scope == "global" then
    return "global"
  end
  if scope == "root" then
    return "root"
  end
  notify("invalid scope " .. vim.inspect(scope), vim.log.levels.ERROR)
  return nil
end

function M._test_reset()
  current = vim.deepcopy(defaults)
end

M._test = { defaults = defaults, notify = notify }

return M

local config = require("lazyaz.config")

local M = {}

local function with_scope(scope, fn)
  local normalized = config.normalize_scope(scope)
  if not normalized then
    return nil
  end
  return fn(normalized)
end

function M.setup(opts)
  return config.setup(opts)
end

function M.toggle(scope)
  return with_scope(scope, function(normalized)
    return require("lazyaz.terminal").toggle(normalized)
  end)
end

function M.open(scope)
  return with_scope(scope, function(normalized)
    return require("lazyaz.terminal").open(normalized)
  end)
end

function M.hide(scope)
  return with_scope(scope, function(normalized)
    return require("lazyaz.terminal").hide(normalized)
  end)
end

function M.focus(scope)
  return with_scope(scope, function(normalized)
    return require("lazyaz.terminal").focus(normalized)
  end)
end

function M.close(scope)
  return with_scope(scope, function(normalized)
    return require("lazyaz.terminal").close(normalized)
  end)
end

function M.is_open(scope)
  return with_scope(scope, function(normalized)
    return require("lazyaz.terminal").is_open(normalized)
  end) or false
end

function M.is_running(scope)
  return with_scope(scope, function(normalized)
    return require("lazyaz.terminal").is_running(normalized)
  end) or false
end

local function edit_config(path)
  local dir = vim.fs.dirname(path)
  vim.fn.mkdir(dir, "p")
  if vim.fn.filereadable(path) == 0 then
    vim.fn.writefile({ "{}" }, path)
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
end

function M.config_edit(scope)
  return with_scope(scope, function(normalized)
    if normalized == "global" then
      edit_config(vim.fs.joinpath(config.real_config_dir(), "config.json"))
      return
    end

    local terminal = require("lazyaz.terminal")
    local root = terminal.root_dir()
    local path = require("lazyaz.overlay").config_path(root, config.get().download_dir)
    if path then
      edit_config(path)
    end
  end)
end

return M

local config = require("lazyaz.config")

local M = {}

function M.setup(opts)
  return config.setup(opts)
end

function M.toggle()
  return require("lazyaz.terminal").toggle()
end

function M.hide_current()
  return require("lazyaz.terminal").hide_current()
end

function M.is_open()
  return require("lazyaz.terminal").is_open()
end

function M.is_running()
  return require("lazyaz.terminal").is_running()
end

local function edit_config(path)
  local dir = vim.fs.dirname(path)
  vim.fn.mkdir(dir, "p")
  if vim.fn.filereadable(path) == 0 then
    vim.fn.writefile({ "{}" }, path)
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
end

function M.config_edit()
  edit_config(vim.fs.joinpath(config.real_config_dir(), "config.json"))
end

return M

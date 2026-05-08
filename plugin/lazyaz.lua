if vim.g.loaded_lazyaz_nvim then
  return
end
vim.g.loaded_lazyaz_nvim = true

if vim.fn.has("nvim-0.10") ~= 1 then
  vim.notify("lazyaz.nvim: Neovim >= 0.10 is required", vim.log.levels.ERROR)
  return
end

local function complete(arglead)
  return vim.tbl_filter(function(item)
    return item:sub(1, #arglead) == arglead
  end, { "global", "root" })
end

local function command(name, method)
  vim.api.nvim_create_user_command(name, function(opts)
    require("lazyaz")[method](opts.args)
  end, { nargs = "?", complete = complete })
end

command("LazyazToggle", "toggle")
command("LazyazOpen", "open")
command("LazyazHide", "hide")
command("LazyazFocus", "focus")
command("LazyazClose", "close")

vim.api.nvim_create_user_command("LazyazConfig", function(opts)
  require("lazyaz").config_edit(opts.args)
end, { nargs = "?", complete = complete })

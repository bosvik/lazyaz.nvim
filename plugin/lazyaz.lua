if vim.g.loaded_lazyaz_nvim then
  return
end
vim.g.loaded_lazyaz_nvim = true

if vim.fn.has("nvim-0.10") ~= 1 then
  vim.notify("lazyaz.nvim: Neovim >= 0.10 is required", vim.log.levels.ERROR)
  return
end

vim.api.nvim_create_user_command("LazyazToggle", function()
  require("lazyaz").toggle()
end, {})

vim.api.nvim_create_user_command("LazyazConfig", function()
  require("lazyaz").config_edit()
end, {})

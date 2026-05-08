return {
  {
    name = "plugin registers commands once",
    fn = function(t)
      vim.g.loaded_lazyaz_nvim = nil
      vim.cmd.runtime("plugin/lazyaz.lua")
      vim.cmd.runtime("plugin/lazyaz.lua")
      t.ok(vim.fn.exists(":LazyazToggle") == 2)
      t.ok(vim.fn.exists(":LazyazConfig") == 2)
    end,
  },
}

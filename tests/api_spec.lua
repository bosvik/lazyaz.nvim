return {
  {
    name = "config edit creates real config",
    fn = function(t)
      local dir = t.tmpdir()
      vim.env.XDG_CONFIG_HOME = dir
      require("lazyaz").config_edit()
      local path = vim.fs.joinpath(dir, "lazyaz", "config.json")
      t.eq(1, vim.fn.filereadable(path))
      t.eq(vim.uv.fs_realpath(path), vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0)))
    end,
  },
}

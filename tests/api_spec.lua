return {
  {
    name = "invalid scope does not load terminal",
    fn = function(t)
      local lazyaz = require("lazyaz")
      local notifications = t.with_notify(function()
        lazyaz.toggle("bad")
      end)
      t.ok(#notifications == 1)
      t.eq(nil, package.loaded["lazyaz.terminal"])
    end,
  },
  {
    name = "global config edit creates isolated real config",
    fn = function(t)
      local dir = t.tmpdir()
      vim.env.XDG_CONFIG_HOME = dir
      require("lazyaz").config_edit("global")
      local path = vim.fs.joinpath(dir, "lazyaz", "config.json")
      t.eq(1, vim.fn.filereadable(path))
      t.eq(vim.uv.fs_realpath(path), vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0)))
    end,
  },
  {
    name = "root config edit creates overlay config",
    fn = function(t)
      local root = t.tmpdir()
      vim.fn.mkdir(vim.fs.joinpath(root, ".git"), "p")
      vim.fn.chdir(root)
      local lazyaz = require("lazyaz")
      lazyaz.setup({ download_dir = "downloads" })
      lazyaz.config_edit("root")
      local path = vim.api.nvim_buf_get_name(0)
      t.ok(path:match("lazyaz%.nvim") ~= nil)
      t.ok(path:match("/lazyaz/config%.json$") ~= nil)
      local decoded = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
      t.eq(
        vim.uv.fs_realpath(vim.fs.joinpath(root, "downloads")),
        vim.uv.fs_realpath(decoded.download_dir)
      )
    end,
  },
}

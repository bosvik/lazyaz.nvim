return {
  {
    name = "relative download dir writes overlay config",
    fn = function(t)
      local root = t.tmpdir()
      local xdg = t.tmpdir()
      vim.env.XDG_CONFIG_HOME = xdg
      local overlay = require("lazyaz.overlay")
      local path = overlay.build(root, "downloads")
      t.ok(path)
      local config_path = vim.fs.joinpath(path, "lazyaz", "config.json")
      local decoded = vim.json.decode(table.concat(vim.fn.readfile(config_path), "\n"))
      t.eq(vim.fs.normalize(vim.fs.joinpath(root, "downloads")), decoded.download_dir)
    end,
  },
  {
    name = "traversal is rejected",
    fn = function(t)
      local root = t.tmpdir()
      local overlay = require("lazyaz.overlay")
      local notifications = t.with_notify(function()
        t.eq(nil, overlay.build(root, "../outside"))
      end)
      t.ok(#notifications > 0)
    end,
  },
  {
    name = "existing overlay config preserves fields",
    fn = function(t)
      local root = t.tmpdir()
      local overlay = require("lazyaz.overlay")
      local path = overlay.build(root, "one")
      local config_path = vim.fs.joinpath(path, "lazyaz", "config.json")
      vim.fn.writefile({ vim.json.encode({ theme = "dark", download_dir = "old" }) }, config_path)
      overlay.build(root, "two")
      local decoded = vim.json.decode(table.concat(vim.fn.readfile(config_path), "\n"))
      t.eq("dark", decoded.theme)
      t.eq(vim.fs.normalize(vim.fs.joinpath(root, "two")), decoded.download_dir)
    end,
  },
}

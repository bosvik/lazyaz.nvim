return {
  {
    name = "defaults and scopes",
    fn = function(t)
      local config = require("lazyaz.config")
      config.setup()
      t.eq(nil, config.get().download_dir)
      t.eq("global", config.normalize_scope(nil))
      t.eq("root", config.normalize_scope("root"))
    end,
  },
  {
    name = "valid overrides",
    fn = function(t)
      local config = require("lazyaz.config")
      config.setup({ download_dir = "downloads", window = { width = 80, title = "x" } })
      t.eq("downloads", config.get().download_dir)
      t.eq(80, config.get().window.width)
      t.eq("x", config.get().window.title)
    end,
  },
  {
    name = "invalid leaves notify and fall back",
    fn = function(t)
      local config = require("lazyaz.config")
      local notifications = t.with_notify(function()
        config.setup({ download_dir = "", window = { width = -1 }, on_open = true })
      end)
      t.ok(#notifications >= 3)
      t.eq(nil, config.get().download_dir)
      t.eq(0.9, config.get().window.width)
    end,
  },
  {
    name = "real config dir follows xdg",
    fn = function(t)
      local config = require("lazyaz.config")
      vim.env.XDG_CONFIG_HOME = "/tmp/xdg-test"
      t.eq("/tmp/xdg-test/lazyaz", config.real_config_dir())
      vim.env.XDG_CONFIG_HOME = ""
      t.ok(config.real_config_dir():match("/%.config/lazyaz$"))
    end,
  },
}

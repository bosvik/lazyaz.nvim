return {
  {
    name = "defaults",
    fn = function(t)
      local config = require("lazyaz.config")
      config.setup()
      t.eq(false, config.get().mux.enabled)
      t.eq("<c-x>", config.get().keys.hide)
    end,
  },
  {
    name = "valid overrides",
    fn = function(t)
      local config = require("lazyaz.config")
      config.setup({ mux = { enabled = true }, keys = { hide = false }, window = { width = 80, title = "x" } })
      t.eq(true, config.get().mux.enabled)
      t.eq(false, config.get().keys.hide)
      t.eq(80, config.get().window.width)
      t.eq("x", config.get().window.title)
    end,
  },
  {
    name = "invalid leaves notify and fall back",
    fn = function(t)
      local config = require("lazyaz.config")
      local notifications = t.with_notify(function()
        config.setup({ window = { width = -1 }, on_open = true, mux = { enabled = "yes" }, keys = { hide = true } })
      end)
      t.ok(#notifications >= 4)
      t.eq(0.9, config.get().window.width)
      t.eq(false, config.get().mux.enabled)
      t.eq("<c-x>", config.get().keys.hide)
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

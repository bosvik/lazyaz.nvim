return {
  {
    name = "command creates or attaches fixed session",
    fn = function(t)
      local tmux = require("lazyaz.tmux")
      t.eq("lazyaz.nvim", tmux.session)
      t.eq({ "tmux", "new", "-A", "-s", "lazyaz.nvim", "-c", "/tmp/project", "lazyaz" }, tmux.command("/tmp/project"))
    end,
  },
}

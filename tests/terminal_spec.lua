return {
  {
    name = "toggle hides and reopens the same running job",
    fn = function(t)
      local bin = t.tmpdir()
      local lazyaz = vim.fs.joinpath(bin, "lazyaz")
      vim.fn.writefile({ "#!/bin/sh", "while true; do sleep 1; done" }, lazyaz)
      vim.fn.setfperm(lazyaz, "rwxr-xr-x")
      vim.env.PATH = bin .. ":" .. vim.env.PATH

      local lazyaz = require("lazyaz")
      lazyaz.setup()
      lazyaz.toggle()
      t.ok(t.wait_until(function()
        return lazyaz.is_running() and lazyaz.is_open()
      end))
      local terminal = require("lazyaz.terminal")
      local instance = terminal.instances.__global__
      local job = instance.job
      local buf = instance.buf
      lazyaz.toggle()
      t.ok(t.wait_until(function()
        return lazyaz.is_running() and not lazyaz.is_open()
      end))
      lazyaz.toggle()
      t.ok(t.wait_until(function()
        return lazyaz.is_running() and lazyaz.is_open()
      end))
      t.eq(job, terminal.instances.__global__.job)
      t.eq(buf, terminal.instances.__global__.buf)
      lazyaz.close()
      t.ok(t.wait_until(function()
        return not lazyaz.is_running()
      end))
    end,
  },
  {
    name = "startup failure leaves no instance",
    fn = function(t)
      vim.env.PATH = t.tmpdir()
      local lazyaz = require("lazyaz")
      lazyaz.setup()
      t.with_notify(function()
        lazyaz.open()
      end)
      t.eq(false, lazyaz.is_open())
      t.eq(false, lazyaz.is_running())
      t.eq(nil, require("lazyaz.terminal").instances.__global__)
    end,
  },
}

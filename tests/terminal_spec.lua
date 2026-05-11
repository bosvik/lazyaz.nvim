return {
  {
    name = "toggle hides and reopens the same running job",
    fn = function(t)
      local bin = t.tmpdir()
      local lazyaz_bin = vim.fs.joinpath(bin, "lazyaz")
      vim.fn.writefile({ "#!/bin/sh", "while true; do sleep 1; done" }, lazyaz_bin)
      vim.fn.setfperm(lazyaz_bin, "rwxr-xr-x")
      vim.env.PATH = bin .. ":" .. vim.env.PATH

      local lazyaz = require("lazyaz")
      lazyaz.setup()
      lazyaz.toggle()
      t.ok(t.wait_until(function()
        return lazyaz.is_running() and lazyaz.is_open()
      end))
      local terminal = require("lazyaz.terminal")
      local job = terminal.instance.job
      local buf = terminal.instance.buf
      lazyaz.toggle()
      t.ok(t.wait_until(function()
        return lazyaz.is_running() and not lazyaz.is_open()
      end))
      lazyaz.toggle()
      t.ok(t.wait_until(function()
        return lazyaz.is_running() and lazyaz.is_open()
      end))
      t.eq(job, terminal.instance.job)
      t.eq(buf, terminal.instance.buf)
      terminal.instance:close()
      t.ok(t.wait_until(function()
        return not lazyaz.is_running()
      end))
    end,
  },
  {
    name = "terminal buffer has configurable hide key",
    fn = function(t)
      local bin = t.tmpdir()
      local lazyaz_bin = vim.fs.joinpath(bin, "lazyaz")
      vim.fn.writefile({ "#!/bin/sh", "while true; do sleep 1; done" }, lazyaz_bin)
      vim.fn.setfperm(lazyaz_bin, "rwxr-xr-x")
      vim.env.PATH = bin .. ":" .. vim.env.PATH

      local lazyaz = require("lazyaz")
      lazyaz.setup({ keys = { hide = "<c-x>" } })
      lazyaz.toggle()
      t.ok(t.wait_until(function()
        return lazyaz.is_running() and lazyaz.is_open()
      end))
      local terminal = require("lazyaz.terminal")
      local buf = terminal.instance.buf
      t.ok(vim.fn.maparg("<c-x>", "t", false, true).buffer == 1)
      t.ok(vim.fn.maparg("<c-x>", "n", false, true).buffer == 1)
      t.eq(true, vim.b[buf].lazyaz)
      lazyaz.setup({ keys = { hide = "<c-g>" } })
      lazyaz.toggle()
      lazyaz.toggle()
      t.eq("", vim.fn.maparg("<c-x>", "t"))
      t.ok(vim.fn.maparg("<c-g>", "t", false, true).buffer == 1)
      t.eq(true, lazyaz.hide_current())
      t.eq(false, lazyaz.is_open())

      terminal.instance:close()
      t.ok(t.wait_until(function()
        return not lazyaz.is_running()
      end))

      lazyaz = t.fresh()
      vim.env.PATH = bin .. ":" .. vim.env.PATH
      lazyaz.setup({ keys = { hide = false } })
      lazyaz.toggle()
      t.ok(t.wait_until(function()
        return lazyaz.is_running() and lazyaz.is_open()
      end))
      terminal = require("lazyaz.terminal")
      vim.api.nvim_set_current_buf(terminal.instance.buf)
      t.eq("", vim.fn.maparg("<c-x>", "t"))
      terminal.instance:close()
    end,
  },
  {
    name = "startup failure leaves no instance",
    fn = function(t)
      vim.env.PATH = t.tmpdir()
      local lazyaz = require("lazyaz")
      lazyaz.setup()
      t.with_notify(function()
        lazyaz.toggle()
      end)
      t.eq(false, lazyaz.is_open())
      t.eq(false, lazyaz.is_running())
      t.eq(nil, require("lazyaz.terminal").instance)
    end,
  },
}

local M = {}

local specs = {
  "tests.config_spec",
  "tests.overlay_spec",
  "tests.terminal_spec",
  "tests.api_spec",
  "tests.commands_spec",
  "tests.health_spec",
}

local total = 0
local failed = 0

local function clear_lazyaz_modules()
  for name in pairs(package.loaded) do
    if name == "lazyaz" or name:match("^lazyaz%.") then
      package.loaded[name] = nil
    end
  end
end

local function cleanup()
  local terminal = package.loaded["lazyaz.terminal"]
  if terminal then
    for _, instance in pairs(terminal.instances) do
      pcall(function()
        instance:close()
      end)
    end
  end
  pcall(vim.cmd, "%bwipeout!")
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= vim.api.nvim_get_current_win() then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

function M.wait_until(fn, timeout_ms)
  local deadline = vim.uv.hrtime() + ((timeout_ms or 1000) * 1000000)
  while vim.uv.hrtime() < deadline do
    if fn() then
      return true
    end
    vim.cmd("sleep 10m")
  end
  return false
end

function M.eq(expected, actual, message)
  if not vim.deep_equal(expected, actual) then
    error((message or "assertion failed") .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual), 2)
  end
end

function M.ok(value, message)
  if not value then
    error(message or "expected truthy value", 2)
  end
end

function M.tmpdir()
  local path = vim.fs.joinpath(vim.fn.tempname(), "lazyaz-test")
  vim.fn.mkdir(path, "p")
  return path
end

function M.with_notify(fn)
  local old = vim.notify
  local items = {}
  vim.notify = function(msg, level, opts)
    table.insert(items, { msg = msg, level = level, opts = opts })
  end
  local ok, err = pcall(fn, items)
  vim.notify = old
  if not ok then
    error(err, 0)
  end
  return items
end

function M.fresh()
  clear_lazyaz_modules()
  return require("lazyaz")
end

function M.run()
  local filter = vim.g.lazyaz_test_filter
  for _, spec_name in ipairs(specs) do
    if not filter or spec_name:find(filter, 1, true) then
      local spec = require(spec_name)
      for _, test in ipairs(spec) do
        total = total + 1
        local old_xdg = vim.env.XDG_CONFIG_HOME
        local old_home = vim.env.HOME
        local old_path = vim.env.PATH
        local old_cwd = vim.fn.getcwd()
        local ok, err = pcall(function()
          cleanup()
          clear_lazyaz_modules()
          test.fn(M)
        end)
        vim.env.XDG_CONFIG_HOME = old_xdg
        vim.env.HOME = old_home
        vim.env.PATH = old_path
        pcall(vim.fn.chdir, old_cwd)
        cleanup()
        if ok then
          print("ok " .. spec_name .. " - " .. test.name)
        else
          failed = failed + 1
          print("not ok " .. spec_name .. " - " .. test.name .. "\n" .. tostring(err))
        end
      end
    end
  end
  print(string.format("%d tests, %d failed", total, failed))
  if failed > 0 then
    vim.cmd.cquit(1)
  end
  vim.cmd.quit()
end

return M

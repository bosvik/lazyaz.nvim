local config = require("lazyaz.config")
local overlay = require("lazyaz.overlay")

local M = { instances = {} }

local GLOBAL_ID = "__global__"

local function notify(msg, level)
  vim.notify("lazyaz.nvim: " .. msg, level or vim.log.levels.WARN)
end

local function safe_call(name, ...)
  local cb = config.get()[name]
  local ok, err = pcall(cb, ...)
  if not ok then
    notify(name .. " callback failed: " .. tostring(err), vim.log.levels.ERROR)
  end
end

local function valid_win(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function is_running(job)
  return job and vim.fn.jobwait({ job }, 0)[1] == -1
end

local function geometry()
  local win_cfg = config.get().window
  local columns = vim.o.columns
  local lines = vim.o.lines - vim.o.cmdheight
  local width = win_cfg.width <= 1 and math.floor(columns * win_cfg.width) or math.floor(win_cfg.width)
  local height = win_cfg.height <= 1 and math.floor(lines * win_cfg.height) or math.floor(win_cfg.height)
  width = math.max(1, math.min(width, columns))
  height = math.max(1, math.min(height, lines))
  return {
    relative = "editor",
    row = math.floor((lines - height) / 2),
    col = math.floor((columns - width) / 2),
    width = width,
    height = height,
    border = win_cfg.border,
    title = win_cfg.title,
    style = "minimal",
  }
end

local function set_window_options(win)
  local win_cfg = config.get().window
  vim.wo[win].winblend = win_cfg.winblend
  vim.wo[win].winhighlight = "Normal:LazyazNormal,FloatBorder:LazyazBorder"
  vim.wo[win].fillchars = "eob: "
  vim.wo[win].signcolumn = "no"
  vim.wo[win].cursorcolumn = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].statuscolumn = ""
end

local function setup_highlights()
  vim.api.nvim_set_hl(0, "LazyazNormal", { link = "NormalFloat", default = true })
  vim.api.nvim_set_hl(0, "LazyazBorder", { link = "FloatBorder", default = true })
end

local function root_dir()
  local ok, root = pcall(vim.fs.root, 0, ".git")
  if ok and root then
    return vim.fs.normalize(root)
  end
  return vim.fs.normalize(vim.fn.getcwd())
end

function M.root_dir()
  return root_dir()
end

local function id_for(scope, root)
  if scope == "global" then
    return GLOBAL_ID
  end
  return vim.fn.sha256(vim.fs.normalize(root)):sub(1, 16)
end

local Terminal = {}
Terminal.__index = Terminal

local leave_autocmd_registered = false

local function ensure_leave_autocmd()
  if leave_autocmd_registered then
    return
  end
  leave_autocmd_registered = true
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("lazyaz.nvim.leave", { clear = true }),
    callback = function()
      for _, instance in pairs(M.instances) do
        if instance:running() then
          pcall(vim.fn.jobstop, instance.job)
        end
      end
    end,
  })
end

function Terminal.new(scope)
  ensure_leave_autocmd()
  local cwd = scope == "root" and root_dir() or vim.fn.getcwd()
  local root = scope == "root" and cwd or nil
  local id = id_for(scope, cwd)
  local self = setmetatable({
    id = id,
    scope = scope,
    cwd = cwd,
    root = root,
    group = vim.api.nvim_create_augroup("lazyaz.nvim." .. id, { clear = true }),
    gen = 0,
    normal_mode = false,
    close_requested = false,
    suppress_on_hide = false,
    finalised = false,
    exit_reported = false,
  }, Terminal)
  M.instances[id] = self
  return self
end

function Terminal:running()
  return is_running(self.job)
end

function Terminal:open_window()
  setup_highlights()
  if not valid_buf(self.buf) then
    self.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[self.buf].bufhidden = "hide"
  end
  if valid_win(self.win) then
    vim.api.nvim_set_current_win(self.win)
    self:restore_mode()
    return true
  end
  self:hide_others()
  self.suppress_on_hide = true
  self.win = vim.api.nvim_open_win(self.buf, true, geometry())
  self.suppress_on_hide = false
  set_window_options(self.win)
  safe_call("on_open")
  self:restore_mode()
  return true
end

function Terminal:hide_others()
  for id, instance in pairs(M.instances) do
    if id ~= self.id and valid_win(instance.win) then
      instance:hide()
    end
  end
end

function Terminal:setup_autocmds()
  local group = self.group
  local buf = self.buf
  vim.api.nvim_create_autocmd({ "TermEnter", "TermLeave" }, {
    group = group,
    buffer = buf,
    callback = function()
      vim.schedule(function()
        if valid_win(self.win) and vim.api.nvim_get_current_win() == self.win then
          self.normal_mode = vim.fn.mode() ~= "t"
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      if valid_win(self.win) and vim.api.nvim_get_current_win() == self.win then
        self:restore_mode()
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      if tonumber(args.match) == self.win then
        self.win = nil
        if not self.suppress_on_hide then
          safe_call("on_hide")
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      if valid_win(self.win) then
        vim.api.nvim_win_set_config(self.win, geometry())
      end
    end,
  })
  vim.api.nvim_create_autocmd("TermClose", {
    group = group,
    buffer = buf,
    callback = function()
      self:on_term_close(vim.v.event.status)
    end,
  })
end

function Terminal:restore_mode()
  if not valid_win(self.win) or vim.api.nvim_get_current_win() ~= self.win then
    return
  end
  if self.normal_mode then
    vim.cmd.stopinsert()
  else
    vim.cmd.startinsert()
  end
end

function Terminal:start()
  self.gen = self.gen + 1
  self.finalised = false
  self.exit_reported = false
  self.close_requested = false
  self.opened_at = vim.uv.hrtime()
  self:open_window()
  self:setup_autocmds()
  local env = nil
  if self.scope == "root" then
    local xdg = overlay.build(self.root, config.get().download_dir)
    if xdg then
      self.overlay = xdg
      env = { XDG_CONFIG_HOME = xdg }
    end
  end
  if not valid_win(self.win) or vim.api.nvim_win_get_buf(self.win) ~= self.buf then
    notify("terminal window disappeared before startup", vim.log.levels.ERROR)
    self:finalise(nil, self.gen)
    return false
  end
  local ok, job = pcall(vim.fn.jobstart, { "lazyaz" }, { term = true, cwd = self.cwd, env = env })
  if not ok or job == 0 or job == -1 then
    notify("failed to start lazyaz", vim.log.levels.ERROR)
    self:finalise(nil, self.gen)
    return false
  end
  self.job = job
  return true
end

function Terminal:on_term_close(code)
  self.last_exit_code = code
  local gen = self.gen
  if not self.exit_reported then
    self.exit_reported = true
    safe_call("on_exit", code)
  end
  if self.close_requested then
    vim.schedule(function()
      self:finalise(code, gen)
    end)
    return
  end
  local elapsed_ms = self.opened_at and ((vim.uv.hrtime() - self.opened_at) / 1000000) or 999999
  if elapsed_ms <= 500 or (code ~= 0 and elapsed_ms <= 3000) then
    self.job = nil
    return
  end
  vim.schedule(function()
    self:finalise(code, gen)
  end)
end

function Terminal:finalise(_, gen)
  if gen and gen ~= self.gen then
    return
  end
  if self.finalised then
    return
  end
  self.finalised = true
  self.suppress_on_hide = true
  if valid_win(self.win) then
    pcall(vim.api.nvim_win_close, self.win, true)
  end
  self.win = nil
  if valid_buf(self.buf) then
    pcall(vim.api.nvim_buf_delete, self.buf, { force = true })
  end
  self.buf = nil
  pcall(vim.api.nvim_del_augroup_by_id, self.group)
  M.instances[self.id] = nil
end

function Terminal:open()
  if self.close_requested then
    return
  end
  if self.job and not self:running() then
    self:finalise(self.last_exit_code, self.gen)
    return Terminal.new(self.scope):start()
  end
  if self.last_exit_code ~= nil and not self:running() then
    self:finalise(self.last_exit_code, self.gen)
    return Terminal.new(self.scope):start()
  end
  if self:running() then
    self:open_window()
    return true
  end
  return self:start()
end

function Terminal:focus()
  return self:open()
end

function Terminal:hide()
  if valid_win(self.win) then
    pcall(vim.api.nvim_win_close, self.win, true)
  end
end

function Terminal:close()
  self.close_requested = true
  if self:running() then
    pcall(vim.fn.jobstop, self.job)
    vim.defer_fn(function()
      if M.instances[self.id] == self and self.close_requested and self.job and not self.exit_reported then
        local result = vim.fn.jobwait({ self.job }, 0)[1]
        if result ~= -1 then
          self:on_term_close(result)
        end
      end
    end, 200)
    return
  end
  self:finalise(self.last_exit_code, self.gen)
end

local function get(scope, create)
  if scope == "global" then
    return M.instances[GLOBAL_ID] or (create and Terminal.new(scope) or nil)
  end
  local root = root_dir()
  local id = id_for(scope, root)
  return M.instances[id] or (create and Terminal.new(scope) or nil)
end

function M.open(scope)
  local instance = get(scope, true)
  return instance and instance:open()
end

function M.focus(scope)
  local instance = get(scope, true)
  return instance and instance:focus()
end

function M.toggle(scope)
  local instance = get(scope, true)
  if not instance then
    return
  end
  if instance:running() and valid_win(instance.win) then
    instance:hide()
    return
  end
  return instance:open()
end

function M.hide(scope)
  local instance = get(scope, false)
  if instance then
    instance:hide()
  end
end

function M.close(scope)
  local instance = get(scope, false)
  if instance then
    instance:close()
  end
end

function M.is_open(scope)
  local instance = get(scope, false)
  return instance ~= nil and valid_win(instance.win)
end

function M.is_running(scope)
  local instance = get(scope, false)
  return instance ~= nil and instance:running()
end

M._test = { Terminal = Terminal, root_dir = root_dir, geometry = geometry }

return M

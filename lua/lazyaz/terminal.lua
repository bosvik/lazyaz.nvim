local config = require("lazyaz.config")

local M = {}

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
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
  return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

local function is_running(job)
  return job ~= nil and vim.fn.jobwait({ job }, 0)[1] == -1
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
      if M.instance and M.instance:running() then
        pcall(vim.fn.jobstop, M.instance.job)
      end
    end,
  })
end

function Terminal.new()
  ensure_leave_autocmd()
  local self = setmetatable({
    cwd = vim.fn.getcwd(),
    group = vim.api.nvim_create_augroup("lazyaz.nvim.terminal", { clear = true }),
    gen = 0,
    normal_mode = false,
    close_requested = false,
    suppress_on_hide = false,
    finalised = false,
    exit_reported = false,
  }, Terminal)
  M.instance = self
  return self
end

function Terminal:running()
  return is_running(self.job)
end

function Terminal:setup_keymaps()
  local hide = config.get().keys.hide
  if self.hide_keymap then
    for _, mode in ipairs({ "n", "t" }) do
      pcall(vim.keymap.del, mode, self.hide_keymap, { buffer = self.buf })
    end
    self.hide_keymap = nil
  end
  if hide == false then
    return
  end
  vim.b[self.buf].lazyaz = true
  vim.keymap.set("n", hide, function()
    self:hide()
  end, { buffer = self.buf, desc = "Hide lazyaz", nowait = true, silent = true })
  vim.keymap.set("t", hide, [[<C-\><C-n><Cmd>lua require("lazyaz.terminal").hide_current()<CR>]], {
    buffer = self.buf,
    desc = "Hide lazyaz",
    nowait = true,
    silent = true,
  })
  self.hide_keymap = hide
end

function Terminal:open_window()
  setup_highlights()
  if not valid_buf(self.buf) then
    self.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[self.buf].bufhidden = "hide"
  end
  self:setup_keymaps()
  if valid_win(self.win) then
    vim.api.nvim_set_current_win(self.win)
    self:restore_mode()
    return true
  end
  self.suppress_on_hide = true
  self.win = vim.api.nvim_open_win(self.buf, true, geometry())
  self.suppress_on_hide = false
  set_window_options(self.win)
  safe_call("on_open")
  self:restore_mode()
  return true
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
  if not valid_win(self.win) or vim.api.nvim_win_get_buf(self.win) ~= self.buf then
    notify("terminal window disappeared before startup", vim.log.levels.ERROR)
    self:finalise(nil, self.gen)
    return false
  end
  local cmd = { "lazyaz" }
  if config.get().mux.enabled then
    local tmux = require("lazyaz.tmux")
    if not tmux.executable() then
      notify("tmux is required when mux.enabled is true", vim.log.levels.ERROR)
      self:finalise(nil, self.gen)
      return false
    end
    cmd = tmux.command(self.cwd)
  end
  local ok, job = pcall(vim.fn.jobstart, cmd, { term = true, cwd = self.cwd })
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
  if M.instance == self then
    M.instance = nil
  end
end

function Terminal:open()
  if self.close_requested then
    return
  end
  if self.job and not self:running() then
    self:finalise(self.last_exit_code, self.gen)
    return Terminal.new():start()
  end
  if self.last_exit_code ~= nil and not self:running() then
    self:finalise(self.last_exit_code, self.gen)
    return Terminal.new():start()
  end
  if self:running() then
    self:open_window()
    return true
  end
  return self:start()
end

function Terminal:blur()
  if valid_win(self.win) and vim.api.nvim_get_current_win() == self.win then
    pcall(vim.cmd.wincmd, "p")
  end
  vim.cmd.stopinsert()
end

function Terminal:hide()
  if valid_win(self.win) then
    self:blur()
    pcall(vim.api.nvim_win_close, self.win, true)
  end
end

function Terminal:close()
  self.close_requested = true
  if self:running() then
    pcall(vim.fn.jobstop, self.job)
    vim.defer_fn(function()
      if M.instance == self and self.close_requested and self.job and not self.exit_reported then
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

local function get(create)
  return M.instance or (create and Terminal.new() or nil)
end

function M.toggle()
  local instance = get(true)
  if not instance then
    return
  end
  if instance:running() and valid_win(instance.win) then
    instance:hide()
    return
  end
  return instance:open()
end

function M.hide_current()
  local instance = M.instance
  if instance then
    instance:hide()
    return true
  end
  return false
end

function M.is_open()
  local instance = get(false)
  return instance ~= nil and valid_win(instance.win)
end

function M.is_running()
  local instance = get(false)
  return instance ~= nil and instance:running()
end

M._test = { Terminal = Terminal, geometry = geometry }

return M

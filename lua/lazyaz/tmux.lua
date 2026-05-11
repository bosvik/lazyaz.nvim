local M = {}

M.session = "lazyaz.nvim"

function M.executable()
  return vim.fn.executable("tmux") == 1
end

function M.command(cwd)
  return { "tmux", "new", "-A", "-s", M.session, "-c", cwd, "lazyaz" }
end

return M

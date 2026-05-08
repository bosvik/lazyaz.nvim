local config = require("lazyaz.config")

local M = {}

local function notify(msg, level)
  vim.notify("lazyaz.nvim: " .. msg, level or vim.log.levels.WARN)
end

local function normalize(path)
  return vim.fs.normalize(path)
end

local function is_absolute(path)
  return path:match("^/") ~= nil
    or path:match("^%a:[/\\]") ~= nil
    or path:match("^%a:$") ~= nil
    or path:match("^[/\\][/\\]") ~= nil
end

local function contained(parent, child)
  parent = normalize(parent):gsub("[/\\]+$", "")
  child = normalize(child):gsub("[/\\]+$", "")
  return child == parent or child:sub(1, #parent + 1) == parent .. "/"
end

local function exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

local function is_dir(path)
  local stat = vim.uv.fs_stat(path)
  return stat and stat.type == "directory"
end

local function is_symlink(path)
  local stat = vim.uv.fs_lstat(path)
  return stat and stat.type == "link"
end

local function rm_rf(path)
  local stat = vim.uv.fs_lstat(path)
  if not stat then
    return true
  end
  if stat.type == "directory" then
    local fs = vim.uv.fs_scandir(path)
    if fs then
      while true do
        local name = vim.uv.fs_scandir_next(fs)
        if not name then
          break
        end
        local ok = rm_rf(vim.fs.joinpath(path, name))
        if not ok then
          return false
        end
      end
    end
    return vim.uv.fs_rmdir(path)
  end
  return vim.uv.fs_unlink(path)
end

local function copy_file(src, dst)
  local data = vim.fn.readfile(src, "b")
  vim.fn.writefile(data, dst, "b")
end

local function copy_dir(src, dst)
  local stat = vim.uv.fs_lstat(src)
  if not stat or stat.type == "link" then
    return
  end
  if stat.type ~= "directory" then
    copy_file(src, dst)
    return
  end
  vim.fn.mkdir(dst, "p")
  local fs = vim.uv.fs_scandir(src)
  if not fs then
    return
  end
  while true do
    local name = vim.uv.fs_scandir_next(fs)
    if not name then
      break
    end
    copy_dir(vim.fs.joinpath(src, name), vim.fs.joinpath(dst, name))
  end
end

local function read_json(path)
  if not exists(path) then
    return {}
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil, "could not read " .. path
  end
  local text = table.concat(lines, "\n")
  if text == "" then
    return {}
  end
  local decoded_ok, decoded = pcall(vim.json.decode, text)
  if not decoded_ok or type(decoded) ~= "table" then
    return nil, "invalid JSON in " .. path
  end
  return decoded
end

local function atomic_write_json(path, value)
  local dir = vim.fs.dirname(path)
  local tmp = vim.fs.joinpath(dir, ".config.json.tmp." .. tostring(vim.uv.hrtime()))
  local ok, encoded = pcall(vim.json.encode, value)
  if not ok then
    return false
  end
  local write_ok = pcall(vim.fn.writefile, { encoded }, tmp, "b")
  if not write_ok then
    pcall(vim.uv.fs_unlink, tmp)
    return false
  end
  local rename_ok = vim.uv.fs_rename(tmp, path)
  if not rename_ok then
    pcall(vim.uv.fs_unlink, tmp)
    return false
  end
  return true
end

local function materialize(real_dir, overlay_dir, name, overlay_base)
  local src = vim.fs.joinpath(real_dir, name)
  if not is_dir(src) then
    return true
  end
  local dst = vim.fs.joinpath(overlay_dir, name)
  if not contained(overlay_base, dst) then
    notify("refusing unsafe overlay path " .. dst, vim.log.levels.ERROR)
    return false
  end
  if is_symlink(dst) and vim.uv.fs_readlink(dst) == src then
    return true
  end
  if exists(dst) and not rm_rf(dst) then
    notify("could not rebuild overlay " .. name, vim.log.levels.ERROR)
    return false
  end
  local ok = vim.uv.fs_symlink(src, dst, { dir = true })
  if ok then
    return true
  end
  copy_dir(src, dst)
  return true
end

local function resolve_download_dir(root, value)
  if type(value) == "function" then
    local ok, result = pcall(value, root)
    if not ok or type(result) ~= "string" or result == "" then
      notify("download_dir function did not return a path; starting without overlay")
      return nil
    end
    value = result
  end
  if type(value) ~= "string" or value == "" then
    notify("invalid download_dir; starting without overlay")
    return nil
  end
  if is_absolute(value) then
    return value
  end
  local resolved = normalize(vim.fs.joinpath(root, value))
  if not contained(root, resolved) then
    notify("download_dir escapes root; starting without overlay", vim.log.levels.ERROR)
    return nil
  end
  return resolved
end

function M.build(root, download_dir, opts)
  opts = opts or {}
  if download_dir == nil and not opts.force then
    return nil
  end
  root = normalize(root)
  local resolved = nil
  if download_dir ~= nil then
    resolved = resolve_download_dir(root, download_dir)
  end
  if download_dir ~= nil and not resolved then
    return nil
  end

  local hash = vim.fn.sha256(root):sub(1, 16)
  local overlay_base = normalize(vim.fs.joinpath(vim.fn.stdpath("cache"), "lazyaz.nvim"))
  local xdg_config_home = vim.fs.joinpath(overlay_base, hash)
  local lazyaz_config_dir = vim.fs.joinpath(xdg_config_home, "lazyaz")

  for _, path in ipairs({ overlay_base, xdg_config_home, lazyaz_config_dir }) do
    if is_symlink(path) then
      notify("refusing symlinked overlay directory " .. path, vim.log.levels.ERROR)
      return nil
    end
  end
  vim.fn.mkdir(lazyaz_config_dir, "p")

  local real_dir = config.real_config_dir()
  materialize(real_dir, lazyaz_config_dir, "themes", overlay_base)
  materialize(real_dir, lazyaz_config_dir, "keymaps", overlay_base)

  local overlay_config = vim.fs.joinpath(lazyaz_config_dir, "config.json")
  local real_config = vim.fs.joinpath(real_dir, "config.json")
  local object, err = read_json(overlay_config)
  if not object then
    notify(err .. "; starting without overlay", vim.log.levels.ERROR)
    return nil
  end
  if not exists(overlay_config) then
    object, err = read_json(real_config)
    if not object then
      notify(err .. "; starting without overlay", vim.log.levels.ERROR)
      return nil
    end
  end
  if resolved ~= nil then
    object.download_dir = resolved
  end
  if not atomic_write_json(overlay_config, object) then
    notify("could not write overlay config; starting without overlay", vim.log.levels.ERROR)
    return nil
  end
  return xdg_config_home
end

function M.config_path(root, download_dir)
  local xdg_config_home = M.build(root, download_dir, { force = true })
  if not xdg_config_home then
    return nil
  end
  return vim.fs.joinpath(xdg_config_home, "lazyaz", "config.json")
end

M._test = {
  contained = contained,
  is_absolute = is_absolute,
  normalize = normalize,
  resolve_download_dir = resolve_download_dir,
}

return M

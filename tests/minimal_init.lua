local root = vim.fn.getcwd()
vim.opt.runtimepath:prepend(root)
vim.opt.packpath = vim.opt.runtimepath:get()
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

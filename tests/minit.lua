#!/usr/bin/env -S nvim -l

-- tests/minit.lua bootstraps a minimal, isolated Neovim + lazy.nvim
-- environment and runs the busted specs in this directory against it, via
-- lazy.nvim's built-in `lazy.minit` module (the same mechanism repro.lua
-- uses via `lazy.minit.repro`, see https://lazy.folke.io/developers#minit).
--
-- Run locally with:
--   nvim -l tests/minit.lua

vim.env.LAZY_STDPATH = ".tests"
vim.env.LAZY_PATH = vim.fs.normalize("~/projects/lazy.nvim")

if vim.fn.isdirectory(vim.env.LAZY_PATH) == 1 then
  loadfile(vim.env.LAZY_PATH .. "/bootstrap.lua")()
else
  load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"), "bootstrap.lua")()
end

require("lazy.minit").setup({
  spec = {
    { dir = vim.uv.cwd(), opts = {} },
  },
})

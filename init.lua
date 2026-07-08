-- Leader must be set before plugins define <leader> mappings
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Set the clipboard provider
vim.g.clipboard = "wl-copy"

-- llama.vim reads this at plugin load time (so it must be set before plug#end())
-- Load configuration from environment variables
local llama_config = {
	endpoint_fim = os.getenv("LLM_ENDPOINT_FIM") or "http://localhost:8081/infill",
	endpoint_inst = os.getenv("LLM_ENDPOINT_INST") or "http://localhost:8081/v1/chat/completions",
	model_inst = os.getenv("LLM_MODEL_INST") or "Devstral-Small-2-24B:Q4_K_M",
	model_fim = os.getenv("LLM_MODEL_FIM") or "Devstral-Small-2-24B:Q4_K_M",
	api_key = os.getenv("LLM_LOCAL_API_KEY") or "sk-local",
	show_info = 2,
	ring_n_chunks = 32,
	auto_fim = false,
	stop_strings = {
		"\n\n",
		"\n/*",
		"\n/**",
		"\n}",
		"\n#",
		"\ndef",
		"\n//",
		"\nclass",
		"\nif",
		"\nfor",
		"\nwhile",
		"\nreturn",
		"\nint",
		"\nvoid",
		"\nconst",
		"\nstatic",
		".\n",
		"?\n",
		"!\n",
		"。",
	},
	keymap_fim_trigger = "<C-F>",
	keymap_fim_accept_full = "<Tab>",
	keymap_fim_accept_line = "<S-Tab>",
	keymap_fim_accept_word = "<C-B>",
}
vim.keymap.set("n", "<leader>llt", ":LlamaToggleAutoFim<CR>", { desc = "Toggle auto-FIM" })

-- Only set llama_config if environment variables are present
if os.getenv("LLM_ENDPOINT_FIM") then
	vim.g.llama_config = llama_config
end

-- Bootstrap vim-plug
local plug_path = vim.fn.stdpath("data") .. "/site/autoload/plug.vim"
if vim.fn.empty(vim.fn.glob(plug_path)) > 0 then
	print("Installing vim-plug...")
	vim.fn.system({
		"curl",
		"-fLo",
		plug_path,
		"--create-dirs",
		"https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim",
	})
	vim.cmd([[autocmd VimEnter * PlugInstall --sync | source $MYVIMRC]])
end

-- Plugin Management
vim.cmd([[call plug#begin()]])

-- Appearance
vim.cmd([[Plug 'folke/tokyonight.nvim']])

vim.cmd([[Plug 'vim-airline/vim-airline']])
vim.cmd([[Plug 'vim-airline/vim-airline-themes']])
vim.cmd([[Plug 'akinsho/bufferline.nvim', { 'tag': '*' }]])

-- Neo-tree and dependencies
vim.cmd([[Plug 'nvim-lua/plenary.nvim']])
vim.cmd([[Plug 'nvim-tree/nvim-web-devicons']])
vim.cmd([[Plug 'MunifTanjim/nui.nvim']])
vim.cmd([[Plug 'nvim-neo-tree/neo-tree.nvim']])

-- Tools
vim.cmd([[Plug 'williamboman/mason.nvim']])
vim.cmd([[Plug 'williamboman/mason-lspconfig.nvim']])
vim.cmd([[Plug 'neovim/nvim-lspconfig']])
vim.cmd([[Plug 'stevearc/conform.nvim']])
vim.cmd([[Plug 'nvim-telescope/telescope.nvim']])
vim.cmd([[Plug 'sphamba/smear-cursor.nvim']])
vim.cmd([[Plug 'ggml-org/llama.vim']])

-- Misc
vim.cmd([[Plug 'MeanderingProgrammer/render-markdown.nvim']])
vim.cmd([[Plug 'nvim-treesitter/nvim-treesitter']])

vim.cmd([[call plug#end()]])

-- General Options
local opt = vim.opt

opt.number = true -- Show line numbers
opt.relativenumber = true -- Relative line numbers
opt.mouse = "a" -- Enable mouse mode
opt.clipboard = "unnamedplus" -- Sync with system clipboard
opt.ignorecase = true -- Case insensitive searching
opt.smartcase = true -- ...unless capital letter used
opt.signcolumn = "yes" -- Always show sign column
opt.updatetime = 250 -- Decrease update time
opt.timeoutlen = 1000 -- Mapped sequence wait time (leader combos)
opt.termguicolors = true -- True color support

-- Indentation
opt.expandtab = true -- Use spaces instead of tabs
opt.shiftwidth = 2 -- Size of an indent
opt.tabstop = 2 -- Number of spaces tabs count for
opt.smartindent = true -- Insert indents automatically

-- Colorscheme
-- Wrap in pcall to avoid errors if plugins aren't installed yet
pcall(vim.cmd, "colorscheme tokyonight-moon")

-- Setup functions for Lua plugins
-- We wrap these in pcall to ensure the config doesn't crash on first load before PlugInstall
local function safe_setup(plugin, opts)
	local status_ok, plugin_module = pcall(require, plugin)
	if status_ok then
		plugin_module.setup(opts or {})
	end
end

safe_setup("cyberpunk", { theme = "dark" })
safe_setup("mason")
safe_setup("telescope")
safe_setup("neo-tree")
safe_setup("smear_cursor")
safe_setup("bufferline", {
	options = {
		diagnostics = "nvim_lsp",
		separator_style = "slant",
		show_close_icon = false,
		show_buffer_close_icons = false,
	},
})

safe_setup("conform", {
	formatters_by_ft = {
		lua = { "stylua" },
		python = { "black" },
		c = { "clang-format" },
		cpp = { "clang-format" },
		json = { "prettier" },
		javascript = { "prettier" },
		html = { "prettier" },
		css = { "prettier" },
		markdown = { "prettier" },
	},
	format_on_save = {
		timeout_ms = 500,
		lsp_format = "fallback",
		quiet = true,
	},
})

-- Format keybind
vim.keymap.set({ "n", "v" }, "<leader>cf", function()
	require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format buffer" })

-- LSP (minimal; install servers via :Mason)
do
	local ok_mason, mason = pcall(require, "mason")
	if ok_mason then
		mason.setup({})
	end

	local ok_mlsp, mlsp = pcall(require, "mason-lspconfig")
	local capabilities = vim.lsp.protocol.make_client_capabilities()

	local native_config_callable = (vim.is_callable and vim.is_callable(vim.lsp.config))
		or type(vim.lsp.config) == "function"

	-- Neovim >= 0.11: prefer the native LSP config API.
	if native_config_callable and ok_mlsp then
		local servers = {}
		if type(mlsp.get_installed_servers) == "function" then
			servers = mlsp.get_installed_servers()
		end

		for _, server_name in ipairs(servers) do
			pcall(vim.lsp.config, server_name, {
				capabilities = capabilities,
			})
			if type(vim.lsp.enable) == "function" then
				pcall(vim.lsp.enable, server_name)
			end
		end

		-- Keep mason-lspconfig loaded (server mappings + UI integration).
		-- Disable automatic enabling to avoid ordering issues.
		mlsp.setup({
			automatic_enable = false,
		})

	-- Older Neovim: fall back to nvim-lspconfig.
	else
		local ok_lsp, lspconfig = pcall(require, "lspconfig")
		if ok_mlsp and ok_lsp then
			-- mason-lspconfig v1: setup_handlers exists; v2 removes it.
			if type(mlsp.setup_handlers) == "function" then
				mlsp.setup({
					automatic_installation = true,
				})
				mlsp.setup_handlers({
					function(server_name)
						lspconfig[server_name].setup({
							capabilities = capabilities,
						})
					end,
				})
			else
				mlsp.setup({})
				local servers = {}
				if type(mlsp.get_installed_servers) == "function" then
					servers = mlsp.get_installed_servers()
				end
				for _, server_name in ipairs(servers) do
					if lspconfig[server_name] then
						lspconfig[server_name].setup({
							capabilities = capabilities,
						})
					end
				end
			end
		end
	end
end

-- Project root helper (LSP root -> git root -> cwd)
local function project_root()
	local clients = vim.lsp.get_clients({ bufnr = 0 })
	for _, c in ipairs(clients) do
		local rd = c.config and c.config.root_dir
		if type(rd) == "string" and rd ~= "" then
			return rd
		end
	end

	local bufname = vim.api.nvim_buf_get_name(0)
	local start = bufname ~= "" and vim.fs.dirname(bufname) or (vim.loop and vim.loop.cwd() or vim.fn.getcwd())
	local git = vim.fs.find(".git", { path = start, upward = true })[1]
	if git then
		return vim.fs.dirname(git)
	end

	return vim.loop and vim.loop.cwd() or vim.fn.getcwd()
end

-- Telescope keymaps (LazyVim-style)
do
	local ok, builtin = pcall(require, "telescope.builtin")
	if ok then
		vim.keymap.set("n", "<leader>sg", function()
			builtin.live_grep({ cwd = project_root() })
		end, { noremap = true, silent = true, desc = "Grep (root)" })

		vim.keymap.set("n", "<leader>sG", function()
			builtin.live_grep({ cwd = (vim.loop and vim.loop.cwd() or vim.fn.getcwd()) })
		end, { noremap = true, silent = true, desc = "Grep (cwd)" })
	end
end

-- LSP keymaps (buffer-local on attach)
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local buf = args.buf

		local function nmap(lhs, rhs, desc)
			vim.keymap.set("n", lhs, rhs, { buffer = buf, noremap = true, silent = true, desc = desc })
		end

		local ok, builtin = pcall(require, "telescope.builtin")
		if ok then
			nmap("gr", builtin.lsp_references, "References")
			nmap("gi", builtin.lsp_implementations, "Implementations")
			nmap("gd", builtin.lsp_definitions, "Definitions")
		else
			nmap("gr", vim.lsp.buf.references, "References")
			nmap("gi", vim.lsp.buf.implementation, "Implementation")
			nmap("gd", vim.lsp_definitions, "Definitions")
		end
	end,
})

-- Diagnostics navigation (LazyVim-style)
do
	local function diag_next(severity)
		return function()
			vim.diagnostic.goto_next({ severity = severity })
		end
	end

	local function diag_prev(severity)
		return function()
			vim.diagnostic.goto_prev({ severity = severity })
		end
	end

	vim.keymap.set(
		"n",
		"]w",
		diag_next(vim.diagnostic.severity.WARN),
		{ noremap = true, silent = true, desc = "Next Warning" }
	)
	vim.keymap.set(
		"n",
		"[w",
		diag_prev(vim.diagnostic.severity.WARN),
		{ noremap = true, silent = true, desc = "Prev Warning" }
	)
	vim.keymap.set(
		"n",
		"]e",
		diag_next(vim.diagnostic.severity.ERROR),
		{ noremap = true, silent = true, desc = "Next Error" }
	)
	vim.keymap.set(
		"n",
		"[e",
		diag_prev(vim.diagnostic.severity.ERROR),
		{ noremap = true, silent = true, desc = "Prev Error" }
	)
end

-- Keymaps
vim.keymap.set("n", "<leader>e", ":Neotree toggle<CR>", { noremap = true, silent = true, desc = "Toggle Explorer" })

-- Pane navigation (LazyVim-style)
vim.keymap.set("n", "<C-h>", "<C-w>h", { noremap = true, silent = true, desc = "Move to left pane" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { noremap = true, silent = true, desc = "Move to below pane" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { noremap = true, silent = true, desc = "Move to above pane" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { noremap = true, silent = true, desc = "Move to right pane" })

-- Bufferline / buffer navigation (LazyVim-style)
vim.keymap.set("n", "<S-h>", function()
	if vim.fn.exists(":BufferLineCyclePrev") == 2 then
		vim.cmd("BufferLineCyclePrev")
	else
		vim.cmd("bprevious")
	end
end, { noremap = true, silent = true, desc = "Prev buffer" })

vim.keymap.set("n", "<S-l>", function()
	if vim.fn.exists(":BufferLineCycleNext") == 2 then
		vim.cmd("BufferLineCycleNext")
	else
		vim.cmd("bnext")
	end
end, { noremap = true, silent = true, desc = "Next buffer" })

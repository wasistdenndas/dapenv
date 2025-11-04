local M = {}
local config = require("dapenv.config")

--- Finds the project root directory by searching upwards for a '.git' directory.
---@return string|nil The path to the project root, or nil if not found.
local function find_project_root()
	local current_buf = vim.api.nvim_get_current_buf()
	local file_path = vim.api.nvim_buf_get_name(current_buf)

	if not file_path or file_path == "" then
		return vim.fn.getcwd()
	end

	local start_dir = vim.fn.fnamemodify(file_path, ":h")
	local root_marker =
		vim.fs.find(".git", { upward = true, stop = vim.env.HOME, path = start_dir, type = "directory" })

	if #root_marker > 0 then
		return vim.fn.fnamemodify(root_marker[1], ":h")
	end

	return vim.fn.getcwd()
end

--- Parses a single .env file line.
---@param line string The line to parse.
---@return string, string|nil The key and value, or nil if the line is invalid.
local function parse_env_line(line)
	line = line:match("^%s*(.-)%s*$") -- Trim whitespace

	if line:sub(1, 1) == "#" or line == "" then
		return nil
	end

	local key, value = line:match("([^=]+)=(.*)")
	if key then
		-- trim quotes from value if present
		if value:sub(1, 1) == '"' and value:sub(-1) == '"' then
			value = value:sub(2, -2)
		elseif value:sub(1, 1) == "'" and value:sub(-1) == "'" then
			value = value:sub(2, -2)
		end

		return key, value
	end

	return nil
end

--- Loads environment variables from a list of files.
---@param env_files table A list of absolute paths to .env files.
---@return table The merged environment variables.
local function load_vars_from_files(env_files)
	local env_vars = {}

	for _, file_path in ipairs(env_files) do
		local file_content = {}
		local file = io.open(file_path, "r")

		if file then
			for line in file:lines() do
				table.insert(file_content, line)
			end
			file:close()

			for _, line in ipairs(file_content) do
				local key, value = parse_env_line(line)

				if key and value then
					env_vars[key] = value
				end
			end
		else
			vim.notify("DAPENV: Could not open env file: " .. file_path, vim.log.levels.WARN)
		end
	end

	return env_vars
end

--- Performs variable substitution on the loaded environment variables.
---@param env_vars table The table of environment variables.
---@return table The table with substituted variables.
local function substitute_vars(env_vars)
	local substituted_vars = {}
	for k, v in pairs(env_vars) do
		-- Match ${VAR} or $VAR patterns
		local substituted_v = v:gsub("%${(.-)}", env_vars):gsub("%$(%w+)", env_vars)
		substituted_vars[k] = substituted_v
	end
	return substituted_vars
end

--- Main function to process the envFile property from a dap configuration.
---@param dap_config table The DAP configuration table passed by nvim-dap. It should contain the envFile key.
---@return table The final environment variables for the debug session.
function M.get_env_from_files(dap_config)
	if not dap_config.envFile or type(dap_config.envFile) ~= "table" then
		return {}
	end

	local project_root = find_project_root()
	if not project_root then
		vim.notify("DAP-ENV: Could not find project root, unable to resolve envFile paths.", vim.log.levels.ERROR)
		return {}
	end

	local env_files_to_load = {}
	for _, env_file_path in ipairs(dap_config.envFile) do
		local resolved_path = env_file_path:gsub("${workspaceFolder}", project_root)
		table.insert(env_files_to_load, resolved_path)
	end

	if #env_files_to_load == 0 then
		return {}
	end

	local loaded_vars = load_vars_from_files(env_files_to_load)

	if config.options.substitution then
		return substitute_vars(loaded_vars)
	end

	return loaded_vars
end

--- Setup function for user configuration.
--- This function will now patch dap.run to intercept debug sessions.
---@param opts table|nil User-provided options.
function M.setup(opts)
	config.setup(opts or {})

	-- Use VimEnter to ensure all plugins, including nvim-dap, are fully loaded and configured.
	vim.api.nvim_create_autocmd("VimEnter", {
		once = true,

		callback = function()
			local dap_ok, dap = pcall(require, "dap")
			if not dap_ok then
				return
			end -- Silently fail if dap isn't there

			local original_dap_run = dap.run
			if not original_dap_run then
				vim.notify("DAPENV: Could not find dap.run to patch.", vim.log.levels.ERROR)
				return
			end

			-- Replace dap.run with our wrapper function
			dap.run = function(config, cb)
				if config and config.envFile and type(config.envFile) == "table" then
					local env_from_files = M.get_env_from_files(config)
					local original_env = config.env or {}

					if type(original_env) ~= "table" then
						original_env = {}
					end

					local final_env = vim.tbl_deep_extend("force", original_env, env_from_files)

					config.env = final_env
				end

				return original_dap_run(config, cb)
			end
		end,
	})
end

return M

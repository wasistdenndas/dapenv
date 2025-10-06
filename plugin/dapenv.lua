vim.api.nvim_create_user_command("DapLoadEnv", function()
	package.loaded["dapenv"] = nil
	package.loaded["dapenv.config"] = nil

	local dap_env = require("dapenv")
	local env_vars = dap_env.get_env()

	vim.print(env_vars)
end, {})

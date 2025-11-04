---@class DapEnvConfig
local M = {}

M.options = {
	substitution = true,
}

--@param opts table|nil The options table passed from the user's setup call
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.options, opts or {})
end

return M

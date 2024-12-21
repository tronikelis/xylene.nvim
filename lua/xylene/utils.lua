local M = {}

---@param str string
---@param starts_with string
---@return boolean
function M.string_starts_with(str, starts_with)
    return string.sub(str, 1, string.len(starts_with)) == starts_with
end

return M

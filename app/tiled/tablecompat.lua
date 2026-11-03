---@type fun(t:table)
local table_clear = table.clear  ---@diagnostic disable-line
if not table_clear then
    local has_tclear
    has_tclear, table_clear = pcall(require, "table.clear")
    if not has_tclear then
        function table_clear(t)
            while true do
                local k = next(t)
                if k == nil then break end
                t[k] = nil
            end
        end
    end
end

---@type fun(narray:integer, nhash:integer):table
local table_new = table.new ---@diagnostic disable-line
if not table_new then
    local has_tnew = pcall(require, "table.new")
    if has_tnew then
       table_new = table.new ---@diagnostic disable-line
    else
        table_new = function(narr, nhash) return {} end
    end
end

return {
    clear = table_clear,
    new = table_new,
    unpack = table.unpack or unpack ---@diagnostic disable-line
}
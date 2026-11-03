---@meta

---@class batteries.Class
---@field protected __super batteries.Class|any
local bclass = {}

---@param class any
---@return boolean
function bclass:is(class) end

---@protected
function bclass:super(...) end

---@param config {name?:string, extends?:any, implements?:any[], default_tostring:boolean?}?
---@return table
function batteries.class(config) end
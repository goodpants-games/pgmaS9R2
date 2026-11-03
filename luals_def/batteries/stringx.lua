---@meta
--[[
	extra string routines
]]

---split a string on a delimiter into an ordered table
---@param self string
---@param delim string
---@param limit integer?
---@return string[]
function string.split(self, delim, limit) end

-- stringx.pretty = pretty.string

---trim all whitespace off the head and tail of a string
---specifically trims space, tab, newline, and carriage return characters
---ignores form feeds, vertical tabs, and backspaces
---
---only generates one string of garbage in the case there's actually space to trim
---@param s string
---@return string
function string.trim(s) end

---trim the start of a string
---@param s string
---@return string
function string.ltrim(s) end

---trim the end of a string
---@param s string
---@return string
function string.rtrim(s) end

---@param s string
---@param keep_trailing_empty boolean?
---@return string
function string.deindent(s, keep_trailing_empty) end

--alias
-- stringx.dedent = stringx.deindent

--apply a template to a string
--supports $template style values, given as a table or function
-- ie ("hello $name"):apply_template({name = "tom"}) == "hello tom"
---@param s string
---@param sub string
---@return string
function string.apply_template(s, sub) end

---check if a given string contains another
---(without garbage)
---@param haystack string
---@param needle string
---@return boolean
function string.contains(haystack, needle) end

--check if a given string starts with another
--(without garbage)
--Using loops is actually faster than string.find!
---@param s string
---@param prefix string
---@return boolean
function string.starts_with(s, prefix) end

--check if a given string ends with another
--(without garbage)
---@param s string
---@param suffix string
---@return boolean
function string.ends_with(s, suffix) end

--split elements by delimiter and trim the results, discarding empties
--useful for hand-entered "permissive" data
--	"a,b,  c, " -> {"a", "b", "c"}
---@param s string
---@param delim string
---@return string[]
function string.split_and_trim(s, delim) end

--titlizes a string
--"quick brown fox" becomes "Quick Brown Fox"
---@param s string
---@return string
function string.title_case(s) end

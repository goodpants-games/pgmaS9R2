---@class ds.PriorityQueue: batteries.Class
---@overload fun(type:"min"|"max"):ds.PriorityQueue
local PriorityQueue = batteries.class {
    name = "ds.PriorityQueue"
}








--------------------------------------------------------------------------------
-- Heap methods
--------------------------------------------------------------------------------

---@param heap any[] Priority queue heap. Items are stored in pairs (value, priority).
---@param cmp fun(a:integer,b:integer):boolean
---@param idx integer 0-based index
local function heap_shift_up(heap, cmp, idx)
    if idx == 0 then return end

    local parent_idx = math.floor((idx - 1) / 2)
    local pkey = parent_idx * 2 + 1
    local key = idx * 2 + 1

    if not cmp(heap[pkey], heap[key]) then
        heap[pkey], heap[key] = heap[key], heap[pkey]
        heap[pkey+1], heap[key+1] = heap[key+1], heap[pkey+1]
        return heap_shift_up(heap, cmp, parent_idx)
    end
end

---@param heap any[] Priority queue heap. Items are stored in pairs (value, priority).
---@param heap_count integer Number of nodes in the heap.
---@param cmp fun(a:integer,b:integer):boolean
---@param idx integer 0-based index
local function heap_shift_down(heap, heap_count, cmp, idx)
    local child1_idx = idx * 2 + 1
    local child2_idx = idx * 2 + 2

    -- no child nodes, done
    if child1_idx >= heap_count then return end

    local key = idx * 2 + 1
    local ck1 = child1_idx * 2 + 1

    -- only left child node
    if child2_idx >= heap_count then
        if not cmp(heap[key], heap[ck1]) then
            heap[key], heap[ck1] = heap[ck1], heap[key]
            heap[key+1], heap[ck1+1] = heap[ck1+1], heap[key+1]
        end

        -- this means that the parent node must be on the second-to-last
        -- layer. therefore, recursion should end here.
        return
    end

    -- both left and right child nodes
    local ck2 = child2_idx * 2 + 1

    if cmp(heap[key], heap[ck1]) and cmp(heap[key], heap[ck2]) then
        return
    end

    if cmp(heap[ck1], heap[ck2]) then
        -- swap with left
        heap[key], heap[ck1] = heap[ck1], heap[key]
        heap[key+1], heap[ck1+1] = heap[ck1+1], heap[key+1]
        return heap_shift_down(heap, heap_count, cmp, child1_idx)
    else
        -- swap with right
        heap[key], heap[ck2] = heap[ck2], heap[key]
        heap[key+1], heap[ck2+1] = heap[ck2+1], heap[key+1]
        return heap_shift_down(heap, heap_count, cmp, child2_idx)
    end
end








--------------------------------------------------------------------------------
-- PriorityQueue
--------------------------------------------------------------------------------

---@param a integer
---@param b integer
---@return boolean
local function cmp_le(a, b)
    return a < b
end

---@param a integer
---@param b integer
---@return boolean
local function cmp_ge(a, b)
    return a > b
end

---@param tp "min"|"max"|fun(a:any,b:any):boolean
function PriorityQueue:new(tp)
    ---Items are stored in pairs (value, priority)
    ---@private
    ---@type any[]
    self._heap = {}
    
    ---@type fun(a:integer, b:integer):boolean
    local cmp
    if type(tp) == "function" then
        cmp = tp
    elseif tp == "max" then
        cmp = cmp_ge
    elseif tp == "min" then
        cmp = cmp_le
    else
        error("bad argument #2 for 'new': expected 'max', 'min', or a function")
    end
    self._cmp = cmp
end

---@param value any
---@param priority any
function PriorityQueue:enqueue(value, priority)
    if value == nil then
        error("bad argument #2 for 'enqueue': value cannot be nil")
    end

    if priority == nil then
        error("bad argument #3 for 'enqueue': priority cannot be nil")
    end

    local heap = self._heap
    table.insert(heap, priority)
    table.insert(heap, value)
    heap_shift_up(heap, self._cmp, #heap / 2 - 1)
end

---@return nil|any
function PriorityQueue:dequeue()
    local heap = self._heap
    if heap[1] == nil then return nil end
    local value = heap[2]

    -- swap root with last node
    local k = #heap - 1
    heap[1], heap[k] = heap[k], heap[1]
    heap[2], heap[k+1] = heap[k+1], heap[2]

    table.remove(heap, k+1)
    table.remove(heap, k)

    heap_shift_down(heap, #heap / 2, self._cmp, 0)

    return value
end

function PriorityQueue:is_empty()
    local heap = self._heap
    return heap[1] == nil
end

---@param clear_existing_table boolean?
function PriorityQueue:clear(clear_existing_table)
    if clear_existing_table then
        table.clear(self._heap) 
    else
        self._heap = {}
    end
end

---@return integer
function PriorityQueue:len()
    return #self._heap / 2
end

function PriorityQueue:iter()
    return self.dequeue, self
end








--------------------------------------------------------------------------------
-- Test
--------------------------------------------------------------------------------

if false then
    local function permutations(t)
        if #t <= 1 then
            return {{t[1]}}
        end

        local out = {}
        for i=1, #t do
            local newt = {}
            for j=1, #t do
                if i ~= j then
                    table.insert(newt, t[j])
                end
            end

            for _, v in ipairs(permutations(newt)) do
                table.insert(v, 1, t[i])
                table.insert(out, v)
            end
        end

        return out
    end

    print("Get permutations")
    local chars = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"}
    for _, t in ipairs(permutations({1, 2, 3, 4, 5, 6, 7})) do
        local q = PriorityQueue("min")
        for _, v in ipairs(t) do
            q:enqueue(chars[v], v)
        end

        local has_error = false
        for i=1, #t do
            if chars[i] ~= q:dequeue() then
                has_error = true
            end
        end
        if q:dequeue() ~= nil then
            has_error = true
        end

        if has_error then
            print("ERROR: PRIORITY QUEUE IS BROKEN!")
            q = PriorityQueue("min")
            for _, v in ipairs(t) do
                print("push", chars[v], v)
                q:enqueue(chars[v], v)
            end

            print("===")

            while true do
                local v = q:dequeue()
                if v == nil then break end
                print("pop", v)
            end
            
            error()
            -- error("PriorityQueue is broken")
        end
    end
    print("No moar permutations")
end

return PriorityQueue
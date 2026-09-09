local help = [[
Usage: lua aa.lua <file1> <file2> ...
Load book file(s) (extension name not needed) and calculate clear balances
Example:
    lua aa.lua log1
@log1.lua:
    return {
        Pay("A", "A B C", 60), -- A paid dinner for A&B&C (A+40 B-20 C-20)
        Pay("B", "C", 10), -- B bought something for C (B+10 C-10)
        Pay("B", "A", 10), -- B repaid A (B-10 A+10)
        Pay("C", "A", 30), -- C repaid A (C-30 A+30)
    }
]]
if #arg == 0 then return print(help) end

local book = {}
local account = setmetatable({}, { __index = function() return 0 end })

---Payer(s) account+, user(s) account-
function Pay(payers, users, price)
    return { payers, users, price }
end

---@param spec string
---@param amount number
local function apply(spec, amount)
    local weight, weightSum = {}, 0
    for name in spec:gmatch("%S+") do
        if name:find("=") then
            local n, w = name:match("([^=]+)=(.+)")
            w = tonumber(w)
            weight[n] = (weight[n] or 0) + w
            weightSum = weightSum + w
        else
            weight[name] = (weight[name] or 0) + 1
            weightSum = weightSum + 1
        end
    end
    for name, w in next, weight do
        account[name] = account[name] + amount * w / weightSum
    end
end

-- Load records
for i = 1, #arg do
    for _, v in next, (require(arg[i])) do
        table.insert(book, v)
    end
end

-- Process records
for _, rec in next, book do
    apply(rec[1], rec[3])
    apply(rec[2], -rec[3])
end

-- Output
local list, list_ex = {}, {}
for k, v in next, account do table.insert(math.abs(v) > .1 and list or list_ex, { k, v }) end

local maxLen = 0
for _, v in next, list do maxLen = math.max(maxLen, #v[1]) end

table.sort(list, function(a, b) return a[2] < b[2] end)
for i = 1, #list do print(("%-" .. maxLen .. "s %.2f"):format(list[i][1], list[i][2])) end
for i = 1, #list_ex do print(("(%s %.3f)"):format(list_ex[i][1], list_ex[i][2])) end

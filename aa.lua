local help = [[
Usage: lua aa.lua <file1> <file2> ...
Load book file(s) (extension name not needed) and calculate clear balances
Example:
    lua aa.lua log1
@log1.lua:
    return {
        Pay("A", "A B C", 60), -- A paid dinner for A&B&C (A+40 B-20 C-20)
        Pay("B", "C", 10), -- B bought something for C (B+10 C-10)
        Pay("B", "A", 10), -- B repaid A (B+10 A-10)
        Pay("C", "A", 30), -- C repaid A (C+30 A-30)
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

-- Display width, counting CJK characters as 2 columns
local function width(s)
    local w = 0
    for _, c in utf8.codes(s) do
        local wide = (c >= 0x1100 and c <= 0x115F) or (c >= 0x2E80 and c <= 0xA4CF)
            or (c >= 0xAC00 and c <= 0xD7A3) or (c >= 0xF900 and c <= 0xFAFF)
            or (c >= 0xFE30 and c <= 0xFE4F) or (c >= 0xFF00 and c <= 0xFF60)
            or (c >= 0xFFE0 and c <= 0xFFE6) or (c >= 0x20000 and c <= 0x3FFFD)
        w = w + (wide and 2 or 1)
    end
    return w
end

local function pad(s, n) return s .. (" "):rep(math.max(0, n - width(s))) end

local maxLen = 0
for _, v in next, list do maxLen = math.max(maxLen, width(v[1])) end

table.sort(list, function(a, b) return a[2] < b[2] end)

-- Balances
print("净额:")
for i = 1, #list do print(("  %s %.2f"):format(pad(list[i][1], maxLen), list[i][2])) end

-- Settlement
print("转账方案:")
local debtors, creditors = {}, {}
for _, v in next, list do table.insert(v[2] < 0 and debtors or creditors, { v[1], v[2] }) end
table.sort(debtors, function(a, b) return a[2] < b[2] end)
table.sort(creditors, function(a, b) return a[2] > b[2] end)
local i, j = 1, 1
while i <= #debtors and j <= #creditors do
    local pay = math.min(-debtors[i][2], creditors[j][2])
    print(("  %s -> %s %.2f"):format(pad(debtors[i][1], maxLen), pad(creditors[j][1], maxLen), pay))
    debtors[i][2] = debtors[i][2] + pay
    creditors[j][2] = creditors[j][2] - pay
    if debtors[i][2] > -0.005 then i = i + 1 end
    if creditors[j][2] < 0.005 then j = j + 1 end
end

-- Residuals
if #list_ex > 0 then
    print("尾差:")
    for k = 1, #list_ex do print(("  %s %.3f"):format(pad(list_ex[k][1], maxLen), list_ex[k][2])) end
end

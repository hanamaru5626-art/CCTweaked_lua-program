
local storageIDs = {
  "minecraft:chest_18",
  "minecraft:chest_19",
  "minecraft:chest_20",
  "minecraft:chest_21",
  "minecraft:chest_22",
  "minecraft:chest_23",
  "minecraft:chest_24",
  "minecraft:chest_25",
}

local inputChest  = "minecraft:chest_26"
local outputChest = "minecraft:chest_27"

local ITEMS_PER_PAGE = 10


local storage = {}
for _, id in ipairs(storageIDs) do
  table.insert(storage, peripheral.wrap(id))
end

local input  = peripheral.wrap(inputChest)
local output = peripheral.wrap(outputChest)


local function storeItems()
  for slot, item in pairs(input.list()) do
    local left = item.count
    for _, chest in ipairs(storage) do
      local moved = chest.pullItems(inputChest, slot, left)
      left = left - moved
      if left <= 0 then break end
    end
  end
end


local function getItemArray()
  local map = {}
  local list = {}

  for _, chest in ipairs(storage) do
    for _, item in pairs(chest.list()) do
      map[item.name] = (map[item.name] or 0) + item.count
    end
  end

  for name, count in pairs(map) do
    table.insert(list, { name = name, count = count })
  end

  table.sort(list, function(a, b)
    return a.name < b.name
  end)

  return list
end


local currentPage = 1

local function printPage(page)
  term.clear()
  term.setCursorPos(1, 1)

  local items = getItemArray()
  local totalPages = math.max(1, math.ceil(#items / ITEMS_PER_PAGE))

  if page < 1 then page = 1 end
  if page > totalPages then page = totalPages end
  currentPage = page

  print("=== Storage === page " .. currentPage .. "/" .. totalPages)
  print("idx | count | item")
  print("------------------------------")

  local start = (currentPage - 1) * ITEMS_PER_PAGE + 1
  local finish = math.min(start + ITEMS_PER_PAGE - 1, #items)

  for i = start, finish do
    local idx = i - start + 1
    local item = items[i]
    print(string.format("%2d  | %5d | %s", idx, item.count, item.name))
  end

  print("------------------------------")
  print("< > : page   take <idx> <count>")
end


local function takeItemByIndex(idx, count)
  local items = getItemArray()
  local start = (currentPage - 1) * ITEMS_PER_PAGE + 1
  local realIndex = start + idx - 1

  local item = items[realIndex]
  if not item then
    print("invalid index")
    sleep(1)
    return
  end

  local left = count
  for _, chest in ipairs(storage) do
    for slot, it in pairs(chest.list()) do
      if it.name == item.name then
        local moved = chest.pushItems(outputChest, slot, left)
        left = left - moved
        if left <= 0 then return end
      end
    end
  end
end


while true do
  storeItems()
  printPage(currentPage)

  local line = read()

  if line == "<" then
    currentPage = currentPage - 1
  elseif line == ">" then
    currentPage = currentPage + 1
  else
    local idx, count = line:match("take%s+(%d+)%s+(%d+)")
    if idx then
      takeItemByIndex(tonumber(idx), tonumber(count))
    end
  end

  sleep(0.1)
end

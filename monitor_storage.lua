-- ==== チェスト設定 ====
local storageIDs = {
  "minecraft:chest_18","minecraft:chest_19","minecraft:chest_20","minecraft:chest_21",
  "minecraft:chest_22","minecraft:chest_23","minecraft:chest_24","minecraft:chest_25",
}
local inputChest  = "minecraft:chest_26"
local outputChest = "minecraft:chest_27"
local ITEMS_PER_PAGE = 10

local storage = {}
for _, id in ipairs(storageIDs) do table.insert(storage, peripheral.wrap(id)) end
local input  = peripheral.wrap(inputChest)
local output = peripheral.wrap(outputChest)

-- ==== モニター設定 ====
local monitor = peripheral.wrap("top")
monitor.setTextScale(0.5)
monitor.clear()
monitor.setCursorBlink(false)

-- キーパッド
local keys = {
    {"1","2","3"},
    {"4","5","6"},
    {"7","8","9"},
    {"C","0","E"},
    {"<", ">", ""}
}
local colWidth = 2
for row=1,#keys do
    for col=1,#keys[row] do
        local x = 1 + (col-1) * colWidth
        monitor.setCursorPos(x,row)
        monitor.write(keys[row][col])
    end
end

local inputCount = ""   -- 個数入力用
local selectedIdx = nil -- 選択中アイテム番号

-- ==== アイテム管理 ====
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
  local map,list = {},{}
  for _, chest in ipairs(storage) do
    for _, item in pairs(chest.list()) do
      map[item.name] = (map[item.name] or 0) + item.count
    end
  end
  for name,count in pairs(map) do table.insert(list,{name=name,count=count}) end
  table.sort(list,function(a,b) return a.name<b.name end)
  return list
end

local currentPage = 1

local function printPage(page)
  monitor.clear()
  for row=1,#keys do
      for col=1,#keys[row] do
          local x = 1 + (col-1)*colWidth
          monitor.setCursorPos(x,row)
          monitor.write(keys[row][col])
      end
  end

  local items = getItemArray()
  local totalPages = math.max(1,math.ceil(#items/ITEMS_PER_PAGE))
  if page<1 then page=1 end
  if page>totalPages then page=totalPages end
  currentPage = page

  monitor.setCursorPos(1,#keys+1)
  monitor.write("=== Storage page "..currentPage.."/"..totalPages)

  local start = (currentPage-1)*ITEMS_PER_PAGE +1
  local finish = math.min(start+ITEMS_PER_PAGE-1,#items)

  for i=start,finish do
    local item = items[i]
    monitor.setCursorPos(1,#keys+2+i-start)
    local prefix = (selectedIdx == i-start+1) and ">" or " "
    monitor.write(string.format("%s%2d:%5d %s", prefix, i-start+1, item.count, item.name))
  end

  -- 個数表示
  monitor.setCursorPos(1,#keys+ITEMS_PER_PAGE+3)
  monitor.write("Count: "..(inputCount=="" and "1" or inputCount))
end

local function takeItemByIndex(idx, count)
  local items = getItemArray()
  local start = (currentPage-1)*ITEMS_PER_PAGE +1
  local realIndex = start + idx -1
  local item = items[realIndex]
  if not item then return end

  local left = count
  for _, chest in ipairs(storage) do
    for slot,it in pairs(chest.list()) do
      if it.name==item.name then
        local moved = chest.pushItems(outputChest, slot, left)
        left = left - moved
        if left<=0 then return end
      end
    end
  end
end

-- ==== モニター操作 ====
printPage(currentPage)

while true do
  storeItems()
  printPage(currentPage)

  local event, side, x, y = os.pullEvent("monitor_touch")
  if side=="top" then
      -- キーパッド押下
      if y>=1 and y<=#keys then
          local col = math.floor((x-1)/colWidth)+1
          if col>=1 and col<=#keys[y] then
              local key = keys[y][col]
              if key=="C" then
                  inputCount = ""
              elseif key=="E" and selectedIdx then
                  takeItemByIndex(selectedIdx, tonumber(inputCount) or 1)
                  inputCount = ""
                  selectedIdx = nil
              elseif key=="<" then
                  currentPage = currentPage-1
              elseif key==">" then
                  currentPage = currentPage+1
              else
                  inputCount = inputCount..key
              end
          end
      -- アイテム行押下
      elseif y>#keys+1 and y<=#keys+ITEMS_PER_PAGE+1 then
          local idx = y-(#keys+1)
          selectedIdx = idx
      end
  end
end

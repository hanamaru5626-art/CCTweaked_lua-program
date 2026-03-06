
local inputChest = peripheral.wrap("sophisticatedbackpacks:backpack_0")
local fuelChest  = peripheral.wrap("sophisticatedbackpacks:backpack_2")
local outputChest = peripheral.wrap("sophisticatedbackpacks:backpack_1")

local powerRelay = peripheral.wrap("redstone_relay_0")
local dumpRelay  = peripheral.wrap("redstone_relay_1")

local furnacePrefix = "minecraft:furnace_"
local furnaceStart = 0
local furnaceCount = 64

local furnaces = {}

for i = 0, furnaceCount - 1 do
    furnaces[i+1] = peripheral.wrap(furnacePrefix .. (furnaceStart + i))
end

local function calcN(count)
    local n = math.floor(count / 64)
    if n < 1 then
        n = 1
    end
    return n
end

local function processInput()

    local items = inputChest.list()

    for slot, item in pairs(items) do
        if item then

            local n = calcN(item.count)

            for i, furnace in ipairs(furnaces) do
                inputChest.pushItems(
                    peripheral.getName(furnace),
                    slot,
                    n,
                    1
                )
            end

        end
    end
end

local function processFuel()

    local items = fuelChest.list()

    for slot, item in pairs(items) do
        if item and item.name == "minecraft:white_carpet" then

            local n = calcN(item.count)

            for i, furnace in ipairs(furnaces) do
                fuelChest.pushItems(
                    peripheral.getName(furnace),
                    slot,
                    n,
                    2
                )
            end

        end
    end
end


local function collectOutput()

    for i, furnace in ipairs(furnaces) do

        furnace.pushItems(
            peripheral.getName(outputChest),
            3
        )

    end
end


local function dumpAll()

    for i, furnace in ipairs(furnaces) do

        for slot = 1,3 do
            furnace.pushItems(
                peripheral.getName(outputChest),
                slot
            )
        end

    end
end

while true do

    if powerRelay.getInput("front") then

        processInput()
        processFuel()
        collectOutput()

        if dumpRelay.getInput("front") then
            dumpAll()
        end

    end

    sleep(0.2)

end

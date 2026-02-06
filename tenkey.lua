local monitorKeypad = peripheral.wrap("top")

monitorKeypad.setTextScale(0.5)
monitorKeypad.clear()
monitorKeypad.setCursorBlink(false)

local keys = {
    {"1","2","3"},
    {"4","5","6"},
    {"7","8","9"},
    {"C","0","E"}
}


local colWidth = 2


for row=1,#keys do
    for col=1,#keys[row] do
        local x = 1 + (col-1) * colWidth
        monitorKeypad.setCursorPos(x, row)
        monitorKeypad.write(keys[row][col])
    end
end


local inputText = ""


local function updateInputDisplay()
    monitorKeypad.setCursorPos(1, #keys + 1)
    monitorKeypad.clearLine()
    monitorKeypad.write(inputText)
end


while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    if side == "top" then
        if y >= 1 and y <= #keys then
            local col = math.floor((x-1)/colWidth) + 1
            if col >=1 and col <= #keys[y] then
                local key = keys[y][col]
                if key == "C" then
                    inputText = ""
                elseif key == "E" then
                    print("input"..inputText)
                    inputText = ""
                else
                    inputText = inputText .. key
                end
                updateInputDisplay()
            end
        end
    end
end

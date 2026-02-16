local net = require("net")
local bit = bit

local BANK_ADDRESS = "bank.com"
local MY_ADDRESS = 102
local AUTO_FILE = "/auto_login.dat"
local CHEST_INPUT = "minecraft:chest_31"
local CHEST_OUTPUT = "minecraft:chest_32"
local PRICE_FILE = "/disk/price_table.lua"

net.init(MY_ADDRESS)

local KEY=nil
local state="INIT"
local tempName=nil
local tempPass=nil

local checkName=nil
local checkMode=nil

local inputBuffer=""
local targetAccount=nil
local itemsInChest=nil
local totalAmount=0
local pendingAmount=0
local chestIn = peripheral.wrap(CHEST_INPUT)
local chestOut = peripheral.wrap(CHEST_OUTPUT)
if not chestIn or not chestOut then error("Cannot find chests") end
local function loadAutoLogin()
    if not fs.exists(AUTO_FILE) then return nil end
    local f = fs.open(AUTO_FILE,"r")
    local t = textutils.unserialize(f.readAll())
    f.close()
    return t
end
local function crypt(str,key)
    local out={}
    for i=1,#str do
        local k=key:byte((i-1)%#key+1)
        out[i]=string.char(bit.bxor(str:byte(i),k))
    end
    return table.concat(out)
end
local function toHex(str)
    return (str:gsub(".", function(c)
        return ("%02X"):format(c:byte())
    end))
end
local function fromHex(hex)
    if type(hex)~="string" then return nil end
    if #hex%2~=0 then return nil end
    if not hex:match("^[0-9A-Fa-f]+$") then return nil end
    return (hex:gsub("..", function(cc)
        local n = tonumber(cc,16)
        if not n then return "" end
        return string.char(n)
    end))
end
local function sendSafe(msg)
    if not KEY then return end
    net.send(BANK_ADDRESS,toHex(crypt(msg,KEY)))
end
local function randKey()
    local t={}
    for i=1,16 do
        t[i]=string.char(math.random(65,90))
    end
    return table.concat(t)
end
local function sendKey()
    KEY=randKey()
    net.send(BANK_ADDRESS,"KEY:"..KEY)
end
local priceTable={}
if fs.exists(PRICE_FILE) then
    local ok,tbl = pcall(dofile, PRICE_FILE)
    if ok and type(tbl)=="table" then
        priceTable=tbl
    end
end
local function listChestItems()
    return chestIn.list()
end
local function calculateChestTotal()
    local items=listChestItems()
    local total=0
    for slot,it in pairs(items) do
        local price=priceTable[it.name] or 0
        total=total+price*it.count
    end
    return total,items
end
local function moveItemsToOutput()
    local items=listChestItems()
    for slot,it in pairs(items) do
        chestIn.pushItems(peripheral.getName(chestOut),slot,it.count)
    end
end
local function clear()
    term.clear()
    term.setCursorPos(1,1)
end
local function draw()
    clear()
    if state=="LOGIN" then
        print("Enter your account name:")
        print(inputBuffer)
    elseif state=="PASS" then
        print("Enter your password:")
        print(string.rep("*",#inputBuffer))
    elseif state=="TARGET" then
        print("Enter source account to pay from:")
        print(inputBuffer)
    elseif state=="CONFIRM" then
        print("Confirm payment:")
        print("From account:", targetAccount)
        print("To account:", tempName)
        print("Items:")
        for slot,it in pairs(itemsInChest or {}) do
            print("-", it.count, it.name, "price:", priceTable[it.name] or 0)
        end
        print("Total:", totalAmount)
        print("Press Enter to confirm")
    elseif state=="WAIT" or state=="WAIT_SEND" then
        print("Please wait...")
    elseif state=="DONE" then
        print("Payment complete!")
        print("Press Enter to continue.")
    end
end
sendKey()
os.sleep(0.2)
local auto=loadAutoLogin()
if auto then
    tempName=auto.name
    tempPass=auto.pass
    state="WAIT"
    sendSafe("LOGIN")
    os.sleep(0.2)
    sendSafe("NAME:"..tempName..",PASS:"..tempPass)
else
    state="LOGIN"
end
draw()
while true do
    local e={os.pullEventRaw()}
    if e[1]=="modem_message" then
        local _,_,_,_,raw=table.unpack(e)
        if not raw then goto continue end
        if type(raw)=="table" and raw.data then
            raw=raw.data
        end
        if type(raw)~="string" then goto continue end
        local msg=raw
        if KEY and msg:match("^[0-9A-Fa-f]+$") then
            local bin=fromHex(msg)
            if bin then
                msg=crypt(bin,KEY)
                msg=msg:gsub("^%s+",""):gsub("%s+$","")
            end
        end
        local upper=msg:upper()
        if upper=="EXISTS" and state=="WAIT" and checkName then
            if checkMode=="LOGIN" then
                tempName=checkName
                state="PASS"
            elseif checkMode=="TARGET" then
                targetAccount=checkName
                totalAmount,itemsInChest=calculateChestTotal()
                state="CONFIRM"
            end
            checkName=nil
            checkMode=nil
        elseif upper=="NOEXIST" and state=="WAIT" and checkName then
            if checkMode=="LOGIN" then
                state="LOGIN"
                inputBuffer=""
            elseif checkMode=="TARGET" then
                state="TARGET"
                inputBuffer=""
            end
            checkName=nil
            checkMode=nil
        elseif upper=="LOGIN NAME,PASS" then
            state="LOGIN"
            inputBuffer=""
        elseif upper=="NAME,PASS" then
            state="LOGIN"
            inputBuffer=""
        elseif msg:match("^M:") then
            state="TARGET"
        elseif upper=="NAME,M" and state=="WAIT_SEND" then
            sendSafe("NAME:"..targetAccount..",M:"..pendingAmount)
            moveItemsToOutput()
            state="DONE"
        end
        draw()
    end
    if e[1]=="char" then
        local c=e[2]
        if state=="LOGIN" or state=="PASS" or state=="TARGET" then
            inputBuffer=inputBuffer..c
            draw()
        end
    end
    if e[1]=="key" then
        local k=e[2]
        if k==keys.backspace and #inputBuffer>0 then
            inputBuffer=inputBuffer:sub(1,#inputBuffer-1)
            draw()
        elseif k==keys.enter then
            if state=="LOGIN" then
                checkName=inputBuffer
                checkMode="LOGIN"
                inputBuffer=""
                state="WAIT"
                net.send(BANK_ADDRESS,"CHECK:"..checkName)
            elseif state=="PASS" then
                tempPass=inputBuffer
                inputBuffer=""
                state="WAIT"
                sendSafe("LOGIN")
                os.sleep(0.2)
                sendSafe("NAME:"..tempName..",PASS:"..tempPass)
            elseif state=="TARGET" then
                checkName=inputBuffer
                checkMode="TARGET"
                inputBuffer=""
                state="WAIT"
                net.send(BANK_ADDRESS,"CHECK:"..checkName)
            elseif state=="CONFIRM" then
                if totalAmount>0 then
                    pendingAmount=totalAmount
                    state="WAIT_SEND"
                    sendSafe("SEND")
                else
                    state="TARGET"
                end
            elseif state=="DONE" then
                state="TARGET"
            end
            draw()
        end
    end
    ::continue::
end

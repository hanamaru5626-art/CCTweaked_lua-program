local net = require("net")
local bit = bit

local BANK_ADDRESS = "bank.com"
local MY_ADDRESS = 100

net.init(MY_ADDRESS)

local AUTO_FILE = "/auto_login.dat"

local KEY=nil
local state="INIT"
local balance=0
local claimFrom=nil
local claimMoney=nil

local inputBuffer=""
local tempName=nil
local tempPass=nil
local tempTarget=nil

local function saveAutoLogin(name, pass)
  local f = fs.open(AUTO_FILE,"w")
  f.write(textutils.serialize({name=name,pass=pass}))
  f.close()
end
local function loadAutoLogin()
  if not fs.exists(AUTO_FILE) then return nil end
  local f = fs.open(AUTO_FILE,"r")
  local t = textutils.unserialize(f.readAll())
  f.close()
  return t
end
local function clearAutoLogin()
  if fs.exists(AUTO_FILE) then fs.delete(AUTO_FILE) end
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
  return (str:gsub(".",function(c)
    return ("%02X"):format(c:byte())
  end))
end
local function fromHex(hex)
  if type(hex)~="string" or #hex%2~=0 then return nil end
  return (hex:gsub("..",function(cc)
    return string.char(tonumber(cc,16))
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
local function clear()
  term.clear()
  term.setCursorPos(1,1)
end
local function draw()
  clear()
  if tempName then
    print("Account:", tempName)
    print("------------------")
  end
  if state=="INIT" then
    print("Connecting...")
  elseif state=="MODE" then
    print("1) Login")
    print("2) Create")
  elseif state=="AUTH_NAME" then
    print("Name:")
    print(inputBuffer)
  elseif state=="AUTH_PASS" then
    print("Pass:")
    print(string.rep("*",#inputBuffer))
  elseif state=="MENU" then
    print("Balance:",balance)
    print("1) Send")
    print("2) Claim")
    print("3) Logout")
    print("4) Exit")
  elseif state=="TARGET_NAME" then
    print("Target:")
    print(inputBuffer)
  elseif state=="TARGET_MONEY" then
    print("Money:")
    print(inputBuffer)
  elseif state=="CLAIM" then
    print("Claim from:",claimFrom)
    print("Amount:",claimMoney)
    print("1) Yes")
    print("2) No")
  elseif state=="WAIT" then
    print("Please wait...")
  end
end
sendKey()
draw()
local auto = loadAutoLogin()
if auto then
  tempName = auto.name
  tempPass = auto.pass
  state = "WAIT"
  sendSafe("LOGIN")
  os.sleep(0.1)
  sendSafe("NAME:"..tempName..",PASS:"..tempPass)
end
while true do
  local e = {os.pullEventRaw()}
  if e[1]=="modem_message" then
    local _, side, ch, replyChannel, raw = table.unpack(e)
    if ch ~= MY_ADDRESS then goto continue end
    if type(raw) ~= "table" then goto continue end
    if not raw.data then goto continue end
    local msg = raw.data
    if KEY and type(msg)=="string" and not msg:match("^KEY:") then
      local bin = fromHex(msg)
      if not bin then goto continue end
      msg = crypt(bin,KEY)
      msg = msg:gsub("^%s+",""):gsub("%s+$","")
    end
    local upper = type(msg)=="string" and msg:upper() or ""
    if upper=="LOGIN" then
      state="MODE"
      local auto2 = loadAutoLogin()
      if auto2 then
        tempName = auto2.name
        tempPass = auto2.pass
        state = "WAIT"
        sendSafe("LOGIN")
        os.sleep(0.1)
        sendSafe("NAME:"..tempName..",PASS:"..tempPass)
      end
    elseif upper=="LOGIN NAME,PASS"
        or upper=="NAME,PASS" then
      state="AUTH_NAME"
      inputBuffer=""
    elseif type(msg)=="string" and msg:match("^M:") then
      balance=tonumber(msg:match("M:(%d+)")) or 0
      if tempName and tempPass then
        saveAutoLogin(tempName,tempPass)
      end
      state="MENU"
    elseif upper=="NAME,M" then
      state="TARGET_NAME"
      inputBuffer=""
    elseif upper=="SEND OK"
        or upper=="SEND FAIL"
        or upper=="CLAIM SENT"
        or upper=="CLAIM OK"
        or upper=="CLAIM DENY"
        or upper=="CLAIM ACCEPTED"
        or upper=="CLAIM FAIL" then
      state="MENU"
    elseif type(msg)=="string" and msg:match("^CLAIM_REQ") then
      claimFrom=msg:match("FROM:(.-),")
      claimMoney=tonumber(msg:match("M:(%d+)")) or 0
      state="CLAIM"
    elseif upper=="COMP" then
      KEY=nil
      state="INIT"
      sendKey()
    end
    draw()
  end
  if e[1]=="char" then
    local c=e[2]
    if state=="MODE" then
      if c=="1" then sendSafe("LOGIN") state="WAIT"
      elseif c=="2" then sendSafe("CREATE") state="WAIT" end
    elseif state=="AUTH_NAME"
        or state=="AUTH_PASS"
        or state=="TARGET_NAME"
        or state=="TARGET_MONEY" then
      inputBuffer=inputBuffer..c
    elseif state=="MENU" then
      if c=="1" then sendSafe("SEND") state="WAIT"
      elseif c=="2" then sendSafe("CLAIM") state="WAIT"
      elseif c=="3" then
        clearAutoLogin()
        net.send(BANK_ADDRESS,"disconnect")
        KEY=nil
        state="INIT"
        sendKey()
      elseif c=="4" then
        net.send(BANK_ADDRESS,"disconnect")
        os.shutdown()
      end
    elseif state=="CLAIM" then
      if c=="1" then sendSafe("YES") state="WAIT"
      elseif c=="2" then sendSafe("NO") state="WAIT" end
    end
    draw()
  end
  if e[1]=="key" then
    local k = e[2]
    if k == keys.backspace then
      if state=="AUTH_NAME"
        or state=="AUTH_PASS"
        or state=="TARGET_NAME"
        or state=="TARGET_MONEY" then
        if #inputBuffer > 0 then
          inputBuffer = inputBuffer:sub(1,#inputBuffer-1)
        end
      end
      draw()
    end
    if k == keys.enter then
      if state=="AUTH_NAME" then
        tempName=inputBuffer
        inputBuffer=""
        state="AUTH_PASS"
      elseif state=="AUTH_PASS" then
        tempPass=inputBuffer
        sendSafe("NAME:"..tempName..",PASS:"..inputBuffer)
        state="WAIT"
      elseif state=="TARGET_NAME" then
        tempTarget=inputBuffer
        inputBuffer=""
        state="TARGET_MONEY"
      elseif state=="TARGET_MONEY" then
        sendSafe("NAME:"..tempTarget..",M:"..inputBuffer)
        state="WAIT"
      end
      draw()
    end
  end
  ::continue::
end

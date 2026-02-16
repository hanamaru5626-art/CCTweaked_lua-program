local net = require("net")
local bit = bit

net.init(12)

local ACCOUNT_FILE = "/accounts.dat"
local LOG_FILE = "/transactions.log"

local sessions = {}
local ADMIN_PASSWORD = "admin123"
local function crypt(str, key)
  local out = {}
  for i = 1, #str do
    local k = key:byte((i - 1) % #key + 1)
    out[i] = string.char(bit.bxor(str:byte(i), k))
  end
  return table.concat(out)
end
local function toHex(str)
  return (str:gsub(".", function(c)
    return ("%02X"):format(c:byte())
  end))
end
local function fromHex(hex)
  if not hex or #hex % 2 ~= 0 then return nil end
  return (hex:gsub("..", function(cc)
    return string.char(tonumber(cc, 16))
  end))
end
local function sendSafe(to, msg)
  if not sessions[to] then return end
  net.send(to, toHex(crypt(msg, sessions[to].key)))
end
local function load()
  if not fs.exists(ACCOUNT_FILE) then return {} end
  local f = fs.open(ACCOUNT_FILE,"r")
  local t = textutils.unserialize(f.readAll())
  f.close()
  return t or {}
end
local function save(t)
  local f = fs.open(ACCOUNT_FILE,"w")
  f.write(textutils.serialize(t))
  f.close()
end
local function log(text)
  local f = fs.open(LOG_FILE,"a")
  f.writeLine(os.date("%H:%M:%S").." "..text)
  f.close()
end
local accounts = load()
for _,a in pairs(accounts) do a.online=nil end
save(accounts)
local function hash(str)
  local h = 0
  for i=1,#str do
    h = (h*31 + str:byte(i)) % 2^32
  end
  return tostring(h)
end
local function updateBalance(name)
  local acc = accounts[name]
  if not acc then return end
  local ch = acc.online
  if ch and sessions[ch] then
    sendSafe(ch,"M:"..acc.money)
  end
end
while true do
  local from, raw = net.receive()
  if not raw then goto continue end
  if type(raw)=="string" and raw:match("^CHECK:") then
    local name = raw:sub(7)
    if accounts[name] then
      net.send(from,"EXISTS")
    else
      net.send(from,"NOEXIST")
    end
    goto continue
  end
  if raw == "disconnect" then
    if sessions[from] and sessions[from].name then
      local acc = accounts[sessions[from].name]
      if acc then acc.online=nil end
      save(accounts)
      print(os.date("%H:%M:%S").." "..sessions[from].name.." disconnected")
    end
    sessions[from]=nil
    goto continue
  end
  if raw:match("^KEY:") then
    sessions[from] = {
      key = raw:sub(5),
      state = "MODE"
    }
    sendSafe(from,"LOGIN")
    goto continue
  end
  local s = sessions[from]
  if not s then goto continue end
  local bin = fromHex(raw)
  if not bin then goto continue end
  local msg = crypt(bin,s.key)
  msg = msg:gsub("^%s+",""):gsub("%s+$","")
  local upper = msg:upper()
  if s.state=="MODE" then
    if upper=="LOGIN" then
      s.state="LOGIN"
      sendSafe(from,"LOGIN NAME,PASS")
    elseif upper=="CREATE" then
      s.state="CREATE"
      sendSafe(from,"NAME,PASS")
    end
  elseif s.state=="CREATE" then
    local name=msg:match("NAME:(.-),")
    local pass=msg:match("PASS:(.+)")
    if name and pass and not accounts[name] then
      accounts[name]={pass=hash(pass),money=0}
      save(accounts)
      sendSafe(from,"COMP")
      sessions[from]=nil
      print(os.date("%H:%M:%S").." New account created: "..name)
    else
      sendSafe(from,"NAME,PASS")
    end
  elseif s.state=="LOGIN" then
    local name=msg:match("NAME:(.-),")
    local pass=msg:match("PASS:(.+)")
    local acc=accounts[name]
    if acc and acc.pass==hash(pass) then
      acc.online=from
      save(accounts)
      s.state="MENU"
      s.name=name
      sendSafe(from,"M:"..acc.money)
      print(os.date("%H:%M:%S").." "..name.." logged in")
    else
      sendSafe(from,"LOGIN NAME,PASS")
    end
  elseif s.state=="MENU" then
    if msg:match("^ADMIN:") then
      local pass,name,amount =
        msg:match("^ADMIN:(.-),NAME:(.-),M:(%d+)")
      amount = tonumber(amount)
      if pass==ADMIN_PASSWORD and accounts[name] then
        accounts[name].money =
          accounts[name].money + amount
        save(accounts)
        log("ADMIN +"..amount.." to "..name)
        print(os.date("%H:%M:%S").." ADMIN +"..amount.." to "..name)
        updateBalance(name)
        sendSafe(from,"ADMIN OK")
      else
        sendSafe(from,"ADMIN FAIL")
      end
    elseif upper=="SEND" then
      s.state="SEND"
      sendSafe(from,"NAME,M")
    elseif upper=="CLAIM" then
      s.state="CLAIM"
      sendSafe(from,"NAME,M")
    end
  elseif s.state=="SEND" then
    local target=msg:match("NAME:(.-),")
    local money=tonumber(msg:match("M:(%d+)"))
    if target and money and money>0
       and accounts[target]
       and accounts[s.name].money>=money then
      accounts[s.name].money =
        accounts[s.name].money - money
      accounts[target].money =
        accounts[target].money + money
      save(accounts)
      log(s.name.." -> "..target.." : "..money)
      print(os.date("%H:%M:%S").." Transaction: "..s.name.." -> "..target.." : "..money)
      sendSafe(from,"SEND OK")
      updateBalance(s.name)
      updateBalance(target)
    else
      sendSafe(from,"SEND FAIL")
    end
    s.state="MENU"
  elseif s.state=="CLAIM" then
    local target=msg:match("NAME:(.-),")
    local money=tonumber(msg:match("M:(%d+)"))
    if target and money and money>0
       and accounts[target]
       and accounts[target].online
       and sessions[accounts[target].online] then
      local t=accounts[target].online
      sessions[t].claim={
        from=s.name,
        money=money
      }
      sessions[t].state="CLAIM_WAIT"
      sendSafe(t,
        "CLAIM_REQ,FROM:"..s.name..",M:"..money)
      sendSafe(from,"CLAIM SENT")
      print(os.date("%H:%M:%S").." Claim request sent from "..s.name.." to "..target.." amount "..money)
    else
      sendSafe(from,"CLAIM FAIL")
      print(os.date("%H:%M:%S").." Claim failed from "..s.name.." to "..(target or "nil"))
    end
    s.state="MENU"
  elseif s.state=="CLAIM_WAIT" then
    if s.claim and (upper=="YES" or upper=="NO") then
      local c=s.claim
      if upper=="YES"
         and accounts[s.name].money>=c.money
         and accounts[c.from] then
        accounts[s.name].money =
          accounts[s.name].money - c.money
        accounts[c.from].money =
          accounts[c.from].money + c.money
        save(accounts)
        log("CLAIM "..c.from.." <- "..s.name.." : "..c.money)
        print(os.date("%H:%M:%S").." CLAIM: "..c.from.." <- "..s.name.." : "..c.money)
        sendSafe(from,"CLAIM OK")
        updateBalance(s.name)
        updateBalance(c.from)
        local t=accounts[c.from].online
        if t and sessions[t] then
          sendSafe(t,"CLAIM ACCEPTED")
        end
      else
        sendSafe(from,"CLAIM DENY")
        print(os.date("%H:%M:%S").." CLAIM denied by "..s.name)
      end
      s.claim=nil
      s.state="MENU"
    end
  end
  ::continue::
end

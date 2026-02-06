local function loadDNS(path)
  local list = {}
  if not fs.exists(path) then return list end
  local f = fs.open(path, "r")
  if not f then return list end
  while true do
    local line = f.readLine()
    if not line then break end
    local name, value = line:match("^([^:]+):(%d+)$")
    if name and value then
      table.insert(list, {name = name,value = tonumber(value)})
    end
  end
  f.close()
  return list
end

local function saveDNS(path, list)
  local f = fs.open(path, "w")
  if not f then return false end
  for _, v in ipairs(list) do
    f.writeLine(v.name .. ":" .. v.value)
  end
  f.close()
  return true
end

local function addDNS(list, name, value)
  table.insert(list, {name = name,value = tonumber(value)})
end

local function deleteDNS(list, index)
    if type(index) ~= "number" then return false end
    if index < 1 or index > #list then return false end
    table.remove(list, index)
    return true
end

input=""
power="off"

while true do
term.clear()
term.setCursorPos(1,1)
print(string.format(
[[
DNS Server


state :%s

1:power on/off
2:DNS edit

]]
,power))
input=read()
if input=="1" then
    if power=="off"
        then power="on"
    elseif power=="on" then
        power="off"
    end
elseif input=="2" then
    page=1
    select=1
    while true do
        term.clear()
        term.setCursorPos(1,1)
        dns=loadDNS("/disk/dns.txt")
        count=#dns
        max_page=math.max(1,math.ceil(count/10))
        
        print(string.format(
[[
DNS Server


page %s
]]
        ,page))
        start=1
        finish=math.min(page*10,count)-(page-1)*10
        for i=start,finish do
            local ri = (page - 1) * 10 + i
            
            if select==i then select_cur="<"
            else select_cur="" end
            print(string.format("%2d %s:%d %s",i,dns[ri].name,dns[ri].value,select_cur))
        end
        print(
[[

---------------------------------------------------
< :back page
 >:next page
1~10 :select domain
a :add  n :domain  i :IP  d :delete  b :back]]
        )
        input_edit=read()
        if input_edit=="a" then
            term.clear()
            term.setCursorPos(1,1)
            print(
[[
DNS Server


domain :?
]]
            )
            domain=read()
            while true do
                term.clear()
                term.setCursorPos(1,1)
                print(string.format(
[[
DNS Server


domain :%s
IP :?
]]
                ,domain))
                IP=read()
                if tonumber(IP) then
                    addDNS(dns, domain, IP)
                    saveDNS("/disk/dns.txt", dns)
                    break
                end
            end
        elseif input_edit=="b" then
            break
        elseif input_edit==">" then
            if page<max_page then
                page=page+1
                select=1
            end
        elseif input_edit=="<" then
            if page>1 then
                page=page-1
                select=1
            end
        elseif input_edit=="d" then
            local realIndex = (page - 1) * 10 + select
            if deleteDNS(dns, realIndex) then
                saveDNS("/disk/dns.txt", dns)
                local maxSelect = math.min(10, #dns - (page - 1) * 10)
                if maxSelect < 1 then
                    page = math.max(1, page - 1)
                    maxSelect = math.min(10, #dns - (page - 1) * 10)
                end
                select = math.min(select, maxSelect)
            end
        elseif tonumber(input_edit) then
            local num = tonumber(input_edit)
            local start = (page - 1) * 10 + 1
            local finish = math.min(page * 10, #dns)
            if start + num - 1 <= finish then
                select = num
            end
        elseif input_edit=="n" then
            local realIndex = (page - 1) * 10 + select
            if dns[realIndex] then
                term.clear()
                term.setCursorPos(1,1)
                print(string.format(
[[
DNS Server


domain :%s
?
]]
                ,dns[realIndex].name))
                local newDomain = read()
                dns[realIndex].name = newDomain
                saveDNS("/disk/dns.txt", dns)
            end
        elseif input_edit=="i" then
            local realIndex = (page - 1) * 10 + select
            if dns[realIndex] then
                while true do
                    term.clear()
                    term.setCursorPos(1,1)
                    print(string.format(
[[
DNS Server


domain :%s
IP :%s
?
]]
                    ,dns[realIndex].name, dns[realIndex].value))
                    local newIP = read()
                    if tonumber(newIP) then
                        dns[realIndex].value = newIP
                        saveDNS("/disk/dns.txt", dns)
                        break
                    end
                end
            end
        end
    end
end
end

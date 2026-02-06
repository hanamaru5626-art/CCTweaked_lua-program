term.clear()
term.setCursorPos(1,1)
local modem = peripheral.find("modem")
local DNS_CHANNEL  = 1
local MAIN_CHANNEL = 0

modem.open(DNS_CHANNEL)

local function loadDNS()
    local dns = {}
    
    if not fs.exists("/disk/dns.txt") then
        print("dns.txt not found")
        return dns
    end
    for line in io.lines("disk/dns.txt") do
        local domain, ip = line:match("([^:]+):(%d+)")
        if domain and ip then
            dns[domain] = tonumber(ip)
        end
    end
    return dns
end

local dnsTable = loadDNS()
print("loaded dns.txt")
while true do
    local _, _, ch, reply, msg = os.pullEvent("modem_message")
    if ch == DNS_CHANNEL and type(msg) == "table" then
        local ip = dnsTable[msg.to]
        if ip then
            msg.to = ip
            modem.transmit(MAIN_CHANNEL,DNS_CHANNEL,msg)
        else
            print("domain is not found")
        end
    end
end

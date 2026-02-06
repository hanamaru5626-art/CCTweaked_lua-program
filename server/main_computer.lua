term.clear()
term.setCursorPos(1,1)
local modem =peripheral.find("modem")
local MAIN_CHANNEL = 0
local DNS_CHANNEL  = 1

modem.open(MAIN_CHANNEL)

print("starting main computer")

while true do
    local _, _, ch, reply, msg =os.pullEvent("modem_message")
    if ch ~= MAIN_CHANNEL or type(msg) ~="table" then goto continue end
    local dest = msg.to
    if tonumber(dest) then
        modem.transmit(tonumber(dest),msg.from,msg)
    else
        modem.transmit(DNS_CHANNEL,MAIN_CHANNEL,msg)
    end
    ::continue::
end

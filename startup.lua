local url = "https://raw.githubusercontent.con/hanamaru5626-art/CCTweaked_lua-program/"
local response = http.get(url)
if not response then
    term.clear()
    term.setCursorPos(1,1)
    print("Sorry, something went wrong. ")
    print("Please check your internet connection or restart. ")
    print("If the problem persists, report the problem to a technician.")
    print("00")
else
    local code = response.readAll()
    response.close()
    
    local fn, err = load(code, url)
    if not fn then
        term.clear()
        term.setCursorPos(1,1)
        print("Sorry, something went wrong. ")
        print("Please check your internet connection or restart. ")
        print("If the problem persists, report the problem to a technician.")
        print("01")
    else
        fn()
    end

end

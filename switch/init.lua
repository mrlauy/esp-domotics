-- load credentials, 'SSID' and 'PASSWORD' declared and initialize in there
dofile("credentials.lua")

function startup()
    if file.open("init.lua") == nil then
        print("init.lua deleted or renamed")
    else
        print("Running")
        file.close("init.lua")
        -- the actual application is stored in 'application.lua'
        -- dofile("application.lua")
    end
end

-- Byline
print('\nStarting Power NodeMCU\n')

-- Configure Wireless Internet
wifi.setmode(wifi.STATION)
wifi.sta.config(SSID,PASSWORD)

print('set mode=STATION (mode='..wifi.getmode()..')\n')
print('MAC Address: ',wifi.sta.getmac())
print('Chip ID: ',node.chipid())
print('Heap Size: ',node.heap(),'\n')

wifi.sta.config{ssid=ssid, pwd=pass}

----------------------------------
-- WiFi Connection Verification --
----------------------------------
tmr.alarm(0, 1000, 1, function()
   if wifi.sta.getip() == nil then
      print("Connecting to AP...\n")
   else
      ip, nm, gw=wifi.sta.getip()
      print("IP Info: \nIP Address: ",ip)
      print("Netmask: ",nm)
      print("Gateway Addr: ",gw,'\n')
      tmr.stop(0)
   end
end)


----------------------
-- Global Variables --
----------------------
power_pin = 3
led_pin = 4

gpio.mode(power_pin, gpio.OUTPUT)
gpio.mode(led_pin, gpio.OUTPUT)

----------------------
-- Config Webserver --
----------------------
print("start server at port 80")
srv=net.createServer(net.TCP)
srv:listen(80,function(conn)
    conn:on("receive", function(client,request)

		-- parse request
        local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP");
        if(method == nil)then
            _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP");
        end
        local _GET = {}
        if (vars ~= nil)then
            for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
                _GET[k] = v
            end
        end

        -- execute command
        local _on,_off = "",""
        if(_GET.pin == "ON1")then
		    print("turn on power_pin");
		    gpio.write(power_pin, gpio.HIGH);
        elseif(_GET.pin == "OFF1")then
		    print("turn off power_pin");
              gpio.write(power_pin, gpio.LOW);
        elseif(_GET.pin == "ON2")then
		    print("turn on led_pin");
              gpio.write(led_pin, gpio.HIGH);
        elseif(_GET.pin == "OFF2")then
		    print("turn off led_pin");
              gpio.write(led_pin, gpio.LOW);
        end

		-- HTML Header Stuff
        conn:send('HTTP/1.1 200 OK\n\n')
        conn:send('<!DOCTYPE HTML>\n')
        conn:send('<html>\n')
        conn:send('<head><meta  content="text/html; charset=utf-8">\n')
        conn:send('<title>ESP8266 Power Node</title></head>\n')
        conn:send('<body><h1>ESP8266 Power Node!</h1>\n')

        conn:send('<p>POWER <a href="?pin=ON1"><button>ON</button></a>&nbsp;<a href="?pin=OFF1"><button>OFF</button></a></p>');
        conn:send('<p>LED   <a href="?pin=ON2"><button>ON</button></a>&nbsp;<a href="?pin=OFF2"><button>OFF</button></a></p>');

        conn:send('</body></html>\n')
        conn:on("sent", function(conn)
        	conn:close()
        end)

        collectgarbage();
    end)
end)

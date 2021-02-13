-- load credentials, 'SSID' and 'PASSWORD' declared and initialize in there
dofile("credentials.lua")

function startup()
    if file.open("init.lua") == nil then
        print("init.lua deleted or renamed")
    else
        -- the actual application is stored in 'application.lua'
        -- dofile("application.lua")
        print("Running")
        file.close("init.lua")
    end
end

---------------------
-- WiFi Connection --
---------------------
wifi.setmode(wifi.STATION)
wifi.sta.config(SSID,PASSWORD)

wifitimer = tmr.create()
wifitimer:register(500, tmr.ALARM_SEMI, function()
   if wifi.sta.getip() == nil then
      print("Connecting to AP...\n")
      wifitimer:start()
   else
      print("====================================")
      print("ESP8266 mode is: " .. wifi.getmode())
      print("MAC address is: " .. wifi.ap.getmac())
      print("IP is ".. wifi.sta.getip())
      print("Chip ID: ".. node.chipid())
      print("Heap Size: ".. node.heap() .."\n")
      print("====================================")
      wifitimer:unregister()
   end
end)
wifitimer:start()

----------------------
-- Global Variables --
----------------------
dht11_pin1 = 3 -- GPIO0
dht11_pin2 = 4 -- GPIO2

temperature=0.0
humidity=0.0
message=""

--------------------
-- get DHT11 data --
--------------------
function getData(pin)
  status, temperature, humidity, temperature_dec, humidity_dec = dht.read(pin)
  if status == dht.OK then
      temperature = temperature / 25.6
      humidity = humidity / 25.6
      print("DHT "..pin.." Temperature:"..temperature..";".."Humidity:"..humidity)
      message = ""
  elseif status == dht.ERROR_CHECKSUM then
      print( "DHT "..pin.." Checksum error." )
      message = "DHT "..pin.." Checksum error."
  elseif status == dht.ERROR_TIMEOUT then
      print( "DHT "..pin.." timed out." )
      message = "DHT "..pin.." timed out."
  end
end

----------------------
-- Config Webserver --
----------------------
print("start server at port 80")
srv=net.createServer(net.TCP)
srv:listen(80,function(conn)
    conn:on("receive", function(client,request)
      conn:send('HTTP/1.1 200 OK\n\n')
      conn:send('<!DOCTYPE HTML><html>')
      conn:send('<head>')
      conn:send('<meta name="viewport" content="width=device-width, initial-scale=1">')
      conn:send('<link rel="stylesheet" href="https://use.fontawesome.com/releases/v5.7.2/css/all.css" integrity="sha384-fnmOCqbTlWIlj8LyTjo7mOUStjsKC4pOpQbqyi7RrhN7udi9RwhKkMHpvLbHG9Sr" crossorigin="anonymous">')
      conn:send('<style>')
      conn:send('html {')
      conn:send('font-family: Arial;')
      conn:send('display: inline-block;')
      conn:send('margin: 0px auto;')
      conn:send('text-align: center;')
      conn:send('}')
      conn:send('h2 { font-size: 3.0rem; }')
      conn:send('p { font-size: 3.0rem; }')
      conn:send('.units { font-size: 1.2rem; }')
      conn:send('.dht-labels{')
      conn:send('font-size: 1.5rem;')
      conn:send('vertical-align:middle;')
      conn:send('padding-bottom: 15px;')
      conn:send('}')
      conn:send('</style>')
      conn:send('</head>')
      conn:send('<body>')
      conn:send('<h2>ESP8266 DHT Server</h2>')
      conn:send('<p>')
      conn:send('<i class="fas fa-thermometer-half" style="color:#059e8a;"></i>')
      conn:send('<span class="dht-labels"> Temperature: </span>')
      conn:send('<span id="temperature">'..temperature..'</span>')
      conn:send('<sup class="units">&deg;C</sup>')
      conn:send('</p>')
      conn:send('<p>')
      conn:send('<i class="fas fa-tint" style="color:#00add6;"></i>')
      conn:send('<span class="dht-labels"> Humidity: </span>')
      conn:send('<span id="humidity">'..humidity..'</span>')
      conn:send('<sup class="units">%</sup>')
      conn:send('</p>')
      conn:send('<p>')
      conn:send('<i><span class="dht-labels">'..message ..'</span></i>')
      conn:send('</p>')

      conn:send('</body></html>\n')
      conn:on("sent", function(conn)
        conn:close()
      end)

      collectgarbage();
    end)
end)

---------------------------
-- start data collection --
---------------------------
--getData(dht11_pin1) -- for debugging
--getData(dht11_pin2) -- for debugging

i = false
datatimer = tmr.create()
datatimer:register(2000, tmr.ALARM_AUTO, function()
  if state then
    getData(dht11_pin1)
    state = false
  else
    -- getData(dht11_pin2)
    state = true
  end
end)
datatimer:start()

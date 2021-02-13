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

messages = {}
function log(message)
  print(message)
  if table.getn(messages) > 10 then
    table.remove(messages, 1)
  end
  table.insert(messages, message)
end

---------------------
-- WiFi Connection --
---------------------
wConnected = false

function wConnect(callback)
  -- Configure Wireless Internet
  wifi.setmode(wifi.STATION)
  wifi.sta.config(SSID,PASSWORD)

  wifitimer = tmr.create()
  wifitimer:register(500, tmr.ALARM_SEMI, function()
     if wifi.sta.getip() == nil then
        log("Connecting to AP...")
        wifitimer:start()
     else
        wConnected = true
        log("====================================")
        log("ESP8266 mode is: " .. wifi.getmode())
        log("MAC address is: " .. wifi.ap.getmac())
        log("IP is ".. wifi.sta.getip())
        log("Chip ID: ".. node.chipid())
        log("Heap Size: ".. node.heap() .."\n")
        log("====================================")
        wifitimer:unregister()
        callback()
     end
  end)
  wifitimer:start()
end

----------------
-- setup mqtt --
----------------
mTopic = "environmentals"
mHost = "10.0.0.21"
mPort = 1883
mSSL = false
mId = "esp"

mConnected = false
mClient = mqtt.Client("esp8266", 120)
function mConnect(callback)
  mClient:connect(mHost, mPort, mSSL, function(client)
    mConnected = true
    log("mqtt connected to: ".. mHost)
    callback()
  end,
  function(client, reason)
    log("mqtt failed reason: " .. reason)
  end)
end

function publish(data, callback)
  if mConnected then
    mClient:publish(mTopic, data, 0, 0, function(client)
      log("data sent: '"..data.."'")
      callback()
    end)
  else
    log("mqtt client not connected, nothing published: ".. data)
  end
end

----------
-- LEDs --
----------
ledPin = 4 -- GPIO2
gpio.mode(ledPin, gpio.OUTPUT)

stopLedTimer = tmr.create()
stopLedTimer:register(3000, tmr.ALARM_SEMI, function()
  gpio.write(ledPin, gpio.LOW)
end)

function showLED()
  gpio.write(ledPin, gpio.HIGH)
  stopLedTimer:start()
end

----------------
-- web server --
----------------
sStarted = false
function startServer()
  if sStarted then
    return
  end
  sStarted = true
  srv=net.createServer(net.TCP)
  srv:listen(80,function(conn)
      conn:on("receive", function(client,request)
        conn:send('HTTP/1.1 200 OK\n\n')
        conn:send('<!DOCTYPE HTML><html>')
        conn:send('<head>')
        conn:send('<meta name="viewport" content="width=device-width, initial-scale=1">')
        conn:send('<style>')
        conn:send('html { ')
        conn:send('font-family: Arial; ')
        conn:send('display: inline-block; ')
        conn:send('margin: 0px auto; ')
        conn:send('text-align: center; ')
        conn:send('} ')
        conn:send('h2 { font-size: 3.0rem; } ')
        conn:send('.messages { background-color: #999999; text-align: left; border: 1px solid; padding: 3px; } ')
        conn:send('.units { font-size: 1.2rem; } ')
        conn:send('.labels{ ')
        conn:send('font-size: 1.5rem; ')
        conn:send('vertical-align:middle; ')
        conn:send('padding-bottom: 15px; ')
        conn:send('} ')
        conn:send('</style>')
        conn:send('</head>')
        conn:send('<body>')
        conn:send('<h2>ESP8266 Server</h2>')
        conn:send('<h4>logging</h4>')
        conn:send('<p class="messages">')
        conn:send('<span>'..table.concat(messages, "<br>")..'</span>')
        conn:send('</p>')
        conn:send('</body></html>\n')
        conn:on("sent", function(conn)
          conn:close()
        end)

        collectgarbage();
      end)
  end)
end

function publishData(once, data)
  publish(data, function()
    if once then
      log("time for sleep")
      -- mClient:close()  -- still nil, because everything is called via callbacks
      -- uart.on("data") -- unregister callback function
      node.dsleep(0) -- sleep time in micro second. If us == 0, it will sleep forever
    end
  end)
end

mConnecting = false
function connect(once, callback)
  if mConnecting then
    log("try to connect when already connecting")
  elseif not wConnected then
    mConnecting = true
    log("init wifi connection")
    wConnect(function()
      mConnecting = false
      connect(once, callback)
    end)
  elseif not mConnected then
    mConnecting = true
    log("init mqtt connection")
    mConnect(function()
      mConnecting = false
      connect(once, callback)
    end)
  else
    callback()
    if not once then
      startServer()
    end
  end
end

function sendData(once, data)
  connect(once,function()
    publishData(once, data)
  end)
end

function startWith(string,start)
   return string.sub(string,1,string.len(start))==start
end

log('\nStarting Environment NodeMCU')
connect(true, function()
  print("READY")
end)

-- SEND:{"testing":"send this!"}
-- UPDATE:{"testing":"this!"}
-- LOG:message
uart.on("data", "\r",
  function(data)
    log("receive from uart: ".. data)
    if startWith(data, "SEND") then
      sendData(true, string.sub(data,1 + string.len("SEND:")))
    elseif startWith(data, "UPDATE") then
      sendData(false, string.sub(data, 1 + string.len("UPDATE:")))
    elseif startWith(data, "LOG") then
      log(string.sub(data, 1 + string.len("LOG:")))
    elseif startWith(data, "FORMAT") then
      -- watchout for when shit fails
      print("formatinng esp")
      file.format()
    elseif startWith(data, "QUIT") then
      print("stopping esp")
      uart.on("data") -- unregister callback function
    else
      log("unkown command: " .. data)
      print("stopping esp")
      uart.on("data") -- unregister callback function
    end
    -- for debug purposes, stop to prevent hanging in there
    -- uart.on("data") -- unregister callback function
end, 0)

-- print("READY")

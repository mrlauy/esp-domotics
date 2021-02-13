-- Based on work by  gwizz, zeroday & sancho among many other open source authors
-- This code is public domain

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

-- read from reg_addr content of dev_addr
function read_reg(dev_addr, reg_addr)
    i2c.start(id)
    i2c.address(id, dev_addr, i2c.TRANSMITTER)
    i2c.write(id, reg_addr)
    i2c.stop(id)
    i2c.start(id)
    i2c.address(id, dev_addr, i2c.RECEIVER)
    c = i2c.read(id, 1)
    i2c.stop(id)
    return c
end

----------------------
-- Global Variables --
----------------------
temperature = 0
humidity = 0
pressure = 0
dewpoint = 0
message = "waiting for first measurement"

id = 0 -- need this to identify (software) IC2 bus?
sda = 3 -- connect to pin GPIO0
scl = 4 -- connect to pin GPIO2

mqtt_topic = "environmentals/bme280"
mqtt_host = "10.0.0.21"
mqtt_port = 1883
mqtt_ssl = false
mqtt_id = "esp-bme"

----------------
-- initialize --
----------------
i2c.setup(id, sda, scl, i2c.SLOW) -- initialize i2c with our id and pins in slow mode :-)

print("Scanning I2C Bus")
for i = 0, 127 do
    if (string.byte(read_reg(i, 0)) == 0) then
        print("Device found at address " .. string.format("%02X", i))
    end
end

bme280.setup()

---------------------
-- WiFi Connection --
---------------------
print("connect to AP: " .. ssid)
wifi.setmode(wifi.STATION)

wifitimer = tmr.create()
wifitimer:register(500, tmr.ALARM_SEMI, function()
    if wifi.sta.getip() == nil then
        print("Connecting to AP...")
        wifitimer:start()
    else
        print("====================================")
        print("ESP8266 mode is: " .. wifi.getmode())
        print("MAC address is: " .. wifi.ap.getmac())
        print("IP is " .. wifi.sta.getip())
        print("Chip ID: " .. node.chipid())
        print("Heap Size: " .. node.heap())
        print("====================================")
        wifitimer:unregister()
        mqtt_connect()
    end
end)
wifitimer:start()

----------------
-- setup mqtt --
----------------
mqtt_client = mqtt.Client("esp8266", 120)
function mqtt_connect()
    print("connecting to mqtt host: " .. mqtt_host)
    mqtt_client:connect(mqtt_host, mqtt_port, mqtt_ssl,
        function(client)
            print("mqtt connected to: " .. mqtt_host)
            -- collect the first specimen
            collect()
        end,
        function(client, reason)
            print("mqtt connection failed reason: " .. reason)
        end
    )
end

function publish(data)
    mqtt_client:publish(mqtt_topic, data, 0, 0, function(client)
        print("data sent: '" .. data .. "'")
    end)
end

----------------------
-- Config Webserver --
----------------------
print("start server at port 80")
srv = net.createServer(net.TCP)
srv:listen(80, function(conn)
    conn:on("receive", function(client, request)
        conn:send("HTTP/1.1 200 OK\n\n")
        conn:send("<!DOCTYPE HTML><html>")
        conn:send("<head>")
        conn:send('<meta name="viewport" content="width=device-width, initial-scale=1">')
        conn:send('<link rel="stylesheet" href="https://use.fontawesome.com/releases/v5.12.0/css/all.css" integrity="sha384-REHJTs1r2ErKBuJB0fCK99gCYsVjwxHrSU0N7I1zl9vZbggVJXRMsv/sLlOAGb4M" crossorigin="anonymous">')
        conn:send("<style>")
        conn:send("html {")
        conn:send("font-family: Arial;")
        conn:send("display: inline-block;")
        conn:send("margin: 0px auto;")
        conn:send("text-align: center;")
        conn:send("}")
        conn:send("h2 { font-size: 3.0rem; }")
        conn:send("p, table td { font-size: 2.5rem; }")
        conn:send(".units { font-size: 1.2rem; }")
        conn:send(".labels{")
        conn:send("font-size: 1.5rem;")
        conn:send("vertical-align:middle;")
        conn:send("padding-bottom: 15px;")
        conn:send("}")
        conn:send("table td:not(:first-child) { text-align: left; }")
        conn:send(".center {")
        conn:send("margin-left: auto;")
        conn:send("margin-right: auto;")
        conn:send("}")
        conn:send("</style>")
        conn:send("</head>")
        conn:send("<body>")
        conn:send("<h2>ESP8266 BME280 Server</h2>")
        conn:send('<table class="center">')
        conn:send("<tr>")
        conn:send('<td><i class="fas fa-thermometer-half" style="color:#059e8a;"></i></td>')
        conn:send('<td><span class="labels">Temperature </span></td>')
        conn:send('<td><span id="temperature">' .. temperature .. '</span><sup class="units">&deg;C</sup></td>')
        conn:send("</tr>")
        conn:send("<tr>")
        conn:send('<td><i class="fas fa-tint" style="color:#00add6;"></i></td>')
        conn:send('<td><span class="labels">Humidity </span></td>')
        conn:send('<td><span id="humidity">' .. humidity .. '</span><sup class="units">%</sup></td>')
        conn:send("</tr>")
        conn:send("<tr>")
        conn:send('<td><i class="fas fa-tachometer-alt" style="color:#394182;"></i></td>')
        conn:send('<td><span class="labels">Atmospheric pressure </span></td>')
        conn:send('<td><span id="pressure">' .. pressure .. '</span><span class="units">hPa</span></td>')
        conn:send("</tr>")
        conn:send("<tr>")
        conn:send('<td><i class="fas fa-temperature-low" style="color:#7da2a8;"></i></td>')
        conn:send('<td><span class="labels">Dew Point </span></td>')
        conn:send('<td><span id="dewpoint">' .. dewpoint .. "</span></td>")
        conn:send("</tr>")
        conn:send("<tr>")
        conn:send('<td colspan="3"><i><span class="labels">' .. message .. "</span></i></td>")
        conn:send("</tr>")
        conn:send("</body></html>\n")

        conn:on("sent", function(conn)
            conn:close()
        end)

        collectgarbage()
    end)
end)

---------------------
-- data collection --
---------------------
function collect()
    local D = 0
    local T, P, H = bme280.read()
    if T and H and P then
        D = bme280.dewpoint(H, T)

        message = ""
        temperature = T / 100
        humidity = H / 1000
        pressure = P / 1000
        dewpoint = D / 100

        print(("temperature:%.2f, humidity:%.3f, pressure:%.3f, dewpoint:%.2f"):format(temperature, humidity, pressure, dewpoint))
        publish(('{"temperature":%.2f, "humidity":%.3f, "pressure":%.3f}'):format(temperature, humidity, pressure))
    else
        print("failed to collect data")
        message = "failed to collect data"
    end
end

tmr.create():alarm(300000, tmr.ALARM_AUTO, collect)

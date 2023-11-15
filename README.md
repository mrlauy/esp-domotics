# ESP Domotics
Domotics with an esp8266

## Table of Contents
1. [Connect](#connect-to-the-esp8266)
2. [Flash firmware](#flash-firmware)
3. [Communication](#communicate-to-the-esp)
4. [Test](#test-nodemcu)
5. [Upload scripts](#upload-scripts)

## Connect to the esp8266
find usb serial device with `lsusb`. Bus 004 Device 010: ID 067b:2303 Prolific Technology, Inc. PL2303 Serial Port
```
sudo modprobe usbserial vendor=0x067b product=0x2303
```

Connect esp to USB to serial
```
VCC -> 3.3v
GND -> GND
Rx -> Tx
Tx -> Rx
```
For flasing mode connect also
```
GPIO0 -> GND
CH_PD -> 3.3v
```

You should now see that it is now showing as attached by running `dmesg`.
```
[11357.143838] usbserial: USB Serial support registered for pl2303
[11357.143891] pl2303 4-1.2:1.0: pl2303 converter detected
[11357.146034] usb 4-1.2: pl2303 converter now attached to ttyUSB0
```

## Flash firmware
Recourse: https://nodemcu.readthedocs.io/en/release/getting-started/

Build the nodemcu firmware with site or with docker image
```
git clone --recurse-submodules https://github.com/nodemcu/nodemcu-firmware.git
```

Change the modules in `nodemcu-firmware/app/include/user_modules.h`
Enable `bme280, bme280_math, file, GPIO, I2C, mqtt, net, node, ow, tmr, uart, wifi`. Build the firmware
```
cd nodemcu-firmware
docker run --rm -ti -v `pwd`:/opt/nodemcu-firmware marcelstoer/nodemcu-build build
```

install flash tooling
```
sudo pip3 install esptool
```

flash firmware
```
sudo python3 -m esptool --trace --port /dev/ttyUSB0 --baud 115200 write_flash 0x00000 nodemcu-firmware/bin/nodemcu_float_release_20210105-1953.bin
```

### Problems
when problems with flashing, try connecting, this works when your esp device keeps listening to serial and isn't ready to receive new firmware.
```
GPIO 0 -> GND
RST -> 3.3v
```
try format, remove extra wires and monitor with gtkterm
```
sudo python3 -m esptool erase_flash
```

## Communicate to the ESP
using gtkterm for serial communication
```
sudo gtkterm --port /dev/ttyUSB0 --speed 115200
```

## Test NodeMCU
write hello world or something to test it.
```
file.format()
file.open("init.lua", "w")
file.writeline([[print("init lua node")]])
file.close()

node.restart()
```
## Upload scripts
install tool to upload files to the esp
```
npm install nodemcu-tool -g
```

upload the script to the esp
```
nodemcu-tool upload --port=/dev/ttyUSB0 init.lua
```

after uploading restart the esp. Connect with serial terminal and execute the command
```
node.restart()
```


scripts that use wifi import a credentials.lue. This contains the SSID and password
## Secrets in lua scripts
```
-- Network Credentials
ssid=<insert SSID>
pass=<insert password>
```

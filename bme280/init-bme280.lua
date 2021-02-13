-- Based on work by zeroday & sancho among many other open source authors
-- This code is public domain, attribution to gareth@l0l.org.uk appreciated.

id=0  -- need this to identify (software) IC2 bus?
sda=3 -- connect to pin GPIO0
scl=4 -- connect to pin GPIO2

-- initialize i2c with our id and pins in slow mode :-)
i2c.setup(id,sda,scl,i2c.SLOW)

-- user defined function: read from reg_addr content of dev_addr
function read_reg(dev_addr, reg_addr)
     i2c.start(id)
     i2c.address(id, dev_addr ,i2c.TRANSMITTER)
     i2c.write(id,reg_addr)
     i2c.stop(id)
     i2c.start(id)
     i2c.address(id, dev_addr,i2c.RECEIVER)
     c=i2c.read(id,1)
     i2c.stop(id)
     return c
end

print("Scanning I2C Bus")
for i=0,127 do
     if (string.byte(read_reg(i, 0))==0) then
     print("Device found at address "..string.format("%02X",i))
     end
end

bme280.setup()

tmr.create():alarm(2000, tmr.ALARM_AUTO, function()
  local D = 0
  local T, P, H = bme280.read()
  if not T and not H then
    D = bme280.dewpoint(H, T)
  end
  print(("temperature=%.2f, humidity=%.3f, pressure=%.3f, dewpoint=%.2f"):format(T / 100, H / 1000, P / 1000, D / 100))
end)

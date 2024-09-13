-- T4-watcher.lua -- This waits for new values placed in I32, then sends them as a strobed
-- word to EIO1:8 CIO1:3 as 2ms strobed word or CIO4 as 10ms TTL, runs on a LabJack T4
-- minifed version use: https://mothereff.in/lua-minifier
-- V1.02
LJ.setLuaThrottle(80)--print ("Current Lua Throttle Setting: ", LJ.getLuaThrottle())
local mbRead=MB.R
local mbWrite=MB.W
local cmd = -1
local lsb = 0
local msb = 0
mbWrite(2601,0,255) -- EIO_DIRECTION = output
mbWrite(2602,0,255) -- CIO_DIRECTION = output
mbWrite(2501,0,0) -- EIO_STATE all LOW
mbWrite(2502,0,0) -- CIO_STATE all LOW
mbWrite(46080, 2, 0) -- set USER_RAM0_I32 (address 46080) to 0
while true do
	cmd = mbRead(46080, 2)
	if (cmd >= 1 and cmd <= 2047) then
		lsb = bit.band(cmd,0xff)
		msb = bit.band(bit.rshift(cmd,8),0xff)
		mbWrite(2501,0,lsb) -- EIO_STATE set to lsb
		if (msb > 0) then mbWrite(2502,0,msb) end-- CIO1:3_STATE set to msb
		mbWrite(61590,1,2000) -- WAIT_US_BLOCKING 2000us = 2ms
		mbWrite(2501,0,0) -- EIO_STATE all LOW
		if (msb > 0) then mbWrite(2502,0,0) end
		--print("HIGH: ", cmd)
	elseif (cmd > 2047) then
		mbWrite(2502,0,8)
		mbWrite(61590,1,10000) -- WAIT_US_BLOCKING max is 100ms
		mbWrite(2502,0,0)
		--print("CIO4: ", 8)
	elseif (cmd == 0) then
		mbWrite(2501,0,0)
		--print("LOW: ", cmd)
	end
	if (cmd > -1) then
		mbWrite(46080, 2, -1) --reset cmd
		--print("RESET")
	end
end
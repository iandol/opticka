-- T4-watcher.lua -- This waits for new values placed in F32, then sends them as a strobed
-- word to EIO as 2ms strobed word or CIO as 300ms TTL, runs on a LabJack T4
-- minifed version use https://mothereff.in/lua-minifier here:
LJ.setLuaThrottle(100)--print ("Current Lua Throttle Setting: ", LJ.getLuaThrottle())
local mbRead=MB.R
local mbWrite=MB.W
local cmd = -1
mbWrite(2601,0,255) -- EIO_DIRECTION = output
mbWrite(2602,0,255) -- CIO_DIRECTION = output
mbWrite(2501,0,0) -- EIO_STATE all LOW
mbWrite(2502,0,0) -- CIO_STATE all LOW
mbWrite(46000, 3, 0) -- set USER_RAM0_F32 (address 46000) to 0
while true do
	cmd = mbRead(46000, 3)
	if (cmd >= 1 and cmd <= 255) then
		mbWrite(2501,0,cmd) -- EIO_STATE set to cmd
		mbWrite(61590,1,2000) -- WAIT_US_BLOCKING 2000us = 2ms
		mbWrite(2501,0,0) -- EIO_STATE all LOW
		--print("HIGH: ", cmd)
	elseif (cmd >= 256 and cmd <= 271) then
		mbWrite(2502,0,(cmd-256))
		mbWrite(61590,1,100000) -- WAIT_US_BLOCKING max is 100ms, so repeat 3 times for 300ms
		mbWrite(61590,1,100000)
		mbWrite(61590,1,100000)
		mbWrite(2502,0,0)
		--print("CIO: ", cmd)
	elseif (cmd == 0) then
		mbWrite(2501,0,0)
		--print("LOW: ", cmd)
	end
	if (cmd > -1) then
		mbWrite(46000, 3, -1) --reset cmd
		--print("RESET")
	end
end
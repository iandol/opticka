-- T4-watcher.lua -- This waits for new values placed in F32, then sends them as a strobed
-- word to EIO, runs on a LabJack T4
-- minifed version from https://mothereff.in/lua-minifier here:
-- LJ.setLuaThrottle(100)LJ.IntervalConfig(0,500)local a=LJ.CheckInterval;local b=MB.R;local c=MB.W;local d=-1;local e=-1;c(2601,0,255)c(46000,3,0)c(2500,0,0)while true do d=b(46000,3)if d~=e and d>=1 then c(2501,0,d)c(61590,1,math.random(1,10)*1000)c(2501,0,0)e=d elseif d~=e and d==0 then c(2501,0,0)e=d end;if a(0)then c(46000,3,0)end end
LJ.setLuaThrottle(100)
--print ("Current Lua Throttle Setting: ", LJ.getLuaThrottle())
LJ.IntervalConfig(0, 500)
local checkInterval=LJ.CheckInterval
local mbRead=MB.R
local mbWrite=MB.W
--local LJread = LJ.DIO_S_R
--local LJwrite = LJ.DIO_S_W
local cmd = -1
local oldcmd = -1
mbWrite(2601,0,255) -- EIO_DIRECTION = output
mbWrite(2602,0,255) -- CIO_DIRECTION = output
mbWrite(46000, 3, 0) -- set USER_RAM0_F32 (address 46000) to 0
mbWrite(2501,0,0) -- EIO_CIO_STATE all LOW
mbWrite(2502,0,0) -- EIO_CIO_STATE all LOW
while true do
	cmd = mbRead(46000, 3)
	if (cmd ~= oldcmd) and (cmd >= 1 and cmd <= 255) then
		mbWrite(2501,0,cmd)
		mbWrite(61590,1,2000)
		mbWrite(2501,0,0)
		--print("HIGH: ", oldcmd, cmd)
		oldcmd = cmd
	elseif (cmd ~= oldcmd) and (cmd >= 256 and cmd <= 271) then
		mbWrite(2502,0,(cmd-256))
		mbWrite(61590,1,100000)
		mbWrite(61590,1,100000)
		mbWrite(61590,1,100000)
		mbWrite(2502,0,0)
		--print("CIO set: ", oldcmd, cmd)
		oldcmd = cmd
	elseif (cmd ~= oldcmd) and (cmd == 0) then
		mbWrite(2501,0,0)
		--print("LOW: ", oldcmd, cmd)
		oldcmd = cmd
	end
	if checkInterval(0) then
		mbWrite(46000, 3, 0) --reset cmd
	end
end
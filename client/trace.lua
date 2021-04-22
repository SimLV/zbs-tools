-- send an event to trace table
local socket = require'socket'
local PORT = 1026
local HOST = 'localhost'

local function send_trace(obj, key, val)
	pcall(function()
		local udp = socket.udp()
		udp:setpeername(HOST, PORT)
    udp:send(obj.pfx..tostring(key or 'key') .. ':' .. tostring(val or 'msg') .. '|t')
		udp:close()
	end)
end
local m = {}
local ret = {
  pfx='',
  }

function m.set_port(new_port)
  if tostring(new_port) ~= tostring(math.floor(tonumber(new_port))) then
      error('port should be a valid integer')
  end
  if new_port < 1 or new_port > 65535 then
    error('port should be between 1 and 65535')
  end
  PORT = new_port
end

function m.set_host(new_host)
  HOST = new_host or 'localhost'
end

function m.set_pfx(pfx)
  ret.pfx = pfx or m.get_random_id()
end

function m.get_random_id()
  require'math'
  require'os'
  return tostring(math.fmod(os.time(), 1000))..'_'
end

local mret = {
  __call=send_trace,
  __index=m,
  }

return setmetatable(ret, mret)
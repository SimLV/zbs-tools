package.path = package.path..';../client/?.lua'

local trace = require'trace'
trace('a.b,a', 'msg') -- this should add msg to columns `a.b` and `a`

package.path = package.path..'..'

local trace = require'utils.trace'
trace('a.b,a', 'msg') -- this should add msg to columns `a.b` and `a`

## What is it?

It is a plugin for ZeroBraneStudio to use more structuring text logging.
This may be useful i.e. when two multiplayer clients are communicating.

## How to use it

Place a *test_table.lua* from `dist` folder into a `packages` folder

## Client

Simple lua client is located at `client/trace.lua`
It may be used like this:
```
local trace = require'trace'

trace('key1,key2', 'some log message')
```

### trace.set_pfx(new_prefix)

This function sets a prefix for first key so 
`trace('key', 'msg')` would be logged at column `<new_prefix>.key`
This may be useful in case of multiple clients

### trace.set_host(new_host)

This function changes host to send messages to

### trace.set_port(new_port)

This function changes port

## Protocol

All messages are separate UDP datagrams with following content:

`<key1>[,<key2>[,<keyN>]]<space><message>`

*key1* is a column name in a table pane in ZBS

*space* is just a space

*message* is arbitary text message

Whole string should be less than MTU

Default port is 1026

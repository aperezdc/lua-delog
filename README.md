delog
=====

`delog` is a fast, extensible, optionally zero-impact logging module for
[Lua](http://www.lua.org).

Quickstart
----------

```lua
-- Import and configure the module
local log = require("delog").level("trace")

local levels = { "trace", "debug", "info", "warn", "error", "fatal" }

for _, level in ipairs(levels) do
  log[level]("This is a message of '${}' level", level)
end
```

Features
--------

* Multiple logging levels: `trace`, `debug`, `info`, `warn`, `error`, and
  `fatal`.

* Lazy evaluation of log format arguments.

* Convenient log format string formatting, supporting
  [string.format](http://www.lua.org/manual/5.3/manual.html#pdf-string.format)
  modifiers (`"${%i}"`), built-in pretty-printers for tables (`"${%p}"`
  and `"${%pp}"`), and table field extraction (`"${fieldname}"`).

* Support for plugging-in additional user-provided formatters.

* `delog` filter for stripping logging calls from Lua sources. The filter
  takes Lua source code as input, removed the calls to functions in the
  `delog` module. Stripped sources can then be used to run applications
  for which logging introduces performance issues.

* Colored console output, with optional automatic detection of terminals
  (requires [lua-isatty](https://bitbucket.org/telemachus/lua-isatty),
  [lua-term](https://github.com/hoelzro/lua-term),
  [luaposix](https://github.com/luaposix/luaposix), or the
  [LuaJIT FFI](http://luajit.org/ext_ffi_api.html)).


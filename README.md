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


Usage
-----

### `delog.level(l)`

Sets the logging level to `l`, which should be one of:

1. `"trace"`
2. `"debug"`
3. `"info"`
4. `"warn"`
5. `"error"`
6. `"fatal"`

By default the logging level is `"warn"`. Enabling a certain level also
enables the rest of levels over it, e.g. enabling `"error"` also enables
`"fatal"`, and enabling `"trace"` enables _all_ logging levels.

### `delog.prepend(s)`

Sets the string which gets prepended to each log line. The default value
produces lines like the following, optionally coloered:

    [WARN   20:45:14] This is a log message.

This is achieved with the following “prepend” format string (which is
available as `delog.PREPEND_DEFAULT`):

    "${%color%}[${%level-upper%} ${%time-hhmmss%}] ${%nocolor%}"

Additionally, the module provides two more “prepend” format strings ready to
use, aimed for debugging:

- `delog.PREPEND_DEBUG`, same as the default, plus the source file name and
  line where the logging function was called.
- `delog.PREPEND_DEBUG_FUNC`, same as `PREPEND_DEBUG`, plus the name of the
  function where the logging function was called (if available).

**Tip:** If you are planning to use `delog` for debugging, probably you want
to load the module as follows:

```lua
local log = require("delog").level("debug")
log.prepend(log.PREPEND_DEBUG)  -- or PREPEND_DEBUG_FUNC
```

### `delog.append(s)`

Sets the string which gets appended to each log line. The default value is
a newline character (`"\n"`).


### `delog.color(flag)`

Manually sets whether to use ANSI color escape sequences. This is useful if
the module cannot detect by itself whether the output is being sent to
a terminal, then colors can still be obtained by using this function:

```lua
local log = require("delog").color(true)
log.warn("This will be always colored")
```

### `delog.output(file)`

Sets the logging output. If a string is passed, it is interpreted as a
file path, and the file will be opened in _append mode_. By default,
output is sent to `io.stderr`.


### `delog.format(name, func)`

Registers a custom formatting function (`func`), with a given format `name`.
This allows client code to supply additional format specifiers. Example:

```lua
local log = require("delog").format("upper", function (value)
  return tostring(value):upper()
end)
log.warn("${%upper}", "this will be output in upper case")
```

### `delog.trace(format, ...)`

Formats a message and writes and logs it in the `"trace"` level.

### `delog.debug(format, ...)`

Formats a message and writes and logs it in the `"debug"` level.

### `delog.info(format, ...)`

Formats a message and writes and logs it in the `"info"` level.

### `delog.warn(format, ...)`

Formats a message and writes and logs it in the `"warn"` level.

### `delog.error(format, ...)`

Formats a message and writes and logs it in the `"error"` level.

### `delog.fatal(format, ...)`

Formats a message and writes and logs it in the `"fatal"` level.

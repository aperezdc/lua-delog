#! /usr/bin/env lua
--
-- delog.lua
-- Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
-- Licensed under the MIT license or, at your option the Apache-2.0 license.
--

local isatty = (function ()
   local choices = {
      { module = "isatty", func = "isatty" },
      { module = "term", func = "isatty" },
      { module = "posix", func =
         function (P)
            local isatty, fileno = P.isatty, P.fileno
            return function (file)
               return isatty(fileno(file)) == 1
            end
         end },
      { module = "ffi", func =
         function (ffi)
            --
            -- With the FFI module (likely, running LuaJIT), allows us to hack
            -- our way to retrieve the FILE* from the file userdata, and use
            -- fileno() on that.
            --
            ffi.cdef [[ int fileno (void *fp); int isatty (int fd); ]]
            local ffi_cast, C = ffi.cast, ffi.C
            local voidp = ffi.typeof("void*")
            return function (file)
               return C.isatty(C.fileno(ffi_cast(voidp, file))) == 1
            end
         end },
   }
   for _, choice in pairs(choices) do
      local ok, mod = pcall(require, choice.module)
      if ok then
         if type(choice.func) == "string" then
            return mod[choice.func]
         else
            local ok, func = pcall(choice.func, mod)
            if ok then
               return func
            end
         end
      end
   end
   -- None found, do not ever use colors by default
   return function (file) return false end
end)()


local delog   = {}
local format  = {}
local level   = "warn"
local color   = false
local output  = false
local prepend = "${%color%}[${%level-upper%} ${%time-hhmmss%}]${%nocolor%} "
local append  = "\n"

delog.PREPEND_DEFAULT, delog.PREPEND_DEBUG = prepend, prepend .. "${%debug-location%}: "
delog.PREPEND_DEBUG_FUNC = prepend .. "${%debug-func-location%}(): "

local str_match, str_gsub, str_sub = string.match, string.gsub, string.sub
local str_upper, str_format = string.upper, string.format
local table_insert, table_concat = table.insert, table.concat
local _type, _pairs, _tostring, _tonumber = type, pairs, tostring, tonumber
local _pcall, _error = pcall, error
local io_open = io.open
local os_date = os.date


function delog.level(name)
   if not delog[name] then
      _error("#1: Invalid level name: " .. _tostring(name))
   end
   level = name
   return delog
end

function delog.prepend(format)
   prepend = format
   return delog
end

function delog.append(format)
   append = format
   return delog
end

function delog.color(enable)
   if output ~= false then
      if enable == nil then
         color = isatty(output)
      else
         color = enable
      end
   end
   return delog
end

function delog.output(file)
   if file == nil then
      file = io.stderr
   elseif _type(file) == "string" then
      file = io_open(file, "a")
   end

   if _type(file.write) ~= "function" then
      _error("#1: Argument does not have a :write() method")
   end

   output = file
   return delog.color()
end

function delog.format(name, func)
   if _type(name) ~= "string" then
      _error("#1: Argument is not a string")
   end
   if str_sub(name, -1) == "%" then
      _error("#1: Formatter names cannot end in '%'")
   end
   if _type(func) ~= "function" then
      _error("#2: Argument is not a function")
   end
   format[name] = func
   return delog
end

local colors = {}

--
-- Built-in formatters
--
format["level%"]       = function (l) return str_format("%-5s", l) end
format["level-upper%"] = function (l) return str_format("%-5s", str_upper(l)) end
format["nocolor%"]     = function (l) return color and "\27[0m" or "" end
format["color%"]       = function (l) return color and colors[l] or "" end
format["time-hhmmss%"] = function (l) return os_date("%H:%S:%M") end

--
-- Formatters which use the debug library
--
local dbg_getinfo = debug.getinfo
format["debug-location%"] = function (l)
   local info = dbg_getinfo(5, "Sl")
   return info.short_src .. ":" .. info.currentline
end
format["debug-func-location%"] = function (l)
   local info = dbg_getinfo(5, "Sln")
   return str_format("%s:%i:%s", info.short_src, info.currentline, info.name)
end

-- TODO: Handle cycles in tables.
local function do_pprint (value)
   if _type(value) == "table" then
      local items = {}
      for k, v in _pairs(value) do
         table_insert(items, str_format("%s=%s", k, do_pprint(v)))
      end
      return "{ " .. table_concat(items, ", ") .. " }"
   elseif _type(value) == "string" then
      return str_format("%q", value)
   else
      return _tostring(value)
   end
end
format.p = do_pprint


local function do_pprint_indent (value, indent)
   if _type(value) == "table" then
      local items = {}
      for k, v in _pairs(value) do
         table_insert(items, str_format("%s = %s", k, do_pprint_indent(v, indent .. "  ")))
      end
      return "{\n  " .. indent .. table_concat(items, ",\n  " .. indent) .. "\n" .. indent .. "}"
   elseif _type(value) == "string" then
      return str_format("%q", value)
   else
      return _tostring(value)
   end
end
format.pp = function (value) return do_pprint_indent(value, "") end


local spec_pattern = "^([^%%]*)%%?(.*)$"

local function interpolate (fmtstring, ...)
   local current_index = 1
   local args = { ... }

   return (str_gsub(fmtstring, "%$%{(.-)}", function (spec)
      local element, conversion = str_match(spec, spec_pattern)

      local value
      if #element == 0 then
         -- Pick from current_index without increment
         value = args[current_index]
      elseif element == "." then
         -- Current index with increment
         value = args[current_index]
         current_index = current_index + 1
      else
         local index = _tonumber(element)
         if index then
            -- Numeric index
            value = args[index]
         else
            -- Named index
            local table = args[current_index]
            if str_sub(element, 1, 1) == "." then
               value = table[str_sub(element, 2)]
               current_index = current_index + 1
            else
               value = table[element]
            end
         end
      end

      if #conversion == 0 then
         return _tostring(value)
      elseif format[conversion] then
         return format[conversion](value)
      else
         local ok, result = _pcall(str_format, "%" .. conversion, value)
         return ok and result or ("${" .. spec .. "}")
      end
   end))
end


local levels = {}
local function make_logger(code, name, color)
   levels[name], colors[name] = code, color
   --colors[name] = color
   delog[name] = function (fmtstring, arg1, ...)
      if code < levels[level] then
         return
      end
      if prepend then
         output:write(interpolate(prepend, name))
      end
      if _type(arg1) == "function" then
         -- Arguments are retrieved by invoking the function
         output:write(interpolate(fmtstring, arg1()))
      else
         output:write(interpolate(fmtstring, arg1, ...))
      end
      if append then
         output:write(interpolate(append, name))
      end
      output:flush()
   end
end

for i, m in ipairs {{ "trace", "\27[34m" };
                    { "debug", "\27[36m" };
                    { "info" , "\27[32m" };
                    { "warn" , "\27[33m" };
                    { "error", "\27[31m" };
                    { "fatal", "\27[35m" }} do
   make_logger(i, m[1], m[2])
end
return delog.output()

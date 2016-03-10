local log = require("delog").level("trace").output(io.stdout)
log.info("An informational message")
log.warn("A pretty-printed table: ${%ddp}", { answer=42 })

log.prepend(log.PREPEND_DEBUG)
log.debug("This shows the location")

log.prepend(log.PREPEND_DEBUG_FUNC)
function this_is_a_function()
   log.info("Printing the function name")
end
this_is_a_function()

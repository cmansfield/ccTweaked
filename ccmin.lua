
return {
    pos = function (...) return term.setCursorPos(...) end,
    cls = function (...) return term.clear() end,
    tCo = function (...) return term.setTextColor(...) end,
    bCo = function (...) return term.setBackgroundColor(...) end,
    box = function (...) return paintutils.drawFilledBox(...) end,
    ln =  function (...) return paintutils.drawLine(...) end,
}
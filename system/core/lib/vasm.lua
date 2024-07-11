--[[
The MIT License (MIT)

Copyright 2024 DanXvoIsMe

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--




local Assembler = {}

local Values = {}

local invoke = component.invoke

local Sectors = {
    ["ax"] = "",
    ["ex"] = "",
    ["as"] = 0,
    ["es"] = 0
}

local RedirectorList = {
    {
        name = "createvalue",
        func = function(valName, valValue)
            Values[valName] = valValue
        end,
        numArgs = 2 
    },
    {
        name = "move",
        func = function(oldvalName, newvalName)
            if Values[oldvalName] == nil then
                error("Attempt to move non-existent value: " .. oldvalName)
            else
                Values[newvalName] = Values[oldvalName]
            end
        end,
        numArgs = 2
    },
    {
        name = "movetosector",
        func = function(sectorName, val)
            if sectorName == "ax" then
                Sectors["ax"] = Values[val]
            end
            if sectorName == "ex" then
                Sectors["ex"] = Values[val]
            end
            if sectorName == "as" then
                Sectors["as"] = Values[val]
            end
            if sectorName == "es" then
                Sectors["es"] = Values[val]
            end
        end,
        numArgs = 2
    },
    {
        name = "getfromsector",
        func = function(sectorname, valuename)
            Values[valuename] = Sectors[sectorname]
        end,
        numArgs = 2
    },
    {
        name = "add",
        func = function(valuename, addtovalue, outvaluename)
            Values[outvaluename] = Values[valuename] + addtovalue
        end,
        numArgs = 3
    },
    {
        name = "minus",
        func = function(valuename, minusfromvalue, outvaluename)
            Values[outvaluename] = Values[valuename] + minusfromvalue
        end,
        numArgs = 3
    },
    {
        name = "runsectors",
        func = function()
            for sector, value in pairs(Sectors) do
                if sector == "ax" then
                    print(value)
                end
            end
        end,
        numArgs = 0
    },
    {
        name = "initcomponent",
        func = function(compoentnname)
            Values[compoentnname] = component.list(component.proxy(compoentnname)())
        end,
        numArgs = 1
    },
    {
        name = "componentfunction1arg",
        func = function(componentval, arg1)
            local component = Values[componentval]
            invoke(component, arg1)
        end,
        numArgs = 1
    },
    {
        name = "componentfunction2arg",
        func = function(componentval, arg1, arg2)
            local component = Values[componentval]
            invoke(component, arg1, arg2)
        end,
        numArgs = 2
    },
    {
        name = "componentfunction1arg",
        func = function(componentval, arg1, arg2, arg3)
            local component = Values[componentval]
            invoke(component, arg1, arg2, arg3)
        end,
        numArgs = 3
    },
    {
        name = "deintcomponent",
        func = function(compoentnname)
            Values[compoentnname] = nil
        end,
        numArgs = 1
    },
}

Assembler.funcs = {}

for _, entry in ipairs(RedirectorList) do
    Assembler.funcs[entry.name] = entry.func
end

local function getNumArgs(funcName)
    for _, entry in ipairs(RedirectorList) do
        if entry.name == funcName then
            return entry.numArgs or 0
        end
    end
    return nil
end

local function parseArgs(args)
    local argList = {}
    local inQuote = false
    local currentArg = ""
    
    for i = 1, #args do
        local char = args:sub(i, i)
        if char == '"' then
            inQuote = not inQuote
        elseif char == " " and not inQuote then
            if #currentArg > 0 then
                table.insert(argList, currentArg)
                currentArg = ""
            end
        else
            currentArg = currentArg .. char
        end
    end
    
    if #currentArg > 0 then
        table.insert(argList, currentArg)
    end
    
    return argList
end

function Assembler.RunCodeWithoutSandbox(code)
    for line in code:gmatch("[^\r\n]+") do
        local funcName, args = line:match("(%w+)%s*(.*)")
        if funcName then
            local func = Assembler.funcs[funcName]
            if func then
                local argList = parseArgs(args)
                local numArgsProvided = #argList
                local expectedArgs = getNumArgs(funcName)

                local success, err
                if expectedArgs == -1 or numArgsProvided == expectedArgs then
                    success, err = pcall(func, table.unpack(argList))
                else
                    error("Incorrect number of arguments for function '" .. funcName .. "'. Provided: " .. numArgsProvided .. ", Expected: " .. expectedArgs)
                end

                if not success then
                    error("Error executing function '" .. funcName .. "': " .. err)
                end
            else
                error("Function not found: " .. funcName)
            end
        else
            error("Invalid code format in line: " .. line)
        end
    end
end

return Assembler

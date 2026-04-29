local module = {}

local watcher = nil

local function audioDeviceChanged(event)
    -- Switch to built-in mic if input device or any device changes
    if event == "dev#" or event == "dIn " then
        -- Find built-in mic avoiding external dependencies like SwitchAudioSource
        for _, dev in ipairs(hs.audiodevice.allInputDevices()) do
            local name = dev:name()
            if name:match("MacBook") or name:match("Built%-in") then
                dev:setDefaultInputDevice()
                break
            end
        end
    end
end

local isRunning = false

function module.start()
    if not isRunning then
        hs.audiodevice.watcher.setCallback(audioDeviceChanged)
        hs.audiodevice.watcher.start()
        isRunning = true
    end
end

function module.stop()
    if isRunning then
        hs.audiodevice.watcher.stop()
        isRunning = false
    end
end

return module

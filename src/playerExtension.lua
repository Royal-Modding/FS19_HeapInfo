--
-- ${title}
--
-- @author ${author}
-- @version ${version}
-- @date 11/12/2020

PlayerExtension = {}

function PlayerExtension:new(superFunc, isServer, isClient)
    self = superFunc(nil, isServer, isClient)
    self.inputInformation.registrationList[InputAction.HEAP_INFO_SHOW] = {
        eventId = "",
        callback = self.showHeapInfoActionEvent,
        triggerUp = false,
        triggerDown = true,
        triggerAlways = false,
        activeType = Player.INPUT_ACTIVE_TYPE.STARTS_DISABLED,
        callbackState = nil,
        text = g_i18n:getText("hi_SHOW"),
        textVisibility = true
    }
    return self
end

function PlayerExtension:updateActionEvents()
    local eventId = self.inputInformation.registrationList[InputAction.HEAP_INFO_SHOW].eventId
    g_inputBinding:setActionEventActive(eventId, HeapInfo.foundHeap ~= nil)
    g_inputBinding:setActionEventTextVisibility(eventId, HeapInfo.foundHeap ~= nil)
end

function PlayerExtension:showHeapInfoActionEvent()
    HeapInfo:showInfo()
end

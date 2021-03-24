---${title}

---@author ${author}
---@version r_version_r
---@date 07/12/2020

InitRoyalMod(Utils.getFilename("rmod/", g_currentModDirectory))
InitRoyalUtility(Utils.getFilename("utility/", g_currentModDirectory))
InitRoyalHud(Utils.getFilename("hud/", g_currentModDirectory))

---@class HeapInfo : RoyalMod
HeapInfo = RoyalMod.new(r_debug_r, false)
HeapInfo.raycastTimer = 0
HeapInfo.raycastTimeout = 250
HeapInfo.scanStartTime = 0
HeapInfo.scannedPoints = 0
HeapInfo.maxScanablePoints = 10000 * getViewDistanceCoeff()
HeapInfo.isScannedBuffer = {}
HeapInfo.foundHeap = nil
HeapInfo.debugPoints = {}

function HeapInfo:initialize()
    Utility.overwrittenFunction(Player, "new", PlayerExtension.new)
    Utility.appendedFunction(Player, "updateActionEvents", PlayerExtension.updateActionEvents)
    if Player.showHeapInfoActionEvent == nil then
        Player.showHeapInfoActionEvent = PlayerExtension.showHeapInfoActionEvent
    end
end

function HeapInfo:onLoad()
    self.hud = InfoHud:new()
end

function HeapInfo:onLoadSavegame(_, _)
    self.terrainSize = g_currentMission.terrainSize
    self.terrainDetailHeightSize = getDensityMapSize(g_currentMission.terrainDetailHeightId)
    self.scanSize = (self.terrainSize / self.terrainDetailHeightSize) * 2
    self.scanAreaSize = self.scanSize / 2
    self.scanAreaOffset = self.scanAreaSize / 2
    self.scanAreaCenterOffset = self.scanAreaOffset + (self.scanAreaSize / 2)
end

function HeapInfo:onStartMission()
    self.hud:loadFillIcons()
end

function HeapInfo:onUpdate(dt)
    if g_dedicatedServerInfo == nil and g_currentMission.player.isEntered then
        self.hud:update(dt)
        self.raycastTimer = self.raycastTimer + dt
        if self.raycastTimer >= self.raycastTimeout then
            self.raycastTimer = 0
            self.foundHeap = nil
            local x, y, z = localToWorld(g_currentMission.player.cameraNode, 0, 0, 1.0)
            local dx, dy, dz = localDirectionToWorld(g_currentMission.player.cameraNode, 0, 0, -1)
            raycastAll(x, y, z, dx, dy, dz, "raycastCallback", 5, self)
        end

        if self.debug then
            if self.foundHeap ~= nil then
                Utility.drawDebugCube({self.foundHeap.x, self.foundHeap.y, self.foundHeap.z}, self.scanAreaOffset, 1, 1, 0)
            end
            local tn = g_currentMission.terrainRootNode
            for _, c in ipairs(self.debugPoints) do
                local cw = c.w / 2
                Utility.drawDebugCube({c.x + cw, getTerrainHeightAtWorldPos(tn, c.x + cw, 0, c.z + cw) + c.y, c.z + cw}, c.w, c.r, c.g, c.b)
            end
        end
    end
end

function HeapInfo:onDraw()
    if g_dedicatedServerInfo == nil and g_currentMission.player.isEntered then
        self.hud:draw()
    end
end

function HeapInfo:raycastCallback(hitObjectId, x, y, z, _, _, _, _, _, _)
    if hitObjectId ~= g_currentMission.player.rootNode then
        if hitObjectId == g_currentMission.terrainRootNode then
            local terrainY = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, y, z)
            if string.format("%.3f", y) ~= string.format("%.3f", terrainY) then
                self.foundHeap = {
                    x = x,
                    y = y,
                    z = z
                }
                return false
            end
        end
    end
    return true -- continue raycast
end

function HeapInfo:showInfo()
    if self.foundHeap ~= nil then
        self.scanStartTime = getTimeSec()
        self.scannedPoints = 0
        local info = self:getInfo(self.foundHeap.x, self.foundHeap.z)
        if info.fillType ~= FillType.UNKNOWN then
            g_logManager:devInfo("[%s] Scanned %d points and found %.1f of %s in %.2fms", self.name, self.scannedPoints, info.amount, g_fillTypeManager:getFillTypeNameByIndex(info.fillType), (getTimeSec() - self.scanStartTime) * 1000)
            if self.scannedPoints >= self.maxScanablePoints then
                g_currentMission:showBlinkingWarning(g_i18n:getText("hi_HEAP_TOO_BIG"), 3000)
            end
            self.hud:show(info.fillType, info.amount)
        end
    end
end

function HeapInfo:getInfo(x, z)
    local startX = math.floor(x)
    local startZ = math.floor(z)

    local total = 0

    local fillType =
        DensityMapHeightUtil.getFillTypeAtArea(
        startX + self.scanAreaOffset,
        startZ + self.scanAreaOffset,
        startX + self.scanAreaOffset,
        startZ + self.scanAreaOffset + self.scanAreaSize,
        startX + self.scanAreaOffset + self.scanAreaSize,
        startZ + self.scanAreaOffset
    )

    if fillType ~= FillType.UNKNOWN then
        self:resetIsScanned()
        if self.debug then
            self.debugPoints = {}
            table.insert(self.debugPoints, {x = startX + self.scanAreaCenterOffset, y = 1, z = startZ + self.scanAreaCenterOffset, w = self.scanAreaSize, r = 0, g = 1, b = 1})
        end
        total = self:scanRecursively({{startX, startZ}}, fillType)
    end

    return {amount = total, fillType = fillType}
end

function HeapInfo:scanRecursively(points, fillType)
    local total = 0
    for _, point in pairs(points) do
        local aroundAmount, validAroundPoints = self:scanAround(point[1], point[2], fillType)
        total = total + aroundAmount
        total = total + self:scanRecursively(validAroundPoints, fillType)
    end
    return total
end

function HeapInfo:scanAround(x, z, fillType)
    local points = {
        {x + self.scanSize, z},
        {x + self.scanSize, z + self.scanSize},
        {x + self.scanSize, z - self.scanSize},
        {x - self.scanSize, z},
        {x - self.scanSize, z + self.scanSize},
        {x - self.scanSize, z - self.scanSize},
        {x, z + self.scanSize},
        {x, z - self.scanSize}
    }
    local aroundAmount = 0
    local validAroundPoints = {}

    for _, point in pairs(points) do
        local pointAmount = self:scanAt(point[1], point[2], fillType)
        aroundAmount = aroundAmount + pointAmount
        if pointAmount > 0 then
            table.insert(validAroundPoints, point)
        end
    end
    return aroundAmount, validAroundPoints
end

function HeapInfo:scanAt(x, z, fillType)
    if not self:getIsScanned(x, z) and self.scannedPoints < self.maxScanablePoints then
        self.scannedPoints = self.scannedPoints + 1
        self:setIsScanned(x, z)
        local amount, _, _ =
            DensityMapHeightUtil.getFillLevelAtArea(
            fillType,
            x + self.scanAreaOffset,
            z + self.scanAreaOffset,
            x + self.scanAreaOffset,
            z + self.scanAreaOffset + self.scanAreaSize,
            x + self.scanAreaOffset + self.scanAreaSize,
            z + self.scanAreaOffset
        )
        if self.debug then
            -- max 250 debug points to prevent heavy lags
            if #self.debugPoints <= 250 then
                if amount > 0 then
                    table.insert(self.debugPoints, {x = x + self.scanAreaCenterOffset, y = 2, z = z + self.scanAreaCenterOffset, w = self.scanAreaSize / 4, r = 0, g = 1, b = 0})
                else
                    table.insert(self.debugPoints, {x = x + self.scanAreaCenterOffset, y = 2, z = z + self.scanAreaCenterOffset, w = self.scanAreaSize / 4, r = 1, g = 0, b = 0})
                end
            end
        end
        return amount
    end
    return 0
end

function HeapInfo:resetIsScanned()
    self.isScannedBuffer = {}
end

function HeapInfo:setIsScanned(x, z)
    if not self.isScannedBuffer[x] then
        self.isScannedBuffer[x] = {}
    end
    self.isScannedBuffer[x][z] = true
end

function HeapInfo:getIsScanned(x, z)
    return self.isScannedBuffer[x] and self.isScannedBuffer[x][z]
end

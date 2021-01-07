--
-- ${title}
--
-- @author ${author}
-- @version ${version}
-- @date 07/12/2020

InitRoyalMod(Utils.getFilename("rmod/", g_currentModDirectory))
InitRoyalUtility(Utils.getFilename("utility/", g_currentModDirectory))
InitRoyalHud(Utils.getFilename("hud/", g_currentModDirectory))

HeapInfo = RoyalMod.new(r_debug_r)
HeapInfo.scanTimer = 0
HeapInfo.scanTimeout = 500
HeapInfo.foundHeap = nil
HeapInfo.debugCubes = {}

function HeapInfo:initialize(baseDirectory, missionCollaborators)
    addConsoleCommand("hiGetInfo", "Get heap informations.", "consoleCommandGetInfo", self)
    Utility.overwrittenFunction(Player, "new", PlayerExtension.new)
    Utility.appendedFunction(Player, "updateActionEvents", PlayerExtension.updateActionEvents)
    if Player.showHeapInfoActionEvent == nil then
        Player.showHeapInfoActionEvent = PlayerExtension.showHeapInfoActionEvent
    end
end

function HeapInfo:onSetMissionInfo(missionInfo, missionDynamicInfo)
end

function HeapInfo:onLoad()
end

function HeapInfo:onPreLoadMap(mapFile)
end

function HeapInfo:onLoadMap(mapNode, mapFile)
end

function HeapInfo:onCreateStartPoint(startPointNode)
end

function HeapInfo:onPostLoadMap(mapNode, mapFile)
end

function HeapInfo:onLoadSavegame(savegameDirectory, savegameIndex)
end

function HeapInfo:onPreLoadVehicles(xmlFile, resetVehicles)
end

function HeapInfo:onPreLoadItems(xmlFile)
end

function HeapInfo:onPreLoadOnCreateLoadedObjects(xmlFile)
end

function HeapInfo:onLoadFinished()
    self.terrainSize = g_currentMission.terrainSize
    self.terrainDetailHeightSize = getDensityMapSize(g_currentMission.terrainDetailHeightId)
    self.scanSize = (self.terrainSize / self.terrainDetailHeightSize) * 2
    self.scanAreaSize = self.scanSize / 2
    self.scanAreaOffset = self.scanAreaSize / 2
    self.scanAreaCenterOffset = self.scanAreaOffset + (self.scanAreaSize / 2)
end

function HeapInfo:onStartMission()
end

function HeapInfo:onMissionStarted()
end

function HeapInfo:onWriteStream(streamId)
end

function HeapInfo:onReadStream(streamId)
end

function HeapInfo:onUpdate(dt)
    if g_dedicatedServerInfo == nil and g_currentMission.player.isEntered then
        self.scanTimer = self.scanTimer + dt
        if self.scanTimer >= self.scanTimeout then
            self.scanTimer = 0
            self.foundHeap = nil
            local x, y, z = localToWorld(g_currentMission.player.cameraNode, 0, 0, 1.0)
            local dx, dy, dz = localDirectionToWorld(g_currentMission.player.cameraNode, 0, 0, -1)
            raycastAll(x, y, z, dx, dy, dz, "raycastCallback", 5, self)
        end

        if self.debug then
            if self.foundHeap ~= nil then
                Utility.drawDebugCube({self.foundHeap.x, self.foundHeap.y, self.foundHeap.z}, self.scanAreaOffset, 1, 1, 0)
            end
            for _, c in pairs(self.debugCubes) do
                local cw = c.w / 2
                Utility.drawDebugCube({c.x + cw, c.y, c.z + cw}, c.w, c.r, c.g, c.b)
            end
        end
    end
end

function HeapInfo:onUpdateTick(dt)
end

function HeapInfo:onWriteUpdateStream(streamId, connection, dirtyMask)
end

function HeapInfo:onReadUpdateStream(streamId, timestamp, connection)
end

function HeapInfo:onMouseEvent(posX, posY, isDown, isUp, button)
end

function HeapInfo:onKeyEvent(unicode, sym, modifier, isDown)
end

function HeapInfo:onDraw()
end

function HeapInfo:onPreSaveSavegame(savegameDirectory, savegameIndex)
end

function HeapInfo:onPostSaveSavegame(savegameDirectory, savegameIndex)
end

function HeapInfo:onPreDeleteMap()
end

function HeapInfo:consoleCommandGetInfo()
end

function HeapInfo:onDeleteMap()
    removeConsoleCommand("hiGetInfo")
end

function HeapInfo:raycastCallback(hitObjectId, x, y, z, _, _, _, _, _, _)
    if hitObjectId ~= self.rootNode then
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
        local info = self:getInfo(self.foundHeap.x, self.foundHeap.z)
        print(string.format("%s: %.0fl", g_fillTypeManager:getFillTypeNameByIndex(info.fillType), info.amount))
    end
end

function HeapInfo:getInfo(x, z)
    self.debugCubes = {}
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
            table.insert(self.debugCubes, {x = startX + self.scanAreaCenterOffset, y = self.foundHeap.y + 1, z = startZ + self.scanAreaCenterOffset, w = self.scanAreaSize, r = 0, g = 1, b = 1})
        end
        total = self:scanRecursively({{startX, startZ}}, fillType)
    end

    return {amount = total, fillType = fillType}
end

function HeapInfo:scanRecursively(points, fillType)
    local total = 0
    for _, point in pairs(points) do
        local tAmount, newPoints = self:scanAround(point[1], point[2], fillType)
        total = total + tAmount
        total = total + self:scanRecursively(newPoints, fillType)
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
    local total = 0
    local pointsToReturn = {}

    for _, point in pairs(points) do
        local tAmount = self:scanAt(point[1], point[2], fillType)
        total = total + tAmount
        if tAmount > 0 then
            table.insert(pointsToReturn, point)
        end
    end
    return total, pointsToReturn
end

function HeapInfo:scanAt(x, z, fillType)
    if not self:getIsScanned(x, z) then
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
            if amount > 0 then
                table.insert(self.debugCubes, {x = x + self.scanAreaCenterOffset, y = self.foundHeap.y + 2, z = z + self.scanAreaCenterOffset, w = self.scanAreaSize / 4, r = 0, g = 1, b = 0})
            else
                table.insert(self.debugCubes, {x = x + self.scanAreaCenterOffset, y = self.foundHeap.y + 2, z = z + self.scanAreaCenterOffset, w = self.scanAreaSize / 4, r = 1, g = 0, b = 0})
            end
        end
        return amount
    end
    return 0
end

function HeapInfo:resetIsScanned()
    self.isScanned = {}
end

function HeapInfo:setIsScanned(x, z)
    if not self.isScanned[x] then
        self.isScanned[x] = {}
    end
    self.isScanned[x][z] = true
end

function HeapInfo:getIsScanned(x, z)
    return self.isScanned[x] and self.isScanned[x][z]
end

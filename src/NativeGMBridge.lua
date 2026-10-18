local NativeGMBridge = {}

-- Never use the game folder for IPC. Other installations commonly live under
-- Program Files, where the normally launched game cannot write files even
-- though the elevated installer and GM window can. TEMP is writable by both
-- processes for the signed-in user and is independent of the game working dir.
local TEMP_ROOT = (os.getenv("TEMP") or os.getenv("TMP") or "."):gsub("\\", "/")
local IPC_ROOT = TEMP_ROOT .. "/PearlBubbleNativeGM"
local COMMAND_PATH = IPC_ROOT .. "/PearlBubbleNativeGM.cmd"
local STATUS_PATH = IPC_ROOT .. "/PearlBubbleNativeGM.status"
local EVENT_LOG_PATH = IPC_ROOT .. "/PearlBubbleNativeGM.events.log"
local TIMELINE_LOG_PATH = IPC_ROOT .. "/PearlBubbleNativeGM.timeline.log"

NativeGMBridge.lastNonce = ""
NativeGMBridge.nextRewardType = nil
NativeGMBridge.persistentRewardType = nil
NativeGMBridge.scheduleId = nil
NativeGMBridge.originalShootDraBallByRes = nil
NativeGMBridge.originalOnSyncConeyAck = nil
NativeGMBridge.originalOnUserConeyChanged = nil
NativeGMBridge.originalOnChangeMoneyNotify = nil
NativeGMBridge.originalOnEventChangeNotify = nil
NativeGMBridge.originalOnGetSuperRewardRes = nil
NativeGMBridge.originalAddBonusDraBall = nil
NativeGMBridge.originalOnEventBallDropDwon = nil
NativeGMBridge.originalOnDraBallTrigger = nil
NativeGMBridge.originalGameCtrlAddProperty = nil
NativeGMBridge.originalOnDwonTrigger = nil
NativeGMBridge.originalOnPartyTrigger = nil
NativeGMBridge.originalOnSyncGameStateAckV2 = nil
NativeGMBridge.visualPearlTags = {}
NativeGMBridge.visualWhiteAutoEnabled = false
NativeGMBridge.visualWhiteAutoTicks = 0
NativeGMBridge.visualWhiteAutoMaxPearls = 60
NativeGMBridge.pendingOfficialPearlSyncIndex = nil
NativeGMBridge.officialBlueLocked = false
NativeGMBridge.officialBlueOutstanding = 0
NativeGMBridge.officialBlueFinalSyncIndex = nil
NativeGMBridge.officialWhiteTags = {}
NativeGMBridge.officialWhiteLocked = false
NativeGMBridge.officialWhiteTag = "none"
NativeGMBridge.officialWhiteFireSyncIndex = nil
NativeGMBridge.officialWhiteDropSyncIndex = nil
NativeGMBridge.officialWhiteState = "idle"
NativeGMBridge.officialWhiteBet = 0
NativeGMBridge.officialWhiteExpectedReward = 0
NativeGMBridge.officialWhiteExpectedNet = 0
NativeGMBridge.officialWhiteAccountBefore = "unknown"
NativeGMBridge.officialWhiteServerDelta = "unknown"
NativeGMBridge.statusPollCount = 0
NativeGMBridge.lastState = "unknown"
NativeGMBridge.lastDetail = ""
NativeGMBridge.lastAccountBalance = "unknown"
NativeGMBridge.lastServerFinal = "unknown"
NativeGMBridge.lastServerAdd = "unknown"
NativeGMBridge.lastServerSub = "unknown"
NativeGMBridge.lastServerRewardCount = 0
NativeGMBridge.lastServerRewardTypes = "none"
NativeGMBridge.lastServerPathReward = "unknown"
NativeGMBridge.lastVisualPathReward = "none"
NativeGMBridge.serverRewardSerial = 0
NativeGMBridge.lastServerCode = "none"
NativeGMBridge.serverCodeAccountBefore = "unknown"
NativeGMBridge.serverCodeRewardSerialBefore = 0
NativeGMBridge.serverCodeSentAt = "unknown"
NativeGMBridge.rewardCreditSerial = 0
NativeGMBridge.originalModelSendLuaCommand = nil
NativeGMBridge.originalModelOnCommand = nil
NativeGMBridge.timelineSequence = 0
NativeGMBridge.timelineStartClock = 0
NativeGMBridge.smallPearlDropCount = 0
NativeGMBridge.smallPearlClientCredit = 0
NativeGMBridge.smallPearlAccountBase = "unknown"
NativeGMBridge.smallPearlLastValue = 0
NativeGMBridge.lastGameStateVerify = "none"
NativeGMBridge.lastGameStateAckIndex = "unknown"
NativeGMBridge.gameStateRejectCount = 0

-- Only protocol fields already decoded by the shipped client are observed.
-- This avoids guessing at a raw buffer format that is not exposed here.
local timelineProtocolFields = {
    SEND = {
        [15] = { "index", "canEnterDraHoleCount", "list", "draballList" },
        [51] = { "code" },
    },
    RECV = {
        [2] = { "plateIndex", "maxBet", "roomBaseData" },
        [5] = { "finalNum", "addNum", "subNum" },
        [9] = { "currentSoulNum", "fallIndex", "bgDataList" },
        [15] = { "verifyOk", "index", "bgDataList", "jpBall", "jpInfo" },
        [31] = { "changeAmount", "currentMoney" },
        [52] = { "buffer", "soulBuffer" },
    },
}

local timelineVectorFields = {
    list = { "eventType", "subType", "ballIndex", "extraInfo" },
    draballList = { "ballType", "x", "y", "z" },
    bgDataList = { "ballType", "holeType", "currentSoulNum", "broadcastIndex" },
}

-- requireWithClearLoaded() does not reliably forward a module return value in
-- this client, so publish the bridge before Start() is requested by main.lua.
if dinoBall ~= nil then
    dinoBall.NativeGMBridge = NativeGMBridge
end

local function timelineEscape(value)
    local text = tostring(value)
    text = string.gsub(text, "\\", "\\\\")
    text = string.gsub(text, "|", "\\p")
    text = string.gsub(text, "\r", "\\r")
    text = string.gsub(text, "\n", "\\n")
    return text
end

local function timelineReadField(value, field)
    if value == nil then
        return nil
    end
    local ok, result = pcall(function()
        return value[field]
    end)
    if ok then
        return result
    end
    return nil
end

local function timelineSerializeSimple(value, depth)
    if value == nil then
        return "nil"
    end
    local valueType = type(value)
    if valueType == "number" or valueType == "boolean" or valueType == "string" then
        return timelineEscape(value)
    end
    if valueType ~= "table" or depth >= 2 then
        return timelineEscape(value)
    end

    local parts = {}
    local count = 0
    for key, child in pairs(value) do
        count = count + 1
        if count > 32 then
            table.insert(parts, "...")
            break
        end
        table.insert(parts, timelineEscape(key) .. ":" .. timelineSerializeSimple(child, depth + 1))
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

local function timelineSerializeObject(value, fields)
    if value == nil then
        return "nil"
    end
    local parts = {}
    for _, field in ipairs(fields) do
        local child = timelineReadField(value, field)
        if child ~= nil then
            table.insert(parts, field .. "=" .. timelineSerializeSimple(child, 0))
        end
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function timelineSerializeVector(value, itemFields)
    if value == nil then
        return "nil"
    end
    if type(value) ~= "table" then
        return timelineEscape(value)
    end
    local parts = {}
    local count = 0
    for index, item in pairs(value) do
        count = count + 1
        if count > 64 then
            table.insert(parts, "...")
            break
        end
        table.insert(parts, tostring(index) .. ":" .. timelineSerializeObject(item, itemFields))
    end
    table.sort(parts)
    return "[" .. table.concat(parts, ",") .. "]"
end

local function timelineSerializeContent(direction, opcode, content)
    local directionFields = timelineProtocolFields[direction]
    local fields = directionFields and directionFields[opcode] or nil
    if fields == nil then
        return content == nil and "nil" or "present"
    end
    local parts = {}
    for _, field in ipairs(fields) do
        local value = timelineReadField(content, field)
        if value ~= nil then
            local vectorFields = timelineVectorFields[field]
            local encoded = vectorFields ~= nil
                and timelineSerializeVector(value, vectorFields)
                or timelineSerializeSimple(value, 0)
            table.insert(parts, field .. "=" .. encoded)
        end
    end
    return table.concat(parts, ",")
end

local function timelineOpcodeName(direction, opcode)
    local protocol = dinoBall and dinoBall.Protocol or nil
    local commands = protocol and (direction == "SEND"
        and protocol.DINOBALL_U2G_PROTOCOL or protocol.DINOBALL_G2U_PROTOCOL) or nil
    if commands ~= nil then
        for name, value in pairs(commands) do
            if value == opcode then
                return name
            end
        end
    end
    return "UNKNOWN"
end

local function appendTimeline(direction, opcode, content)
    NativeGMBridge.timelineSequence = NativeGMBridge.timelineSequence + 1
    local elapsedMs = math.floor((os.clock() - NativeGMBridge.timelineStartClock) * 1000 + 0.5)
    local file = io.open(TIMELINE_LOG_PATH, "a")
    if file == nil then
        return
    end
    file:write(tostring(NativeGMBridge.timelineSequence)
        .. "|" .. tostring(os.time())
        .. "|" .. tostring(elapsedMs)
        .. "|" .. tostring(direction)
        .. "|" .. tostring(opcode)
        .. "|" .. timelineEscape(timelineOpcodeName(direction, opcode))
        .. "|" .. timelineSerializeContent(direction, opcode, content)
        .. "\n")
    file:close()
end

local function startTimeline()
    NativeGMBridge.timelineSequence = 0
    NativeGMBridge.timelineStartClock = os.clock()
    local file = io.open(TIMELINE_LOG_PATH, "w")
    if file ~= nil then
        file:write("seq|unix_s|elapsed_ms|direction|opcode|name|data\n")
        file:close()
    end
end

local function installPassiveTimeline()
    if PearlBubbleModel == nil then
        return false
    end
    if NativeGMBridge.originalModelSendLuaCommand == nil
        and PearlBubbleModel.SendLuaCommand ~= nil then
        NativeGMBridge.originalModelSendLuaCommand = PearlBubbleModel.SendLuaCommand
        PearlBubbleModel.SendLuaCommand = function(self, cmd, content)
            pcall(function()
                appendTimeline("SEND", cmd, content)
            end)
            return NativeGMBridge.originalModelSendLuaCommand(self, cmd, content)
        end
    end
    if NativeGMBridge.originalModelOnCommand == nil
        and PearlBubbleModel.OnCommand ~= nil then
        NativeGMBridge.originalModelOnCommand = PearlBubbleModel.OnCommand
        PearlBubbleModel.OnCommand = function(self, luaCommand)
            local commandType = luaCommand and luaCommand.commandType or nil
            local content = luaCommand and luaCommand.content or nil
            pcall(function()
                appendTimeline("RECV", commandType, content)
            end)
            return NativeGMBridge.originalModelOnCommand(self, luaCommand)
        end
    end
    return NativeGMBridge.originalModelSendLuaCommand ~= nil
        and NativeGMBridge.originalModelOnCommand ~= nil
end

local function readAccountBalance()
    if Gt2UserApp == nil or dinoBall == nil or dinoBall.currencyType == nil then
        return NativeGMBridge.lastAccountBalance
    end
    local ok, value = pcall(function()
        return Gt2UserApp:GetMoney(dinoBall.currencyType)
    end)
    if ok and value ~= nil then
        NativeGMBridge.lastAccountBalance = value
    end
    return NativeGMBridge.lastAccountBalance
end

local function appendEvent(name, detail)
    local file = io.open(EVENT_LOG_PATH, "a")
    if file == nil then
        return
    end
    file:write(tostring(os.time()) .. "|" .. tostring(name) .. "|" .. tostring(detail) .. "\n")
    file:close()
end

local function safeDetail(value)
    local text = tostring(value)
    text = string.gsub(text, "[\r\n]", " ")
    return string.gsub(text, ",", ";")
end

local function readLocalBalance()
    local property = dinoBall and dinoBall.propertyMgrInst or nil
    return property and property.getProperty and property:getProperty() or "unknown"
end

local function scheduleBalanceProbe(serial, delaySeconds)
    local director = cc and cc.Director and cc.Director:getInstance() or nil
    local scheduler = director and director:getScheduler() or nil
    if scheduler == nil then
        return
    end
    local scheduleId = nil
    scheduleId = scheduler:scheduleScriptFunc(function()
        if scheduleId ~= nil then
            scheduler:unscheduleScriptEntry(scheduleId)
            scheduleId = nil
        end
        appendEvent("balance_probe", "reward_serial=" .. tostring(serial)
            .. ",delay_s=" .. tostring(delaySeconds)
            .. ",local_balance=" .. tostring(readLocalBalance())
            .. ",account_balance=" .. tostring(readAccountBalance()))
    end, delaySeconds, false)
end

local function writeStatus(state, detail)
    if state ~= nil then
        NativeGMBridge.lastState = state
    end
    if detail ~= nil then
        NativeGMBridge.lastDetail = detail
    end
    local file = io.open(STATUS_PATH .. ".tmp", "w")
    if file == nil then
        return
    end
    local pending = NativeGMBridge.nextRewardType
    local property = dinoBall and dinoBall.propertyMgrInst or nil
    local localBase = property and property.propertyValue or "unknown"
    local localDelta = property and property.propertyChangeValue or "unknown"
    local localBalance = property and property.getProperty and property:getProperty() or "unknown"
    local accountBalance = readAccountBalance()
    local accountBefore = tonumber(NativeGMBridge.serverCodeAccountBefore)
    local accountNow = tonumber(accountBalance)
    local serverCodeAccountDelta = "unknown"
    if accountBefore ~= nil and accountNow ~= nil then
        serverCodeAccountDelta = accountNow - accountBefore
    end
    local serverCodeRewardDelta = NativeGMBridge.serverRewardSerial
        - NativeGMBridge.serverCodeRewardSerialBefore
    local pearlAccountBase = tonumber(NativeGMBridge.smallPearlAccountBase)
    local pearlAccountNow = tonumber(accountBalance)
    local smallPearlAccountDelta = "unknown"
    local smallPearlSync = "idle"
    if pearlAccountBase ~= nil and pearlAccountNow ~= nil then
        smallPearlAccountDelta = pearlAccountNow - pearlAccountBase
    end
    -- readAccountBalance() and addProperty() observe the same client-side model.
    -- Equality here is therefore not proof that the remote account was credited.
    if NativeGMBridge.smallPearlClientCredit > 0 then
        smallPearlSync = "local_only"
    end
    local gameMain = dinoBall and dinoBall.gameMain or nil
    local syncIndex = gameMain and gameMain.syncGameIndex or "unknown"
    -- A room re-entry resets the per-room sync index and refreshes the account
    -- model from the server. Confirm only when that refreshed balance preserves
    -- the exact expected net change from the authorized one-shot probe.
    if NativeGMBridge.officialWhiteState == "drop_verified"
        and tonumber(syncIndex) == 0
        and tonumber(NativeGMBridge.officialWhiteAccountBefore) ~= nil
        and tonumber(NativeGMBridge.officialWhiteExpectedNet) ~= nil
        and accountNow ~= nil then
        local reentryDelta = accountNow - tonumber(NativeGMBridge.officialWhiteAccountBefore)
        NativeGMBridge.officialWhiteServerDelta = reentryDelta
        if math.abs(reentryDelta - tonumber(NativeGMBridge.officialWhiteExpectedNet)) < 0.0001 then
            NativeGMBridge.officialWhiteState = "confirmed"
            NativeGMBridge.lastState = "server_settled"
            NativeGMBridge.lastDetail = "official white pearl persisted after room re-entry"
            appendEvent("official_white_reentry_balance", "confirmed=true,delta=" .. tostring(reentryDelta)
                .. ",expected_net=" .. tostring(NativeGMBridge.officialWhiteExpectedNet)
                .. ",balance=" .. tostring(accountBalance))
        end
    end
    file:write("state=" .. tostring(NativeGMBridge.lastState) .. "\n")
    file:write("detail=" .. tostring(NativeGMBridge.lastDetail) .. "\n")
    file:write("pending=" .. (pending == nil and "none" or tostring(pending)) .. "\n")
    file:write("persistent_path=" .. (NativeGMBridge.persistentRewardType == nil
        and "none" or tostring(NativeGMBridge.persistentRewardType)) .. "\n")
    file:write("account_balance=" .. tostring(accountBalance) .. "\n")
    file:write("local_balance=" .. tostring(localBalance) .. "\n")
    file:write("local_base=" .. tostring(localBase) .. "\n")
    file:write("local_delta=" .. tostring(localDelta) .. "\n")
    file:write("server_final=" .. tostring(NativeGMBridge.lastServerFinal) .. "\n")
    file:write("server_add=" .. tostring(NativeGMBridge.lastServerAdd) .. "\n")
    file:write("server_sub=" .. tostring(NativeGMBridge.lastServerSub) .. "\n")
    file:write("sync_index=" .. tostring(syncIndex) .. "\n")
    file:write("server_reward_count=" .. tostring(NativeGMBridge.lastServerRewardCount) .. "\n")
    file:write("server_reward_types=" .. tostring(NativeGMBridge.lastServerRewardTypes) .. "\n")
    file:write("server_path_reward=" .. tostring(NativeGMBridge.lastServerPathReward) .. "\n")
    file:write("visual_path_reward=" .. tostring(NativeGMBridge.lastVisualPathReward) .. "\n")
    file:write("visual_white_auto=" .. (NativeGMBridge.visualWhiteAutoEnabled and "on" or "off") .. "\n")
    file:write("official_blue_locked=" .. (NativeGMBridge.officialBlueLocked and "on" or "off") .. "\n")
    file:write("official_blue_outstanding=" .. tostring(NativeGMBridge.officialBlueOutstanding) .. "\n")
    file:write("official_white_state=" .. tostring(NativeGMBridge.officialWhiteState) .. "\n")
    file:write("official_white_tag=" .. tostring(NativeGMBridge.officialWhiteTag) .. "\n")
    file:write("official_white_bet=" .. tostring(NativeGMBridge.officialWhiteBet) .. "\n")
    file:write("official_white_expected_reward=" .. tostring(NativeGMBridge.officialWhiteExpectedReward) .. "\n")
    file:write("official_white_expected_net=" .. tostring(NativeGMBridge.officialWhiteExpectedNet) .. "\n")
    file:write("official_white_server_delta=" .. tostring(NativeGMBridge.officialWhiteServerDelta) .. "\n")
    file:write("server_code=" .. tostring(NativeGMBridge.lastServerCode) .. "\n")
    file:write("server_code_sent_at=" .. tostring(NativeGMBridge.serverCodeSentAt) .. "\n")
    file:write("server_code_account_before=" .. tostring(NativeGMBridge.serverCodeAccountBefore) .. "\n")
    file:write("server_code_account_delta=" .. tostring(serverCodeAccountDelta) .. "\n")
    file:write("server_code_reward_delta=" .. tostring(serverCodeRewardDelta) .. "\n")
    file:write("small_pearl_drop_count=" .. tostring(NativeGMBridge.smallPearlDropCount) .. "\n")
    file:write("small_pearl_last_value=" .. tostring(NativeGMBridge.smallPearlLastValue) .. "\n")
    file:write("small_pearl_client_credit=" .. tostring(NativeGMBridge.smallPearlClientCredit) .. "\n")
    file:write("small_pearl_account_delta=" .. tostring(smallPearlAccountDelta) .. "\n")
    file:write("small_pearl_sync=" .. tostring(smallPearlSync) .. "\n")
    file:write("dragon_sync_verify=" .. tostring(NativeGMBridge.lastGameStateVerify) .. "\n")
    file:write("dragon_sync_index=" .. tostring(NativeGMBridge.lastGameStateAckIndex) .. "\n")
    file:write("dragon_sync_reject_count=" .. tostring(NativeGMBridge.gameStateRejectCount) .. "\n")
    file:close()
    os.remove(STATUS_PATH)
    os.rename(STATUS_PATH .. ".tmp", STATUS_PATH)
end

local function installDiagnostics()
    local gameMain = dinoBall and dinoBall.gameMain or nil

    if dinoBall ~= nil and dinoBall.Machine ~= nil
        and NativeGMBridge.originalAddBonusDraBall == nil
        and dinoBall.Machine.addBonusDraBall ~= nil then
        NativeGMBridge.originalAddBonusDraBall = dinoBall.Machine.addBonusDraBall
        dinoBall.Machine.addBonusDraBall = function(self, count, ballType, dropInfo)
            local result = NativeGMBridge.originalAddBonusDraBall(self, count, ballType, dropInfo)
            appendEvent("ball_created", "ball_type=" .. tostring(ballType)
                .. ",count=" .. tostring(count)
                .. ",drop_info=" .. tostring(dropInfo ~= nil))
            return result
        end
    end

    if gameMain ~= nil and NativeGMBridge.originalOnEventBallDropDwon == nil
        and gameMain.OnEventBallDropDwon ~= nil then
        NativeGMBridge.originalOnEventBallDropDwon = gameMain.OnEventBallDropDwon
        gameMain.OnEventBallDropDwon = function(self, data)
            appendEvent("platform_drop", "ball_type=" .. tostring(data and data.ballType)
                .. ",ball_tag=" .. tostring(data and data.ballTag)
                .. ",sync_before=" .. tostring(self.syncGameIndex))
            return NativeGMBridge.originalOnEventBallDropDwon(self, data)
        end
    end
    if gameMain ~= nil and NativeGMBridge.originalOnSyncConeyAck == nil
        and gameMain.OnSyncConeyAck ~= nil then
        NativeGMBridge.originalOnSyncConeyAck = gameMain.OnSyncConeyAck
        gameMain.OnSyncConeyAck = function(self, data)
            if data ~= nil then
                NativeGMBridge.lastServerFinal = data.finalNum or "unknown"
                NativeGMBridge.lastServerAdd = data.addNum or "unknown"
                NativeGMBridge.lastServerSub = data.subNum or "unknown"
            end
            local result = NativeGMBridge.originalOnSyncConeyAck(self, data)
            if NativeGMBridge.officialWhiteState == "drop_verified"
                and data ~= nil and tonumber(data.finalNum) ~= nil
                and tonumber(NativeGMBridge.officialWhiteAccountBefore) ~= nil then
                local delta = tonumber(data.finalNum) - tonumber(NativeGMBridge.officialWhiteAccountBefore)
                NativeGMBridge.officialWhiteServerDelta = delta
                local expected = tonumber(NativeGMBridge.officialWhiteExpectedNet)
                if expected ~= nil and math.abs(delta - expected) < 0.0001 then
                    NativeGMBridge.officialWhiteState = "confirmed"
                    appendEvent("official_white_balance", "confirmed=true,delta=" .. tostring(delta)
                        .. ",expected_net=" .. tostring(expected)
                        .. ",final=" .. tostring(data.finalNum))
                    writeStatus("server_settled", "official white pearl credited")
                else
                    NativeGMBridge.officialWhiteState = "balance_mismatch"
                    appendEvent("official_white_balance", "confirmed=false,delta=" .. tostring(delta)
                        .. ",expected_net=" .. tostring(expected)
                        .. ",final=" .. tostring(data.finalNum))
                    writeStatus("server_mismatch", "official white pearl balance mismatch")
                end
            end
            appendEvent("server_sync", "final=" .. tostring(NativeGMBridge.lastServerFinal)
                .. ",add=" .. tostring(NativeGMBridge.lastServerAdd)
                .. ",sub=" .. tostring(NativeGMBridge.lastServerSub)
                .. ",local_balance=" .. tostring(readLocalBalance())
                .. ",account_balance=" .. tostring(readAccountBalance()))
            writeStatus("server_sync", "authoritative balance received")
            return result
        end
    end
    if gameMain ~= nil and NativeGMBridge.originalOnSyncGameStateAckV2 == nil
        and gameMain.OnSyncGameStateAckV2 ~= nil then
        NativeGMBridge.originalOnSyncGameStateAckV2 = gameMain.OnSyncGameStateAckV2
        gameMain.OnSyncGameStateAckV2 = function(self, data)
            local pendingIndex = NativeGMBridge.pendingOfficialPearlSyncIndex
            local ackIndex = data and data.index or nil
            local verified = data and data.verifyOk or false
            NativeGMBridge.lastGameStateVerify = verified and "true" or "false"
            NativeGMBridge.lastGameStateAckIndex = ackIndex or "unknown"
            if not verified then
                NativeGMBridge.gameStateRejectCount = NativeGMBridge.gameStateRejectCount + 1
            end
            local result = NativeGMBridge.originalOnSyncGameStateAckV2(self, data)
            appendEvent("dragon_sync_ack", "verify=" .. tostring(verified)
                .. ",index=" .. tostring(ackIndex)
                .. ",reject_count=" .. tostring(NativeGMBridge.gameStateRejectCount))
            if pendingIndex ~= nil and ackIndex == pendingIndex then
                NativeGMBridge.pendingOfficialPearlSyncIndex = nil
                local gameCtrl = self.gameView and self.gameView.gameCtrl or nil
                if verified and gameCtrl ~= nil and gameCtrl.onPearlPartyTrigger ~= nil then
                    local count = gameCtrl:onPearlPartyTrigger()
                    NativeGMBridge.officialBlueOutstanding = tonumber(count) or 0
                    appendEvent("official_blue_pearl_ack", "verify=true,index=" .. tostring(ackIndex)
                        .. ",count=" .. tostring(count))
                    writeStatus("server_verified", "official blue pearls=" .. tostring(count))
                    if NativeGMBridge.officialBlueOutstanding <= 0 then
                        NativeGMBridge.officialBlueLocked = false
                    end
                else
                    NativeGMBridge.officialBlueLocked = false
                    NativeGMBridge.officialBlueOutstanding = 0
                    appendEvent("official_blue_pearl_ack", "verify=false,index=" .. tostring(ackIndex))
                    writeStatus("server_rejected", "official blue pearl probe rejected")
                end
            end
            if NativeGMBridge.officialBlueFinalSyncIndex ~= nil
                and ackIndex == NativeGMBridge.officialBlueFinalSyncIndex then
                NativeGMBridge.officialBlueFinalSyncIndex = nil
                NativeGMBridge.officialBlueLocked = false
                if verified then
                    appendEvent("official_blue_settled", "verify=true,index=" .. tostring(ackIndex)
                        .. ",account=" .. tostring(readAccountBalance()))
                    writeStatus("server_settled", "official blue pearl batch settled")
                else
                    appendEvent("official_blue_settled", "verify=false,index=" .. tostring(ackIndex))
                    writeStatus("server_rejected", "official blue pearl settlement rejected")
                end
            end
            if NativeGMBridge.officialWhiteFireSyncIndex ~= nil
                and ackIndex == NativeGMBridge.officialWhiteFireSyncIndex then
                NativeGMBridge.officialWhiteFireSyncIndex = nil
                if verified then
                    NativeGMBridge.officialWhiteState = "fire_verified"
                    appendEvent("official_white_fire_ack", "verify=true,index=" .. tostring(ackIndex)
                        .. ",ball_tag=" .. tostring(NativeGMBridge.officialWhiteTag))
                    writeStatus("server_verified", "official white pearl is on table")
                else
                    NativeGMBridge.officialWhiteState = "rejected"
                    NativeGMBridge.officialWhiteLocked = false
                    NativeGMBridge.officialWhiteTags = {}
                    appendEvent("official_white_fire_ack", "verify=false,index=" .. tostring(ackIndex))
                    writeStatus("server_rejected", "official white pearl fire rejected")
                end
            end
            if NativeGMBridge.officialWhiteDropSyncIndex ~= nil
                and ackIndex == NativeGMBridge.officialWhiteDropSyncIndex then
                NativeGMBridge.officialWhiteDropSyncIndex = nil
                NativeGMBridge.officialWhiteLocked = false
                if verified then
                    NativeGMBridge.officialWhiteState = "drop_verified"
                    appendEvent("official_white_drop_ack", "verify=true,index=" .. tostring(ackIndex)
                        .. ",expected_reward=" .. tostring(NativeGMBridge.officialWhiteExpectedReward)
                        .. ",expected_net=" .. tostring(NativeGMBridge.officialWhiteExpectedNet))
                    writeStatus("server_pending", "drop verified; waiting authoritative balance")
                else
                    NativeGMBridge.officialWhiteState = "rejected"
                    appendEvent("official_white_drop_ack", "verify=false,index=" .. tostring(ackIndex))
                    writeStatus("server_rejected", "official white pearl drop rejected")
                end
            end
            return result
        end
    end

    if gameMain ~= nil and NativeGMBridge.originalOnUserConeyChanged == nil
        and gameMain.OnUserConeyChanged ~= nil then
        NativeGMBridge.originalOnUserConeyChanged = gameMain.OnUserConeyChanged
        gameMain.OnUserConeyChanged = function(self, data)
            if data ~= nil and data.coney ~= nil then
                NativeGMBridge.lastAccountBalance = data.coney
            end
            local result = NativeGMBridge.originalOnUserConeyChanged(self, data)
            appendEvent("account_update", "balance=" .. tostring(NativeGMBridge.lastAccountBalance))
            writeStatus("account_update", "platform balance notification received")
            return result
        end
    end

    if gameMain ~= nil and NativeGMBridge.originalOnChangeMoneyNotify == nil
        and gameMain.OnChangeMoneyNotify ~= nil then
        NativeGMBridge.originalOnChangeMoneyNotify = gameMain.OnChangeMoneyNotify
        gameMain.OnChangeMoneyNotify = function(self, data)
            local amount = data and data.changeAmount or "unknown"
            local accountBefore = readAccountBalance()
            local localBefore = readLocalBalance()
            local result = NativeGMBridge.originalOnChangeMoneyNotify(self, data)
            appendEvent("money_notify", "amount=" .. tostring(amount)
                .. ",local_before=" .. tostring(localBefore)
                .. ",local_after=" .. tostring(readLocalBalance())
                .. ",account_before=" .. tostring(accountBefore)
                .. ",account_after=" .. tostring(readAccountBalance()))
            return result
        end
    end

    if gameMain ~= nil and NativeGMBridge.originalOnEventChangeNotify == nil
        and gameMain.OnEventChangeNotify ~= nil then
        NativeGMBridge.originalOnEventChangeNotify = gameMain.OnEventChangeNotify
        gameMain.OnEventChangeNotify = function(self, data)
            local amount = data and data.changeAmount or "unknown"
            local accountBefore = readAccountBalance()
            local localBefore = readLocalBalance()
            local result = NativeGMBridge.originalOnEventChangeNotify(self, data)
            appendEvent("event_money_notify", "amount=" .. tostring(amount)
                .. ",local_before=" .. tostring(localBefore)
                .. ",local_after=" .. tostring(readLocalBalance())
                .. ",account_before=" .. tostring(accountBefore)
                .. ",account_after=" .. tostring(readAccountBalance()))
            return result
        end
    end

    local gameCtrl = gameMain and gameMain.gameView and gameMain.gameView.gameCtrl or nil
    if gameCtrl ~= nil and NativeGMBridge.originalOnDwonTrigger == nil
        and gameCtrl.onDwonTrigger ~= nil then
        NativeGMBridge.originalOnDwonTrigger = gameCtrl.onDwonTrigger
        gameCtrl.onDwonTrigger = function(self, ballType, ballPos, ballTag, dropItemInfo)
            if NativeGMBridge.visualPearlTags[ballTag] then
                NativeGMBridge.visualPearlTags[ballTag] = nil
                appendEvent("visual_pearl_drop_ignored", "ball_type=" .. tostring(ballType)
                    .. ",ball_tag=" .. tostring(ballTag))
                writeStatus("visual_only", "simulated pearl left table; no settlement sent")
                return
            end
            local isOfficialBlue = ballType == dinoBall.Define.BallType.BonusPearl
                and NativeGMBridge.officialBlueLocked
                and NativeGMBridge.officialBlueOutstanding > 0
            local result = NativeGMBridge.originalOnDwonTrigger(self, ballType, ballPos, ballTag, dropItemInfo)
            if NativeGMBridge.officialWhiteTags[ballTag] then
                NativeGMBridge.officialWhiteTags[ballTag] = nil
                NativeGMBridge.officialWhiteState = "drop_pending"
                appendEvent("official_white_drop", "ball_tag=" .. tostring(ballTag)
                    .. ",expected_reward=" .. tostring(NativeGMBridge.officialWhiteExpectedReward)
                    .. ",expected_net=" .. tostring(NativeGMBridge.officialWhiteExpectedNet))
                if gameMain.Net_SyncGameState ~= nil then
                    NativeGMBridge.officialWhiteDropSyncIndex = gameMain.syncGameIndex + 1
                    gameMain:Net_SyncGameState(true)
                    writeStatus("server_pending", "official white pearl drop sent")
                end
            end
            if isOfficialBlue then
                NativeGMBridge.officialBlueOutstanding = NativeGMBridge.officialBlueOutstanding - 1
                appendEvent("official_blue_drop", "ball_tag=" .. tostring(ballTag)
                    .. ",remaining=" .. tostring(NativeGMBridge.officialBlueOutstanding))
                if NativeGMBridge.officialBlueOutstanding <= 0 and gameMain.Net_SyncGameState ~= nil then
                    NativeGMBridge.officialBlueFinalSyncIndex = gameMain.syncGameIndex + 1
                    gameMain:Net_SyncGameState(true)
                    writeStatus("server_pending", "waiting for final blue pearl settlement")
                end
            end
            return result
        end
    end
    if gameCtrl ~= nil and NativeGMBridge.originalOnPartyTrigger == nil
        and gameCtrl.onPartyTrigger ~= nil then
        NativeGMBridge.originalOnPartyTrigger = gameCtrl.onPartyTrigger
        gameCtrl.onPartyTrigger = function(self, index, triggerPos, blockGroup, ballTag, shootRot)
            if NativeGMBridge.visualPearlTags[ballTag] then
                appendEvent("visual_party_hole_ignored", "index=" .. tostring(index)
                    .. ",ball_tag=" .. tostring(ballTag))
                return
            end
            return NativeGMBridge.originalOnPartyTrigger(self, index, triggerPos, blockGroup, ballTag, shootRot)
        end
    end
    if gameCtrl ~= nil and NativeGMBridge.originalGameCtrlAddProperty == nil
        and gameCtrl.addProperty ~= nil then
        NativeGMBridge.originalGameCtrlAddProperty = gameCtrl.addProperty
        gameCtrl.addProperty = function(self, value, from)
            local localBefore = readLocalBalance()
            local accountBefore = readAccountBalance()
            local result = NativeGMBridge.originalGameCtrlAddProperty(self, value, from)
            local localAfter = readLocalBalance()
            local accountAfter = readAccountBalance()
            local source = safeDetail(from)
            appendEvent("property_change", "value=" .. tostring(value)
                .. ",source=" .. source
                .. ",local_before=" .. tostring(localBefore)
                .. ",local_after=" .. tostring(localAfter)
                .. ",account_before=" .. tostring(accountBefore)
                .. ",account_after=" .. tostring(accountAfter))
            if string.find(source, "白or藍珍珠掉落", 1, true) ~= nil then
                if tonumber(NativeGMBridge.smallPearlAccountBase) == nil then
                    NativeGMBridge.smallPearlAccountBase = accountBefore
                end
                NativeGMBridge.smallPearlDropCount = NativeGMBridge.smallPearlDropCount + 1
                NativeGMBridge.smallPearlLastValue = tonumber(value) or 0
                NativeGMBridge.smallPearlClientCredit = NativeGMBridge.smallPearlClientCredit
                    + (tonumber(value) or 0)
                appendEvent("small_pearl_credit", "drop="
                    .. tostring(NativeGMBridge.smallPearlDropCount)
                    .. ",value=" .. tostring(value)
                    .. ",client_total=" .. tostring(NativeGMBridge.smallPearlClientCredit)
                    .. ",account_base=" .. tostring(NativeGMBridge.smallPearlAccountBase))
                writeStatus(nil, nil)
            end
            if string.find(source, "獎項表演", 1, true) ~= nil then
                NativeGMBridge.rewardCreditSerial = NativeGMBridge.rewardCreditSerial + 1
                local serial = NativeGMBridge.rewardCreditSerial
                appendEvent("reward_credit", "reward_serial=" .. tostring(serial)
                    .. ",value=" .. tostring(value)
                    .. ",source=" .. source
                    .. ",local_before=" .. tostring(localBefore)
                    .. ",local_after=" .. tostring(localAfter)
                    .. ",account_before=" .. tostring(accountBefore)
                    .. ",account_after=" .. tostring(accountAfter))
                scheduleBalanceProbe(serial, 0.5)
                scheduleBalanceProbe(serial, 2.0)
                scheduleBalanceProbe(serial, 5.0)
                scheduleBalanceProbe(serial, 10.0)
                writeStatus("reward_credit", "delayed prize credit observed")
            end
            return result
        end
    end
    if gameCtrl ~= nil and NativeGMBridge.originalOnGetSuperRewardRes == nil
        and gameCtrl.onGetSuperRewardRes ~= nil then
        NativeGMBridge.originalOnGetSuperRewardRes = gameCtrl.onGetSuperRewardRes
        gameCtrl.onGetSuperRewardRes = function(self, data)
            local rewardTypes = {}
            local list = data and data.superRewardResList or nil
            NativeGMBridge.lastServerRewardCount = list and #list or 0
            if list ~= nil then
                for _, reward in ipairs(list) do
                    table.insert(rewardTypes, tostring(reward.superRewardType))
                    appendEvent("server_outcome", "ball_type=" .. tostring(reward.ballType)
                        .. ",assigned_reward=" .. tostring(reward.superRewardType)
                        .. ",broadcast_index=" .. tostring(reward.broadcastIndex)
                        .. ",soul_num=" .. tostring(reward.soulNum))
                end
            end
            NativeGMBridge.lastServerRewardTypes = #rewardTypes > 0 and table.concat(rewardTypes, ",") or "none"
            NativeGMBridge.serverRewardSerial = NativeGMBridge.serverRewardSerial + 1
            local result = NativeGMBridge.originalOnGetSuperRewardRes(self, data)
            appendEvent("server_reward", "types=" .. tostring(NativeGMBridge.lastServerRewardTypes))
            writeStatus("server_reward", "dragon-ball result received")
            return result
        end
    end

    if gameCtrl ~= nil and NativeGMBridge.originalOnDraBallTrigger == nil
        and gameCtrl.onDraBallTrigger ~= nil then
        NativeGMBridge.originalOnDraBallTrigger = gameCtrl.onDraBallTrigger
        gameCtrl.onDraBallTrigger = function(self, discAngle, ballType, ballPos)
            local accountBefore = readAccountBalance()
            local property = dinoBall and dinoBall.propertyMgrInst or nil
            local localBefore = property and property.getProperty and property:getProperty() or "unknown"
            local assignedReward = self.currDraBallRewardType
            local result = NativeGMBridge.originalOnDraBallTrigger(self, discAngle, ballType, ballPos)
            local localAfter = property and property.getProperty and property:getProperty() or "unknown"
            local accountAfter = readAccountBalance()
            appendEvent("wheel_landed", "ball_type=" .. tostring(ballType)
                .. ",assigned_reward=" .. tostring(assignedReward)
                .. ",disc_angle=" .. tostring(discAngle)
                .. ",local_before=" .. tostring(localBefore)
                .. ",local_after=" .. tostring(localAfter)
                .. ",account_before=" .. tostring(accountBefore)
                .. ",account_after=" .. tostring(accountAfter))
            writeStatus("wheel_landed", "final wheel trigger observed")
            return result
        end
    end
end

local function sendServerCode(codeText)
    if codeText == nil or string.match(codeText, "^%d+$") == nil
        or #codeText < 1 or #codeText > 8 then
        writeStatus("error", "server code must contain 1-8 digits")
        return
    end
    local gameMain = dinoBall and dinoBall.gameMain or nil
    local protocol = dinoBall and dinoBall.Protocol
        and dinoBall.Protocol.DINOBALL_U2G_PROTOCOL or nil
    if gameMain == nil or gameMain.SendLuaCommand == nil or protocol == nil
        or protocol.U2G_CHEAT_CODE_REQ == nil or PearlBubbleCheatCodeReq == nil then
        writeStatus("not_ready", "server cheat protocol unavailable")
        return
    end

    local numericCode = tonumber(codeText)
    if numericCode == nil then
        writeStatus("error", "invalid server code")
        return
    end
    NativeGMBridge.lastServerCode = codeText
    NativeGMBridge.serverCodeAccountBefore = readAccountBalance()
    NativeGMBridge.serverCodeRewardSerialBefore = NativeGMBridge.serverRewardSerial
    NativeGMBridge.serverCodeSentAt = os.time()

    local request = PearlBubbleCheatCodeReq:create()
    request.code = numericCode
    gameMain:SendLuaCommand(protocol.U2G_CHEAT_CODE_REQ, request)
    appendEvent("server_code_sent", "code=" .. codeText
        .. ",account_before=" .. tostring(NativeGMBridge.serverCodeAccountBefore))
    writeStatus("server_sent", "server cheat code=" .. codeText)
end

local function getMachine()
    if dinoBall == nil or dinoBall.gameMain == nil or dinoBall.gameMain.gameView == nil then
        return nil
    end
    return dinoBall.gameMain.gameView.machine
end

local function markVisualPearl(machine, ball)
    machine:nextBallTag()
    local tag = machine.ballTag
    ball:setTag(tag)
    NativeGMBridge.visualPearlTags[tag] = true
    return tag
end

-- Visual/physics simulation only. Tagged pearls are intercepted before the
-- normal reward and network-settlement callbacks.
local function spawnVisualPearls(ballType, count)
    local machine = getMachine()
    if machine == nil or dinoBall == nil or dinoBall.PhysicsBall == nil then
        writeStatus("not_ready", "visual pearl simulator unavailable")
        return
    end
    for i = 1, count do
        local column = (i - 1) % 5
        local row = math.floor((i - 1) / 5)
        local pos = cc.vec3(-22 + column * 4.5, 42 + row * 0.25, -3.5 + row * 1.8)
        local rot = cc.vec3((i * 37) % 360, (i * 71) % 360, 0)
        local ball = dinoBall.PhysicsBall:create(ballType, machine.ballRoot, pos, rot)
        if ballType == dinoBall.Define.BallType.BonusPearl then
            ball:setIsBonus(true)
        end
        markVisualPearl(machine, ball)
        machine.pearlCount = machine.pearlCount + 1
    end
    machine:onBallCountChanged()
    appendEvent("visual_pearl_spawned", "ball_type=" .. tostring(ballType)
        .. ",count=" .. tostring(count))
    writeStatus("visual_only", "simulated pearls placed x" .. tostring(count))
end

local function shootVisualWhitePearl()
    local machine = getMachine()
    local define = dinoBall and dinoBall.Define or nil
    if machine == nil or machine.shootPearl == nil or define == nil then
        writeStatus("not_ready", "white pearl cannon unavailable")
        return
    end
    local group = define.BlockGroup.DraBall + define.BlockGroup.Pearl + define.BlockGroup.Ticket
    local tag = machine:shootPearl(group, dinoBall.ShootAngleG or 0, 1)
    NativeGMBridge.visualPearlTags[tag] = true
    appendEvent("visual_pearl_spawned", "ball_type=" .. tostring(define.BallType.Pearl)
        .. ",count=1,launcher=cannon,ball_tag=" .. tostring(tag))
    writeStatus("visual_only", "white pearl fired; settlement disabled")
end

local function shootVisualBluePearl()
    local machine = getMachine()
    local define = dinoBall and dinoBall.Define or nil
    if machine == nil or machine.getBonusBallPos == nil or define == nil then
        writeStatus("not_ready", "blue pearl launcher unavailable")
        return
    end
    local launch = function()
        local ball = dinoBall.PhysicsBall:create(define.BallType.BonusPearl,
            machine.ballRoot, machine:getBonusBallPos(false), nil)
        machine.pearlCount = machine.pearlCount + 1
        machine:onBallCountChanged()
        local tag = markVisualPearl(machine, ball)
        ball:applyCentralImpulse(define.MachineDefine.BonusPearl.Force)
        ball:setIsBonus(true)
        appendEvent("visual_pearl_spawned", "ball_type=" .. tostring(define.BallType.BonusPearl)
            .. ",count=1,launcher=dragon_head,ball_tag=" .. tostring(tag))
    end
    if machine.playDragonHeadShoot ~= nil then
        machine:playDragonHeadShoot(define.BallType.BonusPearl, launch)
    else
        launch()
    end
    writeStatus("visual_only", "blue pearl fired; settlement disabled")
end

local function updateVisualWhiteAuto()
    if not NativeGMBridge.visualWhiteAutoEnabled then
        return
    end
    NativeGMBridge.visualWhiteAutoTicks = NativeGMBridge.visualWhiteAutoTicks + 1
    if NativeGMBridge.visualWhiteAutoTicks < 4 then
        return
    end
    NativeGMBridge.visualWhiteAutoTicks = 0
    local machine = getMachine()
    if machine == nil or machine.getPearlCount == nil then
        return
    end
    if machine:getPearlCount() >= NativeGMBridge.visualWhiteAutoMaxPearls then
        return
    end
    shootVisualWhitePearl()
end

-- Submit the same ordered state transition as a paid white shot entering a
-- pearl-award middle hole. Blue pearls are created only after verifyOk=true.
local function requestOfficialBluePearls()
    if NativeGMBridge.pendingOfficialPearlSyncIndex ~= nil or NativeGMBridge.officialBlueLocked then
        writeStatus("waiting", "official blue pearl batch still active")
        return
    end
    local gameMain = dinoBall and dinoBall.gameMain or nil
    local gameCtrl = gameMain and gameMain.gameView and gameMain.gameView.gameCtrl or nil
    local machine = gameMain and gameMain.gameView and gameMain.gameView.machine or nil
    local define = dinoBall and dinoBall.Define or nil
    if gameMain == nil or gameCtrl == nil or machine == nil or define == nil
        or gameCtrl.shootPearl == nil or gameMain.Net_SyncGameState == nil then
        writeStatus("not_ready", "official blue pearl flow unavailable")
        return
    end

    NativeGMBridge.visualWhiteAutoEnabled = false
    NativeGMBridge.officialBlueLocked = true
    NativeGMBridge.officialBlueOutstanding = 0
    local shotOk = gameCtrl:shootPearl()
    if not shotOk then
        NativeGMBridge.officialBlueLocked = false
        writeStatus("not_ready", "paid white shot was not accepted locally")
        return
    end
    local ballTag = machine.ballTag
    local holeIndex = nil
    for index, triggerType in pairs(define.PartyTriggerDefine) do
        if triggerType == define.PartyTriggerType.Pearl then
            holeIndex = index
            break
        end
    end
    if holeIndex == nil then
        NativeGMBridge.officialBlueLocked = false
        writeStatus("error", "pearl-award hole unavailable")
        return
    end

    -- Prevent the same physical shot from reporting a second middle-hole hit.
    machine.nonEnterPearl[ballTag] = nil
    local eventData = {
        index = holeIndex,
        partyTriggerType = define.PartyTriggerType.Pearl,
        ballGroup = define.BlockGroup.Pearl,
        currPartyType = gameCtrl.currPartyType,
        value = 0,
        ballTag = ballTag,
        shootRot = dinoBall.ShootAngleG or 0
    }
    dinoBall.CustomEventMgr:NotifyEvent(define.Event.EnterPartyHole, eventData)
    NativeGMBridge.pendingOfficialPearlSyncIndex = gameMain.syncGameIndex + 1
    appendEvent("official_blue_pearl_req", "ball_tag=" .. tostring(ballTag)
        .. ",hole_index=" .. tostring(holeIndex)
        .. ",sync_index=" .. tostring(NativeGMBridge.pendingOfficialPearlSyncIndex))
    gameMain:Net_SyncGameState(true)
    writeStatus("server_pending", "official blue pearl probe sent")
end

-- Authorized single-shot settlement probe.  A normal paid shot creates the
-- server-tracked ball index and debit event; only its client physics position
-- is moved onto the pusher table.  The drop then follows the stock callback,
-- state-sync and authoritative balance paths.
local function requestOfficialWhitePearlOnTable()
    if NativeGMBridge.officialWhiteLocked then
        writeStatus("waiting", "official white pearl probe still active")
        return
    end
    local gameMain = dinoBall and dinoBall.gameMain or nil
    local gameCtrl = gameMain and gameMain.gameView and gameMain.gameView.gameCtrl or nil
    local machine = gameMain and gameMain.gameView and gameMain.gameView.machine or nil
    local define = dinoBall and dinoBall.Define or nil
    if gameMain == nil or gameCtrl == nil or machine == nil or define == nil
        or gameCtrl.shootPearl == nil or gameMain.Net_SyncGameState == nil
        or machine.ballRoot == nil then
        writeStatus("not_ready", "official white pearl flow unavailable")
        return
    end

    NativeGMBridge.visualWhiteAutoEnabled = false
    NativeGMBridge.officialWhiteLocked = true
    NativeGMBridge.officialWhiteState = "creating"
    NativeGMBridge.officialWhiteBet = tonumber(gameCtrl.bet or gameMain.currenctBet) or 0
    NativeGMBridge.officialWhiteExpectedReward =
        (tonumber(define.PearlDefine.GetPropertyPercent) or 0)
        * NativeGMBridge.officialWhiteBet / 100
    NativeGMBridge.officialWhiteExpectedNet = NativeGMBridge.officialWhiteExpectedReward
        - NativeGMBridge.officialWhiteBet
    NativeGMBridge.officialWhiteAccountBefore = readAccountBalance()
    NativeGMBridge.officialWhiteServerDelta = "unknown"

    local shotOk = gameCtrl:shootPearl()
    if not shotOk then
        NativeGMBridge.officialWhiteLocked = false
        NativeGMBridge.officialWhiteState = "not_ready"
        writeStatus("not_ready", "paid white shot was not accepted locally")
        return
    end

    local ballTag = machine.ballTag
    local targetBall = nil
    for _, ball in pairs(machine.ballRoot:getChildren()) do
        if ball.getTag ~= nil and ball:getTag() == ballTag then
            targetBall = ball
            break
        end
    end
    NativeGMBridge.officialWhiteTag = ballTag
    NativeGMBridge.officialWhiteTags[ballTag] = true
    if targetBall ~= nil and targetBall.setPosition3D ~= nil then
        targetBall:setPosition3D(cc.vec3(-12, 39.1, -2.5))
    end

    NativeGMBridge.officialWhiteState = "fire_pending"
    NativeGMBridge.officialWhiteFireSyncIndex = gameMain.syncGameIndex + 1
    appendEvent("official_white_created", "ball_tag=" .. tostring(ballTag)
        .. ",bet=" .. tostring(NativeGMBridge.officialWhiteBet)
        .. ",expected_reward=" .. tostring(NativeGMBridge.officialWhiteExpectedReward)
        .. ",expected_net=" .. tostring(NativeGMBridge.officialWhiteExpectedNet)
        .. ",relocated=" .. tostring(targetBall ~= nil))
    gameMain:Net_SyncGameState(true)
    writeStatus("server_pending", "paid white pearl moved onto table")
end

local function addBall(ballType, label)
    local machine = getMachine()
    if machine == nil or machine.addBonusDraBall == nil or machine.createBonusDraBall == nil then
        writeStatus("not_ready", "machine unavailable")
        return
    end

    local dropInfo = nil
    if ballType == dinoBall.Define.BallType.DraBall
        and dinoBall.gameMain.gameView.gameCtrl
        and dinoBall.gameMain.gameView.gameCtrl.getBonusDraBallDropInfo then
        dropInfo = dinoBall.gameMain.gameView.gameCtrl:getBonusDraBallDropInfo()
    end

    machine:addBonusDraBall(1, ballType, dropInfo)
    machine:createBonusDraBall()
    writeStatus("executed", label)
end

-- Follow the same dragon-hole path used by the shipped TestUI instead of
-- directly creating a physics object. This records SGSCSE_EnterMid and lets
-- the game's normal launcher delay create the ball.
local function triggerNaturalDraBall()
    local gameMain = dinoBall and dinoBall.gameMain or nil
    local gameCtrl = gameMain and gameMain.gameView and gameMain.gameView.gameCtrl or nil
    local define = dinoBall and dinoBall.Define or nil
    if gameCtrl == nil or gameCtrl.onPartyTrigger == nil or define == nil
        or define.PartyTriggerDefine == nil or define.PartyTriggerType == nil
        or define.BlockGroup == nil or define.MachineDefine == nil
        or define.MachineDefine.PartyTrigger == nil then
        writeStatus("not_ready", "natural dragon-ball trigger unavailable")
        return
    end

    local triggerIndex = nil
    for index, triggerType in pairs(define.PartyTriggerDefine) do
        if triggerType == define.PartyTriggerType.DraBall then
            triggerIndex = index
            break
        end
    end
    if triggerIndex == nil then
        writeStatus("error", "dragon-ball party-hole index unavailable")
        return
    end

    local sourcePos = define.MachineDefine.PartyTrigger.CenterPos
    local triggerPos = sourcePos
    if clone ~= nil then
        triggerPos = clone(sourcePos)
    elseif cc ~= nil and cc.vec3 ~= nil and sourcePos ~= nil then
        triggerPos = cc.vec3(sourcePos.x, sourcePos.y, sourcePos.z)
    end

    local syncBefore = gameMain.syncGameIndex
    gameCtrl:onPartyTrigger(triggerIndex, triggerPos, define.BlockGroup.EnterDraBall)
    appendEvent("natural_draball_trigger", "index=" .. tostring(triggerIndex)
        .. ",block_group=" .. tostring(define.BlockGroup.EnterDraBall)
        .. ",sync_before=" .. tostring(syncBefore))
    writeStatus("executed", "natural dragon-ball party-hole flow triggered")
end

local function installPathOverride()
    if NativeGMBridge.originalShootDraBallByRes ~= nil then
        return true
    end
    if dinoBall == nil or dinoBall.Machine == nil or dinoBall.Machine.shootDraBallByRes == nil then
        return false
    end

    NativeGMBridge.originalShootDraBallByRes = dinoBall.Machine.shootDraBallByRes
    dinoBall.Machine.shootDraBallByRes = function(self, ballType, rewardType)
        NativeGMBridge.lastServerPathReward = rewardType
        local selected = NativeGMBridge.nextRewardType
        if selected ~= nil then
            NativeGMBridge.nextRewardType = nil
        else
            selected = NativeGMBridge.persistentRewardType
        end
        if selected ~= nil then
            NativeGMBridge.lastVisualPathReward = selected
            appendEvent("path_applied", "ball_type=" .. tostring(ballType)
                .. ",server_reward=" .. tostring(rewardType)
                .. ",visual_path=" .. tostring(selected))
            writeStatus("applied", "visual path=" .. tostring(selected)
                .. ", server reward=" .. tostring(rewardType))
            return NativeGMBridge.originalShootDraBallByRes(self, ballType, selected)
        end
        NativeGMBridge.lastVisualPathReward = rewardType
        return NativeGMBridge.originalShootDraBallByRes(self, ballType, rewardType)
    end
    return true
end

local function dispatch(command)
    local codeText = string.match(command, "^SERVER_CODE:(%d+)$")
    local holdPath = string.match(command, "^PATH_([123])_HOLD$")
    if holdPath ~= nil then
        NativeGMBridge.nextRewardType = nil
        NativeGMBridge.persistentRewardType = tonumber(holdPath)
        local pathNames = { [1] = "small", [2] = "middle", [3] = "big" }
        writeStatus("armed", "persistent path=" .. pathNames[NativeGMBridge.persistentRewardType])
    elseif codeText ~= nil then
        sendServerCode(codeText)
    elseif command == "ADD_DRA" then
        writeStatus("blocked", "ADD_DRA disabled: server verify rejected")
    elseif command == "ADD_RAIN" then
        addBall(dinoBall.Define.BallType.Rainball, "rainbow ball added")
    elseif command == "VISUAL_WHITE_10" then
        spawnVisualPearls(dinoBall.Define.BallType.Pearl, 10)
    elseif command == "VISUAL_BLUE_10" then
        spawnVisualPearls(dinoBall.Define.BallType.BonusPearl, 10)
    elseif command == "VISUAL_SHOOT_WHITE" then
        shootVisualWhitePearl()
    elseif command == "VISUAL_SHOOT_BLUE" then
        shootVisualBluePearl()
    elseif command == "TOGGLE_VISUAL_WHITE_AUTO" then
        NativeGMBridge.visualWhiteAutoEnabled = not NativeGMBridge.visualWhiteAutoEnabled
        NativeGMBridge.visualWhiteAutoTicks = 0
        appendEvent("visual_white_auto", NativeGMBridge.visualWhiteAutoEnabled and "on" or "off")
        writeStatus("visual_only", "white pearl auto fire="
            .. (NativeGMBridge.visualWhiteAutoEnabled and "on" or "off"))
    elseif command == "OFFICIAL_BLUE_PROBE" then
        requestOfficialBluePearls()
    elseif command == "OFFICIAL_WHITE_TABLE_PROBE" then
        requestOfficialWhitePearlOnTable()
    elseif command == "PATH_0" then
        NativeGMBridge.nextRewardType = 0
        writeStatus("armed", "next path=none")
    elseif command == "PATH_1" then
        NativeGMBridge.nextRewardType = 1
        writeStatus("armed", "next path=small")
    elseif command == "PATH_2" then
        NativeGMBridge.nextRewardType = 2
        writeStatus("armed", "next path=middle")
    elseif command == "PATH_3" then
        NativeGMBridge.nextRewardType = 3
        writeStatus("armed", "next path=big")
    elseif command == "CANCEL_PATH" then
        NativeGMBridge.nextRewardType = nil
        NativeGMBridge.persistentRewardType = nil
        writeStatus("ready", "path override cancelled")
    else
        writeStatus("error", "unknown command=" .. tostring(command))
    end
end

local function pollCommand()
    installPassiveTimeline()
    installPathOverride()
    installDiagnostics()
    updateVisualWhiteAuto()
    NativeGMBridge.statusPollCount = NativeGMBridge.statusPollCount + 1
    if NativeGMBridge.statusPollCount >= 10 then
        NativeGMBridge.statusPollCount = 0
        writeStatus(nil, nil)
    end
    local file = io.open(COMMAND_PATH, "r")
    if file == nil then
        return
    end
    local content = file:read("*a") or ""
    file:close()
    local nonce, command = string.match(content, "^([^|\r\n]+)|([^\r\n]+)")
    if nonce == nil or command == nil or nonce == NativeGMBridge.lastNonce then
        return
    end

    -- Several StarMJ helper processes can load this bridge and poll the same
    -- command file.  Atomically rename it before dispatch so exactly one
    -- process owns the command instead of every process replaying it.
    local claimPath = COMMAND_PATH .. "." .. nonce .. ".claim"
    local claimed = os.rename(COMMAND_PATH, claimPath)
    if not claimed then
        return
    end
    local claimedFile = io.open(claimPath, "r")
    if claimedFile == nil then
        os.remove(claimPath)
        return
    end
    local claimedContent = claimedFile:read("*a") or ""
    claimedFile:close()
    os.remove(claimPath)
    nonce, command = string.match(claimedContent, "^([^|\r\n]+)|([^\r\n]+)")
    if nonce == nil or command == nil or nonce == NativeGMBridge.lastNonce then
        return
    end
    NativeGMBridge.lastNonce = nonce
    local ok, err = pcall(dispatch, command)
    if not ok then
        writeStatus("error", tostring(err))
    end
end

function NativeGMBridge:Start()
    if self.scheduleId ~= nil then
        return
    end
    -- Never replay a command left behind by an earlier game session.
    os.remove(COMMAND_PATH)
    self.visualPearlTags = {}
    self.visualWhiteAutoEnabled = false
    self.visualWhiteAutoTicks = 0
    self.pendingOfficialPearlSyncIndex = nil
    self.officialBlueLocked = false
    self.officialBlueOutstanding = 0
    self.officialBlueFinalSyncIndex = nil
    self.officialWhiteTags = {}
    self.officialWhiteLocked = false
    self.officialWhiteTag = "none"
    self.officialWhiteFireSyncIndex = nil
    self.officialWhiteDropSyncIndex = nil
    self.officialWhiteState = "idle"
    self.officialWhiteBet = 0
    self.officialWhiteExpectedReward = 0
    self.officialWhiteExpectedNet = 0
    self.officialWhiteAccountBefore = readAccountBalance()
    self.officialWhiteServerDelta = "unknown"
    self.smallPearlDropCount = 0
    self.smallPearlLastValue = 0
    self.smallPearlClientCredit = 0
    self.smallPearlAccountBase = readAccountBalance()
    self.lastGameStateVerify = "none"
    self.lastGameStateAckIndex = "unknown"
    self.gameStateRejectCount = 0
    dinoBall.NativeGMBridge = self
    startTimeline()
    installPassiveTimeline()
    installPathOverride()
    installDiagnostics()
    self.scheduleId = cc.Director:getInstance():getScheduler():scheduleScriptFunc(pollCommand, 0.10, false)
    writeStatus("ready", "Pearl Bubble bridge online")
end

function NativeGMBridge:Stop()
    self.nextRewardType = nil
    self.persistentRewardType = nil
    self.visualPearlTags = {}
    self.visualWhiteAutoEnabled = false
    self.visualWhiteAutoTicks = 0
    self.pendingOfficialPearlSyncIndex = nil
    self.officialBlueLocked = false
    self.officialBlueOutstanding = 0
    self.officialBlueFinalSyncIndex = nil
    self.officialWhiteTags = {}
    self.officialWhiteLocked = false
    self.officialWhiteTag = "none"
    self.officialWhiteFireSyncIndex = nil
    self.officialWhiteDropSyncIndex = nil
    self.officialWhiteState = "idle"
    self.officialWhiteBet = 0
    self.officialWhiteExpectedReward = 0
    self.officialWhiteExpectedNet = 0
    self.officialWhiteAccountBefore = "unknown"
    self.officialWhiteServerDelta = "unknown"
    if self.scheduleId ~= nil then
        cc.Director:getInstance():getScheduler():unscheduleScriptEntry(self.scheduleId)
        self.scheduleId = nil
    end
    if self.originalShootDraBallByRes ~= nil and dinoBall and dinoBall.Machine then
        dinoBall.Machine.shootDraBallByRes = self.originalShootDraBallByRes
        self.originalShootDraBallByRes = nil
    end
    if self.originalAddBonusDraBall ~= nil and dinoBall and dinoBall.Machine then
        dinoBall.Machine.addBonusDraBall = self.originalAddBonusDraBall
        self.originalAddBonusDraBall = nil
    end
    if self.originalModelSendLuaCommand ~= nil and PearlBubbleModel ~= nil then
        PearlBubbleModel.SendLuaCommand = self.originalModelSendLuaCommand
        self.originalModelSendLuaCommand = nil
    end
    if self.originalModelOnCommand ~= nil and PearlBubbleModel ~= nil then
        PearlBubbleModel.OnCommand = self.originalModelOnCommand
        self.originalModelOnCommand = nil
    end
    local gameMain = dinoBall and dinoBall.gameMain or nil
    if self.originalOnSyncConeyAck ~= nil and gameMain ~= nil then
        gameMain.OnSyncConeyAck = self.originalOnSyncConeyAck
        self.originalOnSyncConeyAck = nil
    end
    if self.originalOnSyncGameStateAckV2 ~= nil and gameMain ~= nil then
        gameMain.OnSyncGameStateAckV2 = self.originalOnSyncGameStateAckV2
        self.originalOnSyncGameStateAckV2 = nil
    end
    if self.originalOnUserConeyChanged ~= nil and gameMain ~= nil then
        gameMain.OnUserConeyChanged = self.originalOnUserConeyChanged
        self.originalOnUserConeyChanged = nil
    end
    if self.originalOnChangeMoneyNotify ~= nil and gameMain ~= nil then
        gameMain.OnChangeMoneyNotify = self.originalOnChangeMoneyNotify
        self.originalOnChangeMoneyNotify = nil
    end
    if self.originalOnEventChangeNotify ~= nil and gameMain ~= nil then
        gameMain.OnEventChangeNotify = self.originalOnEventChangeNotify
        self.originalOnEventChangeNotify = nil
    end
    if self.originalOnEventBallDropDwon ~= nil and gameMain ~= nil then
        gameMain.OnEventBallDropDwon = self.originalOnEventBallDropDwon
        self.originalOnEventBallDropDwon = nil
    end
    local gameCtrl = gameMain and gameMain.gameView and gameMain.gameView.gameCtrl or nil
    if self.originalOnGetSuperRewardRes ~= nil and gameCtrl ~= nil then
        gameCtrl.onGetSuperRewardRes = self.originalOnGetSuperRewardRes
        self.originalOnGetSuperRewardRes = nil
    end
    if self.originalOnDraBallTrigger ~= nil and gameCtrl ~= nil then
        gameCtrl.onDraBallTrigger = self.originalOnDraBallTrigger
        self.originalOnDraBallTrigger = nil
    end
    if self.originalGameCtrlAddProperty ~= nil and gameCtrl ~= nil then
        gameCtrl.addProperty = self.originalGameCtrlAddProperty
        self.originalGameCtrlAddProperty = nil
    end
    if self.originalOnDwonTrigger ~= nil and gameCtrl ~= nil then
        gameCtrl.onDwonTrigger = self.originalOnDwonTrigger
        self.originalOnDwonTrigger = nil
    end
    if self.originalOnPartyTrigger ~= nil and gameCtrl ~= nil then
        gameCtrl.onPartyTrigger = self.originalOnPartyTrigger
        self.originalOnPartyTrigger = nil
    end
    writeStatus("stopped", "bridge stopped")
end

return NativeGMBridge

HealUI = {}

HealUI.owningGroup = nil

HealUI.unit = nil

HealUI.rootContainer = nil -- Contains the main container and the overlay
HealUI.overlayContainer = nil -- Contains elements that should not be affected by opacity
HealUI.container = nil -- Most elements are contained in this
HealUI.nameText = nil
HealUI.healthBar = nil
HealUI.incomingHealthBar = nil
HealUI.healthText = nil
HealUI.missingHealthText = nil
HealUI.incomingHealText = nil
HealUI.powerBar = nil
HealUI.powerText = nil
HealUI.roleIcon = nil
HealUI.button = nil
HealUI.auraPanel = nil
HealUI.scrollingDamageFrame = nil -- Unimplemented
HealUI.scrollingHealFrame = nil -- Unimplemented
HealUI.auraIconPool = {} -- map: {"frame", "icon", "stackText"}
HealUI.auraIcons = {} -- map: {"frame", "icon", "stackText"}

HealUI.incomingHealing = 0

HealUI.hovered = false
HealUI.pressed = false

HealUI.distanceText = nil
HealUI.lineOfSightIcon = nil -- map: {"frame", "icon"}

HealUI.inRange = true
HealUI.distance = 0
HealUI.inSight = true

HealUI.fakeStats = {} -- Used for displaying a fake party/raid

-- Singleton references, assigned in constructor
local HM
local util

function HealUI:New(unit)
    HM = HealersMate -- Need to do this in the constructor or else it doesn't exist yet
    util = HMUtil
    local obj = {unit = unit, auraIconPool = {}, auraIcons = {}, fakeStats = HealUI.GenerateFakeStats()}
    setmetatable(obj, self)
    self.__index = self
    return obj
end

local fakeNames = {"Leeroyjenkins", "Realsigred", "Appledog", "Exdraclespy", "Dieghostt", "Olascoli", "Yaijin", 
    "Geroya", "Artemyz", "Nomeon", "Orinnberry", "Hoppetosse", "Deathell", "Jackbob", "Luscita", "Healpiggies", 
    "Pamara", "Merauder", "Onetwofree", "Biggly", "Drexx", "Grassguzzler", "Thebackup", "Steaktank", "Fshoo", 
    "Bovinebill", "Rawtee", "Aylin", "Sneeziesnorf", "Dreak", "Jordin", "Evilkillers", "Xathas", "Linkado", 
    "Smiteknight", "Rollnmbqs", "Viniss", "Rinnegon", "Elfdefense", "Foxtau", "Tombdeath", "Myhawk", "Numnumcat", 
    "Laudead", "Esatto", "Boffin", "Tikomo", "Huddletree", "Butterboy", "Bolgrand", "Ginius", "Exulthiuss", 
    "Xplol", "Wheeliebear", "Pimenton", "Meditating", "Qyroth", "Lazhar", "Rookon", "Eiris", "Padren", 
    "Erazergus", "Scarlatina", "Holdrim", "Soulbane", "Debilitated", "Doorooid", "Palefire", "Tellarna", 
    "Breathofwing", "Chillaf", "Hulena", "Hyperiann", "Bluebeam", "Daevana", "Adriena", "Aeywynn", "Bluaa", 
    "Chadd", "Leutry", "Mouzer", "Qiner"}
function HealUI.GenerateFakeStats()

    local name = fakeNames[math.random(table.getn(fakeNames))]

    local class = util.GetRandomClass()

    local currentHealth
    local maxHealth = math.random(100, 5000)
    if math.random(10) > 3 then
        currentHealth = math.random(1, maxHealth)
    elseif math.random(8) == 1 then
        currentHealth = 0
    else
        currentHealth = maxHealth
    end

    local maxPower = math.random(100, 5000)
    if util.ClassPowerTypes[class] ~= "mana" then
        maxPower = 100
    end
    local currentPower = math.random(1, maxPower)

    local debuffType
    local trackedDebuffCount = table.getn(HealersMateSettings.TrackedDebuffTypes)
    if trackedDebuffCount > 0 then
        if math.random(1, 10) == 1 then
            debuffType = HealersMateSettings.TrackedDebuffTypes[math.random(trackedDebuffCount)]
        end
    end

    local online = not (math.random(12) == 1)

    local fakeStats = {
        name = name,
        class = class, 
        currentHealth = currentHealth, 
        maxHealth = maxHealth,
        currentPower = currentPower,
        maxPower = maxPower,
        debuffType = debuffType,
        online = online}
    return fakeStats
end

function HealUI:GetUnit()
    return self.unit
end

function HealUI:GetRootContainer()
    return self.rootContainer
end

function HealUI:GetContainer()
    return self.container
end

function HealUI:Show()
    self.container:Show()
    self.rootContainer:Show()
    self:UpdateAll()
end

function HealUI:Hide()
    if not self:IsFake() then
        self.container:Hide()
        self.rootContainer:Hide()
    end
end

function HealUI:IsShown()
    return self.rootContainer:IsShown()
end

function HealUI:SetOwningGroup(group)
    self.owningGroup = group
    self:Initialize()
    self:GetRootContainer():SetParent(group:GetContainer())
end

function HealUI:RegisterClicks()
    local buttons = HMOptions.CastWhen == "Mouse Up" and util.GetUpButtons() or util.GetDownButtons()
    self.button:RegisterForClicks(unpack(buttons))
    for _, aura in ipairs(self.auraIcons) do
        aura.frame:RegisterForClicks(unpack(buttons))
    end
    for _, aura in ipairs(self.auraIconPool) do
        aura.frame:RegisterForClicks(unpack(buttons))
    end
end

function HealUI:UpdateAll()
    self:UpdateAuras()
    self:UpdateHealth()
    self:UpdatePower()
end

function HealUI:CheckRange(dist)
    local unit = self.unit
    if not dist then
        dist = util.GetDistanceTo(unit)
    end
    self.distance = dist
    local wasInRange = self.inRange
    self.inRange = dist <= 40
    if wasInRange ~= self.inRange then
        self:UpdateOpacity()
    end

    self:UpdateRangeText()
end

function HealUI:CheckSight()
    self.inSight = util.IsInSight(self.unit)
    local frame = self.lineOfSightIcon.frame
    if frame:IsShown() ~= self.inSight then
        local dist = math.ceil(self.distance)
        if not self.inSight and dist < 80 then
            frame:Show()
        else
            frame:Hide()
        end
    end
end

function HealUI:UpdateRangeText()
    local dist = math.ceil(self.distance)
    local distanceText = self.distanceText
    local text = ""
    if dist >= 30 and dist < 100 then
        local color
        if dist <= 40 then
            color = {1, 0.6, 0}
        else
            color = {1, 0.3, 0.3}
        end

        text = text..util.Colorize(dist.." yd", color)
    elseif dist >= 100 and dist < 9999 then
        text = text..util.Colorize("99+ yd", {1, 0.3, 0.3})
    end
    distanceText:SetText(text)
end

function HealUI:UpdateOpacity()
    local profile = self:GetProfile()
    
    local alpha = 1
    if not self.inRange then
        alpha = alpha * (profile.OutOfRangeOpacity / 100)
    end
    if profile.AlertPercent < math.ceil((self:GetCurrentHealth() / self:GetMaxHealth()) * 100) and 
            table.getn(self:GetAfflictedDebuffTypes()) == 0 then
        alpha = alpha * (profile.NotAlertedOpacity / 100)
    end
    self.container:SetAlpha(alpha)
end

function HealUI:GetCurrentHealth()
    if self:IsFake() then
        if not self.fakeStats.online then
            return 0
        end
        return self.fakeStats.currentHealth
    end
    return UnitHealth(self.unit)
end

function HealUI:GetMaxHealth()
    if self:IsFake() then
        return self.fakeStats.maxHealth
    end
    return UnitHealthMax(self.unit)
end

function HealUI:GetCurrentPower()
    if self:IsFake() then
        return self.fakeStats.currentPower
    end
    return UnitMana(self.unit)
end

function HealUI:GetMaxPower()
    if self:IsFake() then
        return self.fakeStats.maxPower
    end
    return UnitManaMax(self.unit)
end

function HealUI:ShouldShowMissingHealth()
    local profile = self:GetProfile()
    local currentHealth = self:GetCurrentHealth()
    if currentHealth == 0 then
        return false
    end
    local missingHealth = self:GetMaxHealth() - currentHealth
    return (missingHealth > 0 or profile.AlwaysShowMissingHealth) and profile.MissingHealthDisplay ~= "Hidden" 
                and (profile.ShowEnemyMissingHealth or not self:IsEnemy()) and not UnitIsGhost(self.unit)
end

function HealUI.GetColorizedText(color, class, theText)
    local text = ""
    if color == "Class" then
        local r, g, b = util.GetClassColor(class)
        if r then
            text = text..util.Colorize(theText, r, g, b)
        else
            text = text..theText
        end
    elseif color == "Default" then
        text = text..theText
    elseif type(color) == "table" then
        text = text..util.Colorize(theText, color)
    end
    return text
end

function HealUI:UpdateHealth()
    local fake = self:IsFake()
    if not UnitExists(self.unit) and not fake then
        return
    end
    local profile = self:GetProfile()
    local unit = self.unit

    local fakeOnline = self.fakeStats.online
    
    local currentHealth = self:GetCurrentHealth()
    local maxHealth = self:GetMaxHealth()
    
    local unitName = fake and self.fakeStats.name or UnitName(unit)
    local class = fake and self.fakeStats.class or util.GetClass(unit)

    self:UpdateOpacity() -- May be changed further down

    if not UnitIsConnected(unit) and (not fake or not fakeOnline) then
        self.nameText:SetText(self.GetColorizedText(profile.NameText.Color, class, unitName))
        self.healthText:SetText(util.Colorize("Offline", 0.7, 0.7, 0.7))
        self.missingHealthText:SetText("")
        self.healthBar:SetValue(0)
        self.powerBar:SetValue(0)
        self:UpdateOpacity()
        self:AdjustHealthPosition()
        return
    end

    -- Set Name and its colors
    local nameText
    if UnitIsPlayer(unit) or fake then
        nameText = self.GetColorizedText(profile.NameText.Color, class, unitName)
    else -- Unit is not a player
        if UnitIsEnemy("player", unit) then
            nameText = util.Colorize(unitName, 1, 0.3, 0.3)
        else -- Unit is not an enemy
            nameText = unitName
        end
    end
    self.nameText:SetText(nameText)

    local healthText = self.healthText
    local missingHealthText = self.missingHealthText

    -- Set Health Status
    if currentHealth <= 0 then -- Unit Dead

        local text = util.Colorize("DEAD", 1, 0.3, 0.3)

        -- Check for Feign Death so the healer doesn't get alarmed
        if util.IsFeigning(unit) then
            text = "Feign"
        end

        healthText:SetText(text)
        missingHealthText:SetText("")
        self.healthBar:SetValue(0)
        self.powerBar:SetValue(0)
    elseif UnitIsGhost(unit) then
        healthText:SetText(util.Colorize("Ghost", 1, 0.3, 0.3))
        missingHealthText:SetText("")
        self.healthBar:SetValue(0)
        self.powerBar:SetValue(0)
    else -- Unit Not Dead
        local text = ""
        local missingText = ""
        if profile.HealthDisplay == "Health/Max Health" then
            text = currentHealth.."/"..maxHealth
        elseif profile.HealthDisplay == "Health" then
            text = currentHealth
        elseif profile.HealthDisplay == "% Health" then
            text = math.floor((currentHealth / maxHealth) * 100).."%"
        end
        
        if self.hovered then
            text = util.Colorize(text, 1, 1, 1)
        end

        local missingHealth = math.floor(maxHealth - currentHealth)

        if self:ShouldShowMissingHealth() then
            local missingHealthStr
            if profile.MissingHealthDisplay == "-Health" then
                missingHealthStr = "-"..missingHealth
            elseif profile.MissingHealthDisplay == "-% Health" then
                missingHealthStr = "-"..math.ceil((missingHealth / maxHealth) * 100).."%"
            end

            if profile.MissingHealthInline then
                if text ~= "" then
                    text = text..self.GetColorizedText(profile.HealthTexts.Missing.Color, nil, " ("..missingHealthStr..")")
                end
            else
                missingText = self.GetColorizedText(profile.HealthTexts.Missing.Color, nil, missingHealthStr)
            end
        end

        healthText:SetText(text)
        missingHealthText:SetText(missingText)

        self.healthBar:SetValue(currentHealth / maxHealth)
    end

    self:UpdateOpacity()
    self:AdjustHealthPosition()
end

function HealUI:UpdatePower()
    local profile = self:GetProfile()
    local unit = self.unit
    local powerBar = self.powerBar
    local fake = self:IsFake()
    local class = fake and self.fakeStats.class or util.GetClass(unit)
    local currentPower = self:GetCurrentPower()
    local maxPower = self:GetMaxPower()

    if class == nil then
        return
    end
    
    local powerColor = fake and util.PowerColors[util.ClassPowerTypes[class]] or util.GetPowerColor(unit)

    powerBar:SetValue(currentPower / maxPower)
    powerBar:SetStatusBarColor(powerColor[1], powerColor[2], powerColor[3])
    local text = ""
    if profile.PowerDisplay == "Power" then
        text = currentPower
    elseif profile.PowerDisplay == "Power/Max Power" then
        text = currentPower.."/"..maxPower
    elseif profile.PowerDisplay == "% Power" then
        if maxPower == 0 then
            maxPower = 1
        end
        text = math.floor((currentPower / maxPower) * 100).."%"
    end
    self.powerText:SetText(text)
end

function HealUI:AllocateAura()
    local frame = CreateFrame("Button", nil, self.auraPanel, "UIPanelButtonTemplate")
    frame:SetNormalTexture(nil)
    frame:SetHighlightTexture(nil)
    frame:SetPushedTexture(nil)
    local buttons = HMOptions.CastWhen == "Mouse Up" and util.GetUpButtons() or util.GetDownButtons()
    frame:RegisterForClicks(unpack(buttons))
    frame:EnableMouse(true)
    
    local icon = frame:CreateTexture(nil, "OVERLAY")
    local stackText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stackText:SetTextColor(1, 1, 1)
    return {["frame"] = frame, ["icon"] = icon, ["stackText"] = stackText}
end

-- Get an icon from the available pool. Automatically inserts into the used pool.
function HealUI:GetUnusedAura()
    local aura
    if table.getn(self.auraIconPool) > 0 then
        aura = table.remove(self.auraIconPool, table.getn(self.auraIconPool))
    else
        aura = self:AllocateAura()
    end
    aura.frame:SetAlpha(aura.frame:GetParent():GetAlpha())
    table.insert(self.auraIcons, aura)
    return aura
end

function HealUI:ReleaseAuras()
    if table.getn(self.auraIcons) == 0 then
        return
    end
    -- Release all icons back to the icon pool
    for _, aura in ipairs(self.auraIcons) do
        local frame = aura.frame
        frame:SetScript("OnEnter", nil)
        frame:SetScript("OnLeave", nil)
        frame:SetScript("OnClick", nil)
        frame:SetScript("OnMouseUp", nil)
        frame:SetScript("OnMouseDown", nil)
        frame:Hide()
        frame:ClearAllPoints()

        local icon = aura.icon
        icon:ClearAllPoints()

        local stackText = aura.stackText
        stackText:ClearAllPoints()
        stackText:SetText("")

        table.insert(self.auraIconPool, aura)
    end
    self.auraIcons = {} -- Allocating new table instead of clearing, might be a mistake?
end

function HealUI:UpdateAuras()
    local profile = self:GetProfile()
    local unit = self.unit
    local enemy = self:IsEnemy()

    self:ReleaseAuras()

    if not UnitExists(unit) then
        return
    end

    local cache = self:GetCache()
    
    local trackedBuffs = HealersMateSettings.TrackedBuffs

    local buffs = {} -- Buffs that are tracked because of matching name
    for name, array in pairs(cache.BuffsMap) do
        if trackedBuffs[name] or enemy then
            util.AppendArrayElements(buffs, array)
        end
    end

    if not enemy then
        table.sort(buffs, function(a, b)
            return trackedBuffs[a.name] < trackedBuffs[b.name]
        end)
    end
    

    local trackedDebuffs = HealersMateSettings.TrackedDebuffs
    local trackedDebuffTypes = HealersMateSettings.TrackedDebuffTypesSet

    local debuffs = {} -- Debuffs that are tracked because of matching name, later combined with typed debuffs
    local typedDebuffs = {} -- Debuffs that are tracked because it's a tracked type (like "Magic" or "Disease")
    for name, array in pairs(cache.DebuffsMap) do
        if trackedDebuffs[name] or enemy then
            util.AppendArrayElements(debuffs, array)
        else
            -- Check if debuff is a tracked type
            for _, debuff in ipairs(array) do
                if trackedDebuffTypes[debuff.type] then
                    table.insert(typedDebuffs, debuff)
                end
            end
        end
    end

    if not enemy then
        table.sort(debuffs, function(a, b)
            return trackedDebuffs[a.name] < trackedDebuffs[b.name]
        end)
        util.AppendArrayElements(debuffs, typedDebuffs)
    end

    local auraTrackerProps = profile.AuraTracker
    local width = auraTrackerProps.Width == "Anchor" and auraTrackerProps:GetAnchorComponent(self):GetWidth() or auraTrackerProps.Width
    local auraSize = auraTrackerProps.Height
    local origSize = auraSize
    local spacing = profile.TrackedAurasSpacing
    local origSpacing = spacing
    local auraCount = table.getn(buffs) + table.getn(debuffs)

    -- If there's not enough space, shrink until all auras fit
    while ((auraSize * auraCount) + (spacing * (auraCount - 1)) > width) and auraSize >= 1 do
        auraSize = auraSize - 1
        spacing = (auraSize / origSize) * origSpacing
    end

    local xOffset = 0
    local yOffset = profile.TrackedAurasAlignment == "TOP" and 0 or origSize - auraSize
    for _, buff in ipairs(buffs) do
        local aura = self:GetUnusedAura()
        self:CreateAura(aura, buff.index, buff.texture, buff.stacks, xOffset, -yOffset, "Buff", auraSize)
        xOffset = xOffset + auraSize + spacing
    end
    xOffset = 0
    for _, debuff in ipairs(debuffs) do
        local aura = self:GetUnusedAura()
        self:CreateAura(aura, debuff.index, debuff.texture, debuff.stacks, xOffset, -yOffset, "Debuff", auraSize)
        xOffset = xOffset - auraSize - spacing
    end

    -- Prevent lingering tooltips when the icon is removed or is changed to a different aura
    if not HM.GameTooltip.OwningFrame or not HM.GameTooltip.OwningFrame:IsShown() or 
            HM.GameTooltip.IconTexture ~= HM.GameTooltip.OwningIcon:GetTexture() then
        HM.GameTooltip:Hide()
    end
end

function HealUI:CreateAura(aura, index, texturePath, stacks, xOffset, yOffset, type, size)
    local unit = self.unit

    local frame = aura.frame
    frame:SetWidth(size)
    frame:SetHeight(size)
    frame:SetPoint(type == "Buff" and "TOPLEFT" or "TOPRIGHT", xOffset, yOffset)
    frame:Show()

    local icon = aura.icon
    icon:SetAllPoints(frame)
    icon:SetTexture(texturePath)
    --icon:SetVertexColor(1, 0, 0)

    -- Creates a function that checks if the mouse is over the UI's button and calls the script if so
    local wrapScript = function(scriptName)
        return function()
            if MouseIsOver(self.button) then
                self.button:GetScript(scriptName)()
            end
        end
    end
    
    frame:SetScript("OnEnter", function()
        local tooltip = HM.GameTooltip
        local cache = self:GetCache()
        tooltip:SetOwner(frame, "ANCHOR_BOTTOMLEFT")
        tooltip.OwningFrame = frame
        tooltip.OwningIcon = icon
        if type == "Buff" then
            tooltip.IconTexture = cache.Buffs[index].texture
            tooltip:SetUnitBuff(unit, index)
        else
            tooltip.IconTexture = cache.Debuffs[index].texture
            tooltip:SetUnitDebuff(unit, index)
        end
        tooltip:Show()

        wrapScript("OnEnter")()
    end)
    
    frame:SetScript("OnLeave", function()
        HM.GameTooltip:Hide()
        HM.GameTooltip.OwningFrame = nil
        HM.GameTooltip.OwningIcon = nil
        HM.GameTooltip.IconTexture = nil
        -- Don't check mouse position for leaving, because it could cause the tooltip to stay if the icon is on the edge
        self.button:GetScript("OnLeave")()
    end)

    frame:SetScript("OnClick", wrapScript("OnClick"))

    frame:SetScript("OnMouseUp", wrapScript("OnMouseUp"))

    frame:SetScript("OnMouseDown", wrapScript("OnMouseDown"))
    
    if stacks > 1 then
        local stackText = aura.stackText
        stackText:SetPoint("CENTER", frame, "CENTER", 0, 0)
        stackText:SetFont("Fonts\\FRIZQT__.TTF", math.ceil(size * (stacks < 10 and 0.75 or 0.6)))
        stackText:SetText(stacks)
    end
end

function HealUI:SetHealth(health)
    self.healthBar:SetValue(health)
end

function HealUI:Initialize()
    local unit = self.unit

    local profile = self:GetProfile()

    -- Container Elements

    local rootContainer = CreateFrame("Frame", unit.."HealRootContainer", UIParent)
    self.rootContainer = rootContainer
    rootContainer:SetPoint("CENTER", 0, 0)

    local container = CreateFrame("Frame", unit.."HealContainer", rootContainer) --type, name, parent
    self.container = container
    container:SetAllPoints(rootContainer)

    local overlayContainer = CreateFrame("Frame", unit.."HealOverlayContainer", rootContainer)
    self.overlayContainer = overlayContainer
    overlayContainer:SetFrameLevel(container:GetFrameLevel() + 5)
    overlayContainer:SetAllPoints(rootContainer)

    -- Distance Text

    local distanceText = overlayContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.distanceText = distanceText
    distanceText:SetAlpha(profile.RangeText:GetAlpha())

    local losFrame = CreateFrame("Frame", nil, container)
    losFrame:SetFrameLevel(container:GetFrameLevel() + 3)
    local losIcon = losFrame:CreateTexture(nil, "OVERLAY")
    self.lineOfSightIcon = {frame = losFrame, icon = losIcon}
    losIcon:SetTexture("Interface\\Icons\\Spell_nature_sleep")
    losIcon:SetAlpha(profile.LineOfSightIcon:GetAlpha())
    losFrame:Hide()

    -- Role Icon

    local roleFrame = CreateFrame("Frame", nil, container)
    roleFrame:SetFrameLevel(container:GetFrameLevel() + 3)
    local roleIcon = roleFrame:CreateTexture(nil, "OVERLAY")
    self.roleIcon = {frame = roleFrame, icon = roleIcon}
    roleIcon:SetAlpha(profile.RoleIcon:GetAlpha())
    roleFrame:Hide()

    -- Health Bar Element

    local incomingHealthBar = CreateFrame("StatusBar", unit.."IncomingHealthBar", container)
    self.incomingHealthBar = incomingHealthBar
    incomingHealthBar:SetStatusBarTexture(HM.BarStyles[profile.HealthBarStyle])
    incomingHealthBar:SetMinMaxValues(0, 1)
    incomingHealthBar:SetAlpha(0.5)

    local healthBar = CreateFrame("StatusBar", unit.."HealthBar", container)
    self.healthBar = healthBar
    healthBar:SetStatusBarTexture(HM.BarStyles[profile.HealthBarStyle])
    healthBar:SetMinMaxValues(0, 1)

    -- Name Element

    local name = healthBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.nameText = name
    name:SetAlpha(profile.NameText:GetAlpha())

    -- Create a background texture for the status bar
    local bg = healthBar:CreateTexture(nil, "BACKGROUND")
    healthBar.background = bg
    bg:SetAllPoints(true)
    bg:SetTexture(0.5, 0.5, 0.5, 0.25) -- set color to light gray with high transparency

    -- Incoming Text
    local incomingHealText = overlayContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.incomingHealText = incomingHealText
    incomingHealText:SetTextColor(0.5, 1, 0.5)

    local origSetValue = healthBar.SetValue
    --local greenToRedColors = {{1, 0, 0}, {1, 1, 0}, {0, 0.753, 0}}
    local greenToRedColors = {{1, 0, 0}, {1, 0.3, 0}, {1, 1, 0}, {0.6, 0.92, 0}, {0, 0.8, 0}}
    local greenToOverhealColors = {{0, 0.8, 0}, {0.2, 1, 0.2}}
    healthBar.SetValue = function(healthBarSelf, value)
        origSetValue(healthBarSelf, value)
        local healthIncMaxRatio = 0
        if self.incomingHealing > 0 then
            healthIncMaxRatio = value + (self.incomingHealing / self:GetMaxHealth())
            incomingHealthBar:SetValue(healthIncMaxRatio)
            if profile.IncomingHealDisplay == "Overheal" then
                if healthIncMaxRatio > 1 then
                    incomingHealText:SetText("+"..math.ceil(self:GetCurrentHealth() + self.incomingHealing - self:GetMaxHealth()))
                else
                    incomingHealText:SetText("")
                end
            elseif profile.IncomingHealDisplay == "Heal" then
                incomingHealText:SetText("+"..self.incomingHealing)
            else
                incomingHealText:SetText("")
            end
        else
            incomingHealthBar:SetValue(0)
            incomingHealText:SetText("")
        end
        incomingHealthBar:SetAlpha(0.5)
        local rgb

        local profile = self:GetProfile()

        local enemy = self:IsEnemy()
        if not enemy then -- Do not display debuff colors for enemies
            for _, trackedDebuffType in ipairs(HealersMateSettings.TrackedDebuffTypes) do
                if self:GetAfflictedDebuffTypes()[trackedDebuffType] then
                    rgb = HealersMateSettings.DebuffTypeColors[trackedDebuffType]
                    break
                end
            end
        end

        local fake = self:IsFake()
        if fake and self.fakeStats.debuffType then
            rgb = HealersMateSettings.DebuffTypeColors[self.fakeStats.debuffType]
        end
        
        if rgb == nil then -- If there's no debuff color, proceed to normal colors
            local hbc = enemy and profile.EnemyHealthBarColor or profile.HealthBarColor
            if hbc == "Class" then
                local class = util.GetClass(unit)
                if class == nil then
                    class = self.fakeStats.class
                end
                local r, g, b = util.GetClassColor(class)
                rgb = {r, g, b}
            elseif hbc == "Green" then
                if healthIncMaxRatio > 1 and value == 1 then
                    rgb = util.InterpolateColors(greenToOverhealColors, math.min(healthIncMaxRatio - 1, 1))
                else
                    rgb = {0, 0.8, 0}
                end
            elseif hbc == "Green To Red" then
                if healthIncMaxRatio > 1 and value == 1 then
                    rgb = util.InterpolateColors(greenToOverhealColors, math.min(healthIncMaxRatio - 1, 1))
                else
                    rgb = util.InterpolateColors(greenToRedColors, value)
                end
            end
        end
        healthBar:SetStatusBarColor(rgb[1], rgb[2], rgb[3])
        incomingHealthBar:SetStatusBarColor(rgb[1], rgb[2], rgb[3])

        if value == 0 then
            bg:SetTexture(0.5, 0.5, 0.5, 0.5)
        elseif value < 0.3 and not enemy then
            bg:SetTexture(1, 0.4, 0.4, 0.25)
        else
            bg:SetTexture(0.5, 0.5, 0.5, 0.25)
        end
    end
    healthBar:SetValue(1)

    -- Missing Health Text

    local missingHealthText = healthBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.missingHealthText = missingHealthText
    missingHealthText:SetAlpha(profile.HealthTexts.Missing:GetAlpha())

    -- Power Bar Element

    local powerBar = CreateFrame("StatusBar", unit.."PowerStatusBar", container)
    self.powerBar = powerBar
    powerBar:SetStatusBarTexture(HM.BarStyles[profile.PowerBarStyle])
    powerBar:SetMinMaxValues(0, 1)
    powerBar:SetValue(1)
    powerBar:SetStatusBarColor(0, 0, 1)
    powerBar:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background"}) -- set a light gray background
    local powerText = powerBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.powerText = powerText
    powerText:SetAlpha(profile.PowerText:GetAlpha())

    -- Button Element

    local button = CreateFrame("Button", unit.."Button", healthBar, "UIPanelButtonTemplate")
    self.button = button
    local healthText = button:GetFontString()
    self.healthText = healthText
    healthText:ClearAllPoints()


    healthText = healthBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.healthText = healthText

    self:RegisterClicks()
    button:SetScript("OnClick", function()
        local buttonType = arg1
        HM.ClickHandler(buttonType, unit, self)
    end)
    button:SetScript("OnMouseDown", function()
        local buttonType = arg1
        HM.CurrentlyHeldButton = HealersMateSettings.CustomButtonNames[buttonType] or HM.ReadableButtonMap[buttonType]
        HM.ReapplySpellsTooltip()
        self.pressed = true
        self:AdjustHealthPosition()
    end)
    button:SetScript("OnMouseUp", function()
        HM.CurrentlyHeldButton = nil
        HM.ReapplySpellsTooltip()
        self.pressed = false
        self:AdjustHealthPosition()
    end)
    button:SetScript("OnEnter", function()
        HM.ApplySpellsTooltip(button, unit)
        self.hovered = true
        self:UpdateHealth()
        if HMOptions.SetMouseover and util.IsSuperWowPresent() then
            SetMouseoverUnit(unit)
        end
    end)
    button:SetScript("OnLeave", function()
        HM.HideSpellsTooltip()
        self.hovered = false
        self:UpdateHealth()
        if HMOptions.SetMouseover and util.IsSuperWowPresent() then
            SetMouseoverUnit(nil)
        end
    end)
    button:EnableMouse(true)

    button:SetNormalTexture(nil)
    button:SetHighlightTexture(nil)
    button:SetPushedTexture(nil)

    -- Buff Panel Element

    local buffPanel = CreateFrame("Frame", unit.."BuffPanel", container)
    self.auraPanel = buffPanel
    buffPanel:SetFrameLevel(container:GetFrameLevel() + 2)

    --[[
    local scrollingDamageFrame = CreateFrame("Frame", unit.."ScrollingDamageFrame", container)
    self.scrollingDamageFrame = scrollingDamageFrame
    scrollingDamageFrame:SetWidth(100) -- width
    scrollingDamageFrame:SetHeight(20) -- height
    scrollingDamageFrame:SetPoint("CENTER", 0, 0) -- Adjust the initial position as needed
    scrollingDamageFrame.text = scrollingDamageFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scrollingDamageFrame.text:SetPoint("CENTER", 0, 0)
    scrollingDamageFrame:Hide() -- Hide the frame initially
    scrollingDamageFrame:SetFrameLevel(100) -- Set the frame level to a high value to ensure it's on top

    local scrollingHealFrame = CreateFrame("Frame", unit.."ScrollingHealFrame", container)
    self.scrollingHealFrame = scrollingHealFrame
    scrollingHealFrame:SetWidth(100) -- width
    scrollingHealFrame:SetHeight(20) -- height
    scrollingHealFrame:SetPoint("CENTER", 0, 0) -- Adjust the initial position as needed
    scrollingHealFrame.text = scrollingHealFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scrollingHealFrame.text:SetPoint("CENTER", 0, 0)
    scrollingHealFrame:Hide() -- Hide the frame initially
    scrollingHealFrame:SetFrameLevel(100) -- Set the frame level to a high value to ensure it's on top
    ]]

    self:SizeElements()
end

function HealUI:SizeElements()
    local profile = self:GetProfile()
    local width = profile.Width
    local healthBarHeight = profile.HealthBarHeight
    local powerBarHeight = profile.PowerBarHeight

    local rootContainer = self.rootContainer
    rootContainer:SetWidth(width)

    local overlayContainer = self.overlayContainer
    overlayContainer:SetWidth(width)

    local container = self.container
    container:SetWidth(width)

    local healthBar = self.healthBar
    healthBar:SetWidth(width)
    healthBar:SetHeight(healthBarHeight)
    healthBar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -profile.PaddingTop)

    local incomingHealthBar = self.incomingHealthBar
    incomingHealthBar:SetWidth(width)
    incomingHealthBar:SetHeight(healthBarHeight)
    incomingHealthBar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -profile.PaddingTop)

    local powerBar = self.powerBar
    powerBar:SetWidth(width)
    powerBar:SetHeight(powerBarHeight)
    powerBar:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", 0, 0)

    local button = self.button
    button:SetWidth(healthBar:GetWidth())
    button:SetHeight(healthBar:GetHeight() + powerBar:GetHeight())
    button:SetPoint("TOP", 0, 0)

    local name = self.nameText
    self:UpdateComponent(name, profile.NameText)

    self:AdjustHealthPosition()

    local powerText = self.powerText
    self:UpdateComponent(powerText, profile.PowerText)

    local incomingHealText = self.incomingHealText
    self:UpdateComponent(incomingHealText, profile.IncomingHealText)

    local distanceText = self.distanceText
    self:UpdateComponent(distanceText, profile.RangeText)

    local losFrame = self.lineOfSightIcon.frame
    self:UpdateComponent(self.lineOfSightIcon.frame, profile.LineOfSightIcon)

    local losIcon = self.lineOfSightIcon.icon
    losIcon:SetAllPoints(losFrame)

    local roleFrame = self.roleIcon.frame
    self:UpdateComponent(self.roleIcon.frame, profile.RoleIcon)

    local roleIcon = self.roleIcon.icon
    roleIcon:SetAllPoints(roleFrame)

    local auraPanel = self.auraPanel
    self:UpdateComponent(auraPanel, profile.AuraTracker)

    rootContainer:SetHeight(self:GetHeight())
    overlayContainer:SetHeight(self:GetHeight())
    container:SetHeight(self:GetHeight())
end

function HealUI:AdjustHealthPosition()
    local profile = self:GetProfile()

    local healthTexts = profile.HealthTexts
    local healthTextProps = (self:ShouldShowMissingHealth() and not profile.MissingHealthInline) and 
        healthTexts.WithMissing or healthTexts.Normal
    local missingHealthTextProps = healthTexts.Missing

    local xOffset, yOffset
    if self.pressed then
        xOffset, yOffset = 1, -1
    end
    self:UpdateComponent(self.healthText, healthTextProps, xOffset, yOffset)
    self:UpdateComponent(self.missingHealthText, missingHealthTextProps, xOffset, yOffset)
end

local alignmentAnchorMap = {
    ["LEFT"] = {
        ["TOP"] = "TOPLEFT",
        ["CENTER"] = "LEFT",
        ["BOTTOM"] = "BOTTOMLEFT",
    },
    ["CENTER"] = {
        ["TOP"] = "TOP",
        ["CENTER"] = "CENTER",
        ["BOTTOM"] = "BOTTOM",
    },
    ["RIGHT"] = {
        ["TOP"] = "TOPRIGHT",
        ["CENTER"] = "RIGHT",
        ["BOTTOM"] = "BOTTOMRIGHT",
    }
}
function HealUI:UpdateComponent(component, props, xOffset, yOffset)
    xOffset = xOffset or 0
    yOffset = yOffset or 0

    local anchor = props:GetAnchorComponent(self)

    component:ClearAllPoints()
    if component.SetFont then -- Must be a FontString
        component:SetWidth(math.min(props.MaxWidth, anchor:GetWidth()))
        component:SetHeight(props.FontSize * 1.25)
        component:SetFont("Fonts\\FRIZQT__.TTF", props.FontSize, props.Outline and "OUTLINE" or nil)
        if props.Outline then
            component:SetShadowOffset(0, 0)
        end
        component:SetJustifyH(props.AlignmentH)
        component:SetJustifyV(props.AlignmentV)
    else
        component:SetWidth(props.Width == "Anchor" and anchor:GetWidth() or props.Width)
        component:SetHeight(props.Height == "Anchor" and anchor:GetHeight() or props.Height)
    end
    local alignment = alignmentAnchorMap[props.AlignmentH][props.AlignmentV]
    component:SetPoint(alignment, anchor, alignment, props:GetOffsetX() + xOffset, props:GetOffsetY() + yOffset)
end

function HealUI:GetCache()
    return HMUnit.Get(self.unit)
end

function HealUI:GetAfflictedDebuffTypes()
    return self:GetCache().AfflictedDebuffTypes
end

function HealUI:GetWidth()
    return self:GetProfile().Width
end

function HealUI:GetHeight()
    return self:GetProfile():GetHeight()
end

function HealUI:IsPlayer()
    return UnitIsPlayer(self.unit)
end

function HealUI:IsEnemy()
    return UnitCanAttack("player", self.unit)
end

function HealUI:IsFake()
    return HealersMate.TestUI and not UnitExists(self.unit)
end

function HealUI:GetRole()
    return HealersMate.GetUnitAssignedRole(self:GetUnit())
end

local roleTexturesPath = HMUtil.GetAssetsPath().."textures\\roles\\"
local roleTextures = {
    ["Tank"] = roleTexturesPath.."Tank",
    ["Healer"] = roleTexturesPath.."Healer",
    ["Damage"] = roleTexturesPath.."Damage"
}
function HealUI:UpdateRole()
    local role = self:GetRole()
    self.roleIcon.icon:SetTexture(roleTextures[role])
    if role then
        self.roleIcon.frame:Show()
    else
        self.roleIcon.frame:Hide()
    end
end

function HealUI:GetProfile()
    return self.owningGroup:GetProfile()
end
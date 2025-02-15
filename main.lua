---@class OnlyDriveThru : ModModule
local M = {
    Author = "TontonSamael",
    Version = 1,

    -- CONSTANTS
    RESTAURANT_CLOSED = 7,
    PAPER_BAGS_ID = 1027,

    -- DATA
    Enabled = false,
}

local function TogglePaperBagsMinimumLevel()
    local marketProducts = FindAllOf("W_App_Market_Product_C") or {}
    for _, p in ipairs(marketProducts) do
        ---@class UW_App_Market_Product_C
        p = p
        if type(p.ProductId.ToString) == "function" then
            local id = tonumber(p.ProductId:ToString())
            if id == M.PAPER_BAGS_ID then
                p:SetProductId(p.ProductId, not M.Enabled, false)
            end
        end
    end
end

---@param ModManager ModManager
local function OnEnable(ModManager)
    ModManager.GameState.DriveThruRequiredLevel = 1
    ModManager.GameState.bDriveThruActive = true
end

---@param ModManager ModManager
local function OnDisable(ModManager)
    if ModManager.GameState:IsValid() then
        ModManager.GameState.DriveThruRequiredLevel = 15
        if ModManager.GameState.RestaurantLevel < 15 then
            ModManager.GameState.bDriveThruActive = false
        end
    end
end

---@param ModManager ModManager
---@param State boolean
---@param Ar any
local function Toggle(ModManager, State, Ar)
    local updated = false
    if State and not M.Enabled then
        M.Enabled = true
        OnEnable(ModManager)
        updated = true
    elseif not State and M.Enabled then
        M.Enabled = false
        OnDisable(ModManager)
        updated = true
    end
    if updated then
        TogglePaperBagsMinimumLevel()
        Log(M, LOG.INFO, string.format("OnlyDriveThru %s", M.Enabled and "enabled" or "disabled"), Ar)
    end
end

---@param ModManager ModManager
local function InitHooks(ModManager)
    ModManager.AddHook(M, "ShouldSpawnCustomer",
        "/Game/Blueprints/Gameplay/CustomerQueue/BP_CustomerManager.BP_CustomerManager_C:ShouldSpawnCustomer",
        function(M2, CustomerManager, bReturnValue)
            bReturnValue:set(false)
        end,
        function()
            return M.Enabled
        end)

    ModManager.AddHook(M, "GenerateDriveThruSpawnCooldown",
        "/Game/Blueprints/Gameplay/CustomerQueue/BP_CustomerManager.BP_CustomerManager_C:GenerateDriveThruSpawnCooldown",
        function(M2, CustomerManager)
            local cooldown = CustomerManager:get():GenerateSpawnCooldown()
            Log(M, LOG.INFO, string.format("Set drive-thru customer cooldown to ped cooldown %f", cooldown))
            return cooldown
        end,
        function()
            return M.Enabled
        end)

    ModManager.AddHook(M, "OnSetIsRestaurantRunning",
        "/Game/Blueprints/GameMode/GameState/BP_BakeryGameState_Ingame.BP_BakeryGameState_Ingame_C:SetIsRestaurantRunning",
        function(M2, GameState, openState)
            ---@type ABP_CustomerManager_C
            local CustomerManager = FindFirstOf("BP_CustomerManager_C")
            if openState:get() and CustomerManager:IsValid() then
                Log(M, LOG.INFO, string.format("On restaurant open : removed %d customers", #CustomerManager.Customers))
                GameState:get().EndOfDayReport.TotalCustomers_20_164D80064BC6096F4B5A32829F380F30 = 0
                CustomerManager:RemoveAllCustomers()
            end
        end,
        function()
            return M.Enabled
        end)

    ModManager.AddHook(M, "OnSetDriveThruActive",
        "/Game/Blueprints/GameMode/GameState/BP_BakeryGameState_Ingame.BP_BakeryGameState_Ingame_C:SetDriveThruActive",
        function(M2, GameState, driveState)
            if not driveState:get() then
                GameState:get():SetDriveThruActive(true)
            end
        end,
        function()
            return M.Enabled
        end)

    ModManager.AddHook(M, "OnMainMenuConfirmation",
        "/Game/UI/Ingame/EscapeMenu/W_EscapeMenu.W_EscapeMenu_C:OnMainMenuConfirmation",
        function(M2, EscapeMenu, bConfirmed)
            if bConfirmed:get() then
                Toggle(ModManager, false)
            end
        end,
        function()
            return M.Enabled
        end)

    ModManager.AddHook(M, "LoadProducts",
        "/Game/UI/Ingame/Computer/Application/Market/W_App_Market.W_App_Market_C:LoadProducts",
        function()
            ExecuteWithDelay(100, function()
                TogglePaperBagsMinimumLevel()
            end)
        end,
        function()
            return M.Enabled
        end)

    ModManager.AddHook(M, "HasProductLevelLimit",
        "/Game/Blueprints/GameMode/GameState/BP_BakeryGameState_Ingame.BP_BakeryGameState_Ingame_C:HasProductLevelLimit",
        function(M2, GameState, ProductTag, bReturnValue)
            if ProductTag:get().TagName:ToString():find("PaperBag") then
                bReturnValue:set(false)
            end
        end,
        function()
            return M.Enabled
        end)
end

---@param ModManager ModManager
---@param Parameters string[]
---@param Ar any
local function ToggleCommand(ModManager, Parameters, Ar)
    if ModManager.AppState == APP_STATES.IN_GAME then
        if not ModManager.IsHost then
            Log(M, LOG.INFO, "You must own the restaurant to enable OnlyDriveThru !", Ar)
            Toggle(ModManager, false, Ar)
            return
        elseif ModManager.GameState.bIsRestaurantRunning then
            -- already running
            Log(M, LOG.INFO, "You cannot toggle OnlyDriveThru after the restaurant opening !", Ar)
            return
        end
    else
        Log(M, LOG.INFO, "You must be in a lobby to enable OnlyDriveThru !", Ar)
        Toggle(ModManager, false, Ar)
        return
    end

    Toggle(ModManager, not M.Enabled, Ar)
end

---@param ModManager ModManager
function M.Init(ModManager)
    InitHooks(ModManager)

    ModManager.AddCommand(M, "onlydrivethru", ToggleCommand)

    -- detect already enabled after a mod reload
    if ModManager.AppState == APP_STATES.IN_GAME and ModManager.GameState.DriveThruRequiredLevel == 1 then
        Log(M, LOG.INFO, "Detected OnlyDriveThru previous enabled state !")
        Toggle(ModManager, true)
    end
end

function M.AppStateChanged(ModManager, State)
    if M.Enabled and State == APP_STATES.MAIN_MENU then
        Toggle(ModManager, false)
    end
end

return M

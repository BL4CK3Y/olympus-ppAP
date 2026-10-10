
pcall(function()
    if _G.__Lolbeans67APNoCrash and _G.__Lolbeans67APNoCrash.Cleanup then
        _G.__Lolbeans67APNoCrash:Cleanup()
    end
end)

local NoCrashState = {
    Alive = true,
    Connections = {},
    Drawings = {},
    HealthEntries = {},
    OpponentHpEnabled = false,
    PersonalHpEnabled = false,
    TargetMarkerEnabled = true,
    CombatEspEnabled = false,   -- name / range box (off by default — was the noisy ESP)
    AnimDebugEspEnabled = false, -- full anim ID / timing dump (debug only)
    HpViewRange = 75,
    LastOverlayUpdate = 0,
}
_G.__Lolbeans67APNoCrash = NoCrashState

function NoCrashState:AddConnection(connection)
    if connection then
        table.insert(self.Connections, connection)
    end
    return connection
end

function NoCrashState:AddDrawing(kind)
    local ok, drawing = pcall(function()
        return Drawing.new(kind)
    end)
    if ok and drawing then
        table.insert(self.Drawings, drawing)
        return drawing
    end
end

function NoCrashState:Cleanup()
    self.Alive = false
    if self.ClearEspTrackers then
        pcall(self.ClearEspTrackers)
    end
    for _, connection in ipairs(self.Connections or {}) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(self.Connections or {})
    for _, drawing in ipairs(self.Drawings or {}) do
        pcall(function() drawing:Remove() end)
    end
    table.clear(self.Drawings or {})
end

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local UIS = game:GetService("UserInputService")
local SelectedFolder = nil
local CycleKeybind = Enum.KeyCode.X

local ESP_Utility = loadstring(game:HttpGet("https://raw.githubusercontent.com/artxficial/matchastuff/main/esp_utility.lua"))() or ESP_Utility
local AnimationTrackerClass = loadstring(game:HttpGet("https://raw.githubusercontent.com/artxficial/matchastuff/main/animationtracker.lua"))() or AnimationTracker

-- Harden AnimationTracker: library prints "Failed to resolve Animator." and returns nil
-- when Character/Animator.Address is missing (common mid-stream / Matcha lag).
-- Wrap Update so we never spam console and never leave callers with nil.
do
    local rawUpdate = AnimationTrackerClass and AnimationTrackerClass.Update
    if type(rawUpdate) == "function" then
        local function instanceAddress(inst)
            if not inst then return nil end
            -- Instances are userdata — never rawget them
            local a
            local okA, vA = pcall(function() return inst.Address end)
            if okA and type(vA) == "number" and vA ~= 0 then return vA end
            if type(getaddress) == "function" then
                local ok, v = pcall(getaddress, inst)
                if ok and type(v) == "number" and v ~= 0 then return v end
            end
            if type(get_address) == "function" then
                local ok, v = pcall(get_address, inst)
                if ok and type(v) == "number" and v ~= 0 then return v end
            end
            return nil
        end

        function AnimationTrackerClass:Update(character)
            if not character or character.Parent == nil then return {} end
            local hum = character:FindFirstChildOfClass("Humanoid")
                or character:FindFirstChildWhichIsA("Humanoid")
            if not hum or hum.Health <= 0 then return {} end
            local animator = hum:FindFirstChildOfClass("Animator")
                or hum:FindFirstChildWhichIsA("Animator")
            if not animator then return {} end

            -- Silence library's "Failed to resolve Animator." (Address lag / missing)
            local oldPrint = print
            print = function(msg, ...)
                if type(msg) == "string" and string.find(msg, "Failed to resolve Animator", 1, true) then
                    return
                end
                return oldPrint(msg, ...)
            end
            local ok, result = pcall(rawUpdate, self, character)
            print = oldPrint
            if not ok then return {} end
            return result or {}
        end
    end
end

local UI_Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/artxficial/INS-ui/main/uilib.min.lua"))() or INSui

-- Red accent (Syndicatus-style)
pcall(function()
    if UI_Library and UI_Library.SetAccent then
        UI_Library:SetAccent(Color3.fromRGB(210, 40, 40))
    end
end)

local AnimationsLoggedCache = {}
local AnimationsLoggedOrder = {}


-- ==========================================
-- Game Configuration
-- ==========================================

local GameName = "Gakuran"

local GameConfig = {
    ["KarateAnims"] = {
        ["rbxassetid://136346659171696"] = {
            DisplayName = "1stM1",
            ReactionTime = 0.15,
        },
        ["rbxassetid://137514920199894"] = {
            DisplayName = "2ndM1",
            ReactionTime = 0.15,
        },
        ["rbxassetid://72779501873271"] = {
            DisplayName = "3rdM1",
            ReactionTime = 0.15,
        },
        ["rbxassetid://127487637547915"] = {
            DisplayName = "4thM1",
            ReactionTime = 0.15,
        },
        ["rbxassetid://116278224437295"] = { DisplayName = "M2", ReactionTime = 0.3 },
        ["rbxassetid://96466099895892"] = {
            DisplayName = "M2",
            ReactionTime = 0.3,
        },
    },
    ["AliAnims"] = {
        ["rbxassetid://103211517133243"] = {
            DisplayName = "1stM1",
            ["ReactionTime"] = 0.12,
        },
        ["rbxassetid://88548871262625"] = {
            DisplayName = "2ndM1",
            ["ReactionTime"] = 0.17,
        },
        ["rbxassetid://104356393941647"] = {
            DisplayName = "3rdM1",
            ["ReactionTime"] = 0.21,
        },
        ["rbxassetid://109925400698635"] = {
            DisplayName = "4thM1",
            ["ReactionTime"] = 0.11,
        },
        ["rbxassetid://92831721340116"] = {
            DisplayName = "M2",
            ReactionTime = 0.34,
        },
        ["rbxassetid://81488798354194"] = {
            DisplayName = "M2Right",
            ReactionTime = 0.34,
        },
    },
    ["BasicAnims"] = {
        ["rbxassetid://100661797632126"] = {
            DisplayName = "1stM1"
        },
        ["rbxassetid://117315538657801"] = {
            DisplayName = "2ndM1"
        },
        ["rbxassetid://83771012317903"] = {
            DisplayName = "3rdM1"
        },
        ["rbxassetid://129031831390386"] = {
            DisplayName = "4thM1"
        },
        ["rbxassetid://80331331149375"] = {
            DisplayName = "M2",
            ReactionTime = 0.3,
        },
        ["M1Time"] = 0.14,
    },
    ["WrestlingAnims"] = {
        ["rbxassetid://74020075116139"] = {
            DisplayName = "4thM1",
        },
        ["rbxassetid://91419261625463"] = {
            DisplayName = "M2",
            ReactionTime = 0.3,
        },
        ["rbxassetid://124808151650835"] = {
            DisplayName = "1stM1",
        },
        ["rbxassetid://79996486219181"] = {
            DisplayName = "2ndM1",
        },
        ["rbxassetid://115207134396914"] = {
            DisplayName = "3rdM1",
        },
        ["M1Time"] = 0.15,

    },
    ["MuayThaiAnims"] = {
        ["rbxassetid://137299369381761"] = { DisplayName = "M2", ReactionTime = 0.3 },
        ["rbxassetid://74462376752922"] = {
            DisplayName = "M2",
            ReactionTime = 0.3,
        },
        ["rbxassetid://90445272780399"] = {
            DisplayName = "4thM1",
            ParryTime = 0.08,
        },
        ["rbxassetid://103717575086418"] = {
            DisplayName = "3rdM1",
            ParryTime = 0.08,
        },
        ["rbxassetid://136830198456192"] = {
            DisplayName = "2ndM1",
            ParryTime = 0.08,
            
        },
        ["rbxassetid://110917888708142"] = {
            DisplayName = "1stM1",
            ParryTime = 0.08,
        },
        ["M1Time"] = 0.1,        
    },
    ["BoxingAnims"] = {
        ["rbxassetid://132913269853139"] = {
            DisplayName = "1stM1",
            ReactionTime = 0.17,
        },
        ["rbxassetid://76033376851583"] = {
            DisplayName = "2ndM1",
            ReactionTime = 0.17,
        },
        ["rbxassetid://126463147281440"] = {
            DisplayName = "3rdM1",
            ReactionTime = 0.17,
            
        },
        ["rbxassetid://75666664304014"] = {
            DisplayName = "4thM1",
            ReactionTime = 0.17,
        },
        ["rbxassetid://128921678079615"] = {
            DisplayName = "M2",
            ReactionTime = 0.40,
            BoxingM2 = true,
            -- Syndicatus sequence: wait → block hold → optional dodge
            ParryFunction = function(data)
                if not CFG.AutoBoxingM2 then return end
                if data.RegistryData and data.RegistryData.Processed then return end
                if data.RegistryData then data.RegistryData.Processed = true end
                task.spawn(function()
                    task.wait(0.40)
                    BlockStart(os.clock(), 0.50)
                    if CFG.AutoDodge then
                        task.wait(0.30)
                        Dodge(true) -- force: part of Boxing M2 sequence
                    end
                end)
            end,
        },
    },
    ["HakariAnims"] = {
        ["rbxassetid://82855179231529"] = {
            DisplayName = "MomentumM2"
        },
        ["rbxassetid://123215666398014"] = {
            DisplayName = "1stM1",
            ReactionTime = 0.15,
        },
        ["rbxassetid://100249628136368"] = {
            DisplayName = "2ndM1",
            ReactionTime = 0.17,
        },
        ["rbxassetid://101160496635774"] = {
            DisplayName = "3rdM1",
            ReactionTime = 0.15,
        },
        ["rbxassetid://76458394174684"] = {
            DisplayName = "4thM1",
            ReactionTime = 0.21,
        },
        ["rbxassetid://78127273702521"] = {
            DisplayName = "M2",
            ReactionTime = 0.19,
        },
    },
    ["CapoeiraAnims"] = {
        ["rbxassetid://91953931348325"] = {
            DisplayName = "1stM1",
            ReactionTime = 0.15,
        },
        ["rbxassetid://127465095270110"] = {
            DisplayName = "2ndM1",
            ReactionTime = 0.22,
        },
        ["rbxassetid://79017113400162"] = {
            DisplayName = "3rdM1",
            ReactionTime = 0.16,
        },
        ["rbxassetid://98872276178039"] = {
            DisplayName = "4thM1",
            ReactionTime = 0.16,
        },
        ["rbxassetid://101740002500802"] = {
            DisplayName = "M2",
            ReactionTime = 0.32,
        }
    },
    ["SluggerAnims"] = {
        ["rbxassetid://78852386182257"] = {
            DisplayName = "1stM1",
            ReactionTime = 0.24,
        },
        ["rbxassetid://89706363973188"] = {
            DisplayName = "2ndM1",
            ReactionTime = 0.22,
        },
        ["rbxassetid://127941398150401"] = {
            DisplayName = "3rdM1",
            ReactionTime = 0.22
        },
        ["rbxassetid://97696355281722"] = {
            DisplayName = "4thM1",
            ReactionTime = 0.19,
        },
        ["rbxassetid://86882821333237"] = {
            DisplayName = "M2",
            ReactionTime = 0.65,
        }
    },
    ["StrikerAnims"] = {
        ["rbxassetid://79224782278508"] = {
            DisplayName = "1stM1"
        },
        ["rbxassetid://74337052553355"] = {
            DisplayName = "2ndM1"
        },
        ["rbxassetid://121264916189386"] = {
            DisplayName = "3rdM1"
        },
        ["rbxassetid://125556631043249"] = {
            DisplayName = "4thM1"
        },
        ["rbxassetid://128600830397859"] = {
            DisplayName = "M2"
        },
        ["rbxassetid://132840225082238"] = {
            DisplayName = "1stM1"
        },
        ["rbxassetid://88761422474765"] = {
            DisplayName = "2ndM1"
        },
        ["rbxassetid://98462236639320"] = {
            DisplayName = "3rdM1"
        },
        ["rbxassetid://122451562066756"] = {
            DisplayName = "4thM1"
        },
        -- Current Striker animations, calibrated as the progressively faster chain.
        ["rbxassetid://116642061934550"] = { DisplayName = "1stM1", ReactionTime = 0.20 },
        ["rbxassetid://115234849770695"] = { DisplayName = "2ndM1", ReactionTime = 0.18 },
        ["rbxassetid://85554794950365"] = { DisplayName = "3rdM1", ReactionTime = 0.05 },
        ["rbxassetid://73777821288331"] = { DisplayName = "4thM1", ReactionTime = 0.05 },
        ["rbxassetid://99309341097380"] = { DisplayName = "M2", ReactionTime = 0.30 },
    },
    ["KickboxingAnims"] = {
        ["rbxassetid://127679697578124"] = { DisplayName = "1stM1", ReactionTime = 0.17 },
        ["rbxassetid://111648334200984"] = { DisplayName = "2ndM1", ReactionTime = 0.18 },
        ["rbxassetid://109134308246065"] = { DisplayName = "3rdM1", ReactionTime = 0.19 },
        ["rbxassetid://123237866254734"] = { DisplayName = "4thM1", ReactionTime = 0.242 },
        ["rbxassetid://119415047601579"] = { DisplayName = "M2", ReactionTime = 0.287 },
    },
    ["KyokushinAnims"] = {
        -- Latest Kyokushin values supplied by you.
        ["rbxassetid://108157433609067"] = { DisplayName = "1stM1", ReactionTime = 0.10 },
        ["rbxassetid://139691512657916"] = { DisplayName = "2ndM1", ReactionTime = 0.10 },
        ["rbxassetid://94267870513016"] = { DisplayName = "3rdM1", ReactionTime = 0.14 },
        ["rbxassetid://107365196082362"] = { DisplayName = "4thM1", ReactionTime = 0.24 },
        ["rbxassetid://128363063231486"] = { DisplayName = "M2", ReactionTime = 0.25 },
    },
    ["CQCAnims"] = {
        -- CQC has multiple M2 tracks, so each variation is registered separately.
        ["rbxassetid://115957047639796"] = { DisplayName = "1stM1", ReactionTime = 0.20 },
        ["rbxassetid://139153666059747"] = { DisplayName = "2ndM1", ReactionTime = 0.20 },
        ["rbxassetid://96433631480947"] = { DisplayName = "3rdM1", ReactionTime = 0.10 },
        ["rbxassetid://119132409702905"] = { DisplayName = "4thM1", ReactionTime = 0.24 },
        ["rbxassetid://135110210666200"] = { DisplayName = "M2", ReactionTime = 0.30 },
        ["rbxassetid://72310116631906"] = { DisplayName = "M2", ReactionTime = 0.30 },
        ["rbxassetid://103319500580356"] = { DisplayName = "M2", ReactionTime = 0.30 },
    },
    ["KureAnims"] = {
        ["rbxassetid://89598700542051"] = {
            DisplayName = "1stM1",
            ReactionTime = 0.16
        },
        ["rbxassetid://84100769626105"] = {
            DisplayName = "2ndM1",
            ReactionTime = 0.16
        },
        ["rbxassetid://75725487794798"] = {
            DisplayName = "3rdM1",
            ReactionTime = 0.16
        },
        ["rbxassetid://103586798765773"] = {
            DisplayName = "4thM1",
            ReactionTime = 0.16
        },
        ["rbxassetid://128246407698779"] = {
            DisplayName = "M2",
            ["ReactionTime"] = 0.1,
        },
    },
    ["LethweiAnims"] = {
        ["rbxassetid://126845586831338"] = {
            DisplayName = "1stM1",
        },
        ["rbxassetid://111506889308405"] = {
            DisplayName = "2ndM1",
        },
        ["rbxassetid://93862547414782"] = {
            DisplayName = "3rdM1",
        },
        ["rbxassetid://81747456615347"] = {
            DisplayName = "4thM1",
        },
        ["rbxassetid://98256190530845"] = {
            DisplayName = "M2",
        },
    },
    ["MishimaAnims"] = {
        ["rbxassetid://122564675454774"] = {
            DisplayName = "1stM1",
        },
        ["rbxassetid://124288660244802"] = {
            DisplayName = "2ndM1",
        },
        ["rbxassetid://116344736444569"] = {
            DisplayName = "3rdM1",
        },
        ["rbxassetid://109354190051977"] = {
            DisplayName = "4thM1",
        },
        ["rbxassetid://113531813891302"] = {
            DisplayName = "M2",
        },
    },
    ["JinAnims"] = {
        ["rbxassetid://89404705737555"] = { DisplayName = "1stM1" },
        ["rbxassetid://126407816250012"] = { DisplayName = "2ndM1" },
        ["rbxassetid://111599179234006"] = { DisplayName = "3rdM1" },
        ["rbxassetid://115508221180588"] = { DisplayName = "4thM1" },
        ["rbxassetid://90986005545750"] = { DisplayName = "M2" },
    },
    ["DragonAnims"] = {
        ["rbxassetid://90632031214738"] = { DisplayName = "1stM1" },
        ["rbxassetid://129870265426519"] = { DisplayName = "2ndM1" },
        ["rbxassetid://103119271372106"] = { DisplayName = "3rdM1" },
        ["rbxassetid://81350056849630"] = { DisplayName = "4thM1" },
        -- Both M2 IDs are registered; their flip kick/dropkick labels are unconfirmed.
        ["rbxassetid://101059515516534"] = { DisplayName = "M2" },
        ["rbxassetid://101850612921423"] = { DisplayName = "M2" },
    },
    ["PerfectcopyAnims"] = {
        ["rbxassetid://89266206062347"] = { DisplayName = "1stM1" },
        ["rbxassetid://118618177788645"] = { DisplayName = "2ndM1" },
        ["rbxassetid://92563642848078"] = { DisplayName = "3rdM1" },
        ["rbxassetid://129685126037621"] = { DisplayName = "4thM1" },
        ["rbxassetid://84779382426562"] = { DisplayName = "M2" },
        ["rbxassetid://123851034848865"] = { DisplayName = "M2" },
    },
    ["AkidoAnims"] = {
        ["rbxassetid://101667835774312"] = { DisplayName = "1stM1" },
        ["rbxassetid://72100016327641"] = { DisplayName = "2ndM1" },
        ["rbxassetid://86622096544948"] = { DisplayName = "3rdM1" },
        ["rbxassetid://116579071175823"] = { DisplayName = "4thM1" },
        ["rbxassetid://113723231962801"] = { DisplayName = "M2", Counter = true },
    },
    ["TaijustuAnims"] = {
        ["rbxassetid://112772003891760"] = { DisplayName = "1stM1" },
        ["rbxassetid://120968355159054"] = { DisplayName = "2ndM1" },
        ["rbxassetid://134363734889174"] = { DisplayName = "3rdM1" },
        ["rbxassetid://140439623648569"] = { DisplayName = "4thM1" },
        ["rbxassetid://70666956463595"] = { DisplayName = "M2" },
    },
    ["GiovannaAnims"] = {
        ["rbxassetid://135716459366783"] = { DisplayName = "1stM1" },
        ["rbxassetid://128178940723536"] = { DisplayName = "2ndM1" },
        ["rbxassetid://133339208745195"] = { DisplayName = "3rdM1" },
        ["rbxassetid://129619149164145"] = { DisplayName = "4thM1" },
        ["rbxassetid://84500842912133"] = { DisplayName = "M2" },
    },
    ["HikakenAnims"] = {
        ["rbxassetid://109471728828625"] = { DisplayName = "1stM1" },
        ["rbxassetid://92152402802393"] = { DisplayName = "2ndM1" },
        ["rbxassetid://139736320509560"] = { DisplayName = "3rdM1" },
        ["rbxassetid://80033824766939"] = { DisplayName = "4thM1" },
        ["rbxassetid://94916233438251"] = { DisplayName = "M2" },
    },
    ["WingChun"] = {
        ["rbxassetid://135699957281468"] = {
            DisplayName = "4thM1",
            ReactionTime = 0.52
        },
        ["rbxassetid://125237241325107"] = {
            DisplayName = "M2",
            ["ReactionTime"] = 0.06,
        },
        ["rbxassetid://94976161225956"] = {
            DisplayName = "1stM1",
            ReactionTime = 0.16
        },
        ["rbxassetid://130903067566077"] = {
            DisplayName = "2ndM1",
            ReactionTime = 0.16
        },
        ["rbxassetid://139503477666199"] = {
            DisplayName = "3rdM1",
            ReactionTime = 0.16
        },
    },
    ["HakariOtherAnims"] = {
        ["rbxassetid://126612786608030"] = {
            DisplayName = "1stM1"
        },
        ["rbxassetid://113719263885794"] = {
            DisplayName = "2ndM1"
        },
        ["rbxassetid://136305578634960"] = {
            DisplayName = "3rdM1"
        },
        ["rbxassetid://89039586375625"] = {
            DisplayName = "4thM1"
        },
        ["rbxassetid://82855179231529"] = {
            DisplayName = "MomentumM2"
        },
        ["rbxassetid://101619248052969"] = {
            DisplayName = "M2"
        },
    },
    ["Debug"] = {
        ["http://www.roblox.com/asset/?id=125750702"] = {
            DisplayName = "M1",
            ReactionTime = 0.3,
        },
    },
}

local IgnoreIds = {
    73766443218740, 111699625251889, 85823794654077, 99661732639863, 106268941365574, 109816855387997, 122561749929324, 129805948180599,
    90752347516770, 135133599113049, 132695091086148, 137015026151472, 114511731321756, 100794890036133, 109303037515668, 117293898907979,
    74690341409113, 73090768467054, 72284079162560, 89016181362524, 76945839486275, 101161965631044, 128307941333158, 85931837451298,
    91352556581859, 77911299793653, 129335968179665, 122384188141033, 132695766056641, 113331696487725, 124220338099067, 99799500309776,
    108636808436488, 90015977935891, 87932588807124, 132477488202815, 102982320608759, 109278619250401, 79971841883936, 97783129267001,
    72822821848529, 79974955602012, 77798715679680, 85845666927963, 108862846290180, 108045962864902, 93184693099565, 120399899079666,
    99958962160522, 93221784050620, 70767328707698,
}

local ParriedAnimation = {
    "rbxassetid://100773926241456", "rbxassetid://102823909334302", "rbxassetid://96304721384743",
    "rbxassetid://82979105739696", "rbxassetid://96600699015093", "rbxassetid://138519505081692",
}
local StunnedAnimation = {
    "rbxassetid://122541287927198", "rbxassetid://83600639547203", "rbxassetid://80309578200579",
    "rbxassetid://92787945841620", "rbxassetid://108045962864902", "rbxassetid://104407197874289",
}
local ParryingAnimation = {
    "rbxassetid://118147060185189", "rbxassetid://80135556847061", "rbxassetid://88718564310179",
}
local ParryFailed = { "rbxassetid://4210597123" }

-- O(1) lookup sets (hot paths use these instead of table.find)
local function BuildSet(list)
    local set = {}
    for _, v in ipairs(list) do
        set[v] = true
        set[tostring(v)] = true
    end
    return set
end

local IgnoreIdSet = BuildSet(IgnoreIds)
local ParriedAnimSet = BuildSet(ParriedAnimation)
local StunnedAnimSet = BuildSet(StunnedAnimation)
local ParryingAnimSet = BuildSet(ParryingAnimation)
local ParryFailedSet = BuildSet(ParryFailed)

local function RebuildIgnoreIdSet()
    IgnoreIdSet = BuildSet(IgnoreIds)
end

local AutoParryRange = 10
local MaxCycleRange = 20
local ParryWindow = 0.2
local ProbabilityToParry = 100
local DefaultReactionTime = 0.1
local ParryOffset = 0
local BlockHoldTime = 0.27

-- Ping helper (used every frame when evaluating attacks — MUST exist)
local _pingCacheMs = 50
local _pingCacheAt = 0
local function GetPingValue()
    local now = os.clock()
    if (now - _pingCacheAt) < 0.25 then
        return _pingCacheMs
    end
    local ping = 50
    pcall(function()
        local stats = game:GetService("Stats")
        local item = stats
            and stats.Network
            and stats.Network.ServerStatsItem
            and stats.Network.ServerStatsItem["Data Ping"]
        if item and item.GetValue then
            ping = item:GetValue() or ping
        end
    end)
    pcall(function()
        if LocalPlayer and type(LocalPlayer.GetNetworkPing) == "function" then
            local p = LocalPlayer:GetNetworkPing()
            if type(p) == "number" then
                ping = p * 1000
            end
        end
    end)
    _pingCacheMs = tonumber(ping) or 50
    _pingCacheAt = now
    return _pingCacheMs
end

local CachedPing = 50
local function GetCachedPing()
    return CachedPing or GetPingValue()
end

-- iskeypressed is an executor global; provide a safe fallback so combat never nil-calls
local _rawIsKeyPressed = (type(iskeypressed) == "function" and iskeypressed) or nil
local function iskeypressed(code)
    if _rawIsKeyPressed then
        local ok, result = pcall(_rawIsKeyPressed, code)
        if ok then return result and true or false end
    end
    -- Fallback via UserInputService (code is virtual-key byte, e.g. string.byte("F") == 70)
    local ok, down = pcall(function()
        local uis = game:GetService("UserInputService")
        local map = {
            [70] = Enum.KeyCode.F,   -- F
            [81] = Enum.KeyCode.Q,   -- Q
            [32] = Enum.KeyCode.Space,
            [88] = Enum.KeyCode.X,
            [71] = Enum.KeyCode.G,
            [90] = Enum.KeyCode.Z,
        }
        local kc = map[code]
        if not kc then return false end
        return uis:IsKeyDown(kc)
    end)
    return ok and down or false
end

-- keypress / keyrelease: ensure callable so rhythm + combat never nil-call
if type(keypress) ~= "function" then
    function keypress(_) end
end
if type(keyrelease) ~= "function" then
    function keyrelease(_) end
end


-- ==========================================
local FlattenedConfig = {}

for styleName, assets in pairs(GameConfig) do
    local m1Time = assets["M1Time"]
    for assetId, data in pairs(assets) do
        if assetId == "M1Time" then continue end

        local flatData = table.clone(data) or {}
        flatData.Style = styleName

        if data.DisplayName ~= "M2" and m1Time then
            flatData.ReactionTime = m1Time
        elseif not data.ReactionTime then
            flatData.ReactionTime = DefaultReactionTime
        end

        FlattenedConfig[assetId] = flatData
    end
end

GameConfig = FlattenedConfig

-- New M2 animation IDs retain the existing normal M2 settings as a baseline.
GameConfig["rbxassetid://80822959210741"] = table.clone(GameConfig["rbxassetid://128363063231486"])
GameConfig["rbxassetid://132891856788045"] = table.clone(GameConfig["rbxassetid://128921678079615"])
GameConfig["rbxassetid://132891856788045"].Awakened = true
GameConfig["rbxassetid://83352556099235"] = table.clone(GameConfig["rbxassetid://91419261625463"])
GameConfig["rbxassetid://83352556099235"].Awakened = true
GameConfig["rbxassetid://85984892267786"] = table.clone(GameConfig["rbxassetid://90986005545750"])
GameConfig["rbxassetid://85984892267786"].Awakened = true
GameConfig["rbxassetid://82076026376495"] = table.clone(GameConfig["rbxassetid://78127273702521"])
GameConfig["rbxassetid://82076026376495"].Awakened = true
-- Blackflash uses this same animation ID in both normal and awakened forms.
GameConfig["rbxassetid://137954350192006"] = table.clone(GameConfig["rbxassetid://78127273702521"])
GameConfig["rbxassetid://137954350192006"].Blackflash = true
GameConfig["rbxassetid://124394929276448"] = table.clone(GameConfig["rbxassetid://137299369381761"])
GameConfig["rbxassetid://124394929276448"].Awakened = true
GameConfig["rbxassetid://120251079111989"] = table.clone(GameConfig["rbxassetid://98256190530845"])
GameConfig["rbxassetid://100495393065612"] = table.clone(GameConfig["rbxassetid://120251079111989"])
GameConfig["rbxassetid://100495393065612"].Awakened = true
GameConfig["rbxassetid://139458993289546"] = table.clone(GameConfig["rbxassetid://70666956463595"])
GameConfig["rbxassetid://139458993289546"].Awakened = true

-- Frozen baseline timings for Reset / Default profile
local OriginalTimings = {}
for id, info in pairs(GameConfig) do
    OriginalTimings[id] = info.ReactionTime or DefaultReactionTime
end

local AnimationIdSliders = {}
local bindStyle = nil -- filled by CreateGroupSliders (per-style button selector)
local currentStyleEditName = nil

-- ==========================================
-- Config System — Lua profiles (JSON fallback for legacy / imports)
-- ==========================================
local PROFILE_FOLDER = "sharingan_ap"
local LEGACY_FOLDERS = { "GakuranConfigs" } -- beerus-style drop-in
local PROFILE_FORMAT = "SharinganConfig"
local PROFILE_VERSION = 2
local profileSourceMap = {}
local selectedConfig = "Default"
local currentProfileName = "Default"
local LAST_SAVE_LOG = { ok = false }
local CONFIG_DEBUG = false -- flipped by Save/Load buttons at bottom of this file

-- Executor I/O probes (single table to keep top-level locals under Luau's 200 limit)
local IO_OK = {
    writefile  = type(writefile)  == "function",
    readfile   = type(readfile)   == "function",
    listfiles  = type(listfiles)  == "function",
    isfolder   = type(isfolder)   == "function",
    makefolder = type(makefolder) == "function",
    delfile    = type(delfile)    == "function",
    loadstring = type(loadstring) == "function",
}

local function cfglog(...)
    if CONFIG_DEBUG then
        print("[Config]", ...)
    end
end

local function ensureProfileFolder()
    if IO_OK.isfolder and IO_OK.makefolder and not isfolder(PROFILE_FOLDER) then
        pcall(makefolder, PROFILE_FOLDER)
    end
end

-- ========== Lua table serializer ==========
local serializeTable
local function serializeValue(v, indent)
    local t = type(v)
    if v == nil then return "nil" end
    if t == "boolean" then return tostring(v) end
    if t == "number" then
        if v ~= v then return "0/0" end
        if v == math.huge then return "math.huge" end
        if v == -math.huge then return "-math.huge" end
        return tostring(v)
    end
    if t == "string" then return string.format("%q", v) end
    if t == "table" then return serializeTable(v, indent) end
    return "nil"
end

serializeTable = function(tbl, indent)
    indent = indent or ""
    local nextIndent = indent .. "  "
    local parts = { "{\n" }
    local isArray = true
    local maxIndex = 0
    local keyCount = 0
    for k in pairs(tbl) do
        keyCount = keyCount + 1
        if type(k) ~= "number" or k % 1 ~= 0 or k < 1 then
            isArray = false
        elseif k > maxIndex then
            maxIndex = k
        end
    end
    if isArray and maxIndex ~= keyCount then isArray = false end

    if isArray then
        for i = 1, maxIndex do
            table.insert(parts, nextIndent)
            table.insert(parts, serializeValue(tbl[i], nextIndent))
            table.insert(parts, ",\n")
        end
    else
        local stringKeys, numericKeys = {}, {}
        for k in pairs(tbl) do
            if type(k) == "string" then
                table.insert(stringKeys, k)
            elseif type(k) == "number" then
                table.insert(numericKeys, k)
            end
        end
        table.sort(stringKeys)
        table.sort(numericKeys)
        for _, k in ipairs(numericKeys) do
            table.insert(parts, nextIndent)
            table.insert(parts, string.format("[%s] = ", tostring(k)))
            table.insert(parts, serializeValue(tbl[k], nextIndent))
            table.insert(parts, ",\n")
        end
        for _, k in ipairs(stringKeys) do
            table.insert(parts, nextIndent)
            table.insert(parts, string.format("[%q] = ", k))
            table.insert(parts, serializeValue(tbl[k], nextIndent))
            table.insert(parts, ",\n")
        end
    end
    table.insert(parts, indent)
    table.insert(parts, "}")
    return table.concat(parts)
end

local function serializeProfile(payload, name)
    -- The file content MUST be a bare table literal — nothing else. Some
    -- executors (e.g. Matcha) implement `loadstring(x)` as `load("return " .. x)`
    -- internally. That means:
    --   `return {...}`               → `return return {...}` → parse error
    --   `local X = {...} return X`   → `return local X = ...`  → parse error
    --   `-- comment\n{...}`          → `return -- comment\n{...}` → nil
    -- Only a pure `{...}` expression survives both wrap-as-expression and
    -- standard loadstring (via our Strategy 2 explicit return-wrap on load).
    -- No leading comments. We embed metadata INSIDE the table as fields.
    payload._savedAt = tostring(os.date("%Y-%m-%d %H:%M:%S"))
    payload._name = tostring(name or "unnamed")
    return serializeTable(payload, "")
end

-- ========== Discovery (both .lua and legacy .json, both folders) ==========
local function scanFolder(folder, names)
    if not IO_OK.listfiles then return end
    local files = {}
    pcall(function() files = listfiles(folder) or {} end)
    if #files == 0 then
        pcall(function() files = listfiles(folder .. "/") or {} end)
    end
    for _, f in pairs(files) do
        local s = tostring(f)
        local nLua = s:match("([^/\\]+)%.lua$")
        local nJson = s:match("([^/\\]+)%.json$")
        if nLua then
            if not profileSourceMap[nLua] or profileSourceMap[nLua].format ~= "lua" then
                table.insert(names, nLua)
                profileSourceMap[nLua] = { format = "lua", path = s }
            end
        elseif nJson then
            if not profileSourceMap[nJson] then
                table.insert(names, nJson)
                profileSourceMap[nJson] = { format = "json", path = s }
            end
        end
    end
end

local function listProfiles()
    table.clear(profileSourceMap)
    ensureProfileFolder()
    local names = {}
    scanFolder(PROFILE_FOLDER, names)
    for _, legacy in ipairs(LEGACY_FOLDERS) do
        scanFolder(legacy, names)
    end

    local seen, out = {}, {}
    for _, n in ipairs(names) do
        if not seen[n] then
            seen[n] = true
            table.insert(out, n)
        end
    end
    table.sort(out)
    if #out == 0 then return { "Default" } end
    local hasDefault = false
    for _, n in ipairs(out) do
        if n == "Default" then hasDefault = true break end
    end
    if not hasDefault then table.insert(out, 1, "Default") end
    return out
end

-- ========== Save ==========
local function saveProfile(name, payload)
    if not IO_OK.writefile then
        LAST_SAVE_LOG = { ok = false, err = "writefile unavailable" }
        return nil, "writefile unavailable"
    end
    ensureProfileFolder()
    local source = serializeProfile(payload, name)
    cfglog("SAVE", name, "bytes=" .. #source)

    local paths = {
        PROFILE_FOLDER .. "/" .. name .. ".lua",
        PROFILE_FOLDER .. "\\" .. name .. ".lua",
    }
    local lastErr
    local savedLuaPath
    for _, fpath in ipairs(paths) do
        local ok, err = pcall(writefile, fpath, source)
        if ok then
            local verified = true
            if IO_OK.readfile then
                local okR, back = pcall(readfile, fpath)
                verified = okR and type(back) == "string" and #back > 0
                if verified then
                    cfglog("SAVE verified", fpath, "bytes=" .. #back)
                end
            end
            if verified then
                savedLuaPath = fpath
                break
            end
        else
            lastErr = err
        end
    end

    if not savedLuaPath then
        LAST_SAVE_LOG = { ok = false, err = tostring(lastErr) }
        return nil, lastErr
    end

    -- Also write a JSON companion. On executors with quirky loadstring (Matcha
    -- wraps input as `return <text>`, breaking anything but a bare expression)
    -- the .json is the reliable load path. loadProfile tries it first.
    local jsonPath = PROFILE_FOLDER .. "/" .. name .. ".json"
    local jsonOk, jsonErr = pcall(function()
        local json = HttpService:JSONEncode(payload)
        writefile(jsonPath, json)
        return #json
    end)
    if jsonOk then
        cfglog("SAVE json companion", jsonPath)
    else
        cfglog("SAVE json companion FAILED", tostring(jsonErr))
        print("[Profiles] WARNING: json companion failed:", jsonErr)
    end

    LAST_SAVE_LOG = { ok = true, path = savedLuaPath, bytes = #source, json = jsonOk }
    return savedLuaPath
end

-- ========== Load ==========
local function loadProfile(name)
    local src = profileSourceMap[name]
    if not src then
        listProfiles()
        src = profileSourceMap[name]
    end
    if not src then return nil, "profile not found" end
    if not IO_OK.readfile then return nil, "readfile unavailable" end

    local okRead, text = pcall(readfile, src.path)
    if not okRead or type(text) ~= "string" then
        cfglog("LOAD readfile failed", src.path)
        return nil, "readfile failed"
    end

    if src.format == "lua" then
        if not IO_OK.loadstring then return nil, "loadstring unavailable" end

        -- PRIORITY: if we saved this file ourselves we also wrote a .json
        -- companion. JSON parsing is reliable across every executor, Lua
        -- loadstring is not — so try the companion FIRST when it exists.
        if IO_OK.readfile then
            local jsonAlt = src.path:gsub("%.lua$", ".json")
            if jsonAlt ~= src.path then
                local okAlt, altText = pcall(readfile, jsonAlt)
                if okAlt and type(altText) == "string" and #altText > 0 then
                    local okJ, altData = pcall(function() return HttpService:JSONDecode(altText) end)
                    if okJ and type(altData) == "table" then
                        cfglog("LOAD json companion", jsonAlt)
                        return altData
                    end
                end
            end
        end

        local lastErr

        -- Strategy 1: run text as-is. On Matcha-style loadstring (wraps as
        -- `return <text>` internally) this works for a bare table literal.
        local chunk, parseErr = loadstring(text)
        if chunk then
            local okRun, data = pcall(chunk)
            if okRun and type(data) == "table" then
                cfglog("LOAD lua ok (direct)", src.path)
                return data
            end
            if not okRun then
                lastErr = "runtime: " .. tostring(data)
            end
        else
            lastErr = "parse: " .. tostring(parseErr)
        end

        -- Strategy 2: standard loadstring expects a statement, so wrap bare
        -- expressions with explicit `return`. ONLY runs when strategy 1
        -- failed to compile — otherwise on Matcha this would double-wrap
        -- (`return return (...)`) and spam the console.
        if not chunk then
            local chunk2 = loadstring("return " .. text)
            if chunk2 then
                local ok2, data2 = pcall(chunk2)
                if ok2 and type(data2) == "table" then
                    cfglog("LOAD lua ok (return-wrapped)", src.path)
                    return data2
                end
                if not ok2 then lastErr = "runtime (wrapped): " .. tostring(data2) end
            end
        end

        -- Strategy 3: run in captured env, scan for a global config variable
        -- (beerus / Gakuran commonly assign without an explicit return).
        local CANDIDATE_NAMES = { "Config", "Profile", "Settings",
            "GakuranConfig", "GakuranConfigs", "Export", "Data", "T", "M" }
        if chunk then
            local env = setmetatable({}, { __index = _G })
            local okFenv = pcall(function() setfenv(chunk, env) end)
            if okFenv then
                pcall(chunk)
                for _, cname in ipairs(CANDIDATE_NAMES) do
                    if type(env[cname]) == "table" then
                        cfglog("LOAD lua ok (env." .. cname .. ")", src.path)
                        return env[cname]
                    end
                end
                for k, v in pairs(env) do
                    if type(v) == "table" and (v.Timings or v.Settings or v.Format) then
                        cfglog("LOAD lua ok (env scan)", src.path, tostring(k))
                        return v
                    end
                end
            end
        end

        -- Strategy 4: text-rewrite — strip `local` from leading `local Name =`
        -- so the value lands in our captured env for scanning. Handles beerus
        -- files like `local Config = {...}` with no return.
        for _, cname in ipairs(CANDIDATE_NAMES) do
            local rewritten, n = text:gsub("local%s+" .. cname .. "%s*=", cname .. " =", 1)
            if n > 0 then
                local chunk4 = loadstring(rewritten)
                if chunk4 then
                    local env4 = setmetatable({}, { __index = _G })
                    local okFenv4 = pcall(function() setfenv(chunk4, env4) end)
                    if okFenv4 then
                        pcall(chunk4)
                        if type(env4[cname]) == "table" then
                            cfglog("LOAD lua ok (strip-local " .. cname .. ")", src.path)
                            return env4[cname]
                        end
                    end
                end
            end
        end

        return nil, lastErr or "no load strategy produced a table"
    else
        local ok, data = pcall(function() return HttpService:JSONDecode(text) end)
        if not ok or type(data) ~= "table" then
            cfglog("LOAD json decode failed")
            return nil, "JSON decode failed"
        end
        cfglog("LOAD json ok", src.path)
        return data
    end
end

local function deleteProfile(name)
    local src = profileSourceMap[name]
    if not IO_OK.delfile then return false end
    if src and src.path then pcall(delfile, src.path) end
    -- Also nuke any stale alt-extension of the same name
    pcall(delfile, PROFILE_FOLDER .. "/" .. name .. ".lua")
    pcall(delfile, PROFILE_FOLDER .. "/" .. name .. ".json")
    pcall(delfile, PROFILE_FOLDER .. "\\" .. name .. ".lua")
    pcall(delfile, PROFILE_FOLDER .. "\\" .. name .. ".json")
    profileSourceMap[name] = nil
    return true
end

local function sanitizeProfileName(t)
    if t == nil then return nil end
    t = tostring(t):gsub('[/\\:*?"<>|]', ""):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 40)
    if t == "" then return nil end
    return t
end

-- Runtime config mirror — source of truth for save/load and combat reads
local CFG = {
    AutoParry = true,
    AutoDodge = true,
    AutoBoxingM2 = true,  -- Syndicatus: AP runs block→dodge on Boxing M2
    AutoTargetNearest = false,
    MultiTarget = true,
    HeightMultiplier = false,
    TargetFacingYou = false,
    YouFacingTarget = true,
    DebugParry = false,
    PingCompensate = true,
    AutoPlay = true,
    IncludeLocalCharacter = false,
    APKeybind = "g",
    MenuKey = "p",  -- INS menu open/close (changeable via keybind pill)
}

-- Early local so UI callbacks + profile load share the same binding
local IncludeLocalCharacter = false

-- CRITICAL: toggle handles MUST be declared BEFORE collect/apply.
-- Lua local scope starts at the `local` line. If AutoParryToggle is
-- declared later, applySettingsSnapshot closes over the GLOBAL (nil)
-- while CreateAPSection assigns the local — load never updates the UI.
-- Syndicatus avoids this with UIRefs.Armed = toggle (table field).
local AutoParryToggle, AutoDodgeToggle
local AutoTargetNearest, MultiTarget
local TargetFacingYou, YouFacingTarget
local ParryDebugToggle
local PingCompensateToggle
local AutoPlayToggle
local HeightToggle
local MenuKeybindRef = nil  -- INS Keybind handle for menu toggle

-- INS UI stores the real value on handle.item.value (checkbox / slider).
-- handle:Get() and handle:Set(v) close over that same item. Writing item
-- directly is the reliable path — same library Syndicatus uses.
local function safeToggleGet(toggle, fallback)
    if not toggle then return fallback end
    local ok, v = pcall(function()
        if type(toggle.item) == "table" and type(toggle.item.value) == "boolean" then
            return toggle.item.value
        end
        if type(toggle.Get) == "function" then return toggle:Get() end
        return nil
    end)
    if ok and type(v) == "boolean" then return v end
    return fallback
end

local function safeToggleSet(toggle, value)
    if not toggle then return end
    -- INS checkbox coerces with (value == true) — match that exactly
    value = (value == true)

    -- 1) Write internal item (what the UI actually draws from)
    pcall(function()
        if type(toggle.item) == "table" then
            toggle.item.value = value
            if type(toggle.item.callback) == "function" then
                toggle.item.callback(value)
            end
        end
    end)

    -- 2) Official API (fires callback only if value changed)
    pcall(function()
        if type(toggle.Set) == "function" then toggle:Set(value) end
    end)
end

local function safeSliderSet(slider, value)
    if not slider then return end
    value = tonumber(value)
    if not value then return end
    pcall(function()
        if type(slider.item) == "table" then
            slider.item.value = value
            if type(slider.item.callback) == "function" then
                slider.item.callback(value)
            end
        end
    end)
    pcall(function()
        if type(slider.Set) == "function" then slider:Set(value) end
    end)
end


local function normalizeMenuKey(key)
    if key == nil then return nil end
    if type(key) == "table" then
        key = key.value or key.Name or key.Key or key[1]
    end
    local s = string.lower(tostring(key or ""))
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" or s == "none" or s == "nil" then return nil end
    -- Enum.KeyCode.P style
    s = s:gsub("^enum%.keycode%.", "")
    return s
end

local function readMenuKey()
    local k = nil
    pcall(function()
        if MenuKeybindRef and type(MenuKeybindRef.item) == "table" then
            k = MenuKeybindRef.item.value
        elseif MenuKeybindRef and type(MenuKeybindRef.Get) == "function" then
            k = MenuKeybindRef:Get()
        end
    end)
    k = normalizeMenuKey(k)
    if k then
        CFG.MenuKey = k
        return k
    end
    return tostring(CFG.MenuKey or "p")
end

local function writeMenuKey(key)
    local s = normalizeMenuKey(key) or "p"
    CFG.MenuKey = s
    pcall(function()
        if UI_Library and UI_Library.SetMenuKey then
            UI_Library:SetMenuKey(s)
        end
    end)
    pcall(function()
        if MenuKeybindRef and type(MenuKeybindRef.item) == "table" then
            MenuKeybindRef.item.value = s
        end
        if MenuKeybindRef and type(MenuKeybindRef.Set) == "function" then
            MenuKeybindRef:Set(s)
        end
    end)
    return s
end

local function readAPKeybind()
    local k = nil
    pcall(function()
        -- INS stores keybind on toggle.item.keybind.value (not .Bind)
        if AutoParryToggle and type(AutoParryToggle.item) == "table"
            and type(AutoParryToggle.item.keybind) == "table"
            and type(AutoParryToggle.item.keybind.value) == "string" then
            k = AutoParryToggle.item.keybind.value
        elseif AutoParryToggle and AutoParryToggle.keyHandle and AutoParryToggle.keyHandle.keybind then
            k = AutoParryToggle.keyHandle.keybind.value
        end
    end)
    if type(k) == "string" and #k > 0 and k ~= "none" then
        CFG.APKeybind = string.lower(k)
        return CFG.APKeybind
    end
    return tostring(CFG.APKeybind or "g")
end

local function writeAPKeybind(key)
    if not key or key == "" then return end
    local s = tostring(key):gsub("%s+", ""):lower()
    if s == "" then return end
    CFG.APKeybind = s
    pcall(function()
        if AutoParryToggle and type(AutoParryToggle.item) == "table"
            and type(AutoParryToggle.item.keybind) == "table" then
            AutoParryToggle.item.keybind.value = s
            AutoParryToggle.item.keybind.mode = "Toggle"
        elseif AutoParryToggle and type(AutoParryToggle.AddKeybind) == "function" then
            AutoParryToggle:AddKeybind(s, "Toggle")
        end
    end)
end

-- Filled after UI is built so Save/Load can sync widgets
local UISettingRefs = {
    RangeSlider = nil,
    ProbabilitySlider = nil,
    OffsetSlider = nil,
    WindowSlider = nil,
    CycleRangeSlider = nil,
    HpRangeSlider = nil,
    TargetMarkerToggle = nil,
    OpponentHpToggle = nil,
    PersonalHpToggle = nil,
    CombatEspToggle = nil,
    AnimDebugEspToggle = nil,
    IncludeLocalToggle = nil,
}

local function collectSettingsSnapshot()
    -- Sync CFG from live widgets before serializing
    if AutoParryToggle then CFG.AutoParry = safeToggleGet(AutoParryToggle, CFG.AutoParry) end
    if AutoDodgeToggle then CFG.AutoDodge = safeToggleGet(AutoDodgeToggle, CFG.AutoDodge) end
    if AutoTargetNearest then CFG.AutoTargetNearest = safeToggleGet(AutoTargetNearest, CFG.AutoTargetNearest) end
    if MultiTarget then CFG.MultiTarget = safeToggleGet(MultiTarget, CFG.MultiTarget) end
    if HeightToggle then CFG.HeightMultiplier = safeToggleGet(HeightToggle, CFG.HeightMultiplier) end
    if TargetFacingYou then CFG.TargetFacingYou = safeToggleGet(TargetFacingYou, CFG.TargetFacingYou) end
    if YouFacingTarget then CFG.YouFacingTarget = safeToggleGet(YouFacingTarget, CFG.YouFacingTarget) end
    if ParryDebugToggle then CFG.DebugParry = safeToggleGet(ParryDebugToggle, CFG.DebugParry) end
    if PingCompensateToggle then CFG.PingCompensate = safeToggleGet(PingCompensateToggle, CFG.PingCompensate) end
    if AutoPlayToggle then CFG.AutoPlay = safeToggleGet(AutoPlayToggle, CFG.AutoPlay) end
    readAPKeybind()
    readMenuKey()

    return {
        AutoParry = CFG.AutoParry and true or false,
        AutoDodge = CFG.AutoDodge and true or false,
        AutoBoxingM2 = CFG.AutoBoxingM2 and true or false,
        AutoTargetNearest = CFG.AutoTargetNearest and true or false,
        MultiTarget = CFG.MultiTarget and true or false,
        HeightMultiplier = CFG.HeightMultiplier and true or false,
        TargetFacingYou = CFG.TargetFacingYou and true or false,
        YouFacingTarget = CFG.YouFacingTarget and true or false,
        DebugParry = CFG.DebugParry and true or false,
        PingCompensate = CFG.PingCompensate and true or false,
        AutoPlay = CFG.AutoPlay and true or false,
        APKeybind = CFG.APKeybind,
        MenuKey = CFG.MenuKey,
        TargetMarker = NoCrashState.TargetMarkerEnabled and true or false,
        OpponentHp = NoCrashState.OpponentHpEnabled and true or false,
        PersonalHp = NoCrashState.PersonalHpEnabled and true or false,
        CombatEsp = NoCrashState.CombatEspEnabled and true or false,
        AnimDebugEsp = NoCrashState.AnimDebugEspEnabled and true or false,
        HpViewRange = NoCrashState.HpViewRange,
        AutoParryRange = AutoParryRange,
        MaxCycleRange = MaxCycleRange,
        ParryWindow = ParryWindow,
        ProbabilityToParry = ProbabilityToParry,
        DefaultReactionTime = DefaultReactionTime,
        ParryOffset = ParryOffset,
        BlockHoldTime = BlockHoldTime,
        SelectedFolder = SelectedFolder,
        IncludeLocalCharacter = IncludeLocalCharacter and true or false,
        Enabled = CFG.AutoParry and true or false,
        OpponentHpEnabled = NoCrashState.OpponentHpEnabled and true or false,
        PersonalHpEnabled = NoCrashState.PersonalHpEnabled and true or false,
        TargetMarkerEnabled = NoCrashState.TargetMarkerEnabled and true or false,
        CombatEspEnabled = NoCrashState.CombatEspEnabled and true or false,
        AnimDebugEspEnabled = NoCrashState.AnimDebugEspEnabled and true or false,
    }
end

local function collectTimingsSnapshot()
    local t = {}
    for id, info in pairs(GameConfig) do
        t[id] = info.ReactionTime or DefaultReactionTime
    end
    return t
end

local function refreshTimingSliders()
    -- After profile load/reset: rebind the open style so slot values match GameConfig
    if bindStyle and currentStyleEditName then
        pcall(function() bindStyle(currentStyleEditName) end)
        return
    end
    for animationId, slider in pairs(AnimationIdSliders) do
        local info = GameConfig[animationId]
        if info and slider and slider.Set then
            pcall(function()
                slider:Set(info.ReactionTime or DefaultReactionTime)
            end)
        end
    end
end

local function applySettingsSnapshot(s)
    if type(s) ~= "table" then return end

    local function bool(v)
        if v == nil then return nil end
        return v and true or false
    end

    -- Accept both our keys and Syndicatus "Enabled"
    local autoParry = s.AutoParry
    if autoParry == nil then autoParry = s.Enabled end
    if autoParry ~= nil then
        CFG.AutoParry = bool(autoParry)
        safeToggleSet(AutoParryToggle, CFG.AutoParry)
    end
    if s.AutoDodge ~= nil then
        CFG.AutoDodge = bool(s.AutoDodge)
        safeToggleSet(AutoDodgeToggle, CFG.AutoDodge)
    end
    if s.AutoBoxingM2 ~= nil then
        CFG.AutoBoxingM2 = bool(s.AutoBoxingM2)
        safeToggleSet(UISettingRefs.AutoBoxingM2Toggle, CFG.AutoBoxingM2)
    end
    if s.AutoTargetNearest ~= nil then
        CFG.AutoTargetNearest = bool(s.AutoTargetNearest)
        safeToggleSet(AutoTargetNearest, CFG.AutoTargetNearest)
    end
    if s.MultiTarget ~= nil then
        CFG.MultiTarget = bool(s.MultiTarget)
        safeToggleSet(MultiTarget, CFG.MultiTarget)
    end
    if s.HeightMultiplier ~= nil or s.AutoHeight ~= nil then
        local hv = s.HeightMultiplier
        if hv == nil then hv = s.AutoHeight end
        CFG.HeightMultiplier = bool(hv)
        safeToggleSet(HeightToggle, CFG.HeightMultiplier)
    end
    if s.TargetFacingYou ~= nil then
        CFG.TargetFacingYou = bool(s.TargetFacingYou)
        safeToggleSet(TargetFacingYou, CFG.TargetFacingYou)
    end
    if s.YouFacingTarget ~= nil then
        CFG.YouFacingTarget = bool(s.YouFacingTarget)
        safeToggleSet(YouFacingTarget, CFG.YouFacingTarget)
    end
    if s.DebugParry ~= nil or s.Debug ~= nil then
        local dv = s.DebugParry
        if dv == nil then dv = s.Debug end
        CFG.DebugParry = bool(dv)
        safeToggleSet(ParryDebugToggle, CFG.DebugParry)
    end
    if s.PingCompensate ~= nil then
        CFG.PingCompensate = bool(s.PingCompensate)
        safeToggleSet(PingCompensateToggle, CFG.PingCompensate)
    end
    if s.AutoPlay ~= nil or s.RhythmAutoHit ~= nil then
        local av = s.AutoPlay
        if av == nil then av = s.RhythmAutoHit end
        CFG.AutoPlay = bool(av)
        safeToggleSet(AutoPlayToggle, CFG.AutoPlay)
    end
    if s.APKeybind ~= nil then
        writeAPKeybind(s.APKeybind)
    end
    if s.MenuKey ~= nil then
        writeMenuKey(s.MenuKey)
    end

    if s.AutoParryRange ~= nil or s.APRange ~= nil then
        AutoParryRange = tonumber(s.AutoParryRange or s.APRange) or AutoParryRange
        safeSliderSet(UISettingRefs.RangeSlider, AutoParryRange)
    end
    if s.MaxCycleRange ~= nil or s.CycleRange ~= nil then
        MaxCycleRange = tonumber(s.MaxCycleRange or s.CycleRange) or MaxCycleRange
        safeSliderSet(UISettingRefs.CycleRangeSlider, MaxCycleRange)
    end
    if s.ParryWindow ~= nil then
        ParryWindow = tonumber(s.ParryWindow) or ParryWindow
        safeSliderSet(UISettingRefs.WindowSlider, ParryWindow)
    end
    if s.ProbabilityToParry ~= nil then
        ProbabilityToParry = tonumber(s.ProbabilityToParry) or ProbabilityToParry
        safeSliderSet(UISettingRefs.ProbabilitySlider, ProbabilityToParry)
    end
    if s.ParryOffset ~= nil then
        ParryOffset = tonumber(s.ParryOffset) or ParryOffset
        safeSliderSet(UISettingRefs.OffsetSlider, ParryOffset)
    end
    if s.DefaultReactionTime ~= nil or s.DefaultRT ~= nil then
        DefaultReactionTime = tonumber(s.DefaultReactionTime or s.DefaultRT) or DefaultReactionTime
    end
    if s.BlockHoldTime ~= nil or s.ParryHold ~= nil then
        BlockHoldTime = tonumber(s.BlockHoldTime or s.ParryHold) or BlockHoldTime
    end
    if s.SelectedFolder ~= nil then
        SelectedFolder = s.SelectedFolder
    end
    if s.IncludeLocalCharacter ~= nil then
        IncludeLocalCharacter = bool(s.IncludeLocalCharacter)
        CFG.IncludeLocalCharacter = IncludeLocalCharacter
        safeToggleSet(UISettingRefs.IncludeLocalToggle, IncludeLocalCharacter)
    end

    local function pickBool(...)
        for i = 1, select("#", ...) do
            local v = select(i, ...)
            if v ~= nil then return bool(v) end
        end
        return nil
    end

    local tm = pickBool(s.TargetMarker, s.TargetMarkerEnabled)
    if tm ~= nil then
        NoCrashState.TargetMarkerEnabled = tm
        safeToggleSet(UISettingRefs.TargetMarkerToggle, tm)
    end
    local oh = pickBool(s.OpponentHp, s.OpponentHpEnabled)
    if oh ~= nil then
        NoCrashState.OpponentHpEnabled = oh
        safeToggleSet(UISettingRefs.OpponentHpToggle, oh)
    end
    local ph = pickBool(s.PersonalHp, s.PersonalHpEnabled)
    if ph ~= nil then
        NoCrashState.PersonalHpEnabled = ph
        safeToggleSet(UISettingRefs.PersonalHpToggle, ph)
    end
    local ce = pickBool(s.CombatEsp, s.CombatEspEnabled)
    if ce ~= nil then
        NoCrashState.CombatEspEnabled = ce
        safeToggleSet(UISettingRefs.CombatEspToggle, ce)
    end
    local ad = pickBool(s.AnimDebugEsp, s.AnimDebugEspEnabled)
    if ad ~= nil then
        NoCrashState.AnimDebugEspEnabled = ad
        safeToggleSet(UISettingRefs.AnimDebugEspToggle, ad)
    end
    if s.HpViewRange ~= nil then
        NoCrashState.HpViewRange = tonumber(s.HpViewRange) or NoCrashState.HpViewRange
        safeSliderSet(UISettingRefs.HpRangeSlider, NoCrashState.HpViewRange)
    end
end

local function applyTimingsSnapshot(timings)
    if type(timings) ~= "table" then return 0 end
    local n = 0
    for id, rt in pairs(timings) do
        local key = tostring(id)
        if not key:find("rbxassetid://", 1, true) and not key:find("http://", 1, true) then
            key = "rbxassetid://" .. key
        end
        if GameConfig[key] then
            GameConfig[key].ReactionTime = tonumber(rt) or DefaultReactionTime
            n = n + 1
        end
    end
    refreshTimingSliders()
    return n
end

local function resetTimingsToOriginal()
    for id, rt in pairs(OriginalTimings) do
        if GameConfig[id] then
            GameConfig[id].ReactionTime = rt
        end
    end
    refreshTimingSliders()
end

local function buildProfilePayload()
    return {
        Format = PROFILE_FORMAT,
        Version = PROFILE_VERSION,
        _format = "lolbeans67-ap-v1", -- legacy field, kept for backwards read
        Name = currentProfileName,
        Timings = collectTimingsSnapshot(),
        Settings = collectSettingsSnapshot(),
    }
end

-- Accept:
--   { Format="SharinganConfig", Timings=..., Settings=... }  (us, Lua + JSON)
--   { _format="lolbeans67-ap-v1", Timings=..., Settings=... }   (legacy JSON)
--   { Format="GakuranTimingConfig", Timings=... }                (beerus)
--   { Timings=..., Settings=... }                                (loose)
--   bare settings table (very old)
local function applyProfilePayload(data)
    if type(data) ~= "table" then return 0, 0 end

    local timings = data.Timings
    local settings = data.Settings

    -- Beerus / Gakuran: timings-only format
    local fmt = tostring(data.Format or data._format or "")
    local timingsOnly = fmt:find("Gakuran", 1, true) ~= nil
                     or fmt:find("Timing", 1, true) ~= nil
                     or (timings and settings == nil)

    local tCount = applyTimingsSnapshot(timings)
    local sCount = 0
    if not timingsOnly then
        local toApply = settings or data
        applySettingsSnapshot(toApply)
        if type(toApply) == "table" then
            for _ in pairs(toApply) do sCount = sCount + 1 end
        end
    end

    cfglog("APPLY", "fmt=" .. fmt, "timings=" .. tCount, "settings=" .. sCount,
        "AutoDodge=" .. tostring(CFG.AutoDodge),
        "AutoParry=" .. tostring(CFG.AutoParry))

    return tCount, sCount
end

local function GetAllFoldersInWorkspace()
    local Folders = {}

    for _, Folder in game.Workspace:GetChildren() do  
        if Folder.ClassName == "Folder" then
            table.insert(Folders, Folder.Name)
        end
    end

    return Folders
end

local function GetAllCharactersInFolder()
    if not SelectedFolder then
        UI_Library:Notify("ERROR", "Select a folder first")
        return nil
    end

    local folder = workspace:FindFirstChild(SelectedFolder)
    if not folder then
        UI_Library:Notify("ERROR", "Select a folder first")
        return nil
    end

    local characters = {}
    local localChar = LocalPlayer.Character

    for _, character in ipairs(folder:GetChildren()) do
        if character.ClassName == "Model" and character:FindFirstChildWhichIsA("Humanoid") then
            if not IncludeLocalCharacter and localChar and character == localChar then
                continue
            end
            table.insert(characters, character)
        end
    end

    return characters
end

local function SetClipboardLoggedCache()
    local totalItems = #AnimationsLoggedOrder
    if totalItems == 0 then
        print("[Clipboard] Nothing logged to copy.")
        return
    end

    local ids = {}
    for i = 1, totalItems do
        -- Extract only the numbers from the asset ID string
        local numericId = tostring(AnimationsLoggedOrder[i]):match("%d+")
        if numericId then
            table.insert(ids, numericId)
        end
    end

    local clipboardString = table.concat(ids, ",")
    
    setclipboard(clipboardString)
    print(string.format("[Clipboard] Successfully copied %d logged animation IDs!", #ids))
    UI_Library:Notify("Clipboard", string.format("Successfully copied %d logged animation IDs!", #ids))
end

local function SetClipboardIgnoreList()
    if #AnimationsLoggedOrder == 0 then
        print("[Clipboard] Nothing logged to copy.")
        return
    end

    local newlyAddedIds = {}

    for animationId in pairs(AnimationsLoggedCache) do
        local numericId = tonumber(string.match(tostring(animationId), "%d+"))
        if numericId and not IgnoreIdSet[numericId] then
            table.insert(IgnoreIds, numericId)
            table.insert(newlyAddedIds, tostring(numericId))
        end
    end

    RebuildIgnoreIdSet()

    local outputstring = table.concat(newlyAddedIds, ", ")
    setclipboard(outputstring)

    print(string.format(
        "[Clipboard] Copied %d NEW IDs! (Total historical ignored count is now: %d)",
        #newlyAddedIds,
        #IgnoreIds
    ))
end

local function AnimationGrabber(Folder)
    local OutputLines = {"{"}
    
    for _, Style in Folder:GetChildren() do
        if not Style.Name:find("Anims") then continue end
        
        local styleAnimations = {}
        
        for _, Animation in Style:GetChildren() do              
            if Animation.Name:find("M1") or Animation.Name:find("M2") then 
                local AnimationIdPointer = memory_read("uintptr_t", Animation.Address + 192)
                local AnimationId = memory_read("string", AnimationIdPointer) or ""
                -- Format the individual animation entry
                local animString = string.format('      ["%s"] = {\n          DisplayName = "%s"\n      }', AnimationId, Animation.Name)
                table.insert(styleAnimations, animString)
            end 
        end
        
        if #styleAnimations > 0 then
            table.insert(OutputLines, string.format('   ["%s"] = {', Style.Name))
            table.insert(OutputLines, table.concat(styleAnimations, ",\n"))
            table.insert(OutputLines, '   },')
        end
    end
    
    table.insert(OutputLines, "}")
    
    local Output = table.concat(OutputLines, "\n")
    setclipboard(Output)
    print(Output)
end
--AnimationGrabber(game.ReplicatedStorage.Animations.Combat)

local function LiteGrabber(Folder)
    local OutputLines = {}
    for _, Animation in Folder:GetChildren() do              
        local AnimationIdPointer = memory_read("uintptr_t", Animation.Address + 192)
        local AnimationId = memory_read("string", AnimationIdPointer) or ""
        local String = `Name: {Animation.Name} | Id: {AnimationId}`
        table.insert(OutputLines, String)
    end

    local Output = table.concat(OutputLines, "\n")
    setclipboard(Output)
    print(Output)
end
--LiteGrabber(game.ReplicatedStorage.Animations.Combat.WingChunAnims)

local function UpdateSliders(_oldReactionTime)
    refreshTimingSliders()
end

local scheduler = {}
local pendingTasks = {}

function scheduler.delay(delayTime, callback)
    table.insert(pendingTasks, {
        executeAt = os.clock() + delayTime,
        callback = callback
    })
end

function scheduler.update()
    local n = #pendingTasks
    if n == 0 then return end
    local now = os.clock()
    for i = n, 1, -1 do
        local task = pendingTasks[i]
        if now >= task.executeAt then
            table.remove(pendingTasks, i)
            coroutine.wrap(task.callback)()
        end
    end
end

-- ==========================================

-- ==========================================

-- ==========================================================
-- UI WINDOW & TAB INITIALIZATION
-- ==========================================================
local UI_Window = UI_Library:CreateWindow({
    title = "Sharingan",
    size = Vector2.new(700, 580),
    configFolder = "sharingan_ap",
    opacity = 1,
    menuKey = tostring(CFG.MenuKey or "p"),
})

-- Dark panels + red accent (match Syndicatus)
pcall(function()
    if UI_Library.SetOpacity then UI_Library:SetOpacity(1) end
    if UI_Library.SetTheme then
        UI_Library:SetTheme({ Background = Color3.fromRGB(0, 0, 0) })
    end
    if UI_Library.SetAccent then
        UI_Library:SetAccent(Color3.fromRGB(210, 40, 40))
    end
end)

-- Menu background image (from Syndicatus)
local BG_IMAGE_URL = "https://raw.githubusercontent.com/BL4CK3Y/SharinganAP/main/sharingan.jpg"
local function applyMenuBackground()
    pcall(function()
        if UI_Library and UI_Library.SetBackgroundImage then
            UI_Library:SetBackgroundImage(BG_IMAGE_URL, 0.10, 1, 1)
        end
    end)
end
applyMenuBackground()
task.defer(applyMenuBackground)
task.delay(1.0, applyMenuBackground)

local AP_Tab = UI_Window:Tab("Auto Parry", "eye")
local Config_Tab = UI_Window:Tab("Style Configurations", "gauge")

local Files_Section     = AP_Tab:Section("Files", "Left")
local AutoplaySection     = AP_Tab:Section("Autoplay", "Left")
local Config_Section    = AP_Tab:Section("Global Configuration", "Left")
local ClipboardSection = AP_Tab:Section("Logging", "Left")

local AP_Section        = AP_Tab:Section("Settings", "Right")
local Folders_Section   = AP_Tab:Section("Folders", "Right")
local Overlay_Section   = AP_Tab:Section("Target Overlay", "Right")

-- ==========================================================
-- STATE & UI ELEMENT REFERENCES
-- ==========================================================
local TargetPool_Text
local LoggedText, IgnoredText

-- Toggle handles declared early (with CFG helpers) — do not redeclare

-- ==========================================================
-- HELPER FUNCTIONS
-- ==========================================================
local function UpdateTargetPoolSection()
    local characters = GetAllCharactersInFolder() 
    local names = {}
    
    for i, character in ipairs(characters) do
        table.insert(names, character.Name)
        if i == 10 then 
            table.insert(names, "... (too long)") 
            break 
        end 
    end

    local poolString = #names > 0 and table.concat(names, ", ") or "NO TARGETS FOUND"
    TargetPool_Text:SetText("Target Pool: " .. poolString)
end

local function UpdateClipboardSection()
    local animationsLoggedCount = 0 
    for _ in pairs(AnimationsLoggedCache or {}) do  
        animationsLoggedCount += 1
    end

    LoggedText:SetText("Logged Ids: " .. animationsLoggedCount)
    IgnoredText:SetText("Ignored Ids: " .. #(IgnoreIds or {}))
end


-- ==========================================================

-- Luau 200-local limit: UI + rhythm in nested scope
local function __LB67_UIAndRhythm()
-- ── Rhythm Auto-Hit (from Syndicatus, peak-tracked holds + crisp taps) ──
-- 4-lane keys: Z X , .   |  2-lane keys: F J
local Receptors = {
    Receptor1 = "Z",
    Receptor2 = "X",
    Receptor3 = ",",
    Receptor4 = ".",
}
local ReceptorXMap = {}
local HeldKeys = {}
local HeldNotes = {}
local HeldNoteKeys = {}
local HeldPressTime = {}
local HeldPeakPosDelta = {}
local FinishedNotes = {}
local DebuggedNotes = {}
local LastRhythmCache = 0
local Threshold = 30
local OFFSCREEN = 2500
local HOLD_PEAK = 80
local HOLD_DONE_POSDELTA = 55
local HOLD_MIN_HELD = 0.12
local TAP_LEAVE = 15
local SAFETY_HELD = 10

local function rhythmKeyByte(key)
    if not key then return nil end
    key = tostring(key)
    if key == "," then return 0xBC end
    if key == "." then return 0xBE end
    if #key == 1 then return string.byte(key:upper()) end
    return string.byte(key:sub(1, 1):upper())
end

local function guiPosY(gui)
    if not gui then return nil end
    local y
    pcall(function() y = gui.AbsolutePosition.Y end)
    return y
end

local function forceReleaseLane(rName, reason)
    local keyB = HeldNoteKeys[rName]
    local note = HeldNotes[rName]
    if keyB then pcall(function() keyrelease(keyB) end) end
    if note then FinishedNotes[note] = true end
    if CFG.DebugParry then
        local heldFor = os.clock() - (HeldPressTime[rName] or os.clock())
        print(string.format("[Rhythm] RELEASE lane=%s held=%.3fs (%s)", rName, heldFor, reason or "?"))
    end
    HeldKeys[rName] = nil
    HeldNotes[rName] = nil
    HeldNoteKeys[rName] = nil
    HeldPressTime[rName] = nil
    HeldPeakPosDelta[rName] = nil
end

function AutoPlayTask() -- global: called from MainLoop in combat scope
    if not CFG.AutoPlay then
        -- Only walk HeldNotes if something is actually held (common case: empty → free)
        if next(HeldNotes) ~= nil then
            for rName in pairs(HeldNotes) do
                forceReleaseLane(rName, "disabled")
            end
        end
        return
    end

    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then return end
    local RhythmServiceUI = gui:FindFirstChild("RhythmServiceUI")
    if not RhythmServiceUI then return end
    local RhythmRoot = RhythmServiceUI:FindFirstChild("RhythmRoot")
    if not RhythmRoot then return end
    local ReceptorLookup = RhythmRoot:FindFirstChild("Receptors")
    local Lanes = RhythmRoot:FindFirstChild("Lanes")
    if not ReceptorLookup or not Lanes then return end

    local now = os.clock()
    if now - LastRhythmCache >= 1 then
        table.clear(ReceptorXMap)
        local count = 0
        for name, key in pairs(Receptors) do
            local rec = ReceptorLookup:FindFirstChild(name)
            if rec then
                local rx
                pcall(function()
                    rx = math.floor(rec.AbsolutePosition.X + rec.AbsoluteSize.X / 2)
                end)
                if rx then
                    count = count + 1
                    ReceptorXMap[rx] = { ReceptorName = name, Key = key, KeyByte = rhythmKeyByte(key), Receptor = rec }
                end
            end
        end
        if count == 2 then
            Receptors.Receptor1 = "F"
            Receptors.Receptor2 = "J"
            Receptors.Receptor3 = nil
            Receptors.Receptor4 = nil
        else
            Receptors.Receptor1 = "Z"
            Receptors.Receptor2 = "X"
            Receptors.Receptor3 = ","
            Receptors.Receptor4 = "."
        end
        table.clear(ReceptorXMap)
        for name, key in pairs(Receptors) do
            if not key then continue end
            local rec = ReceptorLookup:FindFirstChild(name)
            if rec then
                local rx
                pcall(function()
                    rx = math.floor(rec.AbsolutePosition.X + rec.AbsoluteSize.X / 2)
                end)
                if rx then
                    ReceptorXMap[rx] = { ReceptorName = name, Key = key, KeyByte = rhythmKeyByte(key), Receptor = rec }
                end
            end
        end
        LastRhythmCache = now
    end

    local pressCandidate = {}
    local laneCurState = {}

    for _, note in ipairs(Lanes:GetChildren()) do
        if note.Name ~= "NoteTemplate" then continue end
        if FinishedNotes[note] then continue end

        local notePos
        pcall(function() notePos = note.AbsolutePosition end)
        if not notePos then continue end
        local noteW = 0
        pcall(function() noteW = note.AbsoluteSize.X or 0 end)
        local noteX = math.floor(notePos.X + noteW / 2)

        local match
        for rx, data in pairs(ReceptorXMap) do
            if math.abs(noteX - rx) <= 10 then
                match = data
                break
            end
        end
        if not match or not match.Receptor then continue end

        local receptorPos
        pcall(function() receptorPos = match.Receptor.AbsolutePosition end)
        if not receptorPos then continue end
        local rName = match.ReceptorName
        local b = match.KeyByte
        if not b then continue end

        local head = note:FindFirstChild("Head")
        local tail = note:FindFirstChild("Tail")
        local headY = guiPosY(head) or notePos.Y
        local tailY = guiPosY(tail)
        local posDelta = (tailY and headY) and math.abs(tailY - headY) or 0

        if math.abs(headY - receptorPos.Y) > OFFSCREEN then
            continue
        end

        if CFG.DebugParry and not DebuggedNotes[note] then
            if math.abs(headY - receptorPos.Y) < Threshold * 3 then
                DebuggedNotes[note] = true
                print(string.format(
                    "[Rhythm] NOTE lane=%s headY=%.1f recY=%.1f posDelta=%.1f",
                    rName, headY, receptorPos.Y, posDelta
                ))
            end
        end

        if HeldNotes[rName] == note then
            if posDelta > (HeldPeakPosDelta[rName] or 0) then
                HeldPeakPosDelta[rName] = posDelta
            end
            laneCurState[rName] = { headY = headY, recY = receptorPos.Y, posDelta = posDelta }
            continue
        end

        if math.abs(headY - receptorPos.Y) < Threshold then
            local cur = pressCandidate[rName]
            if not cur or math.abs(headY - receptorPos.Y) < math.abs(cur.headY - cur.recY) then
                pressCandidate[rName] = {
                    note = note, b = b, headY = headY, recY = receptorPos.Y, posDelta = posDelta,
                }
            end
        end
    end

    -- Release: despawn
    for rName, heldNote in pairs(HeldNotes) do
        if not heldNote or not heldNote.Parent then
            forceReleaseLane(rName, "despawn")
        end
    end
    -- Release: hold-done / safety
    for rName, _ in pairs(HeldNotes) do
        local heldFor = now - (HeldPressTime[rName] or now)
        if heldFor > SAFETY_HELD then
            forceReleaseLane(rName, "safety")
        else
            local cur = laneCurState[rName]
            if cur then
                local peak = HeldPeakPosDelta[rName] or 0
                if peak >= HOLD_PEAK then
                    if cur.posDelta <= HOLD_DONE_POSDELTA and heldFor >= HOLD_MIN_HELD then
                        forceReleaseLane(rName, "hold-done")
                    end
                end
            end
        end
    end

    -- Press: HOLD vs TAP
    for rName, cand in pairs(pressCandidate) do
        local note = cand.note
        if FinishedNotes[note] then continue end
        if HeldKeys[rName] == note then continue end

        local isHold = (cand.posDelta or 0) >= HOLD_PEAK

        if isHold then
            if HeldKeys[rName] then
                local peak = HeldPeakPosDelta[rName] or 0
                local cur = laneCurState[rName]
                local activeHold = (peak >= HOLD_PEAK and cur and cur.posDelta > HOLD_DONE_POSDELTA)
                if activeHold then
                    continue
                end
                forceReleaseLane(rName, "swap")
            end

            HeldKeys[rName] = note
            HeldNotes[rName] = note
            HeldNoteKeys[rName] = cand.b
            HeldPressTime[rName] = now
            HeldPeakPosDelta[rName] = cand.posDelta or 0
            pcall(function() keypress(cand.b) end)
            if CFG.DebugParry then
                print(string.format(
                    "[Rhythm] PRESS HOLD lane=%s headY=%.1f posDelta=%.1f",
                    rName, cand.headY, cand.posDelta or 0
                ))
            end
        else
            if HeldKeys[rName] then
                local peak = HeldPeakPosDelta[rName] or 0
                local cur = laneCurState[rName]
                if peak >= HOLD_PEAK and cur and cur.posDelta > HOLD_DONE_POSDELTA then
                    continue
                end
                forceReleaseLane(rName, "swap")
            end

            FinishedNotes[note] = true
            local b = cand.b
            task.spawn(function()
                pcall(function() keypress(b) end)
                task.wait(0.05)
                pcall(function() keyrelease(b) end)
            end)
            if CFG.DebugParry then
                print(string.format(
                    "[Rhythm] PRESS TAP lane=%s headY=%.1f posDelta=%.1f",
                    rName, cand.headY, cand.posDelta or 0
                ))
            end
        end
    end

    for n, _ in pairs(FinishedNotes) do
        if not n or not n.Parent then
            FinishedNotes[n] = nil
            DebuggedNotes[n] = nil
        end
    end
end

-- Falling pieces are called note template
-- Lanes are numbered

-- ==========================================================
-- SECTION BUILDERS
-- ==========================================================

local function CreateAutoPlaySection()
    AutoplaySection:Info("Rhythm minigame auto-hit (Syndicatus). 4-lane: Z X , .  |  2-lane: F J")
    AutoPlayToggle = AutoplaySection:Toggle("Rhythm Auto-Hit", CFG.AutoPlay, function(on)
        CFG.AutoPlay = on and true or false
        if not on then
            -- release stuck keys immediately
            pcall(function()
                for rName in pairs(HeldNotes) do
                    forceReleaseLane(rName, "toggle-off")
                end
            end)
        end
        pcall(function()
            UI_Library:Notify("Rhythm", on and "Auto-Hit ON" or "Auto-Hit OFF")
        end)
    end)
    AutoplaySection:Info("Turn ON only during the rhythm minigame. Works with holds + taps.")
end

-- 1. Auto Parry Settings Section
local function CreateAPSection()
    AP_Section:Label("You have to press X in order to target someone or turn on Auto Target Nearest")

    AutoParryToggle = AP_Section:Toggle("Auto Parry", CFG.AutoParry, function(on)
        CFG.AutoParry = on and true or false
    end)
    pcall(function()
        AutoParryToggle:AddKeybind(tostring(CFG.APKeybind or "g"), "Toggle")
    end)

    -- Backup keybind mirror. INS-UI's AddKeybind may flip the toggle's visual
    -- without firing the user callback (varies per executor), which strands
    -- CFG.AutoParry. We mirror the toggle's visual state into CFG after the
    -- press — covers all three cases:
    --   INS fires callback      → CFG already set, mirror is a no-op
    --   INS flips visual only   → mirror reads visual, writes CFG
    --   INS does nothing        → mirror detects no change, flips CFG + visual
    pcall(function()
        if _G.__Lolbeans67AP_KeybindConn then
            _G.__Lolbeans67AP_KeybindConn:Disconnect()
            _G.__Lolbeans67AP_KeybindConn = nil
        end
    end)
    _G.__Lolbeans67AP_KeybindConn = UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local wanted = string.lower(tostring(CFG.APKeybind or "g"))
        if string.lower(input.KeyCode.Name) ~= wanted then return end

        local before = CFG.AutoParry and true or false
        task.defer(function()
            local v = safeToggleGet(AutoParryToggle, nil)
            if type(v) == "boolean" and v ~= before then
                CFG.AutoParry = v -- INS already flipped visual; mirror into CFG
            else
                -- INS didn't flip (or we can't read it) — do it ourselves
                CFG.AutoParry = not before
                safeToggleSet(AutoParryToggle, CFG.AutoParry)
            end
            if CONFIG_DEBUG then
                print("[Config] AP keybind → CFG.AutoParry=", CFG.AutoParry)
            end
        end)
    end)
    NoCrashState:AddConnection(_G.__Lolbeans67AP_KeybindConn)

    AutoDodgeToggle = AP_Section:Toggle("Auto Dodge", CFG.AutoDodge, function(on)
        CFG.AutoDodge = on and true or false
    end)
    UISettingRefs.AutoBoxingM2Toggle = AP_Section:Toggle("Auto Boxing M2", CFG.AutoBoxingM2, function(on)
        CFG.AutoBoxingM2 = on and true or false
        pcall(function()
            UI_Library:Notify(
                "Boxing M2",
                on and "AP runs block→dodge on Boxing M2" or "Manual — AP ignores Boxing M2"
            )
        end)
    end)
    AP_Section:Info("OFF = you parry/dodge Boxing M2 yourself. ON = AP block→dodge sequence.")
    AutoTargetNearest = AP_Section:Toggle("Auto Target Nearest", CFG.AutoTargetNearest, function(on)
        CFG.AutoTargetNearest = on and true or false
    end)
    MultiTarget = AP_Section:Toggle("Multiple Targets", CFG.MultiTarget, function(on)
        CFG.MultiTarget = on and true or false
    end)
    HeightToggle = AP_Section:Toggle("Height Multiplier (May crash some users)", CFG.HeightMultiplier, function(on)
        CFG.HeightMultiplier = on and true or false
    end)

    AP_Section:Divider("Conditions")

    TargetFacingYou = AP_Section:Toggle("Target facing you", CFG.TargetFacingYou, function(on)
        CFG.TargetFacingYou = on and true or false
    end)
    YouFacingTarget = AP_Section:Toggle("You facing target", CFG.YouFacingTarget, function(on)
        CFG.YouFacingTarget = on and true or false
    end)
end

-- Optional overlays stay off by default, so the combat base remains lightweight.
local function CreateOverlaySection()
    Overlay_Section:Label("Press X to cycle targets. Multiple Targets keeps the nearest three.")

    UISettingRefs.TargetMarkerToggle = Overlay_Section:Toggle("X Target Marker", NoCrashState.TargetMarkerEnabled, function(on)
        NoCrashState.TargetMarkerEnabled = on and true or false
    end)

    Overlay_Section:Divider("HP Display")
    UISettingRefs.OpponentHpToggle = Overlay_Section:Toggle("Opponent HP Bars", NoCrashState.OpponentHpEnabled, function(on)
        NoCrashState.OpponentHpEnabled = on and true or false
    end)
    UISettingRefs.PersonalHpToggle = Overlay_Section:Toggle("Personal HP Bar", NoCrashState.PersonalHpEnabled, function(on)
        NoCrashState.PersonalHpEnabled = on and true or false
    end)
    local range = Overlay_Section:Slider("HP View Range", 75, 5, 15, 200, " studs", function(value)
        NoCrashState.HpViewRange = value
    end)
    range:Set(NoCrashState.HpViewRange)
    UISettingRefs.HpRangeSlider = range
    Overlay_Section:Label("Compact name + HP only inside this range (no anim spam).")

    Overlay_Section:Divider("Combat ESP")
    UISettingRefs.CombatEspToggle = Overlay_Section:Toggle("Combat ESP (name / range)", NoCrashState.CombatEspEnabled, function(on)
        NoCrashState.CombatEspEnabled = on and true or false
        if UpdateTargetCharacters and TargetCharacters then
            local list = {}
            for _, c in ipairs(TargetCharacters) do table.insert(list, c) end
            pcall(function() UpdateTargetCharacters(list) end)
        end
    end)
    UISettingRefs.AnimDebugEspToggle = Overlay_Section:Toggle("Anim Debug ESP (IDs / timing)", NoCrashState.AnimDebugEspEnabled, function(on)
        NoCrashState.AnimDebugEspEnabled = on and true or false
        if on and not NoCrashState.CombatEspEnabled then
            NoCrashState.CombatEspEnabled = true
            safeToggleSet(UISettingRefs.CombatEspToggle, true)
        end
        if UpdateTargetCharacters and TargetCharacters then
            local list = {}
            for _, c in ipairs(TargetCharacters) do table.insert(list, c) end
            pcall(function() UpdateTargetCharacters(list) end)
        end
    end)
    Overlay_Section:Label("Anim Debug is the old noisy text (rbxassetid / timing / unknown). Keep OFF unless tuning.")
end

-- 2. Global Configurations Section
local function CreateGlobalConfigSection()
    ParryDebugToggle = Config_Section:Toggle("Debug Parry", CFG.DebugParry, function(on)
        CFG.DebugParry = on and true or false
    end)

    
    
    local Range = Config_Section:Slider("Auto Parry Range", 40, 1, 7, 80, "", function(v)
        AutoParryRange = v
    end)
    Range:Set(AutoParryRange)
    UISettingRefs.RangeSlider = Range

    local Probability = Config_Section:Slider("Probability To Parry", 100, 1, 1, 100, "%", function(v)
        ProbabilityToParry = v
    end)
    Probability:Set(ProbabilityToParry)
    UISettingRefs.ProbabilitySlider = Probability

    local DefaultSection = Config_Tab:Section("Default Configuration", "Left")
    
    local Offset = DefaultSection:Slider("Parry offset", 0, 0.01, -0.1, 0.1, "s", function(v)
        ParryOffset = v
    end)
    Offset:Set(ParryOffset)
    UISettingRefs.OffsetSlider = Offset

    DefaultSection:Label("Positive moves window forward (parry later), Negative moves it backward (parry earlier)")

    PingCompensateToggle = DefaultSection:Toggle("Ping Compensation", CFG.PingCompensate, function(on)
        CFG.PingCompensate = on and true or false
    end)
    DefaultSection:Label("Subtracts half of your ping value from the start time of ur reaction time. May improve performance.")
    
    DefaultSection:Divider("Window")
    
    local Window = DefaultSection:Slider("Default Parry Window", 0.3, 0.01, 0, 1, "", function(v)
        ParryWindow = v
    end)
    Window:Set(ParryWindow)
    UISettingRefs.WindowSlider = Window
    DefaultSection:Label("This is usually constant, don't change this.")
end

-- 3. Folders Section
local function CreateFoldersSection()
    TargetPool_Text = Folders_Section:Label("Target Pool: NO TARGETS FOUND") 

    local folders = GetAllFoldersInWorkspace()

    local Range = Folders_Section:Slider("Max Cycle Range", 10, 1, 7, 50, "", function(v)
        MaxCycleRange = v
    end)
    Range:Set(MaxCycleRange)
    UISettingRefs.CycleRangeSlider = Range

    UISettingRefs.IncludeLocalToggle = Folders_Section:Toggle("Include Local Character", CFG.IncludeLocalCharacter, function(on)
        IncludeLocalCharacter = on and true or false
        CFG.IncludeLocalCharacter = IncludeLocalCharacter
        UpdateTargetPoolSection()
    end)

    local FolderCombo = Folders_Section:Dropdown("Live Folder", nil, folders, false, function(list)
        SelectedFolder = list[1]
        UpdateTargetPoolSection()
    end)

    if game.Workspace:FindFirstChild("Players") then  
        FolderCombo:Set({"Players"})
    elseif game.Workspace:FindFirstChild("Live") then 
        FolderCombo:Set({"Live"})
    end

    print("[UI] Folders Section Created")
end

-- 4. Logging & Clipboard Section
local function CreateClipboardSection()
    LoggedText = ClipboardSection:Label("Logged Ids: ?")
    IgnoredText = ClipboardSection:Label("Ignored Ids: ?")

    local elements = {
        {
            Type = "Toggle",
            Name = "Damage Logs",
            Default = false,
            Callback = function(on)
                ToggleDamageLogger(on)
            end
        },
        {
            Type = "Toggle",
            Name = "Add unknowns to ignore and copy ignore list",
            Default = false,
            Keybind = "v",
            Callback = function(on, instance) 
                SetClipboardIgnoreList()
                AnimationsLoggedCache = {}
                AnimationsLoggedOrder = {}
                UpdateClipboardSection()
            end
        },
        {
            Type = "Toggle",
            Name = "Copy to clipboard",
            Keybind = "c",
            Callback = function()
                SetClipboardLoggedCache()
            end
        },
        {
            Type = "Toggle",
            Name = "Clear animation cache",
            Keybind = "k",
            Callback = function()
                AnimationsLoggedCache = {}
                AnimationsLoggedOrder = {}
                UpdateClipboardSection()
            end
        }
    }

    for _, config in ipairs(elements) do
        local instance

        if game.PlaceId == 128736949265057 then 
            config.Type = "Button"
        end

        if config.Type == "Toggle" then
            instance = ClipboardSection:Toggle(config.Name, config.Default, function(on)
                if on then  
                    config.Callback(on, instance)                    
                end
                instance:Set(false) 
            end)

            if config.Keybind then
                instance:AddKeybind(config.Keybind, "Toggle")
            end

        elseif config.Type == "Button" then
            instance = ClipboardSection:Button(config.Name, config.Callback)
        end
    end
end

-- 5. Profiles Section (Syndicatus-style multi-config)
local function CreateFilesSection()
    Files_Section:Info("Game: " .. tostring(GameName))
    Files_Section:Info("Profiles save as .lua in " .. PROFILE_FOLDER .. "/  (legacy .json still read)")
    Files_Section:Info("Type a name or select one → Save overwrites that profile.")

    -- Menu open/close key — keep handle so save/load can read/write the pill
    pcall(function()
        MenuKeybindRef = Files_Section:Keybind(
            "Menu Toggle Key",
            tostring(CFG.MenuKey or "p"),
            function(key)
                local k = writeMenuKey(key)
                pcall(function()
                    UI_Library:Notify("Menu", "Toggle key → " .. tostring(k):upper())
                end)
            end
        )
    end)
    Files_Section:Info("Click the key pill, press a key to rebind menu open/close. Saved with profiles.")

    local NameLabel = Files_Section:Label("Will save as: " .. currentProfileName)
    local ConfigListLabel = Files_Section:Label("Saved: (none)")
    local ProfileDrop = nil
    local _refreshingDrop = false

    local function setSaveName(t, silent)
        local n = sanitizeProfileName(t)
        if not n then
            if not silent then UI_Library:Notify("Profiles", "Invalid name") end
            return false
        end
        currentProfileName = n
        pcall(function() NameLabel:SetText("Will save as: " .. n) end)
        return true
    end

    local function refreshDrop(preferName)
        if _refreshingDrop then return end
        _refreshingDrop = true
        pcall(function()
            local p = listProfiles()
            -- Prefer explicit name (post-save), then current selection / label — never wipe to empty
            local keep = preferName or selectedConfig or currentProfileName
            if type(keep) ~= "string" or keep == "" then
                keep = "Default"
            end

            if ProfileDrop then
                pcall(function() ProfileDrop.Choices = p end)
                pcall(function() if ProfileDrop.UpdateChoices then ProfileDrop:UpdateChoices(p) end end)
                pcall(function() if ProfileDrop.Refresh then ProfileDrop:Refresh(p) end end)
                pcall(function()
                    if ProfileDrop.ClearChoices and ProfileDrop.AddChoice then
                        ProfileDrop:ClearChoices()
                        for _, n in ipairs(p) do ProfileDrop:AddChoice(n) end
                    end
                end)

                local found = false
                for _, n in ipairs(p) do
                    if n == keep then found = true break end
                end
                -- Keep the name even if scan is briefly lagging; only fall back when keep is useless
                if found then
                    selectedConfig = keep
                elseif keep ~= "Default" and keep ~= "" and keep ~= "none" then
                    selectedConfig = keep  -- stay on saved name
                else
                    selectedConfig = p[1] or "Default"
                end
                currentProfileName = selectedConfig

                pcall(function() ProfileDrop.Value = { selectedConfig } end)
                pcall(function() if ProfileDrop.Set then ProfileDrop:Set(selectedConfig) end end)
                pcall(function() if ProfileDrop.SetValue then ProfileDrop:SetValue(selectedConfig) end end)
            end

            pcall(function() NameLabel:SetText("Will save as: " .. tostring(selectedConfig)) end)
            pcall(function()
                if NameBox then
                    if type(NameBox.item) == "table" then NameBox.item.value = selectedConfig end
                    if type(NameBox.Set) == "function" then NameBox:Set(selectedConfig) end
                end
            end)

            if ConfigListLabel then
                local real = {}
                for _, n in ipairs(p) do
                    if profileSourceMap[n] then table.insert(real, n) end
                end
                local msg = (#real == 0) and "Saved: (none)" or ("Saved: " .. table.concat(real, " | "))
                pcall(function() ConfigListLabel:SetText(msg) end)
            end
        end)
        _refreshingDrop = false
    end

    -- Name input — INS Textbox(label, default, callback). Callback fires on commit.
    local NameBox = nil
    do
        local ok, handle = pcall(function()
            return Files_Section:Textbox("Config Name", tostring(currentProfileName or ""), function(t)
                setSaveName(t, false)
            end)
        end)
        if ok and handle then
            NameBox = handle
        else
            Files_Section:Info("Textbox unavailable — type name via dropdown selection")
        end
    end

    ProfileDrop = Files_Section:Dropdown("Load / Delete target", nil, listProfiles(), false, function(l)
        if _refreshingDrop then return end
        local s = l
        if type(l) == "table" then
            s = l[1] or l.Value or l.Selected or l.Name
        end
        if type(s) == "string" and #s > 0 then
            selectedConfig = s
            setSaveName(s, true)
            -- Keep name box in sync with selection (avoids stale text on Save)
            pcall(function()
                if NameBox then
                    if type(NameBox.item) == "table" then NameBox.item.value = s end
                    if type(NameBox.Set) == "function" then NameBox:Set(s) end
                end
            end)
        end
    end)
    pcall(function()
        if ProfileDrop and ProfileDrop.SetRefresh then
            ProfileDrop:SetRefresh(listProfiles)
        end
    end)

    Files_Section:Button("Save Current", function()
        -- Name priority (dropdown selection wins — don't let empty/stale textbox wipe it):
        -- 1) selectedConfig if real
        -- 2) currentProfileName
        -- 3) Config Name textbox (only if non-empty and not "none")
        local function isUsefulName(s)
            if type(s) ~= "string" then return false end
            local t = s:match("^%s*(.-)%s*$") or ""
            if t == "" or t:lower() == "none" or t:lower() == "nil" then return false end
            return true
        end

        local name = nil
        if isUsefulName(selectedConfig) and selectedConfig ~= "Default" then
            name = sanitizeProfileName(selectedConfig)
        end
        if not name and isUsefulName(currentProfileName) then
            name = sanitizeProfileName(currentProfileName)
        end
        if not name then
            pcall(function()
                if NameBox then
                    local t = nil
                    if type(NameBox.item) == "table" then t = NameBox.item.value end
                    if (not t or t == "") and type(NameBox.Get) == "function" then t = NameBox:Get() end
                    if isUsefulName(t) then name = sanitizeProfileName(t) end
                end
            end)
        end
        if not name and selectedConfig == "Default" then
            name = "Default"
        end
        if not name then
            UI_Library:Notify("Profiles", "Type a config name, or pick one in the dropdown")
            return
        end

        local isOverwrite = profileSourceMap[name] ~= nil
        currentProfileName = name
        selectedConfig = name
        pcall(function() NameLabel:SetText("Will save as: " .. name) end)
        pcall(function()
            if NameBox then
                if type(NameBox.item) == "table" then NameBox.item.value = name end
                if type(NameBox.Set) == "function" then NameBox:Set(name) end
            end
        end)

        local payload = buildProfilePayload()
        local savedPath, err = saveProfile(name, payload)
        if not savedPath then
            UI_Library:Notify("Profiles", "Save FAILED: " .. tostring(err or "writefile?"))
            print("[Profiles] Save FAILED", name, "err=", err, "log=", LAST_SAVE_LOG and LAST_SAVE_LOG.err)
            return
        end

        -- Keep this name selected after refresh (do not snap to Default/none)
        selectedConfig = name
        currentProfileName = name
        listProfiles()
        refreshDrop(name)
        local bytes = (LAST_SAVE_LOG and LAST_SAVE_LOG.bytes) or 0
        local msg = isOverwrite
            and string.format("Overwrote: %s (%d bytes)", name, bytes)
            or string.format("Saved: %s (%d bytes)", name, bytes)
        UI_Library:Notify("Profiles", msg)
        print("[Profiles]", isOverwrite and "OVERWRITE" or "NEW", name, "→", savedPath, "bytes=", bytes)
    end)

    Files_Section:Button("Load Selected", function()
        if not selectedConfig or selectedConfig == "" then
            UI_Library:Notify("Profiles", "Pick a config in the dropdown first")
            return
        end

        -- Built-in Default (no file) → reset timings + keep current UI defaults
        if selectedConfig == "Default" and not profileSourceMap["Default"] then
            resetTimingsToOriginal()
            UI_Library:Notify("Profiles", "Loaded built-in Default timings")
            return
        end

        local data, err = loadProfile(selectedConfig)
        if not data then
            UI_Library:Notify("Profiles", "Load failed: " .. tostring(err or selectedConfig))
            print("[Profiles] Load FAILED", selectedConfig, "err=", err)
            return
        end

        local tCount, sCount = applyProfilePayload(data)
        setSaveName(selectedConfig, true)
        UI_Library:Notify(
            "Profiles",
            string.format("Loaded: %s (%d timings, %d settings)", selectedConfig, tCount, sCount)
        )
    end)

    Files_Section:Button("Delete Selected", function()
        if not selectedConfig or selectedConfig == "" then
            UI_Library:Notify("Profiles", "Nothing selected")
            return
        end
        if selectedConfig == "Default" and not profileSourceMap["Default"] then
            UI_Library:Notify("Profiles", "Default is built-in")
            return
        end
        if not profileSourceMap[selectedConfig] then
            UI_Library:Notify("Profiles", "Not a saved file: " .. tostring(selectedConfig))
            return
        end
        local deletedName = selectedConfig
        deleteProfile(selectedConfig)
        selectedConfig = "Default"
        setSaveName("Default", true)
        refreshDrop()
        UI_Library:Notify("Profiles", "Deleted: " .. deletedName)
    end)

    Files_Section:Button("Refresh List", function()
        refreshDrop()
        UI_Library:Notify("Profiles", "List refreshed")
    end)

    Files_Section:Button("Reset Timings (built-in)", function()
        resetTimingsToOriginal()
        UI_Library:Notify("Profiles", "Timings reset to built-in defaults")
    end)

    Files_Section:Divider("Debug")
    Files_Section:Toggle("Config Debug Logs", false, function(on)
        CONFIG_DEBUG = on and true or false
        print("[Config] debug=" .. tostring(CONFIG_DEBUG))
    end)
    Files_Section:Button("Dump CFG to console", function()
        print("[CFG]", "AutoParry=", CFG.AutoParry, "AutoDodge=", CFG.AutoDodge,
            "AutoTargetNearest=", CFG.AutoTargetNearest, "MultiTarget=", CFG.MultiTarget,
            "HeightMultiplier=", CFG.HeightMultiplier, "TargetFacingYou=", CFG.TargetFacingYou,
            "YouFacingTarget=", CFG.YouFacingTarget, "DebugParry=", CFG.DebugParry,
            "PingCompensate=", CFG.PingCompensate, "AutoPlay=", CFG.AutoPlay,
            "APKeybind=", CFG.APKeybind)
        print("[Numeric]", "AutoParryRange=", AutoParryRange, "MaxCycleRange=", MaxCycleRange,
            "ParryWindow=", ParryWindow, "ProbabilityToParry=", ProbabilityToParry,
            "ParryOffset=", ParryOffset, "DefaultReactionTime=", DefaultReactionTime,
            "BlockHoldTime=", BlockHoldTime, "IncludeLocalCharacter=", IncludeLocalCharacter)
        print("[Overlays]", "TargetMarker=", NoCrashState.TargetMarkerEnabled,
            "OpponentHp=", NoCrashState.OpponentHpEnabled,
            "PersonalHp=", NoCrashState.PersonalHpEnabled,
            "CombatEsp=", NoCrashState.CombatEspEnabled,
            "AnimDebugEsp=", NoCrashState.AnimDebugEspEnabled,
            "HpViewRange=", NoCrashState.HpViewRange)
        print("[LastSave]", LAST_SAVE_LOG and LAST_SAVE_LOG.ok, LAST_SAVE_LOG and LAST_SAVE_LOG.path,
            LAST_SAVE_LOG and LAST_SAVE_LOG.bytes, LAST_SAVE_LOG and LAST_SAVE_LOG.err)
    end)

    -- Also keep legacy INS autosave as optional convenience
    Files_Section:Divider("Legacy INS")
    Files_Section:Button("INS LoadConfig", function()
        pcall(function() UI_Library:LoadConfig(GameName) end)
        UI_Library:Notify("Legacy", "INS LoadConfig called")
    end)
    Files_Section:Button("INS SaveConfig", function()
        pcall(function() UI_Library:SaveConfig(GameName) end)
        UI_Library:Notify("Legacy", "INS SaveConfig called")
    end)

    refreshDrop()
end

-- 6. Per-style button selector (Syndicatus-style Timings UI)
-- Left: click a style → Right: only that style's reaction-time sliders
local function CreateGroupSliders()
    local StylePickSec = Config_Tab:Section("Style Editor", "Left")
    local StyleSliderSec = Config_Tab:Section("Reaction Times", "Right")

    -- Collect unique style names
    local styleNames = {}
    local stylesSeen = {}
    for _, info in pairs(GameConfig or {}) do
        local style = info.Style
        if style and not stylesSeen[style] then
            stylesSeen[style] = true
            table.insert(styleNames, style)
        end
    end
    table.sort(styleNames)

    local currentStyleEdit = styleNames[1] or "KarateAnims"
    local MAX_SLOTS = 16
    local slots = {}
    local StyleTitleLabel = nil
    local StyleHintLabel = nil

    -- Pre-create reusable slider slots (rebound when style changes)
    for i = 1, MAX_SLOTS do
        local slotIndex = i
        local sl = StyleSliderSec:Slider("—", 0, 0.001, 0, 1, "s", function(v)
            local s = slots[slotIndex]
            if s and s.boundInfo then
                s.boundInfo.ReactionTime = v
            end
        end)
        sl:Set(0)
        slots[i] = { slider = sl, boundId = nil, boundInfo = nil, name = "—" }
    end

    local function setSlotName(slot, text)
        local sl = slot.slider
        for _, m in pairs({ "SetText", "SetName", "SetTitle", "SetLabel" }) do
            pcall(function()
                if sl[m] then sl[m](sl, text) end
            end)
        end
        for _, p in pairs({ "Title", "Name", "Text" }) do
            pcall(function()
                if rawget(sl, p) ~= nil then sl[p] = text end
            end)
        end
        slot.name = text
    end

    local function animSortRank(name)
        name = tostring(name or "")
        if name:find("%(A%)") then return 2, name end
        if name:find("%(B%)") then return 3, name end
        if name:find("Feint") then return 4, name end
        -- Natural M1 order: 1st, 2nd, 3rd, 4th, then M2/other
        local m1 = name:match("(%d)stM1") or name:match("(%d)ndM1") or name:match("(%d)rdM1") or name:match("(%d)thM1")
        if m1 then return 1, tonumber(m1) or 99, name end
        if name:find("M2") or name == "Heavy" then return 5, 0, name end
        return 6, 0, name
    end

    bindStyle = function(styleName)
        if not styleName or styleName == "" then return end
        currentStyleEdit = styleName
        currentStyleEditName = styleName

        local collected = {}
        for id, info in pairs(GameConfig) do
            if info.Style == styleName then
                table.insert(collected, { id = id, info = info })
            end
        end

        table.sort(collected, function(a, b)
            local ra, xa, na = animSortRank(a.info.DisplayName)
            local rb, xb, nb = animSortRank(b.info.DisplayName)
            if ra ~= rb then return ra < rb end
            if type(xa) == "number" and type(xb) == "number" and xa ~= xb then return xa < xb end
            return tostring(na) < tostring(nb)
        end)

        local nice = styleName:gsub("Anims", "")
        if StyleTitleLabel then
            pcall(function()
                StyleTitleLabel:SetText(string.format("EDITING: %s  (%d anims)", nice, #collected))
            end)
        end
        if StyleHintLabel then
            pcall(function()
                StyleHintLabel:SetText("Right side shows " .. nice .. " only")
            end)
        end

        -- Clear previous AnimationIdSliders entries that pointed at these slots
        for id, slider in pairs(AnimationIdSliders) do
            for i = 1, MAX_SLOTS do
                if slots[i].slider == slider then
                    AnimationIdSliders[id] = nil
                end
            end
        end

        for i = 1, MAX_SLOTS do
            local slot = slots[i]
            local entry = collected[i]

            if entry then
                local info = entry.info
                local prefix = (info.Blackflash and "Blackflash ")
                    or (info.Awakened and "Awakened ")
                    or ""
                local label = prefix .. (info.DisplayName or ("Anim " .. i))
                if info.Heavy or (info.DisplayName and tostring(info.DisplayName):find("M2")) then
                    label = label .. " [HEAVY]"
                end
                if info.ParryFunction then
                    label = label .. " [FN]"
                end

                slot.boundId = entry.id
                slot.boundInfo = info
                AnimationIdSliders[entry.id] = slot.slider
                setSlotName(slot, label)
                pcall(function()
                    slot.slider:Set(info.ReactionTime or DefaultReactionTime)
                end)
                pcall(function()
                    if slot.slider.SetVisible then slot.slider:SetVisible(true) end
                end)
            else
                slot.boundId = nil
                slot.boundInfo = nil
                setSlotName(slot, "—")
                pcall(function() slot.slider:Set(0) end)
                pcall(function()
                    if slot.slider.SetVisible then slot.slider:SetVisible(false) end
                end)
            end
        end

        UI_Library:Notify("Timings", "Now editing: " .. nice)
    end

    StylePickSec:Info("Click a style → right side shows ONLY that style's timings")
    StyleTitleLabel = StylePickSec:Label("EDITING: —")
    StyleHintLabel = StylePickSec:Label("Pick a style below")

    StylePickSec:Slider("Default RT", DefaultReactionTime, 0.001, 0, 0.5, "s", function(v)
        DefaultReactionTime = v
    end):Set(DefaultReactionTime)

    StylePickSec:Button("Reset Current Style", function()
        for i = 1, MAX_SLOTS do
            local slot = slots[i]
            if slot.boundId and OriginalTimings[slot.boundId] then
                local rt = OriginalTimings[slot.boundId]
                slot.boundInfo.ReactionTime = rt
                pcall(function() slot.slider:Set(rt) end)
            end
        end
        UI_Library:Notify("Timings", "Reset " .. (currentStyleEdit:gsub("Anims", "") or "?"))
    end)

    StylePickSec:Info("--- Styles ---")

    -- Button grid: up to 3 style buttons per row (AddButton when supported)
    do
        local COLS = 3
        local i = 1
        while i <= #styleNames do
            local s1 = styleNames[i]
            local row = StylePickSec:Button(s1:gsub("Anims", ""), function()
                bindStyle(s1)
            end)
            for c = 1, COLS - 1 do
                local idx = i + c
                if idx <= #styleNames and row and row.AddButton then
                    local sN = styleNames[idx]
                    pcall(function()
                        row:AddButton(sN:gsub("Anims", ""), function()
                            bindStyle(sN)
                        end)
                    end)
                elseif idx <= #styleNames then
                    -- Fallback: separate button if AddButton isn't available
                    local sN = styleNames[idx]
                    StylePickSec:Button(sN:gsub("Anims", ""), function()
                        bindStyle(sN)
                    end)
                end
            end
            i = i + COLS
        end
    end

    -- Initial bind
    if #styleNames > 0 then
        bindStyle(currentStyleEdit)
    end
end

-- ==========================================================
-- UI INITIALIZATION
-- ==========================================================
local function InitializeUI()
    CreateAutoPlaySection()
    CreateAPSection()
    CreateGlobalConfigSection()
    CreateFoldersSection()
    CreateOverlaySection()
    CreateClipboardSection()
    CreateFilesSection()
    CreateGroupSliders()
end

InitializeUI()
end
__LB67_UIAndRhythm()

UpdateClipboardSection()

-- ==========================================
local PARRY_DISTANCE = 15 
local PARRY_COOLDOWN = 0.1

local activeOrbs = {}
local lastParryAt = 0

local function GetLocalHRP()
    local localChar = LocalPlayer.Character
    local HRP = localChar and localChar:FindFirstChild("HumanoidRootPart")
    if not HRP then return nil end 
    return HRP
end

local function checkRange(studs, origin)
    local hrp = GetLocalHRP()
    if not hrp or not origin then return false end
    return (hrp.Position - origin.Position).Magnitude < studs
end

local orbSpawnTimes = {} 

local function ListenForOrbs()
    print("[Orbs] Listening for Ardour balls")

    return RunService.Heartbeat:Connect(function()
        if tick() - lastParryAt < 0.08 then return end

        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local thrownFolder = workspace:FindFirstChild("Thrown")
        if not thrownFolder then return end

        local myPosition = hrp.Position

        for _, orb in ipairs(thrownFolder:GetChildren()) do
            if (orb.Name == "ArdourBall2" or orb.Name == "ArdourBall") and orb:IsA("BasePart") then
                if (myPosition - orb.Position).Magnitude <= PARRY_DISTANCE then
                    lastParryAt = tick()
                    local t = os.clock()
                    BlockStart(t, 0.15)
                    BlockEnd()
                    break
                end
            end
        end
    end)
end

-- Start listening
if game.PlaceId == 8668476218 or game.PlaceId == 134572803901609 then  
    NoCrashState:AddConnection(ListenForOrbs())
end

-- ==========================================
-- Configs 
-- ==========================================

local ParryKey = string.byte("F")
local DodgeKey = string.byte("Q")

local KeyHeld = false
local TriggerParry = false
local ReleaseDeadline = 0

local Stunned = false
local currentStunToken = 0

local AnimationTracker = AnimationTrackerClass.new(IgnoreIds)
local LocalTracker = AnimationTrackerClass.new(IgnoreIds)

local DamageLogs = false
-- IncludeLocalCharacter declared earlier (with CFG) so profile/UI share one binding

local connection = nil
local previousHealth = 100
local lastCharacter = nil

local SelectAllMode = true
local TargetCharacters = {}
local EspTrackers = {}

local CurrentIndex = 1
local COLOR_WHITE = Color3.fromRGB(255, 255, 255)
local COLOR_RED = Color3.fromRGB(255, 50, 50)
local COLOR_GREEN = Color3.fromRGB(50, 255, 50)

local AnimationRegistry = {}
local LastPendingRegData = nil
local InputRegisteredTime = nil
local ParryRegisteredTime = nil
local InputLatency = 0 -- (Parry - Input)

-- Per-frame animation cache so we don't call Tracker:Update multiple times on the same character
local FrameAnimCache = {}
local FrameCacheClock = 0

-- True when character has Humanoid+Animator+HRP (avoids AnimationTracker spam / dead updates)
local function instanceHasAddress(inst)
    if not inst then return false end
    -- Instances are userdata — never rawget them
    local okA, vA = pcall(function() return inst.Address end)
    if okA and type(vA) == "number" and vA ~= 0 then return true end
    if type(getaddress) == "function" then
        local ok, v = pcall(getaddress, inst)
        if ok and type(v) == "number" and v ~= 0 then return true end
    end
    return false
end

local function characterTrackable(character)
    if not character or character.Parent == nil then return false end
    local hum = character:FindFirstChildOfClass("Humanoid")
        or character:FindFirstChildWhichIsA("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if not character:FindFirstChild("HumanoidRootPart") then return false end
    local animator = hum:FindFirstChildOfClass("Animator")
        or hum:FindFirstChildWhichIsA("Animator")
    if not animator then return false end
    -- Address is optional here; Update wrapper validates memory Address + silences library spam
    return true
end

local function GetActiveAnimationsCached(character, tracker)
    local now = os.clock()
    if now ~= FrameCacheClock then
        table.clear(FrameAnimCache)
        FrameCacheClock = now
    end

    local cached = FrameAnimCache[character]
    if cached then
        return cached
    end

    -- Gate: library prints "Failed to resolve Animator." and returns nil when missing —
    -- never call Update until the character is fully trackable.
    if not characterTrackable(character) then
        FrameAnimCache[character] = {}
        return FrameAnimCache[character]
    end

    local active = tracker:Update(character) or {}
    FrameAnimCache[character] = active
    return active
end

local function ResetCombatTrackers(reason)
    pcall(function()
        if LocalTracker and type(LocalTracker._cachedTracks) == "table" then
            table.clear(LocalTracker._cachedTracks)
        end
    end)
    pcall(function()
        if AnimationTracker and type(AnimationTracker._cachedTracks) == "table" then
            table.clear(AnimationTracker._cachedTracks)
        end
    end)
    table.clear(FrameAnimCache)
    table.clear(AnimationRegistry)
    LastPendingRegData = nil
    InputRegisteredTime = nil
    ParryRegisteredTime = nil
    KeyHeld = false
    Stunned = false
    if ParryState then
        CurrentParryState = ParryState.IDLE
    end
    if reason and CFG and CFG.DebugParry then
        print("[Sharingan] combat trackers reset:", reason)
    end
end


local ParryState = {
    IDLE = "idle",

    INPUT_PENDING = "input_pending",   -- F was pressed locally, waiting for animation to appear
    PARRYING = "parrying",             -- Animation just appeared
    PARRYINGFAILED = "parryingfailed",       -- Animation didn't appear (Happens when you're on parry cooldown)

    STUNNED = "stunned",
    WINDOW_EXCEEDED = "window_exceeded", -- If you exceed the window cuz ur not targeting or ur

    SUCCESS = "parrysuccess"       -- Parrying animation was detected so its parrying right now
}

local CurrentParryState = ParryState.IDLE

local function ResetParryState()
    KeyHeld = false
    ReleaseDeadline = 0
    BlockEnd()
end

local function TransitionToState(newState)
    if CFG.DebugParry then
        print(string.format("[Parry] %s -> %s", CurrentParryState, newState))
    end
    CurrentParryState = newState
end

-- ==========================================
-- Helpers
-- ==========================================

local function ToggleDamageLogger(state)
    if not state then
        if connection then
        connection:Disconnect()
        connection = nil end
        print("[Logger] Heartbeat damage logger DISABLED.")
        return
    end

    if connection then return end -- Prevent duplicate connections
    print("[Logger] Heartbeat damage logger ACTIVE.")
    
    connection = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if not hum then return end 

        if lastCharacter and (char.Address ~= lastCharacter.Address) then
            lastCharacter = char
            previousHealth = hum.Health
        end
        local currentHealth = hum.Health
        if currentHealth < previousHealth then
            local damageTaken = previousHealth - currentHealth
            
            if #TargetCharacters then
                local activeAnimations = AnimationTracker:Update(TargetCharacter) or {}
                
                
                for _, anim in activeAnimations do
                    if not anim.AnimationId or anim.TimePosition < 0.1 or anim.TimePosition > 0.7 then continue end 
                    local assetId = tostring(anim.AnimationId)
                    local poolData = GameConfig[assetId]
                    warn(string.format(
                        "[HIT] %d DMG | Anim: %s (%s) %s | Frame Time: %.3f", 
                        damageTaken, 
                        poolData and poolData.DisplayName or anim.Name or "Unknown",
                        assetId, 
                        poolData and poolData.Style or "",
                        anim.TimePosition or 0
                    ))
                end
            end
        end
        previousHealth = currentHealth
    end)
    NoCrashState:AddConnection(connection)
end

-- ==========================================

-- Luau register limit (200 locals/function): combat path runs in its own function scope
local function __LB67_CombatRuntime()
-- Parry Core Logic
-- ==========================================


local function GetHeightMultiplierForCharacter(TargetCharacter)
    local succ, data = pcall(function()
        local stateFolder = TargetCharacter and TargetCharacter:FindFirstChild("PlayerData")    
        return stateFolder:GetAttribute("CurrentHeight")
    end)
    if succ then  
        return data
    else
     --   print("failed to get height")
        return 1
    end
end


function Dodge(force)
    -- force=true: used by Boxing M2 sequence (bypasses nothing critical; always input)
    BlockEnd()
    for _ = 1, 4 do
        keypress(DodgeKey)
        keyrelease(DodgeKey)
    end
end

function BlockStart(StartTime, HoldFor)
    if not StartTime then
        if CFG.DebugParry then
            warn("BlockStart: missing start time")
        end
        return
    end

    if CurrentParryState ~= ParryState.IDLE then
        TransitionToState(ParryState.IDLE)
    end

    HoldFor = HoldFor or BlockHoldTime
    ReleaseDeadline = StartTime + HoldFor
    KeyHeld = true

    if CFG.AutoParry then
        keypress(ParryKey)
    end
end

function BlockEnd()
    KeyHeld = false
    if CFG.AutoParry then
        keyrelease(ParryKey)
    end
end


-- ==========================================
-- STATE MACHINE
-- ==========================================


--                  ==[Input State]==
-- Local F keypress
local function OnInputF()

    if CurrentParryState == ParryState.IDLE then
        InputRegisteredTime = os.clock()
        TransitionToState(ParryState.INPUT_PENDING)
    else
    --    print("F was pressed while machine wasnt idle")
    end
end


local function DebugParry()
-- 1. Network Variables (These never rely on the parry window data, so we always calculate them)
    local WeActuallyBlockedAt = ParryRegisteredTime
    local WeWantedToBlockAt = InputRegisteredTime
    local TimeTheServerReceived = InputLatency / 2

    if LastPendingRegData then
        -- 2. Animation Variables (Only extracted if the data actually exists)
        local AnimationStartTime = LastPendingRegData.StartTime
        local BlockStart = LastPendingRegData.BlockStart
        local BlockExpire = LastPendingRegData.BlockExpire
        
        -- Relative Offsets (How far into the animation the window is)
        local RelativeBlockStart = BlockStart - AnimationStartTime   -- e.g., 0.300s
        local RelativeBlockExpire = BlockExpire - AnimationStartTime -- e.g., 0.650s
        
        -- Timeline Calculations
        local ClientReactionTime = WeWantedToBlockAt - AnimationStartTime -- Relative to Anim Start (0)
        local ServerRelativeTime = (WeActuallyBlockedAt - TimeTheServerReceived) - AnimationStartTime -- Relative to Anim Start (0)
        
        local IsSuccess = (ClientReactionTime >= RelativeBlockStart and ClientReactionTime <= RelativeBlockExpire)        
        ----------------------------------------------------------------------
        -- FULL DIAGNOSTICS LOG (Data Exists)
        ----------------------------------------------------------------------
        print(string.format(
            "\n================ PARRY DIAGNOSTICS ================\n" ..
            "[NETWORK STATE]\n" ..
            "Total Input Latency:  %.3fs\n" ..
            "One-Way Server Delay: %.3fs\n" ..
            "---------------------------------------------------\n" ..
            "[ANIMATION TIMELINE]\n" ..
            "Target Parry Window:  %.3fs to %.3fs\n" ..
            "Pressed F At:    %.3fs\n" ..
            "Parry Registered At:  %.3fs (ONE-WAY)\n" ..
            "---------------------------------------------------\n" ..
            "[VERDICT]\n" ..
            "Status:               %s\n" ..
            "===================================================",
            InputLatency,
            TimeTheServerReceived,
            RelativeBlockStart, 
            RelativeBlockExpire,
            ClientReactionTime,
            ServerRelativeTime,
            IsSuccess and "[SUCCESS]" or "[MISSED WINDOW]"
        ))
    else
        ----------------------------------------------------------------------
        -- LATENCY ONLY DIAGNOSTICS LOG (No Parry Data)
        ----------------------------------------------------------------------
        print(string.format(
            "\n============ LATENCY ONLY DIAGNOSTICS ============\n" ..
            "[NETWORK STATE]\n" ..
            "Total Input Latency:  %.3fs\n" ..
            "One-Way Server Delay: %.3fs\n" ..
            "---------------------------------------------------\n" ..
            "[ANIMATION TIMELINE]\n" ..
            "No active parry window / registration data found.\n" ..
            "===================================================",
            InputLatency,
            TimeTheServerReceived
        ))
    end
end

-- Parrying animation detected
local function OnParryingAnimationSuccess()
    if CurrentParryState == ParryState.INPUT_PENDING then
        ParryRegisteredTime = os.clock()
        InputLatency = os.clock() - InputRegisteredTime

        if CFG.DebugParry then
            DebugParry()
        end
        
        TransitionToState(ParryState.PARRYING)
    end
end

-- Parrying window passed without parrying
local function OnParryingAnimationFailed()
    if CurrentParryState == ParryState.INPUT_PENDING then
        TransitionToState(ParryState.PARRYINGFAILED)
        TransitionToState(ParryState.IDLE)
    end
end


local StunToken = 0
local function OnStunned()
    if CurrentParryState ~= ParryState.STUNNED then 
        TransitionToState(ParryState.STUNNED)
    end

    StunToken += 1
    local MyToken = StunToken
    
    
    scheduler.delay(0.4, function()
        if MyToken == StunToken then 
            BlockEnd()
            TransitionToState(ParryState.IDLE)            
        end
    end)
end


local function OnSuccessfulParry()
    if CurrentParryState == ParryState.PARRYING then  

        local AnimId = LastPendingRegData.AnimationId
        local AttackConfig = GameConfig[AnimId]
        local ParryPressTime = tonumber(InputRegisteredTime - LastPendingRegData.StartTime)
        local EstimatedParryWindow = os.clock() - LastPendingRegData.StartTime
        
        -- SANITY CHECK happens when we evaludte outside of parrying
        if ParryPressTime > 1 or ParryPressTime < 0 then
        --    print("HERE", ParryPressTime, os.clock() - InputRegisteredTime, os.clock() - LastPendingRegData.StartTime)
        --    warn("AAAAAAA")
            return
        end
        
        -- NOTIFY UI
        UI_Library:Notify(
            "Parry Success", 
            string.format("%.3fs PT: %.3fs - %s %s", 
                ParryPressTime, 
                EstimatedParryWindow,
                AttackConfig.Style, 
                AttackConfig.DisplayName
            )
        )
        
        LastPendingRegData.LearnedParryTime = ParryPressTime
        LastPendingRegData.Success = true
        --LastPendingRegData.Processed = true

        -- CLEANUP
        --InputRegisteredTime = nil
        
        ResetParryState()
        TransitionToState(ParryState.SUCCESS)
        TransitionToState(ParryState.IDLE)
    else
        warn("Tried to evaluate outside of parrying")
        print(CurrentParryState)
    end
end

local function OnWindowExceeded()
    if CurrentParryState == ParryState.PARRYING then 
        TransitionToState(ParryState.WINDOW_EXCEEDED)
        TransitionToState(ParryState.IDLE)
    end
end

local function GetActiveAnimationsForCharacterAsDictionary(character)
    local returnTable = {}
    local activeAnimations = GetActiveAnimationsCached(character, LocalTracker)
    if not activeAnimations or #activeAnimations == 0 then return returnTable end

    for _, anim in ipairs(activeAnimations) do
        if anim.AnimationId then
            returnTable[anim.AnimationId] = anim
        end
    end

    return returnTable
end

local function ParryTask()
    local now = os.clock()

    if KeyHeld and now > ReleaseDeadline then
        BlockEnd()
    end

    if CurrentParryState == ParryState.INPUT_PENDING then
        local MaxLatency = 0.5
        local timePassed = now - (InputRegisteredTime or now)

        local activeAnims = {}
        if type(GetActiveAnimationsForCharacterAsDictionary) == "function" then
            local ok, result = pcall(GetActiveAnimationsForCharacterAsDictionary, LocalPlayer.Character)
            if ok and type(result) == "table" then
                activeAnims = result
            end
        end
        for _, anim in pairs(activeAnims) do
            if anim and ParryingAnimSet[anim.AnimationId] then
                if type(OnParryingAnimationSuccess) == "function" then
                    OnParryingAnimationSuccess()
                end
                break
            end
        end

        local stillHolding = false
        pcall(function() stillHolding = iskeypressed(ParryKey) and true or false end)
        if not stillHolding then
            if CFG.DebugParry then
                warn("F key was released before parrying animation appeared")
            end
            ResetParryState()
            TransitionToState(ParryState.IDLE)
            return
        end

        if timePassed > MaxLatency then
            if CFG.DebugParry then
                warn(string.format(
                    "Parrying animation didn't appear (likely CD) MAX: %.2f | TIME: %.2f",
                    MaxLatency,
                    timePassed
                ))
            end
            OnParryingAnimationFailed()
            TransitionToState(ParryState.IDLE)
        end

    elseif CurrentParryState == ParryState.PARRYING then
        if ParryRegisteredTime and now > (ParryRegisteredTime + ParryWindow + 0.3) then
            OnWindowExceeded()
        end
    end
end

-- ==========================================


local ParryLearningLog = {}  -- {[animId] = {TriggerTime, Style, DisplayName, Count}}

local function onLocalAnimationAdded(anim)
    local animId = anim.AnimationId
    if not animId then return end

    if ParriedAnimSet[animId] then
        OnSuccessfulParry()
        return
    end

    if ParryingAnimSet[animId] then
        if InputRegisteredTime then
            OnParryingAnimationSuccess()
        end
        return
    end

    if GameConfig[animId] then
        OnStunned()
    end
end

NoCrashState:AddConnection(LocalTracker.AnimationAdded:Connect(onLocalAnimationAdded))

local function LogAnimation(assetId, trackInfo)
    if not AnimationsLoggedCache[assetId] then
        AnimationsLoggedCache[assetId] = { Name = trackInfo.Name }
        table.insert(AnimationsLoggedOrder, assetId)
        UpdateClipboardSection()
    end
end


-- (GetActiveAnimationsForCharacterAsDictionary moved above ParryTask)

-- ==========================================
-- Parry Evaluation
-- ==========================================

local DodgeLockoutEnd = 0

local function ValidateLocalCharacter()
    local localCharacter = LocalPlayer and LocalPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    if not localRoot or Stunned then return nil end
    return localCharacter, localRoot
end

local function ValidateTargetCharacter(character)
    local targetRoot = character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return nil end
    return targetRoot
end

local function CheckCharacterDistance(localRoot, targetRoot)
    return (targetRoot.Position - localRoot.Position).Magnitude
end

local function UpdateCharacterESP(character, Distance)
    local inRange = Distance <= AutoParryRange
    local apOn = CFG.AutoParry

    -- Only touch ESP text when combat ESP is enabled
    if NoCrashState.CombatEspEnabled then
        local tracker = EspTrackers[character]
        if tracker and tracker.ChangeText then
            if not apOn then
                tracker:ChangeText("Name", character.Name .. " | AP OFF", COLOR_RED)
            elseif not inRange then
                tracker:ChangeText("Name", character.Name .. " | " .. math.floor(Distance) .. "m", COLOR_RED)
            else
                tracker:ChangeText("Name", character.Name .. " | " .. math.floor(Distance) .. "m", COLOR_GREEN)
            end
        end
    end

    return apOn and inRange
end

local function CalculateParryTiming(attackConfig, StartTime, Target)
    
    local optimalReactionTime = (attackConfig.ReactionTime or DefaultReactionTime)
    local HeightMultiplier = 1 
    if CFG.HeightMultiplier then  
       HeightMultiplier = GetHeightMultiplierForCharacter(Target)
    end

    local CompValue = 0
    if CFG.PingCompensate then
        CompValue = (GetPingValue() or 50) / 1000 * 0.5
        optimalReactionTime -= CompValue
    end

    local adjustedReactionTime = (optimalReactionTime * HeightMultiplier) + ParryOffset


    local parryWindowStart = adjustedReactionTime
    local parryWindowEnd = adjustedReactionTime + ParryWindow

    local ClockStart = StartTime + parryWindowStart
    local ClockEnd = StartTime + parryWindowEnd
    
    return ClockStart, ClockEnd
end

local ConstLatency = 0.018
local EXECUTE_DEBOUNCE = 0.5

local function UpdateAnimationRegistry(animKey, anim, now, currentTrackTime, attackConfig, TargetCharacter)

    if not AnimationRegistry[animKey] then
        local adjustedNow = now - ConstLatency -- - currentTrackTime
        local BlockStart, BlockExpire = CalculateParryTiming(attackConfig, adjustedNow, TargetCharacter)

        AnimationRegistry[animKey] = {
            StartTime = adjustedNow,
            Processed = false,
            CurrentClockTime = os.clock(),
            CurrentTrackTime = currentTrackTime,
            ReactionTime = attackConfig,
            Ignore = false,
            AnimationId = anim.AnimationId,
            DidALoop = false,
            BlockStart = BlockStart,
            BlockExpire = BlockExpire,
            RandomNum = math.random(1, 100),
            LastExecuteTime = 0, -- debounce timestamp
        }
    end
    
    local regData = AnimationRegistry[animKey]
    
    if regData.CurrentTrackTime and (currentTrackTime < regData.CurrentTrackTime) then
        local BlockStart, BlockExpire = CalculateParryTiming(attackConfig, now - currentTrackTime, TargetCharacter)
        
        regData.Processed = false
        regData.DidALoop = true
        if CFG.DebugParry then
            warn("Loop detected")
        end
        regData.BlockStart = BlockStart
        regData.BlockExpire = BlockExpire
        regData.StartTime = now - ConstLatency
    end
    
    regData.CurrentClockTime = os.clock()
    regData.CurrentTrackTime = currentTrackTime

    if LastPendingRegData == regData then
        LastPendingRegData = regData
    end

    return regData
end

local function CheckAnimationDirection(character, localCharacter, localRoot, targetRoot, attackConfig)
    if character.Address == localCharacter.Address then return true end
    
    local direction = (targetRoot.Position - localRoot.Position).Unit
    local distance = (targetRoot.Position - localRoot.Position).Magnitude
    local isHeavy = attackConfig.DisplayName == "M2" or attackConfig.DisplayName == "Heavy" or attackConfig.Heavy
  --  print(distance)
    
    if not isHeavy then -- and distance > 4 then  
        if CFG.TargetFacingYou and targetRoot.CFrame.LookVector:Dot(-direction) < 0.1 then return false end
        if CFG.YouFacingTarget and localRoot.CFrame.LookVector:Dot(direction) < 0.1 then return false end
    end
    
    return true
end

local function ExecuteParry(regData, attackConfig)
    local now = os.clock()
    if (now - regData.LastExecuteTime) < EXECUTE_DEBOUNCE then
        return
    end
    regData.LastExecuteTime = now

    local isHeavy = attackConfig.DisplayName == "M2" or attackConfig.DisplayName == "Heavy" or attackConfig.Heavy

    if attackConfig.Jump then 
        task.spawn(function()
            keypress(32)
            task.wait(.06)
            keyrelease(32)                      
        end)
        DodgeLockoutEnd = os.clock() + 0.2
    elseif isHeavy and CFG.AutoDodge then
        if CFG.AutoParry then  
            Dodge()            
        end
    --    DodgeLockoutEnd = os.clock() + 0.2
    else
        local debugOn = CFG.DebugParry

        if LastPendingRegData ~= regData then
            LastPendingRegData = regData
            BlockStart(LastPendingRegData.BlockStart)
            if debugOn then
                print(string.format("Block triggered by [%s | %s]", attackConfig.Style, attackConfig.DisplayName))
            end
        elseif regData.DidALoop then
            if debugOn then
                print(string.format(
                    "Block retriggered for [%s | %s] (loop)",
                    attackConfig.Style,
                    attackConfig.DisplayName
                ))
            end
            regData.DidALoop = false
            BlockStart(regData.BlockStart)
        end
    end
end

local function EvaluateAnimation(anim, character, localCharacter, localRoot, targetRoot, currentActiveIds)
    -- ANIMATION VALIDATION
    if not anim.AnimationId then return end
    local animId = anim.AnimationId
    local attackConfig = GameConfig[animId] or GameConfig[tostring(animId)]
    if not attackConfig then return end
    
    local animKey = anim.Address or anim
    currentActiveIds[animKey] = true
    
    -- ANIMATION REGISTRY & STATE
    local now = os.clock()
    local regData = UpdateAnimationRegistry(animKey, anim, now, anim.TimePosition or 0, attackConfig, character)
    if regData.Processed then return end

    if CheckCharacterDistance(localRoot, targetRoot) > AutoParryRange then return end
    
    -- PARRY FUNCTION OVERRIDE (Boxing M2 etc.)
    if attackConfig.ParryFunction
        and (now - regData.StartTime) <= (attackConfig.ReactionTime or DefaultReactionTime) + ParryWindow / 2 then
        -- OFF = player handles Boxing M2 manually; mark processed so normal AP won't steal it
        if attackConfig.BoxingM2 and not CFG.AutoBoxingM2 then
            regData.Processed = true
            return
        end
        if CFG.AutoParry then
            attackConfig.ParryFunction({
                RegistryData = regData,
                Mob = character,
                AnimationData = anim,
                AnimationTracker = AnimationTracker,
            })
        end
        return
    end
    
    -- DIRECTION CHECKS
    if not CheckAnimationDirection(character, localCharacter, localRoot, targetRoot, attackConfig) then return end
    
    if regData.RandomNum > ProbabilityToParry then
        regData.Processed = true
--        print("Skip b/c PTP", RandomNum, ProbabilityToParry)
        return
    end
    
    -- PARRY EXECUTION
    local BlockExpireTimer = regData.BlockExpire - now
    
    if now >= regData.BlockStart and BlockExpireTimer >= 0 then
    --    if not LastPendingRegData or LastPendingRegData.Proc then
            ExecuteParry(regData, attackConfig)
    --    end
    end
end

local function EvaluateCharacter(character, localCharacter, localRoot, currentActiveIds)
    -- Skip corpses / streaming characters (no Animator yet) — prevents resolve spam & dead AP
    if not characterTrackable(character) then return end

    local targetRoot = ValidateTargetCharacter(character)
    if not targetRoot then return end

    local distance = CheckCharacterDistance(localRoot, targetRoot)
    UpdateCharacterESP(character, distance)

    local activeAnimations = GetActiveAnimationsCached(character, AnimationTracker)
    if not activeAnimations or #activeAnimations == 0 then return end

    for _, anim in ipairs(activeAnimations) do
        EvaluateAnimation(anim, character, localCharacter, localRoot, targetRoot, currentActiveIds)
    end
end

local function EvaluateParryTriggers()
    -- Hot path: no locked targets → nothing to evaluate (registry already idle)
    if #TargetCharacters == 0 then
        if next(AnimationRegistry) ~= nil then
            table.clear(AnimationRegistry)
            LastPendingRegData = nil
        end
        return
    end

    local localCharacter, localRoot = ValidateLocalCharacter()
    if not localCharacter or not localRoot then return end

    local currentActiveIds = {}

    for _, character in ipairs(TargetCharacters) do
        EvaluateCharacter(character, localCharacter, localRoot, currentActiveIds)
    end

    for key, val in pairs(AnimationRegistry) do
        if not currentActiveIds[key] then
            AnimationRegistry[key] = nil
            if LastPendingRegData == val then
                LastPendingRegData = nil
            end
        end
    end
end

-- ==========================================
-- ==========================================

local function ProcessEspAndLogging()
    local showAnimDump = NoCrashState.AnimDebugEspEnabled
    local hasTrackers = NoCrashState.CombatEspEnabled or showAnimDump

    for i = #TargetCharacters, 1, -1 do
        local character = TargetCharacters[i]
        local tracker = EspTrackers[character]

        if tracker and not tracker.ChangeText then
            EspTrackers[character] = nil
            table.remove(TargetCharacters, i)
            continue
        end

        -- Always scan anims for unknown-ID logging (clipboard), even with ESP off
        local activeAnimations = GetActiveAnimationsCached(character, AnimationTracker)

        for _, anim in ipairs(activeAnimations) do
            local assetId = anim.AnimationId
            if not assetId then continue end
            local numericId = tonumber(string.match(tostring(assetId), "%d+"))
            if numericId and IgnoreIdSet[numericId] then continue end
            local poolData = GameConfig[tostring(assetId)]
            if not poolData then
                local resolvedName = anim.Name or "???"
                LogAnimation(assetId, { Name = resolvedName, AnimationId = assetId })
            end
        end

        if not hasTrackers or not tracker then continue end

        if not showAnimDump then
            -- Clear any leftover debug line when anim dump is off
            if tracker.ChangeText then
                tracker:ChangeText("CurrentlyPlaying", "", COLOR_WHITE)
            end
            continue
        end

        if #activeAnimations == 0 then
            tracker:ChangeText("CurrentlyPlaying", "None", COLOR_WHITE)
            continue
        end

        local lines = {}
        for _, anim in ipairs(activeAnimations) do
            local assetId = anim.AnimationId
            if not assetId then continue end
            local numericId = tonumber(string.match(tostring(assetId), "%d+"))
            if numericId and IgnoreIdSet[numericId] then continue end

            local poolData = GameConfig[tostring(assetId)]
            local resolvedName = (poolData and poolData.DisplayName) or anim.Name

            table.insert(lines, string.format(
                "%s (%s) | ID: %s | Time: %.2f | Timing: %.2f %s | Speed: %.2f",
                tostring(resolvedName),
                poolData and poolData.Style or "???",
                tostring(assetId),
                anim.TimePosition or 0,
                (poolData and poolData.ReactionTime) or DefaultReactionTime,
                poolData and "[Logged]" or "[Unknown]",
                anim.Speed or 1
            ))
        end

        if tracker.Name then
            tracker:ChangeText("CurrentlyPlaying", table.concat(lines, "\n"), COLOR_WHITE)
        end
    end
end

function ClearAllEspTrackers()
    for char, tracker in pairs(EspTrackers) do
        if tracker and tracker.Destroy then            
            if ESP_Utility.TrackersToUpdate[tracker] then
                ESP_Utility.TrackersToUpdate[tracker] = nil
            end

            -- 2. Destroy the tracker object
            tracker:Destroy()
        end
    end
    table.clear(EspTrackers) -- Safer than re-assigning {} to preserve table memory references
end

function UpdateTargetCharacters(charactersList)
    ClearAllEspTrackers()
    table.clear(TargetCharacters)

    local wantEsp = NoCrashState.CombatEspEnabled or NoCrashState.AnimDebugEspEnabled

    for _, character in charactersList do
        table.insert(TargetCharacters, character)

        -- Only spawn ESP boxes when a visual toggle is on
        if wantEsp and character and character:FindFirstChild("HumanoidRootPart") and ESP_Utility and ESP_Utility.NewTracker then
            local tracker = ESP_Utility.NewTracker(character.HumanoidRootPart, character.Name, COLOR_RED)
            if tracker and tracker.Name then
                tracker:AddText("CurrentlyPlaying", nil, "")
            end
            EspTrackers[character] = tracker
        end
    end
end

-- ==========================================================
-- Lightweight X-target and health overlays
-- The Drawing calls are isolated and throttled so an unsupported drawing feature
-- cannot take down the combat loop or recreate objects every frame.
-- ==========================================================
function NoCrashState:SetVisible(drawing, visible)
    if drawing then
        pcall(function() drawing.Visible = visible end)
    end
end

-- Matcha's existing ESP uses WorldToScreen. Keep the camera call only as a
-- fallback so the overlay works with either projection implementation.
function NoCrashState:Project(worldPosition)
    local ok, point, visible = pcall(function()
        if type(WorldToScreen) == "function" then
            return WorldToScreen(worldPosition)
        end

        local camera = workspace.CurrentCamera
        if camera then
            return camera:WorldToViewportPoint(worldPosition)
        end
    end)

    if not ok or not point or visible ~= true then
        return nil, false
    end
    if point.Z and point.Z <= 0 then
        return nil, false
    end
    return point, true
end

function NoCrashState:EnsureTargetMarker()
    if self.TargetMarker then return self.TargetMarker end

    local marker = {
        Outline = self:AddDrawing("Square"),
        Box = self:AddDrawing("Square"),
        Text = self:AddDrawing("Text"),
    }

    pcall(function()
        marker.Outline.Filled = false
        marker.Outline.Color = Color3.fromRGB(10, 10, 10)
        marker.Outline.Thickness = 3
        marker.Box.Filled = false
        marker.Box.Color = Color3.fromRGB(255, 65, 65)
        marker.Box.Thickness = 1
        marker.Text.Color = Color3.fromRGB(255, 235, 235)
        marker.Text.Size = 12
        marker.Text.Center = true
        marker.Text.Outline = true
    end)

    self.TargetMarker = marker
    return marker
end

function NoCrashState:HideTargetMarker()
    local marker = self.TargetMarker
    if marker then
        self:SetVisible(marker.Outline, false)
        self:SetVisible(marker.Box, false)
        self:SetVisible(marker.Text, false)
    end
end

function NoCrashState:UpdateTargetMarker()
    if not self.TargetMarkerEnabled then
        self:HideTargetMarker()
        return
    end

    local character = TargetCharacters[1]
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        self:HideTargetMarker()
        return
    end

    local point, visible = self:Project(root.Position + Vector3.new(0, 3.2, 0))
    if not visible then
        self:HideTargetMarker()
        return
    end

    local marker = self:EnsureTargetMarker()
    local size = math.clamp(2200 / point.Z, 20, 48)
    local position = Vector2.new(point.X - size / 2, point.Y - size / 2)

    pcall(function()
        marker.Outline.Position = position
        marker.Outline.Size = Vector2.new(size, size)
        marker.Box.Position = position
        marker.Box.Size = Vector2.new(size, size)
        marker.Text.Text = "[X] " .. tostring(character.Name)
        marker.Text.Position = Vector2.new(point.X, point.Y - size / 2 - 15)
        marker.Outline.Visible = true
        marker.Box.Visible = true
        marker.Text.Visible = true
    end)
end

function NoCrashState:EnsureHealthEntry(index)
    local entry = self.HealthEntries[index]
    if entry then return entry end

    entry = {
        Name = self:AddDrawing("Text"),
        Background = self:AddDrawing("Square"),
        Fill = self:AddDrawing("Square"),
        Value = self:AddDrawing("Text"),
    }

    pcall(function()
        entry.Name.Color = Color3.fromRGB(240, 240, 240)
        entry.Name.Transparency = 1
        entry.Name.Size = 11
        entry.Name.Center = true
        entry.Name.Outline = true
        entry.Background.Color = Color3.fromRGB(42, 42, 42)
        entry.Background.Transparency = 1
        entry.Background.Filled = true
        entry.Background.Thickness = 1
        entry.Fill.Color = Color3.fromRGB(55, 230, 85)
        entry.Fill.Transparency = 1
        entry.Fill.Filled = true
        entry.Value.Color = Color3.fromRGB(240, 240, 240)
        entry.Value.Transparency = 1
        entry.Value.Size = 10
        entry.Value.Center = true
        entry.Value.Outline = true
    end)

    self.HealthEntries[index] = entry
    return entry
end

function NoCrashState:HideHealthEntry(entry)
    if entry then
        self:SetVisible(entry.Name, false)
        self:SetVisible(entry.Background, false)
        self:SetVisible(entry.Fill, false)
        self:SetVisible(entry.Value, false)
    end
end

function NoCrashState:UpdateOpponentHealth()
    if not self.OpponentHpEnabled then
        for _, entry in pairs(self.HealthEntries) do self:HideHealthEntry(entry) end
        return
    end

    local folder = SelectedFolder and workspace:FindFirstChild(SelectedFolder)
    local localCharacter = LocalPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    if not folder or not localRoot then
        for _, entry in pairs(self.HealthEntries) do self:HideHealthEntry(entry) end
        return
    end

    local candidates = {}
    for _, character in ipairs(folder:GetChildren()) do
        local humanoid = character:IsA("Model") and character:FindFirstChildWhichIsA("Humanoid")
        local root = character:IsA("Model") and character:FindFirstChild("HumanoidRootPart")
        if character ~= localCharacter and humanoid and root and humanoid.Health > 0 then
            local distance = (localRoot.Position - root.Position).Magnitude
            if distance <= self.HpViewRange then
                table.insert(candidates, { Character = character, Humanoid = humanoid, Root = root, Distance = distance })
            end
        end
    end

    table.sort(candidates, function(a, b) return a.Distance < b.Distance end)
    local displayed = 0

    for _, candidate in ipairs(candidates) do
        if displayed >= 12 then break end
        local head = candidate.Character:FindFirstChild("Head") or candidate.Root
        local point, visible = self:Project(head.Position + Vector3.new(0, 1.15, 0))
        if visible then
            displayed += 1
            local entry = self:EnsureHealthEntry(displayed)
            local width, height = 52, 4
            local health = math.max(0, tonumber(candidate.Humanoid.Health) or 0)
            local maximum = math.max(1, tonumber(candidate.Humanoid.MaxHealth) or 1)
            local ratio = math.clamp(health / maximum, 0, 1)
            local left = point.X - width / 2
            local top = point.Y

            pcall(function()
                entry.Name.Text = tostring(candidate.Character.Name)
                entry.Name.Position = Vector2.new(point.X, top - 13)
                entry.Background.Position = Vector2.new(left, top)
                entry.Background.Size = Vector2.new(width, height)
                entry.Fill.Position = Vector2.new(left + 1, top + 1)
                entry.Fill.Size = Vector2.new(ratio > 0 and math.max(1, (width - 2) * ratio) or 0, height - 2)
                entry.Fill.Color = ratio >= 0.995 and Color3.fromRGB(55, 230, 85) or Color3.fromRGB(math.floor(235 * (1 - ratio)), math.floor(70 + 185 * ratio), 65)
                entry.Value.Text = string.format("%d / %d", math.floor(health + 0.5), math.floor(maximum + 0.5))
                entry.Value.Position = Vector2.new(point.X, top + 5)
                entry.Name.Visible = true
                entry.Background.Visible = true
                entry.Fill.Visible = true
                entry.Value.Visible = true
            end)
        end
    end

    for index = displayed + 1, #self.HealthEntries do
        self:HideHealthEntry(self.HealthEntries[index])
    end
end

function NoCrashState:EnsurePersonalHealth()
    if self.PersonalHealth then return self.PersonalHealth end

    self.PersonalHealth = {
        Background = self:AddDrawing("Square"),
        Fill = self:AddDrawing("Square"),
        Value = self:AddDrawing("Text"),
    }

    pcall(function()
        self.PersonalHealth.Background.Filled = true
        self.PersonalHealth.Background.Color = Color3.fromRGB(42, 42, 42)
        self.PersonalHealth.Background.Transparency = 1
        self.PersonalHealth.Fill.Filled = true
        self.PersonalHealth.Fill.Color = Color3.fromRGB(55, 230, 85)
        self.PersonalHealth.Fill.Transparency = 1
        self.PersonalHealth.Value.Color = Color3.fromRGB(245, 245, 245)
        self.PersonalHealth.Value.Transparency = 1
        self.PersonalHealth.Value.Size = 13
        self.PersonalHealth.Value.Center = true
        self.PersonalHealth.Value.Outline = true
    end)
    return self.PersonalHealth
end

function NoCrashState:UpdatePersonalHealth()
    if not self.PersonalHpEnabled then
        local entry = self.PersonalHealth
        if entry then
            self:SetVisible(entry.Background, false)
            self:SetVisible(entry.Fill, false)
            self:SetVisible(entry.Value, false)
        end
        return
    end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
    local camera = workspace.CurrentCamera
    if not humanoid or humanoid.Health <= 0 or not camera then return end

    local entry = self:EnsurePersonalHealth()
    local width, height = 180, 6
    local health = math.max(0, tonumber(humanoid.Health) or 0)
    local maximum = math.max(1, tonumber(humanoid.MaxHealth) or 1)
    local ratio = math.clamp(health / maximum, 0, 1)
    local viewport = camera.ViewportSize
    if not self.PersonalViewport or self.PersonalViewport.X ~= viewport.X or self.PersonalViewport.Y ~= viewport.Y then
        self.PersonalViewport = viewport
        self.PersonalPosition = Vector2.new((viewport.X - width) / 2, viewport.Y - 64)
    end
    local position = self.PersonalPosition

    pcall(function()
        entry.Background.Position = position
        entry.Background.Size = Vector2.new(width, height)
        entry.Fill.Position = position + Vector2.new(1, 1)
        entry.Fill.Size = Vector2.new(ratio > 0 and math.max(1, (width - 2) * ratio) or 0, height - 2)
        entry.Fill.Color = ratio >= 0.995 and Color3.fromRGB(55, 230, 85) or Color3.fromRGB(math.floor(235 * (1 - ratio)), math.floor(70 + 185 * ratio), 65)
        entry.Value.Text = string.format("HP  %d / %d", math.floor(health + 0.5), math.floor(maximum + 0.5))
        entry.Value.Position = Vector2.new(viewport.X / 2, position.Y - 15)
        entry.Background.Visible = true
        entry.Fill.Visible = true
        entry.Value.Visible = true
    end)
end

function NoCrashState:UpdateOverlays()
    local now = os.clock()
    if not self.Alive or now - self.LastOverlayUpdate < 0.08 then return end
    self.LastOverlayUpdate = now
    pcall(function()
        self:UpdateTargetMarker()
        self:UpdateOpponentHealth()
        self:UpdatePersonalHealth()
    end)
end

NoCrashState.ClearEspTrackers = ClearAllEspTrackers

function CycleEvent()
    local allCharacters = GetAllCharactersInFolder()
    if not SelectedFolder or not allCharacters then 
        UpdateTargetCharacters({})
        return 
    end

    local localPlayer = game.Players.LocalPlayer
    local localCharacter = localPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end

    local validCharacters = {}

    for _, char in ipairs(allCharacters) do
        -- Prevent the script from targeting yourself
      --  if char == localCharacter then continue end 

        local targetRoot = char:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            local distance = (localRoot.Position - targetRoot.Position).Magnitude
            if distance <= MaxCycleRange then
                table.insert(validCharacters, { Character = char, Distance = distance })
            end
        end
    end
    
    if #validCharacters == 0 then
        CurrentIndex = 1
        UpdateTargetCharacters({}) 
        if not CFG.AutoTargetNearest then  
            UI_Library:Notify("Cycle", "No targets found in range [".. MaxCycleRange.." studs]")            
        end
        return
    end

    table.sort(validCharacters, function(a, b)
        return a.Distance < b.Distance
    end)

    if CFG.MultiTarget then
        local Max = 3
        local finalTargets = {}
        
        for i = 1, math.min(Max, #validCharacters) do
            table.insert(finalTargets, validCharacters[i].Character)
        end
        
        UpdateTargetCharacters(finalTargets)
    else
        CurrentIndex = (CurrentIndex % #validCharacters) + 1
        
        local targetIndex = CFG.AutoTargetNearest and 1 or CurrentIndex
        local selectedCharacter = validCharacters[targetIndex].Character
        
        UpdateTargetCharacters({selectedCharacter})
    end
end

-- ==========================================
-- Input & Loop
-- ==========================================
NoCrashState:AddConnection(UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    local RhythmServiceUI = game.Players.LocalPlayer.PlayerGui:FindFirstChild("RhythmServiceUI")
    if RhythmServiceUI then return end

    if input.KeyCode == CycleKeybind or input.KeyCode == string.byte("x") then
        CycleEvent()
    elseif input.KeyCode == string.byte("f") then 
        local localChar = LocalPlayer.Character
        LocalTracker:Update(localChar) 
        OnInputF()
        --[[if AutoParryToggle.Get() == false and LastPendingRegData then  
            InputRegisteredTime = os.clock()
            
            if (InputRegisteredTime - LastReactionTime) < 1 then  
                 print("probably on cooldown")
            end
            if not LastPendingRegData then return end 
            local Difference = os.clock() - LastPendingRegData.StartTime
            local string = string.format("DETECT: You pressed F at %.2f", os.clock() - LastPendingRegData.StartTime)
--            print(string)
        --end]]
    end
end))



local UTILITY_TICK = 0.5 -- 2x per second for cycle + ESP logging
local LastCycleCheck = 0

-- Cached local humanoid (avoids FindFirstChildWhichIsA every frame)
local _cachedChar, _cachedHum = nil, nil
local _localReady = false
local _mainLoopErrAt = 0
local _lastPruneAt = 0

local function PruneDeadTargets()
    for i = #TargetCharacters, 1, -1 do
        local c = TargetCharacters[i]
        if not characterTrackable(c) then
            local tracker = EspTrackers[c]
            if tracker then
                pcall(function()
                    if ESP_Utility and ESP_Utility.TrackersToUpdate then
                        ESP_Utility.TrackersToUpdate[tracker] = nil
                    end
                    if tracker.Destroy then tracker:Destroy() end
                end)
                EspTrackers[c] = nil
            end
            table.remove(TargetCharacters, i)
        end
    end
end

-- Respawn / new character: wipe stale memory track caches so AP works again without reinject
pcall(function()
    NoCrashState:AddConnection(LocalPlayer.CharacterAdded:Connect(function(char)
        _cachedChar, _cachedHum, _localReady = nil, nil, false
        ResetCombatTrackers("CharacterAdded")
        task.spawn(function()
            local hum = char:WaitForChild("Humanoid", 8)
            if not hum then return end
            -- Animator can lag behind Humanoid on spawn
            hum:WaitForChild("Animator", 8)
            if LocalPlayer.Character == char then
                _cachedChar = char
                _cachedHum = hum
                _localReady = characterTrackable(char)
            end
        end)
    end))
end)

local function MainLoop()
    if not NoCrashState.Alive then return end

    local now = os.clock()

    AutoPlayTask()

    local localChar = LocalPlayer.Character
    if localChar ~= _cachedChar then
        _cachedChar = localChar
        _cachedHum = localChar and localChar:FindFirstChildWhichIsA("Humanoid")
        _localReady = false
        if localChar then
            ResetCombatTrackers("character-swap")
        end
    end
    local localHumanoid = _cachedHum
    if not localHumanoid or localHumanoid.Health <= 0 then
        _localReady = false
        scheduler.update()
        return
    end

    -- Don't hammer LocalTracker until Animator exists (stops resolve spam + empty AP)
    if not _localReady then
        _localReady = characterTrackable(localChar)
        if not _localReady then
            scheduler.update()
            return
        end
    end

    LocalTracker:Update(localChar)

    local ok, err = pcall(EvaluateParryTriggers)
    if not ok and (now - _mainLoopErrAt) > 2 then
        _mainLoopErrAt = now
        warn("[MainLoop] EvaluateParryTriggers: ", err)
    end
    ok, err = pcall(ParryTask)
    if not ok and (now - _mainLoopErrAt) > 2 then
        _mainLoopErrAt = now
        warn("[MainLoop] ParryTask: ", err)
    end

    scheduler.update()
    NoCrashState:UpdateOverlays()

    if (now - LastCycleCheck) >= UTILITY_TICK then
        LastCycleCheck = now
        -- Drop dead/missing-Animator targets so we don't soft-lock AP on corpses
        if (now - _lastPruneAt) >= 0.5 then
            _lastPruneAt = now
            PruneDeadTargets()
            -- Soft recovery: if AP is on but local lost trackability, wipe stale memory caches
            if CFG.AutoParry and _cachedChar and not characterTrackable(_cachedChar) then
                _localReady = false
                ResetCombatTrackers("local-untrackable")
            end
        end
        if CFG.AutoTargetNearest then
            CycleEvent()
        end
        ProcessEspAndLogging()
    end
end

NoCrashState:AddConnection(RunService.RenderStepped:Connect(MainLoop))
end
__LB67_CombatRuntime()

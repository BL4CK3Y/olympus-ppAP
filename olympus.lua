
-- =============================================
-- Olympus Auto Parry — v9.3
-- + Ping compensation, Parry Window, Probability
-- + ParryFunction, IgnoreIds, state anim lists
-- + Auto Target Nearest, Rhythm Auto-Hit
-- + BlockStart/BlockEnd, cleanup on re-inject
-- =============================================

-- Cleanup previous inject
pcall(function()
    if _G.__OlympusAP and _G.__OlympusAP.Cleanup then
        _G.__OlympusAP:Cleanup()
    end
end)

local OlympusState = {
    Alive = true,
    Connections = {},
}
_G.__OlympusAP = OlympusState

function OlympusState:AddConnection(c)
    if c then table.insert(self.Connections, c) end
    return c
end

function OlympusState:Cleanup()
    self.Alive = false
    for _, c in ipairs(self.Connections or {}) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(self.Connections or {})
    pcall(function()
        if self.UI_Window and self.UI_Window.Destroy then
            self.UI_Window:Destroy()
        end
    end)
    print("[Olympus] Cleaned up previous session")
end

-- Services
local RunService  = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local PlayersSvc  = game:GetService("Players")
local StatsSvc    = game:GetService("Stats")
if not PlayersSvc then PlayersSvc = game.Players end
if not PlayersSvc then
    warn("[Olympus] FATAL: cannot get PlayersSvc service. Are you in a game?")
    return
end

local LocalPlayer = PlayersSvc.LocalPlayer
if not LocalPlayer then LocalPlayer = PlayersSvc.PlayerAdded:Wait() end

local function _defer(fn)
    if task and task.defer then task.defer(fn)
    elseif task and task.spawn then task.spawn(fn)
    else pcall(fn) end
end

-- ── Utilities ──
pcall(function()
    loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/artxficial/matchastuff/main/animationtracker.lua"
    ))()
end)

pcall(function()
    loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/neaxusxgod-png/INS-ui/main/uilib.min.lua"
    ))()
end)

local UI_Library = rawget(_G, "INSui") or (INSui)
if UI_Library and UI_Library.SetAccent then
    pcall(function() UI_Library:SetAccent(Color3.fromRGB(210, 40, 40)) end)
end

-- Full IgnoreIds from original AP (non-attack anims)
local IgnoreIds = {
    73766443218740,111699625251889,85823794654077,99661732639863,106268941365574,109816855387997,122561749929324,129805948180599,
    90752347516770,135133599113049,132695091086148,137015026151472,114511731321756,100794890036133,109303037515668,117293898907979,
    74690341409113,73090768467054,72284079162560,89016181362524,76945839486275,101161965631044,128307941333158,85931837451298,
    91352556581859,77911299793653,129335968179665,122384188141033,132695766056641,113331696487725,124220338099067,99799500309776,
    108636808436488,90015977935891,87932588807124,132477488202815,102982320608759,109278619250401,79971841883936,97783129267001,
    72822821848529,79974955602012,77798715679680,85845666927963,108862846290180,108045962864902,93184693099565,120399899079666,
    99958962160522,93221784050620,70767328707698,
}

-- Local state anims (block AP while we are stunned / already parrying)
local ParriedAnimation = {
    ["rbxassetid://100773926241456"]=true, ["rbxassetid://102823909334302"]=true,
    ["rbxassetid://96304721384743"]=true,  ["rbxassetid://82979105739696"]=true,
    ["rbxassetid://96600699015093"]=true,  ["rbxassetid://138519505081692"]=true,
}
local StunnedAnimation = {
    ["rbxassetid://122541287927198"]=true, ["rbxassetid://83600639547203"]=true,
    ["rbxassetid://80309578200579"]=true,  ["rbxassetid://92787945841620"]=true,
    ["rbxassetid://108045962864902"]=true, ["rbxassetid://104407197874289"]=true,
}
local ParryingAnimation = {
    ["rbxassetid://118147060185189"]=true, ["rbxassetid://80135556847061"]=true,
    ["rbxassetid://88718564310179"]=true,
}
local ParryFailedAnimation = {
    ["rbxassetid://4210597123"]=true,
}

local function animSetHas(set, id)
    if not id then return false end
    id = tostring(id)
    if set[id] then return true end
    if not id:find("rbxassetid://", 1, true) then
        return set["rbxassetid://" .. id] == true
    end
    return false
end

-- ── Animation Database (FFTM ids, no remote/image code) ──
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
        ["rbxassetid://96466099895892"] = {
            DisplayName = "M2",
            ReactionTime = 0.3,
        },
        ["rbxassetid://116278224437295"] = {
            DisplayName = "M2",
            ReactionTime = 0.1,
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
        ["rbxassetid://124808151650835"] = {
            DisplayName = "1stM1",
        },
        ["rbxassetid://79996486219181"] = {
            DisplayName = "2ndM1",
        },
        ["rbxassetid://115207134396914"] = {
            DisplayName = "3rdM1",
        },
        ["rbxassetid://74020075116139"] = {
            DisplayName = "4thM1",
        },
        ["rbxassetid://91419261625463"] = {
            DisplayName = "M2",
            ReactionTime = 0.3,
        },
        ["rbxassetid://135984725924501"] = {
            DisplayName = "M2EHit"
        },
        ["rbxassetid://99774162066012"] = {
            DisplayName = "M2Success"
        },
        ["M1Time"] = 0.15,
    },
    ["MuayThaiAnims"] = {
        ["rbxassetid://110917888708142"] = {
            DisplayName = "1stM1",
            ParryTime = 0.08,
        },
        ["rbxassetid://136830198456192"] = {
            DisplayName = "2ndM1",
            ParryTime = 0.08,
        },
        ["rbxassetid://103717575086418"] = {
            DisplayName = "3rdM1",
            ParryTime = 0.08,
        },
        ["rbxassetid://90445272780399"] = {
            DisplayName = "4thM1",
            ParryTime = 0.08,
        },
        ["rbxassetid://74462376752922"] = {
            DisplayName = "M2",
            ReactionTime = 0.3,
        },
        ["rbxassetid://137299369381761"] = {
            DisplayName = "M2",
            ReactionTime = 0.1,
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
            -- Custom sequence: wait → block → dodge (original behavior)
            ParryFunction = function(data)
                if data.RegistryData and data.RegistryData.Processed then return end
                if data.RegistryData then data.RegistryData.Processed = true end
                task.spawn(function()
                    task.wait(0.40)
                    BlockStart(os.clock(), 0.50)
                    if CFG.AutoDodge then
                        task.wait(0.30)
                        Dodge(true)  -- already gated by CFG.AutoDodge above
                    end
                end)
            end,
        },
    },
    ["HakariOtherAnims"] = {
        ["rbxassetid://117925051452801"] = {
            DisplayName = "1stM1"
        },
        ["rbxassetid://122040023429227"] = {
            DisplayName = "2ndM1"
        },
        ["rbxassetid://126306184412990"] = {
            DisplayName = "3rdM1"
        },
        ["rbxassetid://85805632651129"] = {
            DisplayName = "4thM1"
        },
        ["rbxassetid://106589382211868"] = {
            DisplayName = "MomentumM2"
        },
        ["rbxassetid://127394334888645"] = {
            DisplayName = "M2"
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
            DisplayName = "M2"
        },
        ["rbxassetid://104060526539640"] = {
            DisplayName = "M2EHit"
        }
    },
    ["AliAnims"] = {
        ["rbxassetid://103211517133243"] = {
            DisplayName = "1stM1",
            ReactionTime = 0.12,
        },
        ["rbxassetid://88548871262625"] = {
            DisplayName = "2ndM1",
            ReactionTime = 0.17,
        },
        ["rbxassetid://104356393941647"] = {
            DisplayName = "3rdM1",
            ReactionTime = 0.21,
        },
        ["rbxassetid://109925400698635"] = {
            DisplayName = "4thM1",
            ReactionTime = 0.11,
        },
        ["rbxassetid://92831721340116"] = {
            DisplayName = "M2",
            ReactionTime = 0.3,
        },
        ["rbxassetid://81488798354194"] = {
            DisplayName = "M2Right",
            ReactionTime = 0.3,
        },
    },
    ["HakariAnims"] = {
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
        ["rbxassetid://137954350192006"] = {
            DisplayName = "MomentumM2"
        },
    },
    ["WingChunAnims"] = {
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
        ["rbxassetid://135699957281468"] = {
            DisplayName = "4thM1",
            ReactionTime = 0.52
        },
        ["rbxassetid://125237241325107"] = {
            DisplayName = "M2",
            ReactionTime = 0.06,
            ForceParry = true,
        },
        ["rbxassetid://140240091451745"] = {
            DisplayName = "M2Success"
        },
        ["rbxassetid://138270482936731"] = {
            DisplayName = "M2EHit"
        }
    },
    ["StrikerAnims"] = {
        -- Set A (older)
        ["rbxassetid://79224782278508"] = { DisplayName = "1stM1 (A)" },
        ["rbxassetid://74337052553355"] = { DisplayName = "2ndM1 (A)" },
        ["rbxassetid://121264916189386"] = { DisplayName = "3rdM1 (A)" },
        ["rbxassetid://125556631043249"] = { DisplayName = "4thM1 (A)" },
        -- Legacy M2 / feint (screenshot "StrikerFeint" ~0.31)
        ["rbxassetid://128600830397859"] = { DisplayName = "StrikerFeint", ReactionTime = 0.31 },
        -- Set B (alternate)
        ["rbxassetid://132840225082238"] = { DisplayName = "1stM1 (B)" },
        ["rbxassetid://88761422474765"] = { DisplayName = "2ndM1 (B)" },
        ["rbxassetid://98462236639320"] = { DisplayName = "3rdM1 (B)" },
        ["rbxassetid://122451562066756"] = { DisplayName = "4thM1 (B)" },
        -- Current set (faster chain)
        ["rbxassetid://116642061934550"] = { DisplayName = "1stM1", ReactionTime = 0.20 },
        ["rbxassetid://115234849770695"] = { DisplayName = "2ndM1", ReactionTime = 0.18 },
        ["rbxassetid://85554794950365"] = { DisplayName = "3rdM1", ReactionTime = 0.05 },
        ["rbxassetid://73777821288331"] = { DisplayName = "4thM1", ReactionTime = 0.05 },
        ["rbxassetid://99309341097380"] = { DisplayName = "M2", ReactionTime = 0.30 },
    },
    ["KickboxingAnims"] = {
        ["rbxassetid://127679697578124"] = {
            DisplayName = "1stM1"
        },
        ["rbxassetid://111648334200984"] = {
            DisplayName = "2ndM1"
        },
        ["rbxassetid://109134308246065"] = {
            DisplayName = "3rdM1"
        },
        ["rbxassetid://123237866254734"] = {
            DisplayName = "4thM1"
        },
        ["rbxassetid://119415047601579"] = {
            DisplayName = "M2"
        },
        ["rbxassetid://140240091451745"] = {
            DisplayName = "M2Success"
        },
        ["rbxassetid://138270482936731"] = {
            DisplayName = "M2EHit"
        }
    },
    ["KyokushinAnims"] = {
        ["rbxassetid://108157433609067"] = {
            DisplayName = "1stM1"
        },
        ["rbxassetid://139691512657916"] = {
            DisplayName = "2ndM1"
        },
        ["rbxassetid://94267870513016"] = {
            DisplayName = "3rdM1"
        },
        ["rbxassetid://107365196082362"] = {
            DisplayName = "4thM1"
        },
        ["rbxassetid://128363063231486"] = {
            DisplayName = "M2"
        },
        ["rbxassetid://80822959210741"] = {
            DisplayName = "M2",
            ReactionTime = 0.300,
        },
    },
    ["CQCAnims"] = {
        ["rbxassetid://80051878176163"] = {
            DisplayName = "1stM1"
        },
        ["rbxassetid://112809686330315"] = {
            DisplayName = "2ndM1"
        },
        ["rbxassetid://96690751054332"] = {
            DisplayName = "3rdM1"
        },
        ["rbxassetid://75394567475187"] = {
            DisplayName = "4thM1"
        },
        ["rbxassetid://136636440521127"] = {
            DisplayName = "M2",
            ReactionTime = 0.1,
        },
    },
    ["MishimaAnims"] = {
        ["rbxassetid://122564675454774"] = {
            DisplayName = "1stM1"
        },
        ["rbxassetid://124288660244802"] = {
            DisplayName = "2ndM1"
        },
        ["rbxassetid://116344736444569"] = {
            DisplayName = "3rdM1"
        },
        ["rbxassetid://109354190051977"] = {
            DisplayName = "4thM1"
        },
        ["rbxassetid://113531813891302"] = {
            DisplayName = "M2"
        }
    },
    ["LethweiAnims"] = {
        ["rbxassetid://126845586831338"] = {
            DisplayName = "1stM1"
        },
        ["rbxassetid://111506889308405"] = {
            DisplayName = "2ndM1"
        },
        ["rbxassetid://93862547414782"] = {
            DisplayName = "3rdM1"
        },
        ["rbxassetid://81747456615347"] = {
            DisplayName = "4thM1"
        },
        ["rbxassetid://98256190530845"] = {
            DisplayName = "M2"
        }
    },
    ["JinAnims"] = {
        ["rbxassetid://89404705737555"] = {
            DisplayName = "1stM1",
            ReactionTime = 0.1,
        },
        ["rbxassetid://126407816250012"] = {
            DisplayName = "2ndM1",
            ReactionTime = 0.1,
        },
        ["rbxassetid://111599179234006"] = {
            DisplayName = "3rdM1",
            ReactionTime = 0.1,
        },
        ["rbxassetid://115508221180588"] = {
            DisplayName = "4thM1",
            ReactionTime = 0.1,
        },
        ["rbxassetid://90986005545750"] = {
            DisplayName = "M2",
            ReactionTime = 0.1,
        },
    },
    ["DragonAnims"] = {
        ["rbxassetid://90632031214738"] = {
            DisplayName = "1stM1",
            ReactionTime = 0.1,
        },
        ["rbxassetid://129870265426519"] = {
            DisplayName = "2ndM1",
            ReactionTime = 0.1,
        },
        ["rbxassetid://103119271372106"] = {
            DisplayName = "3rdM1",
            ReactionTime = 0.1,
        },
        ["rbxassetid://81350056849630"] = {
            DisplayName = "4thM1",
            ReactionTime = 0.1,
        },
        ["rbxassetid://101059515516534"] = {
            DisplayName = "M2",
            ReactionTime = 0.1,
        },
        ["rbxassetid://101850612921423"] = {
            DisplayName = "M2",
            ReactionTime = 0.1,
        },
    },

    ["PerfectCopyAnims"] = {
        ["rbxassetid://89266206062347"] = { DisplayName = "1stM1", ReactionTime = 0.150 },
        ["rbxassetid://118618177788645"] = { DisplayName = "2ndM1", ReactionTime = 0.150 },
        ["rbxassetid://92563642848078"] = { DisplayName = "3rdM1", ReactionTime = 0.150 },
        ["rbxassetid://129685126037621"] = { DisplayName = "4thM1", ReactionTime = 0.150 },
        ["rbxassetid://84779382426562"] = { DisplayName = "M2", ReactionTime = 0.300 },
        ["rbxassetid://123851034848865"] = { DisplayName = "M2", ReactionTime = 0.300 },
    },
    ["AikidoAnims"] = {
        ["rbxassetid://101667835774312"] = { DisplayName = "1stM1", ReactionTime = 0.150 },
        ["rbxassetid://72100016327641"] = { DisplayName = "2ndM1", ReactionTime = 0.150 },
        ["rbxassetid://86622096544948"] = { DisplayName = "3rdM1", ReactionTime = 0.150 },
        ["rbxassetid://116579071175823"] = { DisplayName = "4thM1", ReactionTime = 0.150 },
        ["rbxassetid://113723231962801"] = {
            DisplayName = "M2",
            ReactionTime = 0.200,
            -- Counter (like Wing Chun M2): always parry, never auto-dodge
            ForceParry = true,
        },
    },
    ["TaijutsuAnims"] = {
        ["rbxassetid://112772003891760"] = { DisplayName = "1stM1", ReactionTime = 0.150 },
        ["rbxassetid://120968355159054"] = { DisplayName = "2ndM1", ReactionTime = 0.150 },
        ["rbxassetid://134363734889174"] = { DisplayName = "3rdM1", ReactionTime = 0.150 },
        ["rbxassetid://140439623648569"] = { DisplayName = "4thM1", ReactionTime = 0.150 },
        ["rbxassetid://70666956463595"] = { DisplayName = "M2", ReactionTime = 0.300 },
    },
    ["GiovannaAnims"] = {
        ["rbxassetid://135716459366783"] = { DisplayName = "1stM1", ReactionTime = 0.150 },
        ["rbxassetid://128178940723536"] = { DisplayName = "2ndM1", ReactionTime = 0.150 },
        ["rbxassetid://133339208745195"] = { DisplayName = "3rdM1", ReactionTime = 0.150 },
        ["rbxassetid://129619149164145"] = { DisplayName = "4thM1", ReactionTime = 0.150 },
        ["rbxassetid://84500842912133"] = { DisplayName = "M2", ReactionTime = 0.300 },
    },
    ["HikakenAnims"] = {
        ["rbxassetid://109471728828625"] = { DisplayName = "1stM1", ReactionTime = 0.150 },
        ["rbxassetid://92152402802393"] = { DisplayName = "2ndM1", ReactionTime = 0.150 },
        ["rbxassetid://139736320509560"] = { DisplayName = "3rdM1", ReactionTime = 0.150 },
        ["rbxassetid://80033824766939"] = { DisplayName = "4thM1", ReactionTime = 0.150 },
        ["rbxassetid://94916233438251"] = { DisplayName = "M2", ReactionTime = 0.300 },
    },

    ["Debug"] = {
        ["http://www.roblox.com/asset/?id=125750702"] = {
            DisplayName = "M1",
            ReactionTime = 0.3,
        },
    },
}

local FlatConfig = {}
local DefaultRT = 0.1
for style, anims in pairs(GameConfig) do
    local styleRT = anims.M1Time
    for id, data in pairs(anims) do
        if type(id) == "string" and type(data) == "table"
            and (id:find("rbxassetid://", 1, true) or id:find("http://", 1, true) or id:find("rbxassetid", 1, true)) then
            local f = {}
            for k, v in pairs(data) do f[k] = v end
            f.Style = style
            f.ReactionTime = f.ReactionTime or f.ParryTime or styleRT or DefaultRT
            local name = tostring(f.DisplayName or "")
            if name:find("M2") or name == "Heavy" then f.Heavy = true end
            FlatConfig[id] = f
        end
    end
end
GameConfig = FlatConfig

-- Apply Parry Godzz timings as built-in defaults when IDs match
do
    local Godzz = {
        ["rbxassetid://100249628136368"] = 0.180,
        ["rbxassetid://100661797632126"] = 0.150,
        ["rbxassetid://101059515516534"] = 0.450,
        ["rbxassetid://101160496635774"] = 0.150,
        ["rbxassetid://101740002500802"] = 0.330,
        ["rbxassetid://101850612921423"] = 0.450,
        ["rbxassetid://103119271372106"] = 0.170,
        ["rbxassetid://103211517133243"] = 0.130,
        ["rbxassetid://103586798765773"] = 0.150,
        ["rbxassetid://103717575086418"] = 0.160,
        ["rbxassetid://104356393941647"] = 0.220,
        ["rbxassetid://107365196082362"] = 0.335,
        ["rbxassetid://108157433609067"] = 0.125,
        ["rbxassetid://109134308246065"] = 0.230,
        ["rbxassetid://109354190051977"] = 0.110,
        ["rbxassetid://109925400698635"] = 0.120,
        ["rbxassetid://110917888708142"] = 0.160,
        ["rbxassetid://111506889308405"] = 0.260,
        ["rbxassetid://111599179234006"] = 0.195,
        ["rbxassetid://111648334200984"] = 0.180,
        ["rbxassetid://112809686330315"] = 0.225,
        ["rbxassetid://113531813891302"] = 0.150,
        ["rbxassetid://115207134396914"] = 0.160,
        ["rbxassetid://115508221180588"] = 0.400,
        ["rbxassetid://116278224437295"] = 0.310,
        ["rbxassetid://116344736444569"] = 0.120,
        ["rbxassetid://117315538657801"] = 0.150,
        ["rbxassetid://119415047601579"] = 0.180,
        ["rbxassetid://121264916189386"] = 0.060,
        ["rbxassetid://122564675454774"] = 0.110,
        ["rbxassetid://123215666398014"] = 0.150,
        ["rbxassetid://123237866254734"] = 0.290,
        ["rbxassetid://124288660244802"] = 0.110,
        ["rbxassetid://124808151650835"] = 0.160,
        ["rbxassetid://125237241325107"] = 0.070,
        ["rbxassetid://125556631043249"] = 0.060,
        ["rbxassetid://126407816250012"] = 0.420,
        ["rbxassetid://126463147281440"] = 0.170,
        ["rbxassetid://126845586831338"] = 0.290,
        ["rbxassetid://127465095270110"] = 0.280,
        ["rbxassetid://127487637547915"] = 0.290,
        ["rbxassetid://127679697578124"] = 0.170,
        ["rbxassetid://127941398150401"] = 0.260,
        ["rbxassetid://128246407698779"] = 0.105,
        ["rbxassetid://128363063231486"] = 0.620,
        ["rbxassetid://128600830397859"] = 0.310, -- StrikerFeint
        ["rbxassetid://128921678079615"] = 0.100,
        ["rbxassetid://129031831390386"] = 0.158,
        ["rbxassetid://129870265426519"] = 0.220,
        ["rbxassetid://130903067566077"] = 0.120,
        ["rbxassetid://132913269853139"] = 0.190,
        ["rbxassetid://135699957281468"] = 0.470,
        ["rbxassetid://136346659171696"] = 0.160,
        ["rbxassetid://136830198456192"] = 0.180,
        ["rbxassetid://137299369381761"] = 0.380,
        ["rbxassetid://137514920199894"] = 0.160,
        ["rbxassetid://139503477666199"] = 0.120,
        ["rbxassetid://139691512657916"] = 0.140,
        ["rbxassetid://72779501873271"] = 0.210,
        ["rbxassetid://74020075116139"] = 0.200,
        ["rbxassetid://74337052553355"] = 0.190,
        ["rbxassetid://75394567475187"] = 0.310,
        ["rbxassetid://75666664304014"] = 0.200,
        ["rbxassetid://75725487794798"] = 0.160,
        ["rbxassetid://76033376851583"] = 0.180,
        ["rbxassetid://76458394174684"] = 0.220,
        ["rbxassetid://78127273702521"] = 0.200,
        ["rbxassetid://78852386182257"] = 0.290,
        ["rbxassetid://79017113400162"] = 0.170,
        ["rbxassetid://79224782278508"] = 0.210,
        ["rbxassetid://79996486219181"] = 0.160,
        ["rbxassetid://80051878176163"] = 0.225,
        ["rbxassetid://80331331149375"] = 0.310,
        ["rbxassetid://81350056849630"] = 0.170,
        ["rbxassetid://81488798354194"] = 0.410,
        ["rbxassetid://81747456615347"] = 0.220,
        ["rbxassetid://83771012317903"] = 0.150,
        ["rbxassetid://84100769626105"] = 0.170,
        ["rbxassetid://86882821333237"] = 0.600,
        ["rbxassetid://88548871262625"] = 0.180,
        ["rbxassetid://89404705737555"] = 0.230,
        ["rbxassetid://89598700542051"] = 0.180,
        ["rbxassetid://89706363973188"] = 0.270,
        ["rbxassetid://90445272780399"] = 0.150,
        ["rbxassetid://90632031214738"] = 0.170,
        ["rbxassetid://90986005545750"] = 0.180,
        ["rbxassetid://91419261625463"] = 0.160,
        ["rbxassetid://91953931348325"] = 0.160,
        ["rbxassetid://92831721340116"] = 0.340,
        ["rbxassetid://93862547414782"] = 0.250,
        ["rbxassetid://94267870513016"] = 0.170,
        ["rbxassetid://94976161225956"] = 0.120,
        ["rbxassetid://96690751054332"] = 0.190,
        ["rbxassetid://97696355281722"] = 0.200,
        ["rbxassetid://98256190530845"] = 0.260,
        ["rbxassetid://98872276178039"] = 0.220,
        ["http://www.roblox.com/asset/?id=125750702"] = 0.310,
        -- New styles (starting defaults; tune in Timings tab)
        ["rbxassetid://89266206062347"] = 0.150,
        ["rbxassetid://118618177788645"] = 0.150,
        ["rbxassetid://92563642848078"] = 0.150,
        ["rbxassetid://129685126037621"] = 0.150,
        ["rbxassetid://84779382426562"] = 0.300,
        ["rbxassetid://123851034848865"] = 0.300,
        ["rbxassetid://101667835774312"] = 0.150,
        ["rbxassetid://72100016327641"] = 0.150,
        ["rbxassetid://86622096544948"] = 0.150,
        ["rbxassetid://116579071175823"] = 0.150,
        ["rbxassetid://113723231962801"] = 0.200,
        ["rbxassetid://112772003891760"] = 0.150,
        ["rbxassetid://120968355159054"] = 0.150,
        ["rbxassetid://134363734889174"] = 0.150,
        ["rbxassetid://140439623648569"] = 0.150,
        ["rbxassetid://70666956463595"] = 0.300,
        ["rbxassetid://135716459366783"] = 0.150,
        ["rbxassetid://128178940723536"] = 0.150,
        ["rbxassetid://133339208745195"] = 0.150,
        ["rbxassetid://129619149164145"] = 0.150,
        ["rbxassetid://84500842912133"] = 0.300,
        ["rbxassetid://109471728828625"] = 0.150,
        ["rbxassetid://92152402802393"] = 0.150,
        ["rbxassetid://139736320509560"] = 0.150,
        ["rbxassetid://80033824766939"] = 0.150,
        ["rbxassetid://94916233438251"] = 0.300,
        ["rbxassetid://80822959210741"] = 0.300,
        ["rbxassetid://132840225082238"] = 0.210,
        ["rbxassetid://88761422474765"] = 0.190,
        ["rbxassetid://98462236639320"] = 0.060,
        ["rbxassetid://122451562066756"] = 0.060,
        ["rbxassetid://116642061934550"] = 0.200,
        ["rbxassetid://115234849770695"] = 0.180,
        ["rbxassetid://85554794950365"] = 0.050,
        ["rbxassetid://73777821288331"] = 0.050,
        ["rbxassetid://99309341097380"] = 0.300,

    }
    local n = 0
    for id, rt in pairs(Godzz) do
        local info = GameConfig[id]
        if info then
            info.ReactionTime = rt
            n = n + 1
        end
    end
    -- Keep a frozen copy for Reset Timings
    for id, info in pairs(GameConfig) do
        if FlatConfig[id] then
            FlatConfig[id].ReactionTime = info.ReactionTime
        end
    end
    print("[Olympus] Godzz + new-style defaults applied (" .. n .. " timings)")
end

-- ── Multi-Config ────────────────────────────
local PROFILE_FOLDER = "Olympus"
local GAKURAN_FOLDER = "GakuranConfigs"
local profileSourceMap = {}

local function ensureFolder()
    if not isfolder(PROFILE_FOLDER) then makefolder(PROFILE_FOLDER) end
end

local function listProfiles()
    table.clear(profileSourceMap)
    local names = {}
    ensureFolder()
    local files = {}
    pcall(function() files = listfiles(PROFILE_FOLDER) or {} end)
    if #files == 0 then
        pcall(function() files = listfiles(PROFILE_FOLDER .. "/") or {} end)
    end
    for _, f in pairs(files) do
        local s = tostring(f)
        local n = s:match("([^/\\]+)%.json$")
        if n then
            table.insert(names, n)
            profileSourceMap[n] = { format = "json", path = s }
        end
    end
    if isfolder and isfolder(GAKURAN_FOLDER) then
        local gfiles = {}
        pcall(function() gfiles = listfiles(GAKURAN_FOLDER) or {} end)
        for _, f in pairs(gfiles) do
            local s = tostring(f)
            local n = s:match("([^/\\]+)%.lua$")
            if n then
                local d = "[G] " .. n
                table.insert(names, d)
                profileSourceMap[d] = { format = "lua", path = s }
            end
        end
    end
    table.sort(names)
    return #names > 0 and names or { "Default" }
end

local function saveProfile(name, data)
    ensureFolder()
    local json = HttpService:JSONEncode(data)
    local paths = {
        PROFILE_FOLDER .. "/" .. name .. ".json",
        PROFILE_FOLDER .. "\\" .. name .. ".json",
    }
    for _, fpath in ipairs(paths) do
        local ok = pcall(function() writefile(fpath, json) end)
        if ok then return fpath end
    end
    return nil
end

local function loadProfile(name)
    local src = profileSourceMap[name]
    if not src then listProfiles() src = profileSourceMap[name] end
    if not src then return nil end
    local ok, data = pcall(function()
        local raw = readfile(src.path)
        if src.format == "json" then
            return HttpService:JSONDecode(raw)
        else
            local chunk = loadstring(raw)
            if not chunk then return nil end
            local d = chunk()
            if d and d.Timings then return { Timings = d.Timings } end
            return nil
        end
    end)
    return ok and data or nil
end

local function deleteProfile(name)
    local src = profileSourceMap[name]
    if not src or src.format ~= "json" then return false end
    pcall(function() if delfile then delfile(src.path) end end)
    pcall(function() if delfile then delfile(PROFILE_FOLDER .. "/" .. name .. ".json") end end)
    return true
end

-- ── State ───────────────────────────────────
local CFG = {
    Enabled=true,AutoDodge=true,MultiTarget=true,AutoTargetNearest=true,
    CycleRange=20,APRange=10,ParryOffset=0,ParryHold=0.27,ParryWindow=0.20,AutoHeight=true,HeightInfluence=1,
    PingCompensate=true,ProbabilityToParry=100,
    Debug=false,APKeybind="g",
    SoundOnParry=false,
    HeavyReadyNotify=true, HeavyCooldown=3.0,
    RhythmAutoHit=false,  -- rhythm note auto-hit (was Auto Play)
    AntiAFK=false, AFKInterval=240,
    AutoRespawn=false, RespawnDelay=1.5,
    TargetFacingYou=false, YouFacingTarget=true,
    FacingThreshold=0.5,  -- dot product cutoff: 0.5 = within ~60°, 0.7 = within ~45°
}

local ParryKey = string.byte("F")
local DodgeKey = string.byte("Q")

-- ── Ping ────────────────────────────────────
local function GetPingValue()
    -- returns ms
    local ok, v = pcall(function()
        local item = StatsSvc.Network.ServerStatsItem["Data Ping"]
        return item and item:GetValue()
    end)
    if ok and type(v) == "number" then return v end
    ok, v = pcall(function()
        return LocalPlayer:GetNetworkPing() * 1000
    end)
    if ok and type(v) == "number" then return v end
    return 50
end

-- ── BlockStart / BlockEnd / Dodge (state-aware) ──
local ParryState = {
    IDLE = "idle",
    INPUT_PENDING = "input_pending",
    PARRYING = "parrying",
    STUNNED = "stunned",
}
local CurrentParryState = ParryState.IDLE
local KeyHeld = false
local ReleaseDeadline = 0
local LocalStunned = false
local LocalParrying = false

local function TransitionToState(s)
    CurrentParryState = s
end

function BlockStart(StartTime, HoldFor)
    if not StartTime then StartTime = os.clock() end
    if not CFG.Enabled then return end
    if LocalStunned then return end
    local hold = HoldFor or CFG.ParryHold or 0.27
    ReleaseDeadline = StartTime + hold
    KeyHeld = true
    TransitionToState(ParryState.INPUT_PENDING)
    pcall(function() keypress(ParryKey) end)
end

function BlockEnd()
    KeyHeld = false
    TransitionToState(ParryState.IDLE)
    pcall(function() keyrelease(ParryKey) end)
end

function Dodge(force)
    -- force=true bypasses the AutoDodge toggle (manual/debug only)
    if not force and not CFG.AutoDodge then
        return
    end
    BlockEnd()
    pcall(function()
        for _ = 1, 8 do
            keypress(DodgeKey)
            keyrelease(DodgeKey)
        end
    end)
end

-- ── Parry Queue ─────────────────────────────
local pendingParries = {}
local scheduledMap   = {}
local lastParryFire  = 0
local PARRY_CD       = 0.05
local parryCount     = 0
local menuOpen       = true

local function ensureGameInput()
end

local function tickParryQueue()
    local now = os.clock()
    local i = 1
    while i <= #pendingParries do
        local e = pendingParries[i]
        local removed = false

        if not e.fired and now >= e.fireAt then
            if CFG.Enabled and (now - lastParryFire) >= PARRY_CD then
                lastParryFire = now
                e.fired = true
                e.releaseAt = now + CFG.ParryHold
                ensureGameInput()
                if LocalStunned then
                    e.fired = true
                    e.releaseAt = now
                -- ForceParry (Aikido/WingChun counters): always F, never Q
                elseif e.config.ForceParry then
                    BlockStart(now, CFG.ParryHold)
                    e.releaseAt = now + (CFG.ParryHold or 0.27)
                elseif e.config.Heavy and CFG.AutoDodge then
                    Dodge()
                    e.releaseAt = now
                else
                    BlockStart(now, CFG.ParryHold)
                    e.releaseAt = now + (CFG.ParryHold or 0.27)
                end
                parryCount = (parryCount or 0) + 1

                -- sound feedback (optional)
                if CFG.SoundOnParry then
                    pcall(function()
                        local s = Instance.new("Sound")
                        s.SoundId = "rbxassetid://6026984224"  -- clean click
                        s.Volume = 0.4
                        s.Parent = game:GetService("SoundService")
                        s:Play()
                        game:GetService("Debris"):AddItem(s, 2)
                    end)
                end

                if CFG.Debug and UI_Library then
                    pcall(function()
                        UI_Library:Notify("AP fired",
                            (e.config.Style or "?") .. " | " .. (e.config.DisplayName or "?") ..
                            " | waited " .. string.format("%.3f", e.delay) .. "s")
                        print("[Olympus AP]", e.config.Style, e.config.DisplayName,
                            "delay=" .. string.format("%.3f", e.delay))
                    end)
                end
            elseif not CFG.Enabled then
                table.remove(pendingParries, i) removed = true
            elseif now > e.fireAt + 0.12 then
                table.remove(pendingParries, i) removed = true
            end
        end

        if not removed then
            if e.fired and now >= (e.releaseAt or now) then
                ensureGameInput()
                BlockEnd()
                table.remove(pendingParries, i) removed = true
            elseif not e.fired and now > e.fireAt + 0.25 then
                table.remove(pendingParries, i) removed = true
            end
        end

        if not removed then i = i + 1 end
    end
end

local function heightScale(character)
    local hum = character and character:FindFirstChildWhichIsA("Humanoid")
    if not hum then return 1 end
    local scale = hum:FindFirstChild("BodyHeightScale")
    if scale and tonumber(scale.Value) then return tonumber(scale.Value) end
    return 1
end

local function queueParry(id, timePos, config, character)
    local now = os.clock()
    if LocalStunned then return end

    -- Probability gate
    local prob = tonumber(CFG.ProbabilityToParry) or 100
    if prob < 100 and math.random(1, 100) > prob then
        return
    end

    local rt = config.ReactionTime or config.ParryTime or DefaultRT
    if CFG.AutoHeight then
        local inf = tonumber(CFG.HeightInfluence) or 1
        local s = heightScale(character)
        rt = rt * (1 + (s - 1) * inf)
    end

    -- Ping compensation: subtract half RTT (ms → s)
    if CFG.PingCompensate then
        local half = (GetPingValue() / 1000) * 0.5
        rt = rt - half
        if rt < 0 then rt = 0 end
    end

    local animStart = now - timePos
    local window = tonumber(CFG.ParryWindow) or 0.20
    local fireAt = animStart + rt + (CFG.ParryOffset or 0)
    local windowEnd = fireAt + window

    local key = id .. string.format("%.2f", animStart)
    if scheduledMap[key] then return end

    -- Too late entirely
    if now > windowEnd + 0.02 then return end
    if fireAt < now - 0.05 then
        -- still inside window → fire ASAP
        fireAt = now
    end

    -- Custom ParryFunction (e.g. Boxing M2)
    if type(config.ParryFunction) == "function" then
        scheduledMap[key] = true
        local regData = { Processed = false, StartTime = animStart, Id = id }
        pcall(function()
            config.ParryFunction({
                RegistryData = regData,
                Mob = character,
                AnimationId = id,
            })
        end)
        return
    end

    scheduledMap[key] = true
    table.insert(pendingParries, {
        fireAt = fireAt,
        windowEnd = windowEnd,
        fired = false,
        releaseAt = nil,
        config = config,
        id = id,
        delay = math.max(0, fireAt - now),
    })
end

-- ── AnimationTracker ─────────────────────────
local AnimTrackerInst = nil
if AnimationTracker and AnimationTracker.new then
    local ok, inst = pcall(AnimationTracker.new, AnimationTracker, IgnoreIds)
    if ok then AnimTrackerInst = inst end
end

local _animScratch = {}
local function getAnims(character)
    if not character or not AnimTrackerInst then return _animScratch end
    for i = #_animScratch, 1, -1 do _animScratch[i] = nil end
    local ok, tracks = pcall(AnimTrackerInst.Update, AnimTrackerInst, character)
    if not ok or not tracks then return _animScratch end
    for _, t in ipairs(tracks) do
        if t and t.AnimationId then
            _animScratch[#_animScratch+1] = {id=tostring(t.AnimationId), pos=t.TimePosition or 0}
        end
    end
    return _animScratch
end

-- ── Local Heavy / R ready timer ─────────────
local heavyCdUntil = 0
local heavyNotified = true          -- true = already notified (or never started)
local lastLocalHeavyId = nil
local lastLocalHeavySeen = 0

local function isLocalHeavyAnim(animId)
    local info = GameConfig[animId]
    if not info then
        -- try with rbxassetid prefix variants
        if not tostring(animId):find("rbxassetid://", 1, true) then
            info = GameConfig["rbxassetid://" .. tostring(animId)]
        end
    end
    if not info then return false end
    if info.Heavy then return true end
    local n = tostring(info.DisplayName or "")
    if n:find("M2") or n:find("Feint") or n:find("Heavy") or n:find("Momentum") then
        return true
    end
    return false
end

local function tickHeavyReady(now)
    if not CFG.HeavyReadyNotify then return end
    local char = LocalPlayer.Character
    if char then
        local anims = getAnims(char)
        for _, a in ipairs(anims) do
            if a and a.id and isLocalHeavyAnim(a.id) then
                -- new heavy press: only re-arm when id changes or enough time passed
                if a.id ~= lastLocalHeavyId or (now - lastLocalHeavySeen) > 0.35 then
                    lastLocalHeavyId = a.id
                    lastLocalHeavySeen = now
                    local cd = tonumber(CFG.HeavyCooldown) or 3.0
                    heavyCdUntil = now + cd
                    heavyNotified = false
                    if CFG.Debug then
                        pcall(function()
                            UI_Library:Notify("Heavy CD", string.format("%.1fs", cd))
                        end)
                    end
                else
                    lastLocalHeavySeen = now
                end
                break
            end
        end
    end
    if not heavyNotified and heavyCdUntil > 0 and now >= heavyCdUntil then
        heavyNotified = true
        pcall(function()
            UI_Library:Notify("Heavy Ready", "R / M2 is ready")
        end)
        print("[Olympus] Heavy Ready")
    end
end


-- ── Rhythm Auto-Hit (was "Auto Play") ───────
local Receptors = { Receptor1="X", Receptor2="C", Receptor3="N", Receptor4="M" }
local ReceptorXMap = {}
local LastRhythmCache = 0

function RhythmAutoHitTick()
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
                count += 1
                local rx = math.floor(rec.AbsolutePosition.X + rec.AbsoluteSize.X / 2)
                ReceptorXMap[rx] = { Key = key, Name = name }
            end
        end
        if count == 2 then
            Receptors.Receptor1, Receptors.Receptor2 = "F", "J"
        else
            Receptors.Receptor1, Receptors.Receptor2 = "X", "C"
        end
        LastRhythmCache = now
    end

    local threshold = 30
    for _, note in pairs(Lanes:GetChildren()) do
        if note.Name == "NoteTemplate" then
            local noteX = math.floor(note.AbsolutePosition.X + note.AbsoluteSize.X / 2)
            local noteY = note.AbsolutePosition.Y
            local match
            for rx, data in pairs(ReceptorXMap) do
                if math.abs(noteX - rx) <= 10 then
                    match = data
                    break
                end
            end
            if match then
                local rec = ReceptorLookup:FindFirstChild(match.Name)
                if rec then
                    local dy = math.abs((noteY + note.AbsoluteSize.Y / 2) - (rec.AbsolutePosition.Y + rec.AbsoluteSize.Y / 2))
                    if dy <= threshold then
                        local key = match.Key
                        pcall(function()
                            local code = Enum.KeyCode[key]
                            if code and keypress then
                                -- try virtual key byte if letter
                            end
                            if typeof(key) == "string" and #key == 1 then
                                local b = string.byte(key:upper())
                                keypress(b)
                                keyrelease(b)
                            end
                        end)
                    end
                end
            end
        end
    end
end

-- ── Targeting ───────────────────────────────
local TargetCharacters = {}
local function updateTargets(list)
    table.clear(TargetCharacters)
    for _, c in pairs(list) do
        table.insert(TargetCharacters, c)
    end
end

local lastCycle = 0
local debugLastPrint = 0
local selectedConfig = "Default"
local TargetLabel = nil

local function cycleTargets()
    local lc = LocalPlayer.Character
    local lr = lc and lc:FindFirstChild("HumanoidRootPart")
    if not lr then updateTargets({}) return end
    local candidates = {}
    pcall(function()
        for _, p in pairs(PlayersSvc:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                candidates[#candidates+1] = p.Character
            end
        end
    end)
    local valid = {}
    for _, c in ipairs(candidates) do
        local tr = c:FindFirstChild("HumanoidRootPart")
        local h  = c:FindFirstChildWhichIsA("Humanoid")
        if tr and h and h.Health > 0 then
            local d = (lr.Position-tr.Position).Magnitude
            if d <= CFG.CycleRange then table.insert(valid,{c=c,d=d}) end
        end
    end
    table.sort(valid, function(a,b) return a.d < b.d end)
    local finals = {}
    if CFG.MultiTarget then
        for i=1,math.min(3,#valid) do table.insert(finals,valid[i].c) end
    elseif CFG.AutoTargetNearest and #valid > 0 then
        table.insert(finals, valid[1].c)  -- nearest only
    elseif #valid > 0 then
        -- keep previous lock if still valid, else nearest
        local prev = TargetCharacters[1]
        local keep = false
        if prev then
            for _, v in ipairs(valid) do
                if v.c == prev then keep = true break end
            end
        end
        if keep then
            table.insert(finals, prev)
        else
            table.insert(finals, valid[1].c)
        end
    end
    updateTargets(finals)
end

local UnknownLog = {} local UnknownOrder = {}

-- ── Anti-AFK + Auto-Respawn state ───────────
local lastAFKPing = 0
local pendingRespawn = nil  -- os.clock() of death, nil if alive

-- wire up death detection whenever character spawns
local function hookCharacter(character)
    if not character then return end
    local humanoid = character:FindFirstChildWhichIsA("Humanoid")
    if not humanoid then
        -- wait a moment and retry
        character.ChildAdded:Connect(function(child)
            if child:IsA("Humanoid") then
                child.Died:Connect(function()
                    if CFG.AutoRespawn then
                        pendingRespawn = os.clock()
                    end
                end)
            end
        end)
        return
    end
    humanoid.Died:Connect(function()
        if CFG.AutoRespawn then
            pendingRespawn = os.clock()
        end
    end)
end

-- hook current + future characters
pcall(function()
    if LocalPlayer.Character then hookCharacter(LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(function(c)
        pendingRespawn = nil  -- reset on respawn
        hookCharacter(c)
    end)
end)

-- ── MAIN LOOP ───────────────────────────────
local lastQueueTick  = 0
local lastDetectTick = 0
local QUEUE_RATE     = 1/120  -- queue: 120Hz
local DETECT_RATE    = 1/30   -- detection: 30Hz
local HARD_RATE      = 1/120  -- hard callback cap (handles uncapped Heartbeat in Matcha)

OlympusState:AddConnection(RunService.Heartbeat:Connect(function()
    local now = os.clock()
    -- hard gate: if Matcha runs Heartbeat uncapped (like RenderStepped), kill 80-90% of calls here
    if (now - lastQueueTick) < HARD_RATE then return end
    lastQueueTick = now

    -- queue tick (every callback = 120Hz effective)
    if #pendingParries > 0 then tickParryQueue() end

    if (now-lastDetectTick) < DETECT_RATE then return end
    lastDetectTick = now

    -- Local Heavy / R cooldown notify
    tickHeavyReady(now)

    -- Local stun / parry state from anim lists
    do
        LocalStunned = false
        LocalParrying = false
        local char = LocalPlayer.Character
        if char then
            local anims = getAnims(char)
            for _, a in ipairs(anims) do
                if a and a.id then
                    if animSetHas(StunnedAnimation, a.id) then
                        LocalStunned = true
                    end
                    if animSetHas(ParryingAnimation, a.id) then
                        LocalParrying = true
                        if CurrentParryState == ParryState.INPUT_PENDING then
                            TransitionToState(ParryState.PARRYING)
                        end
                    end
                    if animSetHas(ParriedAnimation, a.id) or animSetHas(ParryFailedAnimation, a.id) then
                        -- reset after resolved exchange
                        if CurrentParryState ~= ParryState.IDLE then
                            TransitionToState(ParryState.IDLE)
                        end
                    end
                end
            end
        end
        -- Auto-release F if hold expired
        if KeyHeld and ReleaseDeadline > 0 and now >= ReleaseDeadline then
            BlockEnd()
        end
    end

    -- Rhythm Auto-Hit (note minigame)
    if CFG.RhythmAutoHit then
        pcall(RhythmAutoHitTick)
    end

    -- Auto-respawn check
    local respawnDelay = tonumber(CFG.RespawnDelay) or 1.5
    if pendingRespawn and CFG.AutoRespawn and (now-pendingRespawn)>=respawnDelay then
        pendingRespawn = nil
        pcall(function() LocalPlayer:LoadCharacter() end)
    end

    -- Anti-AFK ping
    local afkInterval = tonumber(CFG.AFKInterval) or 240
    if CFG.AntiAFK and (now-lastAFKPing)>=afkInterval then
        lastAFKPing = now
        pcall(function()
            keypress(32)
            keyrelease(32)
        end)
    end

    if (now-lastCycle) >= 0.5 then
        lastCycle = now
        if next(scheduledMap) then table.clear(scheduledMap) end
        pcall(cycleTargets)
        if TargetLabel then
            pcall(function()
                local names = {}
                for _, ch in ipairs(TargetCharacters) do
                    names[#names+1] = ch.Name
                end
                local pool = #names > 0 and table.concat(names, ", ") or "(none)"
                TargetLabel:SetText("Locked: "..pool)
            end)
        end
    end
    if not CFG.Enabled then return end
    if not AnimTrackerInst then return end
    local lc = LocalPlayer.Character
    local lr = lc and lc:FindFirstChild("HumanoidRootPart")
    if not lr then return end
    for _, c in pairs(TargetCharacters) do
        local tr = c:FindFirstChild("HumanoidRootPart")
        if not tr then continue end
        local dist = (lr.Position-tr.Position).Magnitude
        if dist > CFG.APRange then continue end
        -- ── Facing conditions ─────────────────────
        if CFG.TargetFacingYou or CFG.YouFacingTarget then
            -- pcall: Vector3 ops crash in Matcha when character is mid-respawn
            local passedFacing = true
            pcall(function()
                local threshold  = tonumber(CFG.FacingThreshold) or 0.5
                local targetLook = tr.CFrame.LookVector
                local myLook     = lr.CFrame.LookVector
                local diff       = lr.Position - tr.Position
                local mag        = diff.Magnitude
                if mag < 0.001 then return end  -- same position, skip
                local toPlayer = diff / mag      -- normalize manually, avoids nan on zero vec
                local toTarget = -toPlayer

                if CFG.TargetFacingYou then
                    if targetLook:Dot(toPlayer) < threshold then
                        passedFacing = false
                    end
                end
                if passedFacing and CFG.YouFacingTarget then
                    if myLook:Dot(toTarget) < threshold then
                        passedFacing = false
                    end
                end
            end)
            if not passedFacing then continue end
        end

        local anims = getAnims(c)
        if CFG.Debug and (now-debugLastPrint) > 2 then
            debugLastPrint = now
            print("[Olympus DEBUG] targets="..#TargetCharacters..
                " anims="..#anims.." dist="..math.floor(dist).." queue="..#pendingParries)
            for _, a in pairs(anims) do
                print("  "..a.id.." inDB="..tostring(GameConfig[a.id]~=nil).." pos="..a.pos)
            end
        end
        for _, anim in pairs(anims) do
            local config = GameConfig[anim.id]
            if not config then
                if CFG.Debug and not UnknownLog[anim.id] then
                    UnknownLog[anim.id] = true
                    local num = anim.id:match("%d+$") or anim.id:match("%d+")
                    if num then table.insert(UnknownOrder,num) print("[Olympus UNKNOWN]",anim.id) end
                end
                continue
            end
            queueParry(anim.id, anim.pos, config, c)
        end
    end
end))

-- ── UI ──────────────────────────────────────
if not UI_Library then
    warn("[Olympus] UI library failed — AP still runs headless")
    menuOpen = false
    pcall(function() setrobloxinput(true) end)
    return
end

local UIRefs = {
    Armed=nil,AutoDodge=nil,MultiTarget=nil,Debug=nil,
    CycleRange=nil,APRange=nil,ParryOffset=nil,ParryHold=nil,ParryCD=nil,
    TargetFacingYou=nil,YouFacingTarget=nil,FacingThreshold=nil,
    AntiAFK=nil,AFKInterval=nil,AutoRespawn=nil,RespawnDelay=nil,
}

local function setMenuInput(open)
    menuOpen = open
end

local UI_Window = UI_Library:CreateWindow({
    title="Olympus",size=Vector2.new(740,580),configFolder="olympus_base",
})

local CombatTab   = UI_Window:Tab("Combat","sword")
local TimingsTab  = UI_Window:Tab("Timings","clock")
local SettingsTab = UI_Window:Tab("Settings","gear")
local UpdatesTab  = UI_Window:Tab("Updates","book-closed")

local bindStyle = nil
local readAPKeybind, writeAPKeybind
local ProfilesSec = CombatTab:Section("Profiles","Left")
local EngineSec   = CombatTab:Section("Engine","Left")
local DebugSec    = CombatTab:Section("Debug","Left")
local ArmedSec    = CombatTab:Section("Armed","Right")
local CondSec     = CombatTab:Section("Conditions","Right")
local TargetSec   = CombatTab:Section("Target Pool","Right")

ProfilesSec:Info("Pick a profile to Load/Save over it, or type a new name then Save.")
local currentName = "Default"
local ProfileDrop = nil
local AnimSliders = {}
local NameLabel = ProfilesSec:Label("Will save as: "..currentName)
local ConfigListLabel = nil
local APKeybindRef = nil
local _refreshingDrop = false

local function sanitizeName(t)
    if t == nil then return nil end
    t = tostring(t):gsub('[/\\:*?"<>|]',""):gsub("^%s+",""):gsub("%s+$",""):sub(1,40)
    if t == "" or t:sub(1,3) == "[G]" then return nil end
    return t
end

local function setSaveName(t, silent)
    local n = sanitizeName(t)
    if not n then
        if not silent then UI_Library:Notify("Profiles","Invalid name") end
        return false
    end
    currentName = n
    pcall(function() NameLabel:SetText("Will save as: "..n) end)
    return true
end

local function refreshDrop()
    if _refreshingDrop then return end
    _refreshingDrop = true
    pcall(function()
        local p = listProfiles()
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
            for _, n in ipairs(p) do if n == selectedConfig then found=true break end end
            if not found then selectedConfig = p[1] or "Default" end
            pcall(function() ProfileDrop.Value = {selectedConfig} end)
        end
        if ConfigListLabel then
            local real = {}
            for _, n in ipairs(p) do if profileSourceMap[n] then table.insert(real,n) end end
            local msg = (#real==0) and "Saved: (none)" or ("Saved: "..table.concat(real," | "))
            pcall(function() ConfigListLabel:SetText(msg) end)
        end
    end)
    _refreshingDrop = false
end

do
    local made = false
    for _, method in pairs({"Textbox","Input","TextInput","TextBox"}) do
        local ok = pcall(function()
            ProfilesSec[method](ProfilesSec,"Config Name","type name + Enter, then Save",
                function(t) setSaveName(t, false) end)
        end)
        if ok then made=true break end
    end
    if not made then
        ProfilesSec:Info("Textbox unavailable — use clipboard button")
        ProfilesSec:Button("Set name from clipboard",function()
            local ok,c = pcall(getclipboard)
            if ok and c and tostring(c)~="" then
                setSaveName(c,false)
                UI_Library:Notify("Profiles","Will save as: "..currentName)
            else UI_Library:Notify("Profiles","Clipboard empty") end
        end)
    end
end

ProfileDrop = ProfilesSec:Dropdown("Load / Delete target",nil,listProfiles,false,function(l)
    if _refreshingDrop then return end
    local s = l
    if type(l)=="table" then s = l[1] or l.Value or l.Selected or l.Name end
    if type(s)=="string" and #s>0 then
        selectedConfig = s
        -- Selecting a real profile also becomes the Save target (not stuck on Default)
        if s:sub(1, 3) ~= "[G]" then
            setSaveName(s, true)
        end
    end
end)
pcall(function()
    if ProfileDrop and ProfileDrop.SetRefresh then ProfileDrop:SetRefresh(listProfiles) end
end)

ConfigListLabel = ProfilesSec:Label("Saved: (none)")

local function applySettings(s)
    if not s then return end
    local function setSlider(ref,val) if ref and val~=nil then pcall(function() ref:Set(val) end) end end
    local function setToggle(ref,val) if ref and val~=nil then pcall(function() ref:Set(val) end) end end
    if s.Enabled     ~=nil then CFG.Enabled=s.Enabled         setToggle(UIRefs.Armed,s.Enabled) end
    if s.AutoDodge   ~=nil then CFG.AutoDodge=s.AutoDodge     setToggle(UIRefs.AutoDodge,s.AutoDodge) end
    if s.MultiTarget ~=nil then CFG.MultiTarget=s.MultiTarget setToggle(UIRefs.MultiTarget,s.MultiTarget) end
    if s.Debug       ~=nil then CFG.Debug=s.Debug             setToggle(UIRefs.Debug,s.Debug) end
    if s.CycleRange        then CFG.CycleRange=s.CycleRange   setSlider(UIRefs.CycleRange,s.CycleRange) end
    if s.APRange           then CFG.APRange=s.APRange         setSlider(UIRefs.APRange,s.APRange) end
    if s.ParryOffset ~=nil then CFG.ParryOffset=s.ParryOffset setSlider(UIRefs.ParryOffset,s.ParryOffset) end
    if s.ParryHold         then CFG.ParryHold=s.ParryHold     setSlider(UIRefs.ParryHold,s.ParryHold) end
    if s.ParryWindow       then CFG.ParryWindow=s.ParryWindow setSlider(UIRefs.ParryWindow,s.ParryWindow) end
    if s.ParryCD           then PARRY_CD=s.ParryCD            setSlider(UIRefs.ParryCD,s.ParryCD) end
    if s.ProbabilityToParry then CFG.ProbabilityToParry=s.ProbabilityToParry setSlider(UIRefs.ProbabilityToParry,s.ProbabilityToParry) end
    if s.PingCompensate  ~=nil then CFG.PingCompensate=s.PingCompensate setToggle(UIRefs.PingCompensate,s.PingCompensate) end
    if s.AutoTargetNearest~=nil then CFG.AutoTargetNearest=s.AutoTargetNearest setToggle(UIRefs.AutoTargetNearest,s.AutoTargetNearest) end
    if s.RhythmAutoHit   ~=nil then CFG.RhythmAutoHit=s.RhythmAutoHit setToggle(UIRefs.RhythmAutoHit,s.RhythmAutoHit) end
        -- facing conditions
    if s.TargetFacingYou ~=nil then CFG.TargetFacingYou=s.TargetFacingYou setToggle(UIRefs.TargetFacingYou,s.TargetFacingYou) end
    if s.YouFacingTarget ~=nil then CFG.YouFacingTarget=s.YouFacingTarget  setToggle(UIRefs.YouFacingTarget,s.YouFacingTarget) end
    if s.FacingThreshold       then CFG.FacingThreshold=s.FacingThreshold  setSlider(UIRefs.FacingThreshold,s.FacingThreshold) end
    -- misc
    if s.SoundOnParry    ~=nil then CFG.SoundOnParry=s.SoundOnParry end
    if s.HeavyReadyNotify~=nil then CFG.HeavyReadyNotify=s.HeavyReadyNotify setToggle(UIRefs.HeavyReadyNotify,s.HeavyReadyNotify) end
    if s.HeavyCooldown          then CFG.HeavyCooldown=s.HeavyCooldown     setSlider(UIRefs.HeavyCooldown,s.HeavyCooldown) end
    if s.AntiAFK         ~=nil then CFG.AntiAFK=s.AntiAFK                 setToggle(UIRefs.AntiAFK,s.AntiAFK) end
    if s.AFKInterval           then CFG.AFKInterval=s.AFKInterval           setSlider(UIRefs.AFKInterval,s.AFKInterval) end
    if s.AutoRespawn     ~=nil then CFG.AutoRespawn=s.AutoRespawn          setToggle(UIRefs.AutoRespawn,s.AutoRespawn) end
    if s.RespawnDelay          then CFG.RespawnDelay=s.RespawnDelay         setSlider(UIRefs.RespawnDelay,s.RespawnDelay) end
    if s.DefaultRT             then DefaultRT=s.DefaultRT end
    if s.APKeybind then pcall(function() writeAPKeybind(s.APKeybind) end) end
    if s.AutoParryRange then CFG.APRange=s.AutoParryRange setSlider(UIRefs.APRange,s.AutoParryRange) end
end

ProfilesSec:Button("Save Current",function()
    -- Save target:
    -- 1) Dropdown selection if it is a real writable profile (not Default, not [G])
    -- 2) Otherwise the typed "Will save as" name
    -- Selecting a profile in the dropdown also updates currentName, so overwrites work.
    local name = nil
    if type(selectedConfig) == "string"
        and selectedConfig ~= ""
        and selectedConfig ~= "Default"
        and selectedConfig:sub(1, 3) ~= "[G]" then
        name = sanitizeName(selectedConfig)
    end
    if not name then
        name = sanitizeName(currentName)
    end
    -- Still allow explicitly saving a file named Default if the user typed it
    if not name and selectedConfig == "Default" and currentName == "Default" then
        name = "Default"
    end
    if not name then
        UI_Library:Notify("Profiles", "Type a config name first (then Enter), or pick a profile")
        return
    end
    currentName = name
    selectedConfig = name
    local t = {}
    for id,info in pairs(GameConfig) do t[id]=info.ReactionTime or DefaultRT end
    local kb = "g"
    pcall(function() if readAPKeybind then kb=readAPKeybind() or kb end end)
    CFG.APKeybind = kb
    local payload = {
        Timings=t,
        Settings={
            -- toggles
            Enabled=CFG.Enabled, AutoDodge=CFG.AutoDodge, MultiTarget=CFG.MultiTarget,
            Debug=CFG.Debug,
            -- facing conditions
            TargetFacingYou=CFG.TargetFacingYou, YouFacingTarget=CFG.YouFacingTarget,
            FacingThreshold=CFG.FacingThreshold,
            -- ranges + timing
            CycleRange=CFG.CycleRange, APRange=CFG.APRange,
            ParryOffset=CFG.ParryOffset, ParryHold=CFG.ParryHold, ParryWindow=CFG.ParryWindow,
            ParryCD=PARRY_CD, ProbabilityToParry=CFG.ProbabilityToParry,
            PingCompensate=CFG.PingCompensate, AutoTargetNearest=CFG.AutoTargetNearest,
            RhythmAutoHit=CFG.RhythmAutoHit,
            DefaultRT=DefaultRT, APKeybind=CFG.APKeybind,
            -- misc
            SoundOnParry=CFG.SoundOnParry,
            HeavyReadyNotify=CFG.HeavyReadyNotify, HeavyCooldown=CFG.HeavyCooldown,
            AntiAFK=CFG.AntiAFK, AFKInterval=CFG.AFKInterval,
            AutoRespawn=CFG.AutoRespawn, RespawnDelay=CFG.RespawnDelay,
            -- compat
            AutoParryRange=CFG.APRange,
        },
    }
    local savedPath = saveProfile(name,payload)
    if not savedPath then UI_Library:Notify("Profiles","Save FAILED") return end
    selectedConfig = name
    pcall(function() NameLabel:SetText("Will save as: "..name) end)
    refreshDrop()
    UI_Library:Notify("Profiles","Saved: "..name)
end)

ProfilesSec:Button("Load Selected",function()
    if not selectedConfig or selectedConfig=="" then
        UI_Library:Notify("Profiles","Pick a config in the dropdown first") return
    end
    if selectedConfig=="Default" and not profileSourceMap["Default"] then
        for id,info in pairs(GameConfig) do
            local orig=FlatConfig[id]
            if orig then info.ReactionTime=orig.ReactionTime or DefaultRT end
        end
        if bindStyle then pcall(bindStyle,currentStyleEdit) end
        UI_Library:Notify("Profiles","Loaded built-in Default timings") return
    end
    local data = loadProfile(selectedConfig)
    if not data then UI_Library:Notify("Profiles","Load failed: "..tostring(selectedConfig)) return end
    local n = 0
    if data.Timings then
        for id,rt in pairs(data.Timings) do
            local key = tostring(id)
            if not key:find("rbxassetid://",1,true) then key="rbxassetid://"..key end
            if GameConfig[key] then GameConfig[key].ReactionTime=tonumber(rt) or 0.1 n+=1 end
        end
    end
    applySettings(data.Settings or data)
    if selectedConfig:sub(1,3)~="[G]" then setSaveName(selectedConfig,true) end
    if bindStyle then pcall(bindStyle,currentStyleEdit) end
    UI_Library:Notify("Profiles","Loaded: "..selectedConfig.." ("..n.." timings)")
end)

ProfilesSec:Button("Delete Selected",function()
    if not selectedConfig or selectedConfig=="" then UI_Library:Notify("Profiles","Nothing selected") return end
    if selectedConfig:sub(1,3)=="[G]" then UI_Library:Notify("Profiles","Cannot delete [G] configs") return end
    if selectedConfig=="Default" and not profileSourceMap["Default"] then
        UI_Library:Notify("Profiles","Default is built-in") return
    end
    if not profileSourceMap[selectedConfig] then
        UI_Library:Notify("Profiles","Not a saved file: "..tostring(selectedConfig)) return
    end
    local deletedName = selectedConfig
    deleteProfile(selectedConfig)
    selectedConfig = "Default"
    setSaveName("Default",true)
    refreshDrop()
    UI_Library:Notify("Profiles","Deleted: "..deletedName)
end)

ProfilesSec:Button("Refresh List",function()
    refreshDrop() UI_Library:Notify("Profiles","List refreshed")
end)

ProfilesSec:Button("Reset Timings (built-in)",function()
    for id,info in pairs(GameConfig) do
        local orig=FlatConfig[id]
        if orig then info.ReactionTime=orig.ReactionTime or DefaultRT end
    end
    if bindStyle then pcall(bindStyle,currentStyleEdit) end
    UI_Library:Notify("Profiles","Timings reset")
end)

-- Armed
ArmedSec:Info("Auto-targets nearby players every 0.5s")
local APToggleElement = ArmedSec:Toggle("Auto Parry",true,function(v) CFG.Enabled=v end)
-- Keybind is for DISPLAY + REBIND only. Arming is handled by our InputBegan
-- (library "Toggle" mode only worked reliably for default G for some users).
APKeybindRef = nil
pcall(function()
    -- Try callback-style first (updates CFG when user rebinds)
    APKeybindRef = APToggleElement:AddKeybind("g", function(v)
        if type(v) == "string" and #v > 0 and v:lower() ~= "none" then
            CFG.APKeybind = v
        elseif v ~= nil then
            local n = tostring(v):match("KeyCode%.(.+)$") or tostring(v)
            if n and n ~= "" then CFG.APKeybind = n end
        end
    end)
end)
if not APKeybindRef then
    pcall(function()
        APKeybindRef = APToggleElement:AddKeybind("g", "Hold")
    end)
end
if not APKeybindRef then
    pcall(function()
        APKeybindRef = APToggleElement:AddKeybind("g", "Always")
    end)
end
pcall(function()
    local row = APKeybindRef or APToggleElement
    if not row then return end
    if row.OnChanged then
        row.OnChanged:Connect(function(v)
            if type(v) == "string" and #v > 0 then CFG.APKeybind = v end
        end)
    end
end)
UIRefs.Armed = APToggleElement
UIRefs.AutoDodge = ArmedSec:Toggle("Auto Dodge Heavy",true,function(v) CFG.AutoDodge=v end)
UIRefs.MultiTarget = ArmedSec:Toggle("Multiple Targets",true,function(v) CFG.MultiTarget=v end)
UIRefs.AutoTargetNearest = ArmedSec:Toggle("Auto Target Nearest",true,function(v) CFG.AutoTargetNearest=v end)

readAPKeybind = function()
    local row = APKeybindRef or APToggleElement
    if not row then return CFG.APKeybind or "g" end

    local function normalize(v)
        if v == nil then return nil end
        if type(v) == "string" then
            v = v:gsub("%s+", "")
            if #v > 0 and v:lower() ~= "none" then return v end
            return nil
        end
        -- Enum.KeyCode.X
        if typeof and typeof(v) == "EnumItem" then
            local n = tostring(v):match("KeyCode%.(.+)$")
            if n then return n end
        end
        local n = tostring(v)
        local short = n:match("KeyCode%.(.+)$")
        if short then return short end
        return nil
    end

    local bind = rawget(row, "Bind")
    if type(bind) == "table" then
        for _, prop in pairs({"Value", "Key", "CurrentKey", "Keybind", "Code"}) do
            local n = normalize(rawget(bind, prop))
            if n then CFG.APKeybind = n return n end
        end
    end
    for _, prop in pairs({"Key", "CurrentKey", "Keybind", "Value", "CurrentKeybind", "Bind"}) do
        local n = normalize(rawget(row, prop))
        if n then CFG.APKeybind = n return n end
    end
    -- deep search common INS layouts
    pcall(function()
        if row.Get then
            local n = normalize(row:Get())
            if n then CFG.APKeybind = n end
        end
    end)
    return CFG.APKeybind or "g"
end

writeAPKeybind = function(key)
    if not key or key=="" then return end
    CFG.APKeybind = key
    local row = APKeybindRef or APToggleElement
    if not row then return end
    local bind = rawget(row,"Bind")
    if type(bind)=="table" then bind.Value=key return end
    pcall(function() if row.Set then row:Set(key) end end)
end

CondSec:Info("Gate parry per target based on facing direction")
UIRefs.TargetFacingYou=CondSec:Toggle("Target facing you",false,function(v) CFG.TargetFacingYou=v end)
UIRefs.YouFacingTarget=CondSec:Toggle("You facing target",true,function(v) CFG.YouFacingTarget=v end)
UIRefs.FacingThreshold=CondSec:Slider("Facing Angle",0.5,0.05,0,1,"dot",function(v) CFG.FacingThreshold=tonumber(v) or 0.5 end)
UIRefs.FacingThreshold:Set(CFG.FacingThreshold)
CondSec:Info("0=any | 0.5=60° cone | 0.7=45° cone | 1.0=dead-on")
UIRefs.AutoHeight = CondSec:Toggle("Automatic Height Timing", true, function(v) CFG.AutoHeight = v end)
UIRefs.HeightInfluence = CondSec:Slider("Height Influence", 1, 0.05, 0, 2, "x", function(v) CFG.HeightInfluence = tonumber(v) or 1 end)
UIRefs.HeightInfluence:Set(1)
CondSec:Info("BodyHeightScale only. 1x = full effect")

TargetLabel = TargetSec:Label("Locked: (none)")
UIRefs.CycleRange = TargetSec:Slider("Cycle Range",20,1,5,60,"s",function(v) CFG.CycleRange=v end)
UIRefs.CycleRange:Set(CFG.CycleRange)
UIRefs.APRange = TargetSec:Slider("AP Range",10,1,5,60,"s",function(v) CFG.APRange=v end)
UIRefs.APRange:Set(10)

UIRefs.Debug = EngineSec:Toggle("Debug Parry",false,function(v)
    CFG.Debug=v
    if v then UI_Library:Notify("Debug ON","Will notify + print each parry fire") end
end)
UIRefs.ParryOffset = EngineSec:Slider("Parry Offset",0,0.001,-0.15,0.15,"s",function(v) CFG.ParryOffset=tonumber(v) or 0 end)
UIRefs.ParryOffset:Set(0)
UIRefs.ParryHold = EngineSec:Slider("Parry Hold",0.27,0.001,0.05,0.8,"s",function(v) CFG.ParryHold=tonumber(v) or 0.27 end)
UIRefs.ParryHold:Set(0.27)
UIRefs.ParryWindow = EngineSec:Slider("Parry Window",0.20,0.001,0,1,"s",function(v) CFG.ParryWindow=tonumber(v) or 0.20 end)
UIRefs.ParryWindow:Set(0.20)
UIRefs.ParryCD = EngineSec:Slider("Parry CD",0.05,0.001,0,1,"s",function(v) PARRY_CD=tonumber(v) or 0.05 end)
UIRefs.ParryCD:Set(0.05)
UIRefs.ProbabilityToParry = EngineSec:Slider("Probability To Parry",100,1,1,100,"%",function(v) CFG.ProbabilityToParry=tonumber(v) or 100 end)
UIRefs.ProbabilityToParry:Set(100)
UIRefs.PingCompensate = EngineSec:Toggle("Ping Compensation", true, function(v) CFG.PingCompensate=v end)
EngineSec:Info("Ping Comp subtracts half your ping from reaction time.")
EngineSec:Info("Window = how long after ideal fire time a parry is still accepted.")
EngineSec:Info("CD = min gap between parries.")

DebugSec:Label("Enable Debug Parry to see prints + notifs")
DebugSec:Button("Copy Unknown IDs",function()
    if #UnknownOrder==0 then UI_Library:Notify("Debug","None logged") return end
    setclipboard(table.concat(UnknownOrder,","))
    UI_Library:Notify("Debug","Copied "..#UnknownOrder.." unknown IDs")
end)
DebugSec:Button("Clear Unknown Log",function()
    table.clear(UnknownLog) table.clear(UnknownOrder)
    UI_Library:Notify("Debug","Cleared")
end)
DebugSec:Button("Flush Parry Queue",function()
    table.clear(pendingParries) table.clear(scheduledMap)
    UI_Library:Notify("Debug","Queue flushed")
end)

-- ── Timings Tab ──────────────────────────────
local StylePickSec   = TimingsTab:Section("Style Editor","Left")
local StyleSliderSec = TimingsTab:Section("Reaction Times","Right")

local styleNames = {} local stylesSeen = {}
for _,info in pairs(GameConfig) do
    if info.Style and not stylesSeen[info.Style] then
        stylesSeen[info.Style]=true table.insert(styleNames,info.Style)
    end
end
table.sort(styleNames)

local currentStyleEdit = styleNames[1] or "KarateAnims"
local MAX_SLOTS = 16
local slots = {}
local StyleTitleLabel = nil
local StyleHintLabel  = nil

for i = 1, MAX_SLOTS do
    local slotIndex = i
    local sl = StyleSliderSec:Slider("—",0,0.001,0,1,"s",function(v)
        local s = slots[slotIndex]
        if s and s.boundInfo then s.boundInfo.ReactionTime=v end
    end)
    sl:Set(0)
    slots[i] = {slider=sl, boundId=nil, boundInfo=nil, name="—"}
end

local function setSlotName(slot, text)
    local sl = slot.slider
    for _,m in pairs({"SetText","SetName","SetTitle","SetLabel"}) do
        pcall(function() if sl[m] then sl[m](sl,text) end end)
    end
    for _,p in pairs({"Title","Name","Text"}) do
        pcall(function() if rawget(sl,p)~=nil then sl[p]=text end end)
    end
    slot.name = text
end

bindStyle = function(styleName)
    if not styleName or styleName=="" then return end
    currentStyleEdit = styleName
    local collected = {}
    for id,info in pairs(GameConfig) do
        if info.Style==styleName then table.insert(collected,{id=id,info=info}) end
    end
    table.sort(collected, function(a, b)
        local function rank(name)
            name = tostring(name or "")
            -- Current set (no suffix) first, then A, B, special names
            if name:find("%(A%)") then return 2, name end
            if name:find("%(B%)") then return 3, name end
            if name:find("Feint") then return 4, name end
            return 1, name
        end
        local ra, na = rank(a.info.DisplayName)
        local rb, nb = rank(b.info.DisplayName)
        if ra ~= rb then return ra < rb end
        return na < nb
    end)
    local nice = styleName:gsub("Anims","")
    if StyleTitleLabel then pcall(function() StyleTitleLabel:SetText("EDITING: "..nice.."  ("..#collected.." anims)") end) end
    if StyleHintLabel  then pcall(function() StyleHintLabel:SetText("Right side shows "..nice.." only") end) end
    for i=1,MAX_SLOTS do
        local slot=slots[i] local entry=collected[i]
        if entry then
            slot.boundId=entry.id slot.boundInfo=entry.info
            AnimSliders[entry.id]=slot.slider
            local label=entry.info.DisplayName or ("Anim "..i)
            if entry.info.Heavy then label=label.." [HEAVY]" end
            setSlotName(slot,label)
            pcall(function() slot.slider:Set(entry.info.ReactionTime or DefaultRT) end)
            pcall(function() if slot.slider.SetVisible then slot.slider:SetVisible(true) end end)
        else
            slot.boundId=nil slot.boundInfo=nil
            setSlotName(slot,"—") pcall(function() slot.slider:Set(0) end)
            pcall(function() if slot.slider.SetVisible then slot.slider:SetVisible(false) end end)
        end
    end
    UI_Library:Notify("Timings","Now editing: "..nice)
end

StylePickSec:Info("Click a style → right side shows ONLY that style")
StyleTitleLabel = StylePickSec:Label("EDITING: —")
StyleHintLabel  = StylePickSec:Label("Pick a style below")
StylePickSec:Slider("Default RT",DefaultRT,0.001,0,0.5,"s",function(v) DefaultRT=v end):Set(DefaultRT)
StylePickSec:Button("Reset Current Style",function()
    for i=1,MAX_SLOTS do
        local slot=slots[i]
        if slot.boundId and FlatConfig[slot.boundId] then
            local rt=FlatConfig[slot.boundId].ReactionTime or DefaultRT
            slot.boundInfo.ReactionTime=rt pcall(function() slot.slider:Set(rt) end)
        end
    end
    UI_Library:Notify("Timings","Reset "..(currentStyleEdit:gsub("Anims","") or "?"))
end)
StylePickSec:Info("--- Styles ---")
do
    local COLS = 3
    local i = 1
    while i <= #styleNames do
        local s1 = styleNames[i]
        local row = StylePickSec:Button(s1:gsub("Anims",""), function() bindStyle(s1) end)
        for c = 1, COLS - 1 do
            local idx = i + c
            if idx <= #styleNames and row and row.AddButton then
                local sN = styleNames[idx]
                pcall(function()
                    row:AddButton(sN:gsub("Anims",""), function() bindStyle(sN) end)
                end)
            end
        end
        i = i + COLS
    end
end
bindStyle(currentStyleEdit)

-- ── Settings Tab ────────────────────────────
local MiscSec     = SettingsTab:Section("Misc","Left")
local AntiAFKSec  = SettingsTab:Section("Anti-AFK","Left")
local RespawnSec  = SettingsTab:Section("Auto Respawn","Right")
local SessionSec  = SettingsTab:Section("Session","Right")


-- Misc
MiscSec:Info("Misc quality-of-life options")
MiscSec:Toggle("Sound on Parry",false,function(v)
    CFG.SoundOnParry=v
end)
MiscSec:Info("Plays a click sound each time F is pressed")
UIRefs.HeavyReadyNotify = MiscSec:Toggle("Heavy Ready Notify", true, function(v)
    CFG.HeavyReadyNotify = v
    if not v then
        heavyNotified = true
        heavyCdUntil = 0
    end
end)
UIRefs.HeavyCooldown = MiscSec:Slider("Heavy Cooldown", 3.0, 0.1, 0.5, 10, "s", function(v)
    CFG.HeavyCooldown = tonumber(v) or 3.0
end)
UIRefs.HeavyCooldown:Set(3.0)
MiscSec:Info("Tracks YOUR M2/R anim, then notifies when the timer ends")
UIRefs.RhythmAutoHit = MiscSec:Toggle("Rhythm Auto-Hit", false, function(v)
    CFG.RhythmAutoHit = v
    UI_Library:Notify("Rhythm Auto-Hit", v and "ON — note minigame keys" or "OFF")
end)
MiscSec:Info("Auto-hits rhythm/note lanes (was Auto Play in original)")
MiscSec:Button("Unload Olympus",function()
    pcall(function()
        if _G.__OlympusAP and _G.__OlympusAP.Cleanup then
            _G.__OlympusAP:Cleanup()
        else
            UI_Window:Destroy()
        end
    end)
    print("[Olympus] Unloaded")
end)

-- Anti-AFK
AntiAFKSec:Info("Jumps every N seconds to prevent AFK kick")
UIRefs.AntiAFK = AntiAFKSec:Toggle("Anti-AFK",false,function(v)
    CFG.AntiAFK=v
    lastAFKPing=os.clock()  -- reset timer on toggle
    UI_Library:Notify("Anti-AFK", v and "Enabled — jumping every "..CFG.AFKInterval.."s" or "Disabled")
end)
UIRefs.AFKInterval = AntiAFKSec:Slider("AFK Interval",240,1,60,600,"s",function(v)
    CFG.AFKInterval=tonumber(v) or 240
end)
UIRefs.AFKInterval:Set(240)
AntiAFKSec:Info("60s min — 600s max. Default 240s (4 min)")

-- Auto Respawn
RespawnSec:Info("Respawns you automatically after death")
UIRefs.AutoRespawn = RespawnSec:Toggle("Auto Respawn",false,function(v)
    CFG.AutoRespawn=v
    UI_Library:Notify("Auto Respawn", v and "Enabled — "..CFG.RespawnDelay.."s delay" or "Disabled")
end)
UIRefs.RespawnDelay = RespawnSec:Slider("Respawn Delay",1.5,0.5,0.5,5,"s",function(v)
    CFG.RespawnDelay=tonumber(v) or 1.5
end)
UIRefs.RespawnDelay:Set(1.5)
RespawnSec:Info("Delay before respawn triggers. Lower = faster.")
RespawnSec:Button("Force Respawn Now",function()
    pcall(function() LocalPlayer:LoadCharacter() end)
    UI_Library:Notify("Respawn","Forced respawn")
end)

-- Session stats
local ParryCountLabel = SessionSec:Label("Parries this session: 0")
SessionSec:Info("Tracks parries fired since inject")
SessionSec:Button("Reset Counter",function()
    parryCount=0
    pcall(function() ParryCountLabel:SetText("Parries this session: 0") end)
end)

-- update counter in cycle
local _origCycle = cycleTargets
local _lastCountUpdate = 0
OlympusState:AddConnection(RunService.Heartbeat:Connect(function()
    local now2 = os.clock()
    if (now2-_lastCountUpdate) > 1 then
        _lastCountUpdate=now2
        pcall(function() ParryCountLabel:SetText("Parries this session: "..parryCount) end)
    end
end))

local UpdatesSec = UpdatesTab:Section("UPDATES","Left")
local SoonSec    = UpdatesTab:Section("COMING SOON","Right")
UpdatesSec:Info("5 New styles added")
UpdatesSec:Label("??? — Perfect Copy")
UpdatesSec:Label("Epic — Aikido")
UpdatesSec:Label("Uncommon — Taijutsu")
UpdatesSec:Label("Uncommon — Hikaken")
UpdatesSec:Label("Uncommon — Giovanna")
UpdatesSec:Divider("Notes")
UpdatesSec:Info("Aikido M2 is a counter (like Wing Chun). Force-parried — never auto-dodged.")
UpdatesSec:Label("Timing sliders: 0.001 step (thousandths)")
UpdatesSec:Label("Kyokushin M2 id updated (+80822959210741)")
SoonSec:Info("Planned")
SoonSec:Label("Auto Combo (M1 after parry)")
SoonSec:Label("Health-Safe Targeting")
SoonSec:Label("Style Detection Display")
SoonSec:Label("Snap Lock")
SoonSec:Label("Profile Quick-Switch keybind")
SoonSec:Divider("Credit")
SoonSec:Info("Made By Fgonzxlez")

local UIS = game:GetService("UserInputService")

local function keyStringToKeyCode(s)
    if s == nil then return nil end
    s = tostring(s):gsub("%s+", "")
    if s == "" or s:lower() == "none" then return nil end
    -- Enum name: "LeftShift", "G", "One", ...
    local ok, kc = pcall(function() return Enum.KeyCode[s] end)
    if ok and typeof(kc) == "EnumItem" then return kc end
    ok, kc = pcall(function() return Enum.KeyCode[s:upper()] end)
    if ok and typeof(kc) == "EnumItem" then return kc end
    ok, kc = pcall(function() return Enum.KeyCode[s:lower()] end)
    if ok and typeof(kc) == "EnumItem" then return kc end
    -- single character
    if #s == 1 then
        ok, kc = pcall(function() return Enum.KeyCode[s:upper()] end)
        if ok and typeof(kc) == "EnumItem" then return kc end
    end
    return nil
end

local function keyCodeToString(kc)
    if not kc then return nil end
    local n = tostring(kc)
    -- Enum.KeyCode.G -> G
    local short = n:match("KeyCode%.(.+)$") or n
    return short
end

local function syncKeybindFromUI()
    local k = nil
    pcall(function()
        if readAPKeybind then k = readAPKeybind() end
    end)
    if type(k) == "string" and #k > 0 and k:lower() ~= "none" then
        CFG.APKeybind = k
    end
end

local function setArmed(state)
    CFG.Enabled = state and true or false
    pcall(function()
        if UIRefs and UIRefs.Armed and UIRefs.Armed.Set then
            UIRefs.Armed:Set(CFG.Enabled)
        end
    end)
    pcall(function()
        if UI_Library and UI_Library.Notify then
            UI_Library:Notify("Auto Parry", CFG.Enabled and "ARMED" or "DISARMED")
        end
    end)
end

OlympusState:AddConnection(UIS.InputBegan:Connect(function(inp, gpe)
    if not OlympusState.Alive then return end
    if gpe then return end

    -- Menu toggle
    if inp.KeyCode == Enum.KeyCode.RightShift then
        menuOpen = not menuOpen
        return
    end

    -- Only keyboard for AP arm keybind
    if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end

    -- Pull latest key from UI so rebinds stick
    syncKeybindFromUI()
    local want = keyStringToKeyCode(CFG.APKeybind or "g")
    if not want then
        want = Enum.KeyCode.G
    end

    if inp.KeyCode == want then
        local t = os.clock()
        if (t - (OlympusState._lastArmToggle or 0)) < 0.2 then return end
        OlympusState._lastArmToggle = t
        setArmed(not CFG.Enabled)
    end
end))


refreshDrop()
setMenuInput(false)
pcall(function() setrobloxinput(true) end)

pcall(function() OlympusState.UI_Window = UI_Window end)
UI_Library:Notify("Olympus","v9.3.1 | RightShift (0.001 timing steps) = close menu")
print("[Olympus v9.3.1] loaded — AutoDodge gate + reliable AP keybind — ping/window/prob/ParryFunction/IgnoreIds/state/rhythm — Heavy Ready notify — Striker unique labels — full Striker anim sets — config save uses selected profile — Aikido M2 ForceParry — timing sliders step 0.001 — PerfectCopy/Aikido/Taijutsu/Giovanna/Hikaken + Kyokushin M2")

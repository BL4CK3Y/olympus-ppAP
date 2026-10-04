-- =============================================
-- Olympus Auto Parry — v9.2 (+ new styles)
-- Fixes: IgnoreIds crash, ESP_Utility nil, broken CD queue,
--        setrobloxinput fighting menu, menu lag (100+ hidden sliders)
-- =============================================

-- Services
local RunService  = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local PlayersSvc  = game:GetService("Players")
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

-- CRITICAL FIX: IgnoreIds was undefined → AnimationTracker.new(nil) broke AP
local IgnoreIds = {}

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
            ReactionTime = 0.100,
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
    Enabled=true,AutoDodge=true,MultiTarget=true,
    CycleRange=20,APRange=10,ParryOffset=0,ParryHold=0.27,AutoHeight=true,HeightInfluence=1,
    Debug=false,APKeybind="g",
    SoundOnParry=false,
    AntiAFK=false, AFKInterval=240,
    AutoRespawn=false, RespawnDelay=1.5,
    TargetFacingYou=false, YouFacingTarget=true,
    FacingThreshold=0.5,  -- dot product cutoff: 0.5 = within ~60°, 0.7 = within ~45°
}

local ParryKey = string.byte("F")
local DodgeKey = string.byte("Q")

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
                -- ForceParry (Aikido/WingChun counters): always F, never Q
                if e.config.ForceParry then
                    pcall(function() keypress(ParryKey) end)
                elseif e.config.Heavy and CFG.AutoDodge then
                    pcall(function()
                        for _ = 1, 3 do keypress(DodgeKey) keyrelease(DodgeKey) end
                    end)
                    e.releaseAt = now
                else
                    pcall(function() keypress(ParryKey) end)
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
                pcall(function() keyrelease(ParryKey) end)
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
    local rt = config.ReactionTime or DefaultRT
    if CFG.AutoHeight then
        local inf = tonumber(CFG.HeightInfluence) or 1
        local s = heightScale(character)
        rt = rt * (1 + (s - 1) * inf)
    end
    local animStart = now - timePos
    local fireAt = animStart + rt + CFG.ParryOffset
    local key = id .. string.format("%.2f", animStart)
    if scheduledMap[key] then return end
    if fireAt < now - 0.05 then return end
    scheduledMap[key] = true
    table.insert(pendingParries, {
        fireAt=fireAt, fired=false, releaseAt=nil,
        config=config, id=id, delay=math.max(0,fireAt-now),
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
    elseif #valid > 0 then
        table.insert(finals, valid[1].c)
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

RunService.Heartbeat:Connect(function()
    local now = os.clock()
    -- hard gate: if Matcha runs Heartbeat uncapped (like RenderStepped), kill 80-90% of calls here
    if (now - lastQueueTick) < HARD_RATE then return end
    lastQueueTick = now

    -- queue tick (every callback = 120Hz effective)
    if #pendingParries > 0 then tickParryQueue() end

    if (now-lastDetectTick) < DETECT_RATE then return end
    lastDetectTick = now
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
end)

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
    if s.ParryCD           then PARRY_CD=s.ParryCD            setSlider(UIRefs.ParryCD,s.ParryCD) end
        -- facing conditions
    if s.TargetFacingYou ~=nil then CFG.TargetFacingYou=s.TargetFacingYou setToggle(UIRefs.TargetFacingYou,s.TargetFacingYou) end
    if s.YouFacingTarget ~=nil then CFG.YouFacingTarget=s.YouFacingTarget  setToggle(UIRefs.YouFacingTarget,s.YouFacingTarget) end
    if s.FacingThreshold       then CFG.FacingThreshold=s.FacingThreshold  setSlider(UIRefs.FacingThreshold,s.FacingThreshold) end
    -- misc
    if s.SoundOnParry    ~=nil then CFG.SoundOnParry=s.SoundOnParry end
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
            ParryOffset=CFG.ParryOffset, ParryHold=CFG.ParryHold,
            ParryCD=PARRY_CD, DefaultRT=DefaultRT, APKeybind=CFG.APKeybind,
            -- misc
            SoundOnParry=CFG.SoundOnParry,
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
APKeybindRef = APToggleElement:AddKeybind("g","Toggle")
UIRefs.Armed = APToggleElement
UIRefs.AutoDodge = ArmedSec:Toggle("Auto Dodge Heavy",true,function(v) CFG.AutoDodge=v end)
UIRefs.MultiTarget = ArmedSec:Toggle("Multiple Targets",true,function(v) CFG.MultiTarget=v end)

readAPKeybind = function()
    local row = APKeybindRef or APToggleElement
    if not row then return CFG.APKeybind or "g" end
    local bind = rawget(row,"Bind")
    if type(bind)=="table" then
        local v = rawget(bind,"Value")
        if type(v)=="string" and #v>0 and v~="none" then return v end
    end
    for _,prop in pairs({"Key","CurrentKey","Keybind","Value","CurrentKeybind"}) do
        local v = rawget(row,prop)
        if type(v)=="string" and #v>0 and v~="none" then return v end
    end
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
UIRefs.ParryCD = EngineSec:Slider("Parry CD",0.05,0.001,0,1,"s",function(v) PARRY_CD=tonumber(v) or 0.05 end)
UIRefs.ParryCD:Set(0.05)
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
MiscSec:Button("Unload Olympus",function()
    pcall(function() UI_Window:Destroy() end) print("[Olympus] Unloaded")
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
RunService.Heartbeat:Connect(function()
    local now2 = os.clock()
    if (now2-_lastCountUpdate) > 1 then
        _lastCountUpdate=now2
        pcall(function() ParryCountLabel:SetText("Parries this session: "..parryCount) end)
    end
end)

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

game:GetService("UserInputService").InputBegan:Connect(function(inp,gpe)
    if gpe then return end
    if inp.KeyCode==Enum.KeyCode.RightShift then
        menuOpen=not menuOpen
    end
end)

refreshDrop()
setMenuInput(false)
pcall(function() setrobloxinput(true) end)

UI_Library:Notify("Olympus","v9.2.5 | RightShift (0.001 timing steps) = close menu")
print("[Olympus v9.2.5] loaded — Striker unique labels — full Striker anim sets — config save uses selected profile — Aikido M2 ForceParry — timing sliders step 0.001 — PerfectCopy/Aikido/Taijutsu/Giovanna/Hikaken + Kyokushin M2")

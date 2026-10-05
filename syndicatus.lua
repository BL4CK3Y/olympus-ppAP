-- =============================================
-- Syndicatus Auto Parry — v9.4.3 base, rebranded in v9.4.8
-- (lineage history retains the Olympus name on versions where that was its name)
-- =============================================
--
-- Original name: Olympus Auto Parry — v9.4.3
-- + Open-source registry + continuous window (lolbeans style)
-- + ConstLatency start-time, loop re-arm, consistent PARRYING
-- + Ping compensation, Parry Window, Probability
-- + ParryFunction, IgnoreIds, state anim lists
-- + Auto Target Nearest, Rhythm Auto-Hit
-- + BlockStart/BlockEnd, cleanup on re-inject
-- - Heavy Ready removed (was inaccurate)
-- - Global PARRY_CD removed (per-anim EXECUTE_DEBOUNCE instead)
-- v9.4.2 cleanup pass (zero AP delta):
--   * forward-declared BlockStart/BlockEnd/Dodge (de-leaked from _G)
--   * local RhythmAutoHitTick, removed dead _defer + _origCycle + PlayersSvc fallback
--   * ping cache @ 10Hz, height cache (weak-keyed per character)
--   * IsHeavy helper, facing-dot pcall unwrap (pure math, cannot throw)
--   * ipairs on Lanes, rhythm KeyByte precache, hoisted tostring(char) in anim loop
--   * cycleTargets arrays hoisted to module locals
--   * applySettings now persists AutoHeight + HeightInfluence; FacingThreshold = 0 now loads
--   * UnknownLog capped at 500 entries
-- v9.4.3:
--   Menu: restored INS animations + drag smoothness (dropped SetPerformance(true), reduced theme-reapply stacking)
--   AP consistency (silent, always-on — no UI toggles):
--     * Live BlockStart recompute per-frame — tracks ping drift during attack windup
--     * Movement bias: horizontal velocity > 20 studs/s shifts fire-point ~15ms earlier
--     * Ping-jitter window expansion (bounded ±25ms shift / +50ms window max)
--     * Local anim-state scan moved to Heartbeat (RS no longer processes own-char anims)
--     * Early-exit RS AP eval on LocalStunned (skips entire target+anim loop when stunned)
--   Config sharing: Export to Clipboard / Import from Clipboard / Import from URL (Profiles tab)
-- v9.4.4 FPS pass (zero AP delta):
--   * Menu auto-perf: tweens OFF when menu hidden (RightShift), ON when visible. You get animations
--     when you're looking, zero INS overhead during fights.
--   * Live BlockStart recompute throttled to every 3rd RS frame (~12ms refresh at 240Hz,
--     well inside ParryWindow tolerance — ping drift still tracked, 2/3 fewer CalculateParryTiming calls)
--   * cycleTargets sort comparator hoisted to module-local (no closure realloc per 2Hz tick)
--   * HB local anim scan early-exits when CFG.Enabled is false (one less matcha Update/HB while disarmed)
-- v9.4.5 feature pack (Techs tab + Visuals section):
--   * Anti Feint — releases F early when attack cancels before parry registers
--   * Crit Defense — randomizes F/Q 50/50 on Heavy/M2 attacks (overrides AutoDodge when on)
--   * Wing Chun Fake Wiff — rotates away + fires M1 to bait WC M2 counter whiff
--   * Shadow Step (Z) / Shadow Crit (B) — rapid F+Q taps on hotkey
--   * Personal HP — compact health bar at screen bottom
--   * Opponent HP — billboard bars over nearby players (gated by HP View Range)
--   * Low Lag Mode — suppresses visual overlays when on
-- v9.4.6 fix pass:
--   * Personal + Opponent HP: parent to gethui()/CoreGui proxy (survives game sanitization)
--     + protect_gui calls where executor supports it
--   * ParryHold + ParryWindow sliders REMOVED — hard-locked to source defaults
--     (Hold=0.27s, Window=0.20s). Legacy save profiles can no longer override these.
-- v9.4.7 strip pass:
--   * Visuals section fully removed (Personal HP, Opponent HP, HP View Range, Low Lag Mode)
--     game has native HP displays — redundant surface area, zero benefit
--   * Performance section removed (Low Lag only gated HP — nothing left to gate)
--   * Facing Threshold slider removed — hard-locked to source default 0.1
--     (source constant, not a tunable; exposing it caused "AP broken" reports)
--   * All related CFG keys, applySettings branches, save payload entries purged
-- v9.4.8 rebrand:
--   * Olympus → Syndicatus everywhere (UI title, notifies, print tags, internal identifiers)
--   * _G.__OlympusAP → _G.__SyndicatusAP (legacy key also cleaned on upgrade)
--   * PROFILE_FOLDER "Olympus" → "Syndicatus" (NOTE: old profiles stay in Olympus/ folder;
--     move them manually or re-save under the new name)
--   * INS config autosave key renamed (menu layout resets once on upgrade — one-time)
--   * External GitHub asset URL kept as-is (not ours)
--   * Share format tag updated; import still accepts legacy "olympus-share-v1"
-- =============================================

-- Cleanup previous inject — handle both the new _G key and the legacy one (v9.4.7 and earlier)
pcall(function()
    if _G.__SyndicatusAP and _G.__SyndicatusAP.Cleanup then
        _G.__SyndicatusAP:Cleanup()
    end
    if _G.__OlympusAP and _G.__OlympusAP.Cleanup then
        _G.__OlympusAP:Cleanup()
        _G.__OlympusAP = nil
    end
end)

local SyndicatusState = {
    Alive = true,
    Connections = {},
}
_G.__SyndicatusAP = SyndicatusState

function SyndicatusState:AddConnection(c)
    if c then table.insert(self.Connections, c) end
    return c
end

function SyndicatusState:Cleanup()
    self.Alive = false
    if self.Connections then
        for _, c in ipairs(self.Connections) do
            pcall(function() c:Disconnect() end)
        end
        table.clear(self.Connections)
    end
    pcall(function()
        if self.UI_Window and self.UI_Window.Destroy then
            self.UI_Window:Destroy()
        end
    end)
    print("[Syndicatus] Cleaned up previous session")
end

-- Services
local RunService  = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local PlayersSvc  = game:GetService("Players")
local StatsSvc    = game:GetService("Stats")

local LocalPlayer = PlayersSvc.LocalPlayer
if not LocalPlayer then LocalPlayer = PlayersSvc.PlayerAdded:Wait() end

-- Forward-declare AP primitives so BoxingM2 ParryFunction closure (in GameConfig below) captures the local slot
local BlockStart, BlockEnd, Dodge

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
            BoxingM2 = true,  -- gated by CFG.AutoBoxingM2
            -- Custom sequence: wait → block → dodge (original behavior)
            ParryFunction = function(data)
                if not CFG.AutoBoxingM2 then return end
                if data.RegistryData and data.RegistryData.Processed then return end
                if data.RegistryData then data.RegistryData.Processed = true end
                task.spawn(function()
                    task.wait(0.40)
                    BlockStart(os.clock(), 0.50)
                    if CFG.AutoDodge then
                        task.wait(0.30)
                        Dodge(true)
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
    print("[Syndicatus] Godzz + new-style defaults applied (" .. n .. " timings)")
end

-- ── Multi-Config ────────────────────────────
local PROFILE_FOLDER = "Syndicatus"
local LEGACY_PROFILE_FOLDER = "Olympus"  -- v9.4.8: fallback for pre-rebrand saves
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
    -- v9.4.8: also enumerate the pre-rebrand Olympus/ folder; marked with [L] prefix so
    -- users can see what's legacy and re-save under a clean name if they want
    if isfolder and isfolder(LEGACY_PROFILE_FOLDER) then
        local lfiles = {}
        pcall(function() lfiles = listfiles(LEGACY_PROFILE_FOLDER) or {} end)
        for _, f in pairs(lfiles) do
            local s = tostring(f)
            local n = s:match("([^/\\]+)%.json$")
            if n then
                local d = "[L] " .. n
                if not profileSourceMap[n] and not profileSourceMap[d] then
                    table.insert(names, d)
                    profileSourceMap[d] = { format = "json", path = s }
                end
            end
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
    Enabled=true,AutoDodge=true,AutoBoxingM2=true,MultiTarget=true,AutoTargetNearest=true,
    CycleRange=20,APRange=10,ParryOffset=0,ParryHold=0.27,ParryWindow=0.20,AutoHeight=true,HeightInfluence=1,
    PingCompensate=true,ProbabilityToParry=100,
    Debug=false,APKeybind="g",
    SoundOnParry=false,
    RhythmAutoHit=false,  -- rhythm note auto-hit (was Auto Play)
    AntiAFK=false, AFKInterval=240,
    AutoRespawn=false, RespawnDelay=1.5,
    TargetFacingYou=false, YouFacingTarget=true,
    FacingThreshold=0.1,  -- matches open-source (0.1); 0.5 ≈ 60° cone
    -- v9.4.5 feature pack (v9.4.7: HP/LowLag stripped — game has native HP)
    AntiFeint=false,
    CritDefense=false,
    WCFakeWiff=false, WCFakeWiffTime=0.18,
    ShadowStep=false, ShadowCrit=false,
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

-- 10Hz cache — refreshed on Heartbeat tick below. Worst-case fire-point drift
-- from 100ms ping staleness is ~5ms, well inside default 200ms ParryWindow.
local CachedPing = GetPingValue()
local lastPingUpdate = 0
local function GetCachedPing()
    return CachedPing
end

-- ── v9.4.3 consistency package (silent, always-on) ──
-- Ping jitter ring buffer: 20 samples @ 10Hz = 2s rolling window
local PING_SAMPLE_COUNT = 20
local pingSamples = table.create(PING_SAMPLE_COUNT, CachedPing)
local pingSampleIdx = 1
local pingJitter = 0  -- ms, max-min over window

-- Movement bias (horizontal velocity-driven early-fire)
-- > 20 studs/s (sprint-ish): -15ms. > 8 studs/s (walk): -8ms. Else 0.
local cachedMovementBias = 0

-- Height cache (weak-keyed per character — GC drops dead chars automatically).
-- BodyHeightScale is set at spawn and does not change mid-fight in FFTM-style games.
local heightCache = setmetatable({}, {__mode = "k"})
local function heightScale(character)
    if not character then return 1 end
    local cached = heightCache[character]
    if cached then return cached end
    local hum = character:FindFirstChildWhichIsA("Humanoid")
    if not hum then return 1 end
    local scale = hum:FindFirstChild("BodyHeightScale")
    local v = (scale and tonumber(scale.Value)) or 1
    heightCache[character] = v
    return v
end

-- Centralised heavy check — identical to the two previous inline copies
local function IsHeavy(cfg)
    return cfg.Heavy
        or cfg.DisplayName == "M2"
        or cfg.DisplayName == "Heavy"
        or (tostring(cfg.DisplayName or ""):find("M2") ~= nil)
end

-- ── AP core — ported from lolbeans67 (identical timing / fire path) ──
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
local InputRegisteredTime = nil
local ParryRegisteredTime = nil
local LastPendingRegData = nil
local AnimationRegistry = {}
local ConstLatency = 0.018
local EXECUTE_DEBOUNCE = 0.5
local parryCount = 0
local menuOpen = true

local function TransitionToState(s)
    CurrentParryState = s
end

-- Source: ReleaseDeadline = StartTime + HoldFor  (NOT os.clock() + hold)
function BlockStart(StartTime, HoldFor)
    if not StartTime then
        return
    end
    if not CFG.Enabled then return end
    if LocalStunned then return end

    if CurrentParryState ~= ParryState.IDLE then
        TransitionToState(ParryState.IDLE)
    end

    local hold = HoldFor or CFG.ParryHold or 0.27
    ReleaseDeadline = StartTime + hold
    KeyHeld = true
    InputRegisteredTime = os.clock()
    TransitionToState(ParryState.INPUT_PENDING)
    pcall(function() keypress(ParryKey) end)
end

function BlockEnd()
    KeyHeld = false
    TransitionToState(ParryState.IDLE)
    pcall(function() keyrelease(ParryKey) end)
end

function Dodge(force)
    if not force and not CFG.AutoDodge then
        return
    end
    BlockEnd()
    pcall(function()
        for _ = 1, 12 do
            keypress(DodgeKey)
            keyrelease(DodgeKey)
        end
    end)
end

-- ── v9.4.5 Shadow Step / Shadow Crit ──
-- Rapid simultaneous F+Q taps. Z = Shadow Step (standalone), B = Shadow Crit (same mechanic,
-- separately gated so you can bind them to different situations).
local function doShadowSequence()
    pcall(function()
        for _ = 1, 3 do
            keypress(ParryKey)
            keypress(DodgeKey)
            task.wait(0.02)
            keyrelease(ParryKey)
            keyrelease(DodgeKey)
            task.wait(0.02)
        end
    end)
end

-- ── v9.4.5 Wing Chun Fake Wiff ──
-- WC M2 is a counter — it whiffs if your M1 doesn't connect during their windup.
-- We rotate away briefly, fire M1 into empty air, then restore facing. One-shot per registry entry.
local WCFakeWiffActive = false
local function doWCFakeWiff(targetChar)
    if WCFakeWiffActive then return end
    WCFakeWiffActive = true
    task.spawn(function()
        local ok = pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
            if not targetHrp then return end

            local origCFrame = hrp.CFrame
            -- Face directly away from target so M1 cone misses
            local awayDir = (hrp.Position - targetHrp.Position)
            if awayDir.Magnitude < 0.01 then return end
            awayDir = awayDir.Unit
            hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + awayDir * 10)

            -- Fire M1 into empty air (bait their counter)
            if mouse1click then mouse1click() end

            task.wait(tonumber(CFG.WCFakeWiffTime) or 0.18)

            -- Restore original facing
            local lookTarget = hrp.Position + origCFrame.LookVector * 10
            hrp.CFrame = CFrame.new(hrp.Position, lookTarget)
        end)
        if not ok and CFG.Debug then print("[Syndicatus] WC Fake Wiff failed") end
        WCFakeWiffActive = false
    end)
end

-- ── v9.4.5 Anti Feint state ──
-- Tracks the regData we last fired on so we can detect its early disappearance (feint).
local AntiFeintTarget = nil  -- regData reference
local AntiFeintFireTime = 0


-- Exact source formula:
--   RT  -= half_ping (if ping comp)
--   adj = (RT * heightMul) + ParryOffset
--   ClockStart/End = StartTime + adj / adj+Window
local function CalculateParryTiming(attackConfig, StartTime, Target)
    local optimalReactionTime = attackConfig.ReactionTime or attackConfig.ParryTime or DefaultRT
    local HeightMultiplier = 1
    if CFG.AutoHeight then
        local inf = tonumber(CFG.HeightInfluence) or 1
        local s = heightScale(Target)
        HeightMultiplier = 1 + (s - 1) * inf
    end
    if CFG.PingCompensate then
        local CompValue = (GetCachedPing() / 1000) * 0.5
        optimalReactionTime = optimalReactionTime - CompValue
        if optimalReactionTime < 0 then optimalReactionTime = 0 end
    end
    -- v9.4.3 consistency: pull BlockStart earlier by jitterShift, extend window by 2 * jitterShift.
    -- jitterShift grows with ping variance (>40ms range triggers), capped at 25ms shift / +50ms window.
    local jitterShift = 0
    if pingJitter > 40 then
        jitterShift = math.min(0.025, (pingJitter - 40) / 4000)
    end
    local adjustedReactionTime = (optimalReactionTime * HeightMultiplier)
        + (CFG.ParryOffset or 0)
        + cachedMovementBias       -- velocity-driven early-fire while moving
        - jitterShift              -- pull leading edge earlier under ping instability
    local window = (tonumber(CFG.ParryWindow) or 0.20) + jitterShift * 2
    local ClockStart = StartTime + adjustedReactionTime
    local ClockEnd = StartTime + adjustedReactionTime + window
    return ClockStart, ClockEnd
end

local function UpdateAnimationRegistry(animKey, animId, now, currentTrackTime, attackConfig, TargetCharacter)
    if not AnimationRegistry[animKey] then
        local adjustedNow = now - ConstLatency
        local blockStart, blockExpire = CalculateParryTiming(attackConfig, adjustedNow, TargetCharacter)
        AnimationRegistry[animKey] = {
            StartTime = adjustedNow,
            Processed = false,
            CurrentClockTime = os.clock(),
            CurrentTrackTime = currentTrackTime,
            AnimationId = animId,
            DidALoop = false,
            BlockStart = blockStart,
            BlockExpire = blockExpire,
            RandomNum = math.random(1, 100),
            LastExecuteTime = 0,
        }
    end

    local regData = AnimationRegistry[animKey]

    -- Loop: TimePosition went backwards → re-arm
    if regData.CurrentTrackTime and (currentTrackTime < regData.CurrentTrackTime) then
        local blockStart, blockExpire = CalculateParryTiming(attackConfig, now - currentTrackTime, TargetCharacter)
        regData.Processed = false
        regData.DidALoop = true
        regData.BlockStart = blockStart
        regData.BlockExpire = blockExpire
        regData.StartTime = now - ConstLatency
        regData.RandomNum = math.random(1, 100)
    end

    regData.CurrentClockTime = os.clock()
    regData.CurrentTrackTime = currentTrackTime
    return regData
end

-- Source: BlockStart(regData.BlockStart) — passes the ideal window start as StartTime
local function ExecuteParry(regData, attackConfig)
    local now = os.clock()
    if (now - (regData.LastExecuteTime or 0)) < EXECUTE_DEBOUNCE then
        return
    end
    regData.LastExecuteTime = now

    if LocalStunned then return end
    if not CFG.Enabled then return end

    local isHeavy = IsHeavy(attackConfig)

    -- ForceParry counters: always F
    if attackConfig.ForceParry then
        if LastPendingRegData ~= regData then
            LastPendingRegData = regData
            BlockStart(regData.BlockStart, CFG.ParryHold)
            parryCount = parryCount + 1
        elseif regData.DidALoop then
            regData.DidALoop = false
            BlockStart(regData.BlockStart, CFG.ParryHold)
            parryCount = parryCount + 1
        end
        if CFG.Debug then
            print("[Syndicatus AP ForceParry]", attackConfig.Style, attackConfig.DisplayName)
        end
        return
    end

    if isHeavy then
        -- v9.4.5 Crit Defense: 50/50 F/Q on heavies, overrides AutoDodge when active
        if CFG.CritDefense then
            if math.random(1, 2) == 1 then
                -- Parry branch
                if LastPendingRegData ~= regData then
                    LastPendingRegData = regData
                    AntiFeintTarget = regData
                    AntiFeintFireTime = now
                    BlockStart(regData.BlockStart, CFG.ParryHold)
                    parryCount = parryCount + 1
                end
            else
                Dodge(true)  -- force dodge regardless of AutoDodge
                parryCount = parryCount + 1
            end
            if CFG.Debug then
                print(string.format("[Syndicatus CritDefense] %s | %s",
                    tostring(attackConfig.Style), tostring(attackConfig.DisplayName)))
            end
            return
        end
        if CFG.AutoDodge then
            Dodge()
            parryCount = parryCount + 1
            return
        end
    end

    -- Identical to source gate
    if LastPendingRegData ~= regData then
        LastPendingRegData = regData
        -- v9.4.5 Anti Feint: remember what we fired on so cleanup pass can detect early cancel
        AntiFeintTarget = regData
        AntiFeintFireTime = now
        BlockStart(regData.BlockStart, CFG.ParryHold)
        parryCount = parryCount + 1
        if CFG.SoundOnParry then
            pcall(function()
                local s = Instance.new("Sound")
                s.SoundId = "rbxassetid://6026984224"
                s.Volume = 0.4
                s.Parent = game:GetService("SoundService")
                s:Play()
                game:GetService("Debris"):AddItem(s, 2)
            end)
        end
        if CFG.Debug then
            print(string.format("[Syndicatus AP] Block [%s | %s]",
                tostring(attackConfig.Style), tostring(attackConfig.DisplayName)))
        end
    elseif LastPendingRegData == regData then
        if regData.DidALoop then
            regData.DidALoop = false
            AntiFeintTarget = regData
            AntiFeintFireTime = now
            BlockStart(regData.BlockStart, CFG.ParryHold)
            parryCount = parryCount + 1
        end
    end
end

-- ParryFunction (Boxing M2) — same window gate as source
local function TryParryFunction(regData, attackConfig, character, animId)
    if type(attackConfig.ParryFunction) ~= "function" then return false end

    if attackConfig.BoxingM2 and not CFG.AutoBoxingM2 then
        regData.Processed = true
        return true
    end

    local now = os.clock()
    local rt = attackConfig.ReactionTime or attackConfig.ParryTime or DefaultRT
    local window = tonumber(CFG.ParryWindow) or 0.20
    if (now - regData.StartTime) <= (rt + window / 2) then
        if CFG.Enabled then
            pcall(function()
                attackConfig.ParryFunction({
                    RegistryData = regData,
                    Mob = character,
                    AnimationId = animId,
                })
            end)
        end
        return true
    end
    return false
end

-- ── AnimationTracker ─────────────────────────
local AnimTrackerInst = nil
if AnimationTracker and AnimationTracker.new then
    local ok, inst = pcall(AnimationTracker.new, AnimationTracker, IgnoreIds)
    if ok then AnimTrackerInst = inst end
end

local _animScratch = {}
local function getAnims(character)
    for i = #_animScratch, 1, -1 do _animScratch[i] = nil end
    if not character or not AnimTrackerInst then return _animScratch end
    -- Guard: Matcha tracker can throw "attempt to index nil with 'X'" on invalid/despawned chars
    if character.Parent == nil then return _animScratch end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return _animScratch end
    local ok, tracks = pcall(function()
        return AnimTrackerInst:Update(character)
    end)
    if not ok or type(tracks) ~= "table" then return _animScratch end
    for i = 1, #tracks do
        local t = tracks[i]
        if t and t.AnimationId then
            _animScratch[#_animScratch + 1] = {
                id = tostring(t.AnimationId),
                pos = tonumber(t.TimePosition) or 0,
            }
        end
    end
    return _animScratch
end

-- ── Rhythm Auto-Hit ───────
-- Hardcoded keys (set these in Gakuran rhythm settings):
--   4-lane: Z  X  ,  .
--   2-lane: F  J
local Receptors = {
    Receptor1 = "Z",
    Receptor2 = "X",
    Receptor3 = ",",
    Receptor4 = ".",
}
local ReceptorXMap = {}
local HeldKeys = {}
local LastRhythmCache = 0
local Threshold = 30

local function rhythmKeyByte(key)
    if not key then return nil end
    key = tostring(key)
    if key == "," then return 0xBC end
    if key == "." then return 0xBE end
    if #key == 1 then return string.byte(key:upper()) end
    return string.byte(key:sub(1, 1):upper())
end

local function RhythmAutoHitTick()
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
        else
            Receptors.Receptor1 = "Z"
            Receptors.Receptor2 = "X"
            Receptors.Receptor3 = ","
            Receptors.Receptor4 = "."
        end
        -- re-map with updated keys
        table.clear(ReceptorXMap)
        for name, key in pairs(Receptors) do
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

    for _, note in ipairs(Lanes:GetChildren()) do
        if note.Name ~= "NoteTemplate" then continue end
        local notePos, noteSize
        pcall(function()
            notePos = note.AbsolutePosition
            noteSize = note.AbsoluteSize
        end)
        if not notePos or not noteSize then continue end
        local noteX = math.floor(notePos.X + noteSize.X / 2)

        local match
        for rx, data in pairs(ReceptorXMap) do
            if math.abs(noteX - rx) <= 10 then
                match = data
                break
            end
        end
        if not match or not match.Receptor then continue end

        local receptor = match.Receptor
        local receptorPos
        pcall(function() receptorPos = receptor.AbsolutePosition end)
        if not receptorPos then continue end
        local rName = match.ReceptorName
        local b = match.KeyByte
        if not b then continue end

        local tail = note:FindFirstChild("Tail")
        local hasTail = false
        pcall(function()
            hasTail = tail and tail.AbsoluteSize and tail.AbsoluteSize.Y > 0
        end)

        if hasTail then
            local whenHold
            pcall(function()
                whenHold = (tail.AbsolutePosition.Y + tail.AbsoluteSize.Y) - receptorPos.Y
            end)
            if whenHold and whenHold + 15 > Threshold then
                if not HeldKeys[rName] then
                    HeldKeys[rName] = true
                    pcall(function() keypress(b) end)
                end
            end
            if HeldKeys[rName] then
                local release = false
                pcall(function()
                    release = (tail.AbsolutePosition.Y - receptorPos.Y) > 0
                end)
                if release then
                    HeldKeys[rName] = nil
                    pcall(function() keyrelease(b) end)
                end
            end
        else
            if math.abs(notePos.Y - receptorPos.Y) < Threshold then
                if HeldKeys[rName] then
                    pcall(function() keyrelease(b) end)
                    HeldKeys[rName] = nil
                end
                task.spawn(function()
                    pcall(function() keypress(b) end)
                    task.wait(0.05)
                    pcall(function() keyrelease(b) end)
                end)
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

-- Hoisted scratch buffers for cycleTargets (runs 2Hz on Heartbeat)
local _candidates, _valid, _finals = {}, {}, {}
local function _validSortAsc(a, b) return a.d < b.d end

local function cycleTargets()
    local lc = LocalPlayer.Character
    local lr = lc and lc:FindFirstChild("HumanoidRootPart")
    if not lr then updateTargets({}) return end
    table.clear(_candidates)
    pcall(function()
        for _, p in pairs(PlayersSvc:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                _candidates[#_candidates+1] = p.Character
            end
        end
    end)
    table.clear(_valid)
    for _, c in ipairs(_candidates) do
        local tr = c:FindFirstChild("HumanoidRootPart")
        local h  = c:FindFirstChildWhichIsA("Humanoid")
        if tr and h and h.Health > 0 then
            local d = (lr.Position-tr.Position).Magnitude
            if d <= CFG.CycleRange then table.insert(_valid,{c=c,d=d}) end
        end
    end
    table.sort(_valid, _validSortAsc)
    table.clear(_finals)
    if CFG.MultiTarget then
        for i=1,math.min(3,#_valid) do table.insert(_finals,_valid[i].c) end
    elseif CFG.AutoTargetNearest and #_valid > 0 then
        table.insert(_finals, _valid[1].c)  -- nearest only
    elseif #_valid > 0 then
        -- keep previous lock if still valid, else nearest
        local prev = TargetCharacters[1]
        local keep = false
        if prev then
            for _, v in ipairs(_valid) do
                if v.c == prev then keep = true break end
            end
        end
        if keep then
            table.insert(_finals, prev)
        else
            table.insert(_finals, _valid[1].c)
        end
    end
    updateTargets(_finals)
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

-- ── MAIN LOOP — same AP path as source (RenderStepped, no rate limit) ──
-- Non-AP utilities moved to a light Heartbeat so RS stays lean.
SyndicatusState:AddConnection(RunService.RenderStepped:Connect(function()
    local now = os.clock()

    -- Source ParryTask: release when past deadline
    if KeyHeld and ReleaseDeadline > 0 and now >= ReleaseDeadline then
        BlockEnd()
    end

    -- Rhythm stays on RS for note accuracy (only when enabled)
    if CFG.RhythmAutoHit then
        pcall(RhythmAutoHitTick)
    end

    -- ── AP eval (unchanged logic) ──
    if not CFG.Enabled then return end
    if not AnimTrackerInst then return end
    -- v9.4.3: early-exit when stunned — can't parry anyway, skip the whole target+anim scan
    if LocalStunned then return end
    local lc = LocalPlayer.Character
    local lr = lc and lc:FindFirstChild("HumanoidRootPart")
    if not lr then return end

    local apRange = CFG.APRange
    local doDebug = CFG.Debug
    local currentActiveIds = {}
    local targets = TargetCharacters
    local nTargets = #targets

    for ti = 1, nTargets do
        local c = targets[ti]
        local tr = c:FindFirstChild("HumanoidRootPart")
        if not tr then continue end
        local dist = (lr.Position - tr.Position).Magnitude
        if dist > apRange then continue end

        local charKey = tostring(c)  -- Instance tostring is stable for its lifetime
        local anims = getAnims(c)
        if doDebug and (now - debugLastPrint) > 2 then
            debugLastPrint = now
            print("[Syndicatus DEBUG] targets=" .. nTargets ..
                " anims=" .. #anims .. " dist=" .. math.floor(dist))
            for ai = 1, #anims do
                local a = anims[ai]
                print("  " .. a.id .. " inDB=" .. tostring(GameConfig[a.id] ~= nil) .. " pos=" .. a.pos)
            end
        end

        for ai = 1, #anims do
            local anim = anims[ai]
            local animId = anim.id
            local config = GameConfig[animId]
            if not config then
                if doDebug and not UnknownLog[animId] and #UnknownOrder < 500 then
                    UnknownLog[animId] = true
                    local num = animId:match("%d+$") or animId:match("%d+")
                    if num then
                        UnknownOrder[#UnknownOrder + 1] = num
                        print("[Syndicatus UNKNOWN]", animId)
                    end
                end
                continue
            end

            -- Source uses anim.Address; we use character|id
            local animKey = charKey .. "|" .. animId
            currentActiveIds[animKey] = true

            local regData = UpdateAnimationRegistry(animKey, animId, now, anim.pos or 0, config, c)
            if regData.Processed then continue end

            -- v9.4.5 WC Fake Wiff: intercept WingChun M2 counter before ForceParry fires
            if CFG.WCFakeWiff and config.ForceParry and config.Style == "WingChunAnims" then
                if not regData.FakeWiffDone then
                    regData.FakeWiffDone = true
                    regData.Processed = true
                    doWCFakeWiff(c)
                    if CFG.Debug then print("[Syndicatus] WC Fake Wiff triggered on", c.Name) end
                end
                continue
            end

            -- ParryFunction first (source order)
            if TryParryFunction(regData, config, c, animId) then
                continue
            end

            -- Direction checks — source skips heavies; uses 0.1 when toggles on
            do
                local isHeavy = IsHeavy(config)
                if not isHeavy and (CFG.TargetFacingYou or CFG.YouFacingTarget) then
                    local passed = true
                    local threshold = tonumber(CFG.FacingThreshold) or 0.1
                    local direction = tr.Position - lr.Position
                    local mag = direction.Magnitude
                    if mag >= 0.001 then
                        direction = direction / mag
                        if CFG.TargetFacingYou then
                            if tr.CFrame.LookVector:Dot(-direction) < threshold then
                                passed = false
                            end
                        end
                        if passed and CFG.YouFacingTarget then
                            if lr.CFrame.LookVector:Dot(direction) < threshold then
                                passed = false
                            end
                        end
                    end
                    if not passed then continue end
                end
            end

            -- Probability (source: RandomNum > PTP → mark Processed)
            local prob = tonumber(CFG.ProbabilityToParry) or 100
            if regData.RandomNum > prob then
                regData.Processed = true
                continue
            end

            -- v9.4.3 live recompute, v9.4.4 throttled to every 3rd RS frame.
            -- At 240Hz: ~12ms refresh — well inside ParryWindow (default 200ms) and jitter headroom.
            -- Initial values from UpdateAnimationRegistry are already fresh, so skipping frames 1-2 is safe.
            -- LastPendingRegData gate catches post-fire shifts — recompute cannot double-fire.
            regData._recomputeFrame = (regData._recomputeFrame or 0) + 1
            if regData._recomputeFrame >= 3 then
                regData._recomputeFrame = 0
                local liveBlockStart, liveBlockExpire = CalculateParryTiming(config, regData.StartTime, c)
                regData.BlockStart = liveBlockStart
                regData.BlockExpire = liveBlockExpire
            end

            local BlockExpireTimer = regData.BlockExpire - now
            if now >= regData.BlockStart and BlockExpireTimer >= 0 then
                ExecuteParry(regData, config)
            end
        end
    end

    -- Cleanup registry entries whose animations stopped
    for key, val in pairs(AnimationRegistry) do
        if not currentActiveIds[key] then
            -- v9.4.5 Anti Feint: fired-upon attack vanished before parry registered → it was a feint
            if CFG.AntiFeint and KeyHeld and val == AntiFeintTarget and not LocalParrying then
                local sinceFire = now - AntiFeintFireTime
                if sinceFire < 0.4 then
                    BlockEnd()
                    AntiFeintTarget = nil
                    if CFG.Debug then
                        print("[Syndicatus AntiFeint] released F — attack cancelled at " ..
                            string.format("%.3fs", sinceFire))
                    end
                end
            end
            if LastPendingRegData == val then
                LastPendingRegData = nil
            end
            if AntiFeintTarget == val then
                AntiFeintTarget = nil
            end
            AnimationRegistry[key] = nil
        end
    end

    -- Clear Anti Feint target if we successfully entered PARRYING state
    if LocalParrying and AntiFeintTarget then
        AntiFeintTarget = nil
    end
end))

-- Light utility tick (not on RenderStepped — keeps AP frame clean)
SyndicatusState:AddConnection(RunService.Heartbeat:Connect(function()
    if not SyndicatusState.Alive then return end
    local now = os.clock()

    -- Ping cache refresh (10Hz) + jitter ring buffer update
    if (now - lastPingUpdate) >= 0.1 then
        lastPingUpdate = now
        CachedPing = GetPingValue()
        pingSamples[pingSampleIdx] = CachedPing
        pingSampleIdx = pingSampleIdx % PING_SAMPLE_COUNT + 1
        local lo, hi = math.huge, -math.huge
        for i = 1, PING_SAMPLE_COUNT do
            local v = pingSamples[i]
            if v < lo then lo = v end
            if v > hi then hi = v end
        end
        pingJitter = hi - lo
    end

    -- Movement-bias cache (velocity-driven early-fire)
    do
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local v = hrp.AssemblyLinearVelocity
                local horizSpeed = math.sqrt(v.X * v.X + v.Z * v.Z)
                if horizSpeed > 20 then
                    cachedMovementBias = -0.015
                elseif horizSpeed > 8 then
                    cachedMovementBias = -0.008
                else
                    cachedMovementBias = 0
                end
            else
                cachedMovementBias = 0
            end
        else
            cachedMovementBias = 0
        end
    end

    -- Local stun / parry state from own-character anim list (moved from RS for consistency under movement).
    -- v9.4.4: skip entirely when AP is disabled — matcha Update is the single biggest HB cost.
    if CFG.Enabled then
        LocalStunned = false
        LocalParrying = false
        local char = LocalPlayer.Character
        if char then
            local anims = getAnims(char)
            for i = 1, #anims do
                local a = anims[i]
                local id = a and a.id
                if id then
                    if animSetHas(StunnedAnimation, id) then
                        LocalStunned = true
                    end
                    if animSetHas(ParryingAnimation, id) then
                        LocalParrying = true
                        if CurrentParryState == ParryState.INPUT_PENDING then
                            TransitionToState(ParryState.PARRYING)
                            ParryRegisteredTime = now
                        end
                    end
                    if animSetHas(ParriedAnimation, id) or animSetHas(ParryFailedAnimation, id) then
                        if CurrentParryState ~= ParryState.IDLE then
                            TransitionToState(ParryState.IDLE)
                        end
                    end
                end
            end
        end
    else
        LocalStunned = false
        LocalParrying = false
    end

    -- Auto-respawn
    if pendingRespawn and CFG.AutoRespawn then
        local respawnDelay = tonumber(CFG.RespawnDelay) or 1.5
        if (now - pendingRespawn) >= respawnDelay then
            pendingRespawn = nil
            pcall(function() LocalPlayer:LoadCharacter() end)
        end
    end

    -- Anti-AFK
    if CFG.AntiAFK then
        local afkInterval = tonumber(CFG.AFKInterval) or 240
        if (now - lastAFKPing) >= afkInterval then
            lastAFKPing = now
            pcall(function()
                keypress(32)
                keyrelease(32)
            end)
        end
    end

    -- Target cycle + label (0.5s like source utility tick)
    if (now - lastCycle) >= 0.5 then
        lastCycle = now
        pcall(cycleTargets)
        if TargetLabel then
            pcall(function()
                local names = {}
                for i = 1, #TargetCharacters do
                    names[#names + 1] = TargetCharacters[i].Name
                end
                local pool = #names > 0 and table.concat(names, ", ") or "(none)"
                TargetLabel:SetText("Locked: " .. pool)
            end)
        end
    end
end))

-- ── UI ──────────────────────────────────────
if not UI_Library then
    warn("[Syndicatus] UI library failed — AP still runs headless")
    menuOpen = false
    pcall(function() setrobloxinput(true) end)
    return
end

local UIRefs = {
    Armed=nil,AutoDodge=nil,MultiTarget=nil,Debug=nil,
    CycleRange=nil,APRange=nil,ParryOffset=nil,ParryHold=nil,
    TargetFacingYou=nil,YouFacingTarget=nil,FacingThreshold=nil,
    AntiAFK=nil,AFKInterval=nil,AutoRespawn=nil,RespawnDelay=nil,
}

local function setMenuInput(open)
    menuOpen = open
end

local UI_Window = UI_Library:CreateWindow({
    title="Syndicatus",size=Vector2.new(740,580),configFolder="syndicatus_base",
    opacity = 1,
})

-- Pure black section/panel fill (kills grey wash)
-- SetPerformance here is driven by menu visibility (see syncMenuPerformance below).
local function applyDarkTheme()
    pcall(function()
        if UI_Library.SetOpacity then UI_Library:SetOpacity(1) end
        if UI_Library.SetTheme then
            UI_Library:SetTheme({
                Background = Color3.fromRGB(0, 0, 0),
            })
        end
    end)
end

-- v9.4.4 menu auto-perf: INS tweens have real GPU cost when menu is open.
-- SetPerformance(true) = tweens disabled = faster. We want that when menu is hidden
-- (fighting), and tweens enabled when menu is visible (user is interacting).
local menuVisible = true  -- INS creates the window visible on inject
local function syncMenuPerformance()
    pcall(function()
        if UI_Library and UI_Library.SetPerformance then
            UI_Library:SetPerformance(not menuVisible)
        end
    end)
end
applyDarkTheme()

-- Menu background — INS draws this ABOVE section cards (z ~119999).
-- High alpha = grey wash over everything. Keep low so black panels read solid.
local BG_IMAGE_URL = "https://raw.githubusercontent.com/BL4CK3Y/olympus-ppAP/main/content.png"
local function applyMenuBackground()
    pcall(function()
        if UI_Library and UI_Library.SetBackgroundImage then
            UI_Library:SetBackgroundImage(BG_IMAGE_URL, 0.10, 1, 1)
        end
    end)
end
applyMenuBackground()

local CombatTab   = UI_Window:Tab("Combat","sword")
local TimingsTab  = UI_Window:Tab("Timings","clock")
local TechsTab    = UI_Window:Tab("Techs","zap")
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
    if s.AutoBoxingM2~=nil then CFG.AutoBoxingM2=s.AutoBoxingM2 setToggle(UIRefs.AutoBoxingM2,s.AutoBoxingM2) end
    if s.MultiTarget ~=nil then CFG.MultiTarget=s.MultiTarget setToggle(UIRefs.MultiTarget,s.MultiTarget) end
    if s.Debug       ~=nil then CFG.Debug=s.Debug             setToggle(UIRefs.Debug,s.Debug) end
    if s.CycleRange        then CFG.CycleRange=s.CycleRange   setSlider(UIRefs.CycleRange,s.CycleRange) end
    if s.APRange           then CFG.APRange=s.APRange         setSlider(UIRefs.APRange,s.APRange) end
    if s.ParryOffset ~=nil then CFG.ParryOffset=s.ParryOffset setSlider(UIRefs.ParryOffset,s.ParryOffset) end
    -- v9.4.6: ParryHold + ParryWindow are hard-locked to source defaults. Legacy profiles
    -- that stored custom values are intentionally ignored here — don't let a bad save poison
    -- the AP timing. Users who want to tune these should modify CFG defaults in source.
    if s.ProbabilityToParry then CFG.ProbabilityToParry=s.ProbabilityToParry setSlider(UIRefs.ProbabilityToParry,s.ProbabilityToParry) end
    if s.PingCompensate  ~=nil then CFG.PingCompensate=s.PingCompensate setToggle(UIRefs.PingCompensate,s.PingCompensate) end
    if s.AutoTargetNearest~=nil then CFG.AutoTargetNearest=s.AutoTargetNearest setToggle(UIRefs.AutoTargetNearest,s.AutoTargetNearest) end
    if s.RhythmAutoHit   ~=nil then CFG.RhythmAutoHit=s.RhythmAutoHit setToggle(UIRefs.RhythmAutoHit,s.RhythmAutoHit) end
        -- facing conditions
    if s.TargetFacingYou ~=nil then CFG.TargetFacingYou=s.TargetFacingYou setToggle(UIRefs.TargetFacingYou,s.TargetFacingYou) end
    if s.YouFacingTarget ~=nil then CFG.YouFacingTarget=s.YouFacingTarget  setToggle(UIRefs.YouFacingTarget,s.YouFacingTarget) end
    -- v9.4.7: FacingThreshold hard-locked to 0.1 — legacy save values ignored
    if s.AutoHeight      ~=nil then CFG.AutoHeight=s.AutoHeight            setToggle(UIRefs.AutoHeight,s.AutoHeight) end
    if s.HeightInfluence ~=nil then CFG.HeightInfluence=s.HeightInfluence  setSlider(UIRefs.HeightInfluence,s.HeightInfluence) end
    -- v9.4.5 feature pack
    if s.AntiFeint     ~=nil then CFG.AntiFeint=s.AntiFeint             setToggle(UIRefs.AntiFeint,s.AntiFeint) end
    if s.CritDefense   ~=nil then CFG.CritDefense=s.CritDefense         setToggle(UIRefs.CritDefense,s.CritDefense) end
    if s.WCFakeWiff    ~=nil then CFG.WCFakeWiff=s.WCFakeWiff           setToggle(UIRefs.WCFakeWiff,s.WCFakeWiff) end
    if s.WCFakeWiffTime      then CFG.WCFakeWiffTime=s.WCFakeWiffTime   setSlider(UIRefs.WCFakeWiffTime,s.WCFakeWiffTime) end
    if s.ShadowStep    ~=nil then CFG.ShadowStep=s.ShadowStep           setToggle(UIRefs.ShadowStep,s.ShadowStep) end
    if s.ShadowCrit    ~=nil then CFG.ShadowCrit=s.ShadowCrit           setToggle(UIRefs.ShadowCrit,s.ShadowCrit) end
    -- v9.4.7: PersonalHP/OpponentHP/HPViewRange/LowLagMode stripped — ignored silently from legacy saves
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
    -- Force-read live pill key into CFG before encoding
    local kb = "g"
    pcall(function()
        if APToggleElement and APToggleElement.Bind and type(APToggleElement.Bind.Value) == "string"
            and #APToggleElement.Bind.Value > 0 and APToggleElement.Bind.Value ~= "none" then
            kb = APToggleElement.Bind.Value
        elseif readAPKeybind then
            kb = readAPKeybind() or kb
        end
    end)
    CFG.APKeybind = tostring(kb):lower()
    local payload = {
        Timings=t,
        Settings={
            -- toggles
            Enabled=CFG.Enabled, AutoDodge=CFG.AutoDodge, AutoBoxingM2=CFG.AutoBoxingM2,
            MultiTarget=CFG.MultiTarget,
            Debug=CFG.Debug,
            -- facing conditions
            TargetFacingYou=CFG.TargetFacingYou, YouFacingTarget=CFG.YouFacingTarget,
            -- height
            AutoHeight=CFG.AutoHeight, HeightInfluence=CFG.HeightInfluence,
            -- v9.4.5 feature pack
            AntiFeint=CFG.AntiFeint, CritDefense=CFG.CritDefense,
            WCFakeWiff=CFG.WCFakeWiff, WCFakeWiffTime=CFG.WCFakeWiffTime,
            ShadowStep=CFG.ShadowStep, ShadowCrit=CFG.ShadowCrit,
            -- ranges + timing
            CycleRange=CFG.CycleRange, APRange=CFG.APRange,
            ParryOffset=CFG.ParryOffset,  -- Hold+Window hard-locked; not saved
            ProbabilityToParry=CFG.ProbabilityToParry,
            PingCompensate=CFG.PingCompensate, AutoTargetNearest=CFG.AutoTargetNearest,
            RhythmAutoHit=CFG.RhythmAutoHit,
            DefaultRT=DefaultRT, APKeybind=CFG.APKeybind,
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
    print("[Syndicatus] Saved profile", name, "APKeybind=", CFG.APKeybind)
    selectedConfig = name
    pcall(function() NameLabel:SetText("Will save as: "..name) end)
    refreshDrop()
    UI_Library:Notify("Profiles","Saved: "..name.."  (AP key: "..tostring(CFG.APKeybind)..")")
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
    local loadedKb = tostring(CFG.APKeybind or "?")
    UI_Library:Notify("Profiles","Loaded: "..selectedConfig.." ("..n.." timings, AP key: "..loadedKb..")")
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

-- ── v9.4.3 config sharing ──
ProfilesSec:Divider("Share")
ProfilesSec:Info("Export your timings+settings to clipboard, or import someone else's")

local function buildSharePayload()
    -- Pull live keybind from pill
    local kb = "g"
    pcall(function()
        if APToggleElement and APToggleElement.Bind and type(APToggleElement.Bind.Value) == "string"
            and #APToggleElement.Bind.Value > 0 and APToggleElement.Bind.Value ~= "none" then
            kb = APToggleElement.Bind.Value
        elseif readAPKeybind then
            kb = readAPKeybind() or kb
        end
    end)
    CFG.APKeybind = tostring(kb):lower()
    local t = {}
    for id, info in pairs(GameConfig) do t[id] = info.ReactionTime or DefaultRT end
    return {
        _format = "syndicatus-share-v1",  -- importer accepts legacy "olympus-share-v1" too
        Timings = t,
        Settings = {
            Enabled=CFG.Enabled, AutoDodge=CFG.AutoDodge, AutoBoxingM2=CFG.AutoBoxingM2,
            MultiTarget=CFG.MultiTarget, Debug=CFG.Debug,
            TargetFacingYou=CFG.TargetFacingYou, YouFacingTarget=CFG.YouFacingTarget,
            AutoHeight=CFG.AutoHeight, HeightInfluence=CFG.HeightInfluence,
            -- v9.4.5 feature pack
            AntiFeint=CFG.AntiFeint, CritDefense=CFG.CritDefense,
            WCFakeWiff=CFG.WCFakeWiff, WCFakeWiffTime=CFG.WCFakeWiffTime,
            ShadowStep=CFG.ShadowStep, ShadowCrit=CFG.ShadowCrit,
            CycleRange=CFG.CycleRange, APRange=CFG.APRange,
            ParryOffset=CFG.ParryOffset,  -- Hold+Window hard-locked; not saved
            ProbabilityToParry=CFG.ProbabilityToParry,
            PingCompensate=CFG.PingCompensate, AutoTargetNearest=CFG.AutoTargetNearest,
            RhythmAutoHit=CFG.RhythmAutoHit,
            DefaultRT=DefaultRT, APKeybind=CFG.APKeybind,
            SoundOnParry=CFG.SoundOnParry,
            AntiAFK=CFG.AntiAFK, AFKInterval=CFG.AFKInterval,
            AutoRespawn=CFG.AutoRespawn, RespawnDelay=CFG.RespawnDelay,
            AutoParryRange=CFG.APRange,
        },
    }
end

local function applyShared(data)
    local tApplied, tMissing = 0, 0
    if type(data.Timings) == "table" then
        for id, rt in pairs(data.Timings) do
            local key = tostring(id)
            if not key:find("rbxassetid://", 1, true) then key = "rbxassetid://" .. key end
            if GameConfig[key] then
                GameConfig[key].ReactionTime = tonumber(rt) or 0.1
                tApplied = tApplied + 1
            else
                tMissing = tMissing + 1
            end
        end
    end
    local sApplied = 0
    if type(data.Settings) == "table" then
        applySettings(data.Settings)
        for _ in pairs(data.Settings) do sApplied = sApplied + 1 end
    end
    if bindStyle then pcall(bindStyle, currentStyleEdit) end
    return tApplied, tMissing, sApplied
end

ProfilesSec:Button("Export to Clipboard", function()
    local ok, err = pcall(function()
        local payload = buildSharePayload()
        local json = HttpService:JSONEncode(payload)
        setclipboard(json)
    end)
    if ok then
        UI_Library:Notify("Share", "Copied — paste to send")
    else
        UI_Library:Notify("Share", "Export failed: " .. tostring(err))
    end
end)

ProfilesSec:Button("Import from Clipboard", function()
    local ok, text = pcall(getclipboard)
    if not ok or type(text) ~= "string" or text == "" then
        UI_Library:Notify("Share", "Clipboard empty or unreadable")
        return
    end
    local okJ, data = pcall(function() return HttpService:JSONDecode(text) end)
    if not okJ or type(data) ~= "table" then
        UI_Library:Notify("Share", "Clipboard isn't valid Syndicatus JSON")
        return
    end
    local tApplied, tMissing, sApplied = applyShared(data)
    UI_Library:Notify("Share", string.format(
        "Imported %d timings (%d skipped), %d settings", tApplied, tMissing, sApplied))
end)

-- URL fetch (raw GitHub gist, pastebin raw, etc.)
local pendingUrl = ""
do
    local made = false
    for _, method in pairs({"Textbox","Input","TextInput","TextBox"}) do
        local ok = pcall(function()
            ProfilesSec[method](ProfilesSec,"Import URL","raw gist/pastebin URL + Enter",
                function(t) pendingUrl = tostring(t or "") end)
        end)
        if ok then made = true break end
    end
    if not made then
        ProfilesSec:Info("Textbox unavailable — use clipboard import instead")
    end
end
ProfilesSec:Button("Fetch & Load URL", function()
    local url = pendingUrl
    if not url or url == "" then
        UI_Library:Notify("Share", "Type a URL in the Import URL field first")
        return
    end
    local okFetch, body = pcall(function() return game:HttpGet(url) end)
    if not okFetch or type(body) ~= "string" or body == "" then
        UI_Library:Notify("Share", "Fetch failed — check URL + executor HttpGet permission")
        return
    end
    local okJ, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not okJ or type(data) ~= "table" then
        UI_Library:Notify("Share", "URL did not return valid Syndicatus JSON")
        return
    end
    local tApplied, tMissing, sApplied = applyShared(data)
    UI_Library:Notify("Share", string.format(
        "Loaded from URL: %d timings (%d skipped), %d settings", tApplied, tMissing, sApplied))
end)

-- Armed
ArmedSec:Info("Auto-targets nearby players every 0.5s")
-- ── AP arm toggle + INS keybind pill (Toggle mode) ──
-- INS stores the bind on the ROW: toggle.Bind = { Value = "g", Mode = "Toggle", ... }
-- Left-click pill = rebind (updates Bind.Value). Right-click = mode.
local APToggleElement = ArmedSec:Toggle("Auto Parry", true, function(v)
    CFG.Enabled = v and true or false
end)
UIRefs.Armed = APToggleElement

pcall(function()
    APToggleElement:AddKeybind(tostring(CFG.APKeybind or "g"):lower(), "Toggle")
end)

UIRefs.AutoDodge = ArmedSec:Toggle("Auto Dodge Heavy", true, function(v) CFG.AutoDodge = v end)
UIRefs.AutoBoxingM2 = ArmedSec:Toggle("Auto Boxing M2", true, function(v)
    CFG.AutoBoxingM2 = v
    pcall(function()
        UI_Library:Notify("Boxing M2", v and "AP will handle Boxing M2" or "Manual — AP ignores Boxing M2")
    end)
end)
ArmedSec:Info("OFF = you parry/dodge Boxing M2 yourself. ON = AP block→dodge sequence.")
UIRefs.MultiTarget = ArmedSec:Toggle("Multiple Targets", true, function(v) CFG.MultiTarget = v end)
UIRefs.AutoTargetNearest = ArmedSec:Toggle("Auto Target Nearest", true, function(v) CFG.AutoTargetNearest = v end)

-- Read/write the live pill via toggle.Bind.Value (INS internal)
readAPKeybind = function()
    local k = nil
    pcall(function()
        if APToggleElement and APToggleElement.Bind and type(APToggleElement.Bind.Value) == "string" then
            k = APToggleElement.Bind.Value
        end
    end)
    if type(k) == "string" and #k > 0 and k ~= "none" then
        CFG.APKeybind = k
        return k
    end
    return tostring(CFG.APKeybind or "g")
end

writeAPKeybind = function(key)
    if not key or key == "" then return end
    local s = tostring(key):gsub("%s+", ""):lower()
    if s == "" then return end
    CFG.APKeybind = s
    pcall(function()
        if APToggleElement and APToggleElement.Bind then
            APToggleElement.Bind.Value = s
            APToggleElement.Bind.Mode = "Toggle"
        elseif APToggleElement and APToggleElement.AddKeybind then
            APToggleElement:AddKeybind(s, "Toggle")
        end
    end)
end

-- Sync CFG from pill so Save always has the current key
SyndicatusState:AddConnection(RunService.Heartbeat:Connect(function()
    if not SyndicatusState.Alive then return end
    local t = os.clock()
    if (SyndicatusState._lastKbSync or 0) + 0.5 > t then return end
    SyndicatusState._lastKbSync = t
    pcall(function()
        if APToggleElement and APToggleElement.Bind then
            local k = APToggleElement.Bind.Value
            if type(k) == "string" and #k > 0 and k ~= "none" then
                CFG.APKeybind = k
            end
            -- force Toggle mode if user right-clicked to Hold
            if APToggleElement.Bind.Mode and APToggleElement.Bind.Mode ~= "Toggle" then
                APToggleElement.Bind.Mode = "Toggle"
            end
        end
    end)
end))

CondSec:Info("Gate parry per target based on facing direction")
UIRefs.TargetFacingYou=CondSec:Toggle("Target facing you",false,function(v) CFG.TargetFacingYou=v end)
UIRefs.YouFacingTarget=CondSec:Toggle("You facing target",true,function(v) CFG.YouFacingTarget=v end)
-- v9.4.7: Facing Angle slider removed. Source uses 0.1 as a constant threshold.
-- Still read from CFG.FacingThreshold (locked at init) so the condition toggles above still work.
CondSec:Info("Facing angle locked to source default (0.1 dot)")
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
-- Parry Hold (0.27s) and Parry Window (0.20s) are hard-locked to source defaults.
-- These are source-constants not meant for user tuning; exposing them historically caused
-- misconfigured ACs to blame the script. See CFG.ParryHold / CFG.ParryWindow.
UIRefs.ProbabilityToParry = EngineSec:Slider("Probability To Parry",100,1,1,100,"%",function(v) CFG.ProbabilityToParry=tonumber(v) or 100 end)
UIRefs.ProbabilityToParry:Set(100)
UIRefs.PingCompensate = EngineSec:Toggle("Ping Compensation", true, function(v) CFG.PingCompensate=v end)
EngineSec:Info("Ping Comp subtracts half your ping from reaction time.")
EngineSec:Info("Hold=0.27s / Window=0.20s locked to source defaults.")
EngineSec:Info("v9.4 uses open-source continuous registry (no global CD).")

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
DebugSec:Button("Flush Registry",function()
    table.clear(AnimationRegistry)
    LastPendingRegData = nil
    UI_Library:Notify("Debug","Registry flushed")
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

-- ── Techs Tab (v9.4.5) ────────────────────────
local AntiFeintSec   = TechsTab:Section("Anti Feint","Left")
local CritDefSec     = TechsTab:Section("Crit Defense","Left")
local WCFakeSec      = TechsTab:Section("Wing Chun Fake Wiff","Right")
local ShadowSec      = TechsTab:Section("Shadow Techs","Right")

AntiFeintSec:Info("Releases F if the fired-upon attack cancels before parry registers")
UIRefs.AntiFeint = AntiFeintSec:Toggle("Anti Feint", false, function(v) CFG.AntiFeint = v end)
AntiFeintSec:Info("Protects against feint bait — detection window is 400ms post-fire")

CritDefSec:Info("Randomizes F / Q (50/50) on Heavy / M2 attacks. Overrides Auto Dodge when on.")
UIRefs.CritDefense = CritDefSec:Toggle("Crit Defense", false, function(v) CFG.CritDefense = v end)
CritDefSec:Info("Breaks pattern reads where opponent expects pure dodge on crits")

WCFakeSec:Info("On WingChun M2 (counter), rotates away + fires M1 so your M1 whiffs,")
WCFakeSec:Info("baiting their counter to activate on empty air")
UIRefs.WCFakeWiff = WCFakeSec:Toggle("WC Counter Fake Wiff", false, function(v) CFG.WCFakeWiff = v end)
UIRefs.WCFakeWiffTime = WCFakeSec:Slider("Fake Wiff Time",0.18,0.01,0.05,0.4,"s",function(v)
    CFG.WCFakeWiffTime = tonumber(v) or 0.18
end)
UIRefs.WCFakeWiffTime:Set(0.18)
WCFakeSec:Info("Duration of the rotation before snapping back")

ShadowSec:Info("Z = Shadow Step | B = Shadow Crit")
ShadowSec:Info("Both press F+Q rapidly (3 taps, ~40ms each)")
UIRefs.ShadowStep = ShadowSec:Toggle("Shadow Step (Z)", false, function(v) CFG.ShadowStep = v end)
UIRefs.ShadowCrit = ShadowSec:Toggle("Shadow Crit (B)", false, function(v) CFG.ShadowCrit = v end)

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
UIRefs.RhythmAutoHit = MiscSec:Toggle("Rhythm Auto-Hit", false, function(v)
    CFG.RhythmAutoHit = v
    UI_Library:Notify("Rhythm Auto-Hit", v and "ON — set keys to Z X , . (4) or F J (2)" or "OFF")
end)
MiscSec:Info("Requires Gakuran keybinds: 4-lane = Z X Comma Period | 2-lane = F J")
MiscSec:Button("Unload Syndicatus",function()
    pcall(function()
        if _G.__SyndicatusAP and _G.__SyndicatusAP.Cleanup then
            _G.__SyndicatusAP:Cleanup()
        else
            UI_Window:Destroy()
        end
    end)
    print("[Syndicatus] Unloaded")
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
local _lastCountUpdate = 0
SyndicatusState:AddConnection(RunService.Heartbeat:Connect(function()
    local now2 = os.clock()
    if (now2-_lastCountUpdate) > 1 then
        _lastCountUpdate=now2
        pcall(function() ParryCountLabel:SetText("Parries this session: "..parryCount) end)
    end
end))

local UpdatesSec = UpdatesTab:Section("UPDATES","Left")
local SoonSec    = UpdatesTab:Section("COMING SOON","Right")

-- ── v9.4.8 ──
UpdatesSec:Divider("v9.4.8 — Rebrand")
UpdatesSec:Info("Changed")
UpdatesSec:Label("Olympus → Syndicatus (title, notifies, print tags, identifiers)")
UpdatesSec:Label("_G._SyndicatusAP (legacy _G._OlympusAP cleaned on upgrade)")
UpdatesSec:Label("Profiles save to Syndicatus/ folder")
UpdatesSec:Label("Share format tag updated — importer still accepts legacy tag")
UpdatesSec:Info("Backward compat")
UpdatesSec:Label("Legacy Olympus/ profiles show up with [L] prefix")
UpdatesSec:Label("Re-save them under a clean name when ready")

-- ── v9.4.7 ──
UpdatesSec:Divider("v9.4.7 — Strip Pass")
UpdatesSec:Info("Removed")
UpdatesSec:Label("Visuals section entirely (Personal HP + Opponent HP + View Range)")
UpdatesSec:Label("Performance section (Low Lag Mode had no purpose without HP)")
UpdatesSec:Label("Facing Angle slider — locked to source constant 0.1")
UpdatesSec:Label("~230 lines of dead GUI code stripped")
UpdatesSec:Info("Game has native HP displays — custom bars were redundant surface")

-- ── v9.4.6 ──
UpdatesSec:Divider("v9.4.6 — HP Fix + Timing Lock")
UpdatesSec:Info("Fixed")
UpdatesSec:Label("Personal HP now renders — parented to protected GUI container")
UpdatesSec:Label("Opponent HP bars now render — same fix via gethui()")
UpdatesSec:Label("Both survive game-side PlayerGui sanitization sweeps")
UpdatesSec:Info("Removed")
UpdatesSec:Label("Parry Hold slider (locked to source default: 0.27s)")
UpdatesSec:Label("Parry Window slider (locked to source default: 0.20s)")
UpdatesSec:Info("Hard-lock prevents accidental AP breakage from misconfigured profiles")

-- ── v9.4.5 ──
UpdatesSec:Divider("v9.4.5 — Techs + Visuals Pack")
UpdatesSec:Info("Added")
UpdatesSec:Label("Anti Feint — releases F if attack cancels pre-parry")
UpdatesSec:Label("Crit Defense — 50/50 F/Q on Heavy/M2 (overrides AutoDodge)")
UpdatesSec:Label("Wing Chun Fake Wiff — rotates away + fires M1 to bait counter")
UpdatesSec:Label("Shadow Step (Z) / Shadow Crit (B) — rapid F+Q taps")
UpdatesSec:Label("Personal HP — compact health bar at screen bottom")
UpdatesSec:Label("Opponent HP — billboard bars over nearby players")
UpdatesSec:Label("HP View Range slider (1–200 studs)")
UpdatesSec:Label("Low Lag Mode — suppresses visual overlays")
UpdatesSec:Label("New tab: Techs")
UpdatesSec:Label("New Settings sections: Visuals + Performance")
UpdatesSec:Info("All v9.4.5 keys persist in Save + Share payloads")

-- ── v9.4.4 ──
UpdatesSec:Divider("v9.4.4 — FPS Pass")
UpdatesSec:Info("Added")
UpdatesSec:Label("Menu auto-perf — tweens OFF when menu hidden (RightShift)")
UpdatesSec:Label("Full INS animations restored when menu is visible")
UpdatesSec:Info("Changed")
UpdatesSec:Label("Live BlockStart recompute throttled to every 3rd RS frame")
UpdatesSec:Label("cycleTargets sort comparator hoisted (no closure realloc)")
UpdatesSec:Label("HB local anim scan early-exits when AP disabled")
UpdatesSec:Info("Zero AP delta — all pure performance work")

-- ── v9.4.3 ──
UpdatesSec:Divider("v9.4.3 — Consistency + Sharing")
UpdatesSec:Info("Added — AP consistency (silent, always-on)")
UpdatesSec:Label("Live BlockStart recompute — tracks ping drift mid-windup")
UpdatesSec:Label("Movement bias — speed > 20 studs/s shifts fire -15ms")
UpdatesSec:Label("Walk bias — speed > 8 studs/s shifts fire -8ms")
UpdatesSec:Label("Ping-jitter window expansion (bounded ±25ms shift)")
UpdatesSec:Label("Early-exit RS AP eval on LocalStunned")
UpdatesSec:Info("Added — Config sharing (Profiles tab)")
UpdatesSec:Label("Export to Clipboard")
UpdatesSec:Label("Import from Clipboard")
UpdatesSec:Label("Import from URL (gist/pastebin raw)")
UpdatesSec:Info("Changed")
UpdatesSec:Label("Menu: dropped SetPerformance(true) — animations restored")
UpdatesSec:Label("Reduced theme-reapply stacking (5 → 3)")
UpdatesSec:Label("Local anim-state scan moved from RS to Heartbeat")

-- ── v9.4.2 ──
UpdatesSec:Divider("v9.4.2 — Cleanup Pass")
UpdatesSec:Info("Removed (dead code)")
UpdatesSec:Label("_defer function (never called)")
UpdatesSec:Label("_origCycle variable (never referenced)")
UpdatesSec:Label("PlayersSvc fallback branch (unreachable)")
UpdatesSec:Info("Fixed")
UpdatesSec:Label("FacingThreshold = 0 now loads from profile (was silently skipped)")
UpdatesSec:Label("AutoHeight + HeightInfluence persist on save/reload")
UpdatesSec:Label("Cleanup nil-guard on empty connections table")
UpdatesSec:Info("Optimized")
UpdatesSec:Label("Ping cache @ 10Hz (was per-registry-create)")
UpdatesSec:Label("Height cache (weak-keyed per character)")
UpdatesSec:Label("Rhythm KeyByte precomputed in ReceptorXMap")
UpdatesSec:Label("pairs → ipairs on Lanes:GetChildren")
UpdatesSec:Label("tostring(char) hoisted from inner anim loop")
UpdatesSec:Label("cycleTargets arrays hoisted to module locals")
UpdatesSec:Label("Facing-dot pcall unwrapped (pure math)")
UpdatesSec:Label("IsHeavy helper (de-dup from 2 inline copies)")
UpdatesSec:Info("Hardened")
UpdatesSec:Label("BlockStart/BlockEnd/Dodge forward-declared (de-leaked from _G)")
UpdatesSec:Label("RhythmAutoHitTick made local (de-leaked from _G)")
UpdatesSec:Label("UnknownLog capped at 500 entries")

-- ── Styles ──
UpdatesSec:Divider("Styles")
UpdatesSec:Info("5 styles added")
UpdatesSec:Label("??? — Perfect Copy")
UpdatesSec:Label("Epic — Aikido")
UpdatesSec:Label("Uncommon — Taijutsu")
UpdatesSec:Label("Uncommon — Hikaken")
UpdatesSec:Label("Uncommon — Giovanna")
UpdatesSec:Divider("Style Notes")
UpdatesSec:Info("Aikido M2 is a counter (like Wing Chun). Force-parried — never auto-dodged.")
UpdatesSec:Label("Timing sliders: 0.001 step (thousandths)")
UpdatesSec:Label("Kyokushin M2 id updated (+80822959210741)")

-- ── Coming Soon ──
SoonSec:Info("Planned")
SoonSec:Label("Auto Combo (M1 after parry)")
SoonSec:Label("Health-Safe Targeting")
SoonSec:Label("Style Detection Display")
SoonSec:Label("Snap Lock")
SoonSec:Label("Profile Quick-Switch keybind")
SoonSec:Label("X Target (manual target lock)")
SoonSec:Label("Timing Learner (auto-tune via trials)")
SoonSec:Label("Record Test Logs")
SoonSec:Label("Auto R (universal auto-crit)")
SoonSec:Label("Damage Logs")
SoonSec:Label("Named Configs polish")
SoonSec:Label("Add unknowns to ignore list (one-click)")

SoonSec:Divider("Credit")
SoonSec:Info("Made By Fgonzxlez")

-- INS UI drives the AP toggle via the keybind pill (Toggle mode).
-- No custom InputBegan needed for arming — the library handles it.
-- RightShift still toggles menu visibility if the lib doesn't already.
local UIS = game:GetService("UserInputService")
SyndicatusState:AddConnection(UIS.InputBegan:Connect(function(inp, gpe)
    if not SyndicatusState.Alive then return end
    if gpe then return end
    if inp.UserInputType == Enum.UserInputType.Keyboard then
        if inp.KeyCode == Enum.KeyCode.RightShift then
            menuOpen = not menuOpen
            menuVisible = not menuVisible
            syncMenuPerformance()
        elseif CFG.ShadowStep and inp.KeyCode == Enum.KeyCode.Z then
            task.spawn(doShadowSequence)
        elseif CFG.ShadowCrit and inp.KeyCode == Enum.KeyCode.B then
            task.spawn(doShadowSequence)
        end
    end
end))

refreshDrop()
setMenuInput(false)
pcall(function() setrobloxinput(true) end)

pcall(function() SyndicatusState.UI_Window = UI_Window end)

-- Re-apply after INS config autosave settles. One deferred catch is enough —
-- stacking multiple delayed reapplies caused drag frame-stutter.
applyMenuBackground()
applyDarkTheme()
syncMenuPerformance()  -- initial perf state matches initial menu visibility
task.defer(function() applyMenuBackground() applyDarkTheme() end)
task.delay(1.0, function() applyMenuBackground() applyDarkTheme() end)
UI_Library:Notify("Syndicatus","v9.4.8 | Rebranded from Olympus")
print("[Syndicatus v9.4.8] Rebrand pass | legacy _G key + Olympus/ profile folder still readable")

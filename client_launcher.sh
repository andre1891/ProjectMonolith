#!/usr/bin/env bash
# =============================================================================
#  Project Monolith - CLIENT Launcher  (Linux/Wine port of client_launcher.bat)
#  - Builds/edits config.json (read by Client DLL)
#  - Launches: wine OrionClient-Win64-Shipping.exe ...
#
#  PLACEMENT: put this script next to OrionClient-Win64-Shipping.exe
#             (OrionGame/Binaries/Win64/)
#
#  Environment overrides:
#    WINE_BIN      wine executable          (default: wine)
#    WINE_PREFIX   Wine prefix for the game (default: ~/.wine-paragon-client)
#
#  Hero/skin tables below are generated from client_launcher.bat.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

CLIENTEXE="OrionClient-Win64-Shipping.exe"
CONFIG="$PWD/config.json"
WINE_BIN="${WINE_BIN:-wine}"
WINE_PREFIX="${WINE_PREFIX:-$HOME/.wine-paragon-client}"

banner() { printf '\n%s\n' "============================================================"; }
die()    { echo "ERROR: $*" >&2; exit 1; }

# --- preflight -----------------------------------------------------------------
command -v "$WINE_BIN" >/dev/null 2>&1 || die "wine not found ('$WINE_BIN'). Install it first (e.g. sudo dnf install wine)"
[ -f "$CLIENTEXE" ] || die "$CLIENTEXE not found in $PWD - place this script next to the client executable"
if ! ls /usr/share/wine/winmd/*.winmd >/dev/null 2>&1; then
    die "wine-common missing (/usr/share/wine/winmd empty) -> wineboot livelocks. Fix: sudo dnf install wine-common"
fi
[ -f /usr/lib64/wine-wow64/wine/x86_64-windows/wldap32.dll ] || \
    die "wine-ldap missing (wldap32.dll) -> game dies instantly with exit 53. Fix: sudo dnf install wine-ldap"

banner
echo           "            PROJECT MONOLITH  -  CLIENT LAUNCHER (Linux/Wine)"
banner
echo
echo "  Prefix: $WINE_PREFIX"
echo

# Initialize the Wine prefix on first use.
if [ ! -f "$WINE_PREFIX/system.reg" ]; then
    echo "Initializing Wine prefix (first run, may take a minute)..."
    WINEPREFIX="$WINE_PREFIX" WINEDLLOVERRIDES="mscoree,mshtml=" \
        "$WINE_BIN" wineboot -u >/dev/null 2>&1 || true
fi

# Ensure Wine loads OUR app-dir xinput1_3.dll (the loader shim for Client.dll).
# Without a native-only override, Wine silently falls back to its builtin
# xinput stub and Client.dll never gets loaded.
WINEPREFIX="$WINE_PREFIX" WINEDLLOVERRIDES="mscoree,mshtml=" \
    "$WINE_BIN" reg add "HKCU\\Software\\Wine\\DllOverrides" /v xinput1_3 /t REG_SZ /d n /f >/dev/null 2>&1 || true

# --- hero table: "Display|ConsoleName" (console name goes into config.json) -------
HEROES=(
    "Murdock|Price"
    "Gadget|Gadget"
    "Grux|Grux"
    "Muriel|Muriel"
    "Rampage|Rampage"
    "Sparrow|Sparrow"
    "Steel|Steel"
    "Twinblast|TwinBlast"
    "Kwang|Kwang"
    "FengMao|ArcBlade"
    "Crunch|Crunch"
    "Dekker|Totem"
    "Gideon|RiftMage"
    "Howitzer|HyperBreach"
    "Kallari|Kurohane"
    "Sevarog|Hammer"
    "IggyScorch|Pyro"
    "GrimExe|Coil"
    "Riktor|Chains"
    "Khaimera|Tomahawk"
    "Greystone|Sword"
    "Fey|Venus"
    "Narbash|WarDrum"
    "LtBelicia|Tacticia"
    "Countess|Vamp"
    "Wukong|Wukong"
    "Tera|Justice"
    "Aurora|Ice"
    "Shinbi|Mudang"
    "Morigesh|Mambo"
    "Revenant|Revenant"
    "Yin|Femme"
    "Zinx|Medic"
    "Serath|FallenAngel"
    "Drongo|Shrapnel"
    "Wraith|Ghost"
    "Phase|Phase"
)

# --- per-hero skin lists (0 = Default, no skin key) --------------------------------
load_skins() {
    local console="$1"
    SKINS=()
    case "$console" in
        Price)
            SKINS=("ChallengerSkin_Price" "MasterSkin_Price" "PriceSkin_Default" "RivalSkin_Price" "Skin_Price_Buy_T1_5_Wasteland" "Skin_Price_Buy_T1_Executioner" "Skin_Price_Buy_T1_Halloween" "Skin_Price_Buy_T2_Green_Carbon" "Skin_Price_Buy_T2_Snakebite" "Skin_Price_Buy_T2_polar_Strike" "Skin_Price_Buy_Tier2_BioFreak" "Skin_Price_Buy_Tier2_BlueBioFreak" "Skin_Price_Buy_Tier2_GreenBioFreak" "Skin_Price_Gift_A_SpecialForces" "Skin_Price_Gift_CS_Monarch" "Skin_Price_Tier1_5_Shogun") ;;
        Gadget)
            SKINS=("ChallengerSkin_Gadget" "GadgetSkin_Default" "GadgetSkin_Shellshock" "GadgetSkin_Shellshock_RP1" "GadgetSkin_Shellshock_RP2" "MasterSkin_Gadget" "RivalSkin_Gadget" "Skin_Gadget_Buy_A_Camo" "Skin_Gadget_Buy_T1_Winter2016") ;;
        Grux)
            SKINS=("ChallengerSkin_Grux" "GruxSkin_Default" "MasterSkin_Grux" "RivalSkin_Grux" "STAR_Skin_Grux_Buy_T1_Tribal" "STAR_Skin_Grux_Challenger" "STAR_Skin_Grux_Halloween" "STAR_Skin_Grux_Master" "STAR_Skin_Grux_Rival" "Skin_Grux_Buy_A_Tribal" "Skin_Grux_Buy_T1_Halloween" "Skin_Grux_Buy_Tier2_Beetle" "Skin_Grux_Buy_Tier2_Qilin" "Skin_Grux_Buy_Tier_1_5_Chestplate" "Skin_Grux_Drop_Tier2_BlackBeetle" "Skin_Grux_Drop_Tier2_GoldBeetle" "Skin_Grux_Drop_Tier3_MagmaBeetle") ;;
        Muriel)
            SKINS=("ChallengerSkin_Muriel" "MasterSkin_Muriel" "MurielSkin_Default" "RivalSkin_Muriel" "Skin_Muriel_Buy_A_Copper" "Skin_Muriel_Buy_T1_Amethyst" "Skin_Muriel_Buy_T3_DarkAngel" "Skin_Muriel_Earn_T1_Midnight") ;;
        Rampage)
            SKINS=("ChallengerSkin_Rampage" "MasterSkin_Rampage" "RampageSkin_Default" "RivalSkin_Rampage" "Skin_Rampage_Buy_A_Bloodrage" "Skin_Rampage_Buy_T1_Redneck" "Skin_Rampage_Buy_Tier2_Elemental" "Skin_Rampage_Buy_Tier2_Elemental_Copper" "Skin_Rampage_Buy_Tier2_Elemental_Ent" "Skin_Rampage_Buy_Tier2_Elemental_Ice" "Skin_Rampage_Tier1_5_Armored") ;;
        Sparrow)
            SKINS=("ChallengerSkin_Sparrow" "MasterSkin_Sparrow" "RivalSkin_Sparrow" "SparrowSkin_Default" "SparrowSkin_WildWestRP1" "SparrowSkin_WildWestRP2" "SparrowSkin_Wild_West" "Skin_Sparrow_Buy_A_AutumnFire" "Skin_Sparrow_Buy_T1_5_Raven" "Skin_Sparrow_Buy_T1_5_Tough" "Skin_Sparrow_Buy_T1_Halloween" "Skin_Sparrow_Buy_T2_Rogue" "Skin_Sparrow_Buy_T2_Rogue_RP1" "Skin_Sparrow_Buy_T2_Rogue_RP2" "Skin_Sparrow_Gift_CS_Monarch") ;;
        Steel)
            SKINS=("BuySkin_Steel_A_CarbonFiber" "BuySkin_Steel_T1_Aegis" "ChallengerSkin_Steel" "MasterSkin_Steel" "RivalSkin_Steel" "Skin_Steel_CS_Gift_Cobalt" "Skin_Steel_T1_Buy_Diesel" "Skin_Steel_T1_Buy_PolyTech" "Skin_Steel_T3_Buy_Mayan" "Skin_Steel_T3_Buy_MayanStone" "Skin_Steel_T3_Buy_MayanWarpaint" "SteelSkin_Default") ;;
        TwinBlast)
            SKINS=("ChallengerSkin_Twinblast" "MasterSkin_Twinblast" "RivalSkin_Twinblast" "Skin_TwinBlast_Buy_T2_ActionMovie" "Skin_TwinBlast_Buy_T2_ActionMovie_Boss" "Skin_Twinblast_Buy_A_Wasteland" "Skin_Twinblast_Buy_T1_Energized" "Skin_Twinblast_Buy_T1_Halloween" "Skin_Twinblast_Buy_T2_ShadowOps" "Skin_Twinblast_Buy_T2_ShadowOps_Carbon" "Skin_Twinblast_Buy_T2_ShadowOps_Gilded" "Skin_Twinblast_Buy_T2_ShadowOps_RedWhite" "Skin_Twinblast_Buy_T2_SummerTime" "Skin_Twinblast_Buy_T2_SummerTime_RP1" "TwinBlastSkin_Default") ;;
        Kwang)
            SKINS=("Challengerskin_Kwang" "KwangSkin_Default" "MasterSkin_Kwang" "RivalSkin_Kwang" "SKin_Kwang_Buy_T1_SilverGhost" "SKin_Kwang_Buy_T1_rosewood" "Skin_Kwang_Buy_T1_Sunburst" "Skin_Kwang_Buy_T2_Manbun" "Skin_Kwang_Buy_T2_Manbun_RP1" "Skin_Kwang_Buy_T2_Manbun_RP2" "Skin_Kwang_Buy_T2_Zombie") ;;
        ArcBlade)
            SKINS=("ArcBladeSkin_Default" "ChallengerSkin_ArcBlade" "MasterSkin_Arcblade" "RivalSkin_Arcblade" "STAR_Skin_Arcblade_Challenger" "STAR_Skin_Arcblade_Master" "STAR_Skin_Arcblade_Rival" "Skin_Arcblade_Buy_A_InnerFire" "Skin_Arcblade_Buy_T1_DarkReaper" "Skin_Arcblade_Buy_T1_Winter2016" "Skin_Arcblade_Buy_T2_RG-BoneCollector" "Skin_Arcblade_Buy_T2_RG-Horns" "Skin_Arcblade_Buy_T2_RG-Undertow" "Skin_Arcblade_Buy_T2_RP1_RoyalGuard" "Skin_Arcblade_Buy_T2_RP2_RoyalGuard" "Skin_Arcblade_Buy_T2_RoyalGuard") ;;
        Crunch)
            SKINS=("ChallengerSkin_Crunch" "MasterSkin_Crunch" "RivalSkin_Crunch" "Skin_Crunch_Buy_T1_GoldenGloves" "Skin_Crunch_Buy_T1_Siege" "Skin_Crunch_Buy_T1_Titanium" "Skin_Crunch_Buy_T1_Valentines2017" "Skin_Crunch_Buy_T3_Black_Site" "Skin_Crunch_Buy_T3_Crash_Site" "Skin_Crunch_Buy_T3_Crash_Site_RP1" "Skin_Crunch_Default") ;;
        Totem)
            SKINS=("ChallengerSkin_Totem" "MasterSkin_Totem" "RivalSkin_Totem" "Skin_Totem_Buy_A_Static" "Skin_Totem_Buy_T1_Arctic" "Skin_Totem_Buy_T1_Valentines2017" "Skin_Totem_Gift_CS_Monarch" "TotemSkin_Default") ;;
        RiftMage)
            SKINS=("ChallengerSkin_Riftmage" "MasterSkin_RiftMage" "RiftMageSkin_Default" "RivalSkin_Riftmage" "Skin_Riftmage_Buy_T2_Tough" "Skin_Riftmage_Buy_Tier1_Halloween" "Skin_Riftmage_Buy_Tier1_Inquisitor" "Skin_Riftmage_Buy_Tier2_Undertow" "Skin_Riftmage_Drop_Tier2_Undertow_Carnivale" "Skin_Riftmage_Drop_Tier2_Undertow_GoldSkull") ;;
        HyperBreach)
            SKINS=("BuySkin_Hyperbreach_A_Hotrod" "BuySkin_Hyperbreach_A_Wasteland" "ChallengerSkin_Hyperbreach" "HyperBreachSkin_Default" "MasterSkin_Hyperbreach" "RivalSkin_Hyperbreach" "Skin_Hyperbreach_Buy_T2_WhiteDome" "Skin_Hyperbreach_Drop_T2_LoveMachine") ;;
        Kurohane)
            SKINS=("BuySkin_Kurohane_A_Purple" "ChallengerSkin_Kurohane" "KurohaneSkin_Default" "MasterSkin_Kurohane" "RivalSkin_Kurohane" "Skin_Kurohane_Buy_T1_Winter2016" "Skin_Kurohane_Buy_T2_Rogue" "Skin_Kurohane_Buy_T2_Rogue_RP1" "Skin_Kurohane_Buy_T2_Rogue_RP2" "Skin_Kurohane_T1_5_Tough" "Skin_Kurohane_T1_5_Wasteland" "Skin_Kurohane_T1_Buy_RedDeath") ;;
        Hammer)
            SKINS=("ChallengerSkin_Hammer" "HammerSkin_Default" "MasterSkin_Hammer" "RivalSkin_Hammer" "STAR_Skin_Hammer_Challenger" "STAR_Skin_Hammer_Master" "STAR_Skin_Hammer_Rival" "STAR_Skin_Hammer_T1_Buy_GrandOracle" "STAR_Skin_Hammer_T1_RedEmperor" "Skin_Hammer_T1_Buy_GrandOracle" "Skin_Hammer_T1_Buy_MaskedReaper" "Skin_Hammer_T1_Earn_RedEmporer") ;;
        Pyro)
            SKINS=("ChallengerSkin_Pyro" "MasterSkin_Pyro" "RivalSkin_Pyro" "STAR_Skin_Pyro_Challenger" "STAR_Skin_Pyro_Master" "STAR_Skin_Pyro_Rival" "Skin_Pyro_Buy_T1_Tribal" "Skin_Pyro_Buy_T1_Winter2016" "Skin_Pyro_Buy_T3_Phoenix" "Skin_Pyro_Buy_T3_Robot" "Skin_Pyro_Buy_T3_Robot_RP1" "Skin_Pyro_Buy_T3_Robot_RP2" "Skin_Pyro_Buy_Tier1_Fireball" "Skin_Pyro_Default") ;;
        Coil)
            SKINS=("ChallengerSkin_Coil" "CoilSkin_Default" "MasterySkin_Coil" "RivalSkin_Coil" "Skin_Coil_Buy_T1_5_Wasteland" "Skin_Coil_Buy_T1_MetallicGreen" "Skin_Coil_Buy_T1_RazorRed") ;;
        Chains)
            SKINS=("ChainsSkin_BadSanta" "ChainsSkin_Default" "ChallengerSkin_Chains" "MasterSkin_Chains" "RivalSkin_Chains" "Skin_Chains_Buy_A_BronzeWarden") ;;
        Tomahawk)
            SKINS=("STAR_Skin_Tomahawk_Buy_T1_Halloween" "STAR_Skin_Tomahawk_Buy_T1_PitViper" "STAR_Skin_Tomahawk_Buy_T1_SunTiger" "STAR_Skin_Tomahawk_Buy_T1_WhiteTiger" "STAR_Skin_Tomahawk_Challenger" "STAR_Skin_Tomahawk_Def" "STAR_Skin_Tomahawk_Master" "STAR_Skin_Tomahawk_Rival" "Skin_Tomahawk_Buy_T1_Halloween" "Skin_Tomahawk_Buy_T1_PitViper" "Skin_Tomahawk_Buy_T1_SunTiger" "Skin_Tomahawk_Buy_T1_WhiteTiger" "Skin_Tomahawk_Buy_T2_GruxPelt" "Skin_Tomahawk_Buy_T2_GruxPelt_RP1" "TomahawkSkin_Challenger" "TomahawkSkin_Default" "TomahawkSkin_Mastery" "TomahawkSkin_Rival") ;;
        Sword)
            SKINS=("Skin_Sword_Buy_T1_Spaceknight" "Skin_Sword_Buy_T1_Spaceknight_RP1" "Skin_Sword_Buy_T1_Spaceknight_RP2" "Skin_Sword_T1_Buy_DragonLord" "Skin_Sword_T1_Buy_WhiteTiger" "Skin_Sword_T2_99Tough" "Skin_Sword_T2_99Tough_RP1" "Skin_Sword_T2_99Tough_RP2" "SwordSkin_Challenger" "SwordSkin_Default" "SwordSkin_Master" "SwordSkin_Rival") ;;
        Venus)
            SKINS=("STAR_Skin_Venus_Buy_T1_Autumnal_RP1" "STAR_Skin_Venus_Challenger" "STAR_Skin_Venus_Def" "STAR_Skin_Venus_Master" "STAR_Skin_Venus_Rival" "Skin_Venus_Buy_T2_Autumnal" "Skin_Venus_Buy_T2_Autumnal_RP1" "Skin_Venus_Buy_T2_Autumnal_RP2" "Skin_Venus_Buy_T2_CelestialButterfly" "Skin_Venus_Buy_T2_RoseButterfly" "Skin_Venus_Buy_Tier1_Angelic" "Skin_Venus_Buy_Tier1_Nightshade" "Skin_Venus_Buy_Tier1_Rainbow" "VenusSkin_Challenger" "VenusSkin_Default" "VenusSkin_Mastery" "VenusSkin_Rival") ;;
        WarDrum)
            SKINS=("STAR_Skin_WarDrum_Buy_Tier1_Ginger" "STAR_Skin_Wardrum_Buy_T1_BlueBeat" "STAR_Skin_Wardrum_Challenger" "STAR_Skin_Wardrum_Def" "STAR_Skin_Wardrum_Master" "STAR_Skin_Wardrum_Rival" "Skin_WarDrum_Buy_Tier1_Ginger" "Skin_WarDrum_Buy_Tier3_Scarecrow" "Skin_WarDrum_Buy_Tier3_Scarecrow_RP1" "Skin_WarDrum_Challenger" "Skin_WarDrum_Default" "Skin_WarDrum_Master" "Skin_WarDrum_Rival" "Skin_Wardrum_Buy_T1_BlueBeat") ;;
        Tacticia)
            SKINS=("ChallengerSkin_Tacticia" "MasterSkin_Tacticia" "RivalSkin_Tacticia" "Skin_Tacticia_Buy_T1_Halloween" "Skin_Tacticia_Buy_T2_HeavyArmor" "Skin_Tacticia_Buy_Tier1_ShadowCommander" "Skin_Tacticia_Buy_Tier1_YellowHazard" "TacticiaSkin_Default" "TacticiaSkin_Zombie") ;;
        Vamp)
            SKINS=("ChallengerSkin_Vamp" "MasterSkin_Vamp" "RivalSkin_Vamp" "STAR_Skin_Vamp_Buy_T1_Carnivale" "STAR_Skin_Vamp_Buy_T1_GoldenMasque" "STAR_Skin_Vamp_Buy_T1_RedHex" "STAR_Skin_Vamp_Buy_T2_Shogun" "STAR_Skin_Vamp_Challenger" "STAR_Skin_Vamp_Def" "STAR_Skin_Vamp_Master" "STAR_Skin_Vamp_Rival" "Skin_Vamp_Buy_T1_Carnivale" "Skin_Vamp_Buy_T1_GoldenMasque" "Skin_Vamp_Buy_T1_RedHex" "Skin_Vamp_Buy_T2_Shogun" "VampSkin_Default") ;;
        Wukong)
            SKINS=("Skin_Wukong_Buy_T2_Halloween" "Skin_Wukong_Buy_T3_Future" "Skin_Wukong_Buy_T3_GreatSage" "Skin_Wukong_Buy_T3_PolarStrike" "Skin_Wukong_Challenger" "Skin_Wukong_Default" "Skin_Wukong_Fury" "Skin_Wukong_Master" "Skin_Wukong_Rival" "Skin_Wukong_Royalty") ;;
        Justice)
            SKINS=("JusticeSkin_Buy_Tier1_5_DragonHorn" "JusticeSkin_Buy_Tier1_5_Gryphon" "JusticeSkin_Challenger" "JusticeSkin_Cyber" "JusticeSkin_Default" "JusticeSkin_Master" "JusticeSkin_Rival") ;;
        Ice)
            SKINS=("STAR_Skin_Ice_Buy_T1_Geode" "STAR_Skin_Ice_Challenger" "STAR_Skin_Ice_Def" "STAR_Skin_Ice_Master" "STAR_Skin_Ice_Rival" "Skin_Ice_Buy_T15_PorcelainFlower" "Skin_Ice_Buy_T1_5_Winter" "Skin_Ice_Buy_T1_Geode" "Skin_Ice_Challenger" "Skin_Ice_Default" "Skin_Ice_LichQueen" "Skin_Ice_LichQueen_Emerald" "Skin_Ice_Master" "Skin_Ice_Rival") ;;
        Mudang)
            SKINS=("MudangSkin_Challenger" "MudangSkin_Default" "MudangSkin_Master" "MudangSkin_Rival" "Skin_Mudang_Buy_T1_Dynasty") ;;
        Mambo)
            SKINS=("MamboSkin_Challenger" "MamboSkin_DarkHeart" "MamboSkin_Default" "MamboSkin_Mastery" "MamboSkin_Rival" "STAR_Skin_Mambo_Challenger" "STAR_Skin_Mambo_Master" "STAR_Skin_Mambo_Rival" "Skin_Mambo_Buy_T3_Frost" "Skin_Mambo_Buy_T3_NorthernMystic_Antlers") ;;
        Revenant)
            SKINS=("Skin_Revenant_Buy_T3_Winter" "Skin_Revenant_Buy_T_1_5_Raven" "Skin_Revenant_Challenger" "Skin_Revenant_Chronos" "Skin_Revenant_Default" "Skin_Revenant_Master" "Skin_Revenant_Rival") ;;
        Femme)
            SKINS=("FemmeSkin_Challenger" "FemmeSkin_Default" "FemmeSkin_Master" "FemmeSkin_Rival" "Skin_Femme_Buy_T1_WindGauntlet" "Skin_Femme_Buy_T2_Halloween") ;;
        Medic)
            SKINS=("Skin_Medic_Challenger" "Skin_Medic_Default" "Skin_Medic_Master" "Skin_Medic_NightPrism" "Skin_Medic_PlacidPearl" "Skin_Medic_Rival") ;;
        FallenAngel)
            SKINS=("FallenAngelSkin_Default" "Skin_FallenAngel_Buy_T1_FutureAngelic" "Skin_FallenAngel_Buy_T1_GoldandRed" "Skin_FallenAngel_Buy_T1_Tough" "Skin_FallenAngel_Buy_T1_Valentines2017" "Skin_FallenAngel_Buy_T1_Zombie" "Skin_FallenAngel_Challenger" "Skin_FallenAngel_Master" "Skin_FallenAngel_Rival") ;;
        Shrapnel)
            SKINS=("ShrapnelSkin_Challenger" "ShrapnelSkin_Default" "ShrapnelSkin_Master" "ShrapnelSkin_Rival" "Skin_Shrapnel_Buy_T15_Cyclops" "Skin_Shrapnel_Buy_T15_Teddy") ;;
        Ghost)
            SKINS=("GhostSkin_Challenger" "GhostSkin_Default" "GhostSkin_Master" "GhostSkin_Rival" "Skin_Ghost_Buy_T15_Martian" "Skin_Ghost_Buy_T15_Scalloped" "Skin_Ghost_Buy_T1_PolyTech") ;;
        Phase)
            SKINS=("PhaseSkin_Challenger" "PhaseSkin_Default" "PhaseSkin_Master" "PhaseSkin_Rival" "Skin_Phase_Buy_T1_Kitty" "Skin_Phase_Buy_T1_Pandapack") ;;
        *) SKINS=() ;;
    esac
}

# --- input helpers -----------------------------------------------------------------
is_uint()  { [[ "$1" =~ ^[0-9]+$ ]]; }

ask_choice() {  # $1=prompt, rest=valid values -> REPLY_V
    local prompt="$1"; shift
    local v
    while true; do
        read -r -p "$prompt " v
        for x in "$@"; do [[ "$v" == "$x" ]] && { REPLY_V="$v"; return 0; }; done
        echo "  >> Invalid choice. Enter one of: $*"
    done
}

# --- 1) USERNAME (robust JSON read, same rules as the bat) ---------------------------
CURNAME="$(python3 - "$CONFIG" <<'PYEOF' 2>/dev/null || true
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        print(json.load(f).get("displayname", ""))
except Exception:
    pass
PYEOF
)"
[[ -n "$CURNAME" ]] || CURNAME=player1

echo "Current username in config.json: $CURNAME"
echo
ask_choice "Username  [1] keep current  [2] enter new  : " 1 2
if [[ "$REPLY_V" == "2" ]]; then
    while true; do
        read -r -p "Enter new username: " NAME
        if [[ "$NAME" =~ ^[A-Za-z0-9_-][A-Za-z0-9_-]*$ ]]; then break; fi
        echo "  >> Invalid. Only letters, digits, underscore and dash allowed."
    done
else
    NAME="$CURNAME"
fi
echo "  -> Username: $NAME"
echo

# --- 2) SERVER IP ---------------------------------------------------------------------
ask_choice "Server  [1] localhost (127.0.0.1:7777)  [2] external IP  : " 1 2
if [[ "$REPLY_V" == "1" ]]; then
    IP="127.0.0.1:7777"
else
    while true; do
        read -r -p "Enter external IPv4 (e.g. 26.123.45.67  or  ip:port): " EXTIP
        [[ -n "$EXTIP" ]] || { echo "  >> Cannot be empty."; continue; }
        if [[ "$EXTIP" == *:* ]]; then
            EH="${EXTIP%%:*}"; EP="${EXTIP##*:}"
            [[ "$EH" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "  >> Invalid IPv4 part. Use x.x.x.x:port"; continue; }
            is_uint "$EP" || { echo "  >> Invalid port. Digits only."; continue; }
            IP="$EH:$EP"
        else
            [[ "$EXTIP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "  >> Invalid IPv4. Use x.x.x.x  e.g. 26.123.45.67"; continue; }
            IP="$EXTIP:7777"
        fi
        break
    done
fi
echo "  -> IP: $IP"
echo

# --- 3) HERO ---------------------------------------------------------------------------
echo "Choose your hero:"
echo "------------------------------------------------------------"
n=0
for h in "${HEROES[@]}"; do
    n=$((n+1))
    printf "   %3d) %s\n" "$n" "${h%%|*}"
done
echo "------------------------------------------------------------"
while true; do
    read -r -p "Enter hero number (1-${#HEROES[@]}): " HSEL
    if is_uint "$HSEL" && (( HSEL >= 1 && HSEL <= ${#HEROES[@]} )); then
        PICK="${HEROES[$((HSEL-1))]}"
        break
    fi
    echo "  >> Invalid. Enter a number from 1 to ${#HEROES[@]}."
done
HCLEAR="${PICK%%|*}"
HCONSOLE="${PICK##*|}"
echo "  -> Hero: $HCLEAR  (config name: $HCONSOLE)"
echo

# --- 4) SKIN (0 = Default -> no skin key; else full skin object name) -------------------
load_skins "$HCONSOLE"
SKNCNT="${#SKINS[@]}"
echo "Skin for $HCLEAR:"
echo "------------------------------------------------------------"
echo "     0) Default (hero default skin)"
n=0
for s in "${SKINS[@]}"; do
    n=$((n+1))
    printf "   %3d) %s\n" "$n" "$s"
done
echo "------------------------------------------------------------"
while true; do
    read -r -p "Enter skin number (0-$SKNCNT): " SKSEL
    if ! is_uint "$SKSEL"; then echo "  >> Invalid. Digits only."; continue; fi
    if (( SKSEL == 0 )); then SKIN=""; SKLBL="Default"; break; fi
    if (( SKSEL < 1 || SKSEL > SKNCNT )); then echo "  >> Invalid. Enter a number from 0 to $SKNCNT."; continue; fi
    SKIN="${SKINS[$((SKSEL-1))]}"
    SKLBL="$SKIN"
    break
done
echo "  -> Skin: $SKLBL"
echo

# --- 5) ROLE (default = no role key = hero-based auto-detect) ----------------------------
ask_choice "Lane / Role:  [0] Default (auto-detect)  [1] Offlane  [2] Mid  [3] Carry  [4] Support  [5] Jungle  : " 0 1 2 3 4 5
case "$REPLY_V" in
    0) ROLE=""; RLBL="default (auto-detect)" ;;
    1) ROLE="0"; RLBL="Offlane" ;;
    2) ROLE="1"; RLBL="Mid" ;;
    3) ROLE="2"; RLBL="Carry" ;;
    4) ROLE="3"; RLBL="Support" ;;
    5) ROLE="4"; RLBL="Jungle" ;;
esac
echo "  -> Role: $RLBL"
echo

# --- 6) TEAM (server DLL mapping: team "2" -> Red, "1" -> Blue) ---------------------------
ask_choice "Team  [2] RED (team=2)  [1] BLUE (team=1)  : " 1 2
if [[ "$REPLY_V" == "2" ]]; then TEAM=2; TEAMLBL="RED"; else TEAM=1; TEAMLBL="BLUE"; fi
echo "  -> Team: $TEAMLBL (team=$TEAM)"
echo

# --- WRITE config.json --------------------------------------------------------------------
ROLEPART=""
[[ -n "$ROLE" ]] && ROLEPART=", \"role\": \"$ROLE\""
SKINPART=""
[[ -n "$SKIN" ]] && SKINPART=", \"skin\": \"$SKIN\""

cat > "$CONFIG" <<EOF
{"ip": "$IP", "displayname": "$NAME", "hero": "$HCONSOLE", "team": "$TEAM"$ROLEPART$SKINPART}
EOF

banner
echo " config.json written:"
cat "$CONFIG"
banner
echo

# --- LAUNCH -----------------------------------------------------------------------------------
# -noepicportal / -skippatchcheck are REQUIRED under Wine (the Epic handshake
# cannot complete); the Client DLL reads ip/hero/etc. from config.json in CWD.
echo "Launching client (Ctrl+C to stop)..."
# Clear previous run's join-diagnostic markers so this run starts fresh:
#   /tmp/client_marker_states.txt  UI state transitions
#   /tmp/client_marker_browse.txt  every engine Browse call (join travel)
#   /tmp/client_marker_connect.txt last "open" attempt + command
#   /tmp/client_marker_join.txt    periodic join status (PC/PlayerState)
rm -f /tmp/client_marker_states.txt /tmp/client_marker_browse.txt \
      /tmp/client_marker_connect.txt /tmp/client_marker_join.txt
WINEPREFIX="$WINE_PREFIX" WINEDLLOVERRIDES="mscoree,mshtml=" WINEDEBUG=-all \
    exec "$WINE_BIN" "$CLIENTEXE" -noepicportal -skippatchcheck

#!/usr/bin/env bash
# =============================================================================
#  Project Monolith - SERVER Launcher  (Linux/Wine port of server_launcher.bat)
#  - Builds/edits server.json (read by Server DLL on F1 and F4 press)
#  - Launches: wine OrionClient-Win64-Shipping-Server.exe ...
#
#  PLACEMENT: put this script next to OrionClient-Win64-Shipping-Server.exe
#             (OrionGame/Binaries/Win64/)
#
#  Environment overrides:
#    WINE_BIN      wine executable              (default: wine)
#    WINE_PREFIX   Wine prefix for the server   (default: ~/.wine-paragon-server)
#    SERVER_MAP    UE map path passed as first arg (default: empty = the Server
#                  DLL loads its own map; e.g. /Game/Maps/Monolith/Monolith)
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

SERVEREXE="OrionClient-Win64-Shipping-Server.exe"
SCONFIG="$PWD/server.json"
WINE_BIN="${WINE_BIN:-wine}"
WINE_PREFIX="${WINE_PREFIX:-$HOME/.wine-paragon-server}"
SERVER_MAP="${SERVER_MAP:-}"

banner() { printf '\n%s\n' "============================================================"; }
die()    { echo "ERROR: $*" >&2; exit 1; }

# --- preflight -----------------------------------------------------------------
command -v "$WINE_BIN" >/dev/null 2>&1 || die "wine not found ('$WINE_BIN'). Install it first (e.g. sudo dnf install wine)"
[ -f "$SERVEREXE" ] || die "$SERVEREXE not found in $PWD - place this script next to the server executable"
if ! ls /usr/share/wine/winmd/*.winmd >/dev/null 2>&1; then
    die "wine-common missing (/usr/share/wine/winmd empty) -> wineboot livelocks. Fix: sudo dnf install wine-common"
fi
[ -f /usr/lib64/wine-wow64/wine/x86_64-windows/wldap32.dll ] || \
    die "wine-ldap missing (wldap32.dll) -> game dies instantly with exit 53. Fix: sudo dnf install wine-ldap"

banner
echo           "            PROJECT MONOLITH  -  SERVER LAUNCHER (Linux/Wine)"
banner
echo
echo "  Prefix: $WINE_PREFIX"
[ -n "$SERVER_MAP" ] && echo "  Map:    $SERVER_MAP"
echo

# Initialize the Wine prefix on first use.
if [ ! -f "$WINE_PREFIX/system.reg" ]; then
    echo "Initializing Wine prefix (first run, may take a minute)..."
    WINEPREFIX="$WINE_PREFIX" WINEDLLOVERRIDES="mscoree,mshtml=" \
        "$WINE_BIN" wineboot -u >/dev/null 2>&1 || true
fi

# Ensure Wine loads OUR app-dir xinput1_3.dll (the loader shim for Server.dll).
# Without a native-only override, Wine silently falls back to its builtin
# xinput stub and Server.dll never gets loaded.
WINEPREFIX="$WINE_PREFIX" WINEDLLOVERRIDES="mscoree,mshtml=" \
    "$WINE_BIN" reg add "HKCU\\Software\\Wine\\DllOverrides" /v xinput1_3 /t REG_SZ /d n /f >/dev/null 2>&1 || true

# --- input helpers ---------------------------------------------------------------
is_uint()  { [[ "$1" =~ ^[0-9]+$ ]]; }
is_dec()   { [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$ ]]; }
is_regen() { [[ "$1" =~ ^0\.(0[1-9]|[1-5][0-9]?)$ ]]; }   # 0.01 .. 0.59 only

ask_choice() {  # $1=prompt, rest=valid values -> REPLY_V
    local prompt="$1"; shift
    local v
    while true; do
        read -r -p "$prompt " v
        for x in "$@"; do [[ "$v" == "$x" ]] && { REPLY_V="$v"; return 0; }; done
        echo "  >> Invalid choice. Enter one of: $*"
    done
}

ask_dec() {  # $1=prompt $2=default (empty input -> default) -> REPLY_V
    local prompt="$1" def="$2" v
    while true; do
        read -r -p "$prompt " v
        if [[ -z "$v" ]]; then REPLY_V="$def"; return 0; fi
        if is_dec "$v"; then REPLY_V="$v"; return 0; fi
        echo "  >> Invalid number. Use digits and one dot, e.g. 1.5 (empty = $def)"
    done
}

# --- 1) BUFF PATCH MASTER SWITCH ---------------------------------------------------
ask_choice "Bot Buff Patch  [1] ENABLE  [2] DISABLE  : " 1 2
if [[ "$REPLY_V" == "1" ]]; then
    ENABLEBUFF=true
    ask_dec "Enemy buff multiplier   (Enter=default 2.5): " 2.5;      ENEMYMULT="$REPLY_V"
    ask_dec "Friendly buff multiplier (Enter=default 2.0): " 2.0;     FRIENDLYMULT="$REPLY_V"
    echo "  -> Buff patch ENABLED  enemy=$ENEMYMULT  friendly=$FRIENDLYMULT"
else
    ENABLEBUFF=false
    ENEMYMULT=2.5
    FRIENDLYMULT=2.0
    echo "  -> Buff patch DISABLED"
fi
echo

# --- 2) PER-TEAM DIFFICULTY ----------------------------------------------------------
# NOTE: upstream server_launcher.bat had the labels swapped (the prompt labelled
# "RED" was written to blue_team_difficulty and vice versa). This port maps them
# correctly.
DIF=(introductory easy intermediate experienced veteran custom)
read -r -p "Blue team difficulty (1-6, Enter=5 veteran): " v
while [[ -n "$v" ]] && { ! is_uint "$v" || (( v < 1 || v > 6 )); }; do
    echo "  >> Invalid. Enter a number from 1 to 6 (empty = 5)."
    read -r -p "Blue team difficulty (1-6, Enter=5 veteran): " v
done
[[ -z "$v" ]] && v=5
BLUEDIFF="${DIF[$((v-1))]}"
read -r -p "Red  team difficulty (1-6, Enter=5 veteran): " v
while [[ -n "$v" ]] && { ! is_uint "$v" || (( v < 1 || v > 6 )); }; do
    echo "  >> Invalid. Enter a number from 1 to 6 (empty = 5)."
    read -r -p "Red  team difficulty (1-6, Enter=5 veteran): " v
done
[[ -z "$v" ]] && v=5
REDDIFF="${DIF[$((v-1))]}"
echo "  -> Blue: $BLUEDIFF   Red: $REDDIFF"
echo

# --- 3) BOSS STAT MODIFICATION ---------------------------------------------------------
ENABLEBOSS=false
BMAXHP=1.0
BATTACK=1.0
BREGEN=0.5
ask_choice "Modify boss stats?  [1] No (boss completely vanilla)  [2] Yes (custom)  : " 1 2
if [[ "$REPLY_V" == "2" ]]; then
    ENABLEBOSS=true
    ask_dec "Boss MaxHP multiplier   (e.g. 0.5 = half HP, Enter=default 0.5): " 0.5;  BMAXHP="$REPLY_V"
    ask_dec "Boss Attack multiplier  (e.g. 0.55, Enter=default 0.55): " 0.55;         BATTACK="$REPLY_V"
    while true; do
        read -r -p "Boss HealthRegen mult   (0.01-0.59, e.g. 0.5 = half regen, Enter=default 0.5): " v
        if [[ -z "$v" ]]; then BREGEN=0.5; break; fi
        if is_regen "$v"; then BREGEN="$v"; break; fi
        echo "  >> Out of range. Must be 0.01-0.59 (kept below engine threshold)."
    done
    echo "  -> Boss-Mod ENABLED  maxhp=$BMAXHP  attack=$BATTACK  regen=$BREGEN"
else
    echo "  -> Boss-Mod DISABLED (boss stays vanilla)"
fi
echo

# --- 4) BOT MOVE-SPEED BUFF ---------------------------------------------------------------
ask_choice "Bot move-speed boost (fixed ~1.49x)?  [1] ENABLE  [2] DISABLE  : " 1 2
if [[ "$REPLY_V" == "1" ]]; then
    ENABLESPEED=true
    echo "  -> Bot speed boost ENABLED (~1.49x)"
else
    ENABLESPEED=false
    echo "  -> Bot speed boost DISABLED (native)"
fi
echo

# --- WRITE server.json (periodic log interval fixed at 60.0) ------------------------------
cat > "$SCONFIG" <<EOF
{
    "enable_buff_patch":              $ENABLEBUFF,
    "enemy_buff_multiplier":          $ENEMYMULT,
    "friendly_buff_multiplier":       $FRIENDLYMULT,
    "enable_bot_speed_buff":          $ENABLESPEED,
    "blue_team_difficulty":           "$BLUEDIFF",
    "red_team_difficulty":            "$REDDIFF",
    "enable_boss_mod":                $ENABLEBOSS,
    "boss_regen_mult":                $BREGEN,
    "boss_maxhp_mult":                $BMAXHP,
    "boss_attack_mult":               $BATTACK,
    "boss_stat_epsilon":              0.5,
    "boss_periodic_log_interval_sec": 60.0
}
EOF

banner
echo " server.json written:"
cat "$SCONFIG"
banner
echo

# --- LAUNCH ---------------------------------------------------------------------------------
ARGS=()
[ -n "$SERVER_MAP" ] && ARGS+=("$SERVER_MAP")
# -noepicportal / -skippatchcheck are REQUIRED under Wine (the Epic handshake
# cannot complete); -log so the [HOST] messages land in the console.
ARGS+=(-port=7777 -log -nosound -noepicportal -skippatchcheck)

echo "Launching server (Ctrl+C to stop)..."
# NOTE on the loader under Wine:
#   The game's d3d11/dxgi path is taken over by DXVK (dxvk-d3d11 + dxvk-dxgi),
#   so a local DXGI.dll in this folder is NEVER loaded - no rename or
#   WINEDLLOVERRIDES can change that. Instead the loader is xinput1_3.dll in
#   this folder: the game imports XINPUT1_3, wine prefers the app-dir native
#   DLL over its builtin stub, and that shim LoadLibraryA's Server.dll (this
#   exe) or Client.dll (the plain client exe) once the engine is ready.
#   mscoree,mshtml= disables the mono/gecko install prompts.
# PM_EXTRA_REPL=1: the Server DLL's extra replication pass is REQUIRED under
# Wine. Native engine replication opens PlayerController channels but NEVER
# PlayerState channels here, so without this pass a real client connects but
# can never receive its PlayerState (stuck on "Connecting", no pawn spawn).
# The pass reuses live native channels (no duplicate channel creation), which
# fixed the earlier ActorChannelFailure/invalid-swap corruption. Set
# PM_NO_EXTRA_REPL=1 in the environment to force it OFF for diagnostics.
WINEPREFIX="$WINE_PREFIX" WINEDLLOVERRIDES="mscoree,mshtml=" WINEDEBUG=-all PM_EXTRA_REPL=1 \
    exec "$WINE_BIN" "$SERVEREXE" "${ARGS[@]}"

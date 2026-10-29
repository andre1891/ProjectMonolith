# Project Monolith

Community listen-server for the discontinued MOBA client v45 (UE 4.19 based) with a
reconstructed bot "macro brain" (lane assignment, objectives, boss and recall decisions).
One player hosts a match on their own machine, others join peer-to-peer. No central server, no
accounts, no connection to any Epic Games service.

> **Not affiliated with Epic Games.** Project Monolith is an independent, non-commercial
> community project and is not endorsed, sponsored or approved by Epic Games, Inc. "Paragon" is
> a trademark of Epic Games, Inc. and is mentioned only to describe compatibility.
> See `NOTICE.md`.

## Non-commercial project

Project Monolith is a non-commercial community project. **I do not accept donations, sponsorships
or payments of any kind**, there are no ads, no paid features and nothing to buy. The project
exists to keep a discontinued game playable for the people who own it, and as a learning and
research project: the reconstructed bot AI and its documentation (`ai_documentation_EN.txt`)
show how the macro decisions of the original bots can be rebuilt, and the code shows reverse
engineering for interoperability.

If anyone asks you for money in connection with this project, it is not from us.

## Credits

Project Monolith would not exist without **[ProjectLegacy](https://github.com/SyST3MDeV/ProjectLegacy)
by SyST3MDeV**, the original listen-server for the v45 client. Hooking framework, listen-server
setup, replication, login handling and most engine addresses come from ProjectLegacy (base
commit `52a3e06`, AGPL-3.0). Project Monolith builds on it with the bot AI, match flow, boss
tuning, deck filter, crash fixes, the new loader and the build tooling. Details per folder:
`NOTICE.md` and the `ORIGIN.md` files.

Also thanks to:
- [Dumper-7](https://github.com/Encryqed/Dumper-7) by Encryqed, which generated the SDK headers
- [UnrealContainers](https://github.com/Fischsalat/UnrealContainers) by Fischsalat
- [MinHook](https://github.com/TsudaKageyu/minhook) by Tsuda Kageyu
- [JsonCpp](https://github.com/open-source-parsers/jsoncpp) by Baptiste Lepilleur and the JsonCpp authors

## What this repository contains, and what it does not

- **Contains:** source code (server DLL, client DLL, loader DLL), launch scripts, docs.
- **Does not contain:** game files, game assets, game binaries, compiled DLLs, or the generated
  SDK headers. You need **your own, legitimately obtained copy of the game client (v45)**.
  This project does not tell you where to get one and does not link to any download.
- **No prebuilt DLLs are distributed.** Build them yourself (below).

## Build

Requirements: Windows and either **Visual Studio 2022** or the free **Build Tools for Visual
Studio 2022** (https://visualstudio.microsoft.com/downloads/), each with the workload
"Desktop development with C++" (toolset v143).

**Get the code:** click **Code → Download ZIP** on this page and extract the ZIP into a folder
(or `git clone` the repository). Don't run the scripts from inside the ZIP.

**One click:** in the extracted folder, run **`build.bat`**. It

1. downloads the generated SDK headers if they are missing (`fetch_sdk.bat`: from the base
   project ProjectLegacy at a fixed commit, see `NOTICE.md`, verified by checksum; needs internet
   once, about half a minute),
2. finds your Visual Studio / Build Tools installation and builds `ProjectMonolith.sln`
   (configuration `v45`, platform `x64`),
3. checks that `Server.dll`, `Client.dll` and `DXGI.dll` (loader) were created in `x64\v45\`.

**In Visual Studio instead:** run `fetch_sdk.bat` once, open `ProjectMonolith.sln`, select
`v45` / `x64` and build the solution.

## Install and play

Step-by-step guide for installing, hosting and joining: **[HOW_TO_PLAY.md](HOW_TO_PLAY.md)**.

In short: copy `Server.dll`, `Client.dll`, `DXGI.dll` and the three `.bat` launchers into the
game's `OrionGame\Binaries\Win64\` folder, and create a copy of the game executable named
`OrionClient-Win64-Shipping-Server.exe` for hosting. Windows loads `DXGI.dll` together with the
game; it forwards the DirectX factory calls to the system `dxgi.dll` and then loads
`Server.dll` or `Client.dll` into the game process. It does not touch any other process and does
not modify files on disk. The server listens on UDP port 7777.

Playing alone against bots also works this way: you host the server and join it yourself
on the same PC (see "Playing solo against bots" in HOW_TO_PLAY.md).

**Linux / Wine:** everything above also runs under Wine — see [Running on Linux (Wine)](#running-on-linux-wine).
On Linux the loader is `xinput1_3.dll` instead of `DXGI.dll`, and the launchers are
`server_launcher.sh` / `client_launcher.sh`.

## Running on Linux (Wine)

The whole project runs under **Wine**. Hosting a match and joining it from the same PC has been
verified end-to-end (Fedora 44, Wine 11 staging + DXVK, AMD GPU/Vulkan). You still need your own,
legitimately obtained copy of the v45 client.

**Prerequisites** (Fedora example; other distros similar):

```bash
sudo dnf install wine dxvk   # full metapackage - do NOT install bare wine-core
```

Two failure modes if you skip the metapackage:
- missing `wine-common` → `wineboot --init` livelocks at 99% CPU and every wine launch hangs;
- missing `wine-ldap` → the game exits instantly with code 53 and an empty log.

**Building:** cross-compile with **mingw-w64** (`x86_64-w64-mingw32-g++`, C++20). GCC has no
native SEH, so the sources need a mechanical `__try/__except` transform plus small portability
shims; that cross-build pipeline is build machinery and is kept outside this repository on
purpose. Alternatively build the DLLs on Windows and copy them over — they are plain PE DLLs.

**Loader difference:** under Wine the game's DXGI/D3D11 path is taken over by DXVK, so a local
`DXGI.dll` is **never loaded** there (no rename or `WINEDLLOVERRIDES` changes that). On Linux the
loader is therefore `xinput1_3.dll` in the game folder: the game imports XINPUT1_3, Wine prefers
the app-dir native DLL over its builtin stub, and the shim loads `Server.dll` (server exe) or
`Client.dll` (client exe) once the engine is ready. On Windows, `DXGI.dll` stays the loader as
before; both files can sit in the same folder.

**Launching:** use `server_launcher.sh` / `client_launcher.sh` (Linux ports of the `.bat`
launchers, same prompts). They add `-noepicportal -skippatchcheck`, which are **required under
Wine** (the Epic handshake cannot complete without them), and the server launcher sets
`PM_NO_EXTRA_REPL=1`: with real client connections under Wine the extra shadow-bot replication
pass must stay off — native engine replication carries the session. Windows builds and launchers
are unaffected by that variable.

## How the bot AI works

`ai_documentation_EN.txt` describes the reconstructed bot macro brain in `Server/dllmain.cpp`:
each subsystem, why it exists, its switches and how it was tested. Start there if you want to
understand or change the bot logic.

## Security notes for hosts

- **The server accepts every connection** (there is no login or authentication). Anyone who
  knows your IP and port can join. Share them only with people you want to play with (Or use tools like radminvpn).
- The DLLs write log files (`debugger.txt`, `seh_crash.txt`, `client_*.txt`) next to the game.

## Open source: use it, improve it, keep it open

Project Monolith is open source, and other developers are welcome to use, study, change and
build on this code, in their own projects too. The one rule comes from the license (AGPL-3.0):
**whatever you build on this code must stay open source under the same license.** In practice:

- If you share a modified version (source or compiled DLLs), you must publish your source code
  under AGPL-3.0 as well and keep the existing copyright and license notices.
- If you run a modified server that other people play on, you must offer those players your
  source code (AGPL §13), for example with a link to your repository.
- Mark what you changed, and keep `NOTICE.md` and `LICENSE.txt`.

Contributions (issues, pull requests) are welcome. By contributing you agree that your
contribution is licensed under AGPL-3.0 like the rest of the project.

## License

GNU Affero General Public License v3 (`LICENSE.txt`), inherited from the base project.
Third-party licenses: `THIRD_PARTY_LICENSES.md`. Origin of each part: `NOTICE.md` and the
`ORIGIN.md` file in each folder.


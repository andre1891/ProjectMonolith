
#include "SDKv45.hpp"
#include "SDKv45/GameplayAbilities_parameters.hpp"

#include <thread>
#include <iostream>
#include <format>
#include <fstream>
#include <unordered_map>

#include "MinHook/include/MinHook.h"
#include "json/json.h"

#pragma comment(lib, "MinHook/lib/libMinHook-x64-v141-mt.lib")


using namespace SDK;

namespace SDKUtils {
    template <typename T>
    std::vector<T*> GetAllObjectsOfType() {
        return UObject::FindObjects<T>();
    }

    template <typename T>
    T* GetLastOfType() {
        auto objs = UObject::FindObjects<T>();
        return objs.empty() ? nullptr : objs.back();
    }

    template <typename T>
    void ListAllObjectsOfType() {
        for (T* obj : GetAllObjectsOfType<T>()) {
            UObject* castObj = reinterpret_cast<UObject*>(obj);

            std::cout << castObj->GetFullName() << std::endl;
        }
    }
}

namespace PLOffsets {

    static const uintptr_t MALLOC = 0xBD2AE0;

    static const uintptr_t SET_UI_STATE = 0x9D2030;
    static const uintptr_t ROUTE_GAMEPLAY_CUE = 0x6BF710;

    static const uintptr_t PROCESSEVENT = 0xEA1BD0;
    static const uintptr_t INIT_MCP_PROFILE = 0x8D35C0;
    static const uintptr_t RETURN_TO_MENU = 0x8C4130;
    static const uintptr_t BROWSE = 0x2328790;
    static const uintptr_t UI_STATE_HOOK = 0x9d2030;
}

namespace Globals {
    __int64 UIManager = 0;

    uintptr_t ModuleBase = 0;

    UWorld* GetGWorld() {

        return UWorld::GetWorld();
    }

    UGameplayStatics* GetGameplayStatics() {
        static UGameplayStatics* gameplayStatics = nullptr;

        if (!gameplayStatics) {
            gameplayStatics = UObject::FindObject<UGameplayStatics>();
        }

        return gameplayStatics;
    }

    UKismetStringLibrary* GetKismetStringLibrary() {
        static UKismetStringLibrary* kismetStringLibrary = nullptr;

        if (!kismetStringLibrary) {
            kismetStringLibrary = UObject::FindObject<UKismetStringLibrary>();
        }

        return kismetStringLibrary;
    }

    UEngine* GetEngine() {
        static UEngine* engine = nullptr;

        if (!engine) {
            engine = SDKUtils::GetLastOfType<UEngine>();
        }

        return engine;
    }

    template <typename T>
    T* GetLocalPlayerController() {
        return reinterpret_cast<T*>(GetGWorld()->OwningGameInstance->LocalPlayers[0]->PlayerController);
    }

    template <typename T>
    T* GetLocalPlayerState() {
        return reinterpret_cast<T*>(GetGWorld()->OwningGameInstance->LocalPlayers[0]->PlayerController->PlayerState);
    }

    template <typename T>
    T* GetGameMode() {
        return reinterpret_cast<T*>(GetGWorld()->AuthorityGameMode);
    }

    template <typename T>
    T* GetGameState() {
        return reinterpret_cast<T*>(GetGWorld()->AuthorityGameMode->GameState);
    }
}

namespace EngineLogic {
    void EnableGameConsole() {
        UKismetStringLibrary* stringLibrary = UObject::FindObjects<UKismetStringLibrary>().back();
        UEngine* engine = UObject::FindObjects<UEngine>().back();
        UInputSettings* inputSettings = UObject::FindObjects<UInputSettings>().back();
        UGameplayStatics* gameplayStatics = UObject::FindObjects<UGameplayStatics>().back();


        inputSettings->ConsoleKeys[0].KeyName = stringLibrary->Conv_StringToName(L"F2");

        UObject* NewObject = gameplayStatics->SpawnObject(engine->ConsoleClass, engine->GameViewport);

        engine->GameViewport->ViewportConsole = reinterpret_cast<UConsole*>(NewObject);
    }

    void ExecuteConsoleCommand(const wchar_t* cmd) {
        static UKismetSystemLibrary* systemLibrary = nullptr;

        if (!systemLibrary) {
            systemLibrary = UObject::FindObject<UKismetSystemLibrary>();
        }


        systemLibrary->ExecuteConsoleCommand(Globals::GetGWorld(), cmd, Globals::GetLocalPlayerController<APlayerController>());
    }

    void ConnectToMatch(const wchar_t* ip) {
        static UGameplayStatics* systemLibrary = nullptr;

        if (!systemLibrary) {
            systemLibrary = UObject::FindObject<UGameplayStatics>();
        }

        static UKismetStringLibrary* kismetStringLibrary = nullptr;

        if (!kismetStringLibrary) {
            kismetStringLibrary = UObject::FindObject<UKismetStringLibrary>();
        }


        systemLibrary->OpenLevel(Globals::GetGWorld(), kismetStringLibrary->Conv_StringToName(ip), true, FString());
    }

    void* Malloc(__int64 size, unsigned int alignment) {
        return reinterpret_cast<void* (__thiscall*)(__int64 size, unsigned int alignment)>(Globals::ModuleBase + PLOffsets::MALLOC)(size, alignment);
    }
}

namespace GameLogic {
    void SetUIState(EOrionUIState state) {

        std::cout << Globals::UIManager << std::endl;
        reinterpret_cast<void(__thiscall*)(__int64, EOrionUIState)>(Globals::ModuleBase + PLOffsets::UI_STATE_HOOK)(Globals::UIManager, state);

    }

    void HideLoadingScreen() {

        for (UOrionUIManagerWidget* uiManager: SDKUtils::GetAllObjectsOfType< UOrionUIManagerWidget>()) {
            uiManager->HideLoadingScreen(Globals::GetGWorld());
        }
;
    }
}

namespace Hooking {
    bool procingCurrentFuncPtrs = false;

    std::vector<void*> FuncPtrsToProcInGameThread = std::vector<void*>();

    void ProcInGameThread(void* ptr) {
        FuncPtrsToProcInGameThread.push_back(ptr);
    }

    static void SafeCallProcTask(void* fp) {
        __try {
            reinterpret_cast<void(*)()>(fp)();
        }
        __except (EXCEPTION_EXECUTE_HANDLER) {
        }
    }

    bool g_clientSsrtLog = false;
    static void ClientSsrtLog(const std::string& line) {
        std::cout << line << std::endl;
        char p[MAX_PATH] = { 0 };
        HMODULE hSelf = nullptr;
        GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                           reinterpret_cast<LPCSTR>(&ClientSsrtLog), &hSelf);
        DWORD n = hSelf ? GetModuleFileNameA(hSelf, p, MAX_PATH) : 0;
        if (n > 0 && n < MAX_PATH) {
            char* slash = strrchr(p, '\\');
            if (slash) strcpy_s(slash + 1, MAX_PATH - static_cast<size_t>(slash + 1 - p), "client_ssrt.txt");
            else       strcpy_s(p, MAX_PATH, "client_ssrt.txt");
        } else {
            strcpy_s(p, MAX_PATH, "client_ssrt.txt");
        }
        static bool s_firstSsrtWrite = true;
        std::ofstream f(p, std::ios::out | (s_firstSsrtWrite ? std::ios::trunc : std::ios::app));
        s_firstSsrtWrite = false;
        if (f.is_open()) f << line << "\n";
    }

    static bool ClientIsLive(void* p) {
        if (!p || IsBadReadPtr(p, sizeof(UObject))) return false;
        UObject* o = reinterpret_cast<UObject*>(p);
        return UObject::GObjects->GetByIndex(o->Index) == o;
    }

    static bool ClientIsCallable(UObject* o) {
        if (!ClientIsLive(o)) return false;
        if (static_cast<int32>(o->Flags) & (0x10 | 0x8000 | 0x10000)) return false;
        FUObjectItem* items = UObject::GObjects->GetDecrytedObjPtr();
        if (!items || o->Index < 0 || o->Index >= UObject::GObjects->Num()) return false;
        const uint8_t* item = reinterpret_cast<const uint8_t*>(&items[o->Index]);
        if (IsBadReadPtr(item, 0x18)) return false;
        const int32 itemFlags = *reinterpret_cast<const int32*>(item + 0x8);
        return (itemFlags & ((1 << 28) | (1 << 29))) == 0;
    }

    static const bool ENABLE_REVULT_SHADE_FIX = true;
    static void ClientRevUltShadeFix() {
        static UObject* s_fxPc = nullptr;
        static ULONGLONG s_fxPcMs = 0;
        static std::vector<UObject*> s_fxChars;
        static ULONGLONG s_fxCharsMs = 0;
        const ULONGLONG nowMs = GetTickCount64();
        APawn* me = ClientIsLive(s_fxPc) ? reinterpret_cast<APlayerController*>(s_fxPc)->Pawn : nullptr;
        if (!ClientIsLive(me) && nowMs - s_fxPcMs >= 2000) {
            s_fxPcMs = nowMs;
            s_fxPc = nullptr;
            for (AOrionPlayerController_Game* pc : SDKUtils::GetAllObjectsOfType<AOrionPlayerController_Game>()) {
                UObject* po = reinterpret_cast<UObject*>(pc);
                if (ClientIsLive(po) && !(static_cast<int32>(po->Flags) & 0x10)) s_fxPc = po;
            }
            me = ClientIsLive(s_fxPc) ? reinterpret_cast<APlayerController*>(s_fxPc)->Pawn : nullptr;
        }
        if (!ClientIsLive(me) || !me->IsA(AOrionChar::StaticClass())
            || !(*reinterpret_cast<const uint8_t*>(reinterpret_cast<uintptr_t>(me) + 0x7D5) & 0x8)) {
            s_fxChars.clear();
            return;
        }
        if (s_fxChars.empty() || nowMs - s_fxCharsMs >= 1000) {
            s_fxChars.clear();
            for (AOrionChar* c : SDKUtils::GetAllObjectsOfType<AOrionChar>())
                if (ClientIsLive(c) && c->GetFullName().find("Default__") == std::string::npos)
                    s_fxChars.push_back(reinterpret_cast<UObject*>(c));
            s_fxCharsMs = nowMs;
        }
        for (UObject* o : s_fxChars) {
            if (!ClientIsCallable(o)) continue;
            const uint8_t inZone = *reinterpret_cast<const uint8_t*>(reinterpret_cast<uintptr_t>(o) + 0x7D5);
            if (!(inZone & 0x8)) continue;
            AOrionChar* c = reinterpret_cast<AOrionChar*>(o);
            if (!c->GetLocalStatus(EOrionCharLocalStatusTypes::IsShade)) continue;
            c->ChangeLocalStatus(EOrionCharLocalStatusTypes::IsShade, false);
        }
    }

    void* origProcessEvent = nullptr;

    void* ProcessEventHook(UObject* object, UFunction* function, void* params) {

        if (!procingCurrentFuncPtrs && FuncPtrsToProcInGameThread.size() > 0) {
            procingCurrentFuncPtrs = true;
            while (FuncPtrsToProcInGameThread.size() > 0) {
                void* funcPtr = FuncPtrsToProcInGameThread.back();
                SafeCallProcTask(funcPtr);
                FuncPtrsToProcInGameThread.pop_back();
            }
            procingCurrentFuncPtrs = false;
        }

        static std::unordered_map<UFunction*, std::string> s_funcNameCache;
        auto funcNameIt = s_funcNameCache.find(function);
        if (funcNameIt == s_funcNameCache.end())
            funcNameIt = s_funcNameCache.emplace(function, function->GetFullName()).first;
        const std::string& funcName = funcNameIt->second;

        if (ENABLE_REVULT_SHADE_FIX) {
            static ULONGLONG s_fxLastMs = 0;
            const ULONGLONG fxNowMs = GetTickCount64();
            if (fxNowMs - s_fxLastMs >= 100) {
                s_fxLastMs = fxNowMs;
                ClientRevUltShadeFix();
            }
        }

  
        if (funcName.find("OnCardShopOpened") != std::string::npos) {
            std::cout << "[DEBUG] OnCardShopOpened abgefangen!" << std::endl;
            if (params != nullptr) {
                *(bool*)params = true;
                std::cout << "[DEBUG] bHasDeck auf TRUE gezwungen. Ueberspringe Deck-Auswahl!" << std::endl;
            }
        }


        if (funcName.find("DeckSelectionScreen") != std::string::npos &&
            (funcName.find("Construct") != std::string::npos || funcName.find("Show") != std::string::npos)) {
            std::cout << "[DEBUG] Blockiere DeckSelectionScreen, um Crash zu verhindern!" << std::endl;
            return nullptr;
        }

        static UFunction* gameplayCueFunc = nullptr;
        if (!gameplayCueFunc)
            gameplayCueFunc = UObject::FindObject<UFunction>(
                "Function GameplayAbilities.AbilitySystemComponent.NetMulticast_InvokeGameplayCueExecuted_WithParams");

        if (function == gameplayCueFunc) {
            Params::AbilitySystemComponent_NetMulticast_InvokeGameplayCueExecuted_WithParams* castParams =
                reinterpret_cast<Params::AbilitySystemComponent_NetMulticast_InvokeGameplayCueExecuted_WithParams*>(params);

            if (castParams->PredictionKey.Current == INT16_MAX || castParams->PredictionKey.Base == INT16_MAX) {
                static UGameplayCueManager* gcManager = nullptr;
                if (!gcManager)
                    gcManager = SDKUtils::GetLastOfType<UGameplayCueManager>();

                AActor* targetActor = ((UOrionAbilitySystemComponent*)object)->AvatarActor;
                FGameplayTag tag = FGameplayTag();

                tag.TagName = Globals::GetKismetStringLibrary()->Conv_StringToName(L"GameplayCue_Damage");

                castParams->GameplayCueParameters.OriginalTag = tag;
                castParams->GameplayCueParameters.MatchedTagName = tag;

                if (targetActor && gcManager) {
                    reinterpret_cast<void(*)(UGameplayCueManager*, AActor*, FGameplayTag, EGameplayCueEvent, FGameplayCueParameters*)>(
                        Globals::ModuleBase + PLOffsets::ROUTE_GAMEPLAY_CUE)(
                            gcManager, targetActor, tag, EGameplayCueEvent::Executed, &castParams->GameplayCueParameters);
                }
            }
            else if (castParams->PredictionKey.Current == INT16_MAX - 1 || castParams->PredictionKey.Base == INT16_MAX - 1) {
                static UGameplayCueManager* gcManager = nullptr;
                if (!gcManager)
                    gcManager = SDKUtils::GetLastOfType<UGameplayCueManager>();

                AActor* targetActor = ((UOrionAbilitySystemComponent*)object)->AvatarActor;
                FGameplayTag tag = FGameplayTag();

                tag.TagName = Globals::GetKismetStringLibrary()->Conv_StringToName(L"GameplayCue_Damage");

                castParams->GameplayCueParameters.OriginalTag = tag;
                castParams->GameplayCueParameters.MatchedTagName = tag;

                if (targetActor && gcManager) {
                    reinterpret_cast<void(*)(UGameplayCueManager*, AActor*, FGameplayTag, EGameplayCueEvent, FGameplayCueParameters*)>(
                        Globals::ModuleBase + PLOffsets::ROUTE_GAMEPLAY_CUE)(
                            gcManager, targetActor, tag, EGameplayCueEvent::Executed, &castParams->GameplayCueParameters);
                }
            }
        }

        if (funcName.find("ReturnToMainMenu") != std::string::npos) {
            for (int i = 0; i < 20; i++) {
                std::cout << "STUBBED RETURN TO MAIN MENU" << std::endl;
            }
            return nullptr;
        }

        if (g_clientSsrtLog && params && !IsBadReadPtr(params, 0x40)
            && funcName.find("ServerSetReplicatedTargetData") != std::string::npos
            && funcName.find("Cancelled") == std::string::npos) {
            int32_t h     = *reinterpret_cast<int32_t*>(params);
            int16_t pkCur = *reinterpret_cast<int16_t*>(reinterpret_cast<uint8_t*>(params) + 0x08);
            int16_t pkBase= *reinterpret_cast<int16_t*>(reinterpret_cast<uint8_t*>(params) + 0x0A);
            int32_t tgt   = *reinterpret_cast<int32_t*>(reinterpret_cast<uint8_t*>(params) + 0x38);
            std::ostringstream ss;
            ss << "[F5-CLIENT-SSRT] SEND handle=" << h << " predkey(Cur/Base)=" << pkCur << "/" << pkBase
               << " tgtCount=" << tgt << " obj=" << object->GetName();
            ClientSsrtLog(ss.str());
        }

        if (g_clientSsrtLog
            && (funcName.find("ServerSetReplicatedEvent") != std::string::npos
                || (funcName.find("Server") != std::string::npos
                    && (funcName.find("Confirm") != std::string::npos || funcName.find("GenericRep") != std::string::npos)))) {
            std::ostringstream ss;
            ss << "[F5-CLIENT-EVENT] SEND " << funcName << " obj=" << object->GetName();
            if (params && !IsBadReadPtr(params, 0x18)) {
                ss << " raw=";
                for (int i = 0; i < 0x18; i += 4)
                    ss << std::hex << *reinterpret_cast<uint32_t*>(reinterpret_cast<uint8_t*>(params) + i) << "/" << std::dec;
            }
            ClientSsrtLog(ss.str());
        }

        return reinterpret_cast<void* (__thiscall*)(UObject*, UFunction*, void*)>(
            origProcessEvent)(object, function, params);
    }
    void* origInitializeMCPProfile = nullptr;

    bool initUI = false;

    bool InitializeMCPProfileHook(APlayerControllerCommon* playercontroller) {
        if (!initUI) {
            initUI = true;
        }
        return true;
    }

    void* origReturnToMainMenu = nullptr;

    void ReturnToMainMenuHook() {
        return;
    }
    

    void* origBrowse = nullptr;
    __int64 UEngineBrowseHook(void* UEngine, void* WorldContext, FURL& URL, FString& Error) {
        for (FString op: URL.Op) {
            if (op.ToString().find("closed") != std::string::npos) {
                return 0;
            }
        }

        return reinterpret_cast<__int64(*)(void*, void*, FURL&, FString&)>(origBrowse)(UEngine, WorldContext, URL, Error);
    }

    void* origSetUIState = 0;

    bool SetUIStateHook(__int64 manager, EOrionUIState state) {
        Globals::UIManager = manager;

        static int s_lastUiStateLogged = -1;
        if (static_cast<int>(state) != s_lastUiStateLogged) {
            std::cout << "CHANGING UI STATE" << std::endl;
            std::cout << (int)state << std::endl;
            std::cout << "CHANGED UI STATE" << std::endl;
            s_lastUiStateLogged = static_cast<int>(state);
        }
        if (state == EOrionUIState::Invalid) {
            static int numTimesChanged = 0;

            if (numTimesChanged == 0) {
                state = EOrionUIState::InitialPreload;
            }
            else {
                return true;
            }

            numTimesChanged++;
        }

        return reinterpret_cast<bool(*)(__int64, EOrionUIState)>(origSetUIState)(manager, state);
    }


    void InitHooking() {
        MH_Initialize();

        void* ProcessEventHookLocal = (void*)(Globals::ModuleBase + PLOffsets::PROCESSEVENT);

        MH_CreateHook(ProcessEventHookLocal, reinterpret_cast<void*>(ProcessEventHook), &origProcessEvent);

        MH_EnableHook(ProcessEventHookLocal);

        void* initMCPProfile = (void*)(Globals::ModuleBase + PLOffsets::INIT_MCP_PROFILE);

        MH_CreateHook(initMCPProfile, reinterpret_cast<void*>(InitializeMCPProfileHook), &origInitializeMCPProfile);

        MH_EnableHook(initMCPProfile);

        void* returnToMainMenu = (void*)(Globals::ModuleBase + PLOffsets::RETURN_TO_MENU);

        MH_CreateHook(returnToMainMenu, reinterpret_cast<void*>(ReturnToMainMenuHook), &origReturnToMainMenu);

        MH_EnableHook(returnToMainMenu);

        void* browseHook = (void*)(Globals::ModuleBase + PLOffsets::BROWSE);

        MH_CreateHook(browseHook, reinterpret_cast<void*>(UEngineBrowseHook), &origBrowse);

        void* setUIState = (void*)(Globals::ModuleBase + PLOffsets::UI_STATE_HOOK);

        MH_CreateHook(setUIState, reinterpret_cast<void*>(SetUIStateHook), &origSetUIState);

        MH_EnableHook(setUIState);
    }
}

void InitConsole() {
    AllocConsole();
    FILE* f = new FILE();
    freopen_s(&f, "CONOUT$", "w", stdout);
}

void ConnectToMatch() {
    std::ifstream config("config.json");
    std::stringstream sstream;
    std::string configString;

    sstream << config.rdbuf();

    configString = sstream.str();

    Json::Value configValue = Json::Value();

    Json::Reader reader = Json::Reader();

    reader.parse(configString, configValue);

    std::string nwIp(configValue["ip"].asString());

    std::wstring ip(nwIp.begin(), nwIp.end());

    std::string nwDisplayName(configValue["displayname"].asString());

    std::wstring displayname(nwDisplayName.begin(), nwDisplayName.end());

    std::string nwHero(configValue["hero"].asString());

    std::wstring hero(nwHero.begin(), nwHero.end());

    std::string nwTeam(configValue["team"].asString());

    std::wstring team(nwTeam.begin(), nwTeam.end());


    std::string nwRole(configValue["role"].asString());
    std::wstring role(nwRole.begin(), nwRole.end());


    std::string nwSkin(configValue["skin"].asString());
    std::wstring skin(nwSkin.begin(), nwSkin.end());

    std::wstring baseCmd(L"open ");
    std::wstring finalCmd = baseCmd.append(ip).append(L"?displayname=").append(displayname).append(L"?hero=").append(hero).append(L"?team=").append(team);
    if (!role.empty()) {
        finalCmd.append(L"?role=").append(role);
    }
    if (!skin.empty()) {
        finalCmd.append(L"?skin=").append(skin);
    }

    {
        std::ifstream deckFile("deck.json");
        if (deckFile.good()) {
            std::stringstream dss;
            dss << deckFile.rdbuf();
            Json::Value deckVal = Json::Value();
            Json::Reader deckReader = Json::Reader();
            if (deckReader.parse(dss.str(), deckVal)) {
                std::string nwDeck(deckVal["deck"].asString());
                if (!nwDeck.empty()) {
                    std::wstring deckW(nwDeck.begin(), nwDeck.end());
                    finalCmd.append(L"?deck=").append(deckW);
                    std::cout << "[CLIENT] Deck-Filter aktiv (deck.json): ?deck=" << nwDeck << std::endl;
                }
            }
        }
    }

    EngineLogic::ExecuteConsoleCommand(finalCmd.c_str());
}

void OnGameInit() {
    std::cout << "Enabling game console..." << std::endl;
    EngineLogic::EnableGameConsole();
    Hooking::ProcInGameThread(ConnectToMatch);
}

void SetUIToInGame() {
    GameLogic::SetUIState(EOrionUIState::Match);
    std::cout << "[CLIENT] UI State auf Match gesetzt!" << std::endl;


    AOrionPlayerController_Game* PC = SDKUtils::GetLastOfType<AOrionPlayerController_Game>();
    if (PC && PC->PlayerState) {
        for (UOrionItemizationComponent* Comp : SDKUtils::GetAllObjectsOfType<UOrionItemizationComponent>()) {
            if (Comp && reinterpret_cast<UObject*>(Comp)->Outer == PC->PlayerState) {

                if (Comp->AllCards.Data && Comp->AllCards.NumElements > 0 && Comp->AllCards.NumElements < 200) {
                    for (int i = 0; i < Comp->AllCards.NumElements; i++) {
                        UOrionGameplayCard* Card = Comp->AllCards.Data[i];
                        if (Card && !IsBadReadPtr(Card, 0x10)) {
                            reinterpret_cast<UObject*>(Card)->Outer = PC->PlayerState;
                        }
                    }
                }

                if (Comp->AllGems.Data && Comp->AllGems.NumElements > 0 && Comp->AllGems.NumElements < 100) {
                    for (int i = 0; i < Comp->AllGems.NumElements; i++) {
                        UOrionGameplayGem* Gem = Comp->AllGems.Data[i];
                        if (Gem && !IsBadReadPtr(Gem, 0x10)) {
                            reinterpret_cast<UObject*>(Gem)->Outer = PC->PlayerState;
                        }
                    }
                }

                std::cout << "[CLIENT] Lokale Besitzurkunden fuer Karten korrigiert. Attribute funktionieren!" << std::endl;
                break;
            }
        }
    }
}


int SafeReadClientASCSpecs(uintptr_t asc, int* outHandles, void** outAbilities,
                           int* outLevels, void** outSourceObjs, unsigned char* outFlags, int maxN) {
    __try {
        void* data = *reinterpret_cast<void**>(asc + 0x520);
        int num = *reinterpret_cast<int*>(asc + 0x528);
        if (!data || num <= 0 || num > 256) return 0;
        int n = 0;
        for (int s = 0; s < num && n < maxN; s++) {
            uintptr_t spec = reinterpret_cast<uintptr_t>(data) + static_cast<size_t>(s) * 0xC8;
            outHandles[n]    = *reinterpret_cast<int*>(spec + 0xC);
            outAbilities[n]  = *reinterpret_cast<void**>(spec + 0x10);
            outLevels[n]     = *reinterpret_cast<int*>(spec + 0x18);
            outSourceObjs[n] = *reinterpret_cast<void**>(spec + 0x20);
            outFlags[n]      = *reinterpret_cast<unsigned char*>(spec + 0x29);
            n++;
        }
        return n;
    } __except (EXCEPTION_EXECUTE_HANDLER) {
        return -1;
    }
}

int SafeFixClientSpec(uintptr_t asc, int handle, void* card) {
    __try {
        void* data = *reinterpret_cast<void**>(asc + 0x520);
        int num = *reinterpret_cast<int*>(asc + 0x528);
        if (!data || num <= 0 || num > 256) return 0;
        for (int s = 0; s < num; s++) {
            uintptr_t spec = reinterpret_cast<uintptr_t>(data) + static_cast<size_t>(s) * 0xC8;
            if (*reinterpret_cast<int*>(spec + 0xC) == handle) {
                if (*reinterpret_cast<int*>(spec + 0x18) == 0) {
                    *reinterpret_cast<int*>(spec + 0x18) = 11;
                    *reinterpret_cast<void**>(spec + 0x20) = card;
                    return 1;
                }
                return 0;
            }
        }
        return 0;
    } __except (EXCEPTION_EXECUTE_HANDLER) {
        return -1;
    }
}

void DumpClientCardSpecs() {
    std::ostringstream out;
    AOrionPlayerController_Game* PC = SDKUtils::GetLastOfType<AOrionPlayerController_Game>();
    if (!PC || !PC->PlayerState) {
        out << "[CLIENT-ACT] kein PC/PlayerState\n";
    } else {
        for (UOrionItemizationComponent* Comp : SDKUtils::GetAllObjectsOfType<UOrionItemizationComponent>()) {
            if (!Comp || reinterpret_cast<UObject*>(Comp)->Outer != PC->PlayerState) continue;
            out << "[CLIENT-ACT] ===== AllCards=" << Comp->AllCards.NumElements
                << " Equipped=" << Comp->EquippedCards.NumElements << " =====\n";
            if (Comp->EquippedCards.Data && Comp->EquippedCards.NumElements > 0 && Comp->EquippedCards.NumElements < 50) {
                for (int i = 0; i < Comp->EquippedCards.NumElements; i++) {
                    UOrionGameplayCard* Card = Comp->EquippedCards.Data[i];
                    if (!Card || IsBadReadPtr(Card, 0x40)) continue;
                    std::string name = "?";
                    if (Card->SourceItemDefinition && !IsBadReadPtr(Card->SourceItemDefinition, 0x10))
                        name = reinterpret_cast<UObject*>(Card->SourceItemDefinition)->GetName();
                    uintptr_t cp = reinterpret_cast<uintptr_t>(Card);
                    void* data = *reinterpret_cast<void**>(cp + 0x28);
                    int num = *reinterpret_cast<int*>(cp + 0x30);
                    out << "[CLIENT-ACT] slot=" << i << " card=" << name << " handlesNum=" << num;
                    if (data && num > 0 && num < 16 && !IsBadReadPtr(data, num * 16)) {
                        for (int h = 0; h < num; h++) {
                            int baseH  = *reinterpret_cast<int*>(reinterpret_cast<uintptr_t>(data) + 16 * h + 0x8);
                            int grantH = *reinterpret_cast<int*>(reinterpret_cast<uintptr_t>(data) + 16 * h + 0xC);
                            out << " | h[" << h << "] base=" << baseH << " granted=" << grantH;
                        }
                    }
                    out << "\n";
                }
            }
            break;
        }

        UOrionAbilitySystemComponent* ASC = nullptr;
        for (UOrionAbilitySystemComponent* a : SDKUtils::GetAllObjectsOfType<UOrionAbilitySystemComponent>()) {
            if (!a || IsBadReadPtr(a, 0x10)) continue;
            UObject* ao = reinterpret_cast<UObject*>(a);
            if (ao->Outer == reinterpret_cast<UObject*>(PC->PlayerState) ||
                (PC->Pawn && ao->Outer == reinterpret_cast<UObject*>(PC->Pawn))) { ASC = a; break; }
        }
        if (ASC) {
            static int specHandles[256];
            static void* specAbils[256];
            static int specLevels[256];
            static void* specSrc[256];
            static unsigned char specFlags[256];
            int sn = SafeReadClientASCSpecs(reinterpret_cast<uintptr_t>(ASC), specHandles, specAbils,
                                            specLevels, specSrc, specFlags, 256);
            out << "[CLIENT-ACT] Client-ASC=0x" << std::hex << reinterpret_cast<uintptr_t>(ASC) << std::dec
                << " ActivatableAbilities=" << sn << " (nur Card/Ward-GAs):\n";
            for (int s = 0; s < sn; s++) {
                std::string an = (specAbils[s] && !IsBadReadPtr(specAbils[s], 0x10))
                    ? reinterpret_cast<UObject*>(specAbils[s])->GetName() : "?";
                if (an.find("Card") != std::string::npos || an.find("ShadowWard") != std::string::npos)
                    out << "[CLIENT-ACT]   spec handle=" << specHandles[s] << " ability=" << an
                        << " Level=" << specLevels[s]
                        << " SourceObj=0x" << std::hex << reinterpret_cast<uintptr_t>(specSrc[s]) << std::dec
                        << " flags=0x" << std::hex << static_cast<int>(specFlags[s]) << std::dec << "\n";
            }
        } else {
            out << "[CLIENT-ACT] Client-ASC NICHT gefunden (Outer==PS/Pawn)\n";
        }
        out << "[CLIENT-ACT] ===== ENDE =====\n";
    }

    std::cout << out.str() << std::flush;

    char p[MAX_PATH] = { 0 };
    HMODULE hSelf = nullptr;
    GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                       reinterpret_cast<LPCSTR>(&DumpClientCardSpecs), &hSelf);
    DWORD n = hSelf ? GetModuleFileNameA(hSelf, p, MAX_PATH) : 0;
    if (n > 0 && n < MAX_PATH) {
        char* slash = strrchr(p, '\\');
        if (slash) strcpy_s(slash + 1, MAX_PATH - static_cast<size_t>(slash + 1 - p), "client_act.txt");
        else       strcpy_s(p, MAX_PATH, "client_act.txt");
    } else {
        strcpy_s(p, MAX_PATH, "client_act.txt");
    }
    static bool s_firstActWrite = true;
    std::ofstream af(p, std::ios::out | (s_firstActWrite ? std::ios::trunc : std::ios::app));
    s_firstActWrite = false;
    if (af.is_open()) af << out.str();
}

static bool IsLiveObject(void* p) {
    if (!p || IsBadReadPtr(p, sizeof(UObject))) return false;
    UObject* o = reinterpret_cast<UObject*>(p);
    return UObject::GObjects->GetByIndex(o->Index) == o;
}

void FixClientCardSpecs() {
    static AOrionPlayerController_Game* s_pc = nullptr;
    static UOrionAbilitySystemComponent* s_asc = nullptr;
    static UOrionItemizationComponent* s_comp = nullptr;
    if (!IsLiveObject(s_pc)) s_pc = SDKUtils::GetLastOfType<AOrionPlayerController_Game>();
    AOrionPlayerController_Game* PC = s_pc;
    if (!PC || !PC->PlayerState) { std::cout << "[CLIENT-FIX] kein PC/PlayerState" << std::endl; return; }
    auto ascBelongs = [&](UOrionAbilitySystemComponent* a) {
        UObject* ao = reinterpret_cast<UObject*>(a);
        return ao->Outer == reinterpret_cast<UObject*>(PC->PlayerState) ||
               (PC->Pawn && ao->Outer == reinterpret_cast<UObject*>(PC->Pawn));
    };
    if (!IsLiveObject(s_asc) || !ascBelongs(s_asc)) {
        s_asc = nullptr;
        for (UOrionAbilitySystemComponent* a : SDKUtils::GetAllObjectsOfType<UOrionAbilitySystemComponent>()) {
            if (!a || IsBadReadPtr(a, 0x10)) continue;
            if (ascBelongs(a)) { s_asc = a; break; }
        }
    }
    UOrionAbilitySystemComponent* ASC = s_asc;
    if (!ASC) { std::cout << "[CLIENT-FIX] Client-ASC nicht gefunden" << std::endl; return; }
    if (!IsLiveObject(s_comp) || reinterpret_cast<UObject*>(s_comp)->Outer != PC->PlayerState) {
        s_comp = nullptr;
        for (UOrionItemizationComponent* c : SDKUtils::GetAllObjectsOfType<UOrionItemizationComponent>()) {
            if (c && reinterpret_cast<UObject*>(c)->Outer == PC->PlayerState) { s_comp = c; break; }
        }
    }
    for (UOrionItemizationComponent* Comp : { s_comp }) {
        if (!Comp) continue;
        if (Comp->EquippedCards.Data && Comp->EquippedCards.NumElements > 0 && Comp->EquippedCards.NumElements < 50) {
            for (int i = 0; i < Comp->EquippedCards.NumElements; i++) {
                UOrionGameplayCard* Card = Comp->EquippedCards.Data[i];
                if (!Card || IsBadReadPtr(Card, 0x40)) continue;
                uintptr_t cp = reinterpret_cast<uintptr_t>(Card);
                void* data = *reinterpret_cast<void**>(cp + 0x28);
                int num = *reinterpret_cast<int*>(cp + 0x30);
                if (!data || num <= 0 || num >= 16 || IsBadReadPtr(data, num * 16)) continue;
                for (int h = 0; h < num; h++) {
                    int grantH = *reinterpret_cast<int*>(reinterpret_cast<uintptr_t>(data) + 16 * h + 0xC);
                    if (grantH <= 0) continue;
                    int r = SafeFixClientSpec(reinterpret_cast<uintptr_t>(ASC), grantH, reinterpret_cast<void*>(Card));
                    if (r == 1) std::cout << "[CLIENT-FIX] slot=" << i << " handle=" << grantH << " GEFIXT (Level=11, SourceObj=Karte)" << std::endl;
                    else if (r == -1) std::cout << "[CLIENT-FIX] slot=" << i << " handle=" << grantH << " SEH-Abbruch" << std::endl;
                }
            }
        }
        break;
    }
}


void MainLoop() {
    bool hackApplied = false;

    while (true) {
        if (!hackApplied) {
            AOrionPlayerController_Game* PC = SDKUtils::GetLastOfType<AOrionPlayerController_Game>();
            if (PC && PC->PlayerState) {
                for (UOrionItemizationComponent* Comp : SDKUtils::GetAllObjectsOfType<UOrionItemizationComponent>()) {
                    if (Comp && reinterpret_cast<UObject*>(Comp)->Outer == PC->PlayerState) {

                        if (Comp->AllCards.Data && Comp->AllCards.NumElements > 0) {
                            std::cout << "[CLIENT] Server-Karten entdeckt! Warte 2 Sekunden auf Netzwerk-Sync..." << std::endl;

                            Sleep(2000);

                            Hooking::ProcInGameThread(SetUIToInGame);
                            hackApplied = true;
                        }
                        break;
                    }
                }
            }
        }

        if (GetAsyncKeyState(VK_F5) & 0x8000) {
            Hooking::g_clientSsrtLog = !Hooking::g_clientSsrtLog;
            std::cout << "[CLIENT] F5: SSRT-Logger " << (Hooking::g_clientSsrtLog ? "AN (-> client_ssrt.txt)" : "AUS") << std::endl;
            while (GetAsyncKeyState(VK_F5) & 0x8000) { Sleep(10); }
        }

        if (GetAsyncKeyState(VK_F6) & 0x8000) {
            Hooking::ProcInGameThread(SetUIToInGame);
            hackApplied = true;
            while (GetAsyncKeyState(VK_F6) & 0x8000) { Sleep(10); }
        }

        if (GetAsyncKeyState(VK_F7) & 0x8000) {
            Hooking::ProcInGameThread(DumpClientCardSpecs);
            while (GetAsyncKeyState(VK_F7) & 0x8000) { Sleep(10); }
        }

        if (GetAsyncKeyState(VK_F8) & 0x8000) {
            Hooking::ProcInGameThread(FixClientCardSpecs);
            while (GetAsyncKeyState(VK_F8) & 0x8000) { Sleep(10); }
        }

        if (hackApplied) {
            static int s_fixTick = 0;
            if (++s_fixTick % 5 == 0) {
                Hooking::ProcInGameThread(FixClientCardSpecs);
            }
        }

        Sleep(100);
    }
}


void Main() {


    InitConsole();

    Globals::ModuleBase = (uintptr_t)GetModuleHandleA("OrionClient-Win64-Shipping.exe");

    Hooking::InitHooking();

    OnGameInit();

    while (true) {
        MainLoop();
    }
}

BOOL APIENTRY DllMain(HMODULE hModule,
    DWORD  ul_reason_for_call,
    LPVOID lpReserved
)
{
    if (ul_reason_for_call == DLL_PROCESS_ATTACH) {
        std::thread t(Main);

        t.detach();
    }
    return TRUE;
}
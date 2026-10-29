
#include "pch.h"
#include <thread>
#include <iostream>
#include "dxgi.h"
#include "dxgi1_3.h"
#include "dxgi1_6.h"
#include <chrono>

#pragma comment(lib, "DXGI.lib")

HMODULE g_hOriginalDXGI = NULL;
typedef HRESULT(WINAPI* fpCreateDXGIFactory)(REFIID, void**);
typedef HRESULT(WINAPI* fpCreateDXGIFactory1)(REFIID, void**);
typedef HRESULT(WINAPI* fpCreateDXGIFactory2)(UINT, REFIID, void**);

fpCreateDXGIFactory g_pOrigCreateDXGIFactory = NULL;
fpCreateDXGIFactory1 g_pOrigCreateDXGIFactory1 = NULL;
fpCreateDXGIFactory2 g_pOrigCreateDXGIFactory2 = NULL;

void InitializeOriginalFunctions() {
    char systemPath[MAX_PATH];
    GetSystemDirectoryA(systemPath, MAX_PATH);

    char dxgiPath[MAX_PATH];
    sprintf_s(dxgiPath, MAX_PATH, "%s\\dxgi.dll", systemPath);

    g_hOriginalDXGI = LoadLibraryA(dxgiPath);
    if (g_hOriginalDXGI) {
        g_pOrigCreateDXGIFactory = (fpCreateDXGIFactory)GetProcAddress(g_hOriginalDXGI, "CreateDXGIFactory");
        g_pOrigCreateDXGIFactory1 = (fpCreateDXGIFactory1)GetProcAddress(g_hOriginalDXGI, "CreateDXGIFactory1");
        g_pOrigCreateDXGIFactory2 = (fpCreateDXGIFactory2)GetProcAddress(g_hOriginalDXGI, "CreateDXGIFactory2");
    }
}

void InjectionThread() {
    if ((uintptr_t)GetModuleHandleA("OrionClient-Win64-Shipping-Server.exe")) {
        std::this_thread::sleep_for(std::chrono::seconds(25));
        LoadLibraryA("Server.dll");
    }
    else if ((uintptr_t)GetModuleHandleA("OrionClient-Win64-Shipping.exe")) {
        std::this_thread::sleep_for(std::chrono::seconds(45));
        LoadLibraryA("Client.dll");
    }
}

// The injection thread is spawned from the first CreateDXGIFactory* call (the
// engine's render init) instead of from DllMain(DLL_PROCESS_ATTACH). Spawning a
// thread while holding the loader lock during early process init fails under
// Wine 11 (EXCEPTION_WINE_STUB, the thread never starts), and deferring to a
// normal execution context is safe on Windows too: the payload DLLs wait for
// engine readiness on their own, so the few seconds of extra delay are
// harmless.
static volatile LONG g_spawned = 0;
static void TrySpawnInjection() {
    if (InterlockedCompareExchange(&g_spawned, 1, 0) == 0) {
        std::thread(InjectionThread).detach();
    }
}

extern "C" HRESULT __stdcall CreateDXGIFactoryFake(REFIID riid, void** ppFactory) {
    TrySpawnInjection();
    if (g_pOrigCreateDXGIFactory) {
        return g_pOrigCreateDXGIFactory(riid, ppFactory);
    }
    return E_FAIL;
}

extern "C" HRESULT __stdcall CreateDXGIFactory1Fake(REFIID riid, void** ppFactory) {
    TrySpawnInjection();
    if (g_pOrigCreateDXGIFactory1) {
        return g_pOrigCreateDXGIFactory1(riid, ppFactory);
    }
    return E_FAIL;
}

extern "C" HRESULT __stdcall CreateDXGIFactory2Fake(UINT Flags, REFIID riid, void** ppFactory) {
    TrySpawnInjection();
    if (g_pOrigCreateDXGIFactory2) {
        return g_pOrigCreateDXGIFactory2(Flags, riid, ppFactory);
    }
    return E_FAIL;
}

void Main() {
    InitializeOriginalFunctions();
    // Injection thread spawn happens in TrySpawnInjection (first factory call).
}

BOOL APIENTRY DllMain(HMODULE hModule,
    DWORD  ul_reason_for_call,
    LPVOID lpReserved
)
{
    if (ul_reason_for_call == DLL_PROCESS_ATTACH) {
        Main();
    }
    return TRUE;
}
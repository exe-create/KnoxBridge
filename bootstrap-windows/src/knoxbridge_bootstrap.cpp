#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cwchar>

static HMODULE g_module = nullptr;

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) g_module = instance;
    return TRUE;
}

// Loaded before libinstrument by the ordered -agentpath / -javaagent VM arguments.
// Add this PZ install's bundled JRE bin directory to native DLL dependency lookup.
extern "C" __declspec(dllexport) int __cdecl Agent_OnLoad(void*, char*, void*) {
    wchar_t modulePath[32768];
    constexpr size_t capacity = sizeof(modulePath) / sizeof(modulePath[0]);
    DWORD length = GetModuleFileNameW(g_module, modulePath, static_cast<DWORD>(capacity));
    if (length == 0 || length >= capacity) return -1;

    wchar_t* separator = std::wcsrchr(modulePath, L'\\');
    if (separator == nullptr) return -1;
    *separator = L'\0'; // .knoxbridge directory
    separator = std::wcsrchr(modulePath, L'\\');
    if (separator == nullptr) return -1;
    *separator = L'\0'; // Project Zomboid install directory

    size_t used = std::wcslen(modulePath);
    const wchar_t suffix[] = L"\\jre64\\bin";
    size_t suffixLength = std::wcslen(suffix);
    if (used + suffixLength >= capacity) return -1;
    for (size_t i = 0; i <= suffixLength; ++i) modulePath[used + i] = suffix[i];
    return SetDllDirectoryW(modulePath) ? 0 : -1;
}

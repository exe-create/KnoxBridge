#define UNICODE
#define _UNICODE
#include <windows.h>
#include <shlobj.h>

#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

namespace {
constexpr int kInstallerPayloadResource = 101;

std::wstring quoteArgument(const std::wstring& value) {
    std::wstring result = L"\"";
    size_t backslashes = 0;
    for (wchar_t ch : value) {
        if (ch == L'\\') {
            ++backslashes;
        } else if (ch == L'"') {
            result.append(backslashes * 2 + 1, L'\\');
            result.push_back(ch);
            backslashes = 0;
        } else {
            result.append(backslashes, L'\\');
            backslashes = 0;
            result.push_back(ch);
        }
    }
    result.append(backslashes * 2, L'\\');
    result.push_back(L'"');
    return result;
}

bool writeBytes(const std::filesystem::path& path, const void* data, DWORD size) {
    HANDLE file = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
                              FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return false;
    DWORD written = 0;
    const bool ok = WriteFile(file, data, size, &written, nullptr) && written == size;
    CloseHandle(file);
    return ok;
}

bool extractBundledPayload(const std::filesystem::path& destination) {
    HRSRC resource = FindResourceW(nullptr, MAKEINTRESOURCEW(kInstallerPayloadResource), RT_RCDATA);
    if (!resource) return false;
    HGLOBAL loaded = LoadResource(nullptr, resource);
    if (!loaded) return false;
    const DWORD size = SizeofResource(nullptr, resource);
    const void* data = LockResource(loaded);
    return data && size > 0 && writeBytes(destination, data, size);
}

int extractOnly(const wchar_t* outputPath) {
    const std::filesystem::path destination(outputPath);
    if (!destination.parent_path().empty()) {
        SHCreateDirectoryExW(nullptr, destination.parent_path().c_str(), nullptr);
    }
    if (!extractBundledPayload(destination)) {
        std::wcerr << L"Could not extract the embedded KnoxBridge package.\n";
        return 2;
    }
    std::wcout << L"Embedded KnoxBridge package extracted.\n";
    return 0;
}

std::filesystem::path localInstallerDirectory() {
    wchar_t* localAppData = nullptr;
    const HRESULT result = SHGetKnownFolderPath(FOLDERID_LocalAppData, KF_FLAG_CREATE, nullptr,
                                                 &localAppData);
    if (FAILED(result) || !localAppData) return {};
    std::filesystem::path directory(localAppData);
    CoTaskMemFree(localAppData);
    return directory / L"KnoxBridgeRuntime" / L"Installer" / L"0.1.0-alpha4";
}

int launchSetup() {
    const auto directory = localInstallerDirectory();
    if (directory.empty()) {
        std::wcerr << L"Could not find your Windows local application-data folder.\n";
        return 2;
    }
    const int directoryResult = SHCreateDirectoryExW(nullptr, directory.c_str(), nullptr);
    if (directoryResult != ERROR_SUCCESS && directoryResult != ERROR_ALREADY_EXISTS) {
        std::wcerr << L"Could not create the KnoxBridge setup folder:\n" << directory << L"\n";
        return 2;
    }

    const auto payload = directory / L"installer-payload.zip";
    const auto runner = directory / L"start-setup.ps1";
    if (!extractBundledPayload(payload)) {
        std::wcerr << L"Could not extract the embedded KnoxBridge package.\n";
        return 2;
    }

    const std::string runnerText =
        "param([Parameter(Mandatory=$true)][string]$PayloadZip,[Parameter(Mandatory=$true)][string]$PackageRoot)\r\n"
        "$ErrorActionPreference = 'Stop'\r\n"
        "Expand-Archive -LiteralPath $PayloadZip -DestinationPath $PackageRoot -Force\r\n"
        "Remove-Item -LiteralPath $PayloadZip -Force\r\n"
        "& (Join-Path $PackageRoot 'scripts\\user-setup.ps1')\r\n";
    if (!writeBytes(runner, runnerText.data(), static_cast<DWORD>(runnerText.size()))) {
        std::wcerr << L"Could not prepare the built-in setup menu.\n";
        return 2;
    }

    std::wstring command = L"powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File " +
        quoteArgument(runner.wstring()) + L" -PayloadZip " + quoteArgument(payload.wstring()) +
        L" -PackageRoot " + quoteArgument(directory.wstring());
    std::vector<wchar_t> mutableCommand(command.begin(), command.end());
    mutableCommand.push_back(L'\0');

    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    PROCESS_INFORMATION process{};
    if (!CreateProcessW(nullptr, mutableCommand.data(), nullptr, nullptr, TRUE, 0, nullptr, nullptr,
                        &startup, &process)) {
        std::wcerr << L"Windows PowerShell could not be started (error " << GetLastError() << L").\n";
        return 2;
    }
    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD exitCode = 2;
    GetExitCodeProcess(process.hProcess, &exitCode);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return static_cast<int>(exitCode);
}
}  // namespace

int wmain(int argc, wchar_t** argv) {
    if (argc == 3 && std::wstring(argv[1]) == L"--extract-payload") return extractOnly(argv[2]);
    std::wcout << L"KnoxBridge Setup - no separate Java download is needed.\n"
               << L"The runtime uses Project Zomboid's bundled Java.\n\n";
    const int result = launchSetup();
    if (result != 0) {
        std::wcout << L"Setup could not continue. Press Enter to close this window.";
        std::wstring ignored;
        std::getline(std::wcin, ignored);
    }
    return result;
}

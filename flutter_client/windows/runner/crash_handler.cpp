#include "crash_handler.h"

#include <windows.h>
#include <dbghelp.h>

#include <string>
#include <vector>

namespace {

std::wstring DiagnosticsRoot() {
  DWORD required = GetEnvironmentVariableW(L"LOCALAPPDATA", nullptr, 0);
  if (required > 1) {
    std::vector<wchar_t> value(required);
    if (GetEnvironmentVariableW(L"LOCALAPPDATA", value.data(), required) > 0) {
      return std::wstring(value.data()) + L"\\AssTimer";
    }
  }

  wchar_t temporary_path[MAX_PATH] = {};
  if (GetTempPathW(MAX_PATH, temporary_path) > 0) {
    return std::wstring(temporary_path) + L"AssTimer";
  }
  return L"AssTimer";
}

LONG WINAPI WriteMiniDump(EXCEPTION_POINTERS* exception_pointers) {
  const std::wstring root = DiagnosticsRoot();
  const std::wstring crash_directory = root + L"\\crashes";
  CreateDirectoryW(root.c_str(), nullptr);
  CreateDirectoryW(crash_directory.c_str(), nullptr);

  SYSTEMTIME now = {};
  GetSystemTime(&now);
  wchar_t file_name[160] = {};
  _snwprintf_s(file_name, _countof(file_name), _TRUNCATE,
               L"\\ass-timer-%04d%02d%02dT%02d%02d%02dZ-%lu.dmp", now.wYear,
               now.wMonth, now.wDay, now.wHour, now.wMinute, now.wSecond,
               GetCurrentProcessId());
  const std::wstring dump_path = crash_directory + file_name;

  HANDLE file = CreateFileW(dump_path.c_str(), GENERIC_WRITE, 0, nullptr,
                            CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file != INVALID_HANDLE_VALUE) {
    MINIDUMP_EXCEPTION_INFORMATION exception_info = {};
    exception_info.ThreadId = GetCurrentThreadId();
    exception_info.ExceptionPointers = exception_pointers;
    exception_info.ClientPointers = FALSE;
    const auto dump_type = static_cast<MINIDUMP_TYPE>(
        MiniDumpNormal | MiniDumpWithThreadInfo |
        MiniDumpWithIndirectlyReferencedMemory);
    MiniDumpWriteDump(GetCurrentProcess(), GetCurrentProcessId(), file,
                      dump_type, &exception_info, nullptr, nullptr);
    CloseHandle(file);
  }
  return EXCEPTION_EXECUTE_HANDLER;
}

}  // namespace

void InstallCrashHandler() {
  SetUnhandledExceptionFilter(WriteMiniDump);
}

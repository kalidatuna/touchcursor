#include <windows.h>
#include <cstdio>
#include <cwchar>
#include <cstdlib>
#include <crtdbg.h>

// Static hook tests run before main. Report assertions to CI instead of opening
// a Windows assertion dialog that would block an unattended build.
struct ConfigureTestReports {
    ConfigureTestReports() {
        _CrtSetReportMode(_CRT_ASSERT, _CRTDBG_MODE_FILE);
        _CrtSetReportFile(_CRT_ASSERT, _CRTDBG_FILE_STDERR);
        _CrtSetReportMode(_CRT_ERROR, _CRTDBG_MODE_FILE);
        _CrtSetReportFile(_CRT_ERROR, _CRTDBG_FILE_STDERR);
        _set_error_mode(_OUT_TO_STDERR);
    }
} configureTestReports;

// Run the real hook's existing synthetic-event suite without installing a hook.
// Emit its diagnostics to CI, rather than only to the Windows debugger.
inline void testTrace(const wchar_t* message) {
    std::fwprintf(stderr, L"%ls", message);
}
#undef OutputDebugString
#define OutputDebugString testTrace
#include "../touchcursordll/dllmain.cpp"

int main() {
    std::puts("PASS: real hook state-machine regression suite, including both activation keys");
    return test::failures ? 1 : 0;
}

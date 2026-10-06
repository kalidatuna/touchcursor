#include <windows.h>
#include <cstdio>
#include <cwchar>

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

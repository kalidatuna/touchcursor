#include "../tclib/options.cpp"
#include <cstdio>
#include <cstdlib>
#include <crtdbg.h>
#include <exception>

static void require(bool ok, const char* message) {
    if (!ok) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}

int main(int argc, char** argv) {
    _CrtSetReportMode(_CRT_ASSERT, _CRTDBG_MODE_FILE);
    _CrtSetReportFile(_CRT_ASSERT, _CRTDBG_FILE_STDERR);
    _set_error_mode(_OUT_TO_STDERR);
    try {
    require(argc == 2, "legacy fixture path supplied");
    Options original(Options::defaults);
    std::fprintf(stderr, "Testing version-7 settings round trip\n");
    original.activationKey = 'A';
    original.activationKey2 = 'Q';
    original.keyMapping['J'] = VK_DOWN;
    original.disableProgs.push_back(L"example.exe");
    std::wistringstream encoded(original.AsString());
    boost::archive::text_wiarchive input(encoded);
    Options loaded(Options::defaults);
    input >> loaded;
    require(loaded.activationKey == 'A', "primary key round trip");
    require(loaded.activationKey2 == 'Q', "secondary key round trip");
    require(loaded.keyMapping['J'] == VK_DOWN, "mapping round trip");
    require(loaded.disableProgs == original.disableProgs, "program list round trip");

    std::ifstream fixture(argv[1], std::ios::binary);
    std::fprintf(stderr, "Testing version-6 settings migration\n");
    require(fixture.is_open(), "legacy fixture opens");
    std::string bytes;
    char byte = 0;
    while (fixture.get(byte)) bytes.push_back(byte);
    require(fixture.eof(), "legacy fixture read completes");
    require(!bytes.empty(), "legacy fixture contains settings");
    std::wstring saved(bytes.begin(), bytes.end());

    std::wistringstream legacyEncoded(saved);
    boost::archive::text_wiarchive legacyInput(legacyEncoded);
    Options legacy(Options::defaults);
    legacyInput >> legacy;
    require(legacy.activationKey == 'A', "version-6 primary key preserved");
    require(legacy.activationKey2 == 0, "version-6 secondary key defaults to none");
    require(legacy.keyMapping['J'] == VK_DOWN, "version-6 mapping preserved");
    require(legacy.disableProgs.size() == 1 && legacy.disableProgs[0] == L"example.exe", "version-6 program list preserved");

    {
        std::wofstream installed(settingsFilePath());
        installed << saved;
        require(installed.good(), "legacy fixture installed in runner profile");
    }
    Options migrated;
    require(migrated.activationKey == 'A' && migrated.activationKey2 == 0, "real disk load preserves version-6 keys");
    require(migrated.keyMapping['J'] == VK_DOWN && migrated.disableProgs == legacy.disableProgs, "real disk load preserves mapping and program list");

    original.Save();
    Options reloaded;
    require(reloaded.activationKey == 'A' && reloaded.activationKey2 == 'Q', "real Save/Load preserves both keys");
    std::puts("PASS: settings round trip and genuine version-6 archive migration");
    return 0;
    } catch (const std::exception& error) {
        std::fprintf(stderr, "FAIL: settings archive exception: %s\n", error.what());
        return 1;
    }
}

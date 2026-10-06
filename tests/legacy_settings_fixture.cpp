// The build generates this copy from options.cpp with archive version 6.
// Its serializer omits the new version-7 field and writes a real old archive.
#include "generated_options_v6.cpp"
#include <fstream>
int main(int argc, char** argv) {
    if (argc != 2) return 1;
    Options legacy(Options::defaults);
    legacy.activationKey = 'A';
    legacy.keyMapping['J'] = VK_DOWN;
    legacy.disableProgs.push_back(L"example.exe");

    const std::wstring encoded = legacy.AsString();
    std::ofstream file(argv[1], std::ios::binary);
    for (std::wstring::const_iterator it = encoded.begin(); it != encoded.end(); ++it) {
        if (*it > 0x7f) return 2;
        file.put(static_cast<char>(*it));
    }
    return file.good() ? 0 : 1;
}

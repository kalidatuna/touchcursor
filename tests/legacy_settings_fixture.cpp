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
    std::wofstream file(argv[1]);
    file << legacy.AsString();
    return file.good() ? 0 : 1;
}

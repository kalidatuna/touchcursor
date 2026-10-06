$ErrorActionPreference = 'Stop'
$boost = 'C:\tc-deps\boost_1_86_0'
$wx = 'C:\tc-deps\wx'
$boostLib = "$boost\lib32-msvc-14.3"

# Generate resources with the matching, source-built wxrc, not the old bundled EXE.
$wxrc = Get-ChildItem "$wx\utils\wxrc" -Filter wxrc.exe -Recurse | Select-Object -First 1
if (!$wxrc) { throw 'Built wxrc.exe is missing' }
Copy-Item $wxrc.FullName touchcursorconfig\wxrc.exe -Force
Push-Location touchcursorconfig
& .\wxrc.exe -e -c -o xrcres.cpp tcconfig.xrc
if ($LASTEXITCODE) { throw 'Resource generation failed' }
Pop-Location

msbuild touchcursor.sln /nologo /m /p:Configuration=Release /p:Platform=Win32 /p:PlatformToolset=v143 "/p:BOOST_DIR=$boost" "/p:WXWIDGETS_DIR=$wx" /p:WindowsTargetPlatformVersion=10.0 /verbosity:minimal
if ($LASTEXITCODE) { throw 'Windows Release build failed' }

$common = @('/nologo','/EHsc','/MDd','/D_DEBUG','/DUNICODE','/D_UNICODE',"/I$boost",'/Itclib')
$link = @('/link',"/LIBPATH:$boostLib",'user32.lib','shell32.lib','advapi32.lib','psapi.lib','gdi32.lib','comdlg32.lib','version.lib','wininet.lib')
$support = @('tclib/options.cpp','tclib/launch.cpp','tclib/win32funcs.cpp','tclib/versionupdate.cpp')
& cl.exe @common tests/state_machine_tests.cpp @support /Fetests/state_machine_tests.exe @link
if ($LASTEXITCODE) { throw 'State-machine test build failed' }
& .\tests\state_machine_tests.exe 2>&1 | Tee-Object tests\state-machine.log
if ($LASTEXITCODE) { throw 'State-machine regression tests failed' }

$legacy = [IO.File]::ReadAllText("$PWD\tclib\options.cpp").Replace('BOOST_CLASS_VERSION(Options, 7)','BOOST_CLASS_VERSION(Options, 6)')
[IO.File]::WriteAllText("$PWD\tests\generated_options_v6.cpp", $legacy)
& cl.exe @common tests/legacy_settings_fixture.cpp tclib/launch.cpp /Fetests/legacy_settings_fixture.exe @link
if ($LASTEXITCODE) { throw 'Legacy-fixture build failed' }
& .\tests\legacy_settings_fixture.exe tests\settings-v6.cfg
if ($LASTEXITCODE) { throw 'Legacy-fixture generation failed' }
& cl.exe @common tests/settings_tests.cpp tclib/launch.cpp /Fetests/settings_tests.exe @link
if ($LASTEXITCODE) { throw 'Settings-test build failed' }
& .\tests\settings_tests.exe tests\settings-v6.cfg 2>&1 | Tee-Object tests\settings.log
if ($LASTEXITCODE) { throw 'Settings/migration tests failed' }

# Verify the actual release configuration window starts and exposes both selectors.
Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class TouchCursorWindows {
    public delegate bool Callback(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr hwnd, Callback callback, IntPtr data);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd, StringBuilder text, int size);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd, uint message, IntPtr w, IntPtr l);
    public struct Rect { public int Left, Top, Right, Bottom; }
    public static int CountChoices(IntPtr hwnd) {
        int count = 0;
        EnumChildWindows(hwnd, (child, data) => {
            var text = new StringBuilder(256);
            GetClassName(child, text, text.Capacity);
            if (text.ToString() == "ComboBox") count++;
            return true;
        }, IntPtr.Zero);
        return count;
    }
}
'@
$config = Start-Process .\bin\Release\tcconfig.exe -PassThru
try {
    if (!$config.WaitForInputIdle(15000)) { throw 'Configuration window did not become ready' }
    $config.Refresh()
    $window = $config.MainWindowHandle
    if (!$window -or $config.HasExited) { throw 'Configuration window did not open' }
    $choices = [TouchCursorWindows]::CountChoices($window)
    if ($choices -lt 2) { throw "Expected both activation-key selectors, found $choices" }
    "PASS: Release configuration window opened with $choices key selectors" | Tee-Object tests\window-smoke.log
    Add-Type -AssemblyName System.Drawing
    $rect = New-Object TouchCursorWindows+Rect
    [TouchCursorWindows]::GetWindowRect($window, [ref]$rect) | Out-Null
    $bitmap = [System.Drawing.Bitmap]::new(($rect.Right-$rect.Left),($rect.Bottom-$rect.Top))
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $dc = $graphics.GetHdc()
    try { [TouchCursorWindows]::PrintWindow($window,$dc,0) | Out-Null }
    finally { $graphics.ReleaseHdc($dc) }
    $bitmap.Save("$PWD\tests\configuration-window.png")
    $graphics.Dispose(); $bitmap.Dispose()
} finally {
    if (!$config.HasExited) {
        $config.CloseMainWindow() | Out-Null
        if (!$config.WaitForExit(5000)) { $config.Kill() }
    }
}

New-Item dist\TouchCursor\docs -ItemType Directory -Force | Out-Null
Copy-Item bin\Release\touchcursor.exe,bin\Release\touchcursor.dll,bin\Release\tcconfig.exe,bin\Release\touchcursor_update.exe dist\TouchCursor
Copy-Item COPYING.txt,RELEASE_NOTES.md dist\TouchCursor
$crt = Get-ChildItem "$env:VCToolsRedistDir\x86" -Directory -Filter 'Microsoft.VC*.CRT' | Select-Object -First 1
if (!$crt) { throw 'Redistributable x86 runtime folder not found' }
Copy-Item "$($crt.FullName)\*.dll" dist\TouchCursor
python -m pip install --quiet markdown==3.7
if ($LASTEXITCODE) { throw 'Documentation dependency failed' }
Push-Location setup
python make_docs.py ..\dist\TouchCursor\docs
if ($LASTEXITCODE) { throw 'Documentation build failed' }
Pop-Location
New-Item dist\TouchCursor\licenses -ItemType Directory -Force | Out-Null
Copy-Item "$boost\LICENSE_1_0.txt" dist\TouchCursor\licenses\Boost.txt
Copy-Item "$wx\docs\licence.txt" dist\TouchCursor\licenses\wxWidgets.txt
Copy-Item tests\*.log,tests\configuration-window.png dist\TouchCursor
git rev-parse HEAD | Set-Content dist\TouchCursor\SOURCE_COMMIT.txt
Get-ChildItem dist\TouchCursor -File | ForEach-Object { Get-FileHash $_.FullName -Algorithm SHA256 | ForEach-Object { "$($_.Hash)  $([IO.Path]::GetFileName($_.Path))" } } | Set-Content dist\TouchCursor\SHA256SUMS.txt
Compress-Archive dist\TouchCursor dist\TouchCursor-two-keys-Windows-x86.zip
Get-FileHash dist\TouchCursor-two-keys-Windows-x86.zip -Algorithm SHA256 | Format-List

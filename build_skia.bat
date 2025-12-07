@echo off
setlocal enabledelayedexpansion

REM Build Skia for Windows
REM Requires: Visual Studio 2017/2019/2022, Python 3
REM Recommended: LLVM/Clang for optimal performance

echo ============================================
echo Building Skia for Windows
echo ============================================

REM Check for Python (try common locations if not in PATH)
set PYTHON_CMD=python
python --version >nul 2>&1
if errorlevel 1 (
    REM Try common Python installation paths
    for %%P in (
        "%USERPROFILE%\AppData\Local\Programs\Python\Python312\python.exe"
        "%USERPROFILE%\AppData\Local\Programs\Python\Python311\python.exe"
        "%USERPROFILE%\AppData\Local\Programs\Python\Python310\python.exe"
        "C:\Python312\python.exe"
        "C:\Python311\python.exe"
        "C:\Python310\python.exe"
    ) do (
        if exist %%P (
            set PYTHON_CMD=%%P
            echo Found Python at: %%P
            goto :python_found
        )
    )
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3 from https://www.python.org/downloads/
    exit /b 1
)
:python_found
echo Using Python: %PYTHON_CMD%

REM Add Python to PATH for gn to find it
set PATH=C:\Users\timey\AppData\Local\Programs\Python\Python312;C:\Users\timey\AppData\Local\Programs\Python\Python312\Scripts;%PATH%

REM Save starting directory
set START_DIR=%~dp0
cd /d "%START_DIR%"

REM 1. Setup GN and Ninja
echo.
echo [1/5] Setting up build tools...

REM 2. Sync Dependencies (serial mode to avoid 429 rate limits)
echo.
echo [2/5] Syncing dependencies in SERIAL mode (this may take a while)...
%PYTHON_CMD% "%START_DIR%git-sync-deps-serial.py"
if errorlevel 1 (
    echo ERROR: Failed to sync dependencies
    exit /b 1
)

REM 3. Configure Skia Build
echo.
echo [3/5] Configuring Skia...
cd /d "%START_DIR%skia"

REM Clean previous build
if exist out\Release (
    echo Cleaning previous build...
    rmdir /s /q out\Release
)

REM Check if LLVM/Clang is installed (recommended for performance)
set CLANG_WIN=
if exist "C:\Program Files\LLVM\bin\clang-cl.exe" (
    set CLANG_WIN=C:\Program Files\LLVM
    echo Found LLVM at: !CLANG_WIN!
    echo Using Clang for optimized build
)

REM Build arguments - similar to Linux but for Windows
REM is_component_build=true creates a DLL instead of static lib
REM We disable system libraries to ensure self-contained build
set GN_ARGS=is_component_build=true is_official_build=false is_debug=false
set GN_ARGS=%GN_ARGS% skia_use_expat=false
set GN_ARGS=%GN_ARGS% skia_use_system_freetype2=false
set GN_ARGS=%GN_ARGS% skia_use_system_libjpeg_turbo=false
set GN_ARGS=%GN_ARGS% skia_use_system_libpng=false
set GN_ARGS=%GN_ARGS% skia_use_system_zlib=false
set GN_ARGS=%GN_ARGS% skia_use_system_icu=false
set GN_ARGS=%GN_ARGS% skia_use_system_harfbuzz=false
set GN_ARGS=%GN_ARGS% skia_use_gl=false
set GN_ARGS=%GN_ARGS% skia_enable_pdf=false
set GN_ARGS=%GN_ARGS% skia_use_libwebp_decode=false
set GN_ARGS=%GN_ARGS% skia_use_libwebp_encode=false

REM Add Clang if available (highly recommended for performance)
if defined CLANG_WIN (
    set GN_ARGS=%GN_ARGS% clang_win=\"!CLANG_WIN!\"
)

echo.
echo GN args: %GN_ARGS%
echo.

REM Create the output directory and args.gn file directly to avoid command-line quoting issues
if not exist out\Release mkdir out\Release

REM Write args.gn with proper formatting (one arg per line)
(
echo is_component_build=true
echo is_official_build=false
echo is_debug=false
echo skia_use_expat=false
echo skia_use_system_libjpeg_turbo=false
echo skia_use_system_libpng=false
echo skia_use_system_zlib=false
echo skia_use_system_icu=false
echo skia_use_system_harfbuzz=false
echo skia_use_gl=false
echo skia_enable_pdf=false
echo skia_use_libwebp_decode=false
echo skia_use_libwebp_encode=false
echo skia_use_freetype=true
echo skia_enable_fontmgr_custom_directory=true
echo skia_enable_fontmgr_custom_empty=true
) > out\Release\args.gn

REM Add clang_win if available
if defined CLANG_WIN (
    echo clang_win="!CLANG_WIN!" >> out\Release\args.gn
)

bin\gn gen out/Release
if errorlevel 1 (
    echo ERROR: GN configuration failed
    cd /d "%START_DIR%"
    exit /b 1
)

REM 4. Build
echo.
echo [4/5] Building Skia (this may take a while)...
ninja -C out\Release skia
if errorlevel 1 (
    echo ERROR: Build failed
    cd /d "%START_DIR%"
    exit /b 1
)

REM 5. Copy library
echo.
echo [5/5] Copying library...
cd /d "%START_DIR%"

if exist skia\out\Release\skia.dll (
    copy skia\out\Release\skia.dll .
    copy skia\out\Release\skia.dll.lib .
    echo.
    echo ============================================
    echo SUCCESS! Built files:
    echo   - skia.dll (runtime library)
    echo   - skia.dll.lib (import library for linking)
    echo ============================================
) else (
    echo ERROR: skia.dll not found in build output
    echo Check skia\out\Release for available files
    dir skia\out\Release\*.dll 2>nul
    dir skia\out\Release\*.lib 2>nul
    exit /b 1
)

echo.
echo NOTE: For best performance, install LLVM/Clang from:
echo   https://releases.llvm.org/download.html
echo And re-run this script.
echo.

endlocal

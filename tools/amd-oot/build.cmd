@echo off
rem SPDX-FileCopyrightText: 2026 OoTTeste contributors
rem SPDX-License-Identifier: GPL-3.0-or-later
rem
rem Usage: tools\amd-oot\build.cmd [generic^|tigerlake]
rem Run it from cmd or PowerShell, not from Git Bash: the configure step breaks there.
rem Paths specific to one machine go in local-paths.cmd (see local-paths.example.cmd).
setlocal
set "CPU_TARGET=%~1"
if not defined CPU_TARGET set "CPU_TARGET=generic"
for %%I in ("%~dp0..\..") do set "REPO=%%~fI"

set "VS_DIR=%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools"
set "QT_DIR=C:\Qt\6.8.3\msvc2022_64"
set "CPM_CACHE=%REPO%\.cache\cpm"
set "JOBS=8"
if exist "%~dp0local-paths.cmd" call "%~dp0local-paths.cmd"

if /i "%CPU_TARGET%"=="generic" goto :generic
if /i "%CPU_TARGET%"=="tigerlake" goto :tigerlake
echo Uso: build.cmd [generic^|tigerlake]
exit /b 2

:generic
if not defined BUILD_DIR_GENERIC set "BUILD_DIR_GENERIC=%REPO%\build\amd-generic"
set "BUILD_DIR=%BUILD_DIR_GENERIC%"
set "CPU_ARGS="
goto :configure

:tigerlake
if not defined BUILD_DIR_TIGERLAKE set "BUILD_DIR_TIGERLAKE=%REPO%\build\amd-tigerlake"
set "BUILD_DIR=%BUILD_DIR_TIGERLAKE%"
set CPU_ARGS="-DCMAKE_C_FLAGS=/clang:-march=tigerlake /clang:-mtune=tigerlake" "-DCMAKE_CXX_FLAGS=/clang:-march=tigerlake /clang:-mtune=tigerlake"
goto :configure

:configure
if not defined VULKAN_SDK (
    echo Defina VULKAN_SDK em tools\amd-oot\local-paths.cmd
    exit /b 2
)
call "%VS_DIR%\VC\Auxiliary\Build\vcvars64.bat" >nul 2>nul || exit /b 1
set "PATH=%VS_DIR%\VC\Tools\Llvm\x64\bin;%VULKAN_SDK%\Bin;%QT_DIR%\bin;%PATH%"
if defined EXTRA_PATH set "PATH=%EXTRA_PATH%;%PATH%"

cmake -S "%REPO%" -B "%BUILD_DIR%" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl %CPU_ARGS% "-DCMAKE_EXE_LINKER_FLAGS=/machine:x64" "-DCMAKE_SHARED_LINKER_FLAGS=/machine:x64" "-DCMAKE_MODULE_LINKER_FLAGS=/machine:x64" -DCPM_SOURCE_CACHE="%CPM_CACHE%" -DENABLE_LTO=OFF -DBUILD_TESTING=OFF -DYUZU_TESTS=OFF -DYUZU_CMD=ON -DYUZU_ROOM=OFF -DYUZU_ROOM_STANDALONE=OFF -DYUZU_USE_BUNDLED_QT=OFF -DCMAKE_PREFIX_PATH="%QT_DIR%" -DYUZU_USE_BUNDLED_SDL3=ON -DENABLE_UPDATE_CHECKER=OFF -DUSE_DISCORD_PRESENCE=OFF -DENABLE_WERROR=OFF || exit /b 1
cmake --build "%BUILD_DIR%" --target yuzu yuzu-cmd --parallel %JOBS%
exit /b %ERRORLEVEL%

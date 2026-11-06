@echo off
rem SPDX-FileCopyrightText: 2026 OoTTeste contributors
rem SPDX-License-Identifier: GPL-3.0-or-later
rem
rem Copy to local-paths.cmd, which git ignores, and adjust to this machine.
rem Only VULKAN_SDK is required; the others have defaults in build.cmd.
set "VULKAN_SDK=C:\VulkanSDK\1.4.341.1"
rem set "VS_DIR=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
rem set "QT_DIR=C:\Qt\6.8.3\msvc2022_64"
rem set "CPM_CACHE=D:\cache\cpm"
rem set "BUILD_DIR_GENERIC=D:\builds\amd-generic"
rem set "BUILD_DIR_TIGERLAKE=D:\builds\amd-tigerlake"
rem set "JOBS=8"
rem Folders with cmake.exe and ninja.exe, if they are not on PATH:
rem set "EXTRA_PATH=C:\tools\cmake\bin;C:\tools\ninja"

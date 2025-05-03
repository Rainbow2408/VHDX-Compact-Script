@echo off
setlocal enabledelayedexpansion

set "p=%"
set "q=""

:-------------------------------------
:: Check for permissions
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
 
:: If error flag set, we do not have admin.
if '%errorlevel%' NEQ '0' (
    echo 請求管理員權限...
    goto UACPrompt
) else ( goto gotAdmin )
 
:UACPrompt
    (
    echo Set UAC = CreateObject^("Shell.Application"^)
    echo UAC.ShellExecute "%temp%\run_script.bat", "", "", "runas", 1
    ) > "%temp%\getadmin.vbs"
    (
    echo @echo off
    echo echo.
    echo echo [Message] Working directory at "%~dp0"
    echo echo.
    echo CD /D "%~dp0"
    echo set "TargetPath=%q%%~s0%q%"
    echo set "Arg1=%q%%~1%q%"
    echo set "Arg2=%q%%~2%q%"
    echo cmd /c "%%%p%TargetPath%p%%% %%%p%Arg1%p%%% %%%p%Arg2%p%%%"
    ) > "%temp%\run_script.bat"
 
    "%temp%\getadmin.vbs"
    exit /B
 
:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    if exist "%temp%\run_script.bat" ( del "%temp%\run_script.bat" )
    pushd "%CD%"
    CD /D "%~dp0"
:--------------------------------------

:: 獲取參數
set "vhd_path=%~1"
set "use_sdelete=%~2"

:: 創建臨時 diskpart 腳本
set "diskpart_mount_rw=%temp%\mount_rw.txt"
set "diskpart_mount_ro=%temp%\mount_ro.txt"
set "diskpart_detach=%temp%\detach.txt"
set "diskpart_compact=%temp%\compact.txt"

:: 創建掛載磁碟(可寫)腳本
(
echo select vdisk file="%vhd_path%"
echo attach vdisk
echo exit
) > "%diskpart_mount_rw%"

:: 創建掛載磁碟(唯讀)腳本
(
echo select vdisk file="%vhd_path%"
echo attach vdisk readonly
echo exit
) > "%diskpart_mount_ro%"

:: 創建解除掛載腳本
(
echo select vdisk file="%vhd_path%"
echo detach vdisk
echo exit
) > "%diskpart_detach%"

:: 創建壓縮腳本
(
echo select vdisk file="%vhd_path%"
echo compact vdisk
echo exit
) > "%diskpart_compact%"

:: 檢查步驟標號
set step=1
set total_step=6

if "%use_sdelete%" NEQ "1" (
    set total_step=3
    goto SkipSDelete
)

:: 執行 sdelete 處理
:: 建立暫存檔案
set "diskpart_list_vdisk=%temp%\list_vdisk.txt"
set "diskpart_show_disk=%temp%\show_disk.txt"
set "volume_list=%temp%\volume_list.txt"
set "vdisk_list=%temp%\vdisk_list.txt"

:: 先檢查虛擬磁碟是否已經掛載
echo 步驟 %step%/%total_step%: 檢查虛擬磁碟是否已掛載...
:FindVdisk
(
echo list vdisk
) > "%diskpart_list_vdisk%"

diskpart /s "%diskpart_list_vdisk%" > "%vdisk_list%"
echo.

:: 找出指定的虛擬磁碟編號，逐行讀取並檢查是否包含目標路徑
for /f "usebackq delims=" %%a in ("%vdisk_list%") do (
    set "line=%%a"
    :: 檢查該行是否包含我們的 VHD 路徑
    echo !line! | findstr /i /c:"%vhd_path%" >nul
    if !errorlevel! equ 0 (
        :: 如果找到路徑，解析 VDisk 和磁碟編號
        for /f "tokens=2,4" %%b in ("!line!") do (
            :: 只有當磁碟編號不是 "---" 時才更新值
            if not "%%c"=="---" (
                set "vdisk_num=%%b"
                set "disk_num=%%c"
            )
        )
    )
)

if not defined disk_num (
    if not defined retry (
        echo 步驟 %step%/%total_step%: 掛載虛擬磁碟^(可寫模式^)^.^.^.
        diskpart /s "%diskpart_mount_rw%"
        echo.
        set retry=1
        goto FindVdisk
    ) else (
        echo 錯誤: 無法找到虛擬磁碟編號
        goto cleanup
    )
)

set /a step+=1
:: 獲取磁碟上的磁碟區資訊
(
echo select disk %disk_num%
echo detail disk
) > "%diskpart_show_disk%"

diskpart /s "%diskpart_show_disk%" > "%volume_list%"
echo.

:: 處理每個磁碟區
for /f "usebackq delims=" %%a in ("%volume_list%") do (
    set "line=%%a"
    :: 檢查是否為磁碟區資訊行
    echo !line! | findstr /r /c:"^ *磁碟區 [0-9]" >nul
    if !errorlevel! equ 0 (
        :: 移除行首空格
        for /f "tokens=* delims= " %%i in ("!line!") do set "line=%%i"
        :: 提取磁碟區編號、磁碟代號、標籤、檔案系統等資訊
        for /f "tokens=2,3,4,5 delims= " %%b in ("!line!") do (
            set "volume_num=%%b"
            set "ltr=%%c"
            set "label=%%d"
            set "fs=%%e"
            set "valid=true"
            :: 檢查長度是否為 1
            if not "!ltr!"=="!ltr:~0,1!" set "valid=false"
            :: 檢查是否為 A-Z
            echo !ltr! | findstr /i "[A-Z]" >nul || set "valid=false"
            if "!valid!"=="true" (
                echo !fs! | findstr /i "NTFS FAT" >nul
                if !errorlevel! equ 0 (
                    echo 使用 sdelete64 清理磁碟區 !ltr!: ^(!fs!^)^.^.^.
                    sdelete64 -z !ltr!:
                )
            )
        )
    )
)
set /a step+=1

echo 步驟 %step%/%total_step%: 解除掛載虛擬磁碟...
set /a step+=1
diskpart /s "%diskpart_detach%"
echo.

:SkipSDelete

echo 步驟 %step%/%total_step%: 掛載虛擬磁碟(唯讀模式)...
set /a step+=1
diskpart /s "%diskpart_mount_ro%"
echo.

echo 步驟 %step%/%total_step%: 壓縮虛擬磁碟...
set /a step+=1
diskpart /s "%diskpart_compact%"

echo 步驟 %step%/%total_step%: 解除掛載虛擬磁碟...
set /a step+=1
diskpart /s "%diskpart_detach%"

echo.
echo 操作完成: 虛擬磁碟壓縮已完成！

:cleanup
:: 清理臨時文件
del "%diskpart_mount_rw%" 2>nul
del "%diskpart_mount_ro%" 2>nul
del "%diskpart_detach%" 2>nul
del "%diskpart_compact%" 2>nul
if "%use_sdelete%" EQU "1" (
    del "%diskpart_list_vdisk%" 2>nul
    del "%diskpart_show_disk%" 2>nul
    del "%volume_list%" 2>nul
    del "%vdisk_list%" 2>nul
)
echo.

pause

endlocal
exit /b 0

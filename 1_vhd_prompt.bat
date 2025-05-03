@echo off
setlocal enabledelayedexpansion

:: 檢查 sdelete64 是否存在
where sdelete64 >nul 2>nul
if %errorlevel% equ 0 (
    set "sdelete_exists=1"
) else (
    set "sdelete_exists=0"
)

:: 詢問使用者是否要使用 sdelete64
if %sdelete_exists% equ 1 (
    set /p use_sdelete="是否使用 sdelete64 清理磁碟空間 (y/N): "
    echo !use_sdelete! | findstr /i "^y" >nul && (
        set "use_sdelete=1"
    ) || (
        set "use_sdelete=0"
    )
) else (
    set "use_sdelete=0"
)

:: 獲取虛擬磁碟路徑
set /p vhd_path="請輸入虛擬磁碟路徑 (例如: D:\a.vhdx): "

:: 檢查路徑是否存在
if not exist "!vhd_path!" (
    echo 錯誤: 找不到指定的虛擬磁碟路徑
    pause
    exit /b 1
)

:: 調用第二個腳本進行處理
cmd /c "2_vhd_compress.bat %vhd_path% %use_sdelete%"

endlocal
exit /b 0
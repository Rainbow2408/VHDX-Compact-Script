## 如何安裝

直接下載就可以了 Code -> Download Zip

或是 Git Clone 方法

記得 1_vhd_prompt.bat 和 2_vhd_compress.bat 要放在同一目錄，雙擊打開 1_vhd_prompt.bat 即可食用。

## 使用方法

### 訊息1: 是否使用 sdelete64 清理磁碟空間 (y/N) 

預設為 (N)，會檢查系統有沒有 sdelete64 指令

如果沒有請到微軟說明網頁下載：

<https://learn.microsoft.com/zh-tw/sysinternals/downloads/sdelete>

或是直接下載

<https://download.sysinternals.com/files/SDelete.zip>

下載後找一個位置存放，再將位置加入環境變數即可。


### 訊息2: 請輸入虛擬磁碟路徑 (例如: D:\a.vhdx) 

可以有空白路徑，像是 "D:\a b\c.vhdx"，記得使用雙引號包住，一般直接把檔案拉進來就自動貼上路徑了。

註： 會自動申請 UAC 管理員權限，以便進行 Diskpart 操作

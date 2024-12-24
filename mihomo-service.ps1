# mihomo-service.ps1

# 定义常量
$REAL_USER = $env:USERNAME
$MIHOMO_CONFIG_DIR = "C:\Users\$REAL_USER\proxy"
$MIHOMO_CONFIG = Join-Path $MIHOMO_CONFIG_DIR "config.yaml"
$SUBSCRIPTION_FILE = Join-Path $MIHOMO_CONFIG_DIR "subscription.txt"

$INSTALL_DIR = "C:\Program Files\mihomo"
$MIHOMO_PATH = Join-Path $INSTALL_DIR "mihomo.exe"
$GITHUB_API = "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest"
$TASK_NAME = "mihomo"



# 检查管理员权限
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 初始化目录
function Initialize-Directories {
    if (!(Test-Path $MIHOMO_CONFIG_DIR)) {
        New-Item -ItemType Directory -Path $MIHOMO_CONFIG_DIR -Force | Out-Null
        Write-Host "[+] Created configuration directory: $MIHOMO_CONFIG_DIR"
    }

    if (!(Test-Path $SUBSCRIPTION_FILE)) {
        New-Item -ItemType File -Path $SUBSCRIPTION_FILE -Force | Out-Null
        Write-Host "[+] Created subscription file: $SUBSCRIPTION_FILE"
    }
}

# 创建服务（使用计划任务）
function Install-MihomoService {
    $action = New-ScheduledTaskAction -Execute $MIHOMO_PATH -Argument "-d `"$MIHOMO_CONFIG_DIR`""
    $trigger = New-ScheduledTaskTrigger -AtLogon
    $principal = New-ScheduledTaskPrincipal -UserId $REAL_USER -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    Register-ScheduledTask -TaskName $TASK_NAME -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force
    Write-Host "[+] Service created successfully."
}

# 添加订阅
function Add-Subscription {
    param([string]$url)
    
    if ([string]::IsNullOrEmpty($url)) {
        Write-Host "Error: Please provide a subscription URL."
        return
    }

    if ($url -notmatch '^https?://') {
        Write-Host "Error: Invalid URL format."
        return
    }

    $url | Out-File $SUBSCRIPTION_FILE -Force
    Write-Host "[+] Subscription added successfully."
    Update-Config
}

# 显示当前订阅
function Show-Subscription {
    if (Test-Path $SUBSCRIPTION_FILE) {
        if ((Get-Item $SUBSCRIPTION_FILE).Length -gt 0) {
            Write-Host "Current subscription URL:"
            Get-Content $SUBSCRIPTION_FILE
        } else {
            Write-Host "Notice: No subscription URL found."
        }
    }
}



function Get-LatestMihomoVersion {
    try {
        $release = Invoke-RestMethod -Uri $GITHUB_API
        $version = $release.tag_name
        $asset = $release.assets | Where-Object { $_.name -like "*windows-amd64*.zip" } | Select-Object -First 1
        return @{
            Version = $version
            DownloadUrl = $asset.browser_download_url
        }
    } catch {
        Write-Host "Error: Failed to get latest version info: $_"
        return $null
    }
}

function Get-CurrentVersion {
    if (Test-Path $MIHOMO_PATH) {
        try {
            $versionOutput = (& $MIHOMO_PATH -v) | Select-Object -First 1
            if ($versionOutput -match "v[0-9]+\.[0-9]+\.[0-9]+") {
                return $Matches[0]
            }
        } catch {
            return $null
        }
    }
    return $null
}


function Install-Mihomo {
    param (
        [switch]$Force
    )

    $latest = Get-LatestMihomoVersion
    if ($null -eq $latest) {
        Write-Host "Error: Failed to get latest version information."
        return $false
    }

    $currentVersion = Get-CurrentVersion
    if (!$Force -and $currentVersion -eq $latest.Version) {
        Write-Host "Current version ($currentVersion) is already up to date."
        return $true
    }

    Write-Host "Installing mihomo $($latest.Version)..."
    
    # 创建临时目录
    $tempDir = Join-Path $env:TEMP "mihomo_install"
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    $zipFile = Join-Path $tempDir "mihomo.zip"

    try {
        # 下载文件
        Write-Host "Downloading mihomo..."
        Invoke-WebRequest -Uri $latest.DownloadUrl -OutFile $zipFile

        # 停止现有服务
        Stop-MihomoService

        # 创建安装目录
        if (!(Test-Path $INSTALL_DIR)) {
            New-Item -ItemType Directory -Force -Path $INSTALL_DIR | Out-Null
        }

        # 解压文件
        Write-Host "Extracting files..."
        Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
        
        # 复制文件到安装目录
        Get-ChildItem -Path $tempDir -Filter "mihomo*.exe" -Recurse | 
            Copy-Item -Destination $MIHOMO_PATH -Force

        # 清理临时文件
        Remove-Item -Path $tempDir -Recurse -Force

        Write-Host "[+] mihomo $($latest.Version) installed successfully."
        return $true
    }
    catch {
        Write-Host "Error during installation: $_"
        return $false
    }
}

function Test-Mihomo {
    if (!(Test-Path $MIHOMO_PATH)) {
        Write-Host "mihomo not found. Installing..."
        if (!(Install-Mihomo)) {
            Write-Host "Error: Failed to install mihomo."
            exit 1
        }
    }
}

function Update-Mihomo {
    Write-Host "Checking for updates..."
    Install-Mihomo -Force
}


# 禁用自启动
function Disable-Autostart {
    Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false
    Write-Host "[+] Autostart disabled."
}

# 显示帮助信息
function Show-Help {
    Write-Host @"
Usage: $($MyInvocation.MyCommand.Name) [command] [arguments]
Commands:
  start           Start the service and enable autostart
  stop            Stop the service
  restart         Restart the service
  status          Check service status
  disable         Disable autostart
  add-sub [URL]   Add a subscription URL
  show-sub        Display the current subscription URL
  update          Update the configuration
  update-mihomo   Update mihomo to latest version
  version         Show current mihomo version
  help            Display this help information
"@
}

# 重启服务
# 修改 Restart-MihomoService 函数
function Restart-MihomoService {
    # 检查任务是否存在
    $taskExists = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue

    if (-not $taskExists) {
        # 如果任务不存在，先创建它
        Write-Host "Creating service..."
        Install-MihomoService
    } else {
        # 如果任务存在，则停止它
        Stop-MihomoService
    }

    Start-Sleep -Seconds 2
    Start-MihomoService
}

# 修改 Stop-MihomoService 函数
function Stop-MihomoService {
    $taskExists = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    if ($taskExists) {
        Stop-ScheduledTask -TaskName $TASK_NAME
    }
    # 确保进程被终止
    Get-Process | Where-Object { $_.Path -eq $MIHOMO_PATH } | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "[+] Service stopped."
}

# 修改 Start-MihomoService 函数
function Start-MihomoService {
    $taskExists = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    if (-not $taskExists) {
        Write-Host "Creating service..."
        Install-MihomoService
    }
    
    Start-ScheduledTask -TaskName $TASK_NAME
    Write-Host "[+] Service started."
    Write-Host "-> Dashboard URL: https://metacubexd.pages.dev/"
    Write-Host "-> Default port: 9097"
}

# 修改 Update-Config 函数
function Update-Config {
    Write-Host "Updating configuration..."

    if (Test-Path $SUBSCRIPTION_FILE) {
        $url = Get-Content $SUBSCRIPTION_FILE
        try {
            Invoke-WebRequest -Uri $url -OutFile $MIHOMO_CONFIG
            if (Test-Path $MIHOMO_CONFIG) {
                Write-Host "[+] Configuration downloaded successfully."
                # 如果配置更新成功，重启服务
                Restart-MihomoService
            } else {
                Write-Host "Error: Failed to save configuration file."
            }
        } catch {
            Write-Host "Error: Configuration update failed. Please check the subscription URL."
            Write-Host "Error details: $_"
        }
    } else {
        Write-Host "Error: No valid subscription URL found."
    }
}


# 检查服务状态
function Get-MihomoStatus {
    $task = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host "Task Status: $($task.State)"
        $process = Get-Process | Where-Object { $_.Path -eq $MIHOMO_PATH }
        if ($process) {
            Write-Host "[+] Service status: Running (PID: $($process.Id))"
        } else {
            Write-Host "[-] Service status: Not running"
        }
    } else {
        Write-Host "Service not installed"
    }
}

# 主程序
if (-not (Test-Administrator)) {
    Write-Host "Error: This script must be run as Administrator."
    exit 1
}

Test-Mihomo
Initialize-Directories

switch ($args[0]) {
    "start" {
        Install-MihomoService
        Start-MihomoService
    }
    "stop" {
        Stop-MihomoService
    }
    "restart" {
        Restart-MihomoService
    }
    "status" {
        Get-MihomoStatus
    }
    "disable" {
        Disable-Autostart
    }
    "add-sub" {
        Add-Subscription $args[1]
    }
    "show-sub" {
        Show-Subscription
    }
    "update" {
        Update-Config
    }
    "update-mihomo" {
        Update-Mihomo
    }
    "version" {
        $current = Get-CurrentVersion
        if ($current) {
            Write-Host "Current version: $current"
        } else {
            Write-Host "mihomo is not installed"
        }
    }
    default {
        Show-Help
    }
}

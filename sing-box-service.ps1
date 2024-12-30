# sing-box-service.ps1

$REAL_USER = $env:USERNAME
$INSTALL_DIR = "C:\Program Files\sing-box"
$SINGBOX_CONFIG = Join-Path $INSTALL_DIR "config.json"
$SUBSCRIPTION_FILE = Join-Path $INSTALL_DIR "subscription.txt"
$SINGBOX_PATH = (Get-Command sing-box -ErrorAction SilentlyContinue).Path
$TASK_NAME = "sing-box"

# 检查管理员权限
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 初始化目录
function Initialize-Directories {
    if (!(Test-Path $INSTALL_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
        Write-Host "[+] Created configuration directory: $INSTALL_DIR"
    }

    if (!(Test-Path $SUBSCRIPTION_FILE)) {
        New-Item -ItemType File -Path $SUBSCRIPTION_FILE -Force | Out-Null
        Write-Host "[+] Created subscription file: $SUBSCRIPTION_FILE"
    }
}

# 创建服务（使用计划任务）
function Install-SingBoxService {
    $SINGBOX_PATH = (Get-Command sing-box -ErrorAction SilentlyContinue).Path
    $action = New-ScheduledTaskAction -Execute $SINGBOX_PATH -Argument "run -C `"$INSTALL_DIR`""
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

# 安装sing-box
function Install-SingBox {
    try {
        Write-Host "Installing sing-box using winget..."
        winget install sing-box
        Write-Host "[+] sing-box installed successfully."
        return $true
    }
    catch {
        Write-Host "Error during installation: $_"
        return $false
    }
}

# 更新sing-box
function Update-SingBox {
    Write-Host "Updating sing-box using winget..."
    winget upgrade sing-box
}

# 检查sing-box是否安装
function Test-SingBox {
    if (!$SINGBOX_PATH) {
        Write-Host "sing-box not found. Installing..."
        if (!(Install-SingBox)) {
            Write-Host "Error: Failed to install sing-box."
            exit 1
        }
        # 重新获取安装后的路径
        $SINGBOX_PATH = (Get-Command sing-box -ErrorAction SilentlyContinue).Path
    }
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
  update-singbox  Update sing-box to latest version
  help            Display this help information
"@
}

# 重启服务
function Restart-SingBoxService {
    $taskExists = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    if (-not $taskExists) {
        Write-Host "Creating service..."
        Install-SingBoxService
    } else {
        Stop-SingBoxService
    }
    Start-Sleep -Seconds 2
    Start-SingBoxService
}

# 停止服务
function Stop-SingBoxService {
    $taskExists = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    if ($taskExists) {
        Stop-ScheduledTask -TaskName $TASK_NAME
    }
    Get-Process | Where-Object { $_.Path -eq $SINGBOX_PATH } | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "[+] Service stopped."
}

# 启动服务
function Start-SingBoxService {
    $taskExists = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    if (-not $taskExists) {
        Write-Host "Creating service..."
        Install-SingBoxService
    }
    Start-ScheduledTask -TaskName $TASK_NAME
    Write-Host "[+] Service started."
}

# 更新配置
function Update-Config {
    Write-Host "Updating configuration..."

    if (Test-Path $SUBSCRIPTION_FILE) {
        $url = Get-Content $SUBSCRIPTION_FILE
        try {
            Invoke-WebRequest -Uri $url -OutFile $SINGBOX_CONFIG
            if (Test-Path $SINGBOX_CONFIG) {
                Write-Host "[+] Configuration downloaded successfully."
                Restart-SingBoxService
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
function Get-SingBoxStatus {
    $task = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host "Task Status: $($task.State)"
        $process = Get-Process | Where-Object { $_.Path -eq $SINGBOX_PATH }
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

Test-SingBox
Initialize-Directories

switch ($args[0]) {
    "start" {
        Install-SingBoxService
        Start-SingBoxService
    }
    "stop" {
        Stop-SingBoxService
    }
    "restart" {
        Restart-SingBoxService
    }
    "status" {
        Get-SingBoxStatus
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
    "update-singbox" {
        Update-SingBox
    }
    default {
        Show-Help
    }
}

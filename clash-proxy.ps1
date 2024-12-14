# mihomo-manager.ps1

# 定义常量
$MIHOMO_DIR = "C:\Users\18317\OneDrive\Downloads\mihomo-windows-amd64-v1.18.9"
$MIHOMO_EXE = Join-Path $MIHOMO_DIR "mihomo-windows-amd64.exe"
$CONFIG_DIR = "C:\Users\18317\OneDrive\Proxy"
$CONFIG_FILE = Join-Path $CONFIG_DIR "config.yaml"
$SUBSCRIPTION_FILE = Join-Path $CONFIG_DIR "subscription.txt"
$TASK_NAME = "Start Mihomo"
$LOG_FILE = Join-Path $CONFIG_DIR "mihomo.log"

# 检查管理员权限
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 初始化目录
function Initialize-Directories {
    if (!(Test-Path $CONFIG_DIR)) {
        New-Item -ItemType Directory -Path $CONFIG_DIR -Force
        Write-Host "✓ Created configuration directory: $CONFIG_DIR"
    }
    
    if (!(Test-Path $SUBSCRIPTION_FILE)) {
        New-Item -ItemType File -Path $SUBSCRIPTION_FILE -Force
        Write-Host "✓ Created subscription file: $SUBSCRIPTION_FILE"
    }
}

# 创建服务
function Install-MihomoService {
    $scriptContent = @"
Start-Process -FilePath "$MIHOMO_EXE" -ArgumentList '-ext-ctl "127.0.0.1:9090"', '-f "$CONFIG_FILE"' -WindowStyle Hidden
"@
    
    $scriptPath = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "StartMihomo.ps1"
    $scriptContent | Out-File $scriptPath -Force
    
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogon
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    Register-ScheduledTask -TaskName $TASK_NAME -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force
    
    Write-Host "✓ Service installed successfully"
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
    Write-Host "✓ Subscription added successfully."
    Update-Config
}

# 显示订阅
function Show-Subscription {
    if (Test-Path $SUBSCRIPTION_FILE) {
        Write-Host "Current subscription URL:"
        Get-Content $SUBSCRIPTION_FILE
    }
    else {
        Write-Host "Notice: No subscription URL found."
    }
}

# 更新配置
function Update-Config {
    Write-Host "Updating configuration..."
    
    if (Test-Path $SUBSCRIPTION_FILE) {
        $url = Get-Content $SUBSCRIPTION_FILE
        try {
            Invoke-WebRequest -Uri $url -OutFile $CONFIG_FILE
            Restart-MihomoService
            Write-Host "✓ Configuration updated successfully."
        }
        catch {
            Write-Host "Error: Configuration update failed. Please check the subscription URL."
        }
    }
    else {
        Write-Host "Error: No valid subscription URL found."
    }
}

# 启动服务
function Start-MihomoService {
    Start-ScheduledTask -TaskName $TASK_NAME
    Write-Host "✓ Service started."
    Write-Host "➜ Dashboard URL: http://127.0.0.1:9090/ui"
}

# 停止服务
function Stop-MihomoService {
    Stop-ScheduledTask -TaskName $TASK_NAME
    Get-Process | Where-Object { $_.Path -eq $MIHOMO_EXE } | Stop-Process -Force
    Write-Host "✓ Service stopped."
}

# 重启服务
function Restart-MihomoService {
    Stop-MihomoService
    Start-Sleep -Seconds 2
    Start-MihomoService
}

# 显示状态
function Show-Status {
    $task = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host "Task Status: $($task.State)"
        $process = Get-Process | Where-Object { $_.Path -eq $MIHOMO_EXE }
        if ($process) {
            Write-Host "Process Status: Running (PID: $($process.Id))"
        }
        else {
            Write-Host "Process Status: Not running"
        }
    }
    else {
        Write-Host "Service not installed"
    }
}

# 显示帮助
function Show-Help {
    Write-Host @"
Usage: .\mihomo-manager.ps1 [command]
Commands:
    install     Install the service
    start       Start the service
    stop        Stop the service
    restart     Restart the service
    status      Show service status
    add-sub     Add subscription URL
    show-sub    Show current subscription
    update      Update configuration
    help        Show this help message
"@
}

# 主程序
if (-not (Test-Administrator)) {
    Write-Host "Please run as Administrator"
    exit 1
}

Initialize-Directories

switch ($args[0]) {
    "install" { Install-MihomoService }
    "start" { Start-MihomoService }
    "stop" { Stop-MihomoService }
    "restart" { Restart-MihomoService }
    "status" { Show-Status }
    "add-sub" { Add-Subscription $args[1] }
    "show-sub" { Show-Subscription }
    "update" { Update-Config }
    default { Show-Help }
}

# sing-box-service.ps1

$REAL_USER = $env:USERNAME
$INSTALL_DIR = "$env:ProgramFiles\sing-box"
$SINGBOX_CONFIG = Join-Path $INSTALL_DIR "config.json"
$SUBSCRIPTION_FILE = Join-Path $INSTALL_DIR "subscription.txt"
$bin = "sing-box.exe"
$SINGBOX_PATH = Join-Path $INSTALL_DIR $bin
$TASK_NAME = "sing-box"
$ScriptPath = "$INSTALL_DIR\sing-box-service.ps1"

$CommandPath = $MyInvocation.MyCommand.Path

function Install-script {
    if ($ScriptPath -ne $CommandPath) {

        if (!(Test-Path $INSTALL_DIR)) {
            New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
        }

        Copy-Item $CommandPath "$INSTALL_DIR\sing-box-service.ps1" -Force

        $aliasContent = "`nSet-Alias -Name sing-box-service -Value '$INSTALL_DIR\sing-box-service.ps1'"

        if (!(Test-Path $PROFILE)) {
            New-Item -Path $PROFILE -Force | Out-Null
        }
        Add-Content -Path $PROFILE -Value $aliasContent

        Write-Host "✅ Installed sing-box-service successfully."
        Write-Host "⚠️ Please restart your PowerShell to use the 'sing-box-service' command."
    }
}

# TODO: winget install
function Install-sing-box {
    try {

        Write-Host "Fetching latest version info..." -ForegroundColor Yellow
        $releaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/SagerNet/sing-box/releases"
        $version = $releaseInfo[0].tag_name

        $env:CGO_ENABLED = "0"
        $env:GOOS = $(go env GOHOSTOS)
        $env:GOARCH = $(go env GOHOSTARCH)
        $env:GOAMD64 = "v3"
        $env:GOMAXPROCS = (Get-WmiObject -Class Win32_ComputerSystem).NumberOfLogicalProcessors

        Write-Host "Installing sing-box $version..." -ForegroundColor Yellow

        $buildCmd = "go install -v " + `
            "-trimpath " + `
            "-tags 'with_quic,with_utls,with_reality_server,with_clash_api' " + `
            "-ldflags=`"-X 'github.com/sagernet/sing-box/constant.Version=$version' -s -w -buildid=`" " + `
            "github.com/sagernet/sing-box/cmd/sing-box@$version"

        $result = Invoke-Expression $buildCmd

        if ($LASTEXITCODE -ne 0) {
            throw "Installation failed with exit code $LASTEXITCODE"
        }

        $goBin = Join-Path (go env GOPATH) "bin"
        $sourcePath = Join-Path $goBin "sing-box.exe"

        if (!(Test-Path $sourcePath)) {
            throw "Cannot find sing-box.exe in GOPATH"
        }
        Stop-SingBoxService
        Copy-Item $sourcePath $INSTALL_DIR -Force
        Write-Host "🥳 sing-box $version installed successfully." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Installation failed: $_" -ForegroundColor Red
        return $false
    }
}


function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-Directories {
    if (!(Test-Path $INSTALL_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
        Write-Host "📁 Created configuration directory: $INSTALL_DIR"
    }

    if (!(Test-Path $SUBSCRIPTION_FILE)) {
        New-Item -ItemType File -Path $SUBSCRIPTION_FILE -Force | Out-Null
        Write-Host "📁 Created subscription file: $SUBSCRIPTION_FILE"
    }
}

function Install-sing-boxService {
    # Hide window https://www.reddit.com/r/PowerShell/comments/1cxeirf/how_do_you_completely_hide_the_powershell/
    $startScript = Join-Path $INSTALL_DIR "start-singbox.ps1"
    @"
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
`$console = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow(`$console, 0)

Set-Location "$INSTALL_DIR"
& "$SINGBOX_PATH" tools synctime -w -C "$INSTALL_DIR"
& "$SINGBOX_PATH" run -C "$INSTALL_DIR"
"@ | Out-File -FilePath $startScript -Force

    # ScheduledTaskAction
    $action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-ExecutionPolicy Bypass -File `"$startScript`""
    $trigger = New-ScheduledTaskTrigger -AtLogon
    $principal = New-ScheduledTaskPrincipal -UserId $REAL_USER -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    Register-ScheduledTask -TaskName $TASK_NAME -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force
    Write-Host "⌛ Service created successfully."
}


function Add-Subscription {
    param([string]$url)
    if ([string]::IsNullOrEmpty($url)) {
        Write-Host "❌ Please provide a subscription URL."
        return
    }

    if ($url -notmatch '^https?://') {
        Write-Host "❌ Invalid URL format."
        return
    }

    $url | Out-File $SUBSCRIPTION_FILE -Force
    Write-Host "📁 Subscription added successfully."
    Update-Config
}

function Show-Subscription {
    if (Test-Path $SUBSCRIPTION_FILE) {
        if ((Get-Item $SUBSCRIPTION_FILE).Length -gt 0) {
            Write-Host "🔗 Current subscription URL:"
            Get-Content $SUBSCRIPTION_FILE
        }
        else {
            Write-Host "❌ No subscription URL found."
        }
    }
}

function Update-SingBox {
    Write-Host "Updating sing-box using winget..."
    winget upgrade sing-box
}

function Test-SingBox {
    if (Test-Path -Path $SINGBOX_PATH) {
        Write-Host "✅ sing-box is found."
    }
    else {
        Write-Host "💢 sing-box not found. Installing..."
        if (!(Install-sing-box)) {
            Write-Host "❌ Failed to install sing-box."
            exit 1
        }
    }
}


function Disable-Autostart {
    Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false
    Write-Host "✋ Autostart disabled."
}

function Restart-SingBoxService {
    $taskExists = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    if (-not $taskExists) {
        Write-Host "⌛ Creating service..."
        Install-sing-boxService
    }
    else {
        Stop-SingBoxService
    }
    Start-Sleep -Seconds 2
    Start-SingBoxService
}
function Stop-SingBoxService {
    $taskExists = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    if ($taskExists) {
        Stop-ScheduledTask -TaskName $TASK_NAME
    }
    Get-Process | Where-Object { $_.ProcessName -eq 'sing-box' } | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "✋ Service stopped."
}

function Start-SingBoxService {
    $taskExists = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    if (-not $taskExists) {
        Write-Host "⌛ Creating service..."
        Install-sing-boxService
    }
    Start-ScheduledTask -TaskName $TASK_NAME
    Write-Host "✅ Service started."
}

function Update-Config {
    if (Test-Path $SUBSCRIPTION_FILE) {
        $url = Get-Content $SUBSCRIPTION_FILE
        Write-Host "⌛ Update Configuration from $url"
        try {
            Invoke-WebRequest -Uri $url -OutFile $SINGBOX_CONFIG
            if (Test-Path $SINGBOX_CONFIG) {
                Write-Host "✅ Configuration downloaded successfully."
                Restart-SingBoxService
            }
            else {
                Write-Host "❌ Failed to save configuration file."
            }
        }
        catch {
            Write-Host "❌ Configuration update failed. Please check the subscription URL."
            Write-Host "Error details: $_"
        }
    }
    else {
        Write-Host "❌ No valid subscription URL found."
    }
}

function Get-SingBoxStatus {
    $task = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
    if ($task) {
        $process = Get-Process | Where-Object { $_.Path -eq $SINGBOX_PATH }
        if ($process) {
            Write-Host "🏃 Service status: $($task.State) (PID: $($process.Id))"
        }
        else {
            Write-Host "⚠️ Service status: Not running"
        }
    }
    else {
        Write-Host "❌ Service not installed"
    }
}

if (-not (Test-Administrator)) {
    Write-Host "⚠️ This script must be run as Administrator."
    exit 1
}

function Show-Help {
    Write-Host @"
Usage: $($MyInvocation.MyCommand.Name) [command] [arguments]
Commands:
  install         install latest version sing-box
  start           Start the service and enable autostart
  stop            Stop the service
  restart         Restart the service
  status          Check service status
  disable         Disable autostart
  add-sub [URL]   Add a subscription URL
  show-sub        Display the current subscription URL
  update          Update the configuration
  help            Display this help information
"@
}


Initialize-Directories
Install-script
Test-SingBox

switch ($args[0]) {
    "install"{
        Install-sing-box
    }
    "start" {
        Install-sing-boxService
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
    default {
        Show-Help
    }
}

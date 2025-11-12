param(
    [Parameter(Mandatory=$true)]
    [string]$url,

    [Parameter(Mandatory=$false)]
    [switch]$KeepTemp  # 添加可选参数-KeepTemp，保留临时文件
)


# 创建临时目录
$tempDir = Join-Path $PSScriptRoot "temp"
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}

# 切换到临时目录
Push-Location $tempDir


yt-dlp --cookies-from-browser firefox `
  --restrict-filenames `
  -t mp4 `
  --write-auto-subs `
  --sub-langs "zh-Hans,en" `
  --convert-subs srt `
  -k `
  $url



# 获取最新的 mp4 文件
$video = Get-ChildItem *.mp4 | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$base = $video.BaseName

$topMargin = 22    # 固定上边距，英文字幕
$bottomMargin = 0  # 固定下边距，中文字幕

ffmpeg -i "$base.mp4" `
-vf "subtitles='${base}.en.srt':force_style='FontName=Arial,FontSize=10,Bold=0.5,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,Outline=0.5,Alignment=2,MarginV=${topMargin},MaxWidth=0',subtitles='${base}.zh-Hans.srt':force_style='FontName=Microsoft YaHei,FontSize=10,Bold=0.5,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,Outline=0.5,Alignment=2,MarginV=${bottomMargin},MaxWidth=0'"  `
-c:a copy "${base}_bilingual.mp4"

$outputFile = "${base}_bilingual.mp4"
$sourcePath = Join-Path $tempDir $outputFile
$finalPath = Join-Path $PSScriptRoot $outputFile

Move-Item -LiteralPath $sourcePath -Destination $finalPath -Force

# 返回原目录
Pop-Location

# 清理临时目录
if (-not $KeepTemp) {
    Remove-Item $tempDir -Recurse -Force
    Write-Host "完成！输出：$finalPath" -ForegroundColor Green
    Write-Host "临时文件已清理" -ForegroundColor Gray
} else {
    Write-Host "完成！输出：$finalPath" -ForegroundColor Green
    Write-Host "临时文件保留在：$tempDir" -ForegroundColor Yellow
}
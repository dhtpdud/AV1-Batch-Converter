@echo off
setlocal
rem Converts every video in a folder and its subfolders to AV1. Videos that are already AV1 are skipped.
rem Uses NVENC first. If it is not available, falls back to Intel QSV, AMD AMF, then CPU (SVT-AV1).
rem Keeps the original extension, except mov, m4v, ts, mts, m2ts, mpg and mpeg, which cannot hold AV1 and become .mp4.
rem Keeping originals: results go to an av1\ folder inside each folder. Deleting originals: results replace them in place.
rem If a result is larger than the original, the result is thrown away and the original is kept.
rem Videos of 1 minute or longer get a 10-second trial encode from the middle, and are skipped if little would be saved.
rem Usage: drag a folder onto this file, or run it and type a path. Several windows can run at the same time.

rem Quality: lower means better quality and larger files (0-63)
set CQ=30
rem How many files to check for AV1 at once. Raising it helps most on slow storage such as rclone mounts.
set JOBS=8
rem Skip a video if the trial encode predicts a saving below this many percent
set MIN_SAVE=10
rem Path used to read the PowerShell code at the end of this file, and by that code to run this file again
set "BATF=%~f0"

rem PowerShell runs this file again with /convert-one for each video. The path arrives in the environment variable SRC.
if "%~1"=="/convert-one" goto convert_one

where ffmpeg >nul 2>&1 || (echo [error] ffmpeg was not found. & pause & exit /b 1)
where ffprobe >nul 2>&1 || (echo [error] ffprobe was not found. & pause & exit /b 1)

rem Try a real encode in order of speed and use the first one that works.
rem An encoder can be built into ffmpeg and still fail if the graphics card does not support it.
rem All of them take 4:2:0 only, so 4:2:2 and 4:4:4 are converted to 4:2:0. 10-bit stays 10-bit, and 4:2:0 passes through untouched.
rem split_encode_mode 2: two NVENC engines share each frame. Preset p5 does not enable this on its own. 8K went from 31 to 55 fps with almost no change in size or quality.
set HWACCEL=-hwaccel cuda
set "ENCNAME=NVIDIA NVENC, 2 engines"
set VOPT=-vf "format=nv12|yuv420p|p010le" -c:v av1_nvenc -preset p5 -split_encode_mode 2 -rc vbr -cq %CQ% -b:v 0
call :try_encoder && goto encoder_ok
set "ENCNAME=NVIDIA NVENC"
set VOPT=-vf "format=nv12|yuv420p|p010le" -c:v av1_nvenc -preset p5 -rc vbr -cq %CQ% -b:v 0
call :try_encoder && goto encoder_ok

rem Without NVENC, CUDA decoding may be missing too, so let ffmpeg pick a decoder. It falls back to the CPU if there is none.
set HWACCEL=-hwaccel auto
set "ENCNAME=Intel Quick Sync"
set VOPT=-vf "format=nv12|p010le" -c:v av1_qsv -preset medium -global_quality %CQ%
call :try_encoder && goto encoder_ok
rem AMF qp runs from 0 to 255, so CQ (0-63) is multiplied by 4
set /a QP=CQ*4
set "ENCNAME=AMD AMF"
set VOPT=-vf "format=nv12|yuv420p|p010le" -c:v av1_amf -quality balanced -rc cqp -qp_i %QP% -qp_p %QP% -qp_b %QP%
call :try_encoder && goto encoder_ok
rem Fastest software encoder measured at 1080p: SVT-AV1 518 fps, libaom 173 fps, rav1e 5 fps. Preset 10 is about as fast as 12 with better quality.
set "ENCNAME=CPU SVT-AV1, no GPU encoder is available, this can be much slower"
set VOPT=-vf "format=yuv420p|yuv420p10le" -c:v libsvtav1 -preset 10 -crf %CQ%
call :try_encoder && goto encoder_ok
echo [error] No usable AV1 encoder was found.
pause
exit /b 1
:encoder_ok
echo Encoder: %ENCNAME%

rem Trial encodes go to a local temp folder, not the video folder, which may be an rclone mount. Each run gets its own folder.
rem RANDOM gives the same value to windows started in the same second, so keep drawing until mkdir claims an unused name.
if not exist "%TEMP%\convert_av1" mkdir "%TEMP%\convert_av1"
:mktmp
set "TMPD=%TEMP%\convert_av1\%RANDOM%"
mkdir "%TMPD%" 2>nul || goto mktmp

set "TARGET=%~1"
if defined TARGET goto check
:ask
set "TARGET="
set /p "TARGET=Folder to convert (you can drag a folder into this window): "
if not defined TARGET (echo [error] No path was entered. & pause & exit /b 1)
:check
rem Remove the quotes a dragged path comes with
set "TARGET=%TARGET:"=%"
cd /d "%TARGET%" 2>nul || (echo [error] Folder not found: "%TARGET%" & goto ask)
echo Target folder: "%CD%"

rem Only originals converted successfully in this run are deleted. Failed and skipped files stay. del does not use the Recycle Bin.
set DEL_ORIGINAL=N
echo Y = delete originals, results are saved in their place (permanent)
echo N = keep originals, results are saved in an av1 folder inside each folder
choice /c YN /n /m "Delete originals after a successful conversion? [Y/N]: "
if not errorlevel 2 set DEL_ORIGINAL=Y
set SUB=av1\
if "%DEL_ORIGINAL%"=="Y" set SUB=

rem The PowerShell code at the end of this file finds the files, checks for AV1 and decides the order.
rem Keeping the list in batch variables stalls for tens of minutes with tens of thousands of files, because every set copies the whole environment.
set "ROOT=%CD%"
powershell -NoProfile -Command "iex (([IO.File]::ReadAllText($env:BATF) -split ('#'+'PS'+'#'))[1])"
if errorlevel 1 echo [error] Stopped because of an error. Run this again to continue with the remaining files.
rd /s /q "%TMPD%" 2>nul

echo Done.
pause
exit /b

:try_encoder
ffmpeg -v quiet -f lavfi -i testsrc2=size=1920x1080:rate=30 -frames:v 10 %VOPT% -f null NUL
exit /b %errorlevel%

:convert_one
rem The path arrives through the environment and is always quoted, so percent signs, ampersands and exclamation marks in names are safe
for %%i in ("%SRC%") do (set "DIR=%%~dpi" & set "NAME=%%~ni" & set "EXT=%%~xi")

set "OUTX=%EXT%"
for %%e in (.mov .m4v .ts .mts .m2ts .mpg .mpeg) do if /i "%EXT%"=="%%e" set OUTX=.mp4
set "OUT=%DIR%%SUB%%NAME%%OUTX%"
rem Write to .part and rename only on success, so an interrupted file never looks finished. ffmpeg picks the container from the last extension.
set "PART=%DIR%%SUB%%NAME%.part%OUTX%"

rem Never overwrite an existing result of the same name. The original itself is the exception when deleting originals.
if exist "%OUT%" if /i not "%OUT%"=="%SRC%" (echo [skip] Result "%OUT%" already exists: "%SRC%" & exit /b)

rem Compare a straight copy of the middle 10 seconds with an AV1 encode of it, to see if there is anything to gain
rem Under 1 minute, or if the trial fails, convert without checking. The size check after conversion still applies.
set PCT=
set DUR=
ffprobe -v error -show_entries format=duration -of csv=p=0 "%SRC%" > "%TMPD%\dur.txt" 2>nul
set /p DUR=<"%TMPD%\dur.txt"
for /f "delims=." %%d in ("%DUR%") do set "DUR=%%d"
set /a DUR=DUR 2>nul
if %DUR% LSS 60 goto encode
set /a SS=DUR/2-5
echo [check] Estimating the saving: "%SRC%"
del "%TMPD%\s_src.mkv" "%TMPD%\s_av1.mkv" 2>nul
ffmpeg -v quiet -ss %SS% -i "%SRC%" -t 10 -map 0:v:0 -c copy -y "%TMPD%\s_src.mkv"
ffmpeg -v quiet %HWACCEL% -ss %SS% -i "%SRC%" -t 10 -map 0:v:0 %VOPT% -y "%TMPD%\s_av1.mkv"
set SSZ=0
set ESZ=0
for %%a in ("%TMPD%\s_src.mkv") do if exist %%a set SSZ=%%~za
for %%a in ("%TMPD%\s_av1.mkv") do if exist %%a set ESZ=%%~za
del "%TMPD%\s_src.mkv" "%TMPD%\s_av1.mkv" 2>nul
if %SSZ% LSS 10000 goto encode
if %ESZ% EQU 0 goto encode
rem Ten seconds stays under 2 GB, so set /a is safe here. Dividing first avoids overflow.
set /a PCT=ESZ/(SSZ/100)
if %PCT% GTR 100 (
  echo [skip] Would get larger, estimated %PCT%%% of the original: "%SRC%"
  exit /b
)
set /a KEEP=100-MIN_SAVE
if %PCT% GTR %KEEP% (
  echo [skip] Little to gain, estimated %PCT%%% of the original: "%SRC%"
  exit /b
)

:encode
if defined PCT (echo [convert] Estimated %PCT%%% of the original: "%SRC%") else (echo [convert] "%SRC%")
if not exist "%DIR%%SUB%" mkdir "%DIR%%SUB%"

rem For .mp4 output, copy only audio that plays widely in mp4. Anything else, such as PCM, is encoded to AAC.
set ACOPY=1
if /i "%OUTX%"==".mp4" (
  ffprobe -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 "%SRC%" 2>nul | findstr /v /x /i "aac mp3 ac3 eac3 opus flac alac" >nul && set ACOPY=
)

rem ffmpeg returns negative codes on failure, which if errorlevel 1 misses, so OK is set only on exit code 0
set OK=
if defined ACOPY (ffmpeg -hide_banner -loglevel warning -stats %HWACCEL% -i "%SRC%" -map 0:v:0 -map 0:a? %VOPT% -c:a copy -y "%PART%" && set OK=1)
rem If copying the audio failed, try once more with AAC
if not defined OK (
  echo [AAC audio] "%SRC%"
  ffmpeg -hide_banner -loglevel warning -stats %HWACCEL% -i "%SRC%" -map 0:v:0 -map 0:a? %VOPT% -c:a aac -b:a 192k -y "%PART%" && set OK=1
)
if not defined OK (
  echo [failed] "%SRC%"
  del "%PART%" 2>nul
  exit /b
)

rem A result that is not smaller is pointless, so throw it away and keep the original
rem Numeric comparison in if goes wrong above 2 GB, so compare 20-digit zero-padded strings
for %%a in ("%PART%") do set "PSIZE=00000000000000000000%%~za"
for %%a in ("%SRC%") do set "SSIZE=00000000000000000000%%~za"
if "%PSIZE:~-20%" GEQ "%SSIZE:~-20%" (
  echo [skip] Result is not smaller, original kept: "%SRC%"
  del "%PART%"
  exit /b
)

move /y "%PART%" "%OUT%" >nul || exit /b
if not "%DEL_ORIGINAL%"=="Y" exit /b
if /i "%OUT%"=="%SRC%" (echo [replaced] "%SRC%") else (del "%SRC%" && echo [deleted original] "%SRC%")
exit /b

rem Below is PowerShell code, which batch never executes directly
#PS#
# Stop at the first error, so that no file is converted without having been checked
$ErrorActionPreference = 'Stop'
$ext = '.mp4', '.mkv', '.mov', '.avi', '.wmv', '.flv', '.webm', '.m4v', '.ts', '.mts', '.m2ts', '.mpg', '.mpeg'

# 1) Find videos, including subfolders. Inaccessible folders (System Volume Information etc.) and junctions or symlinks are skipped.
$files = New-Object Collections.Generic.List[string]
$dirs = New-Object Collections.Stack
$dirs.Push($env:ROOT)
while ($dirs.Count) {
  $d = $dirs.Pop()
  try {
    foreach ($f in [IO.Directory]::GetFiles($d)) { if ($ext -contains [IO.Path]::GetExtension($f)) { $files.Add($f) } }
    foreach ($s in [IO.Directory]::GetDirectories($d)) { if (-not ([IO.File]::GetAttributes($s) -band [IO.FileAttributes]::ReparsePoint)) { $dirs.Push($s) } }
  } catch {}
  [Console]::Error.Write("`rFinding videos: $($files.Count) ")
}
$files.Sort([StringComparer]::OrdinalIgnoreCase)
$n = $files.Count
[Console]::Error.WriteLine()

# 2) Check and convert at the same time
#  - Check: run up to JOBS ffprobe processes at once, and queue every file that is not AV1 as its result arrives.
#    By default ffprobe reads up to 5 MB per file, which makes the head of a hard disk thrash, so read only enough for the codec name.
#  - Convert: take files from the queue one at a time and run :convert_one in this file, passing the path in SRC so that special characters and emoji survive.
#  - Display: progress of the check goes to the window title so it does not mix with ffmpeg's output, and files already in AV1 are only counted.
[Console]::Out.WriteLine("Checking and converting together: $n files (checking $($env:JOBS) at a time, progress is in the window title)")
$jobs = [int]$env:JOBS
$run = New-Object Collections.ArrayList
$todo = New-Object Collections.Queue
$i = 0; $done = 0; $av1 = 0; $k = 0; $conv = $null; $line = $false
try {
  while ($done -lt $n -or $todo.Count -or $conv) {
    $busy = $false
    while ($i -lt $n -and $run.Count -lt $jobs) {
      $si = New-Object Diagnostics.ProcessStartInfo 'ffprobe', ('-v quiet -probesize 32 -analyzeduration 0 -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "' + $files[$i] + '"')
      $si.UseShellExecute = $false; $si.RedirectStandardOutput = $true
      [void]$run.Add(@($files[$i], [Diagnostics.Process]::Start($si))); $i++; $busy = $true
    }
    # The output is a single line and cannot fill the pipe, so it is safe to wait for exit before reading it
    for ($j = $run.Count - 1; $j -ge 0; $j--) {
      if ($run[$j][1].HasExited) {
        if ($run[$j][1].StandardOutput.ReadToEnd().Trim() -eq 'av1') { $av1++ } else { $todo.Enqueue($run[$j][0]) }
        $run.RemoveAt($j); $done++; $busy = $true
      }
    }
    if ($conv -and $conv.HasExited) { $conv = $null }
    if (-not $conv -and $todo.Count) {
      if ($line) { [Console]::Error.WriteLine(); $line = $false }
      $k++
      [Console]::Out.Write("[#$k | checked $done/$n] ")
      $si = New-Object Diagnostics.ProcessStartInfo $env:ComSpec, '/c ""%BATF%" /convert-one"'
      $si.UseShellExecute = $false
      $si.EnvironmentVariables['SRC'] = $todo.Dequeue()
      $conv = [Diagnostics.Process]::Start($si)
    }
    try { [Console]::Title = "AV1 checked $done/$n | already AV1 $av1 | converting #$k | queued $($todo.Count)" } catch {}
    # Show progress on one line while nothing is converting, so the window does not look frozen
    if (-not $conv -and $done -lt $n) { [Console]::Error.Write("`rChecked: $done/$n "); $line = $true }
    if (-not $busy) { Start-Sleep -Milliseconds 20 }
  }
} finally {
  # On an error or Ctrl+C, wait for the running conversion so it is not left alone in the window
  if ($conv) { $conv.WaitForExit() }
}
if ($line) { [Console]::Error.WriteLine() }
[Console]::Out.WriteLine("Check finished: $n files, $av1 already AV1 and skipped, $k conversions attempted")

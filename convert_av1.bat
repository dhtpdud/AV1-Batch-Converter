@echo off
setlocal
rem Converts every video in a folder and its subfolders to AV1. Videos that are already AV1 are skipped.
rem Uses NVENC first. If it is not available, falls back to Intel QSV, AMD AMF, then CPU (SVT-AV1).
rem Keeps the original extension, except mov, m4v, ts, mts, m2ts, mpg and mpeg, which cannot hold AV1 and become .mp4.
rem Only the main video track is encoded. Other tracks, chapters, tags and file dates are kept. A video that cannot keep them is left alone.
rem For HDR10+, Dolby Vision profile 7 and transparency, the user chooses at the start what happens instead.
rem Keeping originals: results go to an av1\ folder inside each folder. Deleting originals: results replace them in place.
rem If a result is larger than the original, the result is thrown away and the original is kept.
rem Videos of 1 minute or longer get a 10-second trial encode from the middle, and are skipped if little would be saved.
rem Results are recorded in a log, and videos in the log are skipped at once on the next run, so a stopped run continues where it left off.
rem Usage: drag a folder onto this file, or run it and type a path. Several windows can run at the same time.

rem Quality: lower means better quality and larger files (0-63)
set CQ=30
rem How many files to check for AV1 at once. Raising it helps most on slow storage such as rclone mounts.
set JOBS=8
rem Skip a video if the trial encode predicts a saving below this many percent
set MIN_SAVE=10
rem Results are recorded here. Delete this file to check every video again.
set "LOG=%~dp0convert_av1.log"
rem Path used to read the PowerShell code at the end of this file, and by that code to run this file again
set "BATF=%~f0"

rem PowerShell runs this file again with /convert-one for each video. The path arrives in the environment variable SRC.
if "%~1"=="/convert-one" goto convert_one

where ffmpeg >nul 2>&1 || (echo [error] ffmpeg was not found. & pause & exit /b 1)
where ffprobe >nul 2>&1 || (echo [error] ffprobe was not found. & pause & exit /b 1)

rem Try a real encode in order of speed and use the first one that works.
rem An encoder can be built into ffmpeg and still fail if the graphics card does not support it.
rem All of them take 4:2:0 only. 10-bit stays 10-bit, and 4:2:0 passes through untouched. Videos with other color are left alone.
rem split_encode_mode 2: two NVENC engines share each frame. Preset p5 does not enable this on its own. 8K went from 31 to 55 fps with almost no change in size or quality.
set HWACCEL=-hwaccel cuda
set "ENCNAME=NVIDIA NVENC, 2 engines"
set "VF=format=nv12|yuv420p|p010le"
set ENC=av1_nvenc -preset p5 -split_encode_mode 2 -rc vbr -cq %CQ% -b:v 0
call :try_encoder && goto encoder_ok
set "ENCNAME=NVIDIA NVENC"
set ENC=av1_nvenc -preset p5 -rc vbr -cq %CQ% -b:v 0
call :try_encoder && goto encoder_ok

rem Without NVENC, CUDA decoding may be missing too, so let ffmpeg pick a decoder. It falls back to the CPU if there is none.
set HWACCEL=-hwaccel auto
set "ENCNAME=Intel Quick Sync"
set "VF=format=nv12|p010le"
set ENC=av1_qsv -preset medium -global_quality %CQ%
call :try_encoder && goto encoder_ok
rem AMF qp runs from 0 to 255, so CQ (0-63) is multiplied by 4
set /a QP=CQ*4
set "ENCNAME=AMD AMF"
set "VF=format=nv12|yuv420p|p010le"
set ENC=av1_amf -quality balanced -rc cqp -qp_i %QP% -qp_p %QP% -qp_b %QP%
call :try_encoder && goto encoder_ok
rem Fastest software encoder measured at 1080p: SVT-AV1 518 fps, libaom 173 fps, rav1e 5 fps. Preset 10 is about as fast as 12 with better quality.
set "ENCNAME=CPU SVT-AV1, no GPU encoder is available, this can be much slower"
set "VF=format=yuv420p|yuv420p10le"
set ENC=libsvtav1 -preset 10 -crf %CQ%
call :try_encoder && goto encoder_ok
echo [error] No usable AV1 encoder was found.
pause
exit /b 1
:encoder_ok
echo Encoder: %ENCNAME%

rem NVENC drops Dolby Vision and SVT-AV1 keeps it, so those videos go to SVT-AV1 whatever the encoder above is
set SVT=libsvtav1 -preset 10 -crf %CQ% -dolbyvision 1
ffmpeg -nostdin -v quiet -f lavfi -i testsrc2=size=320x180:rate=30 -frames:v 2 -c:v libsvtav1 -preset 12 -f null NUL || set SVT=

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
rem Ctrl+C makes choice return 0, which must not mean delete
if errorlevel 1 if not errorlevel 2 set DEL_ORIGINAL=Y
if errorlevel 3 set NO_KEYS=1
set SUB=av1\
if "%DEL_ORIGINAL%"=="Y" set SUB=

rem Some things cannot be kept in AV1, so ask before starting what should happen to such videos
call :ask_loss "HDR10+ and Dolby Vision profile 7 are not kept when converting to AV1."
set ON_HDR=%errorlevel%
call :ask_loss "Transparency is not kept when converting to AV1."
set ON_ALPHA=%errorlevel%

rem The PowerShell code at the end of this file finds the files, checks for AV1 and decides the order.
rem Keeping the list in batch variables stalls for tens of minutes with tens of thousands of files, because every set copies the whole environment.
set "ROOT=%CD%"
powershell -NoProfile -Command "iex (([IO.File]::ReadAllText($env:BATF) -split ('#'+'PS'+'#'))[1])"
if errorlevel 1 echo [error] Stopped because of an error. Run this again to continue with the remaining files.
rd /s /q "%TMPD%" 2>nul

echo Done.
pause
exit /b

:ask_loss
if defined NO_KEYS exit /b 1
echo.
echo %~1
echo 1 = skip such videos
echo 2 = convert them anyway
if not "%DEL_ORIGINAL%"=="Y" (
  choice /c 12 /n /m "What should happen to such videos? [1/2]: "
) else (
  echo 3 = keep the original and save the result in an av1 folder
  choice /c 123 /n /m "What should happen to such videos? [1/2/3]: "
)
rem Without a keyboard choice fails, and a second try hangs, so skip such videos and stop asking
if errorlevel 4 (set NO_KEYS=1 & exit /b 1)
rem Ctrl+C makes choice return 0, which must not mean convert
if not errorlevel 1 exit /b 1
exit /b %errorlevel%

:try_encoder
ffmpeg -nostdin -v quiet -f lavfi -i testsrc2=size=1920x1080:rate=30 -frames:v 10 -vf "%VF%" -c:v %ENC% -f null NUL
exit /b %errorlevel%

:convert_one
rem The exit code tells the PowerShell code at the end of this file what to record in the log:
rem 10 converted, 11 and 12 converted and the extension became .mp4 and .mkv, 13-15 the same with the original kept by choice,
rem 20-29 and 31 skipped, 30 failed
rem The path arrives through the environment and is always quoted, so percent signs, ampersands and exclamation marks in names are safe
for %%i in ("%SRC%") do (set "DIR=%%~dpi" & set "NAME=%%~ni" & set "EXT=%%~xi")

set "OUTX=%EXT%"
for %%e in (.mov .m4v .ts .mts .m2ts .mpg .mpeg) do if /i "%EXT%"=="%%e" set OUTX=.mp4
set "OUT=%DIR%%SUB%%NAME%%OUTX%"
rem Never overwrite an existing result of the same name. The original itself is the exception when deleting originals.
if exist "%OUT%" if /i not "%OUT%"=="%SRC%" (echo [skip] Result "%OUT%" already exists: "%SRC%" & exit /b 20)

rem The main video track is the first one that is not cover art. It is the only track that is encoded.
set VN=-1
set PIXF=
set TRC=
ffprobe -v error -select_streams v -show_entries stream=pix_fmt,color_transfer:stream_disposition=attached_pic -of csv=p=0 "%SRC%" > "%TMPD%\v.txt" 2>nul
for /f "usebackq tokens=1-3 delims=," %%a in ("%TMPD%\v.txt") do (
  set /a VN+=1
  if "%%c"=="0" (set "PIXF=%%a" & set "TRC=%%b" & goto main_found)
)
set VN=0
:main_found

ffprobe -v error -select_streams v:%VN% -show_entries stream_tags=alpha_mode:stream_side_data=side_data_type,dv_profile -of flat "%SRC%" > "%TMPD%\s.txt" 2>nul

rem AV1 here has no transparency. VP8 and VP9 keep it outside the pixel format. Converting anyway also reduces color to 4:2:0.
set ALPHA=
findstr /c:"alpha_mode=\"1\"" "%TMPD%\s.txt" >nul && set ALPHA=1
if defined PIXF echo %PIXF%| findstr /r /i "^yuva ^rgba ^bgra ^argb ^abgr ^gbrap ^ya" >nul && set ALPHA=1
if not defined ALPHA goto alpha_ok
if %ON_ALPHA%==1 (echo [skip] AV1 cannot keep transparency: "%SRC%" & exit /b 31)
if %ON_ALPHA%==3 call :keep_original
goto color_ok
:alpha_ok

rem Anything but 8 or 10-bit 4:2:0 would lose color on these encoders, so leave such a video alone.
rem libaom could keep it, but it is not used.
if not defined PIXF goto color_ok
echo %PIXF%| findstr /x /i "yuv420p yuvj420p yuv420p10le nv12 p010le gray gray10le" >nul && goto color_ok
echo [skip] AV1 encoding here would reduce this color format, %PIXF%: "%SRC%"
exit /b 24
:color_ok

findstr /c:"DOVI" "%TMPD%\s.txt" >nul || goto dovi_ok
rem Profile 7 has a second layer that ffmpeg does not decode, so it cannot be kept. Converting anyway uses the normal encoder.
findstr /c:"dv_profile=7" "%TMPD%\s.txt" >nul || goto dv_keep
if %ON_HDR%==1 (echo [skip] Dolby Vision profile 7 has a layer that would be lost: "%SRC%" & exit /b 27)
if %ON_HDR%==3 call :keep_original
goto dovi_ok
:dv_keep
if not defined SVT (
  echo [skip] Keeping Dolby Vision needs SVT-AV1, which this ffmpeg does not have: "%SRC%"
  exit /b 27
)
set "VF=format=yuv420p|yuv420p10le"
set "ENC=%SVT%"
:dovi_ok

rem No encoder here keeps HDR10+, and only NVENC keeps captions inside the video. Both show in the first frames.
set FRAMES=
if /i "%TRC%"=="smpte2084" set FRAMES=1
if "%ENC:av1_nvenc=%"=="%ENC%" set FRAMES=1
if not defined FRAMES goto frames_ok
ffprobe -v error -select_streams v:%VN% -read_intervals "%%+#5" -show_entries frame_side_data=side_data_type -of csv=p=0 "%SRC%" > "%TMPD%\f.txt" 2>nul
findstr /c:"HDR10+" "%TMPD%\f.txt" >nul || goto hdr_ok
if %ON_HDR%==1 (echo [skip] No encoder here can keep HDR10+: "%SRC%" & exit /b 28)
if %ON_HDR%==3 call :keep_original
:hdr_ok
if "%ENC:av1_nvenc=%"=="%ENC%" findstr /c:"Closed Captions" "%TMPD%\f.txt" >nul && (
  echo [skip] Only NVENC can keep captions inside the video: "%SRC%"
  exit /b 29
)
:frames_ok

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
ffmpeg -nostdin -v quiet -ss %SS% -i "%SRC%" -t 10 -map 0:v:%VN% -c copy -y "%TMPD%\s_src.mkv"
ffmpeg -nostdin -v quiet %HWACCEL% -ss %SS% -i "%SRC%" -t 10 -map 0:v:%VN% -vf "%VF%" -c:v %ENC% -y "%TMPD%\s_av1.mkv"
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
  exit /b 21
)
set /a KEEP=100-MIN_SAVE
if %PCT% GTR %KEEP% (
  echo [skip] Little to gain, estimated %PCT%%% of the original: "%SRC%"
  exit /b 22
)

:encode
if defined PCT (echo [convert] Estimated %PCT%%% of the original: "%SRC%") else (echo [convert] "%SRC%")
if not exist "%DIR%%SUB%" mkdir "%DIR%%SUB%"

rem For .mp4 output, copy only audio that plays widely in mp4. Anything else, such as PCM, is encoded to AAC.
set "AAC=-c:a aac -b:a 192k"
set "AC=-c:a copy"
if /i "%OUTX%"==".mp4" (
  ffprobe -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 "%SRC%" 2>nul | findstr /v /x /i "aac mp3 ac3 eac3 opus flac alac" >nul && set "AC=%AAC%"
)

rem mp4 drops tags it does not know, such as the camera model. It can write them all, but then Explorer cannot read the title and the cover art is lost,
rem so do that only for a video with such tags and no cover art.
set MOVF=
if /i not "%OUTX%"==".mp4" goto movf_ok
findstr /r "^[^,]*,[^,]*,1" "%TMPD%\v.txt" >nul && goto movf_ok
ffprobe -v error -show_entries format_tags -of flat "%SRC%" 2>nul | findstr /v /i "tags.major_brand= tags.minor_version= tags.compatible_brands= tags.encoder= tags.creation_time= tags.title= tags.artist= tags.album_artist= tags.album= tags.composer= tags.comment= tags.genre= tags.date= tags.copyright= tags.description= tags.synopsis= tags.show= tags.episode_id= tags.episode_sort= tags.season_number= tags.network= tags.lyrics= tags.hd_video= tags.media_type= tags.track= tags.disc= tags.location= tags.location-eng= tags.gapless_playback= tags.compilation= tags.rating= tags.grouping= tags.keywords=" >nul && set MOVF=-movflags use_metadata_tags
:movf_ok

rem ffmpeg reads XMP from mp4 and mov but does not write it to mp4, so it is added afterwards as the box mp4 keeps it in
set XIN=
del "%TMPD%\xmp.txt" 2>nul
for %%e in (.mp4 .m4v .mov) do if /i "%EXT%"=="%%e" ffprobe -v error -export_xmp 1 -show_entries format_tags=xmp -of default=nk=1:nw=1 "%SRC%" > "%TMPD%\xmp.txt" 2>nul
if exist "%TMPD%\xmp.txt" for %%a in ("%TMPD%\xmp.txt") do if %%~za GTR 0 set XIN=-export_xmp 1

rem Timecode and chapter tracks are written again from the tags and chapters, and copying them would fail or add a second one
set MAPS=-map 0 -map -0:d?
ffprobe -v error -select_streams d -show_entries stream=codec_tag_string -of csv=p=0 "%SRC%" 2>nul | findstr /v /x /i "tmcd text" >nul && set MAPS=-map 0

rem Find a way to save everything by trying a moment of the video, before spending hours on all of it.
rem First with the audio decided above, then with AAC audio, then as .mkv, which holds subtitles and audio that mp4 cannot.
call :try_mux && goto mux_ok
set "AC=%AAC%"
call :try_mux && goto mux_ok
set "AC=-c:a copy"
set MOVF=
set OUTX=.mkv
call :try_mux && goto mux_ok
if "%MAPS%"=="-map 0" (
  echo [skip] Has a data track that cannot be kept: "%SRC%"
  exit /b 25
)
echo [failed] No way to keep every track: "%SRC%"
exit /b 30
:mux_ok

rem ffmpeg would turn cover art in mkv into a one-frame video track, so leave such a video alone
if /i not "%OUTX%"==".mkv" goto cover_ok
findstr /r "^[^,]*,[^,]*,1" "%TMPD%\v.txt" >nul || goto cover_ok
echo [skip] Has cover art that mkv would not keep as it is: "%SRC%"
exit /b 26
:cover_ok

set "OUT=%DIR%%SUB%%NAME%%OUTX%"
rem Write to .part and rename only on success, so an interrupted file never looks finished. ffmpeg picks the container from the last extension.
set "PART=%DIR%%SUB%%NAME%.part%OUTX%"
if exist "%OUT%" if /i not "%OUT%"=="%SRC%" (echo [skip] Result "%OUT%" already exists: "%SRC%" & exit /b 20)

rem ffmpeg returns negative codes on failure, which if errorlevel 1 misses, so OK is set only on exit code 0
rem -nostdin, here and everywhere else: key q would end ffmpeg with exit code 0, and a cut-off result would count as finished
set OK=
ffmpeg -nostdin -hide_banner -loglevel warning -stats %XIN% %HWACCEL% -i "%SRC%" %OPTS% -y "%PART%" && set OK=1
if not defined OK (
  echo [failed] "%SRC%"
  del "%PART%" 2>nul
  exit /b 30
)
rem ffprobe printed the XMP in text mode, so its line ends are put back first
if defined XIN if /i "%OUTX%"==".mp4" powershell -NoProfile -Command "$e=[Text.Encoding]::GetEncoding(28591);$x=$e.GetBytes($e.GetString([IO.File]::ReadAllBytes($env:TMPD+'\xmp.txt')).Replace([string][char]13+[char]10,[string][char]10).TrimEnd([char]10));$f=[IO.File]::Open($env:PART,'Append','Write');$h=[BitConverter]::GetBytes($x.Length+24);[Array]::Reverse($h);$f.Write($h,0,4);$u=[Text.Encoding]::ASCII.GetBytes('uuid')+[byte[]](0xBE,0x7A,0xCF,0xCB,0x97,0xA9,0x42,0xE8,0x9C,0x71,0x99,0x94,0x91,0xE3,0xAF,0xAC);$f.Write($u,0,20);$f.Write($x,0,$x.Length);$f.Close()" || (
  echo [failed] Could not add XMP: "%SRC%"
  del "%PART%" 2>nul
  exit /b 30
)

rem A result that is not smaller is pointless, so throw it away and keep the original
rem Numeric comparison in if goes wrong above 2 GB, so compare 20-digit zero-padded strings
for %%a in ("%PART%") do set "PSIZE=00000000000000000000%%~za"
for %%a in ("%SRC%") do set "SSIZE=00000000000000000000%%~za"
if "%PSIZE:~-20%" GEQ "%SSIZE:~-20%" (
  echo [skip] Result is not smaller, original kept: "%SRC%"
  del "%PART%"
  exit /b 23
)

move /y "%PART%" "%OUT%" >nul || exit /b 30
set RC=10
if /i not "%OUTX%"=="%EXT%" set RC=11
if /i "%RC%%OUTX%"=="11.mkv" set RC=12
if defined ORIG_KEPT set /a RC+=3
if not "%DEL_ORIGINAL%"=="Y" exit /b %RC%
if /i "%OUT%"=="%SRC%" (echo [replaced] "%SRC%") else (del "%SRC%" && echo [deleted original] "%SRC%")
exit /b %RC%

:keep_original
set ORIG_KEPT=1
set SUB=av1\
set DEL_ORIGINAL=N
exit /b

:try_mux
rem -map_metadata 0 is what keeps creation_time, which ffmpeg leaves out by default. mp4 writes VR metadata only with -strict unofficial.
set OPTS=%MAPS% -map_metadata 0 -strict unofficial -c copy -filter:v:%VN% "%VF%" -c:v:%VN% %ENC% %AC% %MOVF%
ffmpeg -nostdin -v quiet %XIN% %HWACCEL% -i "%SRC%" -t 0.1 %OPTS% -y "%TMPD%\mux%OUTX%"
exit /b %errorlevel%

rem Below is PowerShell code, which batch never executes directly
#PS#
# Stop at the first error, so that no file is converted without having been checked
$ErrorActionPreference = 'Stop'
$ext = '.mp4', '.mkv', '.mov', '.avi', '.wmv', '.flv', '.webm', '.m4v', '.ts', '.mts', '.m2ts', '.mpg', '.mpeg'

# 1) Read the log. Each line holds the time, result, settings, size, modified time and path of a video.
#    The last three identify the video, so a file that was replaced or edited is checked again.
#    Failed videos get another try, and a decision to skip only holds for the settings it was made with.
#    A video skipped because of a question at the start is checked again if the answer is different this time.
$set = "$($env:ENCNAME), CQ $($env:CQ), MIN_SAVE $($env:MIN_SAVE)"
$again = @()
if ($env:ON_HDR -ne '1') { $again += 'skip-hdr10plus', 'skip-dovi' }
if ($env:ON_ALPHA -ne '1') { $again += 'skip-alpha' }
$logged = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
if ([IO.File]::Exists($env:LOG)) {
  # Another window may be writing to the log, so allow that while reading
  $r = New-Object IO.StreamReader (New-Object IO.FileStream $env:LOG, 'Open', 'Read', 'ReadWrite')
  while ($null -ne ($l = $r.ReadLine())) {
    $c = $l -split "`t", 4
    if ($c.Count -eq 4 -and $c[1] -ne 'failed' -and $again -notcontains $c[1] -and ($c[1] -notlike 'skip-*' -or $c[2] -eq $set)) { [void]$logged.Add($c[3]) }
  }
  $r.Close()
}
try { [IO.File]::AppendAllText($env:LOG, $(if ([IO.File]::Exists($env:LOG)) { '' } else { "time`tresult`tsettings`tsize`tmodified`tpath`r`n" })) }
catch { [Console]::Error.WriteLine("[warning] Cannot write to the log, so results may not be remembered: $($env:LOG)") }

function Get-Key($f) { "$($f.Length)`t$($f.LastWriteTimeUtc.Ticks)`t$($f.FullName)" }
$buf = New-Object Text.StringBuilder
function Add-Log($result, $key) { [void]$buf.Append([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture) + "`t$result`t$set`t$key`r`n") }
# If another window has the log open, the lines stay in the buffer until the next pass
function Save-Log { if ($buf.Length) { try { [IO.File]::AppendAllText($env:LOG, $buf.ToString()); $buf.Length = 0 } catch {} } }
# Two windows can reach the same video, so a lock is held while converting. It lives in TEMP because a mount may not enforce it, and Windows frees it if the window dies.
function Get-Lock($p) {
  $h = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($p.ToLowerInvariant()))).Replace('-', '')
  try { New-Object IO.FileStream -ArgumentList @([IO.Path]::Combine($env:TEMP, 'convert_av1', "$h.lock"), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::Write, [IO.FileShare]::None, 4096, [IO.FileOptions]::DeleteOnClose) } catch { $null }
}
# Exit codes of :convert_one. Any other code means it was cut off, so nothing is recorded and the video runs again next time.
$results = @{ 10 = 'converted'; 11 = 'converted'; 12 = 'converted'; 13 = 'converted'; 14 = 'converted'; 15 = 'converted'; 20 = 'skip-exists'; 21 = 'skip-larger'; 22 = 'skip-little-gain'; 23 = 'skip-not-smaller'; 24 = 'skip-color'; 25 = 'skip-data'; 26 = 'skip-cover'; 27 = 'skip-dovi'; 28 = 'skip-hdr10plus'; 29 = 'skip-captions'; 30 = 'failed'; 31 = 'skip-alpha' }
function Add-Result {
  $code = $conv.ExitCode
  $s = $keys[$cur]
  if ($results.ContainsKey($code)) { Add-Log $results[$code] (Get-Key $s) }
  $sub = "$env:SUB"
  if ($code -ge 13 -and $code -le 15) { $code -= 3; $sub = 'av1\' }
  if ($code -ge 10 -and $code -le 12) {
    $x = if ($code -eq 11) { '.mp4' } elseif ($code -eq 12) { '.mkv' } else { [IO.Path]::GetExtension($cur) }
    try {
      $o = New-Object IO.FileInfo ([IO.Path]::Combine([IO.Path]::GetDirectoryName($cur), $sub + [IO.Path]::GetFileNameWithoutExtension($cur) + $x))
      if ($o.Exists) {
        # The dates of the original were read before it could be deleted. A mount may refuse some of them.
        try { $o.LastWriteTimeUtc = $s.LastWriteTimeUtc; $o.CreationTimeUtc = $s.CreationTimeUtc; $o.Refresh() } catch {}
        # Record the new file as well, or the next run would have to check it
        Add-Log 'result' (Get-Key $o)
      }
    } catch {}
  }
  $lock.Dispose()
}

# 2) Find videos, including subfolders, and leave out the ones in the log. Inaccessible folders (System Volume Information etc.) and junctions or symlinks are skipped.
#    Size and modified time come with the folder listing, so this costs nothing extra per file.
#    name.part.ext is a result in progress, possibly from another window, or one left by a stopped run. It is never a source.
$old = 0
$keys = @{}
$files = New-Object Collections.Generic.List[string]
$dirs = New-Object Collections.Stack
$dirs.Push($env:ROOT)
while ($dirs.Count) {
  $d = $dirs.Pop()
  try {
    foreach ($f in ([IO.DirectoryInfo]$d).GetFiles()) {
      if ($ext -contains $f.Extension -and $f.BaseName -notlike '*.part') {
        $key = Get-Key $f
        if ($logged.Contains($key)) { $old++ } else { $files.Add($f.FullName); $keys[$f.FullName] = $f }
      }
    }
    foreach ($s in [IO.Directory]::GetDirectories($d)) { if (-not ([IO.File]::GetAttributes($s) -band [IO.FileAttributes]::ReparsePoint)) { $dirs.Push($s) } }
  } catch {}
  [Console]::Error.Write("`rFinding videos: $($files.Count + $old) ")
}
$files.Sort([StringComparer]::OrdinalIgnoreCase)
$n = $files.Count
[Console]::Error.WriteLine()

# 3) Check and convert at the same time
#  - Check: run up to JOBS ffprobe processes at once, and queue every file that is not AV1 as its result arrives.
#    By default ffprobe reads up to 5 MB per file, which makes the head of a hard disk thrash, so read only enough for the codec name.
#  - Convert: take files from the queue one at a time and run :convert_one in this file, passing the path in SRC so that special characters and emoji survive.
#  - Display: progress of the check goes to the window title so it does not mix with ffmpeg's output, and files already in AV1 are only counted.
[Console]::Out.WriteLine("Log: $($env:LOG)")
[Console]::Out.WriteLine("Skipped at once because they are in the log: $old files")
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
        if ($run[$j][1].StandardOutput.ReadToEnd().Trim() -eq 'av1') { $av1++; Add-Log 'av1' (Get-Key $keys[$run[$j][0]]) } else { $todo.Enqueue($run[$j][0]) }
        $run.RemoveAt($j); $done++; $busy = $true
      }
    }
    if ($conv -and $conv.HasExited) { Add-Result; $conv = $null }
    if (-not $conv -and $todo.Count) {
      if ($line) { [Console]::Error.WriteLine(); $line = $false }
      $cur = $todo.Dequeue()
      # a.mov and a.mp4 end up with the same result name, so the name without its extension is what gets locked
      $lock = Get-Lock ([IO.Path]::Combine([IO.Path]::GetDirectoryName($cur), [IO.Path]::GetFileNameWithoutExtension($cur)))
      # The size is read after taking the lock, because another window may have replaced or removed the file since the list was made
      $f = New-Object IO.FileInfo $cur
      if (-not $lock) {
        [Console]::Out.WriteLine("[skip] Another window is converting this video: `"$cur`"")
      } elseif (-not $f.Exists -or $f.Length -ne $keys[$cur].Length) {
        $lock.Dispose()
        [Console]::Out.WriteLine("[skip] Changed since the list was made, probably by another window: `"$cur`"")
      } else {
        $k++
        [Console]::Out.Write("[#$k | checked $done/$n] ")
        $si = New-Object Diagnostics.ProcessStartInfo $env:ComSpec, '/c ""%BATF%" /convert-one"'
        $si.UseShellExecute = $false
        $si.EnvironmentVariables['SRC'] = $cur
        $conv = [Diagnostics.Process]::Start($si)
      }
    }
    try { [Console]::Title = "AV1 checked $done/$n | already AV1 $av1 | converting #$k | queued $($todo.Count)" } catch {}
    # Show progress on one line while nothing is converting, so the window does not look frozen
    if (-not $conv -and $done -lt $n) { [Console]::Error.Write("`rChecked: $done/$n "); $line = $true }
    Save-Log
    if (-not $busy) { Start-Sleep -Milliseconds 20 }
  }
} finally {
  # On an error or Ctrl+C, wait for the running conversion so it is not left alone in the window
  if ($conv) { $conv.WaitForExit(); Add-Result }
  Save-Log
}
if ($line) { [Console]::Error.WriteLine() }
[Console]::Out.WriteLine("Check finished: $old skipped from the log, $n checked, $av1 of those already AV1, $k conversions attempted")

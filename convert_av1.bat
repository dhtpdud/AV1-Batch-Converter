@echo off
setlocal
rem 지정한 폴더와 모든 하위 폴더의 영상을 AV1로 변환. 이미 AV1인 영상은 건너뜀
rem 인코더는 NVENC를 먼저 쓰고, 못 쓰면 Intel QSV, AMD AMF, CPU(SVT-AV1) 순서로 자동 전환
rem 원본 확장자를 유지하되, AV1을 담을 수 없는 형식(mov, m4v, ts, mts, m2ts, mpg, mpeg)은 .mp4로 저장
rem 원본 유지 시 각 폴더의 av1\ 폴더에, 원본 삭제 시 원본이 있던 자리에 저장
rem 변환 결과가 원본보다 크면 결과를 버리고 원본을 그대로 둠
rem 1분 이상인 영상은 가운데 10초를 먼저 인코딩해 보고, 줄어드는 양이 적으면 변환하지 않고 건너뜀
rem 사용법: 폴더를 이 bat 아이콘에 끌어다 놓거나, 실행 후 경로를 입력. 여러 창에서 동시에 실행해도 됨

rem 화질: 낮을수록 고화질·큰 용량 (0~63)
set CQ=30
rem AV1 여부를 동시에 검사할 파일 수 (rclone 마운트처럼 느린 저장소일수록 늘리면 효과가 큼)
set JOBS=8
rem 시험 인코딩으로 예상한 크기가 원본보다 이 비율(%%) 이상 줄지 않으면 변환하지 않음
set MIN_SAVE=10
rem 이 파일 끝의 PowerShell 코드를 읽고, 그 코드가 이 bat를 다시 실행할 때 쓰는 경로
set "BATF=%~f0"

rem PowerShell이 변환할 파일마다 이 bat를 /convert-one 인자로 다시 실행함. 파일 경로는 환경 변수 SRC로 받음
if "%~1"=="/convert-one" goto convert_one

where ffmpeg >nul 2>&1 || (echo [오류] ffmpeg를 찾을 수 없습니다. & pause & exit /b 1)
where ffprobe >nul 2>&1 || (echo [오류] ffprobe를 찾을 수 없습니다. & pause & exit /b 1)

rem 빠른 순서로 실제 인코딩을 해 보고 처음 성공한 인코더를 씀. ffmpeg에 들어 있어도 그래픽카드가 지원하지 않으면 실패하기 때문
rem 모두 4:2:0만 받으므로 4:2:2·4:4:4 영상은 4:2:0으로 변환 (10비트는 유지, 4:2:0 영상은 변환 없음)
rem split_encode_mode 2: 한 프레임을 NVENC 2개가 나눠 인코딩 (RTX 4070 Ti 이상). p5에서는 자동으로 켜지지 않아 강제. 8K 31→55fps, 크기·화질 차이 거의 없음
set HWACCEL=-hwaccel cuda
set "ENCNAME=NVIDIA NVENC, 인코더 2개 사용"
set VOPT=-vf "format=nv12|yuv420p|p010le" -c:v av1_nvenc -preset p5 -split_encode_mode 2 -rc vbr -cq %CQ% -b:v 0
call :try_encoder && goto encoder_ok
set "ENCNAME=NVIDIA NVENC"
set VOPT=-vf "format=nv12|yuv420p|p010le" -c:v av1_nvenc -preset p5 -rc vbr -cq %CQ% -b:v 0
call :try_encoder && goto encoder_ok

rem NVENC를 못 쓰면 CUDA 디코딩도 없을 수 있으므로 디코더는 ffmpeg가 고르게 함 (없으면 CPU로 디코딩)
set HWACCEL=-hwaccel auto
set "ENCNAME=Intel Quick Sync"
set VOPT=-vf "format=nv12|p010le" -c:v av1_qsv -preset medium -global_quality %CQ%
call :try_encoder && goto encoder_ok
rem AMF의 qp는 0~255 범위라 CQ(0~63)에 4를 곱함
set /a QP=CQ*4
set "ENCNAME=AMD AMF"
set VOPT=-vf "format=nv12|yuv420p|p010le" -c:v av1_amf -quality balanced -rc cqp -qp_i %QP% -qp_p %QP% -qp_b %QP%
call :try_encoder && goto encoder_ok
rem 소프트웨어 중 가장 빠름 (1080p 측정: SVT-AV1 518fps, libaom 173fps, rav1e 5fps). preset 10은 12와 속도가 거의 같고 화질은 더 좋음
set "ENCNAME=CPU SVT-AV1, 그래픽카드 인코더를 쓸 수 없어 전환됨. 많이 느릴 수 있음"
set VOPT=-vf "format=yuv420p|yuv420p10le" -c:v libsvtav1 -preset 10 -crf %CQ%
call :try_encoder && goto encoder_ok
echo [오류] 쓸 수 있는 AV1 인코더가 없습니다.
pause
exit /b 1
:encoder_ok
echo 인코더: %ENCNAME%

rem 시험 인코딩 파일을 둘 곳. 영상 폴더(rclone 마운트 등)가 아닌 로컬 임시 폴더를 쓰고, 여러 창이 겹치지 않게 실행마다 따로 만듦
rem %RANDOM%은 같은 초에 시작한 창끼리 값이 같으므로, mkdir가 이미 있는 폴더에서 실패하는 것을 이용해 빈 이름을 차지할 때까지 다시 뽑음
if not exist "%TEMP%\convert_av1" mkdir "%TEMP%\convert_av1"
:mktmp
set "TMPD=%TEMP%\convert_av1\%RANDOM%"
mkdir "%TMPD%" 2>nul || goto mktmp

set "TARGET=%~1"
if defined TARGET goto check
:ask
set "TARGET="
set /p "TARGET=변환할 폴더 경로를 입력하세요 (폴더를 이 창에 끌어다 놓아도 됨): "
if not defined TARGET (echo [오류] 경로를 입력하지 않았습니다. & pause & exit /b 1)
:check
rem 끌어다 놓은 경로에 붙는 따옴표 제거
set "TARGET=%TARGET:"=%"
cd /d "%TARGET%" 2>nul || (echo [오류] 폴더를 찾을 수 없습니다: "%TARGET%" & goto ask)
echo 대상 폴더: "%CD%"

rem 이번 실행에서 변환에 성공한 원본만 삭제 (실패·건너뛴 파일은 남김). del은 휴지통을 거치지 않음
set DEL_ORIGINAL=N
echo Y = 원본 삭제, 결과는 원본 자리에 저장 (영구 삭제)
echo N = 원본 유지, 결과는 각 폴더의 av1 폴더에 저장
choice /c YN /n /m "변환에 성공한 원본 영상을 삭제할까요? [Y/N]: "
if not errorlevel 2 set DEL_ORIGINAL=Y
set SUB=av1\
if "%DEL_ORIGINAL%"=="Y" set SUB=

rem 파일 찾기, AV1 검사, 변환 순서는 이 파일 끝의 PowerShell 코드가 맡음
rem bat 변수에 파일 목록을 담으면 파일이 수만 개일 때 set마다 환경 전체를 복사해 몇십 분씩 멈추기 때문
rem bat가 CP949라 한글 메시지가 깨지지 않도록 시스템 기본 인코딩(Default)으로 읽음
set "ROOT=%CD%"
powershell -NoProfile -Command "iex (([IO.File]::ReadAllText($env:BATF, [Text.Encoding]::Default) -split ('#'+'PS'+'#'))[1])"
if errorlevel 1 echo [오류] 검사·변환 도중 오류가 나서 멈췄습니다. 남은 파일은 다시 실행하면 이어서 처리합니다.
rd /s /q "%TMPD%" 2>nul

echo 완료.
pause
exit /b

:try_encoder
ffmpeg -v quiet -f lavfi -i testsrc2=size=1920x1080:rate=30 -frames:v 10 %VOPT% -f null NUL
exit /b %errorlevel%

:convert_one
rem 파일 이름에 %, &, ! 등이 있어도 깨지지 않도록 환경 변수로 받고, 쓸 때는 항상 따옴표로 감쌈
for %%i in ("%SRC%") do (set "DIR=%%~dpi" & set "NAME=%%~ni" & set "EXT=%%~xi")

set "OUTX=%EXT%"
for %%e in (.mov .m4v .ts .mts .m2ts .mpg .mpeg) do if /i "%EXT%"=="%%e" set OUTX=.mp4
set "OUT=%DIR%%SUB%%NAME%%OUTX%"
rem .part로 쓰고 성공 시에만 이름을 바꿔, 중간에 끊긴 파일이 완성본으로 남지 않게 함. 끝 확장자로 ffmpeg가 형식을 정함
set "PART=%DIR%%SUB%%NAME%.part%OUTX%"

rem 같은 이름의 결과 파일이 이미 있으면 덮어쓰지 않음. 원본 삭제 모드에서 원본 자신은 예외
if exist "%OUT%" if /i not "%OUT%"=="%SRC%" (echo [건너뜀] 결과 파일 "%OUT%" 이미 있음: "%SRC%" & exit /b)

rem 가운데 10초를 원본 그대로 복사한 것과 AV1로 인코딩한 것의 크기를 비교해 압축 여지를 미리 확인
rem 1분 미만이거나 시험이 실패하면 확인 없이 변환 (변환 후 크기 비교는 그대로 함)
set PCT=
set DUR=
ffprobe -v error -show_entries format=duration -of csv=p=0 "%SRC%" > "%TMPD%\dur.txt" 2>nul
set /p DUR=<"%TMPD%\dur.txt"
for /f "delims=." %%d in ("%DUR%") do set "DUR=%%d"
set /a DUR=DUR 2>nul
if %DUR% LSS 60 goto encode
set /a SS=DUR/2-5
echo [확인] 압축 여지 확인 중: "%SRC%"
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
rem 10초 분량이라 2GB를 넘지 않으므로 set /a로 계산해도 됨. 곱하기 전에 나눠 넘침을 막음
set /a PCT=ESZ/(SSZ/100)
if %PCT% GTR 100 (
  echo [건너뜀] 압축 여지 없음, 예상 크기 원본의 %PCT%%%: "%SRC%"
  exit /b
)
set /a KEEP=100-MIN_SAVE
if %PCT% GTR %KEEP% (
  echo [건너뜀] 압축 여지 적음, 예상 크기 원본의 %PCT%%%: "%SRC%"
  exit /b
)

:encode
if defined PCT (echo [변환] 예상 크기 원본의 %PCT%%%: "%SRC%") else (echo [변환] "%SRC%")
if not exist "%DIR%%SUB%" mkdir "%DIR%%SUB%"

rem mp4로 바꿀 때는 mp4에서 널리 재생되는 오디오만 복사하고, PCM 등은 AAC로 인코딩
set ACOPY=1
if /i "%OUTX%"==".mp4" (
  ffprobe -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 "%SRC%" 2>nul | findstr /v /x /i "aac mp3 ac3 eac3 opus flac alac" >nul && set ACOPY=
)

rem ffmpeg는 실패 시 음수 코드를 반환해 if errorlevel 1 로는 못 잡으므로, 종료 코드 0일 때만 OK를 설정
set OK=
if defined ACOPY (ffmpeg -hide_banner -loglevel warning -stats %HWACCEL% -i "%SRC%" -map 0:v:0 -map 0:a? %VOPT% -c:a copy -y "%PART%" && set OK=1)
rem 복사가 실패한 경우에도 AAC로 한 번 더 시도
if not defined OK (
  echo [AAC 인코딩] "%SRC%"
  ffmpeg -hide_banner -loglevel warning -stats %HWACCEL% -i "%SRC%" -map 0:v:0 -map 0:a? %VOPT% -c:a aac -b:a 192k -y "%PART%" && set OK=1
)
if not defined OK (
  echo [실패] "%SRC%"
  del "%PART%" 2>nul
  exit /b
)

rem 결과가 원본보다 크면 변환할 의미가 없으므로 버리고 원본 유지
rem if의 숫자 비교는 2GB를 넘으면 틀리므로, 앞에 0을 붙여 20자리 문자열로 비교
for %%a in ("%PART%") do set "PSIZE=00000000000000000000%%~za"
for %%a in ("%SRC%") do set "SSIZE=00000000000000000000%%~za"
if "%PSIZE:~-20%" GEQ "%SSIZE:~-20%" (
  echo [건너뜀] 결과가 원본보다 커서 원본 유지: "%SRC%"
  del "%PART%"
  exit /b
)

move /y "%PART%" "%OUT%" >nul || exit /b
if not "%DEL_ORIGINAL%"=="Y" exit /b
if /i "%OUT%"=="%SRC%" (echo [원본 교체] "%SRC%") else (del "%SRC%" && echo [원본 삭제] "%SRC%")
exit /b

rem 아래는 bat가 직접 실행하지 않는 PowerShell 코드
#PS#
# 오류가 나면 바로 멈춤 (검사가 안 된 파일을 변환하지 않도록)
$ErrorActionPreference = 'Stop'
$ext = '.mp4', '.mkv', '.mov', '.avi', '.wmv', '.flv', '.webm', '.m4v', '.ts', '.mts', '.m2ts', '.mpg', '.mpeg'

# 1) 하위 폴더까지 영상 찾기. 들어갈 수 없는 폴더(System Volume Information 등)와 정션·심볼릭 링크 폴더는 건너뜀
$files = New-Object Collections.Generic.List[string]
$dirs = New-Object Collections.Stack
$dirs.Push($env:ROOT)
while ($dirs.Count) {
  $d = $dirs.Pop()
  try {
    foreach ($f in [IO.Directory]::GetFiles($d)) { if ($ext -contains [IO.Path]::GetExtension($f)) { $files.Add($f) } }
    foreach ($s in [IO.Directory]::GetDirectories($d)) { if (-not ([IO.File]::GetAttributes($s) -band [IO.FileAttributes]::ReparsePoint)) { $dirs.Push($s) } }
  } catch {}
  [Console]::Error.Write("`r영상 찾는 중: $($files.Count)개 ")
}
$files.Sort([StringComparer]::OrdinalIgnoreCase)
$n = $files.Count
[Console]::Error.WriteLine()

# 2) AV1 검사와 변환을 동시에 진행
#  - 검사: ffprobe를 JOBS개까지 동시에 띄우고, 끝난 것부터 결과를 받아 AV1이 아닌 파일을 변환 대기열에 넣음
#    기본값은 파일당 최대 5MB를 읽어 HDD에서 동시에 읽으면 헤드가 오가며 느려지므로, 코덱 이름만 알 수 있을 만큼만 읽음
#  - 변환: 대기열에서 하나씩 꺼내, 파일 경로를 환경 변수 SRC로 넘겨 이 bat의 :convert_one을 실행 (특수문자·이모지가 깨지지 않음)
#  - 화면: 변환 출력(ffmpeg 진행률)과 섞이지 않도록 검사 진행은 창 제목에 표시하고, 이미 AV1인 파일은 개수만 셈
[Console]::Out.WriteLine("AV1 여부 검사와 변환을 함께 진행합니다: ${n}개 (검사는 동시에 $($env:JOBS)개씩, 진행 상황은 창 제목에 표시)")
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
    # 출력이 한 줄뿐이라 파이프가 차서 멈출 일이 없으므로, 끝났는지만 보고 결과를 읽음
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
      [Console]::Out.Write("[${k}번째 | 검사 $done/$n] ")
      $si = New-Object Diagnostics.ProcessStartInfo $env:ComSpec, '/c ""%BATF%" /convert-one"'
      $si.UseShellExecute = $false
      $si.EnvironmentVariables['SRC'] = $todo.Dequeue()
      $conv = [Diagnostics.Process]::Start($si)
    }
    try { [Console]::Title = "AV1 검사 $done/$n · 이미 AV1 $av1 · 변환 $k번째 · 대기 $($todo.Count)" } catch {}
    # 변환 중이 아닐 때만 같은 줄에 검사 진행 표시 (멈춘 것처럼 보이지 않도록)
    if (-not $conv -and $done -lt $n) { [Console]::Error.Write("`r검사 진행: $done/$n "); $line = $true }
    if (-not $busy) { Start-Sleep -Milliseconds 20 }
  }
} finally {
  # 오류나 Ctrl+C로 멈출 때 진행 중인 변환이 창에 홀로 남지 않도록 끝날 때까지 기다림
  if ($conv) { $conv.WaitForExit() }
}
if ($line) { [Console]::Error.WriteLine() }
[Console]::Out.WriteLine("검사 끝: ${n}개 중 이미 AV1 ${av1}개 건너뜀, 변환 시도 ${k}개")

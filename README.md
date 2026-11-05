# AV1 Batch Converter

**English** | [한국어](README.ko.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [Русский](README.ru.md) | [العربية](README.ar.md) | [हिन्दी](README.hi.md)

A Windows batch script that converts every video in a folder and its subfolders to AV1.
It uses NVIDIA NVENC first and switches to another encoder automatically if NVENC is not available.

> [!WARNING]
> **Y mode (delete originals) cannot be undone.** AV1 conversion is lossy, and the original cannot be recovered afterwards.
> Use N mode first and check the results before using Y mode. Please read [Limitations](#limitations) first.

## Expected results

When you run the script:

- It finds mp4, mkv, mov, avi, wmv, flv, webm, m4v, ts, mts, m2ts, mpg and mpeg files in the folder and its subfolders.
- Videos that are already AV1 are not converted.
- For videos of 1 minute or longer, it first encodes 10 seconds from the middle. If the estimated size is over 90% of the original, the video is not converted.
- If a finished result is the same size as the original or larger, the result is thrown away and the original is kept.
- A video is not converted if something in it cannot be kept: 4:2:2, 4:4:4 and 12-bit video, data tracks that cannot be copied, and cover art in mkv. For HDR10+, Dolby Vision profile 7 and transparency, you choose at the start.
- If a conversion fails, the original is not deleted.
- Checking for AV1 and encoding run at the same time. Encoding handles one file at a time.
- Results are recorded in a log. Running it again skips videos in the log at once, without checking them, so you can continue after stopping.

**Not every video gets smaller.** Videos that are already well compressed are skipped, and the saving differs from video to video.

### How much smaller

**From 0% (not converted, original kept) to a measured maximum of 96%.** Files never get larger, because a result that is the same size or larger is thrown away.

These results come from 52 real videos picked at random from one PC, using the default settings (NVENC, CQ 30).

| Case | Size compared to original | Saving |
|---|---|---|
| Largest saving | 4% | 96% |
| Median of the 41 converted videos | 44% | 56% |
| Smallest saving among converted videos | 89% | 11% |
| The 11 skipped videos (estimated size 96-233%) | 100% (original kept) | 0% |

| Source codec | Sample | Converted | Size of converted videos compared to original |
|---|---|---|---|
| H.264 | 25 | 18 | 4-89% |
| HEVC | 25 | 21 | 15-88% |
| VP9, MPEG-4 | 1 each | 2 | 81%, 23% |

The higher the source bitrate, the larger the saving. Including skipped videos, the median size compared to the original was 76% for sources below 5 Mbps, 50% for 5-15 Mbps, and 27% for 15-40 Mbps.

These numbers are not a guarantee.

- Each video was compared on the video track only, using 10 seconds at each of the 25%, 50% and 75% points, for 30 seconds in total. These are not results from converting whole files.
- Audio is usually copied as is, so real files shrink less than these numbers.
- Only videos of 1 minute or longer were measured, and they are one person's collection. The range may differ for other videos.
- Only NVENC was measured. Other encoders and other `CQ` values give different results.
- If the estimate before conversion is wrong, a result that saves less than 10% can remain.

### Where results go

| Mode | Saved to | Original |
|---|---|---|
| N (recommended) | An `av1\` folder inside each folder | Kept |
| Y | Where the original was | **Permanently deleted** after a successful conversion (does not go to the Recycle Bin) |

The extension stays the same as the original. The exceptions are mov, m4v, ts, mts, m2ts, mpg and mpeg, which cannot hold AV1 and are saved as `.mp4`. If a track cannot be stored in that format, the result is saved as `.mkv`.

### What is kept after conversion

These results were checked with test videos.

| Item | Result |
|---|---|
| First video track | Converted to AV1 |
| Audio tracks (including multiple tracks and language tags) | Kept. Copied as is. When saving to mp4, incompatible formats are converted to AAC 192 kbps |
| Chapters, tags (title, comment, creation time and others) | Kept |
| 10-bit | Kept |
| HDR10 (BT.2020, PQ, mastering display data) | Kept (checked with NVENC) |
| Rotation | The picture itself is rotated when saved. It looks the same |
| VR metadata (spherical, stereo 3D) | Kept (checked with a real VR video) |
| File dates (created, modified) | Kept |
| Timecode | Kept |
| Subtitle tracks | Kept. Copied as is |
| Second and later video tracks | Kept. Copied as is, so they do not get smaller |
| Cover art, fonts and other attachments | Kept |
| Dolby Vision (profile 8 checked with a real video) | Kept. Such videos are encoded with SVT-AV1 on the CPU, and the result is profile 10 |
| Captions inside the video track | Kept with NVENC. With other encoders the video is not converted |
| XMP in mp4 and mov (file level) | Kept |
| **4:2:2, 4:4:4 and 12-bit video** | **Not converted.** The original stays as it is |
| **Data tracks that cannot be copied (GPS and others)** | **Not converted.** The original stays as it is |
| **Cover art in mkv** | **Not converted.** ffmpeg would turn it into a video track, so the original stays as it is |
| **HDR10+** | **You choose at the start** (skip, convert anyway, or keep the original) |
| **Transparency** | **You choose at the start** (skip, convert anyway, or keep the original) |
| **Dolby Vision profile 7** | **You choose at the start** (skip, convert anyway, or keep the original) |

## Requirements

- Windows 10 or 11
- `ffmpeg` and `ffprobe` on the PATH
- At least one of the encoders below

| Order | Encoder | Needs |
|---|---|---|
| 1 | NVENC (`av1_nvenc`), 2 engines | An NVIDIA graphics card with 2 AV1 encoders, such as the RTX 4070 Ti |
| 2 | NVENC (`av1_nvenc`), 1 engine | An NVIDIA graphics card with AV1 support (RTX 40 series or later) |
| 3 | Intel Quick Sync (`av1_qsv`) | Intel graphics with AV1 encoding |
| 4 | AMD AMF (`av1_amf`) | AMD graphics with AV1 encoding |
| 5 | CPU (`libsvtav1`, preset 10) | An ffmpeg build that includes SVT-AV1 |

At startup, the script runs a real test encode in this order and uses the first one that works. The encoder in use is shown on the `Encoder: ...` line.

## Usage

1. Download `convert_av1.bat` from [Releases](../../releases/latest).
2. Drag the folder to convert onto the bat file, or run the bat file and type the folder path.
3. Check the target folder and choose `Y` (delete originals) or `N` (keep originals).
4. Choose what happens to videos that would lose HDR10+, Dolby Vision profile 7 or transparency.

Progress of the check is shown in the window title. You can run several windows on different folders at the same time, but each window will be slower.

**To stop**: close the window. The `name.part.ext` file of the conversion in progress is left behind, so delete it yourself.

### Videos that cannot keep everything

Before work starts, you are asked two questions: one for HDR10+ and Dolby Vision profile 7, and one for transparency.

| Choice | What happens |
|---|---|
| 1 | The video is skipped and the original stays as it is |
| 2 | The video is converted anyway and what cannot be kept is lost. In Y mode the original is deleted |
| 3 (Y mode only) | The original is kept and the result is saved in an `av1\` folder |

A video skipped this way is checked again if you answer differently on a later run. A transparent video that is also 4:4:4 is reduced to 4:2:0 when converted.

### Settings

Change these values near the top of the bat file.

| Value | Default | Meaning |
|---|---|---|
| `CQ` | 30 | Quality (0-63). Lower means better quality and larger files. Applied the same to every video |
| `JOBS` | 8 | How many files to check for AV1 at once |
| `MIN_SAVE` | 10 | Do not convert if the estimated saving (%) is below this value |
| `LOG` | `convert_av1.log` next to the bat file | Where results are recorded |

### Result log

Results are added to `convert_av1.log` next to the bat file, as tab-separated text. All folders and windows share this one file.

| Result | Meaning | On the next run |
|---|---|---|
| `converted`, `result` | The converted video and the file it produced | Skipped |
| `av1` | Already AV1 | Skipped |
| `skip-exists`, `skip-larger`, `skip-little-gain`, `skip-not-smaller`, `skip-color`, `skip-data`, `skip-cover`, `skip-dovi`, `skip-hdr10plus`, `skip-captions`, `skip-alpha` | Not converted | Skipped while the encoder, `CQ` and `MIN_SAVE` stay the same |
| `failed` | Conversion failed | Tried again |

- A video is identified by its path, size and modified time. If any of these changes, it is checked again.
- A conversion that is stopped is not recorded, so it starts again from the beginning.
- To check every video again, delete the log.

## Measurements

Measured with an RTX 4070 Ti, i7-13700KF, Windows 11 and an ffmpeg build from 2026-10. Results will differ in other environments.

### Encoding speed

| Resolution | NVENC, 1 engine | NVENC, 2 engines | CPU SVT-AV1 preset 10 |
|---|---|---|---|
| 8K (7680×3840) | 31 fps | 55 fps | About 14 fps |
| 4K | 107 fps | 189 fps | Not measured |
| 1080p | 400 fps | 574 fps | About 518 fps |

The CPU measurements were taken while other conversions were running. Software encoders compared at 1080p: SVT-AV1 about 518 fps, libaom about 173 fps, rav1e about 5 fps.

### CQ and file size

Results of converting a 20-second part of an 8K HEVC video (source 30 Mbps) with NVENC. This is an example of an already well-compressed video getting larger at CQ 30.

| CQ | Bitrate | SSIM (vs. original) | Decision |
|---|---|---|---|
| 30 | 53.9 Mbps | 0.9955 | Skipped because it gets larger |
| 36 | 28.8 Mbps | 0.9936 | Skipped because the saving is small |
| 42 | 14.3 Mbps | 0.9900 | Converted |

To shrink videos like this you have to raise `CQ`, which also lowers the quality of all other videos.

### Large numbers of files

| Item | Result |
|---|---|
| Finding 23,100 videos on a local SSD | 0.6 seconds |
| Finding 22,887 videos on an rclone crypt mount | 8.9 seconds |
| Processing all 23,100 on a local SSD (all already AV1) | 239 seconds |
| Running all 23,100 again on a local SSD (all in the log) | 2.3 seconds |

## Limitations

### Risk of data loss

- **Dolby Vision was only checked with profile 8.** Few devices and players can play Dolby Vision in AV1 (profile 10). Use N mode first if you need it.
- **Deletion in Y mode cannot be undone.** It uses `del`, so nothing goes to the Recycle Bin.
- **Results are not played back to check them.** Success is judged only by ffmpeg's exit code and the file size. If the video is damaged but ffmpeg reports success, the original is deleted in Y mode.
- **AV1 conversion is lossy.** Compressing an already compressed video never makes the quality better than the original.
- **4:2:2, 4:4:4 and 12-bit videos do not get smaller.** The AV1 encoders used here take 4:2:0 only, so such videos stay as they are.

### Where decisions can be wrong

- **The estimate looks only at the middle 10 seconds.** In testing, a video estimated at 30% actually came out at 45%. Videos that would have shrunk can be skipped.
- **Videos under 1 minute are not checked in advance.** Size is compared only after conversion.
- **If ffprobe cannot read a file, it is treated as not AV1.** A file that is already AV1 may be encoded again.
- **Videos in the log are not looked at again.** If you delete a result, it is not made again until you delete that video's lines from the log, or the whole log.
- **Captions and HDR10+ are looked for in the first 5 frames only.** If they start later, the video is converted anyway, and HDR10+ is lost. So are captions, except on NVENC.

### Playback and compatibility

- Older devices and players cannot play AV1.
- avi, wmv and flv keep their extension, but AV1 in these formats is not a standard combination, and many players will not play it.

### File names and folders

- If result names collide, as with `a.mov` and `a.mp4`, the file processed later is skipped.
- A `name.part.mp4` left behind after stopping is treated as a normal video on the next run. Delete it yourself.
- Junctions and symbolic link folders are not searched.

### Environment

- **On-screen messages are in English.**
- **It has only been tested on Korean Windows 11.** The bat file uses ASCII characters only, so it does not depend on the system language. It was confirmed to work with console code pages 437, 949 and 65001, but it has not been run on Windows in other languages.
- **Do not overwrite a bat file that a running window is using.** cmd reads the file bit by bit, so a running window may execute the wrong lines.
- CPU encoding is much slower, at about 14 fps for 8K.
- If ffmpeg does not include `libsvtav1`, the script cannot switch to the CPU and ends with an error.

### Using it on an rclone mount

- `--vfs-cache-mode writes` is required. With `off`, mp4 and mkv cannot be written and every file fails.
- In Y mode, **originals are deleted before the upload finishes.** If the upload fails, you depend on the copy left in the cache, so be careful.
- Files being uploaded are not removed from the cache even past `--vfs-cache-max-age` and `--vfs-cache-max-size`, so the cache drive needs free space.
- The modified date is kept, also after remounting. A mount reports the modified date as the creation date too, so there is no separate creation date to keep.
- These points were tested on crypt mounts over local drives, not with cloud storage.

### Not tested

- **Real encoding with Intel QSV and AMD AMF has not been tried.** There was no such hardware, so only option parsing was checked. Whether the quality matches NVENC's CQ is also unknown.
- Graphics cards with only one NVENC engine (only the switch was checked, by simulating a failure of 2-engine mode)
- Environments without NVENC were simulated by hiding the graphics card. It has not been run on real AMD or Intel PCs.
- Paths longer than 260 characters

## License

[MIT](LICENSE)

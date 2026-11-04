# AV1 Batch Converter

[English](README.md) | [한국어](README.ko.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Français](README.fr.md) | **Deutsch** | [Português](README.pt-BR.md) | [Русский](README.ru.md) | [العربية](README.ar.md) | [हिन्दी](README.hi.md)

Ein Windows-Batch-Skript, das alle Videos in einem Ordner und seinen Unterordnern nach AV1 konvertiert.
Es verwendet zuerst NVIDIA NVENC und wechselt automatisch zu einem anderen Encoder, wenn NVENC nicht verfügbar ist.

> [!WARNING]
> **Untertitelspuren bleiben im Ergebnis nicht erhalten.** Im Y-Modus (Originale löschen) gehen die Untertitel des Originals mit ihm verloren und können nicht wiederhergestellt werden.
> Verwenden Sie zuerst den N-Modus und prüfen Sie die Ergebnisse, bevor Sie den Y-Modus verwenden. Bitte lesen Sie zuerst [Einschränkungen](#einschränkungen).

## Erwartete Ergebnisse

Wenn Sie das Skript ausführen:

- Es findet Dateien der Formate mp4, mkv, mov, avi, wmv, flv, webm, m4v, ts, mts, m2ts, mpg und mpeg im Ordner und seinen Unterordnern.
- Videos, die bereits in AV1 vorliegen, werden nicht konvertiert.
- Bei Videos ab 1 Minute Länge kodiert es zuerst 10 Sekunden aus der Mitte. Liegt die geschätzte Größe über 90% des Originals, wird das Video nicht konvertiert.
- Ist ein fertiges Ergebnis genauso groß wie das Original oder größer, wird das Ergebnis verworfen und das Original behalten.
- Schlägt eine Konvertierung fehl, wird das Original nicht gelöscht.
- Die AV1-Prüfung und das Kodieren laufen gleichzeitig. Kodiert wird jeweils nur eine Datei.
- Bei einem erneuten Start werden bereits verarbeitete Dateien übersprungen, sodass Sie nach einem Abbruch weitermachen können.

**Nicht jedes Video wird kleiner.** Bereits gut komprimierte Videos werden übersprungen, und die Ersparnis ist von Video zu Video unterschiedlich.

### Wie viel kleiner

**Von 0% (nicht konvertiert, Original behalten) bis zu einem gemessenen Höchstwert von 96%.** Dateien werden nie größer, weil ein gleich großes oder größeres Ergebnis verworfen wird.

Diese Ergebnisse stammen aus 52 echten, zufällig ausgewählten Videos von einem PC und wurden mit den Standardeinstellungen (NVENC, CQ 30) ermittelt.

| Fall | Größe im Vergleich zum Original | Ersparnis |
|---|---|---|
| Größte Ersparnis | 4% | 96% |
| Median der 41 konvertierten Videos | 44% | 56% |
| Kleinste Ersparnis unter den konvertierten Videos | 89% | 11% |
| Die 11 übersprungenen Videos (geschätzte Größe 96-233%) | 100% (Original behalten) | 0% |

| Quellcodec | Stichprobe | Konvertiert | Größe der konvertierten Videos im Vergleich zum Original |
|---|---|---|---|
| H.264 | 25 | 18 | 4-89% |
| HEVC | 25 | 21 | 15-88% |
| VP9, MPEG-4 | je 1 | 2 | 81%, 23% |

Je höher die Bitrate der Quelle, desto größer die Ersparnis. Bei Quellen unter 5 Mbps lag die mediane Größe, einschließlich übersprungener Videos, bei 76% des Originals, bei 5-15 Mbps bei 50% und bei 15-40 Mbps bei 27%.

Diese Zahlen sind keine Garantie.

- Jedes Video wurde nur anhand der Videospur verglichen, und zwar mit je 10 Sekunden an den Punkten 25%, 50% und 75%, insgesamt also 30 Sekunden. Es handelt sich nicht um Ergebnisse aus der Konvertierung ganzer Dateien.
- Audio wird in der Regel unverändert kopiert, daher schrumpfen echte Dateien weniger stark, als diese Zahlen zeigen.
- Gemessen wurden nur Videos ab 1 Minute Länge, und sie stammen aus der Sammlung einer einzelnen Person. Bei anderen Videos kann die Spanne abweichen.
- Gemessen wurde nur NVENC. Andere Encoder und andere `CQ`-Werte liefern andere Ergebnisse.
- Ist die Schätzung vor der Konvertierung falsch, kann ein Ergebnis übrig bleiben, das weniger als 10% einspart.

### Wo die Ergebnisse landen

| Modus | Gespeichert in | Original |
|---|---|---|
| N (empfohlen) | Ein Ordner `av1\` innerhalb jedes Ordners | Bleibt erhalten |
| Y | Am Ort des Originals | Wird nach erfolgreicher Konvertierung **endgültig gelöscht** (landet nicht im Papierkorb) |

Die Dateiendung bleibt dieselbe wie beim Original. Ausnahmen sind mov, m4v, ts, mts, m2ts, mpg und mpeg: Diese Formate können kein AV1 enthalten und werden als `.mp4` gespeichert.

### Was nach der Konvertierung erhalten bleibt

Diese Ergebnisse wurden mit Testvideos überprüft.

| Element | Ergebnis |
|---|---|
| Erste Videospur | Wird nach AV1 konvertiert |
| Audiospuren (einschließlich mehrerer Spuren und Sprach-Tags) | Bleiben erhalten. Werden unverändert kopiert. Beim Speichern als mp4 werden inkompatible Formate in AAC 192 kbps konvertiert |
| Kapitel, Titel | Bleiben erhalten |
| 10-Bit | Bleibt erhalten |
| HDR10 (BT.2020, PQ, Mastering-Display-Daten) | Bleibt erhalten (mit NVENC geprüft) |
| Drehung | Das Bild selbst wird beim Speichern gedreht. Es sieht gleich aus |
| **Untertitelspuren** | **Gehen verloren** |
| **Zweite und weitere Videospuren** | **Gehen verloren** |
| **4:2:2- und 4:4:4-Farbe** | **Wird auf 4:2:0 reduziert** |

## Voraussetzungen

- Windows 10 oder 11
- `ffmpeg` und `ffprobe` im PATH
- Mindestens einer der unten aufgeführten Encoder

| Reihenfolge | Encoder | Benötigt |
|---|---|---|
| 1 | NVENC (`av1_nvenc`), 2 Engines | Eine NVIDIA-Grafikkarte mit 2 AV1-Encodern, etwa die RTX 4070 Ti |
| 2 | NVENC (`av1_nvenc`), 1 Engine | Eine NVIDIA-Grafikkarte mit AV1-Unterstützung (RTX 40-Serie oder neuer) |
| 3 | Intel Quick Sync (`av1_qsv`) | Intel-Grafik mit AV1-Kodierung |
| 4 | AMD AMF (`av1_amf`) | AMD-Grafik mit AV1-Kodierung |
| 5 | CPU (`libsvtav1`, Preset 10) | Ein ffmpeg-Build, der SVT-AV1 enthält |

Beim Start führt das Skript in dieser Reihenfolge eine echte Testkodierung durch und verwendet den ersten Encoder, der funktioniert. Der verwendete Encoder wird in der Zeile `Encoder: ...` angezeigt.

## Verwendung

1. Laden Sie `convert_av1.bat` unter [Releases](../../releases/latest) herunter.
2. Ziehen Sie den zu konvertierenden Ordner auf die bat-Datei, oder starten Sie die bat-Datei und geben Sie den Ordnerpfad ein.
3. Prüfen Sie den Zielordner und wählen Sie `Y` (Originale löschen) oder `N` (Originale behalten).

Der Fortschritt der Prüfung wird im Fenstertitel angezeigt. Sie können mehrere Fenster gleichzeitig für verschiedene Ordner laufen lassen, aber jedes Fenster wird dann langsamer.

**Zum Beenden**: Schließen Sie das Fenster. Die Datei `name.part.ext` der laufenden Konvertierung bleibt zurück, löschen Sie sie also selbst.

### Einstellungen

Ändern Sie diese Werte im oberen Bereich der bat-Datei.

| Wert | Standard | Bedeutung |
|---|---|---|
| `CQ` | 30 | Qualität (0-63). Niedriger bedeutet bessere Qualität und größere Dateien. Gilt gleichermaßen für jedes Video |
| `JOBS` | 8 | Wie viele Dateien gleichzeitig auf AV1 geprüft werden |
| `MIN_SAVE` | 10 | Nicht konvertieren, wenn die geschätzte Ersparnis (%) unter diesem Wert liegt |

## Messwerte

Gemessen mit einer RTX 4070 Ti, i7-13700KF, Windows 11 und einem ffmpeg-Build von 2026-10. In anderen Umgebungen werden die Ergebnisse abweichen.

### Kodiergeschwindigkeit

| Auflösung | NVENC, 1 Engine | NVENC, 2 Engines | CPU SVT-AV1 Preset 10 |
|---|---|---|---|
| 8K (7680×3840) | 31 fps | 55 fps | Etwa 14 fps |
| 4K | 107 fps | 189 fps | Nicht gemessen |
| 1080p | 400 fps | 574 fps | Etwa 518 fps |

Die CPU-Messungen wurden durchgeführt, während andere Konvertierungen liefen. Software-Encoder im Vergleich bei 1080p: SVT-AV1 etwa 518 fps, libaom etwa 173 fps, rav1e etwa 5 fps.

### CQ und Dateigröße

Ergebnisse der Konvertierung eines 20 Sekunden langen Abschnitts eines 8K-HEVC-Videos (Quelle 30 Mbps) mit NVENC. Dies ist ein Beispiel dafür, wie ein bereits gut komprimiertes Video bei CQ 30 größer wird.

| CQ | Bitrate | SSIM (vs. Original) | Entscheidung |
|---|---|---|---|
| 30 | 53.9 Mbps | 0.9955 | Übersprungen, weil es größer wird |
| 36 | 28.8 Mbps | 0.9936 | Übersprungen, weil die Ersparnis gering ist |
| 42 | 14.3 Mbps | 0.9900 | Konvertiert |

Um solche Videos zu verkleinern, müssen Sie `CQ` erhöhen, was auch die Qualität aller anderen Videos senkt.

### Große Dateimengen

| Element | Ergebnis |
|---|---|
| 23100 Videos auf einer lokalen SSD finden | 0.6 Sekunden |
| 22887 Videos auf einem rclone-crypt-Mount finden | 8.9 Sekunden |
| Alle 23100 auf einer lokalen SSD verarbeiten (alle bereits AV1) | 224 Sekunden |

## Einschränkungen

### Risiko von Datenverlust

- **Untertitelspuren gehen verloren.** Das gilt auch für zweite und weitere Videospuren. Verwenden Sie den Y-Modus nicht für Dateien, die diese benötigen.
- **Das Löschen im Y-Modus kann nicht rückgängig gemacht werden.** Es verwendet `del`, daher landet nichts im Papierkorb.
- **Ergebnisse werden zur Prüfung nicht abgespielt.** Der Erfolg wird nur anhand des Exit-Codes von ffmpeg und der Dateigröße beurteilt. Ist das Video beschädigt, meldet ffmpeg aber Erfolg, wird das Original im Y-Modus gelöscht.
- **Die AV1-Konvertierung ist verlustbehaftet.** Das Komprimieren eines bereits komprimierten Videos macht die Qualität nie besser als die des Originals.
- **4:2:2- und 4:4:4-Videos verlieren Farbauflösung, wenn sie auf 4:2:0 reduziert werden.** Verwenden Sie den N-Modus für Material, das Sie schneiden oder farblich bearbeiten wollen.

### Wo Entscheidungen falsch sein können

- **Die Schätzung betrachtet nur die mittleren 10 Sekunden.** In Tests kam ein auf 30% geschätztes Video tatsächlich auf 45%. Videos, die kleiner geworden wären, können übersprungen werden.
- **Videos unter 1 Minute werden nicht vorab geprüft.** Die Größe wird erst nach der Konvertierung verglichen.
- **Kann ffprobe eine Datei nicht lesen, wird sie als Nicht-AV1-Datei behandelt.** Eine Datei, die bereits AV1 ist, wird dann möglicherweise erneut kodiert.

### Wiedergabe und Kompatibilität

- Ältere Geräte und Player können AV1 nicht abspielen.
- avi, wmv und flv behalten ihre Dateiendung, aber AV1 in diesen Formaten ist keine Standardkombination, und viele Player spielen sie nicht ab.

### Dateinamen und Ordner

- Wenn Ergebnisnamen kollidieren, wie bei `a.mov` und `a.mp4`, wird die später verarbeitete Datei übersprungen.
- Eine nach dem Beenden zurückgebliebene `name.part.mp4` wird beim nächsten Durchlauf wie ein normales Video behandelt. Löschen Sie sie selbst.
- Junctions und als symbolische Links angelegte Ordner werden nicht durchsucht.

### Umgebung

- **Die Bildschirmmeldungen sind auf Englisch.**
- **Es wurde nur unter koreanischem Windows 11 getestet.** Die bat-Datei verwendet nur ASCII-Zeichen und hängt daher nicht von der Systemsprache ab. Die Funktion wurde mit den Konsolen-Codepages 437, 949 und 65001 bestätigt, unter Windows in anderen Sprachen wurde das Skript aber nicht ausgeführt.
- **Überschreiben Sie keine bat-Datei, die gerade von einem laufenden Fenster verwendet wird.** cmd liest die Datei Stück für Stück, daher kann ein laufendes Fenster die falschen Zeilen ausführen.
- Die CPU-Kodierung ist viel langsamer, mit etwa 14 fps bei 8K.
- Wenn ffmpeg `libsvtav1` nicht enthält, kann das Skript nicht zur CPU wechseln und endet mit einem Fehler.

### Verwendung auf einem rclone-Mount

- `--vfs-cache-mode writes` ist erforderlich. Mit `off` können mp4 und mkv nicht geschrieben werden, und die Konvertierung schlägt bei jeder Datei fehl.
- Im Y-Modus werden **Originale gelöscht, bevor der Upload abgeschlossen ist.** Schlägt der Upload fehl, sind Sie auf die im Cache verbliebene Kopie angewiesen, seien Sie also vorsichtig.
- Dateien, die gerade hochgeladen werden, werden auch nach Überschreiten von `--vfs-cache-max-age` und `--vfs-cache-max-size` nicht aus dem Cache entfernt, daher braucht das Cache-Laufwerk freien Speicherplatz.
- Diese Punkte wurden mit einem lokalen crypt-Remote getestet. Die aktuelle Version wurde auf einem echten Mount nur bis zur Dateisuche bestätigt und nicht mit Cloud-Speicher getestet.

### Nicht getestet

- **Echtes Kodieren mit Intel QSV und AMD AMF wurde nicht ausprobiert.** Solche Hardware war nicht vorhanden, daher wurde nur das Parsen der Optionen geprüft. Ob die Qualität dem CQ von NVENC entspricht, ist ebenfalls unbekannt.
- Grafikkarten mit nur einer NVENC-Engine (nur die Umschaltung wurde geprüft, indem ein Ausfall des 2-Engine-Modus simuliert wurde)
- Umgebungen ohne NVENC wurden simuliert, indem die Grafikkarte verborgen wurde. Auf echten AMD- oder Intel-PCs wurde das Skript nicht ausgeführt.
- Ob VR-Metadaten (sphärisch) und Dolby Vision erhalten bleiben
- Ob HDR-Daten bei der CPU-Kodierung erhalten bleiben
- Pfade mit mehr als 260 Zeichen

## Lizenz

[MIT](LICENSE)

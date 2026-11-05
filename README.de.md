# AV1 Batch Converter

[English](README.md) | [한국어](README.ko.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Français](README.fr.md) | **Deutsch** | [Português](README.pt-BR.md) | [Русский](README.ru.md) | [العربية](README.ar.md) | [हिन्दी](README.hi.md)

Ein Windows-Batch-Skript, das alle Videos in einem Ordner und seinen Unterordnern nach AV1 konvertiert.
Es verwendet zuerst NVIDIA NVENC und wechselt automatisch zu einem anderen Encoder, wenn NVENC nicht verfügbar ist.

> [!WARNING]
> **Der Y-Modus (Originale löschen) kann nicht rückgängig gemacht werden.** Die AV1-Konvertierung ist verlustbehaftet, und das Original lässt sich danach nicht wiederherstellen.
> Verwenden Sie zuerst den N-Modus und prüfen Sie die Ergebnisse, bevor Sie den Y-Modus verwenden. Bitte lesen Sie zuerst [Einschränkungen](#einschränkungen).

## Erwartete Ergebnisse

Wenn Sie das Skript ausführen:

- Es findet Dateien der Formate mp4, mkv, mov, avi, wmv, flv, webm, m4v, ts, mts, m2ts, mpg und mpeg im Ordner und seinen Unterordnern.
- Videos, die bereits in AV1 vorliegen, werden nicht konvertiert.
- Bei Videos ab 1 Minute Länge kodiert es zuerst 10 Sekunden aus der Mitte. Liegt die geschätzte Größe über 90% des Originals, wird das Video nicht konvertiert.
- Ist ein fertiges Ergebnis genauso groß wie das Original oder größer, wird das Ergebnis verworfen und das Original behalten.
- Ein Video wird nicht konvertiert, wenn etwas darin nicht erhalten bleiben kann: 4:2:2-, 4:4:4- und 12-Bit-Videos, Datenspuren, die sich nicht kopieren lassen, sowie Cover in mkv. Bei HDR10+, Dolby-Vision-Profil 7 und Transparenz wählen Sie beim Start.
- Schlägt eine Konvertierung fehl, wird das Original nicht gelöscht.
- Die AV1-Prüfung und das Kodieren laufen gleichzeitig. Kodiert wird jeweils nur eine Datei.
- Die Ergebnisse werden in einem Protokoll festgehalten. Bei einem erneuten Start werden Videos aus dem Protokoll sofort und ohne Prüfung übersprungen, sodass Sie nach einem Abbruch weitermachen können.

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

Die Dateiendung bleibt dieselbe wie beim Original. Ausnahmen sind mov, m4v, ts, mts, m2ts, mpg und mpeg: Diese Formate können kein AV1 enthalten und werden als `.mp4` gespeichert. Lässt sich eine Spur in diesem Format nicht speichern, wird das Ergebnis als `.mkv` gespeichert.

### Was nach der Konvertierung erhalten bleibt

Diese Ergebnisse wurden mit Testvideos überprüft.

| Element | Ergebnis |
|---|---|
| Erste Videospur | Wird nach AV1 konvertiert |
| Audiospuren (einschließlich mehrerer Spuren und Sprach-Tags) | Bleiben erhalten. Werden unverändert kopiert. Beim Speichern als mp4 werden inkompatible Formate in AAC 192 kbps konvertiert |
| Kapitel, Tags (Titel, Kommentar, Erstellungszeit und andere) | Bleiben erhalten |
| 10-Bit | Bleibt erhalten |
| HDR10 (BT.2020, PQ, Mastering-Display-Daten) | Bleibt erhalten (mit NVENC geprüft) |
| Drehung | Das Bild selbst wird beim Speichern gedreht. Es sieht gleich aus |
| VR-Metadaten (sphärisch, Stereo-3D) | Bleiben erhalten (mit einem echten VR-Video geprüft) |
| Dateidatum (Erstellung, Änderung) | Bleibt erhalten |
| Timecode | Bleibt erhalten |
| Untertitelspuren | Bleiben erhalten. Werden unverändert kopiert |
| Zweite und weitere Videospuren | Bleiben erhalten. Werden unverändert kopiert und daher nicht kleiner |
| Cover, Schriften und andere Anhänge | Bleiben erhalten |
| Dolby Vision (Profil 8 mit einem echten Video geprüft) | Bleibt erhalten. Solche Videos werden auf der CPU mit SVT-AV1 kodiert, das Ergebnis ist Profil 10 |
| Untertitel innerhalb der Videospur | Bleiben mit NVENC erhalten. Mit anderen Encodern wird das Video nicht konvertiert |
| XMP in mp4 und mov (auf Dateiebene) | Bleibt erhalten |
| **4:2:2-, 4:4:4- und 12-Bit-Video** | **Wird nicht konvertiert.** Das Original bleibt unverändert |
| **Datenspuren, die sich nicht kopieren lassen (GPS und andere)** | **Wird nicht konvertiert.** Das Original bleibt unverändert |
| **Cover in mkv** | **Wird nicht konvertiert.** ffmpeg würde es in eine Videospur umwandeln, daher bleibt das Original unverändert |
| **HDR10+** | **Wird beim Start gewählt** (überspringen, trotzdem konvertieren oder Original behalten) |
| **Transparenz** | **Wird beim Start gewählt** (überspringen, trotzdem konvertieren oder Original behalten) |
| **Dolby-Vision-Profil 7** | **Wird beim Start gewählt** (überspringen, trotzdem konvertieren oder Original behalten) |

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
4. Wählen Sie, was mit Videos geschieht, die HDR10+, Dolby-Vision-Profil 7 oder Transparenz verlieren würden.

Der Fortschritt der Prüfung wird im Fenstertitel angezeigt. Sie können mehrere Fenster gleichzeitig laufen lassen, auch für denselben Ordner, aber jedes Fenster wird dann langsamer. Treffen zwei Fenster auf dasselbe Video, konvertiert eines es und das andere macht mit dem nächsten weiter.

**Zum Beenden**: Schließen Sie das Fenster. Die Datei `name.part.ext` der laufenden Konvertierung bleibt zurück, löschen Sie sie also selbst.

### Videos, die nicht alles behalten können

Vor Arbeitsbeginn werden zwei Fragen gestellt: eine zu HDR10+ und Dolby-Vision-Profil 7, eine zur Transparenz.

| Auswahl | Ergebnis |
|---|---|
| 1 | Das Video wird übersprungen, das Original bleibt unverändert |
| 2 | Das Video wird trotzdem konvertiert, und was nicht erhalten bleiben kann, geht verloren. Im Y-Modus wird das Original gelöscht |
| 3 (nur Y-Modus) | Das Original bleibt erhalten, das Ergebnis wird in einem Ordner `av1\` gespeichert |

Ein so übersprungenes Video wird erneut geprüft, wenn Sie bei einem späteren Start anders antworten. Ein Video mit Transparenz, das auch 4:4:4 ist, wird beim Konvertieren auf 4:2:0 reduziert.

### Einstellungen

Ändern Sie diese Werte im oberen Bereich der bat-Datei.

| Wert | Standard | Bedeutung |
|---|---|---|
| `CQ` | 30 | Qualität (0-63). Niedriger bedeutet bessere Qualität und größere Dateien. Gilt gleichermaßen für jedes Video |
| `JOBS` | 8 | Wie viele Dateien gleichzeitig auf AV1 geprüft werden |
| `MIN_SAVE` | 10 | Nicht konvertieren, wenn die geschätzte Ersparnis (%) unter diesem Wert liegt |
| `LOG` | `convert_av1.log` neben der bat-Datei | Wohin die Ergebnisse geschrieben werden |

### Ergebnisprotokoll

Die Ergebnisse werden als tabulatorgetrennter Text an `convert_av1.log` neben der bat-Datei angehängt. Alle Ordner und Fenster verwenden diese eine Datei gemeinsam.

| Ergebnis | Bedeutung | Beim nächsten Start |
|---|---|---|
| `converted`, `result` | Das konvertierte Video und die dabei erzeugte Datei | Übersprungen |
| `av1` | Bereits AV1 | Übersprungen |
| `skip-exists`, `skip-larger`, `skip-little-gain`, `skip-not-smaller`, `skip-color`, `skip-data`, `skip-cover`, `skip-dovi`, `skip-hdr10plus`, `skip-captions`, `skip-alpha` | Nicht konvertiert | Übersprungen, solange Encoder, `CQ` und `MIN_SAVE` gleich bleiben |
| `failed` | Konvertierung fehlgeschlagen | Neuer Versuch |

- Ein Video wird an Pfad, Größe und Änderungszeit erkannt. Ändert sich eines davon, wird es erneut geprüft.
- Eine abgebrochene Konvertierung wird nicht festgehalten und beginnt daher wieder von vorn.
- Um alle Videos erneut zu prüfen, löschen Sie das Protokoll.

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
| Alle 23100 auf einer lokalen SSD verarbeiten (alle bereits AV1) | 239 Sekunden |
| Alle 23100 auf einer lokalen SSD erneut starten (alle im Protokoll) | 2.3 Sekunden |

## Einschränkungen

### Risiko von Datenverlust

- **Dolby Vision wurde nur mit Profil 8 geprüft.** Nur wenige Geräte und Player können Dolby Vision in AV1 (Profil 10) abspielen. Verwenden Sie bei Bedarf zuerst den N-Modus.
- **Das Löschen im Y-Modus kann nicht rückgängig gemacht werden.** Es verwendet `del`, daher landet nichts im Papierkorb.
- **Ergebnisse werden zur Prüfung nicht abgespielt.** Der Erfolg wird nur anhand des Exit-Codes von ffmpeg und der Dateigröße beurteilt. Ist das Video beschädigt, meldet ffmpeg aber Erfolg, wird das Original im Y-Modus gelöscht.
- **Die AV1-Konvertierung ist verlustbehaftet.** Das Komprimieren eines bereits komprimierten Videos macht die Qualität nie besser als die des Originals.
- **4:2:2-, 4:4:4- und 12-Bit-Videos werden nicht kleiner.** Die hier verwendeten AV1-Encoder unterstützen nur 4:2:0, daher bleiben solche Videos unverändert.

### Wo Entscheidungen falsch sein können

- **Die Schätzung betrachtet nur die mittleren 10 Sekunden.** In Tests kam ein auf 30% geschätztes Video tatsächlich auf 45%. Videos, die kleiner geworden wären, können übersprungen werden.
- **Videos unter 1 Minute werden nicht vorab geprüft.** Die Größe wird erst nach der Konvertierung verglichen.
- **Kann ffprobe eine Datei nicht lesen, wird sie als Nicht-AV1-Datei behandelt.** Eine Datei, die bereits AV1 ist, wird dann möglicherweise erneut kodiert.
- **Videos im Protokoll werden nicht mehr angesehen.** Wenn Sie ein Ergebnis löschen, wird es erst wieder erstellt, nachdem Sie die Zeilen dieses Videos oder das ganze Protokoll gelöscht haben.
- **Eingebettete Untertitel und HDR10+ werden nur in den ersten 5 Bildern gesucht.** Beginnen sie später, wird das Video trotzdem konvertiert und HDR10+ geht verloren. Die Untertitel ebenfalls, außer mit NVENC.

### Wiedergabe und Kompatibilität

- Ältere Geräte und Player können AV1 nicht abspielen.
- avi, wmv und flv behalten ihre Dateiendung, aber AV1 in diesen Formaten ist keine Standardkombination, und viele Player spielen sie nicht ab.

### Dateinamen und Ordner

- Wenn Ergebnisnamen kollidieren, wie bei `a.mov` und `a.mp4`, wird die später verarbeitete Datei übersprungen.
- Dateien mit Namen wie `name.part.mp4` werden nie konvertiert, weil unfertige Ergebnisse so heißen. Eine nach dem Beenden zurückgebliebene Datei wird überschrieben, wenn dieses Video erneut konvertiert wird. Sie können sie auch selbst löschen.
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
- Das Änderungsdatum bleibt erhalten, auch nach erneutem Einbinden. Ein Mount zeigt das Änderungsdatum auch als Erstellungsdatum an, ein eigenes Erstellungsdatum gibt es also nicht.
- Diese Punkte wurden auf crypt-Mounts über lokalen Laufwerken getestet, nicht mit Cloud-Speicher.

### Nicht getestet

- **Echtes Kodieren mit Intel QSV und AMD AMF wurde nicht ausprobiert.** Solche Hardware war nicht vorhanden, daher wurde nur das Parsen der Optionen geprüft. Ob die Qualität dem CQ von NVENC entspricht, ist ebenfalls unbekannt.
- Grafikkarten mit nur einer NVENC-Engine (nur die Umschaltung wurde geprüft, indem ein Ausfall des 2-Engine-Modus simuliert wurde)
- Umgebungen ohne NVENC wurden simuliert, indem die Grafikkarte verborgen wurde. Auf echten AMD- oder Intel-PCs wurde das Skript nicht ausgeführt.
- Pfade mit mehr als 260 Zeichen

## Lizenz

[MIT](LICENSE)

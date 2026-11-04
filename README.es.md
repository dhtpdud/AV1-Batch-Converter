# convert-av1

[English](README.md) | [한국어](README.ko.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | **Español** | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [Русский](README.ru.md) | [العربية](README.ar.md) | [हिन्दी](README.hi.md)

Script por lotes de Windows que convierte a AV1 todos los videos de una carpeta y sus subcarpetas.
Usa primero NVIDIA NVENC y, si NVENC no está disponible, cambia automáticamente a otro codificador.

> [!WARNING]
> **Las pistas de subtítulos no se conservan en el resultado.** En el modo Y (eliminar los originales), los subtítulos del original se pierden con él y no se pueden recuperar.
> Usa primero el modo N y revisa los resultados antes de usar el modo Y. Por favor, lee primero las [Limitaciones](#limitaciones).

## Resultados esperados

Al ejecutar el script:

- Busca archivos mp4, mkv, mov, avi, wmv, flv, webm, m4v, ts, mts, m2ts, mpg y mpeg en la carpeta y sus subcarpetas.
- Los videos que ya están en AV1 no se convierten.
- En los videos de 1 minuto o más, primero codifica 10 segundos de la parte central. Si el tamaño estimado supera el 90% del original, el video no se convierte.
- Si el resultado final tiene el mismo tamaño que el original o es mayor, se descarta y se conserva el original.
- Si una conversión falla, el original no se elimina.
- La comprobación de AV1 y la codificación se ejecutan al mismo tiempo. La codificación procesa un archivo a la vez.
- Al volver a ejecutarlo, omite los archivos ya procesados, así que puedes continuar después de detenerlo.

**No todos los videos reducen su tamaño.** Los videos que ya están bien comprimidos se omiten, y el ahorro varía de un video a otro.

### Cuánto se reducen

**Desde el 0% (no se convierte, se conserva el original) hasta un máximo medido del 96%.** Los archivos nunca aumentan de tamaño, porque un resultado del mismo tamaño o mayor se descarta.

Estos resultados proceden de 52 videos reales elegidos al azar de un mismo PC, con la configuración predeterminada (NVENC, CQ 30).

| Caso | Tamaño respecto al original | Ahorro |
|---|---|---|
| Mayor ahorro | 4% | 96% |
| Mediana de los 41 videos convertidos | 44% | 56% |
| Menor ahorro entre los videos convertidos | 89% | 11% |
| Los 11 videos omitidos (tamaño estimado 96-233%) | 100% (se conserva el original) | 0% |

| Códec de origen | Muestra | Convertidos | Tamaño de los videos convertidos respecto al original |
|---|---|---|---|
| H.264 | 25 | 18 | 4-89% |
| HEVC | 25 | 21 | 15-88% |
| VP9, MPEG-4 | 1 de cada uno | 2 | 81%, 23% |

Cuanto mayor es la tasa de bits de origen, mayor es el ahorro. La mediana del tamaño, incluidos los videos omitidos, fue del 76% por debajo de 5 Mbps, del 50% con 5-15 Mbps y del 27% con 15-40 Mbps.

Estas cifras no son una garantía.

- Cada video se comparó solo en la pista de video, usando 10 segundos en cada uno de los puntos del 25%, 50% y 75%, 30 segundos en total. No son resultados de convertir archivos completos.
- El audio normalmente se copia tal cual, así que los archivos reales se reducen menos que estas cifras.
- Solo se midieron videos de 1 minuto o más, y son la colección de una sola persona. El rango puede ser distinto con otros videos.
- Solo se midió NVENC. Otros codificadores y otros valores de `CQ` dan resultados diferentes.
- Si la estimación previa a la conversión es errónea, puede quedar un resultado que ahorre menos del 10%.

### Dónde se guardan los resultados

| Modo | Se guarda en | Original |
|---|---|---|
| N (recomendado) | Una carpeta `av1\` dentro de cada carpeta | Se conserva |
| Y | Donde estaba el original | **Se elimina permanentemente** tras una conversión correcta (no va a la Papelera de reciclaje) |

La extensión se mantiene igual que la del original. Las excepciones son mov, m4v, ts, mts, m2ts, mpg y mpeg, que no admiten AV1 y se guardan como `.mp4`.

### Qué se conserva tras la conversión

Estos resultados se comprobaron con videos de prueba.

| Elemento | Resultado |
|---|---|
| Primera pista de video | Se convierte a AV1 |
| Pistas de audio (incluidas varias pistas y etiquetas de idioma) | Se conservan. Se copian tal cual. Al guardar en mp4, los formatos incompatibles se convierten a AAC 192 kbps |
| Capítulos, título | Se conservan |
| 10 bits | Se conserva |
| HDR10 (BT.2020, PQ, datos de la pantalla de masterización) | Se conserva (comprobado con NVENC) |
| Rotación | La propia imagen se gira al guardar. Se ve igual |
| **Pistas de subtítulos** | **Se pierden** |
| **Segunda pista de video y siguientes** | **Se pierden** |
| **Color 4:2:2 y 4:4:4** | **Se reduce a 4:2:0** |

## Requisitos

- Windows 10 u 11
- `ffmpeg` y `ffprobe` en el PATH
- Al menos uno de los codificadores siguientes

| Orden | Codificador | Necesita |
|---|---|---|
| 1 | NVENC (`av1_nvenc`), 2 motores | Una tarjeta gráfica NVIDIA con 2 codificadores AV1, como la RTX 4070 Ti |
| 2 | NVENC (`av1_nvenc`), 1 motor | Una tarjeta gráfica NVIDIA compatible con AV1 (serie RTX 40 o posterior) |
| 3 | Intel Quick Sync (`av1_qsv`) | Gráficos Intel con codificación AV1 |
| 4 | AMD AMF (`av1_amf`) | Gráficos AMD con codificación AV1 |
| 5 | CPU (`libsvtav1`, preset 10) | Una compilación de ffmpeg que incluya SVT-AV1 |

Al iniciarse, el script hace una codificación de prueba real en este orden y usa el primero que funciona. El codificador en uso se muestra en la línea `Encoder: ...`.

## Uso

1. Descarga `convert_av1.bat` desde [Releases](../../releases/latest).
2. Arrastra la carpeta que quieres convertir sobre el archivo bat, o ejecuta el archivo bat y escribe la ruta de la carpeta.
3. Comprueba la carpeta objetivo y elige `Y` (eliminar los originales) o `N` (conservar los originales).

El progreso de la comprobación se muestra en el título de la ventana. Puedes ejecutar varias ventanas con carpetas diferentes al mismo tiempo, pero cada ventana irá más lenta.

**Para detenerlo**: cierra la ventana. El archivo `name.part.ext` de la conversión en curso se queda ahí, así que elimínalo manualmente.

### Configuración

Cambia estos valores cerca del principio del archivo bat.

| Valor | Predeterminado | Significado |
|---|---|---|
| `CQ` | 30 | Calidad (0-63). Un valor más bajo significa mejor calidad y archivos más grandes. Se aplica por igual a todos los videos |
| `JOBS` | 8 | Cuántos archivos se comprueban a la vez para detectar AV1 |
| `MIN_SAVE` | 10 | No convertir si el ahorro estimado (%) es inferior a este valor |

## Mediciones

Medido con una RTX 4070 Ti, un i7-13700KF, Windows 11 y una compilación de ffmpeg de 2026-10. Los resultados serán distintos en otros entornos.

### Velocidad de codificación

| Resolución | NVENC, 1 motor | NVENC, 2 motores | CPU SVT-AV1 preset 10 |
|---|---|---|---|
| 8K (7680×3840) | 31 fps | 55 fps | Unos 14 fps |
| 4K | 107 fps | 189 fps | No medido |
| 1080p | 400 fps | 574 fps | Unos 518 fps |

Las mediciones de CPU se tomaron mientras se ejecutaban otras conversiones. Codificadores por software comparados a 1080p: SVT-AV1 unos 518 fps, libaom unos 173 fps, rav1e unos 5 fps.

### CQ y tamaño de archivo

Resultados de convertir con NVENC un fragmento de 20 segundos de un video HEVC 8K (origen 30 Mbps). Es un ejemplo de un video ya bien comprimido que aumenta de tamaño con CQ 30.

| CQ | Tasa de bits | SSIM (respecto al original) | Decisión |
|---|---|---|---|
| 30 | 53.9 Mbps | 0.9955 | Omitido porque aumenta de tamaño |
| 36 | 28.8 Mbps | 0.9936 | Omitido porque el ahorro es pequeño |
| 42 | 14.3 Mbps | 0.9900 | Convertido |

Para reducir videos como este hay que subir `CQ`, lo que también baja la calidad de todos los demás videos.

### Grandes cantidades de archivos

| Elemento | Resultado |
|---|---|
| Encontrar 23,100 videos en un SSD local | 0.6 segundos |
| Encontrar 22,887 videos en un montaje crypt de rclone | 8.9 segundos |
| Procesar los 23,100 en un SSD local (todos ya en AV1) | 224 segundos |

## Limitaciones

### Riesgo de pérdida de datos

- **Las pistas de subtítulos se pierden.** Lo mismo ocurre con la segunda pista de video y las siguientes. No uses el modo Y en archivos que las necesiten.
- **La eliminación en el modo Y no se puede deshacer.** Usa `del`, así que nada va a la Papelera de reciclaje.
- **Los resultados no se reproducen para comprobarlos.** El éxito se determina solo por el código de salida de ffmpeg y el tamaño del archivo. Si el video está dañado pero ffmpeg indica que todo salió bien, en el modo Y se elimina el original.
- **La conversión a AV1 tiene pérdidas.** Comprimir un video ya comprimido nunca hace que la calidad sea mejor que la del original.
- **Los videos 4:2:2 y 4:4:4 pierden resolución de color al reducirse a 4:2:0.** Usa el modo N con el material que pienses editar o al que vayas a aplicar corrección de color.

### Dónde pueden fallar las decisiones

- **La estimación solo mira los 10 segundos centrales.** En las pruebas, un video estimado en el 30% acabó en el 45%. Se pueden omitir videos que sí se habrían reducido.
- **Los videos de menos de 1 minuto no se comprueban de antemano.** El tamaño solo se compara después de la conversión.
- **Si ffprobe no puede leer un archivo, se trata como si no fuera AV1.** Un archivo que ya está en AV1 puede volver a codificarse.

### Reproducción y compatibilidad

- Los dispositivos y reproductores antiguos no pueden reproducir AV1.
- avi, wmv y flv conservan su extensión, pero AV1 en estos formatos no es una combinación estándar y muchos reproductores no lo reproducirán.

### Nombres de archivo y carpetas

- Si los nombres de los resultados coinciden, como con `a.mov` y `a.mp4`, se omite el archivo que va después.
- Un `name.part.mp4` que quede tras detener el proceso se trata como un video normal en la siguiente ejecución. Elimínalo manualmente.
- Los puntos de unión y las carpetas de enlaces simbólicos no se examinan.

### Entorno

- **Los mensajes en pantalla están en inglés.**
- **Solo se ha probado en Windows 11 en coreano.** El archivo bat usa solo caracteres ASCII, así que no depende del idioma del sistema. Se confirmó que funciona con las páginas de códigos de consola 437, 949 y 65001, pero no se ha ejecutado en Windows en otros idiomas.
- **No sobrescribas un archivo bat que esté usando una ventana en ejecución.** cmd lee el archivo poco a poco, así que una ventana en ejecución podría ejecutar líneas equivocadas.
- La codificación por CPU es mucho más lenta: unos 14 fps en 8K.
- Si ffmpeg no incluye `libsvtav1`, el script no puede cambiar a la CPU y termina con un error.

### Uso en un montaje de rclone

- `--vfs-cache-mode writes` es obligatorio. Con `off`, no se pueden escribir mp4 ni mkv y todos los archivos fallan.
- En el modo Y, **los originales se eliminan antes de que termine la subida.** Si la subida falla, dependes de la copia que quede en la caché, así que ten cuidado.
- Los archivos que se están subiendo no se eliminan de la caché aunque superen `--vfs-cache-max-age` y `--vfs-cache-max-size`, así que la unidad de la caché necesita espacio libre.
- Estos puntos se probaron con un remote crypt local. La versión actual solo se confirmó en un montaje real hasta la búsqueda de archivos, y no se probó con almacenamiento en la nube.

### Sin probar

- **La codificación real con Intel QSV y AMD AMF no se ha probado.** No se disponía de ese hardware, así que solo se comprobó el análisis de las opciones. Tampoco se sabe si la calidad coincide con el CQ de NVENC.
- Tarjetas gráficas con un solo motor NVENC (solo se comprobó el cambio, simulando un fallo del modo de 2 motores)
- Los entornos sin NVENC se simularon ocultando la tarjeta gráfica. No se ha ejecutado en PC reales con AMD o Intel.
- Si se conservan los metadatos de VR (esféricos) y Dolby Vision
- Si se conservan los datos HDR con la codificación por CPU
- Rutas de más de 260 caracteres

## Licencia

[MIT](LICENSE)

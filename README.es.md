# AV1 Batch Converter

[English](README.md) | [한국어](README.ko.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | **Español** | [Français](README.fr.md) | [Deutsch](README.de.md) | [Português](README.pt-BR.md) | [Русский](README.ru.md) | [العربية](README.ar.md) | [हिन्दी](README.hi.md)

Script por lotes de Windows que convierte a AV1 todos los videos de una carpeta y sus subcarpetas.
Usa primero NVIDIA NVENC y, si NVENC no está disponible, cambia automáticamente a otro codificador.

> [!WARNING]
> **El modo Y (eliminar los originales) no se puede deshacer.** La conversión a AV1 tiene pérdida de calidad y el original no se puede recuperar después.
> Usa primero el modo N y revisa los resultados antes de usar el modo Y. Por favor, lee primero las [Limitaciones](#limitaciones).

## Resultados esperados

Al ejecutar el script:

- Busca archivos mp4, mkv, mov, avi, wmv, flv, webm, m4v, ts, mts, m2ts, mpg y mpeg en la carpeta y sus subcarpetas.
- Los videos que ya están en AV1 no se convierten.
- En los videos de 1 minuto o más, primero codifica 10 segundos de la parte central. Si el tamaño estimado supera el 90% del original, el video no se convierte.
- Si el resultado final tiene el mismo tamaño que el original o es mayor, se descarta y se conserva el original.
- Un video no se convierte si algo de su contenido no se puede conservar: video 4:2:2, 4:4:4 y de 12 bits, pistas de datos que no se pueden copiar y carátulas en mkv. Para HDR10+, Dolby Vision perfil 7 y transparencia, eliges al empezar.
- Si una conversión falla, el original no se elimina.
- La comprobación de AV1 y la codificación se ejecutan al mismo tiempo. La codificación procesa un archivo a la vez.
- Los resultados se registran en un log. Al volver a ejecutarlo, los videos del log se omiten de inmediato, sin comprobarlos, así que puedes continuar después de detenerlo.

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

Cuanto mayor es la tasa de bits de origen, mayor es el ahorro. Con un origen de menos de 5 Mbps, la mediana del tamaño respecto al original, incluidos los videos omitidos, fue del 76%; con 5-15 Mbps, del 50%, y con 15-40 Mbps, del 27%.

Estas cifras no son una garantía.

- Cada video se comparó solo en la pista de video, usando 10 segundos en cada uno de los puntos del 25%, 50% y 75%, 30 segundos en total. No son resultados de convertir archivos completos.
- El audio normalmente se copia tal cual, así que los archivos reales se reducen menos de lo que indican estas cifras.
- Solo se midieron videos de 1 minuto o más, y son la colección de una sola persona. El rango puede ser distinto con otros videos.
- Solo se midió NVENC. Otros codificadores y otros valores de `CQ` dan resultados diferentes.
- Si la estimación previa a la conversión es errónea, puede quedar un resultado que ahorre menos del 10%.

### Dónde se guardan los resultados

| Modo | Se guarda en | Original |
|---|---|---|
| N (recomendado) | Una carpeta `av1\` dentro de cada carpeta | Se conserva |
| Y | Donde estaba el original | **Se elimina permanentemente** tras una conversión correcta (no va a la Papelera de reciclaje) |

La extensión se mantiene igual que la del original. Las excepciones son mov, m4v, ts, mts, m2ts, mpg y mpeg, que no admiten AV1 y se guardan como `.mp4`. Si una pista no se puede guardar en ese formato, el resultado se guarda como `.mkv`.

### Qué se conserva tras la conversión

Estos resultados se comprobaron con videos de prueba.

| Elemento | Resultado |
|---|---|
| Primera pista de video | Se convierte a AV1 |
| Pistas de audio (incluidas varias pistas y etiquetas de idioma) | Se conservan. Se copian tal cual. Al guardar en mp4, los formatos incompatibles se convierten a AAC 192 kbps |
| Capítulos, etiquetas (título, comentario, fecha de creación y otras) | Se conservan |
| 10 bits | Se conserva |
| HDR10 (BT.2020, PQ, datos de la pantalla de masterización) | Se conserva (comprobado con NVENC) |
| Rotación | La propia imagen se gira al guardar. Se ve igual |
| Metadatos de VR (esféricos, 3D estéreo) | Se conservan (comprobado con un video VR real) |
| Fechas del archivo (creación, modificación) | Se conservan |
| Código de tiempo | Se conserva |
| Pistas de subtítulos | Se conservan. Se copian tal cual |
| Segunda pista de video y siguientes | Se conservan. Se copian tal cual, así que no se reducen |
| Carátula, fuentes y otros adjuntos | Se conservan |
| Dolby Vision (perfil 8 comprobado con un video real) | Se conserva. Estos videos se codifican con SVT-AV1 en la CPU y el resultado es perfil 10 |
| Subtítulos dentro de la pista de video | Se conservan con NVENC. Con otros codificadores el video no se convierte |
| XMP en mp4 y mov (a nivel de archivo) | Se conserva |
| **Video 4:2:2, 4:4:4 y de 12 bits** | **No se convierte.** El original queda igual |
| **Pistas de datos que no se pueden copiar (GPS y otras)** | **No se convierte.** El original queda igual |
| **Carátula en mkv** | **No se convierte.** ffmpeg la convertiría en una pista de video, así que el original queda igual |
| **HDR10+** | **Se elige al empezar** (omitir, convertir igualmente o conservar el original) |
| **Transparencia** | **Se elige al empezar** (omitir, convertir igualmente o conservar el original) |
| **Dolby Vision perfil 7** | **Se elige al empezar** (omitir, convertir igualmente o conservar el original) |

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
4. Elige qué hacer con los videos que perderían HDR10+, Dolby Vision perfil 7 o la transparencia.

El progreso de la comprobación se muestra en el título de la ventana. Puedes ejecutar varias ventanas al mismo tiempo, incluso con la misma carpeta, pero cada ventana irá más lenta. Si dos ventanas llegan al mismo video, una lo convierte y la otra pasa al siguiente.

**Para detenerlo**: cierra la ventana. El archivo `name.part.ext` de la conversión en curso se queda ahí, así que elimínalo manualmente.

### Videos que no pueden conservarlo todo

Antes de empezar se hacen dos preguntas: una sobre HDR10+ y Dolby Vision perfil 7, y otra sobre la transparencia.

| Opción | Qué ocurre |
|---|---|
| 1 | El video se omite y el original queda igual |
| 2 | El video se convierte igualmente y se pierde lo que no se puede conservar. En el modo Y se elimina el original |
| 3 (solo modo Y) | Se conserva el original y el resultado se guarda en una carpeta `av1\` |

Un video omitido así se vuelve a comprobar si respondes de otra forma en una ejecución posterior. Un video con transparencia que además sea 4:4:4 se reduce a 4:2:0 al convertirlo.

### Configuración

Cambia estos valores cerca del principio del archivo bat.

| Valor | Predeterminado | Significado |
|---|---|---|
| `CQ` | 30 | Calidad (0-63). Un valor más bajo significa mejor calidad y archivos más grandes. Se aplica por igual a todos los videos |
| `JOBS` | 8 | Cuántos archivos se comprueban a la vez para detectar AV1 |
| `MIN_SAVE` | 10 | No convertir si el ahorro estimado (%) es inferior a este valor |
| `LOG` | `convert_av1.log` junto al archivo bat | Dónde se registran los resultados |

### Log de resultados

Los resultados se añaden a `convert_av1.log`, junto al archivo bat, como texto separado por tabulaciones. Todas las carpetas y ventanas comparten este único archivo.

| Resultado | Significado | En la siguiente ejecución |
|---|---|---|
| `converted`, `result` | El video convertido y el archivo que produjo | Se omite |
| `av1` | Ya está en AV1 | Se omite |
| `skip-exists`, `skip-larger`, `skip-little-gain`, `skip-not-smaller`, `skip-color`, `skip-data`, `skip-cover`, `skip-dovi`, `skip-hdr10plus`, `skip-captions`, `skip-alpha` | No se convirtió | Se omite mientras el codificador, `CQ` y `MIN_SAVE` no cambien |
| `failed` | La conversión falló | Se vuelve a intentar |

- Cada video se identifica por su ruta, su tamaño y su fecha de modificación. Si cambia alguno de estos datos, se vuelve a comprobar.
- Una conversión detenida no se registra, así que vuelve a empezar desde el principio.
- Para comprobar de nuevo todos los videos, elimina el log.

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
| Encontrar 23100 videos en un SSD local | 0.6 segundos |
| Encontrar 22887 videos en un montaje crypt de rclone | 8.9 segundos |
| Procesar los 23100 en un SSD local (todos ya en AV1) | 239 segundos |
| Volver a ejecutar los 23100 en un SSD local (todos en el log) | 2.3 segundos |

## Limitaciones

### Riesgo de pérdida de datos

- **Dolby Vision solo se ha comprobado con el perfil 8.** Pocos dispositivos y reproductores pueden reproducir Dolby Vision en AV1 (perfil 10). Si lo necesitas, usa primero el modo N.
- **La eliminación en el modo Y no se puede deshacer.** Usa `del`, así que nada va a la Papelera de reciclaje.
- **Los resultados no se reproducen para comprobarlos.** El éxito se determina solo por el código de salida de ffmpeg y el tamaño del archivo. Si el video está dañado pero ffmpeg indica que todo salió bien, en el modo Y se elimina el original.
- **La conversión a AV1 tiene pérdidas.** Comprimir un video ya comprimido nunca hace que la calidad sea mejor que la del original.
- **Los videos 4:2:2, 4:4:4 y de 12 bits no se reducen.** Los codificadores AV1 que se usan aquí solo admiten 4:2:0, así que estos videos quedan igual.

### Dónde pueden fallar las decisiones

- **La estimación solo mira los 10 segundos centrales.** En las pruebas, un video estimado en el 30% acabó en el 45%. Se pueden omitir videos que sí se habrían reducido.
- **Los videos de menos de 1 minuto no se comprueban de antemano.** El tamaño solo se compara después de la conversión.
- **Si ffprobe no puede leer un archivo, se trata como si no fuera AV1.** Un archivo que ya está en AV1 puede volver a codificarse.
- **Los videos del log no se vuelven a examinar.** Si eliminas un resultado, no se genera de nuevo hasta que elimines las líneas de ese video del log o el log completo.
- **Los subtítulos incrustados y HDR10+ solo se buscan en los primeros 5 fotogramas.** Si empiezan más tarde, el video se convierte igualmente y HDR10+ se pierde. Los subtítulos también, salvo con NVENC.

### Reproducción y compatibilidad

- Los dispositivos y reproductores antiguos no pueden reproducir AV1.
- avi, wmv y flv conservan su extensión, pero AV1 en estos formatos no es una combinación estándar y muchos reproductores no lo reproducirán.

### Nombres de archivo y carpetas

- Si los nombres de los resultados coinciden, como con `a.mov` y `a.mp4`, se omite el archivo que se procese después.
- Los archivos con nombres como `name.part.mp4` nunca se convierten, porque así se llaman los resultados sin terminar. Uno que quede tras detener el proceso se sobrescribe al volver a convertir ese video, o puedes eliminarlo manualmente.
- Los puntos de unión y las carpetas de vínculos simbólicos no se examinan.

### Entorno

- **Los mensajes en pantalla están en inglés.**
- **Solo se ha probado en Windows 11 en coreano.** El archivo bat usa solo caracteres ASCII, así que no depende del idioma del sistema. Se confirmó que funciona con las páginas de códigos de consola 437, 949 y 65001, pero no se ha ejecutado en Windows en otros idiomas.
- **No sobrescribas un archivo bat que esté usando una ventana en ejecución.** cmd lee el archivo poco a poco, así que una ventana en ejecución podría ejecutar líneas equivocadas.
- La codificación por CPU es mucho más lenta: unos 14 fps en 8K.
- Si ffmpeg no incluye `libsvtav1`, el script no puede cambiar a la CPU y termina con un error.

### Uso en un montaje de rclone

- `--vfs-cache-mode writes` es obligatorio. Con `off`, no se pueden escribir mp4 ni mkv y todos los archivos fallan.
- En el modo Y, **los originales se eliminan antes de que termine la subida.** Si la subida falla, dependes de la copia que quede en la caché, así que ten cuidado.
- Los archivos que se están subiendo no se eliminan de la caché aunque se superen `--vfs-cache-max-age` y `--vfs-cache-max-size`, así que la unidad de la caché necesita espacio libre.
- La fecha de modificación se conserva, también después de volver a montar. El montaje muestra la fecha de modificación también como fecha de creación, así que no hay una fecha de creación aparte que conservar.
- Estos puntos se probaron en montajes crypt sobre unidades locales, no con almacenamiento en la nube.

### Sin probar

- **La codificación real con Intel QSV y AMD AMF no se ha probado.** No se disponía de ese hardware, así que solo se comprobó el análisis de las opciones. Tampoco se sabe si la calidad coincide con el CQ de NVENC.
- Tarjetas gráficas con un solo motor NVENC (solo se comprobó el cambio, simulando un fallo del modo de 2 motores)
- Los entornos sin NVENC se simularon ocultando la tarjeta gráfica. No se ha ejecutado en PC reales con AMD o Intel.
- Rutas de más de 260 caracteres

## Licencia

[MIT](LICENSE)

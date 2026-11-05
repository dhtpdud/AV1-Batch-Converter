# AV1 Batch Converter

[English](README.md) | [한국어](README.ko.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | **Português** | [Русский](README.ru.md) | [العربية](README.ar.md) | [हिन्दी](README.hi.md)

Script em lote do Windows que converte para AV1 todos os vídeos de uma pasta e de suas subpastas.
Ele usa primeiro o NVIDIA NVENC e troca automaticamente para outro codificador se o NVENC não estiver disponível.

> [!WARNING]
> **O modo Y (excluir os originais) não pode ser desfeito.** A conversão para AV1 tem perda de qualidade, e o original não pode ser recuperado depois.
> Use primeiro o modo N e confira os resultados antes de usar o modo Y. Por favor, leia primeiro as [Limitações](#limitações).

## Resultados esperados

Ao executar o script:

- Ele encontra arquivos mp4, mkv, mov, avi, wmv, flv, webm, m4v, ts, mts, m2ts, mpg e mpeg na pasta e em suas subpastas.
- Vídeos que já estão em AV1 não são convertidos.
- Em vídeos de 1 minuto ou mais, ele primeiro codifica 10 segundos do meio. Se o tamanho estimado passar de 90% do original, o vídeo não é convertido.
- Se o resultado final tiver o mesmo tamanho do original ou for maior, ele é descartado e o original é mantido.
- Um vídeo não é convertido se algo nele não puder ser mantido: vídeo 4:2:2, 4:4:4 e de 12 bits, faixas de dados que não podem ser copiadas e capas em mkv. Para HDR10+, Dolby Vision perfil 7 e transparência, você escolhe no início.
- Se uma conversão falhar, o original não é excluído.
- A verificação de AV1 e a codificação acontecem ao mesmo tempo. A codificação processa um arquivo por vez.
- Os resultados são registrados em um log. Ao executar de novo, os vídeos do log são ignorados na hora, sem verificação, então você pode continuar depois de parar.

**Nem todo vídeo fica menor.** Vídeos que já estão bem comprimidos são ignorados, e a economia varia de vídeo para vídeo.

### Quanto fica menor

**De 0% (não convertido, original mantido) até um máximo medido de 96%.** Os arquivos nunca ficam maiores, porque um resultado do mesmo tamanho ou maior é descartado.

Estes resultados vêm de 52 vídeos reais escolhidos ao acaso em um único PC, com as configurações padrão (NVENC, CQ 30).

| Caso | Tamanho em relação ao original | Economia |
|---|---|---|
| Maior economia | 4% | 96% |
| Mediana dos 41 vídeos convertidos | 44% | 56% |
| Menor economia entre os vídeos convertidos | 89% | 11% |
| Os 11 vídeos ignorados (tamanho estimado 96-233%) | 100% (original mantido) | 0% |

| Codec de origem | Amostra | Convertidos | Tamanho dos vídeos convertidos em relação ao original |
|---|---|---|---|
| H.264 | 25 | 18 | 4-89% |
| HEVC | 25 | 21 | 15-88% |
| VP9, MPEG-4 | 1 de cada | 2 | 81%, 23% |

Quanto maior a taxa de bits de origem, maior a economia. Com origem abaixo de 5 Mbps, a mediana do tamanho em relação ao original, incluindo os vídeos ignorados, foi de 76%; em 5-15 Mbps, de 50%; e em 15-40 Mbps, de 27%.

Estes números não são uma garantia.

- Cada vídeo foi comparado apenas na faixa de vídeo, usando 10 segundos em cada um dos pontos de 25%, 50% e 75%, num total de 30 segundos. Estes não são resultados da conversão de arquivos inteiros.
- O áudio geralmente é copiado como está, então os arquivos reais diminuem menos do que estes números indicam.
- Só foram medidos vídeos de 1 minuto ou mais, e eles são a coleção de uma única pessoa. O intervalo pode ser diferente com outros vídeos.
- Só o NVENC foi medido. Outros codificadores e outros valores de `CQ` dão resultados diferentes.
- Se a estimativa antes da conversão estiver errada, pode permanecer um resultado que economize menos de 10%.

### Onde os resultados ficam

| Modo | Salvo em | Original |
|---|---|---|
| N (recomendado) | Uma pasta `av1\` dentro de cada pasta | Mantido |
| Y | No lugar do original | **Excluído permanentemente** após uma conversão bem-sucedida (não vai para a Lixeira) |

A extensão continua igual à do original. As exceções são mov, m4v, ts, mts, m2ts, mpg e mpeg, que não comportam AV1 e são salvos como `.mp4`. Se uma faixa não puder ser salva nesse formato, o resultado é salvo como `.mkv`.

### O que é mantido após a conversão

Estes resultados foram verificados com vídeos de teste.

| Item | Resultado |
|---|---|
| Primeira faixa de vídeo | Convertida para AV1 |
| Faixas de áudio (incluindo várias faixas e tags de idioma) | Mantidas. Copiadas como estão. Ao salvar em mp4, formatos incompatíveis são convertidos para AAC 192 kbps |
| Capítulos, tags (título, comentário, data de criação e outras) | Mantidos |
| 10 bits | Mantido |
| HDR10 (BT.2020, PQ, dados do monitor de masterização) | Mantido (verificado com NVENC) |
| Rotação | A própria imagem é girada ao salvar. A aparência é a mesma |
| Metadados de VR (esféricos, 3D estéreo) | Mantidos (verificado com um vídeo VR real) |
| Datas do arquivo (criação, modificação) | Mantidas |
| Timecode | Mantido |
| Faixas de legenda | Mantidas. Copiadas como estão |
| Segunda faixa de vídeo e seguintes | Mantidas. Copiadas como estão, então não diminuem |
| Capa, fontes e outros anexos | Mantidos |
| Dolby Vision (perfil 8 verificado com um vídeo real) | Mantido. Esses vídeos são codificados com SVT-AV1 na CPU, e o resultado é perfil 10 |
| Legendas dentro da faixa de vídeo | Mantidas com NVENC. Com outros codificadores o vídeo não é convertido |
| XMP em mp4 e mov (no nível do arquivo) | Mantido |
| **Vídeo 4:2:2, 4:4:4 e de 12 bits** | **Não é convertido.** O original fica como está |
| **Faixas de dados que não podem ser copiadas (GPS e outras)** | **Não é convertido.** O original fica como está |
| **Capa em mkv** | **Não é convertido.** O ffmpeg a transformaria em uma faixa de vídeo, então o original fica como está |
| **HDR10+** | **Escolhido no início** (ignorar, converter mesmo assim ou manter o original) |
| **Transparência** | **Escolhido no início** (ignorar, converter mesmo assim ou manter o original) |
| **Dolby Vision perfil 7** | **Escolhido no início** (ignorar, converter mesmo assim ou manter o original) |

## Requisitos

- Windows 10 ou 11
- `ffmpeg` e `ffprobe` no PATH
- Pelo menos um dos codificadores abaixo

| Ordem | Codificador | Precisa de |
|---|---|---|
| 1 | NVENC (`av1_nvenc`), 2 motores | Uma placa de vídeo NVIDIA com 2 codificadores AV1, como a RTX 4070 Ti |
| 2 | NVENC (`av1_nvenc`), 1 motor | Uma placa de vídeo NVIDIA com suporte a AV1 (série RTX 40 ou posterior) |
| 3 | Intel Quick Sync (`av1_qsv`) | Gráficos Intel com codificação AV1 |
| 4 | AMD AMF (`av1_amf`) | Gráficos AMD com codificação AV1 |
| 5 | CPU (`libsvtav1`, preset 10) | Uma compilação do ffmpeg que inclua SVT-AV1 |

Ao iniciar, o script faz uma codificação de teste real nessa ordem e usa o primeiro que funcionar. O codificador em uso aparece na linha `Encoder: ...`.

## Como usar

1. Baixe `convert_av1.bat` em [Releases](../../releases/latest).
2. Arraste a pasta a ser convertida e solte-a sobre o arquivo bat, ou execute o arquivo bat e digite o caminho da pasta.
3. Confira a pasta-alvo e escolha `Y` (excluir os originais) ou `N` (manter os originais).
4. Escolha o que fazer com os vídeos que perderiam HDR10+, Dolby Vision perfil 7 ou a transparência.

O progresso da verificação aparece no título da janela. Você pode executar várias janelas em pastas diferentes ao mesmo tempo, mas cada janela ficará mais lenta.

**Para parar**: feche a janela. O arquivo `name.part.ext` da conversão em andamento não é removido, então exclua-o manualmente.

### Vídeos que não podem manter tudo

Antes de começar, são feitas duas perguntas: uma sobre HDR10+ e Dolby Vision perfil 7, e outra sobre transparência.

| Escolha | O que acontece |
|---|---|
| 1 | O vídeo é ignorado e o original fica como está |
| 2 | O vídeo é convertido mesmo assim e o que não pode ser mantido se perde. No modo Y o original é excluído |
| 3 (só no modo Y) | O original é mantido e o resultado é salvo em uma pasta `av1\` |

Um vídeo ignorado assim é verificado de novo se você responder de outra forma em uma execução posterior. Um vídeo com transparência que também seja 4:4:4 é reduzido para 4:2:0 ao ser convertido.

### Configurações

Altere estes valores perto do início do arquivo bat.

| Valor | Padrão | Significado |
|---|---|---|
| `CQ` | 30 | Qualidade (0-63). Quanto menor, melhor a qualidade e maiores os arquivos. Aplicado igualmente a todos os vídeos |
| `JOBS` | 8 | Quantos arquivos verificar ao mesmo tempo para detectar AV1 |
| `MIN_SAVE` | 10 | Não converter se a economia estimada (%) for menor que este valor |
| `LOG` | `convert_av1.log` ao lado do arquivo bat | Onde os resultados são registrados |

### Log de resultados

Os resultados são adicionados a `convert_av1.log`, ao lado do arquivo bat, como texto separado por tabulações. Todas as pastas e janelas compartilham este único arquivo.

| Resultado | Significado | Na próxima execução |
|---|---|---|
| `converted`, `result` | O vídeo convertido e o arquivo gerado | Ignorado |
| `av1` | Já está em AV1 | Ignorado |
| `skip-exists`, `skip-larger`, `skip-little-gain`, `skip-not-smaller`, `skip-color`, `skip-data`, `skip-cover`, `skip-dovi`, `skip-hdr10plus`, `skip-captions`, `skip-alpha` | Não convertido | Ignorado enquanto o codificador, `CQ` e `MIN_SAVE` não mudarem |
| `failed` | A conversão falhou | Nova tentativa |

- Cada vídeo é identificado pelo caminho, pelo tamanho e pela data de modificação. Se algum deles mudar, o vídeo é verificado de novo.
- Uma conversão interrompida não é registrada, então recomeça do início.
- Para verificar todos os vídeos de novo, apague o log.

## Medições

Medido com uma RTX 4070 Ti, um i7-13700KF, Windows 11 e uma compilação do ffmpeg de 2026-10. Os resultados serão diferentes em outros ambientes.

### Velocidade de codificação

| Resolução | NVENC, 1 motor | NVENC, 2 motores | CPU SVT-AV1 preset 10 |
|---|---|---|---|
| 8K (7680×3840) | 31 fps | 55 fps | Cerca de 14 fps |
| 4K | 107 fps | 189 fps | Não medido |
| 1080p | 400 fps | 574 fps | Cerca de 518 fps |

As medições de CPU foram feitas enquanto outras conversões estavam em execução. Codificadores de software comparados em 1080p: SVT-AV1 cerca de 518 fps, libaom cerca de 173 fps, rav1e cerca de 5 fps.

### CQ e tamanho do arquivo

Resultados da conversão de um trecho de 20 segundos de um vídeo HEVC 8K (origem 30 Mbps) com NVENC. Este é um exemplo de vídeo já bem comprimido que fica maior com CQ 30.

| CQ | Taxa de bits | SSIM (em relação ao original) | Decisão |
|---|---|---|---|
| 30 | 53.9 Mbps | 0.9955 | Ignorado porque fica maior |
| 36 | 28.8 Mbps | 0.9936 | Ignorado porque a economia é pequena |
| 42 | 14.3 Mbps | 0.9900 | Convertido |

Para diminuir vídeos assim, você precisa aumentar o `CQ`, o que também reduz a qualidade de todos os outros vídeos.

### Grandes quantidades de arquivos

| Item | Resultado |
|---|---|
| Encontrar 23100 vídeos em um SSD local | 0.6 segundos |
| Encontrar 22887 vídeos em uma montagem crypt do rclone | 8.9 segundos |
| Processar todos os 23100 em um SSD local (todos já em AV1) | 239 segundos |
| Executar de novo os 23100 em um SSD local (todos no log) | 2.3 segundos |

## Limitações

### Risco de perda de dados

- **O Dolby Vision só foi verificado com o perfil 8.** Poucos dispositivos e players reproduzem Dolby Vision em AV1 (perfil 10). Se precisar dele, use primeiro o modo N.
- **A exclusão no modo Y não pode ser desfeita.** Ela usa `del`, então nada vai para a Lixeira.
- **Os resultados não são reproduzidos para verificação.** O sucesso é julgado apenas pelo código de saída do ffmpeg e pelo tamanho do arquivo. Se o vídeo estiver danificado, mas o ffmpeg informar sucesso, o original é excluído no modo Y.
- **A conversão para AV1 tem perdas.** Comprimir um vídeo já comprimido nunca deixa a qualidade melhor que a do original.
- **Vídeos 4:2:2, 4:4:4 e de 12 bits não diminuem.** Os codificadores AV1 usados aqui só aceitam 4:2:0, então esses vídeos ficam como estão.

### Onde as decisões podem estar erradas

- **A estimativa olha apenas os 10 segundos do meio.** Nos testes, um vídeo estimado em 30% acabou ficando com 45%. Vídeos que teriam diminuído podem ser ignorados.
- **Vídeos com menos de 1 minuto não são verificados antecipadamente.** O tamanho só é comparado depois da conversão.
- **Se o ffprobe não conseguir ler um arquivo, ele é tratado como não AV1.** Um arquivo que já é AV1 pode ser codificado de novo.
- **Vídeos no log não são examinados de novo.** Se você apagar um resultado, ele só é gerado novamente depois que você apagar as linhas desse vídeo do log ou o log inteiro.
- **Legendas embutidas e HDR10+ só são procurados nos primeiros 5 quadros.** Se começarem depois, o vídeo é convertido mesmo assim e o HDR10+ se perde. As legendas também, exceto com NVENC.

### Reprodução e compatibilidade

- Dispositivos e players antigos não conseguem reproduzir AV1.
- avi, wmv e flv mantêm a extensão, mas AV1 nesses formatos não é uma combinação padrão, e muitos players não vão reproduzi-lo.

### Nomes de arquivos e pastas

- Se os nomes dos resultados colidirem, como em `a.mov` e `a.mp4`, o arquivo processado depois é ignorado.
- Um `name.part.mp4` que restar após a interrupção é tratado como vídeo normal na execução seguinte. Exclua-o manualmente.
- Junções e pastas de links simbólicos não são pesquisadas.

### Ambiente

- **As mensagens na tela estão em inglês.**
- **Só foi testado no Windows 11 em coreano.** O arquivo bat usa apenas caracteres ASCII, então não depende do idioma do sistema. Foi confirmado que funciona com as páginas de código do console 437, 949 e 65001, mas não foi executado no Windows em outros idiomas.
- **Não sobrescreva um arquivo bat que uma janela em execução esteja usando.** O cmd lê o arquivo aos poucos, então uma janela em execução pode executar as linhas erradas.
- A codificação por CPU é muito mais lenta, cerca de 14 fps em 8K.
- Se o ffmpeg não incluir `libsvtav1`, o script não consegue trocar para a CPU e termina com um erro.

### Uso em uma montagem do rclone

- `--vfs-cache-mode writes` é obrigatório. Com `off`, mp4 e mkv não podem ser gravados e todos os arquivos falham.
- No modo Y, **os originais são excluídos antes de o upload terminar.** Se o upload falhar, você depende da cópia que ficou no cache, então tenha cuidado.
- Arquivos em upload não são removidos do cache mesmo que `--vfs-cache-max-age` e `--vfs-cache-max-size` sejam ultrapassados, então a unidade do cache precisa de espaço livre.
- A data de modificação é mantida, inclusive depois de montar de novo. A montagem mostra a data de modificação também como data de criação, então não existe uma data de criação separada para manter.
- Estes pontos foram testados em montagens crypt sobre unidades locais, não com armazenamento em nuvem.

### Não testado

- **A codificação real com Intel QSV e AMD AMF não foi testada.** Não havia esse hardware, então apenas a análise das opções foi verificada. Também não se sabe se a qualidade corresponde ao CQ do NVENC.
- Placas de vídeo com apenas um motor NVENC (só a troca foi verificada, simulando uma falha do modo de 2 motores)
- Ambientes sem NVENC foram simulados ocultando a placa de vídeo. Não foi executado em PCs reais com AMD ou Intel.
- Caminhos com mais de 260 caracteres

## Licença

[MIT](LICENSE)

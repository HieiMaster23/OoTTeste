<!--
SPDX-FileCopyrightText: 2026 OoTTeste contributors
SPDX-License-Identifier: GPL-3.0-or-later
-->

# Ocarina of Time em GPUs AMD

Trabalho experimental para rodar *The Legend of Zelda: Ocarina of Time* de Switch 2 (programa `0400486024DEC000`) em GPUs AMD, com imagem próxima da do console. Primeiro veio a imagem; agora a prioridade é subir o FPS sem perdê-la.

Keys, firmware e o jogo não fazem parte deste repositório.

## Estado atual

Medido em uma RX 6600M, driver 2.0.353, sem `VK_EXT_robustness2`, em Kokiri e no modo Docked.

| Item | Estado |
|---|---|
| Tela escura, vegetação, exposição e neblina volumétrica | Corrigidos na base anterior. **A imagem nesta base nova ainda não foi conferida** |
| Queda do driver ao compilar shaders | Contornada: a falha do compilador é capturada e o pipeline é refeito sem subgroup |
| Estabilidade | Cerca de 8 min nesta base, sem perda de dispositivo |
| Manchas do layer `c72b6ea746c00433` | Contornadas ao desligar o shader, o que também remove a névoa rente ao chão e o rio |
| FPS | 21-24 nas melhores janelas, com o cache de shaders ainda sendo preenchido |
| Travamentos | Frames de cerca de 83 s e 63 s na primeira sessão. Causa não provada |
| Computes `F9EA14A22394F5B1` e `8C29514395041853` | Falharam com `VK_ERROR_OUT_OF_HOST_MEMORY`. Efeito na imagem desconhecido |

O FPS veio de uma única sessão. Ainda falta uma sessão de referência com o cache cheio, na mesma cena.

## O que entrou sobre a base

Base: [zortos293/Lichii](https://github.com/zortos293/Lichii), commit `5f6066b26` (#184). O primeiro commit deste repositório é uma cópia desse tree, sem `.github/workflows`; o histórico e a autoria originais estão lá.

- Sharkiix (`Shakoquo/Lichii-sharkiix-version`, commit `28f594acc`): tensor em AMD, GC de texturas e espera estreita de DMA de macro.
- Captura de falha do compilador AMD e nova tentativa sem subgroup. Pipelines com fragment que usa subgroup são emitidos de forma síncrona.
- Proteções para AMD: `EDEN_C0_AMD_BOUNDS`, buffer nulo, `EDEN_C0_AMD_DISPATCH_BARRIERS` e `EDEN_C0_PTR_*`.
- Do Lichii: #185 (ordem de deferred clear), #176 (banco uniforme) e #192 (pipelines guardados e de mesh no disco).
- `EDEN_C0_SUBMIT_BEFORE_FENCE_WAIT`: envia o trabalho pendente antes de esperar uma fence.
- `EDEN_NX2_WRITTEN_SSBO_MARK_KIB`, desligado por padrão, e `EDEN_NX2_PRESENT_STATS_EVERY` funcionando.

## Compilar no Windows

É preciso ter Visual Studio 2022 Build Tools com clang-cl, CMake, Ninja, Qt 6.8.3 (`msvc2022_64`) e o Vulkan SDK.

```bat
copy tools\amd-oot\local-paths.example.cmd tools\amd-oot\local-paths.cmd
rem Ajuste os caminhos em local-paths.cmd.
tools\amd-oot\build.cmd generic
```

- `generic` roda em qualquer processador com SSE4.1. `tigerlake` usa as instruções desse processador e só deve ser usado nele.
- Rode pelo `cmd` ou pelo PowerShell. A configuração quebra no Git Bash.
- O resultado fica em `bin`, dentro da pasta de build.
- Para gerar o zip que abre sem instalar nada:

```powershell
powershell -ExecutionPolicy Bypass -File tools\amd-oot\pack.ps1 -Target generic -BuildDir <pasta-de-build> -OutDir <pasta-de-saida>
```

O script recusa empacotar com alterações sem commit, para o zip corresponder sempre a um commit.

## Próximos testes

Nenhum destes precisa recompilar. Mudar uma variável por vez, na mesma cena, com `EDEN_NX2_PRESENT_STATS_EVERY=60`.

| Ordem | Variável | O que responde |
|---|---|---|
| 1 | Nenhuma, com o cache cheio | Referência de FPS e imagem desta base |
| 2 | `EDEN_C0_AMD_DISPATCH_BARRIERS=0` | Quanto custam as barreiras |
| 3 | `EDEN_NX2_IDLE_SPIN_US=30`, depois `100` | Ganho com menos espera de thread |
| 4 | Afinidade das threads em núcleos físicos | Ganho com menos disputa entre núcleos |
| 5 | `cpu_accuracy=Unsafe` | Ganho de CPU. Conferir a imagem |
| 6 | `EDEN_NX2_DMA_READ_DRAIN=1` com `EDEN_NX2_REJECT_HASH=0` | Se as manchas somem e quanto custa |
| 7 | `EDEN_NX2_WRITTEN_SSBO_MARK_KIB` | Ganho em buffers. Cuidado com culling lido pela CPU |
| 8 | `EDEN_NX2_WAIT_PROFILE=1`, `EDEN_NX2_GPU_PROFILE=1` | Só contadores, para achar o próximo gargalo |

Com o conjunto decidido, a última etapa é uma build com ThinLTO e PGO.

## Como testar

- Variáveis `EDEN_*` valem no ambiente ou em `nx2_switches.txt`, ao lado do executável. O ambiente tem prioridade.
- `EDEN_NX2_DEBUG_SERVER=27060` liga o servidor de depuração, usado por `tools/nx2/debug_mcp.py` para capturas e testes A/B de shaders.
- `EDEN_DKB_FRAME_TRACE=1` mostra o tempo de GPU por shader. O traço também pesa no FPS.
- Não desligar `3ddfb1d7a854c849`: é o composite que aplica a neblina volumétrica.

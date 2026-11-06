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
| Queda do driver ao compilar shaders | Contornada: a falha do compilador é capturada e o pipeline é refeito sem subgroup. Os dois fragments conhecidos agora compilam sem otimização |
| Linha preta no horizonte em Hyrule Field | Causada por um draw de máscara que não exporta cor. Corrigida na RX 6600M. A primeira versão da correção deixava Link preto em partes de Hyrule Field; a atual só atua em shaders sem nenhuma exportação |
| Estabilidade | Cerca de 8 min nesta base, sem perda de dispositivo |
| Manchas do layer `c72b6ea746c00433` | Contornadas ao desligar o shader, o que também remove a névoa rente ao chão e o rio |
| FPS | Antes desta versão: 21-24 em Kokiri nas melhores janelas e 19-20 em Hyrule Field. **Esta versão ainda não foi medida** |
| Grama e texturas somem no fim do golpe de espada | Já existia antes da build-88. Causa não provada; a primeira candidata é a leitura de resultados de oclusão antigos (`EDEN_C0_QUERY_DMA_FLUSH=1`) |
| Limite do FPS | Comunicação CPU/GPU: com 1/9 dos pixels (864x480, sem `Max Resolution`) o frame fica igual, em ~46 ms. Queda de resolução não é o caminho |
| Travamentos | Draws nativos esperam o pipeline mesmo com shaders assíncronos: 35,7 s de espera em uma sessão, com picos de 1,5 s. Cerca de 36% dos frames acima de 100 ms não têm pipeline por perto, e a causa desses ainda não foi medida |
| Computes `F9EA14A22394F5B1` e `8C29514395041853` | Falharam com `VK_ERROR_OUT_OF_HOST_MEMORY`. Efeito na imagem desconhecido |

O FPS veio de uma única sessão. Ainda falta uma sessão de referência com o cache cheio, na mesma cena.

## O que entrou sobre a base

Base: [zortos293/Lichii](https://github.com/zortos293/Lichii), commit `5f6066b26` (#184). O primeiro commit deste repositório é uma cópia desse tree, sem `.github/workflows`; o histórico e a autoria originais estão lá.

- Sharkiix (`Shakoquo/Lichii-sharkiix-version`, commit `28f594acc`): tensor em AMD, GC de texturas e espera estreita de DMA de macro.
- Captura de falha do compilador AMD e nova tentativa sem subgroup. O fallback é traduzido na thread da GPU e emitido no worker.
- Proteções para AMD: `EDEN_C0_AMD_BOUNDS`, buffer nulo, `EDEN_C0_AMD_DISPATCH_BARRIERS` e `EDEN_C0_PTR_*`.
- Do Lichii: #185 (ordem de deferred clear), #176 (banco uniforme), #192 (pipelines guardados e de mesh no disco), os commits da build-88 (#193, #194 e #240) e os PRs #206 (laço atômico) e #210 (compilação sem otimização). Do #240 vem o Dynamic FPS, ligado por padrão. Quem já tem o mod `Dynamic-fps` continua usando o próprio.
- `EDEN_C0_FRAG_EXPORT_MASK`: `1` (padrão) não escreve cor com fragments que não exportam nenhuma; `2` bloqueia todo alvo não exportado, o que deixa Link preto; `0` desliga. Só no caminho de máscara estática; drivers com blend dinâmico (EDS3) não mudam.
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

Nenhum destes precisa recompilar. Mudar uma variável por vez, na mesma cena, com `EDEN_NX2_PRESENT_STATS_EVERY=60`. A cena de referência agora é Hyrule Field.

O #194 voltou os padrões de envio à GPU para 128 draws e 500 µs. Para comparar com os valores anteriores, use `EDEN_NX2_FENCE_FLUSH_US=5000`.

| Ordem | Variável | O que responde |
|---|---|---|
| 1 | Nenhuma, com o cache cheio | Referência de FPS e imagem desta base |
| 2 | `EDEN_C0_FRAG_EXPORT_MASK=0` | Confirma se a máscara é o que remove a linha |
| 3 | `EDEN_NX2_REJECT_HASH=0` | Se a máscara também resolveu as manchas do `c72b` e trouxe de volta a névoa rente ao chão e o rio |
| 4 | Desligar o add-on `Max Resolution` | Quanto do frame depende de resolução. Conferir a nitidez |
| 5 | `EDEN_NX2_NOOPT_SHADERS=all` | Quanto a compilação encurta sem otimização, e quanto o FPS cai. Só para medir |
| 6 | `EDEN_C0_PIPELINE_WORKERS=6` | Menos disputa com as threads do jogo, contra fila maior de compilação |
| 7 | `EDEN_C0_AMD_PIPELINE_CACHE=1` | Se um `VkPipelineCache` explícito encurta os builds do driver AMD |
| 8 | `EDEN_C0_PIPELINE_EVICT_FRAMES=0` | Se descartar pipelines parados causa recompilação |
| 9 | `EDEN_C0_AMD_DISPATCH_BARRIERS=0` | Quanto custam as barreiras. Conferir vegetação e névoa |
| 10 | `EDEN_NX2_WAIT_PROFILE=1`, `EDEN_NX2_GPU_PROFILE=1`, `EDEN_DKB_FRAME_TRACE=1`, `EDEN_C0_CPU_READ_PROFILE=1` | Só contadores, para achar o próximo gargalo, inclusive as leituras da CPU em memória da GPU |
| 11 | `EDEN_C0_QUERY_DMA_FLUSH=1` | Se a grama para de sumir na espada e as manchas do `c72b` mudam. Pode travar ou custar FPS |
| 12 | `EDEN_C0_ACQUIRE_RESUME=1` | Evita drenar o split em acquire já satisfeito. Conferir vegetação, névoa e troca de cena |
| 13 | `EDEN_C0_FRONT_SHORT_SPIN=1`, depois `EDEN_C0_BACK_SHORT_SPIN=1` | Menos espera ativa nas threads da GPU. Pode aumentar wakeups |

Com o conjunto decidido, a última etapa é uma build com ThinLTO e PGO.

## Como testar

- Variáveis `EDEN_*` valem no ambiente ou em `nx2_switches.txt`, ao lado do executável. O ambiente tem prioridade.
- `EDEN_NX2_DEBUG_SERVER=27060` liga o servidor de depuração, usado por `tools/nx2/debug_mcp.py` para capturas e testes A/B de shaders.
- `EDEN_DKB_FRAME_TRACE=1` mostra o tempo de GPU por shader. O traço também pesa no FPS.
- Não desligar `3ddfb1d7a854c849`: é o composite que aplica a neblina volumétrica.

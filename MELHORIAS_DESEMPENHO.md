# Melhorias de desempenho e enxugamento — dotfiles Hyprland + Quickshell

Documento gerado por varredura do repositório em `~/.config` (Hyprland, Quickshell Donwaztok, `app.lst`, `install.sh`, shell). Objetivo: manter o setup **pequeno e previsível em CPU/GPU/RAM**, com sugestões que vão de ajustes rápidos a remoção de funcionalidades caras.

**Alterações já aplicadas no repo:** blur do compositor desativado (`decoration.blur.enabled = false`) e layerrules de blur removidas; removidos geoclue, EasyEffects, Cava/visualizador de áudio e `QML2_IMPORT_PATH` fixo (passa a vir de `hypr/hyprland/env.conf`); `cliphist wipe` no arranque; duplicados de `layerrule` para `indicator.*` eliminados.

**Código Quickshell morto removido (limpeza):** singletons e UI sem referências — `LauncherApps` / `options.launcher.pinnedApps`; `LauncherSearch` + `LauncherSearchResult` + `Todo`; `SessionWarnings`; `Privacy`; `Booru` + `BooruResponseData` + estado `booru` em `Persistent` + opções `options.booru`; reconhecimento musical (`SongRec`, `MusicRecognitionToggle`, script `recognize-music.sh`, `options.musicRecognition` e secção em Definições). Pastas `Directories` só usadas por booru/todo também foram enxugadas.

---

## 1. Resumo executivo

| Área | Estado atual | Risco de custo |
|------|----------------|----------------|
| **Hyprland — blur** | Blur **desligado** em `general.conf`; sem `layerrule` de blur | **Baixo** (GPU) |
| **Arranque (`exec-once`)** | Quickshell, `cliphist wipe`, **dois** `wl-paste --watch` com `qs … ipc`; opcionalmente apps em `custom/execs.conf` | **Médio** (picos ao copiar; login depende dos teus `exec-once` custom) |
| **`app.lst`** | Mistura essencial (Hyprland, portals, quickshell) com **stack KDE**, vários browsers/IDEs, extras (ex.: gamemode) | **Médio** em disco, atualizações AUR e processos em background |
| **Quickshell** | Visualizador/cava removidos; alguns timers agressivos **só quando funcionalidades estão ativas**; `ResourceUsage` usa truque de **1 ms** no primeiro tick | **Baixo a médio** conforme módulos usados |
| **Zsh** | **Cada** shell novo executa `pokeget \| fastfetch` | **Médio** se abres muitos terminais |

Com blur desligado e sem regras de blur em layers, o custo de GPU no compositor desce; o que resta notável no arranque são **IPC do clipboard** e processos que adiciones em `custom/execs.conf`.

---

## 2. Arranque de sessão (maior impacto)

### 2.1 `hypr/hyprland/execs.conf`

- **`easyeffects --hide-window --service-mode`** — DSP em tempo real; útil para áudio, mas é um dos processos mais pesados no arranque. *Sugestão:* iniciar só quando fores usar (atalho `exec`) ou remover se não precisares de EQ/efeitos.
- **Dois `wl-paste --watch`** (texto e imagem) — cada cópia corre `cliphist store` **e** `qs -c $qsConfig ipc call cliphistService update`. *Sugestão:* consolidar num único watcher se possível, ou **debounce** no lado shell; avaliar **só texto** se raramente copias imagens.
- **`start_geoclue_agent.sh`** — daemon de geolocalização (ex.: meteorologia). *Sugestão:* remover se não usares clima/localização; reduz privacidade e um serviço a menos.
- **`qs -c $qsConfig &`** — inevitável para o shell; manter.

### 2.2 `hypr/custom/execs.conf`

- **`gtk-launch zen`**, **`zapzap`**, **`Thunderbird`** — três aplicações gráficas no login (Chromium/Electron + email). *Sugestão:* **não** auto-start; abrir com atalho. Ganho enorme em RAM e tempo até o desktop “respirar”.
- **`solaar -w hide`** — razoável se usas periféricos Logitech; caso contrário remover da lista de pacotes e do `exec-once`.

### 2.3 `install.sh` + systemd

- Habilita **SDDM**, **NetworkManager**, **bluetooth**, **ydotool**. Para um sistema “mínimo”, podes não instigar bluetooth/ydotool em máquinas que não precisam.

---

## 3. Hyprland (compositor e GPU)

### 3.1 Blur (já parcialmente mitigado)

Ficheiro: `hypr/hyprland/general.conf`

- `blur { size = 10; passes = 3; … }` — custo elevado quando aplicado a **várias** layer surfaces.
- As **layerrules** em `hypr/hyprland/rules.conf` ativam blur para `quickshell:*`, `bar*`, `launcher`, `notifications`, etc.

*Sugestões (por ordem de impacto):*

1. Reduzir **`passes`** para `2` ou `1` e **`size`** para `6–8` (alinha com comentários em `hypr/themes/theme.conf` no repo).
2. Desativar blur em namespaces **menos críticos** (ex.: tooltips `quickshell:popup` já tem ajustes; testar `blur off` em overlays que não precisem).
3. Se quiseres **máximo desempenho**: `decoration { blur { enabled = false } }` e remover `blur on` das layerrules (visual mais “seco”, ganho máximo em GPU).

### 3.2 Sombras e cantos

- `shadow { range = 50; render_power = 10; }` — não é gratuito em cenas com muitas layers/janelas.
- `rounding = 18` — custo marginal; prioridade menor vs blur.

### 3.3 Animações e gestos

- Bloco `animations` extenso (vários béziers, `workspaces` com duração 7, etc.). *Sugestão:* desativar `animations { enabled = false }` para teste A/B; ou encurtar durações das animações de workspace/layers.
- `gestures` / `workspace_swipe` — custo geralmente baixo; só relevante em portáteis com trackpad intensivo.

### 3.4 Outras flags úteis (já bem configuradas)

- `misc { vfr = 1; animate_manual_resizes = false; … }` — boas para FPS.
- `allow_tearing` + regras `immediate` para jogos — adequado para desempenho em fullscreen.

### 3.5 Duplicação em `layerrule`

Há regras repetidas para o mesmo namespace (ex.: `indicator.*` com `blur` mais de uma vez). *Sugestão:* limpar duplicados para facilitar manutenção e evitar comportamento confuso (impacto em desempenho: pequeno).

---

## 4. Quickshell (Donwaztok)

### 4.1 Caminho fixo no código

- `quickshell/donwaztok/shell.qml`: `QML2_IMPORT_PATH=/home/don/.config/quickshell/donwaztok` — impede clonar para outro utilizador sem editar; não é desempenho, mas é **dívida operacional**.

### 4.2 Clipboard → IPC

- Cada cópia dispara `qs … ipc call cliphistService update`. Em cópias em massa ou scripts, isto pode gerar **muitos** processos `qs`. *Sugestão:* documentar alternativa (só `cliphist` sem IPC, refresh da UI ao abrir o histórico).

### 4.3 Timers e serviços

- **`ResourceUsage.qml`**: primeiro disparo do timer com `interval: 1` ms, depois ajusta para `updateInterval` (ex. 3000 ms). É um “hack” de arranque; substituir por `triggeredOnStart: true` + intervalo normal evita um tick desnecessariamente agressivo.
- **`TimerService.qml`**: timer de **10 ms** só quando o **stopwatch** está a correr — OK; **200 ms** com pomodoro ativo — OK.
- **`Persistent.qml`**: timers 100 ms só para debounce de ficheiro — OK.
- **`Updates.qml`**: com `enableCheck: true` e `checkInterval: 120` (minutos), corre `checkupdates` periodicamente. *Sugestão:* aumentar intervalo ou desativar se não precisares de badge de updates na barra.
- **Cava**: `CavaProvider` só corre com `Config.background.visualiser.enabled` — no teu `donwaztok/config.json` está **`false`** — bom para CPU.

### 4.4 Visualiser / wallpaper / relógio no ambiente de trabalho

- `Background.qml` + `Visualiser` + relógio: com `visualiser.enabled: false` já poupas o processo `cava`. O **relógio no desktop** (`desktopClock.enabled: true`) ainda é uma layer extra com sombra/blur conforme opções — se quiseres menos trabalho na GPU, desativar relógio ou efeitos no mesmo.

### 4.5 Tamanho do repositório Quickshell

- Centenas de ficheiros QML — não aumenta *runtime* por si, mas aumenta **tempo de reload** do `qs` e complexidade. “Enxugar até ser pequeno” aqui significa **desativar módulos** na config JSON ou forkar e apagar pastas não usadas (bar entries, dashboard, AI, etc.), não só otimizar timers.

### 4.6 Funcionalidades com custo cognitivo e opcionalmente runtime

- **`services/Ai.qml`** — chat LLM; inativo até usares, mas carrega lógica e keyring. Remover do build só faz sentido num fork minimalista.
- **SongRec / reconhecimento musical** — se não usas, remove pacote e entradas na UI.
- **Thumbnails / ImageMagick / venv Python** (`DONWAZTOK_VIRTUAL_ENV`) — peso em disco e no primeiro uso; avaliar se precisas de pré-visualizações pesadas.

---

## 5. `app.lst` — pacotes a questionar (enxugamento)

**Candidatos a remover** se o objetivo for sistema mínimo:

| Pacote / grupo | Motivo |
|----------------|--------|
| **songrec**, **translate-shell** | Removidos da lista base; instalar sob demanda se precisares |
| **gamemode** | Só se jogas com regularidade |
| **cursor-bin** | IDE específica; não precisa estar na lista “base” de dotfiles |
| **thunderbird**, **zapzap**, **zen-browser-bin** | Apps pesados; melhor como opt-in |
| **dolphin** | Removido da lista base; gestor por defeito **Nautilus** (Super+E) |
| **bluedevil**, **plasma-nm**, **systemsettings**, **breeze*** | Stack KDE para applets/Bluetooth; se usares só Quickshell + `networkmanager` CLI/applet leve, podes reduzir |
| **eog** | Opcional se já tens visualizador preferido |
| **solaar** | Só hardware Logitech |
| **ddcutil** | Só monitores com DDC/CI |
| **wf-recorder**, **tesseract*** | Só se usas gravação/OCR no fluxo diário |
| **pokeget** | Usado no `.zshrc` para decoração — ver secção 6 |

**Manter** como núcleo típico deste projeto: `hyprland`, `quickshell-git`, `wl-clipboard`, `cliphist`, `fuzzel`, `hypridle`, `hyprlock`, `xdg-desktop-portal-hyprland`, `pipewire`/`wireplumber`, `kitty` (ou terminal preferido), `mako` (se usado), etc.

*Sugestão estrutural:* como já notado no `README.md`, separar **`app.lst.core`** vs **`app.lst.extra`** e documentar perfis (“minimal”, “full”).

---

## 6. Shell — `.zshrc`

Linha no topo (aprox.): `pokeget random --hide-name | fastfetch --file-raw -`

- **Cada novo terminal** arranca dois processos e possivelmente rede/cache para sprite Pokémon + fastfetch.
- *Sugestão:* mover para **login interativo apenas** (`if [[ -o interactive ]]; then … fi`) ou executar **uma vez por sessão** (ficheiro de flag em `/tmp` ou `~/.cache`), ou remover `pokeget` e usar `fastfetch` só quando pedires (`ff` alias).

Oh My Zsh + Powerlevel10k + plugins: aceitável; se quiseres arranque de shell mais rápido, reduz plugins ou perfil do p10k.

---

## 7. Instalação (`install.sh`)

- Clona e instala **temas GTK (Graphite)**, **ícones Tela**, **GRUB Particle**, **SDDM Candy** — ótimo para “rice”, ruim para **tempo de install** e superfície de manutenção.
- *Sugestão:* flags ou secções comentadas para “install mínimo sem temas”.

---

## 8. Plano de ação sugerido (prioridades)

**Quick wins (baixo esforço, bom retorno)**

1. Tirar **Zen / ZapZap / Thunderbird** dos `exec-once` em `hypr/custom/execs.conf`.
2. Ajustar **blur** (`passes`/`size`) ou desligar blur em layers não essenciais.
3. **Desativar ou adiar EasyEffects** no arranque.
4. Condicionar **fastfetch/pokeget** no `.zshrc`.
5. Aumentar **`updates.checkInterval`** ou `enableCheck: false` no `donwaztok/config.json` se não precisares do indicador.

**Médio esforço**

6. Unificar ou simplificar **watchers de clipboard** + IPC ao Quickshell.
7. Refatorar **primeiro tick** de `ResourceUsage.qml` (remover `interval: 1`).
8. Dividir **`app.lst`** em perfis e documentar no `README`.

**Grande enxugamento (fork ou limpeza agressiva)**

9. Desativar blur global nas layers + sombras mais leves.
10. Remover módulos Quickshell não usados (AI, dashboard, media fancy, etc.) de `config.json` ou do código.
11. Lista de pacotes “minimal” sem stack KDE completa (substituir por ferramentas mais leves para rede/Bluetooth).

---

## 9. Conclusão

O setup **já tem boas escolhas** (VFR, sem blur em janelas X11/Wayland normais, visualiser e cava desligados na config atual). Para ficar **claramente mais leve e pequeno**, o maior ganho vem de:

1. **Menos coisas no login** (browsers, email, EasyEffects opcional, geoclue opcional).
2. **Blur/sombras nas layers** do Quickshell alinhados com a GPU disponível.
3. **Menos trabalho por terminal** (fastfetch/pokeget).
4. **`app.lst`** enxuto com perfis documentados.

Este ficheiro pode ser atualizado sempre que alterares `execs.conf`, `general.conf`, `rules.conf`, `config.json` ou a lista de pacotes.

# Comboio — Design system e telas

## 1. Identidade

**Nome: Comboio.** Grupo de veículos que viaja junto. Curto, em português, fala do uso e não da tecnologia. Antes de publicar, conferir se o nome está livre na App Store e no Google Play.

**Conceito visual:** painel de instrumentos de moto à noite. Fundo quase preto, um único laranja de sinalização para tudo que é ação, verde só para "voz ativa/conectado". Cor nunca é decoração: cada cor tem um significado fixo.

**Ícone do app:** fundo `#0A0B0D`. Dois arcos concêntricos abertos (ondas de voz) em laranja, saindo de um ponto à esquerda, com um segundo ponto à direita, verde: dois pilotos ligados por voz. Sem texto, sem gradiente. Legível em 29 px.

**Splash:** fundo `#0A0B0D`, ícone centralizado, os arcos se desenham da esquerda para a direita em 400 ms e o ponto verde acende. Vai direto para a Home; nada de splash segurando o usuário.

## 2. Tokens

### 2.1 Cor

| Token | Escuro | Claro | Uso |
|---|---|---|---|
| `bg` | `#0A0B0D` | `#F4F5F7` | Fundo da tela |
| `surface` | `#14161A` | `#FFFFFF` | Cartões |
| `surfaceHigh` | `#1E2127` | `#E9EBEF` | Controles sobre cartão |
| `border` | `#2C3038` | `#C5CAD3` | Contornos |
| `text` | `#FFFFFF` | `#0A0B0D` | Texto principal |
| `textDim` | `#C9CED6` | `#3A3F49` | Texto secundário (contraste ≥ 10:1; nada de cinza apagado) |
| `accent` | `#FF8A00` | `#FF8A00` | Preenchimento de ação principal |
| `onAccent` | `#0A0B0D` | `#0A0B0D` | Texto sobre laranja |
| `accentText` | `#FF8A00` | `#A84300` | Laranja usado como texto/ícone |
| `live` | `#2EE86B` | `#0B8F3C` | Falando, conectado |
| `warn` | `#FFD60A` | `#8A6A00` | Sinal fraco, degradado |
| `danger` | `#FF4D5E` | `#C8102E` | Erro, fora do alcance, mudo |

Cores de piloto (escolha do usuário, usadas no anel do avatar): `#FF8A00` `#2EE86B` `#3DA9FF` `#FF4D9D` `#FFD60A` `#B58CFF`.

Regra de sol forte: informação de estado nunca depende só de cor. Sempre cor + ícone + palavra.

### 2.2 Tipografia

- **Saira Condensed** (600/700): títulos, botões, números e status. Condensada, com cara de painel, algarismos de largura fixa.
- **Inter** (400/600): texto corrido e configurações.

Ambas são SIL OFL e vão embutidas em `assets/fonts/` (o app funciona offline; nada de baixar fonte em tempo de execução).

Na versão 0.1 só a Saira Condensed está embutida; o texto corrido usa a fonte do sistema (Roboto no Android, San Francisco no iOS), que cumpre o mesmo papel.

| Estilo | Fonte | Tamanho/altura | Uso |
|---|---|---|---|
| `display` | Saira Condensed 700 | 56/56 | Status gigante no modo painel |
| `headline` | Saira Condensed 700 | 34/38 | Título de tela |
| `title` | Saira Condensed 600 | 24/28 | Nome de piloto, cartões |
| `button` | Saira Condensed 700, caixa alta, +0,5 de espaçamento | 22/24 | Botões |
| `body` | Inter 400 | 17/24 | Texto |
| `label` | Inter 600 | 14/18 | Rótulos, nunca abaixo de 14 |

### 2.3 Espaço, raio, toque, movimento

| Grupo | Tokens |
|---|---|
| Espaçamento | `xs 4` · `sm 8` · `md 16` · `lg 24` · `xl 32` · `xxl 48` |
| Raio | `sm 12` · `md 20` · `lg 28` · `pill 999` |
| Alvo de toque | mínimo `64`, principal `72`, PTT `≥ 160` |
| Distância entre alvos | mínimo `16` (luva erra por pouco) |
| Duração | `fast 120 ms` · `base 220 ms` · `slow 400 ms` |
| Curva | `easeOutCubic` para entrada, `easeInCubic` para saída |

### 2.4 Ícones

**Material Icons, variante arredondada** (já embutidos no Flutter). O Phosphor era a primeira escolha, mas o pacote `phosphor_flutter` 2.1 não compila no Flutter 3.50. Tamanhos 28 (inline) e 36 (dentro de botão).

### 2.5 Microanimações (cada uma informa algo)

| Animação | Significado | Detalhe |
|---|---|---|
| Onda de voz | Quem está falando e com que força | 5 barras, altura segue o nível de áudio real, 60 fps, cor do piloto |
| Pulso do anel | Estado do link | Verde fixo = ok. Âmbar pulsando 1 Hz = degradado. Vermelho pulsando 2 Hz = reconectando |
| Morph do botão de modo | VOX ↔ PTT | 220 ms |
| Entrada de piloto | Alguém entrou | Tile desliza de baixo + vibração curta |

Respeitar "Reduzir movimento" do sistema: pulsos viram troca de cor estática.

## 3. Feedback sem olhar a tela

Frases gravadas em pt-BR (arquivos em `assets/audio/pt-BR/`), tocadas no capacete, sempre precedidas de um earcon curto. Gravadas em vez de TTS para soar igual em qualquer aparelho e não depender de voz instalada.

| Evento | Earcon | Frase | Vibração |
|---|---|---|---|
| Sala criada, aguardando | 1 bip | "Sala criada" | curta |
| Piloto entrou | 2 notas subindo | "Léo conectado" (ou "Piloto 2 conectado") | curta |
| Fora do alcance | 2 notas descendo | "Piloto 2 fora do alcance" | longa |
| Reconectou | 2 notas subindo | "Reconectado" | curta |
| Mudo ligado / desligado | clique grave / agudo | "Mudo" / "Microfone aberto" | curta |
| Capacete desconectou | — (não há onde tocar) | — | 3 longas |
| Capacete voltou | 1 bip | "Capacete conectado" | curta |
| Bateria ≤ 15% | bip duplo | "Bateria fraca" | — |

Nomes próprios não dá para gravar; a frase usa "Piloto N" e o nome aparece só na tela.

## 4. Telas

Todas em retrato, com as ações principais no terço inferior (alcance do polegar). O modo painel também aceita paisagem.

### 4.1 Onboarding (3 passos, uma vez)

```
┌──────────────────────────────┐
│  ● ○ ○                       │
│                              │
│        ( ícone mic )         │
│                              │
│   MICROFONE                  │
│   Para os outros pilotos     │
│   ouvirem você pelo          │
│   capacete.                  │
│                              │
│                              │
│ ┌──────────────────────────┐ │
│ │        PERMITIR          │ │  72 dp
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

1. **Microfone.** Dispara o diálogo do sistema.
2. **Rede local.** "Para os celulares se encontrarem sem internet." O botão inicia uma busca Bonjour, que faz o iOS mostrar o diálogo.
3. **Capacete.** Detecta a rota de áudio atual.
   - Achou: check verde, "(nome do headset) conectado", botão **TESTAR SOM** (toca uma frase no capacete e grava 2 s do microfone para devolver).
   - Não achou: "Ligue o capacete e pareie em Ajustes > Bluetooth", botão **ABRIR AJUSTES**, e a tela se atualiza sozinha quando a rota aparecer.

No iOS não existe passo de Bluetooth (não é necessário). No Android o passo 2 pede "Dispositivos próximos".

Por último: nome do piloto (campo já preenchido com o nome do aparelho) e cor (6 bolinhas grandes).

```
OnboardingScreen
└─ PageView (sem gesto de arrastar; avança pelo botão)
   ├─ PermissionStep(icon, title, body, onGrant)      ×2
   ├─ HelmetCheckStep
   │  ├─ StatusRing(state)
   │  └─ BigButton
   └─ ProfileStep
      ├─ TextField
      └─ PilotColorPicker
```

### 4.2 Home

```
┌──────────────────────────────┐
│ COMBOIO                  ⚙   │
│                              │
│ ┌──────────────────────────┐ │
│ │ 🎧 Headset conectado  ✓  │ │  chip de estado do capacete
│ └──────────────────────────┘ │
│                              │
│ SALAS POR PERTO              │
│ ┌──────────────────────────┐ │
│ │ ● Sala do Léo      1/6 › │ │  toque = entra (1 toque)
│ └──────────────────────────┘ │
│                              │
│ ┌──────────────────────────┐ │
│ │        ENTRAR            │ │  contorno, 72 dp → QR/PIN
│ └──────────────────────────┘ │
│ ┌──────────────────────────┐ │
│ │      CRIAR SALA          │ │  laranja cheio, 72 dp
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

- A busca de salas começa ao abrir a tela. Sala de piloto já conhecido aparece no topo e entra com **1 toque**.
- **Criar sala** = 1 toque; a sala abre e mostra o QR/PIN em folha inferior. No iPhone, se o hotspot estiver desligado, a folha mostra o passo a passo com botão **ABRIR AJUSTES** (o iOS não deixa o app ligar o hotspot).
- **Entrar** sem sala listada abre o leitor de QR, com alternativa "digitar PIN" (teclado numérico próprio, teclas de 72 dp).
- Se o capacete não está conectado, o chip fica vermelho e os botões continuam ativos, mas o toque leva antes à tela de erro 4.5a.

```
HomeScreen
└─ SafeArea > Column
   ├─ AppHeader(title, onSettings)
   ├─ HelmetChip(route)
   ├─ Expanded > NearbyRoomsList
   │              └─ RoomTile(room, onTap)
   ├─ BigButton.outlined("ENTRAR")
   └─ BigButton.filled("CRIAR SALA")
```

### 4.3 Sala ativa

```
┌──────────────────────────────┐
│ ‹ SAIR      SALA DO LÉO   ⛶ │  ⛶ = modo painel
│                              │
│      ╭────────────╮          │
│      │    ▂▅█▅▂   │          │  anel na cor do piloto
│      │    LÉO     │          │  onda = nível de voz
│      ╰────────────╯          │
│      ▮▮▮▯  ~35 m             │  qualidade do link · distância
│                              │
│  ┌────────┐   ┌────────┐     │
│  │ VOCÊ   │   │ + CONV.│     │  tiles menores
│  │ ▂▃▂    │   │  QR    │     │
│  └────────┘   └────────┘     │
│                              │
│  🔉 ━━━━━━━━━━●━━━━  🔊     │  volume, trilho de 64 dp
│                              │
│ ┌──────────┐ ┌─────────────┐ │
│ │  VOX     │ │    MUDO     │ │  72 dp cada
│ └──────────┘ └─────────────┘ │
└──────────────────────────────┘
```

- Com 2 pilotos, o outro ocupa o destaque. Com 3 a 6, grade 2×N de `PilotTile`, quem fala ganha contorno verde e onda.
- **Qualidade do link:** 4 barras calculadas de perda de pacotes, RTT e jitter (estatísticas do WebRTC). O iOS não expõe o sinal Wi-Fi do outro aparelho, então não existe "RSSI" confiável.
- **Distância:** só aparece se os dois ativarem a localização (GPS trocado pelo canal de controle). Sem isso, o campo some; nada de estimativa inventada.
- **MUDO** ativo fica vermelho cheio com ícone de microfone cortado e a palavra "MUDO".
- **VOX/PTT:** alterna o modo. Em PTT, a faixa inferior inteira vira um botão **FALAR** de 160 dp de altura (segurar para falar).
- **Sair** pede confirmação com dois botões grandes, para não derrubar a sala com um esbarrão.

**Modo painel** (suporte de guidão): tela sempre acesa, brilho no máximo, layout reduzido a três coisas: status em `display` ("CONECTADO"), onda de quem fala e um botão único gigante (MUDO, ou FALAR em PTT). Toque duplo em qualquer ponto sai do modo.

```
RoomScreen
└─ Scaffold
   ├─ RoomHeader(onLeave, onDashboard)
   ├─ Expanded > PilotGrid
   │              └─ PilotTile
   │                 ├─ StatusRing(linkState, color)
   │                 ├─ VoiceWave(level)
   │                 └─ LinkQualityBars + DistanceLabel
   ├─ VolumeSlider
   └─ RoomControls
      ├─ ModeToggle (VOX | PTT)
      └─ MuteButton   ou   PttButton

DashboardScreen
└─ GestureDetector(onDoubleTap: sair)
   └─ Column [ StatusDisplay, VoiceWave(grande), GiantActionButton ]
```

### 4.4 Configurações

Lista de cartões, cada linha com 64 dp de altura mínima.

| Grupo | Itens |
|---|---|
| Piloto | Nome · Cor |
| Voz | Modo padrão (VOX/PTT) · Sensibilidade do VOX (slider com medidor ao vivo do microfone e marca do limiar) · **CALIBRAR** (mede o ruído por 3 s) · Redução de ruído (normal/forte) |
| Áudio | Qualidade (econômica 16 kbps / padrão 24 / alta 32) · Avisos por voz (ligado/desligado) · Volume dos avisos |
| Tela | Tema (escuro/claro/sistema) · Manter tela acesa na sala |
| Pilotos conhecidos | Lista com opção de esquecer |
| Sobre | Versão · Diagnóstico (rota de áudio, IP, estatísticas) |

```
SettingsScreen
└─ ListView
   └─ SettingsSection(title)
      ├─ SettingsTile.text / .color / .choice / .toggle
      └─ VoxSensitivityTile
         ├─ LiveMicMeter(level, threshold)
         └─ Slider
```

### 4.5 Estados de erro

Sempre em tela cheia quando impedem a conversa: ícone grande, uma frase dizendo o que houve, uma frase dizendo o que fazer, um botão.

| Erro | Título | O que fazer | Botão |
|---|---|---|---|
| a. Capacete desconectado | CAPACETE DESCONECTADO | "Ligue o capacete. A conversa volta sozinha." (o áudio fica mudo enquanto isso, para não vazar pelo alto-falante) | ABRIR BLUETOOTH |
| b. Fora do alcance | FORA DO ALCANCE | "Tentando reconectar… aproxime as motos." Contador de tempo desde a queda | (nenhum; reconecta sozinho) + SAIR DA SALA discreto |
| c. Sala não encontrada | NENHUMA SALA POR PERTO | "Confira se você está no Wi-Fi do outro piloto." Mostra o nome do Wi-Fi atual | ABRIR WI-FI · TENTAR DE NOVO |
| d. Hotspot desligado (host iOS) | LIGUE O ACESSO PESSOAL | 3 passos ilustrados | ABRIR AJUSTES |
| e. Microfone negado | SEM ACESSO AO MICROFONE | "Permita em Ajustes." | ABRIR AJUSTES |
| f. Em ligação | EM LIGAÇÃO | "A conversa volta quando a ligação terminar." | — |

Erro b não é tela cheia quando há mais de 2 pilotos: só o tile daquele piloto fica vermelho.

```
ErrorScreen(kind)
└─ Column [ Icon(96), Text(headline), Text(body), BigButton? ]
```

## 5. Componentes base

| Widget | Contrato |
|---|---|
| `BigButton` | `.filled` / `.outlined` / `.danger`; altura 72; rótulo em caixa alta; ícone opcional; vibração leve no toque |
| `StatusRing` | `state: connected/degraded/reconnecting/idle`, `color`; cuida do pulso |
| `VoiceWave` | `level: 0..1` (stream), `color`, `bars`; `CustomPainter` com `RepaintBoundary` |
| `PilotTile` | piloto + estado do link; variantes destaque/grade |
| `LinkQualityBars` | `quality: 0..4`, sempre com rótulo textual para leitor de tela |
| `HelmetChip` | rota de áudio atual |
| `PttButton` | segurar para falar; `onDown/onUp`; ignora arrasto para não soltar com trepidação |

Acessibilidade: todo controle com `Semantics` e rótulo; contraste mínimo 7:1 para texto; nada abaixo de 14 pt.

## 6. Tema claro

Mesma estrutura, valores da coluna "Claro" da tabela 2.1. O laranja de preenchimento não muda (com texto preto por cima o contraste se mantém); o laranja usado como *texto* escurece para `#A84300`, e verde/âmbar/vermelho escurecem para manter contraste sobre branco. Padrão do app: escuro. O tema claro existe para quem prefere sob sol direto.

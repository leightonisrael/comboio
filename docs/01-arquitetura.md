# Comboio — Arquitetura

Intercomunicador por voz para motociclistas, sem internet e sem sinal de celular.

O app não depende de marca ou modelo de capacete: funciona com qualquer headset Bluetooth que atenda ligações (perfil HFP/HSP), inclusive os genéricos sem intercom próprio. O celular faz todo o trabalho de rede; o headset é só microfone e fone.

Este documento cobre: veredito sobre a abordagem proposta, arquitetura, transporte de rede, pipeline de áudio, protocolo, segurança, estrutura Flutter e configurações nativas.

Convenção: **[VALIDAR]** marca afirmações que dependem de teste em aparelho real (ver `04-testes-e-roadmap.md`). Nada marcado assim deve ser tratado como fato.

---

## 0. Veredito sobre a abordagem proposta

| Proposta | Veredito | O que muda |
|---|---|---|
| WebRTC (flutter_webrtc), só candidatos locais | **Manter** | É a escolha certa: entrega Opus, jitter buffer adaptativo (NetEQ), AEC/NS/AGC e DTLS-SRTP prontos. Reescrever isso seria meses de trabalho pior. |
| Opus com FEC e DTX | **Manter, e somar RED** | FEC in-band só recupera 1 pacote perdido isolado. Wi-Fi em movimento perde em rajada. Ativar também redundância RED (`audio/red`), que custa ~20 kbps a mais e é irrelevante em rede local. [VALIDAR suporte no flutter_webrtc] |
| Sinalização WebSocket no host + mDNS | **Manter, com ressalvas** | (1) Não usar o pacote `multicast_dns`: ele abre socket multicast cru, o que no iOS exige o entitlement `com.apple.developer.networking.multicast`, que precisa de aprovação da Apple e não existe em Apple ID gratuito. Usar `bonsoir` ou `nsd`, que chamam o Bonjour nativo. (2) mDNS em hotspot de iPhone é instável: somar um atalho determinístico (seção 2.3). |
| Opção A: hotspot | **Principal no MVP** | Único caminho em que o WebRTC funciona sem modificação, e o único que cobre iOS↔Android. |
| Opção B: MultipeerConnectivity | **Trocar** | Multipeer é API antiga e opaca. O equivalente moderno é `Network.framework` com `includePeerToPeer = true` (mesmo rádio AWDL por baixo, com UDP de verdade). Porém o WebRTC provavelmente não faz ICE sobre a interface `awdl0` [VALIDAR], então esse caminho exige transporte de mídia próprio. Fica como evolução, não como fallback do MVP. |
| Wi-Fi Direct / Nearby Connections no Android | **Trocar** | Nearby Connections tem latência e throughput imprevisíveis para tempo real. No Android usar `WifiManager.startLocalOnlyHotspot()`: o app sobe um hotspot sem internet sozinho e mostra SSID/senha em QR. |
| `.allowBluetooth` + `.voiceChat` no iOS | **Manter** | Correto para HFP. Não incluir `.allowBluetoothA2DP` (A2DP não tem microfone; o iOS pode escolher A2DP para saída e o microfone do iPhone para entrada). |
| `UIBackgroundModes: audio` | **Suficiente** | Não precisa de `voip` (isso é PushKit, exige servidor) nem de CallKit no MVP. Sessão `playAndRecord` ativa mantém o app vivo com a tela bloqueada. CallKit entra depois, só para melhorar a convivência com ligações. |
| Permissão de Bluetooth no onboarding | **Remover no iOS** | Usar um headset HFP via AVAudioSession não exige permissão de Bluetooth (ela é do CoreBluetooth/BLE). Pedir permissão desnecessária assusta o usuário. No Android 12+ `BLUETOOTH_CONNECT` é necessária. |
| Mixar com música | **Expectativa a corrigir** | Com o link de voz (SCO) aberto, *todo* o áudio do capacete passa em qualidade de telefone, mono. GPS falado fica ok; música fica ruim. Não há como ter A2DP e microfone ao mesmo tempo num headset clássico. Ver seção 3.5. |
| Latência < 200 ms | **Apertado** | Só os dois saltos Bluetooth consomem 60–100 ms. A meta realista é 150–250 ms. Como os pilotos não se ouvem pelo ar, até ~300 ms não incomoda. |
| Mesh vs. host mixer para grupo | **Mesh até 6** | Só áudio, 6 pilotos = 5 streams Opus de ~24 kbps por aparelho. Trivial. Mixer/SFU dentro do app exigiria WebRTC nativo customizado sem ganho real. |

### O risco que pode invalidar o produto: alcance

Intercomunicadores mesh de verdade (Cardo DMC, Sena Mesh) usam rádio dedicado e chegam a centenas de metros ou mais. Wi-Fi entre dois celulares **dentro de bolso de jaqueta, com o corpo do piloto no meio**, entrega algo entre 10 e 50 m [VALIDAR]. Isso serve bem para piloto + garupa e para motos rodando coladas; não serve para grupo espaçado em estrada. O teste T2 mede isso antes de qualquer investimento no app. Mitigações: celular em suporte de guidão ou bolso externo, hotspot em 2,4 GHz.

### O que a versão 0.1 implementa, e onde ela simplifica este desenho

| Tema | Desenho (este documento) | Versão 0.1 no repositório |
|---|---|---|
| Descoberta | Sonda do gateway + Bonjour | Sonda do gateway + varredura da sub-rede /24 em `GET /info`, e endereço digitado à mão. Sem Bonjour: nenhuma dependência de multicast. |
| Pareamento | QR com segredo forte, chaves Ed25519 por aparelho | PIN de 6 dígitos com prova HMAC mútua, bloqueio após 5 erros. O PIN de um host conhecido fica salvo: entrar de novo é um toque. |
| Modo de fala | VOX por padrão | **Aberto** por padrão; VOX e PTT selecionáveis. O VOX depende de o WebRTC informar o nível do microfone com a trilha desligada, o que só dá para confirmar em aparelho. |
| Reconexão | ICE restart com token de retomada | Reautentica com o PIN salvo e recria a conexão. Mais simples, com um corte de ~1 s a mais. |
| Avisos no capacete | Frases gravadas + earcons | Voz sintetizada do sistema (TTS) + vibração. |
| Estado | Riverpod, go_router | `ChangeNotifier` e `Navigator` puros: menos peças para o tamanho atual. |
| Grupo | Malha até 6 | Já implementado na sinalização e nas conexões; a tela mostra grade quando há mais de um piloto remoto. Não testado com 3+. |
| Código nativo | Plugin de áudio completo | Android: canal `comboio/audio` com `getRoute` e `openSettings`. O roteamento Bluetooth usa o gerenciamento do próprio flutter_webrtc. iOS: nenhum código nativo ainda. |

---

## 1. Arquitetura

### 1.1 Visão ponta a ponta

```
 PILOTO A                                                              PILOTO B
┌──────────┐  BT HFP/SCO   ┌───────────────────────────┐            ┌───────────────────────────┐  BT HFP/SCO   ┌──────────┐
│ Capacete │◄─────────────►│        iPhone A (host)    │            │      iPhone B (cliente)   │◄─────────────►│ Capacete │
│ (headset)│  mSBC 16 kHz  │                           │            │                           │  mSBC 16 kHz  │ (headset)│
└──────────┘  ou CVSD 8k   │  Hotspot (AP Wi-Fi)       │◄══ Wi-Fi ═►│  Wi-Fi cliente            │               └──────────┘
                           │  WS sinalização :47800    │◄── TCP ───►│  WS cliente               │
                           │  Bonjour _comboio._tcp    │            │  Bonjour browse / gateway │
                           │  WebRTC PeerConnection    │◄─ SRTP/UDP►│  WebRTC PeerConnection    │
                           └───────────────────────────┘            └───────────────────────────┘
```

Regra do MVP: **quem cria a sala é quem liga o hotspot.** Assim o host da sala é sempre o gateway da rede, e o cliente o encontra sem depender de mDNS.

### 1.2 Camadas dentro do app

```
┌────────────────────────────────────────────────────────────────────┐
│ UI (Flutter)          telas, design system, modo painel            │
├────────────────────────────────────────────────────────────────────┤
│ Aplicação (Dart)      RoomController  ·  VoxController             │
│                       FeedbackService (voz/earcon/vibração)        │
├───────────────┬───────────────┬───────────────┬────────────────────┤
│ Sessão        │ Mídia         │ Descoberta    │ Segurança          │
│ SignalingHost │ PeerMesh      │ Bonjour       │ Identity (Ed25519) │
│ SignalingCli  │ (flutter_     │ GatewayProbe  │ Pairing (QR/PIN)   │
│ Reconnector   │  webrtc)      │               │ TrustStore         │
├───────────────┴───────────────┴───────────────┴────────────────────┤
│ Plataforma (platform channel `comboio/audio`)                      │
│  iOS: AVAudioSession, rotas, interrupções                          │
│  Android: AudioManager, foreground service, LocalOnlyHotspot       │
└────────────────────────────────────────────────────────────────────┘
```

Princípio: toda a lógica vive em Dart. O código nativo só faz o que o Dart não alcança (rota de áudio, serviço em primeiro plano, hotspot).

---

## 2. Transporte de rede

### 2.1 Decisão

| Par | MVP | Evolução |
|---|---|---|
| iOS ↔ iOS | Hotspot do host | AWDL via Network.framework, sem configurar nada (após spike S3) |
| Android ↔ Android | LocalOnlyHotspot do host (QR com SSID/senha) | — |
| iOS ↔ Android | Hotspot de qualquer um | Wi-Fi Aware (iOS 26+ e Android) [pesquisar] |

Justificativa do hotspot como principal:
- WebRTC funciona como está: interface Wi-Fi normal, IPv4, candidatos host.
- O iOS reconecta sozinho a uma rede Wi-Fi conhecida quando ela volta ao alcance. A reconexão de rede sai de graça; o app só refaz a sessão.
- Um caminho único para todas as combinações de plataforma.

### 2.2 Ressalvas do hotspot do iPhone

- **Modo avião desliga o Acesso Pessoal.** Usar "dados celulares ligados, sem cobertura", não modo avião. Se o hotspot liga e aceita clientes com zero barras é o teste T1 [VALIDAR]. Depende também de a operadora permitir tethering no plano.
- **O hotspot para de se anunciar** depois de um tempo sem clientes com a tela bloqueada [VALIDAR]. Efeito: se o cliente ficar minutos fora de alcance, pode não reencontrar a rede até o host abrir Ajustes > Acesso Pessoal. Mitigação: colocar os dois aparelhos em Compartilhamento Familiar com "Acesso Pessoal" automático, que acorda o hotspot por BLE.
- Ativar **Maximizar Compatibilidade** (força 2,4 GHz: mais alcance e atravessa melhor o corpo).
- Limite de clientes do hotspot do iPhone: 3 a 5 conforme modelo/operadora [VALIDAR]. Afeta o modo grupo.
- Se houver cobertura, o cliente usa a franquia de dados do host. No cliente: Ajustes > Wi-Fi > (rede) > **Modo de Pouco Dados**.
- O host gasta mais bateria. Recomendar alimentação USB na moto do host.

### 2.3 Descoberta em duas vias

1. **Atalho do gateway (principal):** o cliente lê o IP do gateway da rede Wi-Fi (`172.20.10.1` no hotspot do iPhone; obtido por `network_info_plus`) e tenta WebSocket na porta fixa 47800. Determinístico, rápido, não depende de multicast.
2. **Bonjour (secundário):** serviço `_comboio._tcp`. Serve quando os aparelhos estão num Wi-Fi comum (teste em casa, roteador de viagem) e para listar salas na tela "Entrar".

### 2.4 Evolução: AWDL sem hotspot (iOS↔iOS)

`NWListener`/`NWBrowser` com `includePeerToPeer = true` cria link direto entre iPhones, sem hotspot, sem dados celulares e sem operadora. É a melhor experiência possível ("abrir o app e falar").

O custo: se o ICE do WebRTC não funcionar sobre `awdl0`, a mídia precisa trafegar por `NWConnection` UDP próprio, o que implica pipeline próprio: `AVAudioEngine` com voice processing → Opus → pacotes → jitter buffer. São semanas de trabalho nativo. Decisão depois do spike S3 e só se o teste de campo mostrar que o hotspot atrapalha o uso.

---

## 3. Pipeline de áudio

### 3.1 Fluxo

```
Mic capacete A → SCO → iPhone A: VoiceProcessingIO → APM (HPF, NS, AGC) → gate VOX
  → Opus enc (16 kHz mono, 20 ms, FEC, DTX, RED) → SRTP → UDP/Wi-Fi
  → iPhone B: SRTP → NetEQ (jitter buffer, PLC) → Opus dec → mixer → saída
  → SCO → fone capacete B
```

### 3.2 Parâmetros

| Parâmetro | Valor | Motivo |
|---|---|---|
| Amostragem | 16 kHz mono | O HFP entrega no máximo 16 kHz (mSBC). Capturar acima disso é desperdício. |
| Opus | 24 kbps, quadro de 20 ms | Voz wideband transparente. Quadros de 10 ms economizam 10 ms e dobram os pacotes; não compensa. |
| `useinbandfec=1` | ligado | Recupera perda isolada. |
| `usedtx=1` | ligado | Silêncio custa quase zero de rede e bateria. |
| RED | ligado se disponível | Protege contra perda em rajada. |
| AEC | ligado (nativo) | Com fone no ouvido o eco é pequeno, mas há vazamento dentro do capacete. |
| NS | ligado, nível alto | Ver 3.4 sobre vento. |
| AGC | ligado | Compensa distância variável do microfone à boca. |

Munging do SDP: `a=fmtp:111 minptime=10;useinbandfec=1;usedtx=1;maxaveragebitrate=24000;stereo=0;sprop-stereo=0`.

### 3.3 Orçamento de latência (boca → ouvido, um sentido)

| Etapa | Típico | Pior caso |
|---|---|---|
| Mic → celular por SCO (codec + rádio + DSP do headset) | 30 ms | 50 ms |
| Buffer de captura + processamento (APM) | 15 ms | 25 ms |
| Opus (quadro 20 ms + lookahead) | 25 ms | 25 ms |
| Wi-Fi local (inclui retransmissões 802.11) | 5 ms | 30 ms |
| Jitter buffer (NetEQ, adaptativo) | 40 ms | 100 ms |
| Decodificação + buffer de saída | 15 ms | 25 ms |
| Celular → fone por SCO | 30 ms | 50 ms |
| **Total** | **~160 ms** | **~305 ms** |

Os números de SCO e do DSP do headset são estimativas; o teste T3 mede o valor real (batida de palmas gravada por um terceiro aparelho). O único botão de ajuste relevante é o jitter buffer; todo o resto é fixo pelo hardware.

### 3.4 Vento e ruído

O NS do WebRTC foi feito para ruído estacionário (ventilador, motor). Vento é turbulento e passa parcialmente. Camadas de defesa, em ordem de custo:
1. Física: espuma no microfone e posicionamento dentro da queixeira. Resolve mais que qualquer software.
2. Filtro passa-alta (já no APM) + NS em nível alto.
3. Gate VOX com limiar ajustável e calibração automática: mede o piso de ruído por 3 s com a moto andando e põe o limiar acima dele.
4. Futuro: supressor neural (RNNoise ou similar) no caminho de captura nativo. Só se o T4 mostrar que é necessário.

### 3.5 VOX e PTT

- **VOX (padrão):** o microfone fica sempre capturando. O app lê o nível de entrada (estatística `audioLevel` do WebRTC, a cada 50 ms) e liga/desliga `track.enabled`. Ataque imediato ao passar do limiar, sustentação (hangover) de 800 ms. Com a trilha desligada + DTX, o envio cai a quase zero. Limitação conhecida: corta ~50–100 ms do início da primeira sílaba. Aceitável no MVP; a correção definitiva é VAD nativo com pré-buffer.
- **PTT:** botão gigante na tela e, se possível, o botão multifunção do capacete. Capturar botão de headset HFP sem CallKit é limitado no iOS [VALIDAR]. No MVP, PTT é só na tela (modo painel).
- **Mudo:** `track.enabled = false` fixo, com aviso sonoro.

### 3.6 Convivência com GPS e música

| Situação | Comportamento |
|---|---|
| Voz do Waze/Maps durante a conversa | Toca no capacete pelo mesmo link de voz. Sessão configurada com `mixWithOthers` para não calar o navegador. |
| Música durante a conversa | Toca, mas em qualidade de telefone mono. Limitação do Bluetooth clássico. |
| "Modo música" (futuro) | Com PTT: SCO fechado em repouso (música em A2DP com qualidade plena); ao apertar PTT ou ao chegar voz do outro piloto, abre o SCO. Custo: 1–2 s para abrir o link, e reativar gravação com o app em segundo plano no iOS é arriscado [VALIDAR]. Não entra no MVP. |
| Ligação telefônica | O iOS interrompe a sessão. O app avisa os pares ("em ligação"), e retoma ao fim. A notificação de fim de interrupção nem sempre chega com o app em segundo plano [VALIDAR em T5]; se falhar, a solução é integrar CallKit. |

### 3.7 Rota Bluetooth

- **iOS:** categoria `.playAndRecord`, modo `.voiceChat`, opções `[.allowBluetooth, .mixWithOthers]`. Fixar a entrada com `setPreferredInput` no port `bluetoothHFP`. Observar `routeChangeNotification`.
- **Android:** `MODE_IN_COMMUNICATION` + `setCommunicationDevice()` (API 31+) com o device `TYPE_BLUETOOTH_SCO`; abaixo de 31, `startBluetoothSco()`.
- **Capacete caiu no meio da conversa:** o sistema cai para o alto-falante e o microfone do celular. O app precisa reagir imediatamente: silenciar envio e reprodução (privacidade e ruído), vibrar, mostrar erro em tela cheia. Quando a rota HFP volta: re-fixar a entrada, retomar, tocar o earcon de "capacete conectado".
- O flutter_webrtc gerencia a AVAudioSession por conta própria. É preciso configurar pela API dele (`Helper.setAppleAudioConfiguration` ou equivalente da versão em uso) e não brigar com ele pelo platform channel. [VALIDAR no spike S1]

---

## 4. Descoberta, sinalização e sessão

### 4.1 Anúncio Bonjour

Serviço `_comboio._tcp`, porta 47800. Registro TXT:

| Chave | Exemplo | Significado |
|---|---|---|
| `v` | `1` | Versão do protocolo |
| `rid` | `a3f91c02` | ID da sala |
| `name` | `Sala do Léo` | Nome exibido |
| `n` | `1/6` | Ocupação |
| `kid` | `9b2e…` (8 hex) | Prefixo da chave pública do host, para reconhecer host já confiado |

### 4.2 Mensagens de sinalização

WebSocket em `ws://<host>:47800/v1`, JSON, um objeto por frame. Todo objeto tem `t` (tipo).

| Tipo | Direção | Campos | Uso |
|---|---|---|---|
| `hello` | C→H | `v, peerId, name, color, pub, nonceC` | Apresentação |
| `challenge` | H→C | `pub, nonceH, mode` (`known`/`pair`) | Host pede prova |
| `auth` | C→H | `proof` | Prova (seção 5) |
| `welcome` | H→C | `roomId, you, peers[], resume` | Entrada aceita; `resume` é token de retomada |
| `reject` | H→C | `code` (`full`, `auth`, `version`) | Recusa |
| `peer-joined` / `peer-left` | H→todos | `peer` / `peerId, reason` | Presença |
| `offer` / `answer` / `candidate` | par→par via H | `from, to, sdp` ou `cand`, `mac` | Negociação WebRTC, retransmitida pelo host |
| `state` | par→todos via H | `muted, mode, onCall, batt` | Estado do piloto |
| `resume` | C→H | `peerId, resume, nonceC` | Retomada rápida após queda |
| `ping` / `pong` | ambos | `ts` | Keepalive do socket (5 s) |
| `bye` | ambos | — | Saída voluntária |

Regra anti-colisão na malha: entre dois pares, quem tem o `peerId` menor (ordem lexicográfica) envia a `offer`.

### 4.3 Canal de controle em chamada

DataChannel `ctl` em cada PeerConnection, não confiável e não ordenado. A cada 500 ms: `{seq, ts, talking, batt, lat?, lon?}`.
- Detecta perda de link em ~1,5 s (o ICE sozinho leva 5 s ou mais).
- Leva o indicador "falando" sem passar pelo host.
- `lat/lon` opcional alimenta a distância real em metros (GPS funciona sem internet).

### 4.4 Máquina de estados (por par)

```
            criar/entrar
  IDLE ───────────────► DISCOVERING ──achou host──► JOINING ──welcome──► NEGOTIATING
   ▲                        │ timeout 15 s               │ reject              │ ICE connected
   │                        ▼                            ▼                     ▼
   │                   NOT_FOUND                    AUTH_FAILED            CONNECTED ◄────────────┐
   │                                                                          │ 3 heartbeats      │
   │ sair                                                                     ▼ perdidos (1,5 s)  │ heartbeat
   └───────────────────────────────────────────────────────────────────── DEGRADED ──────────────┤ volta
                                                                              │ 4 s sem nada      │
                                                                              ▼                   │
                                                                         RECONNECTING ────────────┘
                                                                         (tenta para sempre)
```

| Estado | Tela | Capacete |
|---|---|---|
| CONNECTED | Anel verde | — |
| DEGRADED | Anel âmbar pulsando | Silêncio (evita falso alarme em curva ou caminhão no meio) |
| RECONNECTING | Anel vermelho, "Fora do alcance" | Earcon descendente + "Piloto 2 fora do alcance", uma vez |
| volta a CONNECTED | Anel verde | Earcon ascendente + "Reconectado" |

### 4.5 Reconexão

Laço do cliente em RECONNECTING:
1. Wi-Fi associado à rede da sala? Se não, esperar (o sistema reassocia sozinho).
2. Tentar WebSocket no gateway:47800, timeout de 1,5 s.
3. Enviar `resume` com o token; o host responde `welcome` sem repetir o pareamento.
4. Renegociar com **ICE restart** na PeerConnection existente. Se falhar duas vezes, destruir e recriar a PeerConnection.

Ritmo: a cada 2 s no primeiro minuto, depois a cada 5 s, sem limite de tempo. O custo é um SYN TCP por tentativa. A sala só termina quando alguém sai explicitamente. Sem migração de host: se o host sai, a rede some junto, então não há o que migrar.

---

## 5. Segurança

**Modelo de ameaça:** alguém a até ~50 m tentando ouvir ou entrar na conversa. Não é um adversário com recursos, mas "qualquer um com o app entra na minha sala" é inaceitável.

**Camadas:**
1. Wi-Fi do hotspot já é WPA2/WPA3.
2. Mídia: DTLS-SRTP do WebRTC, sempre ligado.
3. O que falta resolver é autenticar *com quem* o DTLS foi fechado. É isso que o pareamento faz.

**Identidade:** cada instalação gera um par Ed25519 guardado no Keychain/Keystore. `peerId` = primeiros 16 hex do SHA-256 da chave pública.

**Pareamento (primeira vez):**
- **QR (padrão, forte):** o host mostra QR com `{rid, pub do host, segredo de 128 bits, SSID/senha quando Android}`. O cliente prova posse com `proof = HMAC(segredo, nonceH ‖ nonceC ‖ pubC)`. Parados no acostamento, um aponta a câmera para a tela do outro.
- **PIN de 6 dígitos (conveniência):** mesmo fluxo, com chave derivada do PIN. Limitação declarada: 10⁶ combinações permitem ataque offline por quem capturar a troca. Mitigações: 3 tentativas, PIN válido por 2 minutos e uso único. A proteção total exigiria PAKE (SPAKE2); entra se houver implementação Dart confiável.

**Depois do primeiro pareamento (TOFU):** cada lado guarda a chave pública do outro como "piloto conhecido". Nas próximas vezes, `challenge.mode = known` e a prova é uma assinatura Ed25519 sobre os nonces. Sem PIN, sem QR: o cliente toca "Entrar" e está dentro. É isso que garante os 2 toques.

**Ligação entre pareamento e mídia:** cada `offer`/`answer` leva `mac` = assinatura Ed25519 do fingerprint DTLS contido no SDP. Um intermediário não consegue trocar o fingerprint sem invalidar a assinatura.

---

## 6. Grupo (3 a 6)

- **Topologia de mídia:** malha completa. Cada par tem sua PeerConnection.
- **Topologia de rede:** estrela (todos no hotspot do host). Todo pacote entre dois clientes passa pelo rádio do host, então o alcance útil é a distância de cada um até o host. O host deve rodar no meio do grupo.
- **Sinalização:** o host retransmite `offer/answer/candidate` entre clientes.
- **Custos com 6:** 5 codificações Opus e ~120 kbps de subida por aparelho. Irrelevante.
- **Limites reais:** número de clientes do hotspot (2.2) e alcance.
- O protocolo do MVP já nasce com `peers[]` e roteamento `from/to`; o grupo não exige mudança de formato.

---

## 7. Estrutura do projeto Flutter

```
lib/
  main.dart
  app.dart                         MaterialApp, rotas, tema
  design/
    tokens.dart                    cores, espaçamento, raios, durações
    theme.dart                     ThemeData escuro e claro
    widgets/                       BigButton, StatusRing, VoiceWave, PilotTile, ...
  features/
    onboarding/                    permissões, checagem do capacete
    home/                          Criar sala / Entrar
    room/                          sala ativa, modo painel
    settings/
    errors/                        telas de erro em tela cheia
  core/
    room/room_controller.dart      orquestra tudo; estado exposto à UI
    session/
      signaling_host.dart          servidor WS (dart:io HttpServer)
      signaling_client.dart
      protocol.dart                tipos de mensagem
      reconnector.dart
    media/
      peer_mesh.dart               PeerConnections, SDP munging, stats
      vox_controller.dart
    discovery/
      bonjour_discovery.dart
      gateway_probe.dart
    security/
      identity.dart                Ed25519
      pairing.dart                 QR, PIN, provas
      trust_store.dart
    audio/
      audio_route.dart             fachada do platform channel
    feedback/
      feedback_service.dart        earcons, frases, vibração
    settings/settings_store.dart
assets/
  fonts/  audio/pt-BR/  icon/
ios/Runner/AudioRoutePlugin.swift
android/app/src/main/kotlin/.../AudioRoutePlugin.kt
android/app/src/main/kotlin/.../IntercomService.kt     foreground service
android/app/src/main/kotlin/.../HotspotPlugin.kt       LocalOnlyHotspot
```

### 7.1 Platform channel `comboio/audio`

| Método (Dart → nativo) | Retorno |
|---|---|
| `getRoute()` | `{input, output, isBluetoothHfp, deviceName}` |
| `configureForIntercom()` | aplica categoria/modo e fixa a entrada HFP |
| `releaseAudio()` | desativa a sessão |
| `startForegroundService()` / `stop…` | Android apenas |
| `startLocalHotspot()` | Android: `{ssid, password}` |

| Evento (nativo → Dart, EventChannel `comboio/audio/events`) | Quando |
|---|---|
| `routeChanged {…}` | capacete conectou/desconectou |
| `interruptionBegan` / `interruptionEnded {shouldResume}` | ligação, Siri, alarme |

### 7.2 Dependências

| Pacote | Para quê |
|---|---|
| `flutter_webrtc` | Mídia |
| `bonsoir` (ou `nsd`) | Bonjour nativo. **Não** usar `multicast_dns` |
| `network_info_plus` | IP do gateway, SSID |
| `flutter_riverpod` | Estado |
| `go_router` | Rotas |
| `cryptography` | Ed25519, HMAC, HKDF |
| `flutter_secure_storage` | Chave privada |
| `shared_preferences` | Preferências |
| `permission_handler` | Permissões |
| `mobile_scanner` + `qr_flutter` | Ler e mostrar QR |
| `wakelock_plus` | Modo painel |
| `just_audio` | Earcons e frases |
| `geolocator` | Distância real (extra) |

Fontes vão como asset no app. **Não** usar `google_fonts` baixando em tempo de execução: o app é para uso offline.

Servidor WebSocket: `dart:io` (`HttpServer` + `WebSocketTransformer`), sem pacote extra.

---

## 8. Configurações nativas

### 8.1 iOS — `Info.plist`

```xml
<key>NSMicrophoneUsageDescription</key>
<string>O Comboio usa o microfone do capacete para você conversar com os outros pilotos.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>O Comboio conecta os celulares dos pilotos diretamente, sem internet.</string>
<key>NSBonjourServices</key>
<array>
  <string>_comboio._tcp</string>
</array>
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
<key>NSCameraUsageDescription</key>
<string>Para ler o QR code da sala de outro piloto.</string>
```

Extras, só quando o recurso existir: `NSLocationWhenInUseUsageDescription` (distância).

As quatro primeiras chaves já estão em `ios/Runner/Info.plist`. A da câmera entra junto com o leitor de QR.

**Entitlements:** nenhum. Tudo acima é chave de Info.plist e funciona com Apple ID gratuito. O que **não** está disponível em conta gratuita e por isso foi evitado no desenho: push/VoIP push, entitlement de multicast, Wi-Fi Aware, Hotspot Configuration (entrar em Wi-Fi por código) [VALIDAR este último].

A permissão de Rede Local não tem API de consulta: o diálogo aparece na primeira tentativa de uso. O onboarding dispara uma busca Bonjour de propósito para provocá-lo no momento certo.

### 8.2 Android — `AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE"/>
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE"/>
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES"
                 android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.CAMERA"/>

<application ...>
  <service android:name=".IntercomService"
           android:foregroundServiceType="microphone"
           android:exported="false"/>
</application>
```

Notas: o serviço em primeiro plano tem de ser iniciado com o app visível (Android 14+ bloqueia iniciar serviço de microfone em segundo plano). Pedir ao usuário para isentar o app da otimização de bateria; fabricantes como Xiaomi e Samsung matam serviços de forma agressiva.

# Comboio — Testes de campo e roadmap

A ordem importa: os testes T1 e T2 custam uma tarde e podem derrubar a ideia inteira. Fazer antes de escrever o app.

## 1. Testes sem escrever código (uma tarde)

Material: os dois iPhones, os dois capacetes com headset Bluetooth, um app de chamada que funcione em rede local sem internet (ou, no mínimo, `ping` por um app de utilitários de rede) e uma trena ou o odômetro.

### T1 — Hotspot sem cobertura

Pergunta: o Acesso Pessoal liga e aceita cliente sem sinal?

1. Num lugar sem cobertura (ou simulando: Ajustes > Celular > Seleção de Rede manual, escolhendo uma operadora que não é a sua, para ficar "Sem Serviço" com os dados celulares ligados).
2. iPhone A: ligar Acesso Pessoal + Maximizar Compatibilidade.
3. iPhone B: entrar no Wi-Fi do A.
4. Repetir em modo avião com Wi-Fi religado, para registrar o comportamento.
5. Bloquear a tela dos dois por 10 minutos e conferir se B continua associado.
6. Afastar B até cair, esperar 5 minutos, voltar: B reassocia sozinho? Com a tela do A bloqueada?

Passa se: os passos 3, 5 e 6 funcionam com dados celulares ligados e sem serviço.
Se falhar o 6: testar com Compartilhamento Familiar. Se falhar o 3: o caminho hotspot morre para iPhone e o projeto depende do AWDL (S3).

### T2 — Alcance

Pergunta: a que distância o link aguenta, com o celular onde ele realmente vai ficar?

Medir `ping` contínuo de B para `172.20.10.1` e anotar a distância em que a perda passa de 5% e a distância em que cai de vez. Cenários:

| Cenário | Celular A | Celular B |
|---|---|---|
| a | Na mão, visada direta | Na mão |
| b | Bolso interno da jaqueta | Bolso interno |
| c | Bolso da calça, sentado na moto | Idem |
| d | Suporte de guidão | Suporte de guidão |
| e | Melhor combinação acima, rodando a 60 e a 100 km/h, moto B atrás e depois na frente | |

Critério de decisão:
- Menos de 15 m no cenário realista: o produto só serve para piloto + garupa. Reavaliar.
- 20 a 50 m: viável para rodar em formação. Seguir.
- Mais de 50 m: ótimo.

### T2b — Capacete

Parear cada headset com seu iPhone, fazer uma ligação comum e observar: qualidade do microfone a 80–100 km/h, se o headset negocia voz HD (mSBC) ou só banda estreita, e quanto tempo leva para reconectar ao ser desligado e religado.

## 2. Spikes com código mínimo

Cada spike é um app descartável de uma tela, instalado por sideload.

| Spike | O que constrói | Responde |
|---|---|---|
| **S0** | Casca do app (o que já está no repositório) instalada com Apple ID gratuito | T0: o pipeline sem Mac funciona de ponta a ponta? As chaves de áudio em segundo plano e rede local sobrevivem à assinatura do Sideloadly? |
| **S1** | Chamada WebRTC entre dois IPs digitados à mão, com o capacete | Áudio entra e sai pelo headset? A sessão de áudio do flutter_webrtc aceita a configuração HFP? RED/FEC/DTX negociam? |
| **S2** | S1 + servidor WebSocket no host + sonda do gateway + Bonjour | A descoberta funciona no hotspot do iPhone? O diálogo de Rede Local aparece? |
| **S3** | Dois `NWConnection` UDP com `includePeerToPeer` trocando pacotes; e tentativa de ICE do WebRTC sem Wi-Fi associado | O AWDL serve como transporte? O WebRTC enxerga a interface? Qual o jitter? |

## 3. Testes de campo com o spike S1/S2

| Teste | Procedimento | Passa se |
|---|---|---|
| **T3 Latência** | Um terceiro celular grava em vídeo: bater palma perto do microfone A com o fone B encostado no gravador. Medir o intervalo no áudio da gravação. | ≤ 250 ms |
| **T4 Ruído** | Rodar a 60, 80, 100 km/h com viseira fechada e aberta. Gravar o que chega em B. Testar NS normal/forte e 3 limiares de VOX. | Fala compreensível a 100 km/h; VOX não abre sozinho com vento |
| **T5 Interrupções** | Com a conversa ativa e tela bloqueada: (a) receber ligação e atender; (b) receber e recusar; (c) Waze dando instruções; (d) tocar música; (e) Siri; (f) alarme. | A conversa volta sozinha em todos; anotar os que não voltam |
| **T6 Segundo plano e bateria** | Conversa aberta, telas bloqueadas, 3 horas. Anotar bateria a cada 30 min nos dois aparelhos e a temperatura no bolso. | App vivo às 3 h; host ≤ 20%/h, cliente ≤ 12%/h |
| **T7 Bluetooth** | Desligar e religar o capacete no meio da conversa; afastar o capacete do celular até cair e voltar. | Áudio não vaza pelo alto-falante; volta ao capacete sem tocar na tela |
| **T8 Reconexão** | Afastar até cair, por 10 s, 1 min e 5 min, e reaproximar. Tela bloqueada. | Volta em ≤ 5 s após a rede reassociar, nos três casos |
| **T9 Perda** | Rodar no limite do alcance medido em T2. Comparar com e sem RED. | Fala compreensível com 10–15% de perda |

Registrar tudo numa planilha simples: data, versão do iOS, modelo, cenário, resultado, observação.

## 4. Mapa risco → teste

| Risco (do briefing) | Teste |
|---|---|
| 1. Hotspot sem cobertura | T1 |
| 2. Alcance em movimento | T2, T9 |
| 3. Sessão viva com tela bloqueada | T6 |
| 4. Capacete desconecta e reconecta | T7 |
| 5. Ligações e navegação | T5 |
| 6. Capabilities no sideload gratuito | S0 |
| (novo) Hotspot para de se anunciar | T1 passo 6, T8 |
| (novo) WebRTC × sessão de áudio HFP | S1 |
| (novo) Vento | T2b, T4 |

## 5. Roadmap

| Fase | Entrega | Critério de saída |
|---|---|---|
| **0. Validação** | T1, T2, T2b; pipeline S0 instalado nos dois iPhones | Alcance realista ≥ 20 m e hotspot funciona sem sinal. **Ponto de decisão: seguir, mudar de transporte ou parar.** |
| **1. Spikes** | S1, S2 (S3 se T1 falhar) | Dois capacetes conversando por WebRTC em rede local |
| **2. MVP** | 2 pilotos, iOS, hotspot. Criar/Entrar, QR, pilotos conhecidos, VOX + mudo, reconexão, avisos por voz, telas de erro, design system, onboarding | T3 a T9 passam |
| **3. Estrada** | Uma viagem real de 3 h. Ajustes de VOX, NS, jitter buffer e textos | Dois fins de semana sem precisar mexer no celular em movimento |
| **4. Android** | Plugin de áudio, serviço em primeiro plano, LocalOnlyHotspot, workflow de APK | Android↔Android e iOS↔Android conversando |
| **5. TestFlight** | Conta paga, workflow de TestFlight, pastas nativas versionadas | Instalação sem PC |
| **6. Grupo** | Malha de 3 a 6, grade de pilotos, limites do hotspot medidos | 4 pilotos por 1 hora |
| **7. Extras** | PTT, modo painel completo, distância por GPS, AWDL sem hotspot (iOS), modo música, CallKit, supressor de ruído neural, tema claro refinado | Por demanda |

Fora de escopo com headsets Bluetooth comuns: alcance de centenas de metros. Isso exige rádio dedicado.

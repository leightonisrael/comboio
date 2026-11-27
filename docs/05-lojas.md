# Comboio — Publicação nas lojas

Textos e respostas prontos para o Google Play Console e o App Store Connect. Tudo aqui descreve o app como ele é hoje; se o app mudar (por exemplo, passar a usar localização), as respostas mudam junto.

## Antes de publicar

1. **Identificador do app.** Hoje é `br.com.comboio.comboio`. Depois de publicado, **não dá para trocar**, nem no Google Play nem na App Store. Use um domínio que seja seu.
2. **Nome.** Na App Store o nome precisa ser único no mundo. Se "Comboio" estiver ocupado, use uma variação, como "Comboio Intercom".
3. **Teste em aparelho.** As duas lojas revisam o app funcionando. Enviar para revisão antes de testar em dois celulares é pedir rejeição. Use primeiro as trilhas de teste (abaixo), que não passam por revisão completa.

## Caminho recomendado

| Etapa | Google Play | App Store |
|---|---|---|
| 1. Teste interno | Teste interno: até 100 pessoas por e-mail, sem revisão | TestFlight interno: até 100 pessoas da equipe, sem revisão |
| 2. Teste fechado | Obrigatório em contas pessoais criadas depois de novembro de 2023: 12 testadores por 14 dias antes de liberar produção | TestFlight externo: passa por uma revisão rápida |
| 3. Produção | Revisão do Google | Revisão da Apple |

O TestFlight interno já resolve "instalar no iPhone sem PC": o app chega pelo aplicativo TestFlight.

## Textos da loja

**Nome:** Comboio

**Descrição curta (até 80 caracteres):**
Intercomunicador de capacete sem internet: fale com outros pilotos pelo Wi-Fi.

**Subtítulo (App Store, até 30 caracteres):**
Intercom de moto sem internet

**Descrição completa:**

Converse com outros pilotos durante o passeio, sem internet e sem sinal de operadora.

O Comboio transforma o celular de cada piloto em um intercomunicador. Cada um usa o próprio capacete Bluetooth com o próprio celular, e os celulares se falam por Wi-Fi local. Funciona com qualquer intercomunicador ou fone de capacete que atenda ligações, de qualquer marca.

COMO FUNCIONA
• Um piloto liga o roteador Wi-Fi do celular e cria a sala.
• Os outros conectam nesse Wi-Fi e entram na sala com um PIN.
• Guardem os celulares e rodem. A conversa segue com a tela bloqueada.

RECURSOS
• Sem internet, sem chip, sem cadastro.
• Botões grandes, feitos para usar de luva.
• Três modos de fala: microfone aberto, ativação por voz (VOX) e apertar para falar (PTT).
• Reconecta sozinho quando as motos se afastam e voltam.
• Avisos por voz no capacete: quem conectou, quem saiu do alcance, quem voltou.
• Tema escuro de alto contraste e tema claro.
• Até 6 pilotos na mesma sala.

BOM SABER
• O alcance é o do Wi-Fi entre os celulares: algumas dezenas de metros. É indicado para piloto e garupa ou motos rodando próximas.
• Durante a conversa, músicas tocam com qualidade de ligação. É uma limitação do Bluetooth dos capacetes.

PRIVACIDADE
O áudio vai direto de um celular para o outro, criptografado. Nada é gravado e nada é enviado para a internet.

**Palavras-chave (App Store, até 100 caracteres):**
intercomunicador,moto,capacete,intercom,piloto,garupa,offline,walkie,talkie,bluetooth,motociclista

**Categoria:** Comunicação (alternativa: Navegação/Viagem não se aplica).

**Política de privacidade (URL):**
https://github.com/leightonisrael/intercomunicador-v10/blob/main/docs/privacidade.md

**Classificação etária:** Livre. O app não tem conteúdo; os usuários só conversam com quem está na mesma rede Wi-Fi e conhece o PIN.

## Google Play — formulários

**Segurança dos dados**

| Pergunta | Resposta |
|---|---|
| O app coleta ou compartilha dados do usuário? | Não |
| Os dados são criptografados em trânsito? | Sim (o áudio entre os celulares usa DTLS-SRTP) |
| O usuário pode pedir exclusão dos dados? | Não se aplica: nada é coletado |

Observação: no formulário do Google, áudio processado apenas de forma efêmera e que não sai para servidores do desenvolvedor não conta como "coletado". O áudio do Comboio vai só para os outros aparelhos da sala.

**Permissão de serviço em primeiro plano (microfone)**

O Google pede justificativa e um vídeo curto mostrando o uso.

- Tipo: `microphone`
- Justificativa: "O app é um intercomunicador de voz para motociclistas. O usuário inicia a conversa com o app aberto e guarda o celular no bolso; a chamada de voz precisa continuar com a tela bloqueada durante todo o trajeto. O serviço começa quando o usuário cria ou entra em uma sala e termina quando ele sai."
- Vídeo: gravar a tela criando a sala, bloqueando o celular e mostrando a notificação "Conversa ativa".

**Público-alvo:** 18 anos ou mais (habilitação de moto). Evita as exigências de apps para crianças.

**Anúncios:** não contém.

**Formato do envio:** o Google Play exige `.aab` em vez de `.apk`:

```
C:\src\flutter\bin\flutter build appbundle --release
```

Sai em `build\app\outputs\bundle\release\app-release.aab`. Na primeira publicação o Play Console oferece a Assinatura de Apps do Google Play; aceite e mantenha a chave local como chave de upload.

## App Store Connect — formulários

**Privacidade do app:** "Dados não coletados".

**Conformidade de exportação:** o app usa apenas criptografia padrão (DTLS-SRTP). O `Info.plist` já declara `ITSAppUsesNonExemptEncryption = false`, então a pergunta não aparece a cada envio.

**Notas para a revisão (obrigatório explicar, porque o revisor não tem dois capacetes):**

"Comboio é um intercomunicador de voz em rede local. Para testar são necessários dois aparelhos na mesma rede Wi-Fi: no primeiro, toque em Criar sala; no segundo, toque na sala listada e digite o PIN mostrado no primeiro. Não é preciso capacete: sem fone Bluetooth, o áudio usa o microfone e o fone de ouvido do próprio aparelho. O app usa o modo de áudio em segundo plano para manter a chamada de voz ativa com a tela bloqueada, como um aplicativo de chamadas."

**Envio do build:** não é pelo navegador. O build sobe pelo workflow `iOS (TestFlight)` do GitHub Actions, que precisa de quatro segredos no repositório (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`, `APPLE_TEAM_ID`). Ver `03-build-e-instalacao.md`, Fase 2.

## Capturas de tela

As duas lojas exigem capturas reais do app. Tamanhos mínimos:

| Loja | Exigência |
|---|---|
| Google Play | 2 a 8 capturas de celular, mais ícone 512×512 e imagem de destaque 1024×500 |
| App Store | Capturas de iPhone 6,9" (1320×2868) ou 6,5" |

Telas a capturar: Home com uma sala listada, Sala ativa com piloto falando, Sala em modo PTT, Como conectar, Configurações.

# Comboio — Build e instalação sem Mac

Guia para quem nunca instalou um app de iPhone fora da App Store. Tudo é feito a partir de um PC com Windows.

Como funciona, em uma frase: o GitHub compila o app num Mac alugado na nuvem e entrega um arquivo `.ipa`; no seu PC, um programa assina esse arquivo com o seu Apple ID e instala no iPhone pelo cabo.

---

## Fase 1 — Gratuita (desenvolvimento e teste de campo)

### Passo 1. Colocar o projeto no GitHub

1. Crie uma conta em github.com, se ainda não tem.
2. Na pasta do projeto, pelo terminal:
   ```
   gh auth login
   gh repo create comboio --public --source . --push
   ```
   **Público ou privado?** Em repositório público os minutos de macOS do GitHub Actions são gratuitos e ilimitados. Em repositório privado, a conta gratuita tem 2.000 minutos por mês e cada minuto de macOS conta como 10, o que dá cerca de 200 minutos reais, ou 10 a 15 builds. Se o código pode ser aberto, use público.

### Passo 2. Gerar o `.ipa`

1. No site do repositório, abra a aba **Actions**.
2. À esquerda, clique em **iOS (IPA sem assinatura)**.
3. Clique em **Run workflow** > **Run workflow**.
4. Espere ficar verde (10 a 15 minutos).
5. Clique na execução e, no fim da página, em **Artifacts**, baixe `comboio-ios-unsigned`.
6. Descompacte o `.zip`. Dentro está `comboio-unsigned.ipa`.

### Passo 3. Preparar o PC (uma vez só)

1. **Desinstale** o iTunes e o iCloud se vieram da Microsoft Store (Configurações > Aplicativos).
2. Instale o **iTunes** pelo site da Apple: na página de download, role até "Procurando outras versões?" e escolha **Windows**. O instalador deve ser um `.exe` (iTunes64Setup.exe), não um link para a loja.
3. Instale o **iCloud para Windows** também na versão de instalador direto da Apple (necessário apenas para o AltStore).
4. Reinicie o PC.
5. Conecte o iPhone pelo cabo, desbloqueie e toque em **Confiar** quando aparecer "Confiar neste computador?". Abra o iTunes e confirme que o iPhone aparece.

Por que não a versão da loja: as versões da Microsoft Store ficam isoladas e os programas de sideload não conseguem usar os drivers delas.

### Passo 4. Instalar com o Sideloadly (caminho mais simples)

1. Baixe o Sideloadly em sideloadly.io e instale.
2. Abra o Sideloadly com o iPhone conectado; ele aparece em **iDevice**.
3. Arraste o `comboio-unsigned.ipa` para a janela.
4. Em **Apple ID**, digite o seu. Recomendação: crie um Apple ID separado só para isso, para não expor a conta principal a um programa de terceiros.
5. Clique em **Start**. Digite a senha e o código de dois fatores quando pedir.
6. Aguarde "Done".

### Passo 5. Liberar no iPhone (uma vez só)

1. **Confiar no desenvolvedor:** Ajustes > Geral > VPN e Gerenciamento de Dispositivos > toque no seu Apple ID > **Confiar**.
2. **Modo de Desenvolvedor** (iOS 16 ou mais novo): Ajustes > Privacidade e Segurança > role até o fim > **Modo de Desenvolvedor** > ligar. O iPhone reinicia e pede confirmação.
   A opção só aparece *depois* de você instalar o primeiro app por sideload. Se não aparecer, repita o passo 4.
3. Abra o Comboio. Aceite microfone e rede local.

Repita os passos 4 e 5 no segundo iPhone. Pode ser o mesmo Apple ID.

### Limites da conta gratuita

| Limite | Consequência |
|---|---|
| O app vale **7 dias** | Depois disso ele não abre. Reinstale por cima (passo 4): as configurações do app são mantidas. |
| **3 apps** por aparelho | Somados todos os instalados por sideload com Apple ID gratuito. |
| **10 identificadores de app** a cada 7 dias | Só incomoda se você mudar o identificador do app várias vezes. |

**Regra de ouro para viagem:** reinstale na véspera. Um app que expirou no meio da estrada não tem conserto sem o PC.

### Renovação automática com AltStore (opcional)

Para não reinstalar à mão toda semana:

1. Baixe o **AltServer** em altstore.io e instale no PC.
2. Com o iPhone no cabo: ícone do AltServer na bandeja do Windows > **Install AltStore** > seu iPhone. Informe o Apple ID.
3. No iPhone, confie no perfil (passo 5.1) e abra o AltStore.
4. Mande o `.ipa` para o iPhone (iCloud Drive, por exemplo). No AltStore: aba **My Apps** > **+** > escolha o arquivo.
5. No iTunes, com o iPhone selecionado, marque **Sincronizar com este iPhone via Wi-Fi**.
6. Deixe o AltServer rodando no PC. Quando o iPhone estiver no mesmo Wi-Fi do PC, o AltStore renova os apps em segundo plano.

Detalhes: o próprio AltStore ocupa 1 das 3 vagas. A renovação automática nem sempre dispara; abra o AltStore e toque em **Refresh All** antes de viajar.

### O que funciona com Apple ID gratuito

| Recurso | Funciona? | Por quê |
|---|---|---|
| Áudio em segundo plano | Sim | É chave de Info.plist, não exige entitlement |
| Rede local e Bonjour | Sim | Idem |
| Microfone, câmera | Sim | Idem |
| Rede ponto a ponto (Multipeer / Network.framework) | Sim | Não exige entitlement |
| Notificações push, VoIP push | Não | Exigem conta paga |
| Multicast cru, Wi-Fi Aware | Não | Entitlements restritos |

O teste T0 confirma isso no aparelho antes de qualquer outra coisa.

### Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| Sideloadly não enxerga o iPhone | iTunes da Microsoft Store, ou cabo só de carga | Reinstalar o iTunes pelo site da Apple; trocar o cabo; desbloquear o iPhone e tocar em Confiar |
| "Unable to Verify App" ao abrir | iPhone sem internet na primeira abertura | Conectar ao Wi-Fi e abrir de novo; a verificação é só uma vez |
| "Desenvolvedor não confiável" | Passo 5.1 pulado | Ajustes > Geral > VPN e Gerenciamento de Dispositivos |
| App abre e fecha na hora | Modo de Desenvolvedor desligado ou app expirado | Passo 5.2; reinstalar |
| Não acho o Modo de Desenvolvedor | Nenhum app instalado por sideload ainda | Instalar primeiro, depois procurar |
| "Maximum number of apps" | Já há 3 apps de sideload | Apagar um deles do iPhone |
| "Maximum App IDs" | 10 identificadores usados em 7 dias | Esperar, ou usar outro Apple ID |
| Erro de login no Sideloadly/AltServer | Autenticação de dois fatores | Conferir o código; se persistir, gerar senha de app em account.apple.com |
| AltStore não renova | AltServer fechado, redes diferentes ou sincronização Wi-Fi desmarcada | Conferir o passo 6 acima; renovar pelo cabo |
| Workflow falha em "pod install" | Dependência nativa nova | Abrir o log do passo; normalmente é versão mínima de iOS no Podfile |
| Nenhuma pergunta de "Rede Local" apareceu | O iOS só pergunta quando o app usa a rede | Abrir a tela Entrar; se negou antes: Ajustes > Privacidade e Segurança > Rede Local |

---

## Fase 2 — Paga (uso real)

Quando o app estiver validado na estrada: Apple Developer Program, 99 USD por ano. Ganhos: builds valem **90 dias**, instalação pelo app **TestFlight** direto no iPhone, sem PC e sem cabo, e até 100 testadores internos.

### Preparação (uma vez)

1. Inscreva-se em developer.apple.com/programs (aprovação leva de horas a dias).
2. Em appstoreconnect.apple.com > **Apps** > **+** > Novo App. Defina o **Bundle ID** (por exemplo `br.com.seunome.comboio`) e anote.
3. Em **Usuários e Acesso** > **Integrações** > **App Store Connect API** > gerar chave com função **Admin**. Baixe o arquivo `.p8` (só dá para baixar uma vez) e anote o **Key ID** e o **Issuer ID**.
4. Seu **Team ID** está em developer.apple.com > Account > Membership details.
5. Troque o identificador do projeto para esse Bundle ID (ver "Identificador do app" no fim deste guia).

### Segredos no GitHub

Repositório > **Settings** > **Secrets and variables** > **Actions** > **New repository secret**.

| Segredo | Conteúdo |
|---|---|
| `ASC_KEY_ID` | Key ID da chave da API |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_KEY_P8_BASE64` | Arquivo `.p8` em base64 |
| `APPLE_TEAM_ID` | Team ID (10 caracteres) |

Gerar o base64 no PowerShell:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXXXXXXXX.p8")) | Set-Clipboard
```

### Publicar

Actions > **iOS (TestFlight)** > Run workflow. O build aparece no TestFlight em 10 a 30 minutos. No iPhone: instale o app TestFlight, aceite o convite que chega por e-mail e toque em Instalar.

O workflow `ios-testflight.yml` usa assinatura automática gerenciada pela Apple. **Ele ainda não foi executado**, porque depende da conta paga; conte com um ou dois ajustes na primeira execução. Alternativa sem manutenção de YAML: Codemagic (500 minutos gratuitos de macOS por mês), que tem assistente para a mesma chave de API.

---

## Android

### Chave de assinatura

O Android só aceita atualizar um app se a nova versão tiver a mesma assinatura. A chave deste projeto já foi criada neste PC:

- `android/app/comboio-release.jks` (a chave)
- `android/key.properties` (a senha e o alias)

Os dois ficam fora do git. **Copie os dois para um lugar seguro** (pendrive, gerenciador de senhas). Perder a chave significa desinstalar e instalar de novo em todos os aparelhos.

### Gerar o APK neste PC

```powershell
C:\src\flutter\bin\flutter build apk --release
```

O arquivo sai em `build\app\outputs\flutter-apk\app-release.apk`.

### Gerar o APK no GitHub (opcional)

Para o workflow assinar com a mesma chave, cadastre os segredos (os valores estão em `android/key.properties`):

| Segredo | Conteúdo |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | O `.jks` em base64 |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` |
| `ANDROID_KEY_ALIAS` | `comboio` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` |

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\app\comboio-release.jks")) | Set-Clipboard
```

Sem esses segredos o workflow ainda gera um APK, assinado com chave de depuração: instala num aparelho limpo, mas não atualiza por cima do APK gerado neste PC.

Actions > **Android (APK)** > Run workflow. Baixe o artifact `comboio-android`.

### Instalar

1. Tenha o `.apk` em mãos (gerado neste PC ou baixado do GitHub).
2. Mande o `.apk` para o celular (cabo, Drive, WhatsApp).
3. Toque no arquivo. O Android pede para permitir instalação daquela origem: **Configurações** > ative **Permitir desta fonte** > voltar > **Instalar**.
4. Se o Play Protect avisar que não conhece o app: **Instalar mesmo assim**.

O APK não expira.

---

## Ferramentas instaladas neste PC

| Ferramenta | Onde | Observação |
|---|---|---|
| Flutter 3.50 | `C:\src\flutter` | Não foi adicionado ao PATH. Use o caminho completo, ou adicione `C:\src\flutter\bin` ao PATH. |
| Android SDK (plataformas 35 e 36) | `%LOCALAPPDATA%\Android\Sdk` | Instalado pela linha de comando, sem Android Studio. |

As pastas `android/` e `ios/` estão versionadas. O Flutter gera a pasta `ios/` no Windows, mas só um Mac (o do GitHub Actions) consegue compilá-la.

## Identificador do app

O identificador atual é `com.leightonisrael.comboio` (Android `applicationId` e iOS bundle id). Serve para sideload. Antes de publicar em loja ou no TestFlight, troque por um domínio seu em `android/app/build.gradle.kts` e em `ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`).

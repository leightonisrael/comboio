# Comboio

Intercomunicador por voz para motociclistas. Funciona sem internet e sem sinal de celular: cada piloto usa o próprio celular com o próprio capacete Bluetooth, e os celulares conversam por Wi-Fi local.

Serve para **qualquer headset Bluetooth de capacete**, de qualquer marca, inclusive os genéricos que não têm função de intercom entre unidades. O app só precisa que o headset funcione para ligações telefônicas (perfil HFP).

```
Capacete A ──Bluetooth── Celular A ══ Wi-Fi local (hotspot) ══ Celular B ──Bluetooth── Capacete B
```

## Como usar (2 pilotos)

1. Cada um pareia o capacete com o próprio celular em Ajustes > Bluetooth.
2. **Piloto A** liga o hotspot (roteador Wi-Fi) do celular, abre o Comboio e toca em **Criar sala**. A tela mostra um PIN.
3. **Piloto B** conecta no Wi-Fi do piloto A, abre o Comboio e toca na sala que aparece. Na primeira vez digita o PIN; nas seguintes entra com um toque.
4. Guardem os celulares. A conversa continua com a tela bloqueada e reconecta sozinha quando as motos se afastam e voltam.

## Estado atual

| Parte | Situação |
|---|---|
| App Android (APK) | Compila e gera APK assinado. **Ainda não testado em aparelho.** |
| App iOS | Mesmo código. **Nunca compilado**: depende do workflow do GitHub Actions (não há Mac). |
| Sinalização, PIN, retransmissão entre pilotos | Coberta por testes automáticos (`flutter test`). |
| Áudio, Bluetooth, alcance, bateria | Só dá para validar na rua. Roteiro em `docs/04-testes-e-roadmap.md`. |

## Documentação

| Arquivo | Conteúdo |
|---|---|
| [docs/01-arquitetura.md](docs/01-arquitetura.md) | Decisões técnicas, pipeline de áudio, protocolo, segurança, configurações nativas |
| [docs/02-design.md](docs/02-design.md) | Design system, telas, feedback por voz e vibração |
| [docs/03-build-e-instalacao.md](docs/03-build-e-instalacao.md) | Como gerar e instalar no iPhone sem Mac e no Android |
| [docs/04-testes-e-roadmap.md](docs/04-testes-e-roadmap.md) | Testes de campo e roadmap |
| [docs/05-lojas.md](docs/05-lojas.md) | Textos e respostas para Google Play e App Store |
| [docs/privacidade.md](docs/privacidade.md) | Política de privacidade |

## Desenvolvimento

```
flutter pub get
flutter test
flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
```

A chave de assinatura do Android fica em `android/app/comboio-release.jks` e `android/key.properties`. Os dois arquivos estão fora do git de propósito. **Faça backup deles**: sem a mesma chave, o Android recusa atualizar o app por cima da versão instalada.

## O que o MVP ainda não tem

Em relação ao desenho completo em `docs/`: pareamento por QR e chaves por aparelho (hoje é PIN), descoberta por Bonjour (hoje é varredura da sub-rede), distância por GPS, modo painel, frases gravadas (hoje é a voz sintetizada do sistema) e o hotspot automático no Android.

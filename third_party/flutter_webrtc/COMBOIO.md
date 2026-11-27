# Copia local do flutter_webrtc 1.7.0

Unica mudanca em relacao ao pacote publicado, em
`android/src/main/java/com/cloudwebrtc/webrtc/MethodCallHandlerImpl.java`:

- `options.disableNetworkMonitor = true`
- o tipo de adaptador "desconhecido" deixa de ser ignorado

Motivo: no celular que faz o roteador Wi-Fi (hotspot), a interface do roteador
nao e uma rede do ConnectivityManager e tem nome fora do padrao. O WebRTC a
descartava, nao gerava candidato ICE na sub-rede do hotspot e a conversa ficava
em "conectando" quando nao havia outro Wi-Fi em comum.

Sem o monitor de rede o WebRTC nao amarra mais os sockets a rede Wi-Fi; quem
faz isso e o app (`bindWifi` em MainActivity.kt).

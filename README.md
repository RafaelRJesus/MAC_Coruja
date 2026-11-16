# 🦉 Coruja

Uma coruja de mesa que mantém o computador acordado.

- **Olhos abertos**: a tela não descansa e o sistema não fica ocioso.
- **Olhos fechados**: o computador volta ao comportamento normal (descansa e hiberna).

## Como usar

| Ação | O que acontece |
|---|---|
| Clicar nos **olhos** | Acorda / põe a coruja para dormir |
| Clicar na **orelha direita** | Abre as configurações |
| Arrastar a coruja | Move pela tela |
| Botão direito | Menu (acordar/dormir, configurações, sempre na frente, sair) |

### Configurações (orelha direita)

São opcionais. Você escolhe uma delas:

- **Sem limite**: fica acordada até você fechar os olhos dela.
- **Temporizador**: faz uma contagem regressiva (horas + minutos) e depois dorme sozinha.
- **Horário**: dorme num horário fixo. Se o horário de hoje já passou, vale para amanhã.

A escolha fica salva. Toda vez que você abrir os olhos da coruja, ela usa o limite configurado.
Passe o mouse sobre a coruja para ver quanto tempo falta.

## Instalação

### macOS

Precisa das Ferramentas de Linha de Comando da Apple (o script oferece a instalação se faltar).

```bash
bash macos/instalar.sh
```

O script compila, gera o ícone e instala a Coruja em Aplicativos.
Na primeira vez que a coruja acordar, o macOS pede permissão de **Acessibilidade**.

### Windows e Linux

Em breve.

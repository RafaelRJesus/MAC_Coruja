# 🦉 Coruja

Um amiguinho de mesa que mantém o computador acordado.

- **Olhos abertos**: a tela não descansa e o sistema não fica ocioso.
- **Olhos fechados**: o computador volta ao comportamento normal (descansa e hiberna).

Ela é pequena, fica num cantinho da tela e tem vida própria: respira, pisca, olha para o
mouse, passeia, toma café, almoça e dorme no ninho.

## Como usar

| Ação | O que acontece |
|---|---|
| Clicar nos **olhos** | Acorda / põe a coruja para dormir |
| Clicar na **orelha direita** (a do brinco) | Quando dormir: temporizador ou horário |
| Clicar na **orelha esquerda** | Animações: liga/desliga, opções e tamanho |
| Clicar na **barriga** | Carinho (olhinhos ^^ e corações) |
| Arrastar a coruja | Move pela tela (ela bate as asas) |
| Botão direito | Menu com tudo isso e "Sair" |

### Quando dormir (orelha direita)

Opcional. Escolha uma:

- **Sem limite**: fica acordada até você fechar os olhos dela.
- **Temporizador**: contagem regressiva (horas + minutos) e depois dorme sozinha.
- **Horário**: dorme num horário fixo. Se já passou hoje, vale para amanhã.

A pedra do brinco mostra a opção ativa: **laranja** = sem limite, **azul** = temporizador,
**verde** = horário. Passe o mouse sobre a coruja para ver quanto tempo falta.

### Animações (orelha esquerda)

**Sempre que acontece algo:**
- Acordar: o sol nasce atrás dela e ela se espreguiça.
- Dormir: o sol se põe, os olhos vão fechando e ela se aninha no ninho (com Zzz).
- Ser arrastada: bate as asas.
- Carinho na barriga: olhinhos felizes e corações.

**Aleatórias** (sorteadas, em intervalos variados, sem repetir a anterior):
olhar em volta, piar com notinhas, bater asas, pulinho, descansar no ninho,
bocejar (mais comum à noite) e passear pela tela.

**Chamar atenção** (opcional): de vez em quando faz carinha de filhote, com olhos grandes,
brilhantes e corações.

**Por horário** (opcional, uma vez por dia, num momento sorteado dentro da janela):

| Janela | Animação |
|---|---|
| 08:30 – 10:00 | Cafezinho (caneca com vapor) |
| 12:00 – 13:30 | Almoço (tigela de sementes) |
| 15:30 – 16:30 | Lanche (biscoito) |
| Sexta, 17:00 – 18:00 | Sextou! (chapéu de festa e confete) |
| 18:30 | Anoitecer: o sol baixa e os olhos ficam um pouco mais baixos |
| 06:00 | Amanhecer: o sol nasce e ela se espreguiça |

Também dá para ver qualquer animação na hora pelo menu "Ver uma animação agora…".

### Leve

- Parada, a coruja usa de 8 a 12 quadros por segundo; 30 só durante uma animação.
- Quando está escondida (atrás de janelas, em outra mesa ou com a tela apagada), pausa tudo.
- Com as animações desligadas, fica parada e não usa processamento.
- Tamanhos: pequena (padrão), média e grande.

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

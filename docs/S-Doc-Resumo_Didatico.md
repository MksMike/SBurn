# O que descobrimos — em linguagem de gente

*(Resumo da sessao de 12-14/08/2026. Para ler sem saber programacao.)*

---

## O que a gente estava tentando fazer

Descobrir se dois indicadores de graficos — apelidados aqui de **TMO** e **ScalpPullback** — conseguem dizer, com antecedencia, se vale a pena comprar ou vender ouro. Nada de "achismo" ou de olhar o grafico e sentir. A regra da casa: so vale o que da para **contar**.

O metodo foi sempre o mesmo. Pegamos cada aviso que o indicador deu nos ultimos 8 meses — foram cerca de **21 mil avisos** — e fizemos a mesma pergunta a todos: *depois que voce apareceu, o preco andou mais a favor ou mais contra?* Sem opiniao. So contagem.

---

## Primeiro: consertar as ferramentas

Antes de medir qualquer coisa, achamos defeitos serios nos dois indicadores. O pior deles: no historico, eles "espiavam o futuro" sem querer — mostravam no passado informacoes que so existiriam minutos depois. Isso faz qualquer teste parecer maravilhoso e depois fracassar no dinheiro real. Corrigido.

Tambem passamos uma madrugada inteira caçando um erro fantasma. A causa era um detalhe tecnico invisivel: linhas de "organizacao visual" dentro do indicador estavam bagunçando a ordem dos ajustes quando outro programa o consultava — como um formulario em que todas as respostas entram no campo errado. Depois disso, criamos a regra de que **todo programa se apresenta no relatorio ao ligar**, dizendo qual versao e com quais ajustes. Nunca mais adivinhamos qual codigo esta rodando.

---

## O veredito sobre o TMO: bom termometro, volante ruim

O TMO e como um cata-vento: mostra que o vento mudou **agora**. Testamos se ele prevê para onde o vento vai — em cinco velocidades de grafico diferentes, do mais rapido ao mais lento. **Nao prevê em nenhuma.** Depois do aviso, o preco anda praticamente a mesma distancia para os dois lados. E cara-ou-coroa. E cara-ou-coroa pagando pedagio (o custo de cada operacao) da prejuizo garantido.

Colocamos numero nisso: seguir o TMO cegamente durante 8 meses teria pago **1,6 milhao de pontos so de pedagio** e terminado bem no negativo. Uma maquina de pagar taxa.

**Mas o mesmo teste revelou o oposto:** o TMO e otimo medindo o *estado* do mercado. Ele identifica quando o preco esta "esticado demais" para cima ou para baixo — e descobrimos que tentar operar **contra** esse exagero (comprar o que despencou, vender o que disparou) e o pior negocio do livro. Isso apareceu em **todas as cinco velocidades**, mês apos mês. Segurar faca caindo, parar foguete com a mao.

Entao o TMO foi promovido e rebaixado ao mesmo tempo: **demitido como volante, contratado como termometro**. A regra "nao opere contra exagero" e o primeiro achado solido do projeto — e sobreviveu inclusive a 4 meses de dados que nenhuma teoria nossa tinha visto antes.

---

## O paradoxo do grafico: "mas eu vejo o preco andando!"

Em certo momento o Mike olhou um grafico real e questionou: *"da para ver claramente o preco andando entre um aviso e outro — nao acredito que so de prejuizo."*

Os dois estavam certos, e a explicacao e bonita:

- **10% das operacoes** rendem enormes lucros (somadas: +15 milhoes de pontos)
- **os outros 90%** somados dao −16 milhoes

Quando alguem olha um grafico, o olho **encontra naturalmente os trechos bonitos** — que sao exatamente esses 10%. Os outros 90%, pequenos e chatos, passam despercebidos. O grafico nao mente; ele mostra a excecao. A planilha conta tudo.

E tem um detalhe crucial: as operacoes **curtas** (ate 30 min) sao as que sangram; as **longas** sao as que pagam. Mas na hora de entrar, ninguem sabe qual das duas caiu na sua mao.

---

## O que tentamos e nao funcionou (e por que isso vale ouro)

Testamos varias ideias razoaveis. **Quase todas morreram** — e cada morte economizou meses de dinheiro real:

- **"Espere 25 minutos; se nao andou, saia."** A informacao existe (operacoes que nao andam em 25 min terminam mal em 97% dos casos), mas quando voce sai, o prejuizo **ja foi pago**. Sair ali nao devolve nada e ainda corta recuperacoes.
- **"So continue se a primeira barra confirmar."** Aqui quase caimos numa armadilha: o calculo rapido dava um resultado espetacular. Ao refazer com honestidade, percebemos que ele **ignorava o custo de esperar a confirmacao**. Feito direito: negativo.
- **"Whipsaws vem em sequencia — pause depois de duas perdas."** Nao vem. As perdas nao se atraem; e moeda.
- **"Troque o TMO por outro indicador (MACD e parentes)."** Sao todos primos que medem a mesma coisa com roupa diferente. Se o conceito nao funciona, mudar de marca nao salva.
- **"Coloque um alvo de lucro fixo."** Piora tudo — porque o lucro vive nas operacoes gigantes e raras, e um teto corta justamente elas.

---

## E entao apareceu a boa noticia

A ultima ideia testada foi diferente. Em vez de apostar em **reversao** (tentar pegar o momento em que o mercado vira), ela aposta em **continuacao**: esperar uma tendencia ja estabelecida, esperar o preco dar uma "respirada" para tras, e entrar quando ele retoma o caminho. E o ScalpPullback fazendo o que foi desenhado para fazer — **com uma condicao extra**: um grafico mais lento (de 30 minutos) precisa concordar com a direcao.

Resultado:

- Positivo **nos quatro primeiros meses** e **nos quatro ultimos**, testados separadamente (o teste mais rigoroso que aplicamos)
- Positivo em **5 dos 8 meses**
- Funciona tambem quando trocamos a velocidade do grafico — coisa que nenhum outro achado conseguiu
- E o numero final: **+1.637 pontos de lucro medio por operacao**, ja descontado o custo — cerca de 6 vezes o pedagio, com aproximadamente 1,6 operacoes por dia

**E o primeiro resultado positivo de todo o projeto.**

---

## O que isso significa (e o que ainda nao significa)

Significa que temos, pela primeira vez, uma estrategia completa — entrada, saida e custo — com sinal positivo em dados que ela nunca tinha visto.

**Nao significa que esta pronta.** Sao 337 operacoes ao longo de 8 meses: meses, nao anos. Parte dos dados antigos pode ter qualidade inferior. E, o mais importante para quem vai operar: essa estrategia **vive de poucas operacoes muito grandes**. Na pratica isso quer dizer longas sequencias de resultados medianos entre os grandes acertos — exige estomago e regra de risco, nao entusiasmo.

O proximo passo ja esta definido: baixar anos de dados de melhor qualidade e submeter essa estrategia a um teste muito mais longo. Se passar, ai sim vira um robo.

---

## A moral da historia

Oito meses de dados, 21 mil avisos, e a maior parte do trabalho foi **descobrir onde o lucro nao esta**. Cada "nao" documentado — com numero, nao com opiniao — foi o que permitiu chegar a um "talvez" que aguenta ser questionado.

E mais lento que a maioria faz. E exatamente por isso que, quando esse robo for ligado, vai se saber **por que** ele liga.

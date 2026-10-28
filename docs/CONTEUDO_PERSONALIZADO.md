# Conteúdo personalizado

**[English → CUSTOM_CONTENT.md](CUSTOM_CONTENT.md)**

Com a expansão, a tela **Personalizar** transforma decks, conjuntos de filósofos, escritores e governantes e predefinições de regras em arquivos CSV. Dá para editá-los no editor de tabela do próprio jogo ou em qualquer planilha (LibreOffice, Excel, Google Planilhas), duplicar, exportar e importar.

- O que vem com o jogo (deck Pentakosmos, deck Arcaico, filósofos, escritores e governantes clássicos) fica travado. **Duplique** para fazer a sua versão.
- Os seus arquivos ficam na pasta de dados do jogo, em `conteudo/<tipo>/<nome>.csv` (`decks`, `philosophers`, `writers`, `governors`, `presets`). O nome do arquivo é o nome do conteúdo; renomear no jogo também atualiza as predefinições que o usam.
- As colunas podem ser separadas por `,` ou `;` (planilhas em português costumam salvar com `;`). Os nomes das colunas estão em inglês, mas os nomes em português (`grupo`, `pontos`, `bônus`, `efeito`, `nome`, `ar`, `água`, `éter`, `fogo`, `terra`, `esfera`…) também são aceitos.
- Um arquivo com erros não é usado: o jogo lista as linhas que precisam de correção.
- **Exportar** uma predefinição salva um `.zip` com ela e com todos os decks e conjuntos que ela usa, para um amigo receber tudo de uma vez.

## Decks

```
grupo;pontos;bônus;ar;água;éter;fogo;terra;esfera;efeito
1;0;ar;0;1;1;1;1;0;
2;2;água;0;0;5;0;0;0;
3;4;fogo + terra;0;7;0;0;0;0;ficha
1;-1;coringa;2;0;0;0;0;1;turno_extra
```

| Coluna | Significado |
|---|---|
| `group` / `grupo` | 1, 2 ou 3 (ou `básica`, `intermediária`, `avançada`). Cada grupo precisa de 5 a 100 cartas. |
| `points` / `pontos` | −10 a 10. Pontos negativos são permitidos. |
| `bonus` / `bônus` | O desconto permanente que a carta dá. Um elemento (`ar`, `água`, `éter`, `fogo`, `terra`); vários unidos por `+` (`ar + 2 fogo`, até 5 no total); `nenhum`; ou `coringa` (ao comprar, você escolhe o elemento de uma das suas cartas). |
| `ar` … `terra` | Custo em fichas de cada elemento, 0 a 12. |
| `sphere` / `esfera` | Custo que só se paga com esferas, 0 a 12. Opcional. |
| `effect` / `efeito` | O que acontece ao comprar a carta. Opcional: vazio, `ficha` (pegar 1 ficha), `duas_fichas` (pegar 2), `esfera` (pegar 1 esfera) ou `turno_extra` (jogar mais uma vez). Em inglês: `token`, `two_tokens`, `sphere`, `extra_turn`. |

## Filósofos e escritores

```
nome;ar;água;éter;fogo;terra;pontos
Homero;0;3;0;3;0;1
```

`nome` e depois quantas cartas de cada elemento o requisito pede (0 a 20). Escritores têm também `pontos` (−10 a 10; 1 se vazio). Um conjunto de filósofos precisa de pelo menos 6; um de escritores, de pelo menos 2.

## Governantes

```
name,group,condition,condition_value,cost,cost_value,advantage,advantage_value,target_change,title
Pericles,composition,advanced,2,none,0,none,0,-4,The Golden Age
```

| Coluna | Significado |
|---|---|
| `group` | Onde aparece na lista: `composition` (pelas cartas), `tokens` (pelas fichas), `reserves` (pelas reservas), `position` (pela posição) ou `price` (com um preço). |
| `condition` + `condition_value` | O que o jogador precisa fazer para recebê-lo (`n` = o valor). |
| `cost` + `cost_value` | O que o jogador paga ao recebê-lo. Opcional (`none`). |
| `advantage` + `advantage_value` | O que o jogador ganha. Opcional (`none`). |
| `target_change` | Quanto o governante muda a meta de quem o tem, em relação à meta base (−50 a 50). |
| `title` | Um subtítulo curto. |

Um conjunto de governantes precisa de pelo menos 3. Os códigos abaixo ficam em inglês.

**Condições:** `advanced` (n cartas avançadas) · `equal` (cartas dos cinco elementos em números exatamente iguais) · `same_element` (n cartas de um elemento) · `no_tokens` (terminar a vez sem fichas) · `full_hand` (mão cheia de fichas) · `spheres` (n esferas na mão) · `no_reserve_cards` (n cartas compradas sem nunca reservar) · `reserves` (n cartas reservadas) · `blind_bought` (comprar uma carta reservada às cegas) · `last_place` (último lugar com pelo menos n cartas) · `behind_leader` (cartas de n ou mais elementos e menos pontos que o líder) · `streak` (comprar carta em n vezes seguidas) · `near_leader_last` (a até n pontos do líder quando começa a última rodada) · `points` (n pontos) · `philosopher_no_advanced` (um filósofo e nenhuma carta avançada) · `writers` (n escritores).

**Custos:** `none` · `lose_points` (perder n pontos) · `return_tokens` (devolver n fichas) · `return_spheres` (devolver n esferas) · `no_reserve` (nunca mais reservar) · `return_philosopher` (o seu último filósofo volta à mesa).

**Vantagens:** `none` · `gain_points` (+n pontos agora) · `gain_tokens` (pegar n fichas de elementos diferentes) · `specialization` (n pontos num elemento já vencem por especialização) · `advanced_bonus` (cada carta avançada vale +n) · `see_hidden` (ver as reservas ocultas e o topo de cada pilha) · `blind_choice` (ao reservar às cegas, ver as n cartas do topo e escolher uma) · `wins_ties` (vence os empates) · `extra_turn` (uma vez) · `extra_round` (se você não vencer, a partida ganha mais uma rodada, uma vez) · `confiscate` (as fichas que os adversários devolvem por passar do limite vêm para você) · `writer_points` (cada escritor vale n pontos).

## Predefinições de regras

Duas colunas, `key` (ou `chave`) e `value` (ou `valor`), uma regra por linha. O jeito mais fácil de fazer uma é ajustar as regras no jogo e apertar **Salvar**. As chaves que apontam para conteúdo (`deck`, `phil_set`, `writer_set`, `gov_set`) guardam `caio` / `arcaico` / `classico` para os que vêm com o jogo, ou `user:<nome>` para os seus.

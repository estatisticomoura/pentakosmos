# How Pentakosmos was born

It all started at the table, with a card game I loved and a handful of rules I kept changing with friends. How many tokens should there be with three players? What if the philosophers asked a little less, but rewarded the first one more than the last? What if a five-player game had a bigger market? Those questions were fun, but I wanted answers that were more than hunches.

## Rules, put to the test
So I sat down with Claude, an AI assistant, and we turned each idea into an experiment. We wrote a simulator and let my own computer play tens of thousands of games, comparing every variant against the traditional rules, for two, three, four and five players: how long games lasted, how often players had to throw tokens away, how much the first player was favoured. When something surprised us, we dug deeper — and when a result contradicted my intuition, the numbers had the last word. Many of the rules you see in the Pentakosmos mode survived that process: the token counts by number of players, taking two of a kind from a pile of three, the larger market for five, the flexible philosophers worth 3, 2 and 1 points.

## A deck made of formulas
Then came the part I am proudest of, and which I designed on my own: the deck. Instead of drawing 90 cards one by one, I wrote 18 formulas. Each formula describes a card relative to its own element — level, points and how much it costs in the elements that come before and after it in a fixed cycle (air, water, aether, fire, earth). Applied to the five elements, each formula yields five cards that are perfect mirrors of one another. The deck is balanced by construction: no element is stronger than another, and every card has a reason to exist. The simulations then showed how it behaved against the traditional deck, and helped me fine-tune it.

## From spreadsheets to a real game
Once the rules were solid, I wanted anyone to be able to play them — on Linux, Windows and Android, for free. Claude and I built the game in Godot, with every rule available as an option in the menu. I wanted opponents worthy of the name, so we created several kinds of artificial intelligence and let them evolve: a genetic algorithm tuned their strategy over hundreds of thousands of games on my computer, and a tournament decided which one deserved each place. Along the way a new idea appeared — the specialization victory, for whoever masters a single element — and the opponents learned to pursue it and to stop it.

## The five solids
Finally the game found its own soul. In the Timaeus, Plato associates the elements with the five regular solids: fire with the tetrahedron, air with the octahedron, water with the icosahedron, earth with the cube, and the dodecahedron with the cosmos itself. The tokens became slowly turning solids, the joker became a golden sphere, the visitors of each academy became the philosophers who first wondered what the world is made of, and the computer opponents borrowed their names from the people who talk in Plato's dialogues. The name followed naturally: **Pentakosmos**, the cosmos of the five.

## Free, for everyone
I made this game for the joy of making it: of testing an idea, watching the numbers confirm it (or not), and seeing a detail fall into place. That joy is meant to be shared. Pentakosmos is free and open source under the MIT license: you can play it, study it, translate it, change it, build your own version and even sell it — I only ask that you mention where it started.

If you have an idea, find a bug, want to improve a translation or just want to tell me about a game you played, I would love to hear from you:
- Conversations and suggestions: [github.com/estatisticomoura/pentakosmos/discussions](https://github.com/estatisticomoura/pentakosmos/discussions)
- Bugs: [github.com/estatisticomoura/pentakosmos/issues](https://github.com/estatisticomoura/pentakosmos/issues)

Have a good game!
— Caio Moura Quina


---

## Appendix: the formulas of the Pentakosmos deck

Each element card has a level, points and a cost. In the Pentakosmos deck, the cost is written relative to the card's own element, using the cycle **air → water → aether → fire → earth → air**: "−2" is the element two steps before the card's element in the cycle, "own" is the card's element, "+1" the next one, and so on. Each of the 18 formulas is applied to the five elements, giving 90 cards.

| # | Level | Points | −2 | −1 | own | +1 | +2 | Total cost |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 0 | 1 | 1 | · | 1 | 1 | 4 |
| 2 | 1 | 0 | 1 | 2 | 1 | · | · | 4 |
| 3 | 1 | 0 | · | · | 1 | 2 | 1 | 4 |
| 4 | 1 | 0 | · | 2 | · | 2 | · | 4 |
| 5 | 1 | 0 | · | 2 | 1 | · | · | 3 |
| 6 | 1 | 0 | 2 | · | · | · | 2 | 4 |
| 7 | 1 | 0 | · | · | · | 3 | · | 3 |
| 8 | 1 | 1 | · | · | 4 | · | · | 4 |
| 9 | 2 | 1 | · | 3 | · | 2 | · | 5 |
| 10 | 2 | 1 | 3 | · | · | · | 3 | 6 |
| 11 | 2 | 2 | · | · | 5 | · | · | 5 |
| 12 | 2 | 2 | · | · | 3 | 4 | · | 7 |
| 13 | 2 | 2 | · | 4 | 1 | 2 | · | 7 |
| 14 | 2 | 3 | · | · | 6 | · | · | 6 |
| 15 | 3 | 3 | · | 5 | 2 | 2 | · | 9 |
| 16 | 3 | 4 | · | · | 5 | 5 | · | 10 |
| 17 | 3 | 4 | 3 | 6 | · | · | · | 9 |
| 18 | 3 | 5 | · | · | · | 7 | 3 | 10 |

Example: formula 9 for a **fire** card (level 2, 1 point) costs 3 aether (−1) and 2 earth (+1).

The formulas live in `scripts/core/defs.gd` (`FORMULAS_CAIO` and `OFFSETS`), so anyone can design a variant by editing a single table.

## Appendix: some numbers

- The game engine was checked against the original Python simulator: with 2,000 games per configuration, average length and number of philosophers matched within the margin of error (for example, 22.32 versus 22.26 rounds in three-player Pentakosmos games).
- **Specialization victory.** With the threshold at 10 points in one element, between 9% and 12% of games between computer opponents end by specialization, and the rule changes the winner in about 3% of all games: it adds a second path to victory without taking over the game.
- **Genetic algorithm.** Measured as wins above the expected share against the strategist (Crito): the general champion reached +5.75 percentage points; the champion trained only with the Pentakosmos rules (including specialization) reached +8.2, that is, 4.8 points more than the general one on the same games; the champion of the Legacy rules reached +6.5.
- **Tournament** (Pentakosmos rules, thousands of games): mixed +10.8, tactical +4.7, evolved −10.6 percentage points above the expected share in direct matches. Against strategists, the mixed opponent wins 30.8 points above its expected share.

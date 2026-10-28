# Custom content

**[Português → CONTEUDO_PERSONALIZADO.md](CONTEUDO_PERSONALIZADO.md)**

With the expansion, the **Customize** screen turns decks, sets of philosophers, writers and governors, and rule presets into CSV files. You can edit them in the game's table editor or in any spreadsheet program (LibreOffice, Excel, Google Sheets), duplicate them, export them and import them.

- The content that ships with the game (Pentakosmos deck, Archaic deck, classic philosophers, writers and governors) is locked. **Duplicate** it to make your own version.
- Your files live in the game's data folder, under `conteudo/<kind>/<name>.csv` (`decks`, `philosophers`, `writers`, `governors`, `presets`). The file name is the content's name; renaming in the game also updates the presets that use it.
- Columns may be separated by `,` or `;` (spreadsheets in many languages save with `;`). Column names are in English, but the Portuguese names (`grupo`, `pontos`, `bônus`, `efeito`, `nome`, `ar`, `água`, `éter`, `fogo`, `terra`, `esfera`…) are accepted too.
- A file with errors is not used: the game lists the lines that need fixing.
- **Export** on a preset saves a `.zip` with the preset and every deck and set it uses, so a friend gets everything at once.

## Decks

```
group,points,bonus,air,water,aether,fire,earth,sphere,effect
1,0,air,0,1,1,1,1,0,
2,2,water,0,0,5,0,0,0,
3,4,fire + earth,0,7,0,0,0,0,token
1,-1,joker,2,0,0,0,0,1,extra_turn
```

| Column | Meaning |
|---|---|
| `group` | 1, 2 or 3 (or `basic`, `intermediate`, `advanced`). Each group needs 5 to 100 cards. |
| `points` | −10 to 10. Negative points are allowed. |
| `bonus` | The permanent discount the card gives. One element (`air`, `water`, `aether`, `fire`, `earth`); several joined with `+` (`air + 2 fire`, up to 5 in total); `none`; or `joker` (when bought, you choose the element of one of your cards). |
| `air` … `earth` | Cost in tokens of each element, 0 to 12. |
| `sphere` | Cost that can only be paid with spheres, 0 to 12. Optional. |
| `effect` | What happens when the card is bought. Optional: empty, `token` (take 1 token), `two_tokens` (take 2), `sphere` (take 1 sphere) or `extra_turn` (play once more). |

## Philosophers and writers

```
name,air,water,aether,fire,earth,points
Homer,0,3,0,3,0,1
```

`name`, then the number of cards of each element the requirement asks for (0 to 20). Writers also have `points` (−10 to 10; 1 if empty). A philosopher set needs at least 6 philosophers; a writer set, at least 2.

## Governors

```
name,group,condition,condition_value,cost,cost_value,advantage,advantage_value,target_change,title
Pericles,composition,advanced,2,none,0,none,0,-4,The Golden Age
```

| Column | Meaning |
|---|---|
| `group` | Where it shows in the list: `composition`, `tokens`, `reserves`, `position` or `price`. |
| `condition` + `condition_value` | What a player must do to receive it (`n` = the value). |
| `cost` + `cost_value` | What the player pays on receiving it. Optional (`none`). |
| `advantage` + `advantage_value` | What the player gains. Optional (`none`). |
| `target_change` | How much the governor changes its holder's goal, relative to the base goal (−50 to 50). |
| `title` | A short subtitle. |

A governor set needs at least 3 governors.

**Conditions:** `advanced` (n advanced cards) · `equal` (cards of the five elements in exactly equal numbers) · `same_element` (n cards of one element) · `no_tokens` (end the turn with no tokens) · `full_hand` (a full hand of tokens) · `spheres` (n spheres in hand) · `no_reserve_cards` (n cards bought without ever reserving) · `reserves` (n reserved cards) · `blind_bought` (buy a card reserved face down) · `last_place` (last place with at least n cards) · `behind_leader` (cards of n or more elements and fewer points than the leader) · `streak` (buy a card n turns in a row) · `near_leader_last` (within n points of the leader when the last round begins) · `points` (n points) · `philosopher_no_advanced` (a philosopher and no advanced cards) · `writers` (n writers).

**Costs:** `none` · `lose_points` (lose n points) · `return_tokens` (return n tokens) · `return_spheres` (return n spheres) · `no_reserve` (never reserve again) · `return_philosopher` (your last philosopher returns to the table).

**Advantages:** `none` · `gain_points` (+n points now) · `gain_tokens` (take n tokens of different elements) · `specialization` (n points in one element already win by specialization) · `advanced_bonus` (each advanced card is worth +n) · `see_hidden` (see hidden reserves and the top of each pile) · `blind_choice` (when reserving face down, look at the top n cards and choose one) · `wins_ties` · `extra_turn` (once) · `extra_round` (if you do not win, the game gets one more round, once) · `confiscate` (tokens opponents return for going over the limit come to you) · `writer_points` (each writer is worth n points).

## Rule presets

Two columns, `key` and `value`, one rule per line. The easiest way to make one is to set the rules in the game and press **Save**. The keys that point to content (`deck`, `phil_set`, `writer_set`, `gov_set`) hold `caio` / `arcaico` / `classico` for the built-in ones, or `user:<name>` for yours.

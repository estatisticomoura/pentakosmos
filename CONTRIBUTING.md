# Contributing to Pentakosmos

Thank you for wanting to help! *(Português no fim da página.)*

## Ways to help

- **Play and tell us about it.** Ideas, questions, strategies and stories go to [Discussions](https://github.com/estatisticomoura/pentakosmos/discussions).
- **Report bugs** in [Issues](https://github.com/estatisticomoura/pentakosmos/issues). Please include the operating system, the rules you were playing with, the number of players and, if possible, what you did right before the problem.
- **Improve a translation** (see below) — this is the easiest way to make a big difference.
- **Code, art and sound:** open a pull request. For larger changes, start a discussion first so we can agree on the direction.

## Translations

- Each language is `data/lang/<code>.json`, a dictionary `{"English text": "translation"}`. Edit the right-hand side only.
- Keep the placeholders exactly as they are: `{name}`, `{n}`, `{pts}`, `{color}`, `{gold}` and so on. You may move them inside the sentence.
- Keep translations short enough to fit buttons and tiles; when in doubt, look at the game in your language.
- `python3 tools/idiomas.py` lists how many texts are missing in each language and checks the placeholders. `python3 tools/idiomas.py <code>` lists the missing texts of one language.
- New language: `python3 tools/idiomas.py --modelo <code>` creates the file with empty translations; then add the language to `LANGS` in `scripts/core/lang.gd`.
- The rules and the creative-process texts are in `data/texts/<page>_<code>.txt` (Godot BBCode). Translating them is very welcome: copy the `_en.txt` file to `_<code>.txt`.

## Code

- The game is made with **Godot 4.7.2** and GDScript. The game engine (`scripts/core/`) does not depend on the interface; please keep it that way.
- Before sending a pull request, run the tests:
  ```
  godot --headless --path . --script res://tests/sim_test.gd -- house 3 normal 300
  godot --headless --path . res://tests/ui_smoke.tscn -- 4 house
  ```
- User-visible texts are written in English with `L.t("...")` or `L.f("...", {...})`.

By contributing, you agree that your contribution is released under the project licenses (MIT for code, CC BY 4.0 for texts, sounds and images).

---

## Português

- **Conversas, ideias e sugestões:** [Discussions](https://github.com/estatisticomoura/pentakosmos/discussions). **Erros:** [Issues](https://github.com/estatisticomoura/pentakosmos/issues).
- **Traduções:** edite só o lado direito de `data/lang/<código>.json` e mantenha os marcadores (`{name}`, `{n}` etc.). `python3 tools/idiomas.py` mostra o que falta. Os textos longos ficam em `data/texts/`.
- **Código:** Godot 4.7.2 e GDScript; rode os testes acima antes de enviar um pull request.
- Ao contribuir, você concorda que a sua contribuição fica sob as licenças do projeto (MIT para o código; CC BY 4.0 para textos, sons e imagens).

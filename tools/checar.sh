#!/bin/sh
# Verifica erros de sintaxe/tipos em todos os scripts.
cd "$(dirname "$0")/.."
for f in $(find scripts tests -name "*.gd"); do
  out=$(timeout 60 godot --headless --path . --check-only --script "res://$f" 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error" | grep -v "depended")
  [ -n "$out" ] && echo "== $f" && echo "$out"
done
echo "verificacao concluida"

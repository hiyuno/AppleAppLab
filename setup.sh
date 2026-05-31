#!/bin/bash
# AppleAppLab — setup
# Copia los skills del equipo al proyecto actual
# Uso: curl -s https://raw.githubusercontent.com/hiyuno/AppleAppLab/main/setup.sh | bash

set -e

REPO="https://github.com/hiyuno/AppleAppLab"
SKILLS_DIR=".claude/skills"
TEMP_DIR=$(mktemp -d)

echo "🍎 AppleAppLab setup..."

# Clonar solo la carpeta .claude/skills con sparse checkout
git clone --quiet --depth=1 --filter=blob:none --sparse "$REPO" "$TEMP_DIR" 2>/dev/null
cd "$TEMP_DIR"
git sparse-checkout set .claude/skills CLAUDE.md

# Crear directorio destino si no existe
cd - > /dev/null
mkdir -p "$SKILLS_DIR"

# Copiar skills
cp -r "$TEMP_DIR/.claude/skills/"* "$SKILLS_DIR/"

# Copiar CLAUDE.md solo si no existe ya uno propio
if [ ! -f "CLAUDE.md" ]; then
  cp "$TEMP_DIR/CLAUDE.md" "CLAUDE.md"
  echo "  ✓ CLAUDE.md creado"
else
  echo "  ↩ CLAUDE.md existente no modificado"
fi

# Limpiar temp
rm -rf "$TEMP_DIR"

echo "  ✓ Skills instalados en $SKILLS_DIR"
echo ""
echo "Equipo listo:"
echo "  /steve  → Orquestador (empieza aquí)"
echo "  /scott  → PM y roadmap"
echo "  /avie   → Arquitectura"
echo "  /jonny  → Diseño UI/UX"
echo "  /woz    → SwiftUI / Swift"
echo "  /larry  → HIG Review"
echo "  /bertrand → QA y testing"
echo "  /sarah  → Accesibilidad"
echo "  /phil   → App Store"
echo ""
echo "→ Escribe /steve para empezar"

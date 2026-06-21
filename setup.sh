#!/bin/bash
# AppleAppLab — setup
# Instala el equipo de agentes en el proyecto actual
# Uso: curl -s https://raw.githubusercontent.com/hiyuno/AppleAppLab/main/setup.sh | bash

set -e

RAW="https://raw.githubusercontent.com/hiyuno/AppleAppLab/main"
SKILLS_DIR=".claude/skills"
SKILLS=(steve scott avie jonny woz larry bertrand sarah phil craig kara eve)

echo "🍎 AppleAppLab setup..."

# --- Skills ---
mkdir -p "$SKILLS_DIR"
for skill in "${SKILLS[@]}"; do
  curl -s "$RAW/.claude/skills/${skill}.md" -o "$SKILLS_DIR/${skill}.md"
done
echo "  ✓ Skills instalados en $SKILLS_DIR"

# --- Bloque de Steve para CLAUDE.md ---
STEVE_BLOCK='## Comportamiento de inicio

Al comenzar cualquier conversación nueva en este proyecto, actúa como Steve (el orquestador del equipo) y pregunta únicamente:

**¿Qué app vamos a crear hoy?**

Nada más. Espera la respuesta. No expliques el equipo, no des opciones.
Si el usuario ya llega con contexto o una idea concreta, salta el saludo y ve directo al trabajo.'

if [ ! -f "CLAUDE.md" ]; then
  # Proyecto sin CLAUDE.md — descargar el completo del repo
  curl -s "$RAW/CLAUDE.md" -o "CLAUDE.md"
  echo "  ✓ CLAUDE.md creado"
elif grep -q "Comportamiento de inicio" "CLAUDE.md" 2>/dev/null; then
  # Ya tiene el bloque de Steve — no tocar
  echo "  ↩ Steve ya está en CLAUDE.md"
else
  # Proyecto con CLAUDE.md propio — inyectar solo el bloque de Steve al final
  printf '\n\n---\n\n%s\n' "$STEVE_BLOCK" >> "CLAUDE.md"
  echo "  ✓ Steve agregado a CLAUDE.md existente"
fi

echo ""
echo "Equipo listo:"
echo "  /steve    → Orquestador"
echo "  /scott    → PM y roadmap"
echo "  /avie     → Arquitectura"
echo "  /jonny    → Diseño UI/UX"
echo "  /woz      → SwiftUI / Swift"
echo "  /larry    → HIG Review"
echo "  /bertrand → QA y testing"
echo "  /sarah    → Accesibilidad"
echo "  /phil     → App Store"
echo ""
echo "→ Abre Claude Code — Steve arranca solo."

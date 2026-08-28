#!/bin/bash
# AppleAppLab — setup
# Instala el equipo de agentes en el proyecto actual
# Uso: curl -s https://raw.githubusercontent.com/hiyuno/AppleAppLab/main/setup.sh | bash

set -e

RAW="https://raw.githubusercontent.com/hiyuno/AppleAppLab/main"
SKILLS_DIR=".claude/skills"
SKILLS=(steve scott avie ivan jonny woz larry bertrand sarah chris phil craig kara eve tim john kate kim frederick update-team)
REMOTE_VERSION=$(curl -sf "$RAW/VERSION" | tr -d '[:space:]')

echo "🍎 AppleAppLab setup (v$REMOTE_VERSION)..."

# --- Skills (Claude Code) ---
mkdir -p "$SKILLS_DIR"
for skill in "${SKILLS[@]}"; do
  curl -s "$RAW/.claude/skills/${skill}.md" -o "$SKILLS_DIR/${skill}.md"
done
echo "  ✓ Skills instalados en $SKILLS_DIR"

# --- Versión instalada ---
mkdir -p ".appleapplab"
echo "$REMOTE_VERSION" > ".appleapplab/VERSION"
echo "  ✓ Versión $REMOTE_VERSION registrada en .appleapplab/VERSION"

# --- Temas predefinidos ---
mkdir -p "Themes"
for theme in fintrol todocky todo-project test; do
  curl -sf "$RAW/Themes/${theme}.json" -o "Themes/${theme}.json" && true
done
curl -sf "$RAW/Themes/THEMES.md" -o "Themes/THEMES.md"
echo "  ✓ Temas instalados en Themes/ (Fintrol, Todocky, ToDo Project, Test)"

# --- Catálogo de patterns ---
curl -sf "$RAW/PATTERNS.md" -o "PATTERNS.md"
echo "  ✓ PATTERNS.md instalado (catálogo de componentes AppleAppLabUI)"

# --- Memoria evolutiva ---
curl -fsSL "$RAW/KNOWN_ISSUES.md" -o ".appleapplab/KNOWN_ISSUES.md"
echo "  ✓ Snapshot global actualizado en .appleapplab/KNOWN_ISSUES.md"

if [ ! -f "PROJECT_LEARNINGS.md" ]; then
  curl -fsSL "$RAW/PROJECT_LEARNINGS_TEMPLATE.md" -o "PROJECT_LEARNINGS.md"
  echo "  ✓ PROJECT_LEARNINGS.md creado"
else
  echo "  ↩ PROJECT_LEARNINGS.md preservado"
fi

# --- AGENTS.md (OpenAI Codex) ---
curl -s "$RAW/AGENTS.md" -o "AGENTS.md"
echo "  ✓ AGENTS.md instalado (OpenAI Codex)"

# --- GEMINI.md (Gemini CLI) ---
if [ ! -f "GEMINI.md" ]; then
  curl -s "$RAW/GEMINI.md" -o "GEMINI.md"
  echo "  ✓ GEMINI.md creado (Gemini CLI)"
elif grep -q "AppleAppLab" "GEMINI.md" 2>/dev/null; then
  echo "  ↩ GEMINI.md ya existe"
else
  curl -s "$RAW/GEMINI.md" >> "GEMINI.md"
  echo "  ✓ Equipo agregado a GEMINI.md existente"
fi

# --- Cursor rules ---
mkdir -p ".cursor/rules"
curl -s "$RAW/.cursor/rules/apple-team.mdc" -o ".cursor/rules/apple-team.mdc"
echo "  ✓ .cursor/rules/apple-team.mdc instalado (Cursor)"

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
echo "  /ivan     → Seguridad y release gate"
echo "  /jonny    → Diseño UI/UX"
echo "  /woz      → SwiftUI / Swift"
echo "  /larry    → HIG Review"
echo "  /bertrand → QA y testing"
echo "  /sarah    → Accesibilidad"
echo "  /chris    → Compatibilidad en dispositivos reales"
echo "  /kate     → Legal y compliance (antes de todo lanzamiento público)"
echo "  /kim      → Localización e i18n (cuando la app soporta múltiples idiomas)"
echo "  /tim      → Analytics y métricas (cuando la app lo necesita)"
echo "  /john     → Core ML y features de IA (cuando hay inteligencia real)"
echo "  /phil     → App Store"
echo "  /craig    → CI/CD"
echo "  /kara     → Monetización"
echo "  /eve      → Widgets y extensiones"
echo "  /frederick → Growth: nicho, pricing, Apple Search Ads, análisis de mercado
  /update-team → Sincronizar equipo con la última versión de AppleAppLab"
echo ""
echo "Compatibilidad:"
echo "  Claude Code → .claude/skills/ + CLAUDE.md"
echo "  Cursor      → .cursor/rules/apple-team.mdc"
echo "  Codex       → AGENTS.md"
echo "  Gemini CLI  → GEMINI.md"
echo ""
echo "→ Abre tu herramienta — Steve arranca solo."

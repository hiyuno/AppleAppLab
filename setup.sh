#!/bin/bash
# AppleAppLab — setup
# Proyecto nuevo:  curl -s https://raw.githubusercontent.com/hiyuno/AppleAppLab/main/setup.sh | bash
# Actualizar:      curl -s https://raw.githubusercontent.com/hiyuno/AppleAppLab/main/setup.sh | bash -s --update

set -e

RAW="https://raw.githubusercontent.com/hiyuno/AppleAppLab/main"

# --- Modo actualización (desde /update-team en un proyecto existente) ---
if [ "$1" = "--update" ]; then
  echo "🔄 Actualizando equipo AppleAppLab en $(pwd)..."
  echo ""
else
  # --- Modo instalación nuevo proyecto: siempre pide nombre ---
  if [ -t 0 ]; then
    # Terminal interactiva
    printf "Nombre del nuevo proyecto: "
    read -r PROJECT_NAME
  else
    # Pipe (curl | bash) — leer desde /dev/tty
    printf "Nombre del nuevo proyecto: " > /dev/tty
    read -r PROJECT_NAME < /dev/tty
  fi

  if [ -z "$PROJECT_NAME" ]; then
    echo "Error: debes ingresar un nombre para el proyecto."
    exit 1
  fi

  if [ -d "$PROJECT_NAME" ]; then
    echo "⚠️  La carpeta '$PROJECT_NAME' ya existe. Instalando dentro de ella..."
  else
    mkdir "$PROJECT_NAME"
    echo "  ✓ Carpeta '$PROJECT_NAME' creada"
  fi
  cd "$PROJECT_NAME"

  # Repo git propio para que Claude Code lo trate como proyecto independiente
  if [ ! -d ".git" ]; then
    git init -q
    echo "  ✓ Repositorio git inicializado"
  fi

  echo "  ✓ Instalando en: $(pwd)"
  echo ""
fi
SKILLS_DIR=".claude/skills"
SKILLS=(steve scott avie ivan jonny woz larry bertrand sarah chris phil craig kara eve tim john kate kim frederick update-team update-feature optimize-app architecture-audit app-store-ready clean-folder-project global-audit global-fix app-web-intake link-todocky)
# app-master no se instala: opera sobre la base global de AppleAppLab (KNOWN_ISSUES.md), no sobre proyectos
REMOTE_VERSION=$(curl -sf "$RAW/VERSION" | tr -d '[:space:]')

echo "🍎 AppleAppLab setup (v$REMOTE_VERSION)..."

# --- Skills (Claude Code) ---
mkdir -p "$SKILLS_DIR"
for skill in "${SKILLS[@]}"; do
  mkdir -p "$SKILLS_DIR/${skill}"
  curl -s "$RAW/.claude/skills/${skill}/SKILL.md" -o "$SKILLS_DIR/${skill}/SKILL.md"
  rm -f "$SKILLS_DIR/${skill}.md"   # formato plano anterior — Claude Code no lo registra como comando
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

# --- Research/ (HIG, Xcode 27 MCP y demás documentación de referencia que los skills citan) ---
mkdir -p "Research"
if curl -sfL "https://github.com/hiyuno/AppleAppLab/archive/refs/heads/main.tar.gz" \
    | tar -xz --strip-components=2 -C "Research" "AppleAppLab-main/Research" 2>/dev/null; then
  echo "  ✓ Research/ sincronizado (HIG, Xcode 27 MCP, etc.)"
else
  echo "  ⚠ No se pudo sincronizar Research/ — revisa conexión y reintenta con /update-team"
fi

# --- Skills oficiales de Apple (Xcode ≥ 27) — export local con sello de build; nunca entran al repo ---
XCODE_MAJOR=$(xcodebuild -version 2>/dev/null | awk 'NR==1{print int($2)}')
if [ -n "$XCODE_MAJOR" ] && [ "$XCODE_MAJOR" -ge 27 ]; then
  XCODE_BUILD=$(xcodebuild -version | awk 'NR==2{print $3}')
  XSKILLS="$HOME/.claude/xcode-skills"
  STAMP="$XSKILLS/.xcode-build"
  if [ ! -f "$STAMP" ] || [ "$(cat "$STAMP")" != "$XCODE_BUILD" ]; then
    mkdir -p "$XSKILLS"
    if xcrun mcpbridge run-agent skills export --output-dir "$XSKILLS" --replace-existing >/dev/null 2>&1; then
      echo "$XCODE_BUILD" > "$STAMP"
      echo "  ✓ Skills de Apple exportadas a ~/.claude/xcode-skills (Xcode $XCODE_BUILD)"
    else
      echo "  ⚠ No se pudieron exportar las skills de Apple — corre a mano: xcrun mcpbridge run-agent skills export --output-dir ~/.claude/xcode-skills --replace-existing"
    fi
  else
    echo "  ↩ Skills de Apple al día (Xcode $XCODE_BUILD)"
  fi
  mkdir -p "$HOME/.claude/skills"
  for link in "$HOME/.claude/skills"/*; do
    [ -L "$link" ] || continue
    case "$(readlink "$link")" in "$XSKILLS"/*) [ -e "$link" ] || rm -f "$link" ;; esac
  done
  for dir in "$XSKILLS"/*/; do
    [ -f "$dir/SKILL.md" ] || continue
    ln -sfn "${dir%/}" "$HOME/.claude/skills/$(basename "$dir")"
  done
  echo "  ✓ Skills de Apple enlazadas en ~/.claude/skills (swiftui-specialist, device-interaction, modernize-tests…)"
  if ! claude mcp list 2>/dev/null | grep -q '^xcode:'; then
    echo "  → MCP de Xcode sin registrar: claude mcp add --scope user --transport stdio xcode -- xcrun mcpbridge"
    echo "    y activa Xcode → Settings → Intelligence → Model Context Protocol → \"Allow external agents to use Xcode tools\""
  fi
else
  echo "  ↩ Xcode < 27 o no instalado — skills de Apple y MCP de Xcode omitidos"
fi

# --- asc (App Store Connect CLI) — opcional; acelera /app-store-ready, Phil, Craig, Frederick, Kara. Nunca requisito ---
if command -v asc >/dev/null 2>&1; then
  echo "  ✓ asc $(asc version 2>/dev/null | head -1) detectado — /app-store-ready usará App Store Connect desde la terminal"
  echo "    → skills del proveedor para agentes (25): asc install-skills"
else
  echo "  ↩ asc no instalado (opcional): brew install asc — Research/asc-cli/00-index.md"
fi

# --- Memoria evolutiva ---
curl -fsSL "$RAW/KNOWN_ISSUES.md" -o ".appleapplab/KNOWN_ISSUES.md"
echo "  ✓ Snapshot global actualizado en .appleapplab/KNOWN_ISSUES.md"

# --- Template del intake para el sitio web (web-lab /app-web) ---
# Solo el template; app-web-intake.md se crea en la raíz únicamente cuando el usuario pide /app-web-intake
curl -fsSL "$RAW/APP_WEB_INTAKE_TEMPLATE.md" -o ".appleapplab/app-web-intake-template.md"
echo "  ✓ Template de app-web-intake en .appleapplab/ (se usa con /app-web-intake)"

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
  /update-team → Sincronizar equipo con la última versión de AppleAppLab
  /update-feature → Sparkle: actualizaciones automáticas fuera del App Store (macOS)
  /optimize-app → Auditoría de performance + plan por etapas (go <n> aplica cada una)
  /architecture-audit → Auditoría de arquitectura: veredicto + migración por etapas (go <n>)
  /app-store-ready → ¿Lista para App Store? Veredicto, plan por etapas y opciones de distribución (go <n>)
  /clean-folder-project → Limpiar y organizar carpetas y archivos: estructura objetivo + plan con git mv (go <n>)
  /global-audit → Las cuatro auditorías + reconciliación: un tablero y una secuencia global de go en rondas
  /global-fix <error> → Bugs que vuelven: reproducir, mapa del flujo, todas las causas, fix por causa, verificar, simplificar (auto sin checkpoints)
  /app-web-intake → Intake del sitio web para web-lab: app-web-intake.md se llena mientras construimos (solo a petición)
  /link-todocky <code> → Enlaza este repo a su proyecto en Todocky (código de 'Copy project number'; requiere el MCP)"
echo ""
echo "Compatibilidad:"
echo "  Claude Code → .claude/skills/ + CLAUDE.md"
echo "  Cursor      → .cursor/rules/apple-team.mdc"
echo "  Codex       → AGENTS.md"
echo "  Gemini CLI  → GEMINI.md"
echo "  Xcode 27    → MCP 'xcode' (claude mcp) + skills de Apple en ~/.claude/skills/"
echo ""
echo "→ Abre $(pwd) en Claude Code — Steve arranca solo."

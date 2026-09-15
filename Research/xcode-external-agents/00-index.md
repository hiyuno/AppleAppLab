# Xcode 27: Acceso de Agentes Externos

## Resumen ejecutivo

Xcode 27 (en beta desde junio 2026, lanzamiento público septiembre 2026) introduce soporte de primera clase para agentes externos (Claude Code, Cursor, Codex, Gemini, etc.) mediante el **Model Context Protocol (MCP)** y el puente **mcpbridge** de Apple. Esto permite que agentes externos accedan en tiempo real al proceso vivo de Xcode: read/write de archivos, compilación, testing, debugging, SwiftUI previews, automatización de simulador, acceso a diagnósticos, y búsqueda en documentación de Apple.

## Fuentes

- [Enabling the Xcode 27 MCP Server in Claude Code](https://crunchybagel.com/enabling-the-xcode-27-mcp-server-in-claude-code/)
- [How to use Xcode 27 MCP Server - Wendy Liga](https://wendyliga.com/blog/how-to-use-xcode-27-mcp-server/)
- [Xcode 27: The Future of Agent-Driven Development - DEV Community](https://dev.to/arshtechpro/xcode-27-the-future-of-agent-driven-development-is-here-12fk)
- Apple Developer Documentation: [Giving external agents access to Xcode](https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode) (página oficial, no accesible en este fetch)

---

## 1. Qué es el MCP de Xcode

**Model Context Protocol (MCP)**: protocolo abierto que define cómo agentes externos pueden:
- Leer/escribir/actualizar archivos
- Compilar proyectos
- Ejecutar tests
- Acceder a diagnósticos y errores de build

**mcpbridge**: ejecutable de Apple que traduce MCP sobre XPC hacia el proceso vivo de Xcode, convirtiendo el IDE en un nodo MCP universal.

Apple también definió **Agent Client Protocol (ACP)** para permitir que cualquier implementación de agente de terceros se conecte a Xcode.

---

## 2. Cómo habilitar el acceso (Setup)

### En Xcode
1. Abre **Settings (Preferences) > Intelligence > Model Context Protocol**
2. Activa **"Allow external agents to use Xcode tools"**

### Desde el agente externo

Registra el MCP server con la herramienta CLI del agente:

**Claude Code:**
```bash
claude mcp add --scope user --transport stdio xcode -- xcrun mcpbridge
```

**Codex:**
```bash
codex mcp add xcode -- xcrun mcpbridge
```

**Verificación:**
```bash
claude mcp list  # (puede disparar prompts de permisos)
```

---

## 3. Requisitos

- **Xcode 27**: beta 3 o posterior (disponible desde junio 2026; release público esperado septiembre 2026)
- **Hardware**: Apple Silicon únicamente (Neural Engine integrado)
- **Permisos**: nivel de usuario; algunos tooling puede disparar prompts del sistema
- **Agente externo**: Claude Code, Cursor, Codex, Gemini, o compatible con MCP/ACP

---

## 4. Capacidades principales

### 4.1 Build & Desarrollo
- Compilar esquemas activos con reporte de errores/warnings
- Ejecutar operaciones build-and-run con adjunción de debugger opcional
- Acceso a logs de build comprensivos

### 4.2 Testing & Debugging
- Enumerar y ejecutar test targets, clases, o métodos específicos
- Acceso a comandos LLDB en sesiones de debug compartidas
- Leer console output en vivo de aplicaciones en ejecución

### 4.3 Gestión de Proyecto
- Read/write/update de archivos del proyecto con búsqueda glob y grep
- Gestión de build settings y compiler flags por archivo
- Manejar entitlements e Info.plist
- Listar y filtrar problemas del Issue Navigator

### 4.4 UI & Previews
- Renderizar SwiftUI previews a imágenes (con parámetros personalizables)
- Soportar variantes de preview y controles timeline de widgets

### 4.5 Automatización & Runtime
- Interacción UI en simulador/dispositivo (síntesis de entrada por coordenadas)
- Acceso a crash signatures y diagnósticos de performance de App Store/TestFlight
- Ejecución de snippets Swift en REPL
- Búsqueda semántica en documentación de frameworks de Apple
- Gestión de localizaciones en String Catalog

### 4.6 Workspace Management
- Abrir ventanas de workspace
- Cambiar esquemas y run destinations

---

## 5. Flujo de trabajo completo

1. **Inspección**: Agente lee el estado del proyecto activo (archivos, settings, targets)
2. **Cambios**: Agente modifica código/configuración
3. **Build**: Agente compila vía Xcode, recibe errores/warnings en tiempo real
4. **Test**: Agente ejecuta tests y lee resultados
5. **Preview**: Agente renderiza SwiftUI previews como imágenes
6. **Interacción**: Agente automatiza UI en simulador/dispositivo
7. **Validación**: Agente verifica sin intervención manual

Todo esto ocurre en un loop autonomo sin que el developer tenga que tocar Xcode manualmente (aunque siempre puede editar el plan en Markdown antes de ejecutar).

---

## 6. Arquitectura de Xcode 27

### Dual-Engine System

**Motor local (On-Device Intelligence)**:
- Modelos en dispositivo sobre el Neural Engine de Apple Silicon
- Sugerencias de código instantáneas
- Sin conectividad a cloud, sin exposición de fuente

**Agentes avanzados (External Agents)**:
- Tareas complejas: refactoring multi-archivo, debugging autónomo, etc.
- Proveedores: Anthropic (Claude), Google (Gemini), OpenAI (Codex), etc.

### Interfaz de Conversación
- Developer describe requisitos en lenguaje natural
- Agente genera plan en Markdown (editable antes de ejecutar)
- Cambios de código se muestran con previews en vivo

---

## 7. Protocolos involucrados

- **Model Context Protocol (MCP)**: protocolo abierto que define tools y capacidades
- **Agent Client Protocol (ACP)**: protocolo que permite implementaciones de agente de terceros
- **XPC (Inter-Process Communication)**: puente de Apple que traduce MCP ↔ Xcode process

---

## 8. Integración de terceros

Apple también permite que servicios como GitHub y Figma se integren como MCP extensions, poniendo control de versión y assets de diseño a disposición de agentes.

---

## 9. Notas de seguridad & permisos

- El acceso requiere **consentimiento explícito en Settings** de Xcode
- Cada agente externo debe estar registrado via CLI (no auto-discovery)
- Algunos tooling puede disparar prompts del sistema operativo
- Los source code **no viajan a la cloud** si se usa motor local; solo se envía metadata si se requiere agente externo avanzado

---

## 10. Timeline & disponibilidad

- **Developer Beta**: desde 8 junio 2026
- **Public Release**: esperado septiembre 2026
- **Scope**: Apple Developer Program members inicialmente

---

## Recomendaciones de implementación para AppleAppLab

1. **Avie** (Arquitecto): Integrar MCP de Xcode en la arquitectura del flujo de agentes; definir cómo Woz, Bertrand, y otros pueden usar mcpbridge.
2. **Woz** (Coder): Implementar llama a mcpbridge desde Claude Code, gestionar errores/outputs de build, integrar en el flujo de desarrollo.
3. **Bertrand** (QA): Usar MCP para ejecutar tests automáticos vía agentes, recolectar resultados, validar UI.
4. **Ivan** (Security Architect): Revisar modelo de permisos de mcpbridge, threat model de acceso externo a Xcode, requisitos de firma/entitlements si se extiende.

---

**Recolectado**: 2026-09-14

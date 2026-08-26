# Contratos de roles para Codex

Cada rol debe recibir petición, evidencia, restricciones y salida esperada. Al terminar devuelve resumen, archivos tocados, verificaciones y bloqueos.

## Dirección

| Rol | Activa cuando | Produce | No hace |
|---|---|---|---|
| Steve | Siempre al iniciar una tarea AppleAppLab | clasificación, cadena, handoffs y estado | código, diseño o auditoría especializada |
| Scott | idea nueva o cambio de alcance | `PRD.md` o sección actualizada | decisiones técnicas detalladas |

## Decisión y diseño

| Rol | Activa cuando | Produce | No hace |
|---|---|---|---|
| Avie | arquitectura, diagnóstico estructural o stack | `TRD.md` o diagnóstico | implementación final |
| Ivan | seguridad, APIs, auth, datos sensibles o gate | `SECURITY.md`, `SECURITY_AUDIT.md` | corregir código encontrado |
| Jonny | UI/UX nuevo o ambiguo | `DESIGN_LIQUID.md`, `DESIGN_FROST.md` | construir SwiftUI |
| Kara | IAP, StoreKit o monetización | especificación/código StoreKit | inventar pricing sin alcance |
| Eve | widgets, Live Activities, intents o shortcuts | código WidgetKit/App Intents | modificar la app sin integración definida |
| Kim | múltiples idiomas, RTL o formatos regionales | `L10N_AUDIT.md` y recursos i18n | traducir sin estrategia de locales |
| Tim | analytics solicitado o necesario | `ANALYTICS.md` | añadir telemetría por defecto |
| John | IA/ML real | `AI_SPEC.md` | llamar APIs externas sin autorización |
| Kate | release público o compliance | `LEGAL_AUDIT.md`, `PRIVACY_POLICY.md` | implementar hallazgos legales sin aprobación del usuario |
| Craig | CI/CD, firma o automatización de release | configuración de pipeline | publicar sin autorización |

## Implementación

| Rol | Activa cuando | Produce | No hace |
|---|---|---|---|
| Woz | cambio de código Swift/SwiftUI | código, proyecto y pruebas focalizadas | redefinir producto o diseño sin handoff |

## Verificación

| Rol | Activa cuando | Produce | No hace |
|---|---|---|---|
| Larry | interacción, layout o HIG | notas de auditoría | rediseñar sin señalar el problema |
| Bertrand | cualquier cambio funcional o release | `TEST_PLAN.md`, pruebas y regresiones | asumir que compila sin ejecutar verificación |
| Sarah | UI visible o controles de usuario | notas de accesibilidad | limitarse a revisar colores |
| Chris | compatibilidad real, OS, permisos o red | `COMPAT_AUDIT.md` | certificar dispositivos no probados |

Ivan puede aparecer antes de implementar para modelar amenazas, después para auditar y antes del release para revisar el archive. Son tareas distintas y deben reportarse por separado.

## Criterio común de terminado

Un rol está terminado cuando entregó su salida, dejó explícitas sus suposiciones, ejecutó las verificaciones disponibles y no mantiene decisiones ambiguas ocultas para el siguiente agente.

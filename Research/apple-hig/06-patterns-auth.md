# Authorization & Sign-In Patterns

**Fuentes**:
- https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple
- https://developer.apple.com/documentation/AuthenticationServices/implementing-user-authentication-with-sign-in-with-apple
- https://developer.apple.com/news/?id=09122019b (Guidelines for Sign in with Apple)

**En una frase**: Cómo diseñar sign-in flows seguros, privados y confiables usando Sign in with Apple como primera opción.

---

## Sign in with Apple (Recomendado)

### Por qué usar Sign in with Apple

1. **Privacidad**: No compartir email real con app (usa relay privado si user lo elige).
2. **Seguridad**: Two-Factor Authentication requerido en el ID de Apple.
3. **Consistencia**: Usuario ya confía en esto (usa Apple ID en dispositivo).
4. **UX**: Sin passwords que recordar, sin second-factor SMS.

### Requisitos Obligatorios

- User debe haber habilitado **Two-Factor Authentication** en su Apple ID.
- Si no está enabled, el sistema le pide que lo haga en Settings.
- **App Store Requirement**: Si tu app incluye sign-up con cuenta de terceros (Google, Facebook), DEBES ofrecen Sign in with Apple como opción.

### Flujo de Sign in with Apple

1. User tap el botón "Sign in with Apple".
2. Sistema verifica si está logged in con Apple ID en el dispositivo.
3. Si SÍ: Solicita confirmación (opcional pedirle verificar con Face ID).
4. Si NO: Abre System Settings para que sign-in.
5. App recibe:
   - User identifier (encriptado, único, persistente).
   - User's name (si eligió compartir).
   - Email (real o relay privado).
   - Credential (JWT token para backend).

### Sign in with Apple Button

**Diseño**:
- Usar el **official Apple-provided button asset** (no crear custom).
- Botón debe ser al menos tan prominente como otras opciones de sign-in.
- No puede estar "debajo del fold" en la pantalla de sign-in.

**Variaciones**:
- **"Sign in with Apple"** — standard label.
- **"Continue with Apple"** — si es sign-up flujo.
- **Icon only** — en constrained spaces (ej. Apple Watch).

**Color**:
- **Light mode**: Black button con white text (o black text en white background, menos recomendado).
- **Dark mode**: White button con black text.
- **No cambiar colores** ni tamaños — apple es específica.

### Sign in with Apple for the Web

Si web app también lo soporta:
- Usar el mismo flujo (JSON Web Token).
- Usuario no necesita estar en iOS — apple.com reenvía al navegador web.

---

## Other Sign-In Options (Fallback)

### Biometric First (Face ID / Touch ID)

**Si el app ya tiene cuenta establecida**:
- Ofrecer biometric unlock como opción rápida.
- No fuercer sign-in de nuevo si ya tiene sesión.

### OAuth / Social Login

**Si el app permite sign-up con Google, Facebook, etc.**:
- Estos van DESPUÉS de "Sign in with Apple".
- Menos prominentes pero permitidos.

### Traditional Username / Password

**No recomendado en iOS**:
- Más fricción que biometric.
- Menos seguro.
- Si es necesario (legacy system):
  - AutoFill de iCloud Keychain debe funcionar.
  - Password generator integrado en iOS.
  - Show/hide password toggle.

---

## Sign-Up vs Sign-In

### Sign-In (Existing Account)

```
User has account → Sign in with Apple / Password / Biometric
                ↓
             Success → App home
```

### Sign-Up (New Account)

```
User new to app → "Create account" button
                ↓
             Continue with Apple / Email signup
                ↓
             (optional) Fill profile info
                ↓
             Account created → App home
```

**Best Practice**: Allow user to start sign-up, then realize they already have account, then switch to sign-in — don't require restart.

---

## Flow Implementation

### State 1: Onboarding (No Account)

- Big "Sign in with Apple" button.
- Optional smaller "Create with Email" / "Continue with Google" buttons.
- No form fields yet.

### State 2: Biometric Unlock (Existing Account)

- Face ID / Touch ID prompt.
- "Use password instead" link as fallback.
- Seamless → home if success.

### State 3: Account Recovery

- "Forgot password?" link (if applicable).
- Email reset flow.

### State 4: Account Settings

- Show current sign-in method.
- Allow add secondary auth (ej. email backup).
- Disconnect auth method if alternatives exist.

---

## Authorization Requests (System Permissions)

**Separate from Sign-In** — but often follow:
- After user signed in, app can request camera, microphone, contacts, etc.
- **Ask just-in-time**: Pedir permiso cuando necesario, no al launch.
- **Explain first**: Mostrar sheet o alert explicando por qué.

### Request Flow

```
Feature needs permission
    ↓
User taps feature
    ↓
Dialog: "App wants to access your Camera"
    ↓
User allows → Proceed
  or denies → Graceful degradation
```

**Recomendación**: Primero permitir preview con permiso, si user denies, mostrar explanation screen ("To take photos, allow camera access in Settings").

---

## Platform Differences

| Platform | Default | Notes |
|----------|---------|-------|
| **iOS** | Sign in with Apple + Biometric | Touch ID / Face ID standard |
| **macOS** | Sign in with Apple + Password | No Touch ID típicamente |
| **iPadOS** | Sign in with Apple + Biometric | Similar a iOS |
| **watchOS** | Biometric + Handoff | Complete sign-in en iPhone |

---

## Accessibility

- **Color contrast**: Button must pass WCAG AA (4.5:1).
- **Touch target**: Button mínimo 44pt tall (Apple recomendación).
- **VoiceOver**: "Sign in with Apple, button" — claro y descriptivo.
- **Keyboard navigation**: Tab to button, Space/Return to activate.
- **Focus indicator**: Visible focus ring around button.

---

## Security Checklist

- [ ] Sign in with Apple button prominently placed (Estado 1).
- [ ] Biometric available si user tiene cuenta (Estado 2).
- [ ] Password field masked by default (si needed).
- [ ] Show/hide password toggle accesible.
- [ ] Biometric works offline.
- [ ] Session persists with encryption (no plaintext tokens).
- [ ] Logout clears all sensitive data.
- [ ] Force re-auth para sensitive operations (payment, delete account).

---

## Fecha de recolección

2026-08-24

# Sharing & Collaboration Patterns

**Fuentes**:
- https://developer.apple.com/design/human-interface-guidelines/collaboration-and-sharing
- Apple HIG Sharing guidelines
- SwiftUI ShareLink documentation

**En una frase**: Cómo permitir users compartir contenido, colaborar en tiempo real, y aprovechar características nativas de Apple (AirDrop, Messages, etc.).

---

## Sharing: When & How

### Types of Sharing

1. **Simple Share** — User selects item(s) and shares via sheet.
   - Típico: button o long-press → share sheet.
   - Destinos: Mail, Messages, AirDrop, Reminders, etc.

2. **Contextual Sharing** — Share within app.
   - Ej. Invite friends to group, add to Reminders, send via Messages.
   - Menos formal que "Share to Apps".

3. **Deep Share** — Share with link/QR that opens in app.
   - Ej. Shared document link → abrir en Pages/Numbers.
   - Requiere app to handle link (universal link o deep link).

### When to Offer Sharing

- User selects item.
- Item is complete/ready to share (no drafts).
- Item has external value (others should know about it).

**Don't**: Force sharing at app launch, or hide core features behind sharing.

---

## Share Sheet (iOS/macOS)

Apple provides a built-in **Share Sheet** that shows available share destinations.

### SwiftUI Implementation (iOS 16+)

```swift
ShareLink(item: URL(string: "https://example.com/item123")!,
          subject: Text("Check this out"),
          message: Text("I found this cool item!"),
          preview: SharePreview("Item Title", image: Image(systemName: "star.fill"))) {
    Label("Share", systemImage: "square.and.arrow.up")
}
```

Or simplified:

```swift
ShareLink(item: myDocument,
          subject: Text(myDocument.title)) {
    Label("Share", systemImage: "square.and.arrow.up")
}
```

### Share Sheet Behavior

- **Built-in apps**: Mail, Messages, Notes, Reminders, etc.
- **Third-party apps**: Installed apps with sharing extensions (Twitter, Slack, etc.).
- **AirDrop**: Available when other devices nearby (iOS 7+).
- **Copy**: Always available ("Copy URL", "Copy").
- **Custom actions**: App can add custom share actions (optional).

---

## AirDrop

**What It Is**: Wireless sharing between Apple devices without requiring network.

### When to Support AirDrop

- Sharing files (documents, images, videos).
- Sharing contacts (vCard).
- Sharing URLs or text (less useful than share sheet).

### How It Works (from user perspective)

1. Select item → Share button → AirDrop option → Choose recipient device → Done.
2. Recipient gets notification → Accept/Decline → Item imported.

### SwiftUI: Automatic via ShareLink

AirDrop is automatically included in ShareLink if:
- iOS 13+ (or macOS 10.15+).
- Item conforms to Transferable protocol.

```swift
// Image auto-supports AirDrop via Transferable
ShareLink(item: myImage, preview: SharePreview("Photo", image: myImage))
```

---

## Direct Sharing Within App

**Don't force share sheet for everything** — sometimes sharing is contextual.

### Patterns

1. **Invite to Group**
   - Button → "Invite Members" → Send invite link or in-app notification.
   - Better UX than generic share sheet.

2. **Add to List / Reminder**
   - Quick action (not sheet) → Add to Reminders, Calendar, etc.
   - Use system frameworks (EventKit, RemindersKit).

3. **Send in Message**
   - If app has direct messaging → Send item directly.
   - Faster than Messages app.

---

## Collaboration (Real-Time)

**Advanced pattern** — multiple users editing same content.

### Technologies

- **CloudKit** (Apple's backend) — sync data across devices & users.
- **Combine** — reactive updates.
- **SwiftUI Observable** — UI reflects changes.

### Design Principles

1. **Show who's editing** — Avatar + name of other users in document.
2. **Conflict resolution** — Clear rules (last-edit wins, or merge).
3. **Permissions** — Owner, Editor, Viewer roles.
4. **Offline support** — Work offline, sync when back online.

### Example Flow (e.g., Shared Notes)

```
User A opens note → Share button → Copy share link
User A sends link to User B
User B opens link → App opens, displays note, shows "User A is editing"
User B edits → Real-time sync to User A
User A sees changes live
```

---

## What to Share

### Good Candidates

- **URLs** — Easy to share, deep-link to content.
- **Documents** — PDFs, images, videos.
- **Contacts** — Phone numbers, emails (vCard).
- **Rich content** — Text + images + metadata.

### Avoid Sharing

- **Passwords** — Extreme security risk.
- **Private data** — Medical, financial info.
- **Drafts** — Incomplete, may change.

---

## Platform Differences

| Platform | Share Sheet | AirDrop | Best For |
|----------|-------------|---------|----------|
| **iOS** | Full | Yes | AirDrop is native, expected |
| **macOS** | Full | Yes (10.15+) | Less common to share files |
| **iPadOS** | Full | Yes | Similar to iOS |
| **watchOS** | Limited | Yes (6.0+) | Quick shares only |

**macOS note**: Share menu typically in menu bar or toolbar (not bottom sheet like iOS).

---

## Accessibility

- **Share button**: Clearly labeled with icon + text ("Share").
- **VoiceOver**: "Share, button" — speaks action.
- **Share sheet**: VoiceOver navigable, items clearly listed.
- **AirDrop**: Device names clearly spoken.
- **Permissions**: Ask permission clearly before sharing (e.g., access to contacts).

---

## Security & Privacy Considerations

1. **User control**: Never auto-share without explicit tap.
2. **Permissions**: Request camera/contacts access only when needed, explain why.
3. **Deep linking**: Validate that links are safe (no XSS, injection).
4. **Encryption**: Share links with unique tokens, expire after time if sensitive.
5. **Audit trail**: Log shares for compliance if required.

---

## Best Practices

- **Make sharing obvious** — Button with share icon is recognized globally.
- **Test share destinations** — Ensure content formats well in Mail, Messages, Notes.
- **Respect privacy settings** — Don't share email without permission.
- **Provide context** — Share includes title, preview, or thumbnail.
- **Fallback gracefully** — If share fails, offer alternative (copy link, save).

---

## Fecha de recolección

2026-08-24

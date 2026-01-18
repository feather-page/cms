# Features Index

## Zweck
Diese Datei bietet einen schnellen Überblick über alle Features im Projekt - für Menschen zum Navigieren und für AI-Agenten zum token-sparenden Suchen relevanter Dokumentation.

---

## Übersicht aller Features

| Feature | Status | Beschreibung | Verzeichnis |
|---------|--------|--------------|-------------|
| _example-feature_ | _planned/in-progress/completed_ | _Kurze 1-Satz Beschreibung_ | `[feature-name]/` |

<!--
Beispiel-Einträge:

| Feature | Status | Beschreibung | Verzeichnis |
|---------|--------|--------------|-------------|
| User Authentication | completed | Login, logout, session management | `authentication/` |
| Report Export | in-progress | Export reports as PDF/Excel | `report-export/` |
| Email Notifications | planned | Send email notifications for events | `email-notifications/` |
-->

---

## Features nach Kategorie

### Authentication & Authorization
- _Liste der Features_

### Data Management
- _Liste der Features_

### UI/UX
- _Liste der Features_

### Integration
- _Liste der Features_

---

## Schnellsuche

### Du arbeitest an einem Feature?
1. Finde es in der Tabelle oben
2. Öffne `docs/features/[feature-name]/README.md`
3. Dort findest du Links zu allen Diagrammen und Details

### Du suchst nach ähnlichen Patterns?
- **Authentication**: Siehe `authentication/`
- **API Endpoints**: Siehe `[feature-with-api]/sequence.md`
- **UI Components**: Siehe `[ui-feature]/ui-mockup.md`

---

## Architektur-Entscheidungen (ADRs)

Siehe: `docs/architecture/decisions/`

### Relevante ADRs nach Thema:

| ADR | Thema | Betroffene Features |
|-----|-------|---------------------|
| _001-auth_ | _Authentication Method_ | _authentication, user-profile_ |

---

## Navigation-Tipps

### Für Menschen 👤
- **Übersicht**: Tabelle oben zeigt alle Features auf einen Blick
- **Details**: Klick auf Feature-Ordner → `README.md` → alle Infos
- **Kategorien**: Finde verwandte Features schnell
- **ADRs**: Siehe welche Architektur-Entscheidungen welches Feature betreffen

### Für AI-Agenten 🤖

**⚡ Token-sparende Such-Strategie:**

1. **Start hier** (dieser Index) → 1 File read
2. **Relevante Features identifizieren** → Kategorie/Beschreibung
3. **Nur relevante README.md lesen** → `docs/features/[name]/README.md`
4. **Nur bei Bedarf Diagramme lesen**:
   - `flow.md` → User Flow
   - `sequence.md` → API-Interaktionen
   - `ui-mockup.md` → UI-Layout
   - `feature.gherkin` → Test-Scenarios

**❌ Nicht tun:**
- Alle Feature-Ordner durchsuchen
- Alle Diagramme lesen
- Unrelated Features explorieren

**✅ Immer lesen:**
- `AGENTS.md` → Workflow & Regeln
- `GLOSSARY.md` → Domänensprache
- `docs/architecture/README.md` → System-Übersicht
- Relevante ADRs für dein Feature

---

## Wartung

### Beim Erstellen eines neuen Features:
1. Erstelle Feature-Ordner: `docs/features/[feature-name]/`
2. **Aktualisiere diesen Index** (README.md) mit neuem Eintrag
3. Füge Feature zur passenden Kategorie hinzu
4. Verlinke relevante ADRs

### Beim Abschließen eines Features:
1. Setze Status auf "completed"
2. Stelle sicher, dass alle Diagramme aktuell sind

---

## Template

```bash
# Neues Feature hinzufügen
mkdir -p docs/features/[feature-name]
cp docs/templates/feature-template.md docs/features/[feature-name]/README.md
cp docs/templates/feature.gherkin docs/features/[feature-name]/

# Diesen Index aktualisieren
# Füge eine Zeile zur Tabelle hinzu
```

---

## Änderungshistorie

| Datum | Feature | Aktion |
|-------|---------|--------|
| _YYYY-MM-DD_ | _feature-name_ | _Created/Updated/Completed_ |

# Documentation Templates

Diese Vorlagen helfen bei der strukturierten Dokumentation von Features, Architektur-Entscheidungen und UI-Designs.

## Verfügbare Templates

### 1. Feature Documentation
**Datei:** `feature-template.md`

**Verwendung:**
```bash
cp templates/feature-template.md docs/features/[feature-name]/README.md
```

**Enthält:**
- Overview
- Gherkin Scenarios (Verweis)
- User Flow (Mermaid)
- Architecture/Sequence Diagram (Mermaid)
- UI Mockup (ASCII-Art)
- Implementation Notes
- Testing Strategy
- Change History

---

### 2. Gherkin Feature File
**Datei:** `feature.gherkin`

**Verwendung:**
```bash
cp templates/feature.gherkin docs/features/[feature-name]/feature.gherkin
```

**Enthält:**
- Feature description (As a... I want... So that...)
- Background (common preconditions)
- Happy Path Scenario
- Alternative Path Scenario
- Error Case Scenario
- Edge Case Scenario
- Scenario Outline (data-driven)

**Wichtig:** Gherkin-Files immer auf **Englisch** schreiben!

---

### 3. Architecture Decision Record (ADR)
**Datei:** `architecture-decision-record.md`

**Verwendung:**
```bash
cp templates/architecture-decision-record.md docs/architecture/decisions/XXX-[decision-name].md
```

**Enthält:**
- Status (Proposed, Accepted, Deprecated, Superseded)
- Context & Requirements
- Decision Statement
- Options Considered (mit Pros/Cons)
- Consequences (Positive, Negative, Neutral)
- Implementation Notes
- Diagrams
- Review History

---

### 4. UI Mockup Template
**Datei:** `ui-mockup-template.md`

**Verwendung:**
```bash
cp templates/ui-mockup-template.md docs/features/[feature-name]/ui-mockup.md
```

**Enthält:**
- Desktop View (ASCII-Art)
- Tablet View (ASCII-Art)
- Mobile View (ASCII-Art)
- Component Details
- User Interactions (Mermaid)
- States & Variants (Loading, Empty, Error)
- Accessibility Notes
- Design Tokens
- Implementation Notes

---

## Workflow-Empfehlung

### Für neue Features:

1. **Erstelle Feature-Ordner:**
   ```bash
   mkdir -p docs/features/[feature-name]
   ```

2. **Kopiere Templates:**
   ```bash
   cp templates/feature.gherkin docs/features/[feature-name]/
   cp templates/feature-template.md docs/features/[feature-name]/README.md
   cp templates/ui-mockup-template.md docs/features/[feature-name]/ui-mockup.md
   ```

3. **Fülle die Templates aus:**
   - Beginne mit `feature.gherkin` (Gherkin Scenarios)
   - Ergänze `README.md` (Flow, Sequence, Notes)
   - Erstelle `ui-mockup.md` (für UI-Features)

4. **Iteriere mit dem Team/AI:**
   - Diskutiere Gherkin Scenarios
   - Verfeinere Visualisierungen
   - Dokumentiere Entscheidungen

### Für Architektur-Entscheidungen:

1. **Erstelle ADR:**
   ```bash
   # Finde nächste ADR-Nummer
   ls docs/architecture/decisions/ | wc -l

   # Kopiere Template
   cp templates/architecture-decision-record.md docs/architecture/decisions/001-[name].md
   ```

2. **Fülle ADR aus:**
   - Context beschreiben
   - Optionen evaluieren
   - Entscheidung dokumentieren
   - Consequences festhalten

3. **Review & Accept:**
   - Team-Review
   - Status auf "Accepted" setzen
   - Im Projekt referenzieren

---

## Best Practices

### Für Menschen:
- ✅ Templates als Ausgangspunkt nutzen
- ✅ Nicht benötigte Abschnitte entfernen
- ✅ Konkrete Beispiele statt generische Platzhalter
- ✅ Diagramme aktuell halten

### Für AI-Agenten:
- ✅ Templates beim Start eines Features verwenden
- ✅ Alle Abschnitte sorgfältig ausfüllen
- ✅ Bei Unklarheiten Rückfragen stellen
- ✅ Visualisierungen mit dem Menschen abstimmen
- ✅ Change History pflegen

---

## Template-Pflege

Diese Templates sind lebende Dokumente:
- Verbessere sie, wenn du bessere Strukturen findest
- Ergänze projekt-spezifische Abschnitte
- Entferne nicht benötigte Teile
- Dokumentiere die Änderungen

---

## Weitere Ressourcen

- **Gherkin Syntax:** https://cucumber.io/docs/gherkin/reference/
- **Mermaid Dokumentation:** https://mermaid.js.org/
- **ADR Best Practices:** https://adr.github.io/
- **ASCII Art Generator:** https://www.asciiart.eu/

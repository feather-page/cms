# Projekt-Glossar

## Übersicht
Dieses Glossar definiert die Domänensprache für dieses Projekt. Es wird sowohl von Menschen als auch von KI-Agenten gepflegt und genutzt.

**Wichtig:**
- Verwende diese Begriffe konsistent in Code, Dokumentation und Kommunikation
- Das Glossar enthält sowohl **deutsche** als auch **englische** Begriffe
- Bei mehrsprachigen Begriffen sind beide Varianten angegeben

---

## Entwicklungsprozess

### ADR (Architecture Decision Record)
**Definition:** Ein dokumentiertes Protokoll einer Architektur-Entscheidung, das Kontext, Optionen und Begründung festhält.

**Verwendung:** "Diese Entscheidung sollten wir als ADR dokumentieren"

**Ort:** `docs/architecture/decisions/`

**Siehe auch:** Architektur

---

### BDD (Behavior-Driven Development)
**Definition:** Eine Entwicklungsmethode, bei der das Verhalten der Software vor der Implementierung in natürlicher Sprache spezifiziert wird.

**Verwendung:** "Wir arbeiten nach BDD - erst das Scenario, dann der Code"

**Siehe auch:** Gherkin, Cucumber, Feature-First Development

---

### Code Coverage
**Definition:** Der prozentuale Anteil des Codes, der durch Tests ausgeführt wird.

**Verwendung:** "Neuer Code muss 100% Code Coverage haben"

**Typen:**
- **Line Coverage:** Anteil ausgeführter Codezeilen
- **Branch Coverage:** Anteil ausgeführter Verzweigungen

**Siehe auch:** RSpec, Cucumber

---

### Cucumber
**Definition:** Ein Test-Framework, das Gherkin-Scenarios ausführbar macht.

**Verwendung:** "Die Cucumber-Tests laufen mit `bundle exec cucumber`"

**Ort:** `features/` (Step Definitions), `docs/features/` (Feature-Dateien)

**Siehe auch:** Gherkin, Step Definition

---

### Feature-First Development
**Definition:** Ein Workflow, bei dem zuerst die Feature-Spezifikation erstellt und abgestimmt wird, bevor mit der Implementierung begonnen wird.

**Verwendung:** "Bitte erst das Feature schreiben, dann implementieren"

**Siehe auch:** BDD, Gherkin

---

### Gherkin
**Definition:** Eine strukturierte Sprache zur Beschreibung von Software-Verhalten im Given-When-Then-Format.

**Verwendung:** "Schreibe bitte ein Gherkin-Scenario für den Login"

**Format:**
```gherkin
Feature: [Name]
  Scenario: [Beschreibung]
    Given [Ausgangszustand]
    When [Aktion]
    Then [Erwartetes Ergebnis]
```

**Siehe auch:** Cucumber, Scenario

---

### Step Definition
**Definition:** Ruby-Code, der einen Gherkin-Step ausführbar macht.

**Verwendung:** "Die Step Definition für 'Given I am logged in' fehlt noch"

**Ort:** `features/step_definitions/`

**Siehe auch:** Cucumber, Gherkin

---

## Architektur & Code

### ViewComponent
**Definition:** Eine Ruby-Klasse, die einen wiederverwendbaren UI-Baustein kapselt (Template + Logik).

**Verwendung:** "Der Button sollte als ViewComponent implementiert werden"

**Ort:** `app/components/`

**Siehe auch:** Partial

---

### Service Object
**Definition:** Eine Ruby-Klasse, die eine spezifische Business-Logik kapselt und aus Controllern extrahiert wird.

**Verwendung:** "Die Export-Logik gehört in ein Service Object"

**Ort:** `app/services/`

---

### Hugo
**Definition:** Ein statischer Site-Generator, der Markdown in HTML umwandelt.

**Verwendung:** "Hugo baut die statische Website aus den Inhalten"

**Kontext:** Meerkat CMS nutzt Hugo im Backend zum Generieren der Websites

---

## Domänenspezifische Begriffe

### Site
**Definition:** Eine Website, die im CMS verwaltet wird.

**Verwendung:** "Der Benutzer hat drei Sites angelegt"

**Attribute:** Title, Domain, Theme, Emoji

**Englisch:** Site (identisch)

---

### Post
**Definition:** Ein Blog-Beitrag innerhalb einer Site.

**Verwendung:** "Erstelle einen neuen Post für den Blog"

**Attribute:** Title, Content, Slug, Publish Date, Draft Status

**Englisch:** Post (identisch)

---

### Page
**Definition:** Eine statische Seite innerhalb einer Site (kein Blog-Post).

**Verwendung:** "Die About-Seite ist eine Page"

**Englisch:** Page (identisch)

---

### Theme
**Definition:** Eine visuelle Vorlage, die das Aussehen einer Site bestimmt.

**Verwendung:** "Wechsle das Theme zu 'Modern'"

**Englisch:** Theme (identisch)

---

## Benutzer & Rollen

### User / Benutzer
**Definition:** Eine Person, die das CMS nutzt, um Websites zu verwalten.

**Typen:**
- **Site Owner:** Besitzer einer Site mit vollen Rechten
- **Invited User:** Eingeladener Benutzer mit eingeschränkten Rechten

**Verwendung:** "Der User muss eingeloggt sein, um Sites zu sehen"

---

### Agent
**Definition:** Ein KI-System (z.B. Claude), das eigenständig Aufgaben im Projekt ausführt.

**Verwendung:** "Der Agent hat das Feature implementiert"

**Siehe auch:** AGENTS.md

---

## Format-Richtlinien

Wenn du einen neuen Begriff hinzufügst, verwende diese Struktur:

```markdown
### Begriff
**Definition:** Klare, präzise Definition

**Typen/Kategorien:** (optional)
- Untertyp 1: Beschreibung
- Untertyp 2: Beschreibung

**Verwendung:** Beispielsatz in Anführungszeichen

**Kontext:** (optional) Zusätzliche Informationen

**Ort:** (optional) Wo im Projekt zu finden

**Englisch:** (optional) Englischer Begriff

**Siehe auch:** (optional) Verwandte Begriffe
```

---

## Änderungshistorie

| Datum | Geändert von | Änderung |
|-------|--------------|----------|
| 2026-01-18 | Claude | Begriffe aus AGENTS.md ergänzt: BDD, Cucumber, Gherkin, Step Definition, ADR, etc. |

---

## Wartung

### Für Menschen
- Füge neue Begriffe hinzu, wenn sie im Projekt wichtig werden
- Aktualisiere Definitionen, wenn sich das Verständnis ändert
- Halte die Begriffe aktuell und relevant

### Für Agenten
- Prüfe das Glossar vor Beginn der Arbeit
- Verwende die definierten Begriffe konsistent
- Schlage neue Begriffe vor, wenn du sie identifizierst
- Frage bei Unklarheiten nach

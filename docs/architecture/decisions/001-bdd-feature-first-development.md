# ADR-001: BDD Feature-First Development

## Status
**Accepted**

## Date
2026-01-18

## Context

### Problem Statement
- Entwicklung ohne klare Spezifikation führt zu Missverständnissen zwischen Mensch und AI-Agent
- Features werden oft anders implementiert als gedacht
- Keine lebende Dokumentation der Funktionalität

### Requirements
- Klare, verständliche Spezifikation vor der Implementierung
- Ausführbare Tests, die als Dokumentation dienen
- Gemeinsames Verständnis zwischen allen Beteiligten

---

## Decision

**Wir verwenden Behavior-Driven Development (BDD) mit Cucumber und Gherkin als primäre Entwicklungsmethode.**

### Rationale
- Gherkin-Scenarios sind für Menschen und Maschinen lesbar
- Features werden vor der Implementierung abgestimmt
- Tests dienen gleichzeitig als Dokumentation
- Cucumber ist in der Ruby/Rails-Welt etabliert

---

## Options Considered

### Option 1: Keine formale Spezifikation
**Description:** Direkte Implementierung basierend auf Beschreibungen

**Pros:**
- Schneller Start
- Weniger Overhead

**Cons:**
- Missverständnisse häufig
- Keine ausführbare Dokumentation
- Schwer nachvollziehbar

---

### Option 2: User Stories ohne Ausführbarkeit
**Description:** Nur textuelle User Stories

**Pros:**
- Einfach zu schreiben
- Keine Tool-Abhängigkeit

**Cons:**
- Nicht ausführbar
- Veraltet schnell
- Keine Verifikation

---

### Option 3: BDD mit Cucumber/Gherkin ✅
**Description:** Feature-First mit ausführbaren Gherkin-Scenarios

**Pros:**
- Ausführbare Spezifikation
- Lebende Dokumentation
- Gemeinsame Sprache (Given-When-Then)
- Rails-Integration vorhanden

**Cons:**
- Initialer Lernaufwand
- Step Definitions müssen gepflegt werden

---

## Consequences

### Positive
- Klare Kommunikation zwischen Mensch und Agent
- Features sind vor Implementierung abgestimmt
- Tests dokumentieren das Verhalten
- Regressionssicherheit

### Negative
- Mehr Aufwand vor der Implementierung
- Step Definitions müssen gepflegt werden

### Neutral
- Workflow ändert sich: Erst Feature, dann Code

---

## Implementation

### Workflow
1. Anforderungen verstehen und Rückfragen stellen
2. Gherkin-Scenario schreiben
3. Mensch zur Bestätigung bitten
4. Step Definitions implementieren
5. Feature implementieren
6. Cucumber-Tests ausführen

### Projektstruktur
```
docs/features/           # Gherkin Feature-Dateien (.feature)
features/
├── step_definitions/    # Ruby Step-Implementierungen
└── support/             # Cucumber-Konfiguration
```

### Beispiel
```gherkin
Feature: Post Management
  As a site owner
  I want to create blog posts
  So that I can publish content

  Scenario: Create a new post
    Given I am logged in
    And I have a site "My Blog"
    When I create a post with title "Hello World"
    Then the post should exist
```

---

## References
- [Cucumber Documentation](https://cucumber.io/docs)
- [The Cucumber Book](https://pragprog.com/titles/hwcuc2/the-cucumber-book-second-edition/)
- AGENTS.md - Workflow für neue Features

---

## Change History

| Date | Author | Change | Reason |
|------|--------|--------|--------|
| 2026-01-18 | Claude | Created | Initial documentation of BDD approach |

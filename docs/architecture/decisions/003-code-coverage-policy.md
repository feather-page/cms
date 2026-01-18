# ADR-003: Code Coverage Policy

## Status
**Accepted**

## Date
2026-01-18

## Context

### Problem Statement
- Ungetesteter Code führt zu Regressionen
- Unklare Erwartungen an Test-Abdeckung
- Keine einheitliche Coverage-Messung

### Requirements
- Hohe Code-Qualität sicherstellen
- Regressionen vermeiden
- Klare, messbare Ziele

---

## Decision

**Wir streben 100% Line Coverage an, gemessen durch kombinierte RSpec- und Cucumber-Tests.**

### Rationale
- 100% ist ein klares, messbares Ziel
- Kombination aus Unit- und Acceptance-Tests deckt verschiedene Ebenen ab
- SimpleCov ermöglicht einfache Messung und Merge von Coverage-Daten

---

## Options Considered

### Option 1: Keine Coverage-Anforderung
**Description:** Tests nach Ermessen

**Pros:**
- Maximale Flexibilität
- Kein Overhead

**Cons:**
- Ungetesteter Code schleicht sich ein
- Keine Qualitätsgarantie

---

### Option 2: 80% Coverage-Ziel
**Description:** Industriestandard-Minimum

**Pros:**
- Realistisch erreichbar
- Erlaubt Ausnahmen

**Cons:**
- 20% ungetesteter Code
- Unklar, welcher Code ungetestet bleiben darf

---

### Option 3: 100% Line Coverage ✅
**Description:** Vollständige Abdeckung

**Pros:**
- Keine Grauzonen
- Maximale Sicherheit
- Zwingt zu testbarem Design

**Cons:**
- Höherer Aufwand
- Manche Edge Cases schwer testbar

---

## Consequences

### Positive
- Hohe Code-Qualität
- Regressionssicherheit
- Vertrauen bei Refactoring
- Dokumentation durch Tests

### Negative
- Mehr Zeit für Tests
- Manchmal "Coverage-Driven" statt "Quality-Driven"

---

## Implementation

### Test-Pyramide
```
         /\
        /  \       Cucumber (Acceptance)
       /----\      → User-facing Behavior
      /      \
     /--------\    RSpec (Integration/Unit)
    /          \   → Models, Services, Components
   /------------\
```

### Wann welcher Test?

| Situation | Test-Typ | Grund |
|-----------|----------|-------|
| Neues User-Feature | Cucumber | Dokumentiert Verhalten |
| Model-Validierung | RSpec | Schnell, fokussiert |
| Service-Logik | RSpec | Isoliert testbar |
| UI-Workflow | Cucumber | End-to-End |
| Edge Case | RSpec | Schnell, kein Feature-Wert |

### Coverage prüfen
```bash
# Kombinierte Coverage (RSpec + Cucumber)
rake coverage

# Report anzeigen
open coverage/index.html
```

### Erlaubte Ausnahmen (müssen dokumentiert werden)
- Dead Code, der entfernt wird
- Plattform-spezifischer Code
- Emergency Fallbacks

---

## References
- [SimpleCov](https://github.com/simplecov-ruby/simplecov)
- AGENTS.md - Test-Anforderungen

---

## Change History

| Date | Author | Change | Reason |
|------|--------|--------|--------|
| 2026-01-18 | Claude | Created | Document coverage policy |

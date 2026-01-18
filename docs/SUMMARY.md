# Best Practices für Mensch-AI-Zusammenarbeit: Zusammenfassung

## Übersicht

Dieses Dokument fasst alle Best Practices und Workflows für die effektive Zusammenarbeit zwischen Menschen und KI-Agenten in der Softwareentwicklung zusammen.

---

## 🎯 Kernprinzipien

### 1. Gemeinsame Grundlage schaffen
- **Gherkin** (auf Englisch) als gemeinsame Spezifikationssprache
- **Glossar** (DE + EN) für Domänenbegriffe
- **Index-basierte Dokumentation** für token-effiziente Suche

### 2. Visualisierung vor Implementierung
- Mermaid-Diagramme für Flows und Architekturen
- ASCII-Art für UI-Mockups
- Gemeinsame Abstimmung und Iteration

### 3. Dokumentation während der Arbeit
- Nicht nachträglich dokumentieren
- Strukturierte Ablage in `docs/`
- Feature-Index aktuell halten

### 4. Sicherheit und Qualität
- Security First (Brakeman, OWASP Top 10)
- 100% Code Coverage für neuen Code
- Keine simplen Sicherheitsfehler

---

## 📋 9-Phasen Workflow

| Phase | Was | Wer entscheidet | Kritisch |
|-------|-----|-----------------|----------|
| **1. Anforderungen** | Rückfragen, Feature verstehen | Mensch ✅ | Bei inhaltlichen Änderungen immer fragen |
| **2. Gherkin** | Scenarios schreiben (EN) | Mensch reviewt ✅ | Verständnis-Check |
| **3. Visualisierung** | Diagramme, Mockups | Gemeinsam ✅ | Nur für größere Features |
| **4. Dokumentation** | Ablegen in docs/ | Agent | ⚠️ VOR Implementierung! |
| **5. Implementierung** | Code schreiben | Agent + Mensch ✅ | Dependencies, Performance, DB, Security |
| **6. Tests** | 100% Coverage | Agent | Unit + Integration + Gherkin |
| **7. Code Quality** | Linting | Agent | Nur neue Probleme beheben |
| **8. Feature-Index** | README aktualisieren | Agent | ⚠️ Sonst wird Feature nicht gefunden! |
| **9. Commit** | Git commit | Mensch gibt OK ✅ | Vor Push/PR |

---

## 🚨 Kritische Regeln (NIEMALS ohne Mensch)

### Dependencies
- ❌ Keine neuen Gems/Packages ohne Zustimmung
- ❌ Gemfile/package.json nicht ändern
- ✅ Research: Ruby Toolbox, Aktualität, Security
- ✅ Variante OHNE Dependency vorschlagen

### Database
- ❌ Keine Migrations ohne Review (vor & nach)
- ❌ Keine Spalten/Tabellen löschen
- ❌ Keine Daten-Migration ohne Plan
- ✅ Immer reversibel (up/down)
- ✅ Rollback-Strategie dokumentieren
- ✅ Zero-Downtime

### Security
- ❌ Keine Authorization-Änderungen ohne Review
- ❌ Niemals User-Input vertrauen
- ✅ Brakeman vor Commit
- ✅ Für jedes Feature: Wer darf zugreifen?
- ✅ OWASP Top 10 vermeiden

### Code Quality
- ❌ NIEMALS Linter-Konfigurationen ändern
- ❌ Keine bestehenden Probleme in unveränderten Dateien beheben
- ✅ Nur neue Probleme in geänderten Dateien

### Commits & Deployment
- ❌ Kein Push ohne Bestätigung
- ❌ Kein Force Push
- ❌ Kein Pull Request ohne OK
- ✅ Aussagekräftige Commit-Message
- ✅ Co-Authored-By: Claude

### Inhaltliche Änderungen
- ❌ Keine neuen Features ohne Abstimmung
- ❌ Keine Business-Logik-Änderungen
- ❌ Keine API-Änderungen
- ✅ Kleinigkeiten (Button-Text) eigenständig
- ✅ Bei Unklarheit: Lieber einmal zu viel fragen

---

## 📁 Dokumentationsstruktur

```
project/
├── docs/
│   ├── AGENTS.md                    # ✅ Immer lesen
│   ├── GLOSSARY.md                  # ✅ Immer lesen
│   │
│   ├── architecture/
│   │   ├── README.md                # ⭐ Index (immer lesen)
│   │   ├── system-overview.md       # Bei Bedarf
│   │   ├── data-flow.md             # Bei Bedarf
│   │   └── decisions/               # ADRs (nur relevante)
│   │
│   ├── features/
│   │   ├── README.md                # ⭐ Index (immer lesen)
│   │   └── [feature-name]/
│   │       ├── README.md            # Feature-Übersicht
│   │       ├── feature.gherkin      # Scenarios (EN)
│   │       ├── flow.md              # Mermaid Flow
│   │       ├── sequence.md          # Mermaid Sequence
│   │       └── ui-mockup.md         # ASCII Mockups
│   │
│   └── templates/                   # Vorlagen
```

**⭐ = Index-Datei**: Immer zuerst lesen für token-effiziente Suche!

---

## 🎨 Visualisierungstypen

| Typ | Tool | Wofür | Beispiel |
|-----|------|-------|----------|
| **User Flow** | Mermaid Graph | Nutzer-Interaktionen | Login-Flow |
| **Sequence** | Mermaid Sequence | API/Service-Interaktionen | Auth-Service Calls |
| **State Machine** | Mermaid State | Zustandsübergänge | Order Status |
| **UI Mockup** | ASCII-Art | Layout/Interface | Login-Page, Dashboard |
| **Architecture** | Mermaid Graph | System-Komponenten | High-Level System |

---

## 🔍 Token-effiziente Suche für AI

```
1. docs/features/README.md lesen
   → Welche Features sind relevant?

2. docs/features/[name]/README.md lesen
   → Feature-Übersicht

3. Bei Bedarf Diagramme lesen
   → flow.md, sequence.md, ui-mockup.md

4. docs/architecture/README.md lesen
   → System-Übersicht

5. Nur relevante ADRs lesen
   → docs/architecture/decisions/
```

**Ergebnis**: 3-5 Dateien statt 20+ → ~84% Token-Einsparung!

---

## ✅ Checklisten

### Für neue Features

- [ ] Anforderungen geklärt (Rückfragen gestellt)
- [ ] Inhaltliche Änderungen abgestimmt
- [ ] Gherkin-Scenarios geschrieben (EN)
- [ ] Visualisierungen erstellt (bei größeren Features)
- [ ] Dokumentation abgelegt (VOR Implementierung)
- [ ] Dependencies geprüft (Alternative ohne?)
- [ ] Performance-Strategie (Async bei >2s?)
- [ ] Security gecheckt (Wer darf zugreifen?)
- [ ] Implementierung abgeschlossen
- [ ] 100% Code Coverage erreicht
- [ ] Linter passed (nur neue Probleme)
- [ ] Brakeman/Security-Scan passed
- [ ] Feature-Index aktualisiert
- [ ] Commit erstellt
- [ ] Mensch hat OK gegeben

### Für Database Migrations

- [ ] Migration ist reversibel (up/down)
- [ ] Rollback-Strategie dokumentiert
- [ ] Zero-Downtime kompatibel
- [ ] Keine Daten gehen verloren
- [ ] Mensch hat Migration-Code reviewed
- [ ] Mensch hat OK gegeben
- [ ] OPS-Team informiert (falls nötig)
- [ ] Nach Migration: Mensch hat Ergebnis geprüft

### Für Security-Features

- [ ] Input Validation implementiert
- [ ] Authorization gecheckt (wer darf was?)
- [ ] Parameterized Queries (SQL Injection)
- [ ] Output Escaping (XSS)
- [ ] CSRF Protection (Forms)
- [ ] File Upload Validation
- [ ] Brakeman scan passed
- [ ] Keine Secrets in Logs
- [ ] Mensch hat Security reviewed

---

## 🤝 Mensch-AI Zusammenarbeit

### Was AI eigenständig kann:
- Kleinere Formulierungen (Button-Text)
- Code-Struktur/Refactoring (ohne Verhaltensänderung)
- Linting (neue Probleme in geänderten Dateien)
- Tests schreiben
- Dokumentation ablegen
- Feature-Index aktualisieren

### Was AI mit Mensch abstimmen muss:
- Neue Features
- Business-Logik-Änderungen
- Datenmodell-Änderungen
- API-Änderungen
- Dependencies hinzufügen
- Performance-Architektur
- Database Migrations
- Security-Änderungen
- Commits pushen

### Was AI NIEMALS alleine macht:
- Linter-Konfigurationen ändern
- Migrations ausführen
- Daten löschen
- Production-Deployments
- Force Push
- Secrets/Credentials ändern

---

## 📊 Erfolgskriterien

Ein Feature ist fertig, wenn:
- ✅ Gherkin-Scenarios existieren und passen
- ✅ Visualisierungen abgestimmt sind
- ✅ Dokumentation vollständig in docs/ liegt
- ✅ Feature-Index aktualisiert ist
- ✅ 100% Code Coverage erreicht ist
- ✅ Alle Tests (Unit + Integration + Gherkin) grün sind
- ✅ Linter passed
- ✅ Brakeman/Security-Scan passed
- ✅ Mensch hat reviewed und OK gegeben
- ✅ Commit erstellt (wartet auf Push-Bestätigung)

---

## 🎓 Lernende Dokumentation

### ADRs für wichtige Erkenntnisse
Wenn der Agent wichtige Patterns lernt:
- Security-Patterns → ADR dokumentieren
- Performance-Patterns → ADR dokumentieren
- Architektur-Entscheidungen → ADR dokumentieren

**Immer vom Menschen reviewen lassen!**

---

## 📚 Weitere Ressourcen

- **Gherkin**: https://cucumber.io/docs/gherkin/reference/
- **Mermaid**: https://mermaid.js.org/
- **ADRs**: https://adr.github.io/
- **OWASP Top 10**: https://owasp.org/Top10/
- **Ruby Toolbox**: https://www.ruby-toolbox.com/

---

## 💡 Zusammenfassung in einem Satz

**"Gemeinsam planen (Gherkin + Visualisierung), strukturiert dokumentieren (Index-basiert), sicher implementieren (Security + 100% Coverage), immer abstimmen (inhaltliche Änderungen), und der Mensch gibt das finale OK."**

---

_Erstellt: 2024-01-18_
_Für: Effektive Mensch-AI-Zusammenarbeit in der Softwareentwicklung_

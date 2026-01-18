# ADR-002: Dokumentationsstruktur

## Status
**Accepted**

## Date
2026-01-18

## Context

### Problem Statement
- Dokumentation ist oft verstreut oder nicht auffindbar
- AI-Agenten verschwenden Tokens beim Suchen nach relevanten Informationen
- Keine klare Struktur für Feature-Dokumentation
- Diagramme und Mockups gehen im Chat verloren

### Requirements
- Zentrale, auffindbare Dokumentation
- Token-effiziente Navigation für AI-Agenten
- Lebende Dokumentation neben dem Code
- Klare Ablageorte für verschiedene Artefakte

---

## Decision

**Wir verwenden eine hierarchische Dokumentationsstruktur in `docs/` mit Index-Dateien für schnelle Navigation.**

### Rationale
- Index-Dateien (README.md) ermöglichen schnelles Auffinden
- Feature-Ordner bündeln alle Artefakte eines Features
- Trennung von Architektur-Entscheidungen und Feature-Dokumentation
- Templates sorgen für Konsistenz

---

## Options Considered

### Option 1: Wiki-basierte Dokumentation
**Description:** Externe Wiki-Plattform (Notion, Confluence)

**Pros:**
- Bessere Formatierung
- Kollaborative Bearbeitung

**Cons:**
- Nicht im Repository
- Sync-Probleme mit Code
- AI-Agenten haben keinen direkten Zugriff

---

### Option 2: Flache Markdown-Struktur
**Description:** Alle Docs im Root-Verzeichnis

**Pros:**
- Einfach
- Wenig Overhead

**Cons:**
- Wird schnell unübersichtlich
- Keine logische Gruppierung
- Schwer zu navigieren

---

### Option 3: Hierarchische docs/-Struktur ✅
**Description:** Strukturierte Ordner mit Index-Dateien

**Pros:**
- Logische Gruppierung
- Token-effizient durch Indizes
- Versioniert mit Code
- Skaliert gut

**Cons:**
- Initiale Einrichtung nötig
- Pflege der Index-Dateien

---

## Consequences

### Positive
- AI-Agenten finden relevante Docs schnell
- Features sind vollständig dokumentiert
- Diagramme und Mockups bleiben erhalten
- Architektur-Entscheidungen sind nachvollziehbar

### Negative
- Index-Dateien müssen gepflegt werden
- Mehr Dateien im Repository

---

## Implementation

### Verzeichnisstruktur
```
docs/
├── GLOSSARY.md              # Domänensprache
├── SUMMARY.md               # Übersicht
├── features/
│   ├── README.md            # Feature-Index (Pflichtlektüre!)
│   ├── authentication.feature
│   ├── posts.feature
│   └── [feature-name]/      # Feature-Ordner (optional)
│       ├── README.md        # Feature-Übersicht
│       ├── flow.md          # Mermaid User Flow
│       ├── sequence.md      # Sequenzdiagramm
│       └── ui-mockup.md     # ASCII-Mockups
├── architecture/
│   ├── README.md            # Architektur-Übersicht
│   └── decisions/
│       ├── TEMPLATE.md
│       └── 001-*.md         # ADRs
└── templates/               # Vorlagen
    ├── feature-template.md
    └── ui-mockup-template.md
```

### Navigation für AI-Agenten
1. **Start:** `docs/features/README.md` (Feature-Index)
2. **Architektur:** `docs/architecture/README.md`
3. **Begriffe:** `docs/GLOSSARY.md`
4. **Nur bei Bedarf:** Spezifische Feature-Ordner oder ADRs

### Pflichtlektüre bei jedem Feature
- `AGENTS.md` - Workflow
- `docs/GLOSSARY.md` - Begriffe
- `docs/features/README.md` - Feature-Übersicht

---

## References
- AGENTS.md - Workflow-Dokumentation
- [Architecture Decision Records](https://adr.github.io/)

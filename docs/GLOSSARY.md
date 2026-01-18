# Projekt-Glossar

## Übersicht
Dieses Glossar definiert die Domänensprache für dieses Projekt. Es wird sowohl von Menschen als auch von KI-Agenten gepflegt und genutzt.

**Wichtig:**
- Verwende diese Begriffe konsistent in Code, Dokumentation und Kommunikation
- Das Glossar darf sowohl **deutsche** als auch **englische** Begriffe enthalten
- Bei mehrsprachigen Begriffen bitte beide Varianten angeben

---

## Allgemeine Begriffe

### Agent
**Definition:** Ein KI-System (z.B. Claude), das eigenständig Aufgaben im Projekt ausführt.

**Verwendung:** "Der Agent hat das Feature implementiert"

---

### Gherkin-Scenario
**Definition:** Eine strukturierte Beschreibung einer Funktionalität im Given-When-Then-Format.

**Verwendung:** "Bitte erstelle ein Gherkin-Scenario für den Login-Flow"

**Siehe auch:** Feature, Scenario

---

## Domänenspezifische Begriffe

_Hier projektspezifische Begriffe ergänzen_

### Beispiel: Benutzer
**Definition:** Eine Person, die das System nutzt

**Typen:**
- **Admin:** Benutzer mit vollen Rechten
- **Standard-Benutzer:** Benutzer mit eingeschränkten Rechten

**Verwendung:** "Der Benutzer muss eingeloggt sein"

**Englisch:** User

---

### Beispiel: Feature
**Definition:** Eine abgeschlossene Funktionalität des Systems

**Verwendung:** "Das Export-Feature ist fertig implementiert"

**Siehe auch:** Gherkin-Scenario

---

## Technische Begriffe

_Hier technische Begriffe ergänzen_

### Beispiel: Repository
**Definition:** Ein Git-Repository, das den Projekt-Code enthält

**Verwendung:** "Bitte pushe die Änderungen ins Repository"

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

**Englisch:** (optional) Englischer Begriff

**Siehe auch:** (optional) Verwandte Begriffe
```

---

## Änderungshistorie

| Datum | Geändert von | Änderung |
|-------|--------------|----------|
| _Datum_ | _Mensch/Agent_ | _Beschreibung_ |

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

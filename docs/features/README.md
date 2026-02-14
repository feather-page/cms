# Features Index

## Zweck
Diese Datei bietet einen schnellen Überblick über alle Cucumber Features im Projekt. Die `.feature` Dateien dienen sowohl als ausführbare Spezifikationen als auch als Dokumentation.

---

## Übersicht aller Features

| Feature | Beschreibung | Datei |
|---------|--------------|-------|
| Authentication | Login, Logout, Token-basierte Authentifizierung | `authentication.feature` |
| Site Management | Erstellen und Verwalten von Websites | `site_management.feature` |
| Posts | Blog-Posts erstellen, bearbeiten, veröffentlichen | `posts.feature` |
| Pages | Statische Seiten verwalten | `pages.feature` |
| Books | Buchkatalog verwalten | `books.feature` |
| Book Reviews | Buchrezensionen mit Sterne-Bewertung | `book_reviews.feature` |
| Book Block | Bücher aus Katalog in Posts einbetten | `book_block.feature` |
| Projects | Entwicklungsprojekte für Portfolio-Websites verwalten | `projects/feature.gherkin` |
| Hugo Multi-Theme | Hugo-basierte Multi-Theme Unterstützung für statische Sites | `hugo-multi-theme/README.md` |

---

## Features nach Kategorie

### Authentication & Authorization
- [authentication.feature](authentication.feature) - Login, Logout, Token-Management

### Content Management
- [posts.feature](posts.feature) - Blog-Posts
- [pages.feature](pages.feature) - Statische Seiten
- [books.feature](books.feature) - Buchkatalog
- [book_reviews.feature](book_reviews.feature) - Buchrezensionen
- [book_block.feature](book_block.feature) - Bücher in Posts einbetten
- [projects/feature.gherkin](projects/feature.gherkin) - Entwicklungsprojekte für Portfolio

### Site Administration
- [site_management.feature](site_management.feature) - Website-Verwaltung

---

## Cucumber ausführen

```bash
# Alle Features ausführen
bundle exec cucumber

# Einzelnes Feature ausführen
bundle exec cucumber docs/features/posts.feature

# Nur JavaScript-Tests
bundle exec cucumber --tags "@javascript"

# Ohne JavaScript-Tests
bundle exec cucumber --tags "not @javascript"
```

---

## Projektstruktur

```
docs/features/           # Gherkin Feature-Dateien
features/
├── step_definitions/    # Ruby Step-Implementierungen
└── support/             # Cucumber-Konfiguration & Helpers
```

---

## Neues Feature hinzufügen

1. Erstelle eine neue `.feature` Datei in `docs/features/`
2. Implementiere Step Definitions in `features/step_definitions/`
3. Aktualisiere diesen Index

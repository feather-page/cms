# Glossar

Domänensprache von Meerkat CMS. Begriffe, die hier definiert sind, werden im Code,
in Specs und in Commit-Messages genau so verwendet.

Index-Datei im Sinne von [ADR-002](architecture/decisions/002-documentation-structure.md) —
vor der Arbeit an einem Feature lesen.

---

## Inhalt

**Site**:
Die Website einer Nutzerin, bestehend aus Posts, Pages, Projects und Books.
Eine Site ist die Einheit, die exportiert und veröffentlicht wird.

**Post**:
Ein datierter Beitrag. Erscheint chronologisch auf der Startseite.
Ein Post darf keinen Slug haben — dann wird er über seine Public ID adressiert.

**Page**:
Eine undatierte Seite. Hat immer einen Slug. Die Page mit dem Slug `/` ist die Startseite.

**Project**:
Ein Portfolio-Eintrag. Lebt im eigenen Adressraum unter `projects/` und darf
deshalb denselben Slug tragen wie ein Post oder eine Page.

**Block**:
Eine Inhaltseinheit innerhalb eines Posts, einer Page oder eines Projects
(Absatz, Bild, Zitat, Buch, Tabelle …). Blocks sind die Speicherform des Editors.

**Variante**:
Eine Größen- und Format-Ausprägung eines Bildes, z. B. `mobile_x1_webp`.
Jedes Bild existiert in genau den Varianten aus `Image::Variants`.

---

## Adressierung

**Slug**:
Die von der Nutzerin gewählte Adresskomponente eines Inhalts. Beginnt immer mit
einem Schrägstrich (`/ueber-mich`). Bei Posts optional, bei Pages und Projects verpflichtend.

**Reservierter Präfix**:
Eine Adresskomponente, die die Site selbst erzeugt (`images/`, `posts/`, `projects/`,
`page/`, `feed.xml`, `robots.txt`, `sitemap.xml`) und die deshalb nicht als Slug
vergeben werden darf.

**Site-Root**:
Das Präfix, unter dem die internen Links einer Site aufgelöst werden — `/` für eine
Deployed Site, `/preview/<public-id>/` für einen Preview.
_Vermeiden_: base_url

**Kanonische URL**:
Die absolute, extern auflösbare Adresse einer Site (`https://beispiel.de/`). Wird für
Artefakte gebraucht, die außerhalb der Site gelesen werden: RSS-Feed, Sitemap, robots.txt.
Nicht zu verwechseln mit dem Site-Root — beim Preview fallen beide zufällig zusammen,
bei einer Deployed Site nicht.
_Vermeiden_: base_url

**Artefakt**:
Eine generierte Datei der Site, die keinem Inhalt entspricht: `feed.xml`, `robots.txt`,
`sitemap.xml`. Artefakte sind adressierbar, aber nicht editierbar.

---

## Veröffentlichung

**Deployment Target**:
Eine Adresse samt Zugangsdaten, unter der eine Site veröffentlicht wird. Eine Site kann
mehrere haben (Staging, Produktion, Backup).

**Preview**:
Die vom CMS live gerenderte Ansicht einer Site unter `/preview/<deployment-target>/`.
Zeigt denselben Inhalt wie die Deployed Site, aber ohne Export, ohne Verzögerung und
unter einer anderen Adresse.
_Vermeiden_: Staging (das ist ein Typ von Deployment Target, keine Ansicht)

**Deployed Site**:
Die exportierte, statische Kopie einer Site, ausgeliefert unter der `public_hostname`
ihres Deployment Targets. Auch ein Staging-Target hat eine Deployed Site.
_Vermeiden_: Live-Site, Staging-Site

**Export**:
Der Vorgang, der eine Site als Dateien in ein Verzeichnis schreibt.
Erzeugt Inhalte, Bildvarianten und Artefakte.

**Deploy**:
Der Vorgang, der die exportierten Dateien zum Deployment Target überträgt.
Läuft pro Target serialisiert — ein Target deployt nie zweimal gleichzeitig.

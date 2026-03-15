# frozen_string_literal: true

class EmptyStateComponentPreview < Lookbook::Preview
  # @label Icon Mode (default)
  def icon_default
    render EmptyStateComponent.new(icon: "files", message: "No documents found.")
  end

  # @label Icon with Action
  def icon_with_action
    render EmptyStateComponent.new(
      icon: "file-plus",
      message: "You haven't created any posts yet.",
      action_label: "Create Post",
      action_href: "#"
    )
  end

  # @label Emoji: Posts
  def emoji_posts
    render EmptyStateComponent.new(
      emoji: "✏️",
      message: "Noch keine Blogposts",
      subtitle: "Schreibe deinen ersten Post und teile ihn mit der Welt.",
      action_label: "Neuer Post",
      action_href: "#"
    )
  end

  # @label Emoji: Books
  def emoji_books
    render EmptyStateComponent.new(
      emoji: "📚",
      message: "Dein Bücherregal ist leer",
      subtitle: "Füge dein erstes Buch hinzu.",
      action_label: "Neues Buch",
      action_href: "#"
    )
  end

  # @label Emoji: Pages
  def emoji_pages
    render EmptyStateComponent.new(
      emoji: "📄",
      message: "Keine Seiten vorhanden",
      subtitle: "Erstelle Seiten wie Impressum, About oder Kontakt.",
      action_label: "Neue Seite",
      action_href: "#"
    )
  end

  # @label Emoji: Projects
  def emoji_projects
    render EmptyStateComponent.new(
      emoji: "🏗️",
      message: "Keine Projekte",
      subtitle: "Zeige deine Arbeit und Projekte.",
      action_label: "Neues Projekt",
      action_href: "#"
    )
  end

  # @label Emoji: Invitations
  def emoji_invitations
    render EmptyStateComponent.new(
      emoji: "✉️",
      message: "Keine ausstehenden Einladungen",
      subtitle: "Lade weitere Nutzer ein, um an deiner Seite mitzuarbeiten.",
      action_label: "Einladen",
      action_href: "#"
    )
  end
end

defmodule FeatherWeb.ConfirmHelpers do
  @moduledoc """
  Drives the shared confirmation dialog (setzkasten's `confirm_dialog/1`,
  rendered once by `FeatherWeb.Layouts.app/1`) in LiveView tests.

  A delete trigger does not send its event: its `phx-click` writes the
  question into the dialog `#confirm-delete`, parks the destructive command
  on the dialog's confirm button and opens it, all in the browser.
  `confirm_click/3` checks those commands and then sends the parked event,
  as a click on the confirm button would; `asked/2` returns what the dialog
  would show without confirming.
  """
  import ExUnit.Assertions
  import Phoenix.LiveViewTest

  @dialog "confirm-delete"

  @doc """
  Clicks the trigger `selector`, asserts that it opens the dialog (with
  `question` when given) and confirms: renders the parked event.
  Returns what `render_click/3` returns (HTML or a redirect error tuple).
  """
  def confirm_click(view, selector, question \\ nil) do
    asked = asked(view, selector)
    if question, do: assert(asked.question == question)
    assert has_element?(view, "dialog##{@dialog} ##{@dialog}-confirm")

    case asked.action do
      [["push", %{"event" => event} = push]] ->
        view
        |> with_target(push["target"])
        |> render_click(event, push["value"] || %{})

      other ->
        flunk("expected the dialog to park one push, got: #{inspect(other)}")
    end
  end

  @doc """
  The dialog texts and the parked command of the trigger `selector`:
  `%{question:, text:, label:, action:}` (`label` is nil for the dialog's
  own "Delete"). Fails if the trigger pushes an event itself.
  """
  def asked(view, selector) do
    ops = view |> element(selector) |> render() |> click_ops(selector)

    refute Enum.any?(ops, &match?(["push", _], &1)),
           "#{selector} pushes an event itself instead of leaving it to the dialog"

    action =
      Enum.find_value(ops, fn
        [
          "set_attr",
          %{"attr" => ["data-confirm-action", json], "to" => "#" <> @dialog <> "-confirm"}
        ] ->
          Jason.decode!(json)

        _ ->
          nil
      end) || flunk("#{selector} does not park a command on the confirm dialog")

    texts =
      Enum.find_value(ops, fn
        ["dispatch", %{"event" => "setzkasten:show-modal", "to" => "#" <> @dialog} = op] ->
          op["detail"]["text"]

        _ ->
          nil
      end) || flunk("#{selector} does not open the confirm dialog")

    %{
      question: texts["##{@dialog}-title"],
      text: texts["##{@dialog}-text"],
      label: texts["##{@dialog}-confirm-label"],
      action: action
    }
  end

  defp click_ops(html, selector) do
    case html |> LazyHTML.from_fragment() |> LazyHTML.attribute("phx-click") do
      [json | _] -> Jason.decode!(json)
      [] -> flunk("#{selector} has no phx-click")
    end
  end
end

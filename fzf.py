from textual.app import App, ComposeResult
from textual.containers import Container
from textual.widgets import Input, ListView, ListItem, Label
from textual.reactive import reactive
from textual import events
import difflib


class FuzzyItem(ListItem):
    """A custom list item for the fuzzy finder."""

    def __init__(self, text: str):
        super().__init__()
        self.text = text

    def compose(self) -> ComposeResult:
        yield Label(self.text)


class FuzzyFinder(Container):
    """A fuzzy finder component similar to fzf."""

    items = reactive([])
    filtered_items = reactive([])
    query = reactive("")

    def __init__(self, items: list[str]):
        super().__init__()
        self.items = items
        self.filtered_items = items.copy()

    def compose(self) -> ComposeResult:
        yield Input(placeholder="Search...", id="search-input")
        yield ListView(id="results-list")

    def on_mount(self) -> None:
        """Called when the component is mounted."""
        self.update_list()

    def watch_query(self, query: str) -> None:
        """Called when the query changes."""
        if not query:
            self.filtered_items = self.items.copy()
        else:
            # Use difflib for fuzzy matching (similar to what fzf does)
            self.filtered_items = [
                item for item in self.items if self.fuzzy_match(query, item)
            ]

            # Sort by match quality
            self.filtered_items.sort(
                key=lambda item: difflib.SequenceMatcher(None, query, item).ratio(),
                reverse=True,
            )

        self.update_list()

    def fuzzy_match(self, query: str, item: str) -> bool:
        """Check if the query fuzzy matches the item."""
        query = query.lower()
        item_lower = item.lower()

        # Simple character-by-character matching
        item_idx = 0
        for char in query:
            item_idx = item_lower.find(char, item_idx)
            if item_idx == -1:
                return False
            item_idx += 1
        return True

    def update_list(self) -> None:
        """Update the list view with filtered items."""
        list_view = self.query_one("#results-list", ListView)
        list_view.clear()

        for item in self.filtered_items:
            list_view.append(FuzzyItem(item))

    def on_input_changed(self, event: Input.Changed) -> None:
        """Called when the input changes."""
        self.query = event.value

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        """Called when a list item is selected."""
        selected_item = self.filtered_items[event.index]
        self.post_message(FuzzyFinder.Selected(selected_item))

    class Selected(events.Message):
        """Event sent when an item is selected."""

        def __init__(self, item: str):
            self.item = item
            super().__init__()


class FuzzyFinderApp(App):
    """Example application using the FuzzyFinder component."""

    CSS = """
    FuzzyFinder {
        width: 100%;
        height: 100%;
        border: solid green;
        padding: 1;
    }
    
    Input {
        dock: top;
        margin-bottom: 1;
    }
    
    ListView {
        height: 1fr;
        border: solid blue;
    }
    
    FuzzyItem {
    }
    
    FuzzyItem:hover {
        background: $accent-darken-2;
    }
    """

    def __init__(self):
        super().__init__()
        # Example list of items
        self.items = [
            "apple",
            "banana",
            "cherry",
            "date",
            "elderberry",
            "fig",
            "grape",
            "honeydew",
            "kiwi",
            "lemon",
            "mango",
            "nectarine",
            "orange",
            "pear",
            "quince",
            "raspberry",
            "strawberry",
            "tangerine",
            "watermelon",
        ]

    def compose(self) -> ComposeResult:
        yield FuzzyFinder(self.items)

    def on_fuzzy_finder_selected(self, event: FuzzyFinder.Selected) -> None:
        """Called when an item is selected in the fuzzy finder."""
        self.exit(event.item)


if __name__ == "__main__":
    app = FuzzyFinderApp()
    result = app.run()
    print(f"Selected: {result}")

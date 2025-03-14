import subprocess
import sys
from pathlib import Path

from rich.syntax import Syntax
from rich.traceback import Traceback

from textual.app import App, ComposeResult
from textual.containers import Container, Vertical
from textual.reactive import reactive
from textual.widgets import DirectoryTree, Footer, Header, Static


FILES_HOME = Path("/mnt/c/Users/tomco/OneDrive")
SCANS_INBOX = FILES_HOME / "Documents/Scans"
SCAN_DEST_1 = FILES_HOME / "Money"
SCAN_DEST_2 = FILES_HOME / "IncomeTax"


class ScanOrganizer(App):
    """Scan file organizer"""

    CSS_PATH = "styles.tcss"
    BINDINGS = [
        ("o", "open_pdf", "Open PDF"),
        ("f", "toggle_files", "Toggle Files"),
        ("q", "quit", "Quit"),
    ]

    dest_path: reactive[str | None] = reactive(str(SCAN_DEST_1))

    def watch_show_tree(self, show_tree: bool) -> None:
        """Called when show_tree is modified."""
        self.set_class(show_tree, "-show-tree")

    def compose(self) -> ComposeResult:
        """Compose our UI."""
        path = "./" if len(sys.argv) < 2 else sys.argv[1]
        yield Header()
        with Container():
            with Vertical():
                yield DirectoryTree(str(SCANS_INBOX), id="scans-inbox")
                yield DirectoryTree(str(SCAN_DEST_1), id="scan-dest-1")
                yield DirectoryTree(str(SCAN_DEST_2), id="scan-dest-2")
            with Vertical():
                yield DirectoryTree(self.dest_path, id="scan-dest")
        yield Footer()

    def on_mount(self) -> None:
        self.query_one("#scan-dest-1").focus()

        def theme_change(_signal) -> None:
            """Force the syntax to use a different theme."""
            self.watch_path(self.dest_path)

        self.theme_changed_signal.subscribe(self, theme_change)

    def on_directory_tree_file_selected(
        self, event: DirectoryTree.FileSelected
    ) -> None:
        """Called when the user selects a file in a scan-dest tree"""
        if event.path.is_file:
            self.dest_path = str(event.path)

    def watch_path(self, path: str | None) -> None:
        """Called when path changes."""
        code_view = self.query_one("#code", Static)
        if path is None:
            code_view.update("")
            return
        try:
            syntax = Syntax.from_path(
                path,
                line_numbers=True,
                word_wrap=False,
                indent_guides=True,
                theme="github-dark" if self.current_theme.dark else "github-light",
            )
        except Exception:
            code_view.update(Traceback(theme="github-dark", width=None))
            self.sub_title = "ERROR"
        else:
            code_view.update(syntax)
            self.query_one("#code-view").scroll_home(animate=False)
            self.sub_title = path

    def action_toggle_files(self) -> None:
        """Called in response to key binding."""
        self.show_tree = not self.show_tree

    def action_open_pdf(self) -> None:
        """Action to open the selected file with wslview in the focused DirectoryTree."""
        # Find the currently focused DirectoryTree widget
        focused_widget = self.focused

        # Check if a DirectoryTree is focused
        if isinstance(focused_widget, DirectoryTree):
            directory_tree = focused_widget
            selected_node = directory_tree.cursor_node

            # Check if a node is selected
            if selected_node is not None:
                # Get the path of the selected node
                selected_path = directory_tree.cursor_node.data.path

                # Only try to open if it's a file, not a directory
                if selected_path.is_file():
                    try:
                        # Call wslview with the selected file path
                        subprocess.run(["wslview", str(selected_path)], check=True)
                        self.notify(f"Opening {selected_path.name} with wslview")
                    except subprocess.CalledProcessError as e:
                        self.notify(f"Error opening file: {e}", severity="error")
                    except FileNotFoundError:
                        self.notify("wslview command not found", severity="error")
                else:
                    self.notify(
                        "Cannot open directories with wslview", severity="warning"
                    )
            else:
                self.notify("No file selected", severity="warning")
        else:
            self.notify("No DirectoryTree is currently focused", severity="warning")


if __name__ == "__main__":
    ScanOrganizer().run()

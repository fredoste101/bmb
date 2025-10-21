BookMarkBook, or bmb for short,
will be a plugin to help with bookmarks in vim.


Idea is to create a hierarchical bookmark-book,
which can be browsed (or accessed quickly through commands).


Each bookmark should have its own litte description.

Bookmarks will be hard coded (I.E file and line),
but there will be functions to detect when a bookmark no longer point to
the same piece of text as previous.

This allows us (hopefully) to update bookmarks when changes occurs in text (code).



--- Architecture ---
bmb will save the bookmarks into a JSON-file,
which can then be read and parsed.


--- Usage ---
How to create bookmark?
How to change bookmark?
How to add information about bookmark?
How to change inforamtion about a bookmark?

How to hierachy?
How to create a directory?
How to add bookmark to directory?
How to add directory to directory?

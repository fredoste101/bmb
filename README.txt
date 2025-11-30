=== BMB ===

BookMarkBook, or bmb for short,
will be a plugin to help with bookmarks in vim.

--- Introduction ---
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


--- TODO ---
Change bookmark manually
	Change line and file

	Change directory

	Duplicate bookmark? Could be nice if several domains/directories
	refer to the same thing

	Change info within the file

	Remove bookmark

Change directory manually
	Add a subdir

	move directory

	retmove directory


add signs where bookmarks are


Killer feature: autochange bookmarks
	Change bookmarks depending on line-content if file changes
	
	Allow for notifications if this change cannot happen due to
		Could not find suitable change
	
		File no longer exists

Get a little popup with preview of bookmark

	

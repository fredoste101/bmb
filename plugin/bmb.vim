
"Current bookmark ID that we can use to move/or alter bookmark
let g:BMB_currentBookmarkId = -1

"What BMB-state are we in? Are we trying to create a new bookmark?
"Are we altering abookmark, deleting, adding info, moving, etc etc...

"0 - Means we are not initialized at all. nothing will work
"1 - We have initialized, either by init from existing or creating a new. Now
"    we can start doing stuff

let s:BMB_state = 0 

"Next ID to use when creating a new bookmark
let g:BMB_nextBookmarkId = -1

let g:BMB_nextDirId = -1

"The actual bookmark book
let g:BMB_bookMarkBook = v:none

let g:BMB_autoSave = v:false

"The current filename of the file to write/read bookmarks to/from
let g:BMB_fileName = v:none


"All previously visited bookmarks. This can be used to go quickly to a
"previous place is my thinking... Lets see if it be smart of nah
let g:BMB_previousBookMarksVisited = []


let s:BMB_rootIndex = 0


function! BMB_createBook(fileName, name, baseDir)
	"Create a bookmark book with name, save in fileName.
	"baseDir is to keep track of paths in some sort of fashion. lets see
	"how it plays out

	let g:BMB_nextBookmarkId = 0
	let g:BMB_nextDirId 	 = 1

	let g:BMB_bookMarkBook = {
					\"name":	   a:name,
					\"created":	   localtime(), 
					\"modified":	   localtime(),
					\"basedir":	   a:baseDir,
					\"bookmarkDict":   {},
					\"dirDict":	   {},
					\"nextBookmarkId": g:BMB_nextBookmarkId,
					\"nextDirId":	   g:BMB_nextDirId
				\} 	

	let rootNode = 	 {
				\"name":"root", 
				\"bookmarkIdList":[], 
				\"dirIdList":[], 
				\"info":"", 
				\"created":localtime(),
				\"modified":localtime(),
			\}


	let g:BMB_bookMarkBook["dirDict"][string(s:BMB_rootIndex)] = rootNode

	let jsonString = json_encode(g:BMB_bookMarkBook)	

	call writefile([jsonString], a:fileName)

	"We have our file
	let g:BMB_fileName 	= a:fileName
	let s:BMB_state 	= 1 

endfunction


function! BMB_init(bookMarkFile)
	"Initialize the bookmark-book :)
	let g:BMB_fileName = a:bookMarkFile

	let lines = readfile(a:bookMarkFile)

	let jsonString = join(lines)

	let jsonObject = json_decode(jsonString)

	let g:BMB_bookMarkBook = jsonObject

	let g:BMB_nextBookmarkId = jsonObject["nextBookmarkId"]
	let g:BMB_nextDirId = jsonObject["nextDirId"]

	let s:BMB_state = 1 
endfunction


function! BMB_addBookmarkWithParent(parent)
	"Add bookmark at the current position
	"With parent as directory

	if s:BMB_state == 0
		echom "ERROR: must initialize BMB first"
		return	
	endif

	let curPos = getcurpos()

	let line   = curPos[1]

	let column = curPos[2]

	let string = getline(line) 

	"Now create the bookmark
	let bookmark = 	{
				\"id":g:BMB_nextBookmarkId, 
				\"file":@%,
				\"line":line,
				\"column":column,
				\"info":"",
				\"dirIdList":[string(a:parent)],
				\"string":string
			\} 

	let key = string(g:BMB_nextBookmarkId)

	"Link together the new bookmark with the dir it ends up in
	let g:BMB_bookMarkBook["bookmarkDict"][key] = bookmark

	call add(g:BMB_bookMarkBook["dirDict"][string(a:parent)]["bookmarkIdList"], bookmark["id"])

	"Increment the bookmarks
	let g:BMB_nextBookmarkId += 1

endfunction


function! BMB_addBookmark()
	"Add a bookmark in the root. To make it easy to add stuff quickly
	call BMB_addBookmarkWithParent(0)
endfunction


function! BMB_removeBookmark(id)
	"TODO


endfunction


function! BMB_removeDir(id)
	"TODO: this one is the most pain in ass. It needs to be recursively
	"deleted downwards, both dirs and bookmarks

endfunction


function! BMB_moveDir(id, newParent)
	"move directory into new parent-directory


endfunction


function! BMB_gotoBookmark(bookmarkId)
	"Jump to the given bookmarkId 
	if s:BMB_state == 0
		echom "ERROR: must be initialized first"
		return	
	endif	

	let bookmarkId = string(a:bookmarkId)

	if !has_key(g:BMB_bookMarkBook["bookmarkDict"], bookmarkId)
		echom "ERROR: bookmark with id: " . bookmarkId . " does not exist in the book"
		return
	endif

	let bookmark = g:BMB_bookMarkBook["bookmarkDict"][bookmarkId]

	"Go to bookmark
	execute("e +" . bookmark["line"] . " " . bookmark["file"])

	"Center the cursor
	execute("normal zz")

endfunction


function! BMB_addDir(parentId, name, info)
	"add directory to the bookmarks book
	
	let newDir = 	 {
				\"id":g:BMB_nextDirId,
				\"name":a:name, 
				\"bookmarkIdList":[], 
				\"dirIdList":[], 
				\"info":a:info, 
				\"created":localtime(),
				\"modified":localtime()
			\}

	"Add dir to the rest
	let g:BMB_bookMarkBook["dirDict"][string(g:BMB_nextDirId)] = newDir

	"Add the added dir to the parent dir :)
	call add(g:BMB_bookMarkBook["dirDict"][string(a:parentId)]["dirIdList"], g:BMB_nextDirId)

	let g:BMB_nextDirId += 1

endfunction


function! s:BMB_printBookmark(bookmark, line, indent)

	call setline(a:line, a:indent . string(a:bookmark["id"]) . " | " . a:bookmark["string"] . " | " . a:bookmark["info"])

endfunction


function! s:BMB_printFullDir(dir, startLine, indent)
	let lineNumber = a:startLine

	let dirSpecifierString = "[v] -"

	call setline(lineNumber, a:indent . dirSpecifierString . " " . a:dir["name"] . " | " . a:dir["info"])
	
	let lineNumber += 1

	for dirId in a:dir["dirIdList"]
		let subDir = g:BMB_bookMarkBook["dirDict"][string(dirId)]
		let lineNumber = s:BMB_printFullDir(subDir, lineNumber, a:indent . "  ")
	endfor

	for bookmarkId in a:dir["bookmarkIdList"]
		call s:BMB_printBookmark(g:BMB_bookMarkBook["bookmarkDict"][string(bookmarkId)], 
					 \lineNumber, 
					 \a:indent . "  ")
		let lineNumber += 1
	endfor

	return lineNumber
endfunction


function! BMB_openBuffer()
	"Open the BMB buffer to browse bookmarks 
	"This should be a special buffer then, whith special special
	
	if s:BMB_state == 0
		echom "ERROR: must initialize BMB first before opening special buffer"
		return	
	endif

	:enew

	setlocal filetype=bmb
	setlocal buftype=nofile


	"TODO: create the hierarchy. We can start by showing it all? and then
	"we do the hiding, unhiding as a second step :)

	let root = g:BMB_bookMarkBook["dirDict"][string(s:BMB_rootIndex)]

	call s:BMB_printFullDir(root, 1, "")


	setlocal nomodifiable
	setlocal readonly
	setlocal nowrap
	
endfunction




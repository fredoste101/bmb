
"Save all bufnr that we open with bmb so we can recreate teh state
"when going back... this is retarded but I don't know else what to do
let g:BMB_bufferDict = {} 

"What BMB-state are we in? Are we trying to create a new bookmark?
"Are we altering abookmark, deleting, adding info, moving, etc etc...

"0 - Means we are not initialized at all. nothing will work
"1 - We have initialized, either by init from existing or creating a new. Now
"    we can start doing stuff
let s:BMB_state = 0 


"If there is an pending operation to be done
"A pending operation is an operation started,
"waiting to be preformed by BMB_applyPendingOp
let g:BMB_pendingOpData = {"op":v:none}

"The actual bookmark book


let g:BMB_bookMarkBook = v:none

"The rendering depth-dict
let g:BMB_renderLineDepth = {} 

"TODO: use this to autosave at times. 
"I think it will be replaced by config in bookMarksBook
let g:BMB_autoSave = v:false

"All previously visited bookmarks. This can be used to go quickly to a
"previous place is my thinking... Lets see if it be smart of nah
let g:BMB_previousBookMarksVisited = []

let s:BMB_rootIndex = 0


function! BMB_createBook(fileName, name)
	"Create a bookmark book with name, save in fileName.
	"baseDir is to keep track of paths in some sort of fashion. 
	"lets see how it plays out

	"name: 		 Then name of the bmb
	"created: 	 timestamp when created
	"modified: 	 timestamp when modified
	"basedir: 	 base directory from which the rest of bookmarks depend on
	"	  	 per default: current working directory
	"bookmarkDict: 	 dictionary with all bookmarks
	"dirDict: 	 dictionary with dirs. Each dir contains refs to more dirs or
	"         	 bookmarks
	"nextBookmarkId: ID that a newly bookmark will get
	"nextDirId: 	 ID that a newly created dir will get
	let g:BMB_bookMarkBook = {
					\"name":	   a:name,
					\"created":	   localtime(), 
					\"modified":	   localtime(),
					\"basedir":	   getcwd(),
					\"bookmarkDict":   {},
					\"dirDict":	   {},
					\"nextBookmarkId": 0,
					\"nextDirId":	   1,
					\"fileName": 	   a:fileName
				\} 	

	let rootNode = 	 {
				\"id": 0,
				\"name":"root", 
				\"bookmarkIdList":[], 
				\"dirIdList":[], 
				\"info":"", 
				\"rendered":v:false,
				\"created":localtime(),
				\"modified":localtime(),
			\}

	let g:BMB_bookMarkBook["dirDict"][string(s:BMB_rootIndex)] = rootNode

	let jsonString = json_encode(g:BMB_bookMarkBook)	

	call writefile([jsonString], a:fileName)

	"We have our file
	let s:BMB_state 	= 1 

endfunction


function! BMB_saveBook()
	"Save the book
	if s:BMB_state == 0
		echoe "must initialize BMB first"
		return	
	endif
	
	call BMB_saveBookAs(g:BMB_bookMarkBook["fileName"])
endfunction


function! BMB_saveBookAs(fileName)
	"Save the book as fileName
	if s:BMB_state == 0
		echoe "must initialize BMB first"
		return	
	endif

	let g:BMB_bookMarkBook["fileName"] = a:fileName
	
	let jsonString = json_encode(g:BMB_bookMarkBook)	

	call writefile([jsonString], a:fileName)

endfunction


function! BMB_init(bookMarkFile)
	"Initialize the bookmark-book :)
	"With an existing one given by bookMarkFile
	call sign_unplace("bmb")
	sign define bmbSign text=B> texthl=Search

	let g:BMB_pendingOpData = {"op":v:none}

	let lines = readfile(a:bookMarkFile)

	let jsonString = join(lines)

	let jsonObject = json_decode(jsonString)

	let g:BMB_bookMarkBook = jsonObject

	let s:BMB_state = 1 

endfunction


function! BMB_addBookmarkWithParent(parent)
	"Add bookmark at the current position
	"With parent (id) as directory

	if s:BMB_state == 0
		echoe "must initialize BMB first"
		return	
	endif

	let curPos = getcurpos()

	let line   = curPos[1]

	let column = curPos[2]

	let string = getline(line) 

	"TODO: how is the file in comparison to baseDir in the bmbook?
	"TODO: also check that parent exists

	let nextBookmarkId = g:BMB_bookMarkBook["nextBookmarkId"] 
	"Now create the bookmark
	"id: the id of the bookmark. Should be unique
	"file: the file the bookmark is in
	"line: the line in the file
	"column: I don't think I use this yet...
	"name: If the bookmark needs a name...
	"info: some string explaining the bookmark
	"dirIdList: a list of all dirs this bookmark belongs to... future
	"	    proof they call it
	"string: the string that the bookmark points to
	"	 It should match file and line, but doesn't have to,
	"	 then we must change it or accept it (approval of new pos)
	let bookmark = 	{
				\"id": nextBookmarkId,
				\"file":@%,
				\"line":line,
				\"column":column,
				\"name":"",
				\"info":"",
				\"dirIdList":[a:parent],
				\"string":string
			\} 

	let key = string(nextBookmarkId)

	"Link together the new bookmark with the dir it ends up in
	let g:BMB_bookMarkBook["bookmarkDict"][key] = bookmark

	call add(g:BMB_bookMarkBook["dirDict"][string(a:parent)]["bookmarkIdList"], 
		 \bookmark["id"])

	"Increment the bookmarks
	let g:BMB_bookMarkBook["nextBookmarkId"] += 1

endfunction


function! BMB_addBookmark()
	"Add a bookmark in the root. To make it easy to add stuff quickly
	call BMB_addBookmarkWithParent(0)
endfunction


function! s:BMB_removeDir(dir, parentDir)
	"Remove dir. I.E remove all bookmarks in it,
	"and then remove all subdirs recursively in same manner
		


	for bookmarkId in a:dir["bookmarkIdList"]
		"Remove this dir from the bookmark.
		"why are we even here? just to suffer?
		let bookmark = g:BMB_bookMarkBook["bookmarkDict"][string(bookmarkId)]

		let indexToRemove = index(bookmark["dirIdList"], a:dir["id"])

		call remove(bookmark["dirIdList"], indexToRemove)	

		if len(bookmark["dirIdList"]) == 0
			"This bookmark was only in this dir. And this dir is going away. 
			"so bye bye bookmark

			"Remove any sign this bookmark has
			if bufexists(bookmark["file"])
				call sign_unplace("bmb", {'buffer' : bufnr(bookmark["file"]), 
					   		  \'id' : bookmark["id"] + 1})
			endif	

			call remove(g:BMB_bookMarkBook["bookmarkDict"], string(bookmarkId))	
		endif
	endfor

	for dirId in a:dir["dirIdList"]
		call s:BMB_removeDir(g:BMB_bookMarkBook["dirDict"][string(dirId)], a:dir)
	endfor

	"Remove this dir
	let indexToRemove = index(a:parentDir["dirIdList"], a:dir["id"])

	call remove(a:parentDir["dirIdList"], indexToRemove)

	call remove(g:BMB_bookMarkBook["dirDict"], string(a:dir["id"]))	

endfunction


function! BMB_removeInBook()
	let bookmark = s:BMB_getBookmarkInBook()

	let dir = s:BMB_getDirInBook()

	if type(bookmark) == 4 
		let v = confirm("Remove bookmark completly?:", "&Yes\n&No", 2)

		if v == 1
			for id in bookmark["dirIdList"]
				let dir = g:BMB_bookMarkBook["dirDict"][string(id)]

				let indexToRemove = index(dir["bookmarkIdList"], bookmark["id"])

				call remove(dir["bookmarkIdList"], indexToRemove)	
				
			endfor

			"Remove any sign this bookmark has
			if bufexists(bookmark["file"])
				call sign_unplace("bmb", {'buffer' : bufnr(bookmark["file"]), 
					   		  \'id' : bookmark["id"] + 1})
			endif	

			call remove(g:BMB_bookMarkBook["bookmarkDict"], string(bookmark["id"]))	

			let cp = getcurpos()

			call s:BMB_render()

			call setpos(".", cp)
		endif

	elseif type(dir) == 4

		"I don't want to remove root. That f-ing illegal!
		if dir["id"] != 0

			let v = confirm("Remove dir completly?:", "&Yes\n&No", 2)

			call BMB_gotoParentDirInBook()

			let parentDir = s:BMB_getDirInBook() 


			if v == 1

				call s:BMB_removeDir(dir, parentDir)	

				call s:BMB_render()
			endif
		endif

	
	endif


endfunction


function! BMB_gotoBookmark(bookmarkId)
	"Jump to the given bookmarkId 
	"echo "gotoBookmark"
	if s:BMB_state == 0
		echoe "bmb must be initialized first"
		return	
	endif	

	let bookmarkId = string(a:bookmarkId)

	if !has_key(g:BMB_bookMarkBook["bookmarkDict"], bookmarkId)
		echoe "bookmark with id: " . bookmarkId . " does not exist in the book"
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
	
	let dirId = g:BMB_bookMarkBook["nextDirId"]

	let newDir = 	 {
				\"id":		   dirId,
				\"name":	   a:name, 
				\"bookmarkIdList": [], 
				\"dirIdList":      [], 
				\"rendered":	   v:false,
				\"info":	   a:info, 
				\"created":        localtime(),
				\"modified":       localtime()
			\}

	"Add dir to the rest
	let g:BMB_bookMarkBook["dirDict"][string(dirId)] = newDir

	"Add the added dir to the parent dir :)
	call add(g:BMB_bookMarkBook["dirDict"][string(a:parentId)]["dirIdList"], dirId)

	let g:BMB_bookMarkBook["nextDirId"] += 1

endfunction


function! s:BMB_renderBookmark(bookmark, line, depth)

	let g:BMB_renderLineDepth[string(a:line)] = a:depth

	let indent = repeat("  ", a:depth)

	let g:BMB_bookMarkBook["renderedBookmarks"][string(a:line)] = a:bookmark["id"]

	let lineContent = trim(a:bookmark["string"])

	"TODO: also if content is less than 30, fill to 30
	if strlen(lineContent) > 30
		let lineContent = strcharpart(lineContent, 0, 30) 	
	endif

	call setline(a:line, 
		     \indent . string(a:bookmark["id"]) . 
		     \" | " . lineContent . " | " . a:bookmark["info"])

endfunction


function! s:BMB_renderDir(dir, startLine, depth)
	"TODO: must save the line numbers and such, in order to open.
	"How to handle closing and opening? that's a future problem
	
	let renderSubElements = has_key(a:dir,"rendered") && a:dir["rendered"]

	
	let g:BMB_renderLineDepth[string(a:startLine)] = a:depth
	
	let lineNumber = a:startLine

	let dirSpecifierString = "[>] -"

	if renderSubElements
		let dirSpecifierString = "[v] -"
	endif

	let indent = repeat("  ", a:depth)

	call setline(lineNumber, 
		     \indent . 
		     \dirSpecifierString . " " . a:dir["name"] . " | " . a:dir["info"])

	let g:BMB_bookMarkBook["renderedDirs"][string(lineNumber)] = a:dir
	
	let lineNumber += 1

	if !renderSubElements
		"Do not render the bookmarks for this dir if not rendered	
		return lineNumber
	end

	for dirId in a:dir["dirIdList"]
		let subDir = g:BMB_bookMarkBook["dirDict"][dirId]

		let lineNumber = s:BMB_renderDir(subDir, 
					         \lineNumber, 
						 \a:depth + 1)
	endfor

	for bookmarkId in a:dir["bookmarkIdList"]
		call s:BMB_renderBookmark(g:BMB_bookMarkBook["bookmarkDict"][string(bookmarkId)], 
					 \lineNumber, 
					 \a:depth + 1)
		let lineNumber += 1
	endfor

	return lineNumber
endfunction


function! s:BMB_openDir(dir)
	"Open the dir to be rendered. and then rerender
	let cp = getcurpos()

	let dir = a:dir 

	if has_key(dir, "rendered")
		if dir["rendered"]
			"echom "SET TO FALSE: " .. dir["name"]	
			let dir["rendered"] = v:false	
		else
			let dir["rendered"] = v:true	
		endif

	else
		let dir["rendered"] = v:true

	endif

	call s:BMB_render()

	call setpos(".", cp)
endfunction


function! BMB_openInBook()
	"Open either a bookmark (in current buffer)
	"Or open a directory for viewing
		
	let cp = getcurpos()

	let lineString = string(cp[1])

	if has_key(g:BMB_bookMarkBook["renderedBookmarks"], lineString)
		call BMB_gotoBookmark(g:BMB_bookMarkBook["renderedBookmarks"][lineString])

	elseif has_key(g:BMB_bookMarkBook["renderedDirs"], lineString)
		call s:BMB_openDir(g:BMB_bookMarkBook["renderedDirs"][lineString])
	endif

	
endfunction


function! BMB_changeInfoBookmark(id, info)
	let g:BMB_bookMarkBook["bookmarkDict"][string(a:id)]["info"] = a:info 
endfunction


function! BMB_changeInfoDir(id, info)
	let g:BMB_bookMarkBook["dirDict"][string(a:id)]["info"] = a:info 
endfunction


function! BMB_changeInfoInBook()
	"Within the book, change info of currently selected element
	
	"TODO: What I'd like is to have ability to print the current info...
	"Or even better, open a separete buffer for it... Right now its poor
	"mans solution. Lore accurate
	
	call inputsave()

	let info = input("info: ")

	call inputrestore()

	let cp = getcurpos()

	let lineString = string(cp[1])

	if has_key(g:BMB_bookMarkBook["renderedBookmarks"], lineString)
		let bookmarkId = g:BMB_bookMarkBook["renderedBookmarks"][lineString]

		call BMB_changeInfoBookmark(bookmarkId, info)

	elseif has_key(g:BMB_bookMarkBook["renderedDirs"], lineString)
		let dirId = g:BMB_bookMarkBook["renderedDirs"][lineString]["id"]

		call BMB_changeInfoDir(dirId, info)
	endif

	call s:BMB_render()

	call setpos(".", cp)
endfunction


function! s:BMB_getDirInBook()
	"When in bmb file, return if the current line is on a rendered dir
	"If not, v:none is returned

	let cp = getcurpos()

	let lineString = string(cp[1])

	if has_key(g:BMB_bookMarkBook["renderedDirs"], lineString)
		return g:BMB_bookMarkBook["renderedDirs"][lineString]
	endif

	return v:none


endfunction


function! s:BMB_getBookmarkInBook()
	"Return the bookmark when in the book.
	"I.E for the current line, check if any booksmarks are rendered for it
	"and if so, return that bookmark
	"else return v:none
	
	let cp = getcurpos()

	let lineString = string(cp[1])

	if has_key(g:BMB_bookMarkBook["renderedBookmarks"], lineString)
		let bookmarkId = g:BMB_bookMarkBook["renderedBookmarks"][lineString]

		let bookmark = 	g:BMB_bookMarkBook["bookmarkDict"][string(bookmarkId)]

		return bookmark
	endif

	return v:none

endfunction


function! BMB_changePosInBook()
	let cp = getcurpos()

	let lineString = string(cp[1])

	let bookmark = s:BMB_getBookmarkInBook()

	if has_key(g:BMB_bookMarkBook["renderedBookmarks"], lineString)
		let bookmarkId = g:BMB_bookMarkBook["renderedBookmarks"][lineString]

		let bookmark = 	g:BMB_bookMarkBook["bookmarkDict"][string(bookmarkId)]

		call popup_notification("Change bookmark: " . bookmarkId, 
					\{"title":"c", "pos":"topright"})	

		let g:BMB_pendingOpData = {"op":"changeBookmark", "bookmark":bookmark} 
	endif
endfunction


function! BMB_gotoParentDirInBook()
	"Jump to parent in book.

	let cp = getcurpos()		

	let currentDepth = g:BMB_renderLineDepth[string(cp[1])]

	let notFoundInList = v:true
	let dir = v:none

	if currentDepth == 0
		echom "on root already"
		return
	endif

	while notFoundInList
		let cp = getcurpos()		
		let cp[1] -= 1
		call setpos(".", cp)
		let dir = s:BMB_getDirInBook()

		if type(dir) == 4
			if g:BMB_renderLineDepth[string(cp[1])] == (currentDepth - 1)
				let notFoundInList = v:false	
			endif
		endif
	endwhile	

endfunction


function! BMB_moveInBook()
	"Starts operation to move bookmark in book	
	"Is applied with BMB_applyPendingOp
	"TODO: add ability to move dir also through this
	
	let bookmark = s:BMB_getBookmarkInBook()

	let dir = s:BMB_getDirInBook()

	let cp = getcurpos()		

	let startpos = cp 
	
	let bookmarkDepth = g:BMB_renderLineDepth[string(cp[1])]

	if type(bookmark) == 4 
		call BMB_gotoParentDirInBook()

		let dir = s:BMB_getDirInBook()

		let g:BMB_pendingOpData = {"op":"moveBookmarkInBook", "bookmark":bookmark, "fromDir":dir}

		call setpos(".", startpos)

	elseif type(dir) == 4
		call BMB_gotoParentDirInBook()

		let parentDir = s:BMB_getDirInBook() 

		let g:BMB_pendingOpData = {"op":"moveDirInBook", "dirToMove":dir, "parentDir":parentDir}

		call setpos(".", startpos)

	endif
	
endfunction


function! s:BMB_startDuplicateBookmarkInBook()

	let bookmark = s:BMB_getBookmarkInBook()

	if type(bookmark) == 4
		let g:BMB_pendingOpData = {"op":"duplicateBookmark", "bookmark":bookmark}

	endif

endfunction


function! s:BMB_addDirInBook()
	"Add a subdir to a dir in the book
	"Only put in name first now. Info is easy to add later :)

	let dir = s:BMB_getDirInBook()

	if type(dir) == 4
			
		call inputsave()

		let name = input("dir name: ")

		call inputrestore()

		let cp = getcurpos()

		call BMB_addDir(dir["id"], name, "")

		call s:BMB_render()

		call setpos(".", cp)
	endif

endfunction


function! BMB_startPendingOp(op)

	if a:op == "changePosInBook"
		call BMB_changePosInBook()

	elseif a:op == "moveInBook"
		call BMB_moveInBook()
	
	elseif a:op == "duplicateBookmarkInBook"
		call s:BMB_startDuplicateBookmarkInBook()

	elseif a:op == "addDirInBook"
		call s:BMB_addDirInBook()
	else
		echoe "ERROR: unknown op: " . a:op

	endif

endfunction


function! s:BMB_render()
	"Render the book. Should be called when filetype is bmb

	setlocal filetype=bmb
	setlocal buftype=nowrite
	setlocal bufhidden=delete
	setlocal cursorline
	setlocal noswapfile
	setlocal nowrap
	setlocal noshowcmd


	augroup BMB
		au!
		"Add all bmb-mappings
		nnoremap <buffer> <CR> :call BMB_openInBook()<CR>
		nnoremap <buffer> i    :call BMB_changeInfoInBook()<CR>

		"Starting pending operations
		nnoremap <buffer> c    :call BMB_startPendingOp("changePosInBook")<CR>
		nnoremap <buffer> m    :call BMB_startPendingOp("moveInBook")<CR>
		nnoremap <buffer> d    :call BMB_startPendingOp("duplicateBookmarkInBook")<CR>
		nnoremap <buffer> ad   :call BMB_startPendingOp("addDirInBook")<CR>

		"Direct actions
		nnoremap <buffer> r    :call BMB_removeInBook()<CR>

		"This is the most retarded thing I've ever seen.
		"If I call this function explicitly in the bmb-buffer, it
		"doesn't work. in fact. getcurpos doesn't work. it jump to
		"first line all the time. except that some of the time it
		"doesn't... fucking shit. but this works... somehow
		nnoremap <buffer> p    :call BMB_gotoParentDirInBook()<CR>

		"These are here so we know how to rerender the bmb-buffer later
		autocmd BufLeave * :call BMB_setBMB() 
		autocmd BufEnter * :call BMB_bufEnter() 
		
		"Some syntax :) I guess this should be in syntax.vim later
		syntax match BMB_DIR '\[v\]'    
		syntax match BMB_DIR '\[>\]'    
		highlight BMB_DIR cterm=bold 
	augroup END

	"Clear the buffer
	execute "normal! ggVGdd"


	let g:BMB_bookMarkBook["renderedBookmarks"] = {}
	let g:BMB_bookMarkBook["renderedDirs"] 	    = {}
	let g:BMB_renderLineDepth = {} 

	let root = g:BMB_bookMarkBook["dirDict"][string(s:BMB_rootIndex)]

	setlocal modifiable
	call s:BMB_renderDir(root, 1, 0)

	"setlocal nomodifiable
endfunction


function! BMB_setBMB()
	if &filetype == "bmb"
		if !has_key(g:BMB_bufferDict, string(bufnr()))
			let g:BMB_bufferDict[string(bufnr())] = v:true
		endif	
	endif 
endfunction


function! BMB_applyDuplicateBookmark()
	"Apply the duplicate operation.
	"Must be on a dir, and, it shouldnt exists within it alread.
	
	let dir = s:BMB_getDirInBook()

	if type(dir) == 4
		let bookmark = g:BMB_pendingOpData["bookmark"]

		let index = index(dir["bookmarkIdList"], bookmark["id"])

		if index == -1
			let cp = getcurpos()
			call add(dir["bookmarkIdList"], bookmark["id"])
			call add(bookmark["dirIdList"], dir["id"])
			call s:BMB_render()
			call setpos(".", cp)

		else
			echom "Already in this dir"
		endif
	endif
endfunction


function! BMB_applyMoveDirInBook()
	"Apply the operation to move a dir wihtin the book

	let dirToMove = g:BMB_pendingOpData["dirToMove"]

	let parentDir = g:BMB_pendingOpData["parentDir"]
	
	let toDir = s:BMB_getDirInBook()

	if type(toDir) == 4
		"We are on a dir
		if toDir != dirToMove && toDir != parentDir 
			"The dir we are on are not the dir we are trying to
			"move, or the parent of the dir to move.
			let indexToRemove = index(parentDir["dirIdList"], dirToMove["id"])

			call remove(parentDir["dirIdList"], indexToRemove)

			call add(toDir["dirIdList"], dirToMove["id"])

			let cp = getcurpos()

			call s:BMB_render()

			call setpos(".", cp)
		endif 		
	endif

endfunction


function! s:BMB_applyChangeBookmark()
	"Apply the change bookmark operation.
	"I.E CHANGE the FILE and LINE of given bookmark.

	if &filetype == "bmb"
		echoe "cannot set a bookmark to be in the book :("
		return
	endif


	let bookmark = g:BMB_pendingOpData["bookmark"]

	"Remove old sign.
	if bufexists(bookmark["file"])
		call sign_unplace("bmb", {'buffer' : bufnr(bookmark["file"]), 
					   \'id' : bookmark["id"] + 1})
	endif	


	let cp = getcurpos()

	let line = cp[1]
	let string = getline(line) 

	"Change line, string, and file
	let bookmark["line"] 	= line
	let bookmark["string"] 	= string
	let bookmark["file"] 	= @%

	"Place a new sign
	call sign_place(bookmark["id"] + 1, "bmb", "bmbSign", bookmark["file"], {'lnum' : bookmark["line"]})
	echom "Set line: " . line . " for bookmark: " . bookmark["id"]

endfunction


function! s:BMB_applyMoveBookmarkInBook()
	"Apply the operation moveBookmarkInBook
	"That is: move the bookmark to another dir

	"First check if current file is the bmb
	if &filetype != "bmb"
		echoe "Can't move bookmark if not in bmb file"	
		return
	endif

	"Check if current line is a dir	
	let dir = s:BMB_getDirInBook()		

	if type(dir) != 4
		echoe "Not on dir"	
		return
	endif

	let startpos = getcurpos()

	let bookmark = g:BMB_pendingOpData["bookmark"]

	let fromDir = g:BMB_pendingOpData["fromDir"]

	if fromDir != dir
		"Only move if different dir to move to... yes
		"Also, if dir already exists, it is only a
		"removal. Is this an error case?

		let indexToRemove = index(bookmark["dirIdList"], fromDir["id"]) 
		
		call remove(bookmark["dirIdList"], indexToRemove)

		let bookmarkIndexToRemove = index(fromDir["bookmarkIdList"], bookmark["id"])

		call remove(fromDir["bookmarkIdList"], bookmarkIndexToRemove)

		if index(bookmark["dirIdList"], dir["id"]) == -1
			"Only add the bookmark to the new dir,
			"if it isn't already there. Is this a
			"error case?
			call add(bookmark["dirIdList"], dir["id"])
			call add(dir["bookmarkIdList"], bookmark["id"]) 
		endif

		"Rerender the shit
		call s:BMB_render() 

		"go back to where we were
		call setpos(".", startpos)
	endif

endfunction


function! BMB_applyPendingOp()
	"Apply a pending operation in BMB_pendingOpData
	if g:BMB_pendingOpData["op"] != v:none
		let op = g:BMB_pendingOpData["op"] 

		if op == "changeBookmark"
			call s:BMB_applyChangeBookmark()
	
		elseif op == "moveBookmarkInBook"
			call s:BMB_applyMoveBookmarkInBook()

		elseif op == "duplicateBookmark"
			call BMB_applyDuplicateBookmark()

		elseif op == "moveDirInBook"
			call BMB_applyMoveDirInBook()
		
		else
			echoe "ERROR: unknown op: " . op
		endif

		let g:BMB_pendingOpData = {"op":v:none}
	endif

endfunction


function! BMB_addSignsToBuffer()

	let fileName = @%

	let startPos = getcurpos()

	execute "normal! GG"

	let lastLine = getcurpos()[1]

	call setpos(".", startPos)

	for bookmark in values(g:BMB_bookMarkBook["bookmarkDict"])
		if fileName == bookmark["file"]
			call sign_place(bookmark["id"] + 1, "bmb", "bmbSign", fileName, {'lnum' : bookmark["line"]})
		endif		
	endfor

endfunction


function! s:BMB_getBookmarkListForBuffer(bufferName)
	"Return a list of all bookmarks in the current buffer
	"
	let bookmarkList = []

	for bookmark in values(g:BMB_bookMarkBook["bookmarkDict"])
		if bookmark["file"] == a:bufferName
			call add(bookmarkList, bookmark)
		endif
	endfor

	return bookmarkList

endfunction


function! s:BMB_getBookmarkOnCurrentLine()
	"Get the bookmark on current line if any.
	"Returns the bookmark, or if none, returns v:none 	
	
	let fileName = @%

	let cp = getcurpos()

	let bookmarkList = s:BMB_getBookmarkListForBuffer(fileName)

	let bookmarkOnCurrentLine = v:none

	for bookmark in bookmarkList
		if bookmark["line"] == cp[1]
			let bookmarkOnCurrentLine = bookmark	
			break
		endif	
	endfor

	return bookmarkOnCurrentLine
	

endfunction


function! BMB_editInfoInPlace()
	"Edit info within the buffer that the bookmark points to
	let fileName = @%
	
	let bookmark = s:BMB_getBookmarkOnCurrentLine()

	if type(bookmark) == 4 
		
		call inputsave()

		let info = input("info: ")

		call inputrestore()

		let bookmark["info"] = info	
	endif
endfunction


function! BMB_moveInPlace()
	"start moving bookmark in buffer that bookmark is in
	let fileName = @%
	
	let bookmark = s:BMB_getBookmarkOnCurrentLine()

	if type(bookmark) == 4 
		
		call popup_notification("Change bookmark: " . bookmark["id"], 
					\{"title":"c", "pos":"topright"})	
		let g:BMB_pendingOpData = {"op":"changeBookmark", "bookmark":bookmark} 
	endif
endfunction


function! BMB_bufEnter()
	"Called every time we enter a buffer
	"I think it is this one that should determine to render, if we are
	"entering bmb-buffer. Needed for ctrl+o jumps for example.
	"
	"Or if not bmb-file: to place signs if any bookmark points to a valid line within this
	"buffer (file)
	if has_key(g:BMB_bufferDict, string(bufnr()))
		call s:BMB_render()

	else
		if g:BMB_pendingOpData["op"] != v:none
			"If there is a pending operation, set a mapping for it
			nnoremap <leader>bmba :call BMB_applyPendingOp()<CR>
		endif


		if type(g:BMB_bookMarkBook) == 4
			call BMB_addSignsToBuffer()

			nnoremap<buffer> <leader>bei :call BMB_editInfoInPlace()<CR>
			nnoremap<buffer> <leader>bm :call BMB_moveInPlace()<CR>
		endif

	endif	
endfunction


function! BMB_openBuffer()
	"Open the BMB buffer to browse bookmarks 
	"This should be a special buffer then, whith special special
	
	if s:BMB_state == 0
		echoe "must initialize BMB first before opening special buffer"
		return	
	endif

	:enew 

	call s:BMB_render()
	
endfunction


"Save all bufnr that we open with bmb so we can recreate teh state
"when going back... this is retarded but I don't know else what to do
let g:BMB_bufferDict = {} 

"What BMB-state are we in? Are we trying to create a new bookmark?
"Are we altering abookmark, deleting, adding info, moving, etc etc...

"0 - Means we are not initialized at all. nothing will work
"1 - We have initialized, either by init from existing or creating a new. Now
"    we can start doing stuff

let s:BMB_state = 0 


"The actual bookmark book
let g:BMB_bookMarkBook = v:none

"TODO: use this to autosave at times. I think it will be replaced by config in
"bookMarksBook
let g:BMB_autoSave = v:false


"All previously visited bookmarks. This can be used to go quickly to a
"previous place is my thinking... Lets see if it be smart of nah
let g:BMB_previousBookMarksVisited = []


let s:BMB_rootIndex = 0


function! BMB_createBook(fileName, name)
	"Create a bookmark book with name, save in fileName.
	"baseDir is to keep track of paths in some sort of fashion. 
	"lets see how it plays out

	"name: Then name of the bmb
	"created: timestamp when created
	"modified: timestamp when modified
	"basedir: base directory from which the rest of bookmarks depend on
	"	  per default: current working directory
	"bookmarkDict: dictionary with all bookmarks
	"dirDict: dictionary with dirs. Each dir contains refs to more dirs or
	"         bookmarks
	"nextBookmarkId: ID that a newly bookmark will get
	"nextDirId: ID that a newly created dir will get
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
		echom "ERROR: must initialize BMB first"
		return	
	endif
	
	call BMB_saveBookAs(g:BMB_bookMarkBook["fileName"])
endfunction


function! BMB_saveBookAs(fileName)
	"Save the book as fileName
	if s:BMB_state == 0
		echom "ERROR: must initialize BMB first"
		return	
	endif

	let g:BMB_bookMarkBook["fileName"] = a:filename
	
	let jsonString = json_encode(g:BMB_bookMarkBook)	

	call writefile([jsonString], a:fileName)

endfunction


function! BMB_init(bookMarkFile)
	"Initialize the bookmark-book :)
	"With an existing one given by bookMarkFile

	let lines = readfile(a:bookMarkFile)

	let jsonString = join(lines)

	let jsonObject = json_decode(jsonString)

	let g:BMB_bookMarkBook = jsonObject

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

	"TODO: how is the file in comparison to baseDir in the bmbook?
	"TODO: also check that parent exists

	let nextBookmarkId = g:BMB_bookMarkBook["nextBookmarkId"] 
	"Now create the bookmark
	let bookmark = 	{
				\"id": nextBookmarkId,
				\"file":@%,
				\"line":line,
				\"column":column,
				\"name":"",
				\"info":"",
				\"dirIdList":[string(a:parent)],
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
	echo "gotoBookmark"
	if s:BMB_state == 0
		echom "ERROR: bmb must be initialized first"
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


function! s:BMB_renderBookmark(bookmark, line, indent)

	let g:BMB_bookMarkBook["renderedBookmarks"][string(a:line)] = a:bookmark["id"]

	let lineContent = trim(a:bookmark["string"])

	"TODO: also if content is less than 30, fill to 30
	if strlen(lineContent) > 30
		let lineContent = strcharpart(lineContent, 0, 30) 	
	endif

	call setline(a:line, 
		     \a:indent . string(a:bookmark["id"]) . 
		     \" | " . lineContent . " | " . a:bookmark["info"])

endfunction


function! s:BMB_renderDir(dir, startLine, indent)
	"TODO: must save the line numbers and such, in order to open.
	"How to handle closing and opening? that's a future problem
	
	let lineNumber = a:startLine

	let dirSpecifierString = "[d] -"

	call setline(lineNumber, 
		     \a:indent . 
		     \dirSpecifierString . " " . a:dir["name"] . " | " . a:dir["info"])

	let g:BMB_bookMarkBook["renderedDirs"][string(lineNumber)] = a:dir
	
	let lineNumber += 1

	if !has_key(a:dir,"rendered") || !a:dir["rendered"]
		"Do not render the bookmarks for this dir if not rendered	
		return lineNumber
	end

	for dirId in a:dir["dirIdList"]
		let subDir = g:BMB_bookMarkBook["dirDict"][string(dirId)]

		let lineNumber = s:BMB_renderDir(subDir, 
						    \lineNumber, 
						    \a:indent . "  ")
	endfor

	for bookmarkId in a:dir["bookmarkIdList"]
		call s:BMB_renderBookmark(g:BMB_bookMarkBook["bookmarkDict"][string(bookmarkId)], 
					 \lineNumber, 
					 \a:indent . "  ")
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


function! s:BMB_render()
	"Render the book. Should be called when filetype is bmb
	echom "RENDER"

	setlocal filetype=bmb
	setlocal buftype=nowrite
	setlocal bufhidden=delete
	setlocal cursorline
	setlocal noswapfile
	setlocal nowrap

	augroup BMB
		au!
		nnoremap <buffer> <CR> :call BMB_openInBook()<CR>
		nnoremap <buffer> i :call BMB_changeInfoInBook()<CR>

		"These are here so we know how to rerender the bmb-buffer later
		autocmd BufLeave * :call BMB_setBMB() 
		autocmd BufEnter * :call BMB_checkBMB() 
		
		"Some syntax :) I guess this should be in syntax.vim later
		syntax match BMB_DIR '\[d\]'    
		highlight BMB_DIR cterm=bold 
	augroup END

	"Clear the buffer
	execute "normal ggVGdd"

	let g:BMB_bookMarkBook["renderedBookmarks"] = {}
	let g:BMB_bookMarkBook["renderedDirs"] 	    = {}

	let root = g:BMB_bookMarkBook["dirDict"][string(s:BMB_rootIndex)]

	setlocal modifiable
	call s:BMB_renderDir(root, 1, "")

	"setlocal nomodifiable
endfunction


function! BMB_setBMB()
	if &filetype == "bmb"
		if !has_key(g:BMB_bufferDict, string(bufnr()))
			let g:BMB_bufferDict[string(bufnr())] = v:true
		endif	
	endif 
	
endfunction


function! BMB_checkBMB()
	if has_key(g:BMB_bufferDict, string(bufnr()))
		call s:BMB_render()
	endif	
endfunction


function! BMB_openBuffer()
	"Open the BMB buffer to browse bookmarks 
	"This should be a special buffer then, whith special special
	
	if s:BMB_state == 0
		echom "ERROR: must initialize BMB first before opening special buffer"
		return	
	endif

	:enew 

	call s:BMB_render()
	
endfunction




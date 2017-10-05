" Features: Dynamic Tiling Window Management
" each tab has its own layout and master size/count
" inc/dec master count dynamically
" four layouts: top, bottom, right, left
" can rotate the windows
"
" tagbar acts wierd

if exists('g:loaded_tile')
    finish
endif
let g:loaded_tile = 1

if !exists('g:tiler#layout')
    let g:tiler#layout = 'right'
endif

if !exists('g:tiler#master#size')
    let g:tiler#master#size = 62
endif

if !exists('g:tiler#master#count')
    let g:tiler#master#count = 1
endif

if !exists('g:tiler#popup#windows')
    let g:tiler#popup#windows = {}
endif

let s:popup_is_vertical = { 'left': 1, 'right': 1, 'top': 0, 'bottom': 0 }
let s:popup_directions  = { 'right': 'L', 'left': 'H', 'top': 'K', 'bottom': 'J' }
let s:saved_popups = {}

let s:tile_layouts_master = { 'right': 'H', 'left': 'L', 'top': 'J', 'bottom': 'K' }
let s:tile_layouts_stack  = { 'right': 'K', 'left': 'J', 'top': 'L', 'bottom': 'H' }
let s:tile_layouts_order  = { 'right': 'J', 'left': 'J', 'top': 'L', 'bottom': 'L' }
let s:tile_layouts_master_split = { 'right': 'split', 'left': 'split', 'top': 'vsplit', 'bottom': 'vsplit' }

let s:layouts = ['right', 'top', 'left', 'bottom']
let s:tile_master  = 0
let s:reordering = 0
let s:tab_layouts = {}

let s:window_layout = {}
let s:master_count = {}
let s:master_size = {}

" returns max height of a window
function! s:winmaxheight()
    let l:height = &lines - &cmdheight

    " subtract one from height if tabbar is visible
    if len(gettabinfo()) > 1 && &showtabline
        let l:height -= 1
    endif

    " subtract one from height if statusline is visible
    if &laststatus > 0
        let l:height -= 1
    endif

    return l:height
endfunction

function! s:window_close(win)
    execute printf('silent %d wincmd w', a:win)
    close
endfunction

function! s:window_move(dir, ...)
    let a:winnum = get(a:, 1, winnr())
    execute printf('silent %d wincmd w', a:winnum)
    execute printf('silent wincmd %s', a:dir)
endfunction

function! s:window_resize(size, is_vertical, ...)
    let a:winnum = get(a:, 1, winnr())
    let l:command = a:is_vertical ? 'vertical' : ''

    execute printf('silent %d wincmd w', a:winnum)
    execute printf('silent %s resize %d', l:command, a:size)
endfunction

function! s:window_resize_percentage(size, is_vertical, ...)
    let a:winnum = get(a:, 1, winnr())
    let l:size = s:winmaxheight() * (a:size * 0.01)
    if a:is_vertical
        let l:size = &columns * (a:size * 0.01)
    endif
    call s:window_resize(float2nr(l:size), a:is_vertical, a:winnum)
endfunction

function! s:sort_popups(a, b)
    return get(a:a.vars, 'order', 0) < get(a:b.vars, 'order', 0)
endfunction

function! s:get_saved_popups()
    let l:current_tab = tabpagenr()
    if empty(get(s:saved_popups, l:current_tab))
        let s:saved_popups[l:current_tab] = []
    endif
    return s:saved_popups[l:current_tab]
endfunction

function! s:set_saved_popups(popups)
    let s:saved_popups[tabpagenr()] = a:popups
endfunction

function! s:find_popups()
    let l:popups = []

    for i in range(1, winnr('$'))
        let l:buf = winbufnr(i)
        let l:bufname = bufname(l:buf + 0)
        let l:filetype = getbufvar(l:buf, "&filetype")

        for [l:name, l:window] in items(g:tiler#popup#windows)
            if has_key(l:window, 'filetype') && l:window.filetype !=# l:filetype
                continue
            endif
            if has_key(l:window, 'name') && !len(matchstr(l:bufname, l:window.name))
                continue
            endif
            let l:popups = add(l:popups, { 'vars': l:window, 'id': win_getid(i) })
        endfor
    endfor

    " sort to keep popup locations consistent
    return sort(l:popups, 's:sort_popups')
endfunction

function! s:get_master_layout()
    let l:current_tab = tabpagenr()
    if empty(get(s:window_layout, l:current_tab))
        let s:window_layout[l:current_tab] = []
    endif
    return s:window_layout[l:current_tab]
endfunction

function! s:set_master_layout(layout)
    let s:window_layout[tabpagenr()] = a:layout
endfunction

function! s:get_master_size()
    let l:current_tab = tabpagenr()
    if empty(get(s:master_size, l:current_tab))
        let s:master_size[l:current_tab] = g:tiler#master#size
    endif
    return s:master_size[l:current_tab]
endfunction

function! s:set_master_size(count)
    let s:master_size[tabpagenr()] = a:count
endfunction

function! s:get_master_count()
    let l:current_tab = tabpagenr()
    if empty(get(s:master_count, l:current_tab))
        let s:master_count[l:current_tab] = g:tiler#master#count
    endif
    return s:master_count[l:current_tab]
endfunction

function! s:update_master_count(count)
    let s:master_count[tabpagenr()] = a:count
endfunction

function! s:set_tab_layout(layout)
    let s:tab_layouts[tabpagenr()] = a:layout
endfunction

function! s:get_tab_layout()
    let l:current_tab = tabpagenr()
    if empty(get(s:tab_layouts, l:current_tab))
        let s:tab_layouts[l:current_tab] = g:tiler#layout
    endif
    return s:tab_layouts[l:current_tab]
endfunction

function! s:get_master()
    return win_id2win(get(s:get_master_layout(), 0, 1))
endfunction

function! s:resize_master()
    " don't resize if only one window visible
    if len(s:get_master_layout()) <= 1
        return
    endif

    let l:curwin = winnr()
    execute printf('%d wincmd w', s:get_master())

    let l:is_vertical = 1
    if s:get_tab_layout() ==# 'top' || s:get_tab_layout() ==# 'bottom'
        let l:is_vertical = 0
    endif

    " make the master windows size relative to vims width/height minus popups size
    let l:offset = 0
    let l:popups = s:find_popups()
    for popup in l:popups
        if index(['left', 'right'], popup.vars.position) > -1 && l:is_vertical
            let l:offset += popup.vars.size
        elseif index(['top', 'bottom'], popup.vars.position) > -1 && !l:is_vertical
            let l:offset += popup.vars.size
        endif
    endfor

    let l:size = s:get_master_size()
    " handle correct sizing, prevents popups from being larger than main window
    if s:get_master_count() > 1 && len(s:get_master_layout()) <= s:get_master_count()
        let l:size = 100
    endif
    call s:window_resize_percentage(l:size - l:offset, l:is_vertical, s:get_master())
    execute printf('%d wincmd w', l:curwin)
endfunction

function! s:arrange_windows()
    let l:layout = s:get_tab_layout()
    for i in range(1, winnr('$'))
        if ((l:layout ==# 'left' || l:layout ==# 'right') && winwidth(i) != &columns) ||
            \ ((l:layout ==# 'top' || l:layout ==# 'bottom') && winheight(i) != s:winmaxheight())
            call s:window_move(s:tile_layouts_stack[l:layout], i)
            return -1
        endif
    endfor
    return 1
endfunction

" puts all the windows in a vertical or horizontal stack
function! tiler#stack_windows() abort
    let l:counter = 0
    while s:arrange_windows() < 0
        let l:counter += 1
        if l:counter > 50
            echoerr 'infinite loop, probably an issue with getting max height or width'
            break
        endif
    endwhile
endfunction

function! s:swap_buffers(a, b)
    let l:abuf = winbufnr(a:a)
    let l:bbuf = winbufnr(a:b)

    execute a:a . 'wincmd w'
    execute 'b ' . l:bbuf
    execute a:b . 'wincmd w'
    execute 'b ' . l:abuf
endfunction

" make sure tile_order is correct, when another window opened without calling TilerNew
function! s:verify_tile_order(popups)
    let l:window_layout = s:get_master_layout()
    if len(l:window_layout) + len(a:popups) != winnr('$')
        let l:window_layout = reverse(sort(map(range(1, winnr('$')), 'win_getid(v:val)')))
        let l:window_layout = insert(filter(l:window_layout, 'v:val != s:tile_master'), s:tile_master)
    endif
    call s:set_master_layout(filter(l:window_layout, 'v:val != 0'))
endfunction

function! tiler#close_window()
    call s:set_master_layout(filter(s:get_master_layout(), 'v:val != win_getid()'))
    close
    call tiler#reorder()
endfunction

function! tiler#create_window()
    wincmd n
    let s:tile_master = win_getid()
    let l:window_layout = s:get_master_layout()
    call s:set_master_layout(insert(l:window_layout, s:tile_master))
    call tiler#reorder()
    execute printf('%d wincmd w', s:get_master())
endfunction

function! s:get_current_layout()
    return map(range(1, winnr('$')), 'win_getid(v:val)')
endfunction

function! tiler#reorder()
    " prevent from trying to reorder while reordering
    if s:reordering == 1
        return
    endif
    let s:reordering = 1

    let l:popups = s:find_popups()
    call s:verify_tile_order(l:popups)

    let l:currwin = win_getid()
    call tiler#stack_windows()

    let l:new_popups = filter(copy(l:popups), 'index(s:get_saved_popups(), v:val) < 0 && get(v:val.vars, "replace", 0)')
    for popup in l:new_popups
        let l:popups_to_close = filter(copy(l:popups), 'v:val != popup && get(v:val.vars, "replace", 0) && popup.vars.position ==# v:val.vars.position')
        for win in map(l:popups_to_close, 'win_id2win(v:val.id)')
            call s:window_close(win)
        endfor
    endfor

    let l:popups = s:find_popups()
    call s:set_saved_popups(l:popups)

    let l:current_layout = s:get_current_layout()
    " move popup windows to bottom of stack and remove from list of current windows
    for popup in l:popups
        call s:window_move(s:tile_layouts_order[s:get_tab_layout()], win_id2win(popup.id))
        let l:current_layout = filter(l:current_layout, 'v:val != popup.id')
    endfor

    let l:window_layout = s:get_master_layout()
    if (l:current_layout != l:window_layout)
        let l:buforder = map(l:window_layout, 'winbufnr(win_id2win(v:val))')
        " move buffers around rather than move the actual window
        for i in range(1, len(l:buforder))
            " make sure window exists
            if !win_getid(i)
                continue
            endif

            execute printf('%d wincmd w', i)
            execute printf('b %d', l:buforder[i - 1])
        endfor
    endif

    " windows are now sorted, so get correct winids for layout
    " minus the popup windows
    let l:window_layout = s:get_current_layout()
    for popup in l:popups
        let l:window_layout = filter(l:window_layout, 'v:val != popup.id')
    endfor
    call s:set_master_layout(l:window_layout)

    " move master window to correct spot
    let s:tile_master = win_getid(s:get_master())
    call s:window_move(s:tile_layouts_master[s:get_tab_layout()], s:get_master())

    " handle more than one master window
    if s:get_master_count() > 1 && len(l:window_layout) > 1
        let l:new_window_count = s:get_master_count() - 1
        if len(l:window_layout) <= l:new_window_count
            let l:new_window_count = len(l:window_layout) - 1
        endif

        " create master splits/layout
        for i in range(1, l:new_window_count)
            execute s:tile_layouts_master_split[s:get_tab_layout()]
            let l:window_layout = insert(l:window_layout, win_getid())
        endfor

        " shift all buffers up by new window count
        " start at non master window, subtract one for master window
        for i in range(1, len(l:window_layout) - l:new_window_count - 1)
            execute printf('%s wincmd w', win_id2win(l:window_layout[i]))
            execute 'b' . winbufnr(win_id2win(l:window_layout[l:new_window_count + i]))
        endfor

        " remove extra windows
        for i in range(1, l:new_window_count)
            execute printf('%d wincmd w', win_id2win(l:window_layout[-1]))
            close
            let l:window_layout = l:window_layout[0:-2]
        endfor
    endif

    " handle popup windows like nerdtree, tagbar, qf, etc
    for popup in l:popups
        call s:window_move(s:popup_directions[popup.vars.position], win_id2win(popup.id))
    endfor

    " set every windows size correctly
    for popup in l:popups
        call s:window_resize_percentage(popup.vars.size, s:popup_is_vertical[popup.vars.position], win_id2win(popup.id))
    endfor
    wincmd =
    execute printf('%d wincmd w', win_id2win(l:currwin))

    call s:set_master_layout(l:window_layout)
    call s:resize_master()
    let s:reordering = 0
endfunction

function! tiler#open(file)
    call tiler#create_window()
    execute 'e' a:file
endfunction

function! tiler#resize_master(size)
    call s:set_master_size(a:size)
    call s:resize_master()
endfunction

function! tiler#switch_layout(layout)
    call s:set_tab_layout(a:layout)
    call tiler#reorder()
endfunction

function! tiler#rotate_forwards()
    if len(s:get_current_layout()) < 1
        return
    endif

    let l:window_layout = s:get_master_layout()
    let l:selected_window_index = index(l:window_layout, win_getid())

    let l:window_layout = insert(l:window_layout, l:window_layout[-1])
    let l:window_layout = l:window_layout[0:-2]
    call s:set_master_layout(l:window_layout)

    call tiler#reorder()
    let l:window_layout = s:get_master_layout()
    let l:new_window = get(l:window_layout, l:selected_window_index + 1, l:window_layout[0])
    execute printf('%d wincmd w', win_id2win(l:new_window))
endfunction

function! tiler#rotate_backwards()
    if len(s:get_master_layout()) < 1
        return
    endif

    let l:window_layout = s:get_master_layout()
    let l:selected_window_index = index(l:window_layout, win_getid())

    let l:window_layout = add(l:window_layout, l:window_layout[0])
    let l:window_layout = l:window_layout[1:]
    call s:set_master_layout(l:window_layout)

    call tiler#reorder()
    execute printf('%d wincmd w', win_id2win(s:get_master_layout()[l:selected_window_index - 1]))
endfunction

function! tiler#rotate_layout(dir)
    let l:current_layout = index(s:layouts, s:get_tab_layout())
    let l:current_layout += a:dir

    if l:current_layout < 0
        let l:current_layout = len(s:layouts) - 1
    elseif l:current_layout > len(s:layouts) - 1
        let l:current_layout = 0
    endif

    call tiler#switch_layout(s:layouts[l:current_layout])
endfunction

function! tiler#update_master_count(size)
    let l:new_count = s:get_master_count() + a:size
    if l:new_count <= 0
        let l:new_count = 1
    endif

    if l:new_count == s:get_master_count()
        return
    endif

    call s:update_master_count(l:new_count)
    call tiler#reorder()
    call s:resize_master()
endfunction

" taken from https://github.com/junegunn/dotfiles/tree/master/vimrc
function! tiler#zoom()
  if winnr('$') > 1
    tab split
  elseif len(filter(map(range(tabpagenr('$')), 'tabpagebuflist(v:val + 1)'),
                  \ 'index(v:val, '.bufnr('').') >= 0')) > 1
    tabclose
  endif
endfunction

function! tiler#get_master_size()
    return s:get_master_size()
endfunction

function! tiler#get_master_count()
    return s:get_master_count()
endfunction

function! tiler#get_layout()
    return s:get_tab_layout()
endfunction

function! tiler#focus()
    call s:swap_buffers(s:get_master(), winnr())
    execute printf('%d wincmd w', s:get_master())
    call s:resize_master()
endfunction

function! s:list_layouts(A,L,P)
    return filter(s:layouts, 'v:val !=# s:get_tab_layout()')
endfun

nnoremap <silent> <Plug>TilerAddMaster :call tiler#update_master_count(1)<CR>
nnoremap <silent> <Plug>TilerDelMaster :call tiler#update_master_count(-1)<CR>
nnoremap <silent> <Plug>TilerRotateLayoutR :call tiler#rotate_layout(1)<CR>
nnoremap <silent> <Plug>TilerRotateLayoutL :call tiler#rotate_layout(-1)<CR>
nnoremap <silent> <Plug>TilerFocus :call tiler#focus()<CR>
nnoremap <silent> <Plug>TilerNew :call tiler#create_window()<CR>
nnoremap <silent> <Plug>TilerClose :call tiler#close_window()<CR>
nnoremap <silent> <Plug>TilerRotateForwards :call tiler#rotate_forwards()<CR>
nnoremap <silent> <Plug>TilerRotateBackwards :call tiler#rotate_backwards()<CR>
nnoremap <silent> <Plug>TilerZoom :call tiler#zoom()<CR>

command! -nargs=1 -complete=file TilerOpen call tiler#open(<q-args>)
command! -nargs=1 TilerResize call tiler#resize_master(<q-args>)
command! -nargs=1 -complete=customlist,s:list_layouts TilerSwitch  call tiler#switch_layout(<q-args>)
command! TilerFocus call tiler#focus()
command! TilerNew call tiler#create_window()
command! TilerClose call tiler#close_window()
command! TilerReorder call tiler#reorder()

" vim: fdm=marker
" GUARD                                                                                   {{{1
if exists("s:loaded") || &cp || version < 700
  finish
endif
let s:loaded = 1
" }}}1

scriptencoding utf8

" THE MODEL                                                                               {{{1
" TODO: need heavy refactor for model structure
let s:m = {}
let s:m.items = []

function! m.get_fname_set() dict                                                        " {{{2
  let fname_set = {}
  for item in self.items
    let fname_set[item.fname]
  endfor
  return keys(fname_set)
endfunction " }}}2

let g:m = s:m

" }}}1

" THE VIEW                                                                                {{{1
let s:v = {}
let mudox#todo#view = s:v
let s:v.stat = {}
" a list of fname whose section is unfoled when shown
let s:v.stat.unfolded = []

function! s:v.is_file_line(line) dict                                                   " {{{2
  return a:line =~ '^' . s:file_line_prefix
endfunction "  }}}2

function! s:v.is_title_line(line) dict                                                  " {{{2
  return a:line =~ '^' . s:title_line_prefix
endfunction "  }}}2

function! s:v.is_item_line(line) dict                                                   " {{{2
  return a:line =~ '^' . s:item_line_prefix
endfunction "  }}}2

function! s:v.line2fname(which) dict                                                    " {{{2
  " TODO!!!: refactor it with new parameter types
  " a:which accepts 2 kinds of values,
  "   a string that is one of 'next', 'cur', 'prev'
  "   a line number

  let flags = {
        \ 'next' : 'Wn',
        \ 'cur'  : 'Wnbc',
        \ 'prev' : 'Wnbc',
        \ }

  let lnum = 0
  if a:which =~ 'next\|cur\|prev'
    let lnum = search(s:file_line_prefix, flags[a:which])
    if a:which == 'prev'
      let lnum = search(s:file_line_prefix, flags[a:which])
    endif
  elseif type(a:which) == type(1)
    let lnum = a:which
  else
    echoerr printf(
          \ 'a:which (= %s) need a string of  [next, cur, prev] or a line number',
          \ a:which,
          \ )
  endif

  " first & last line must be empty line, can not be valid file line
  if lnum == 0 || lnum == line('$')
    return ''
  endif

  return substitute(getline(lnum), s:file_line_prefix . ' .', '', '')
endfunction " }}}2

function! s:v.line2item() dict                                                          " {{{2
  if ! s:v.is_item_line(getline('.'))
    return {}
  endif

  " get line number
  let lnum = matchstr(getline('.'), '\d\+\ze\s*$') + 0

  " get file path
  let fname = ''
  for nr in range(line('.'), 1, -1)
    if s:v.is_file_line(getline(nr))
      let fname = s:v.line2fname(nr)
      break
    endif
  endfor

  " look up the item by filename & lnum
  for item in g:items
    if item.linenr == lnum && item.fname == fname
      return item
    endif
  endfor
  echoerr printf('fail looking up item: %s|%s', fname, lnum)
endfunction "  }}}2

function! s:v.unfold_section() dict                                                " {{{2
  let pos = getcurpos()

  let line = getline('.')

  let start_nr = 0
  let end_nr = 0

  if line =~ s:symbol.folded

    " unfold section
    let lnum = line('.')
    let fname = s:v.line2fname(lnum)
    let lines = []
    for i in range(len(g:items) - 1)
      if g:items[i].fname == fname
        let j = i
        let title = ''
        while j < len(g:items) && g:items[j].fname == fname
          if g:items[j].title != title
            let title = g:items[j].title
            call add(lines, s:title_line(title))
          endif
          call add(lines, s:item_line(g:items[j]))
          let j += 1
        endwhile
        break
      endif
    endfor

    setlocal modifiable
    call setline(lnum, s:file_line(fname, 'unfolded'))
    call append('.', lines)
    setlocal nomodifiable

    let startofline = &startofline
    set nostartofline
    call setpos('.', pos)
    let &startofline = startofline

  elseif line =~ s:symbol.unfolded || s:v.is_title_line(line) || s:v.is_item_line(line)

    " fold section
    let lnum = line('.')
    for i in range(lnum, line('$'))
      if getline(i) == ''
        let end_nr = i - 1
        break
      endif
    endfor

    for i in range(lnum, 1, -1)
      if s:v.is_file_line(getline(i))
        let start_nr = i + 1
        break
      endif
    endfor

    setlocal modifiable
    silent execute printf('%s,%sd _', start_nr, end_nr)
    let fname = s:v.line2fname(start_nr - 1)
    call setline(start_nr - 1, s:file_line(fname, 'folded'))
    setlocal nomodifiable

    normal! gk
  endif

endfunction " }}}2

function! s:v.goto_section()                                                  " {{{2
  " TODO!!!: implement ui_goto_section()
endfunction " }}}2

function! s:v.toggle_folding()                                                " {{{2
  " TODO!!!: implement ui_toggle_folding()
endfunction " }}}2

function! s:v.only_unfold_current_section()                                   " {{{2
  " TODO!!!: implement ui_only_unfold_current_section()
  let fname = s:v.line2fname('cur')

  let on_file_line = 0
  let col = 0
  let off = 0

  if s:v.is_file_line(line('.'))
    let on_file_line = 1
  else
    let col = col('.')
    let off = line('.') - search(fname, 'w')
  endif

  if !empty(fname)
    call s:show([fname])
  endif

  if on_file_line
    call search(fname, 'w')
  else
    let lnum = search(fname, 'w') + off
    let startofline = &startofline
    set nostartofline
    call cursor(lnum, col)
    let &startofline = startofline
  endif
endfunction " }}}2

" }}}1

" IDEA!!!: add each mapping's doc text within its' corresponding function.
" TODO: need a fallback suite of symbols
" TODO: need to honor user's choice
let s:symbol = {
      \ 'folded'   : '',
      \ 'linenr'   : ' ',
      \ 'p!!!'     : '',
      \ 'p!!'      : ' ',
      \ 'p!'       : '  ',
      \ 'p'        : '   ',
      \ 'unfolded' : '',
      \ }
let mudox#todo#symbol = s:symbol

let s:titles = [
      \ 'TODO',
      \ 'ISSUE',
      \ 'IDEA',
      \ 'INFO',
      \ ]

" patterns used for line identifying & highlighting
let s:file_line_prefix = printf(' \(%s\|%s\)',
      \ s:symbol.folded, s:symbol.unfolded)
let mudox#todo#file_line_prefix = s:file_line_prefix


function! s:strip_markers(line)                                                         " {{{1
  let comment_prefix = split(&commentstring, '%s')[0]
  let markers_pat = substitute(&foldmarker, ',', '\\|', '')
  let pattern = printf('\s*\%%(%s\)\s*\%%(%s\)\d\?\s*',
        \ comment_prefix,
        \ markers_pat,
        \ )
  return substitute(a:line, pattern, ' ', '')
endfunction "  }}}1

function! s:sort_items()                                                                " {{{1
  function! s:sort_by_priority(l, r)
    let left = a:l.priority
    let right = a:r.priority
    return left == right ? 0 : left < right ? 1 : -1
  endfunction

  function! s:sort_by_title(l, r)

    let left = index(s:titles, a:l.title)
    let right = index(s:titles, a:r.title)
    return left == right ? 0 : left > right ? 1 : -1
  endfunction

  function! s:sort_by_fname(l, r)
    let left = a:l.fname
    let right = a:r.fname
    return left == right ? 0 : left > right ? 1 : -1
  endfunction

  call sort(g:items, 's:sort_by_priority')
  call sort(g:items, 's:sort_by_title')
  call sort(g:items, 's:sort_by_fname')
endfunction "  }}}1

function! mudox#todo#nav_section(dir)                                                   " {{{1
  let pos = getcurpos()

  let lnum = 0
  if a:dir == -1
    let lnum = search(s:file_line_prefix, 'Wb')
    let lnum = search(s:file_line_prefix, 'Wb')
  elseif a:dir == 1
    let lnum = search(s:file_line_prefix, 'W')
  else
    echoerr printf('a:dir (= %s) need -1 or 1', a:dir)
  endif

  if lnum == 0
    let startofline = &startofline
    set nostartofline
    call setpos('.', pos)
    let &startofline = startofline
    return
  end

  let fname = s:v.line2fname(lnum)
  call s:show([fname])

  call search(fname)
endfunction " }}}1

function! mudox#todo#ui_goto_definition()                                               " {{{1
  let item = s:v.line2item()
  if empty(item)
    return
  endif

  execute 'drop ' . item.fname
  execute printf('normal! %szz', item.linenr)
  silent! normal! zO
endfunction "  }}}1

function! mudox#todo#ui_refresh()                                                       " {{{1
  let pos = getcurpos()

  call MakeToDo()

  let startofline = &startofline
  set nostartofline
  call setpos('.', pos)
  let &startofline = startofline
endfunction "  }}}1

function! data_items_for_bufnr(bufnr)                                                   " {{{1
  return filter(s:items, printf('v:val.bufnr == %d', a:bufnr))
endfunction " }}}1

function! mudox#todo#ui_change_priority(delta)                                          " {{{1
  let col = col('.')

  " figure out the new priority: new_priority
  let item = s:v.line2item()
  if empty(item)
    return
  endif

  if a:delta == +1 && len(item.priority) < 4
    let item.priority .= '!'
  elseif a:delta == -1 && len(item.priority) > 1
    let item.priority = item.priority[:-2]
  else
    return
  endif

  " TODO!!!: need to add data view synchronization way

  " re-sort the items & re-show
  call s:show()

  " cursor follow the changed line
  let line_pat = s:item_line(item)
  call cursor(0, 1)
  let lnum = search(line_pat, 'Wc' . a:delta == 1 ? 'b' : '')
  execute printf('normal! %dzz', lnum)

  " apply the change back
  execute 'edit ' . item.fname
  let line = getline(item.linenr)
  let line = substitute(line, item.title . '\zs.\{-}\ze:',
        \ item.priority[1:], '')
  call setline(item.linenr, line)
  update

  " jump back to *TODO* buffer
  execute printf('buffer! %s', s:bufnr)

  let startofline = &startofline
  set nostartofline
  call cursor(lnum, col)
  let &startofline = startofline
endfunction "  }}}1

function! s:show(...)                                                                   " {{{1
  " if arg1 is given (file path list), then only unfold this file's secition

  if a:0 == 1
    let fname_set = m.fname_set()
    for fname in a:1
      if index(fname_set, fname) == -1
        echoerr prinf('arg1 (%s) not in file list', a:1)
      endif
    endfor
    let s:ui_stat.unfolded = a:1
  elseif a:0 == 0
    let s:ui_stat.unfolded = m.get_fname_set()
  else
    echoerr 'need 0 or 1 argument (file name)'
  endif

  call s:sort_items()

  let fname = ''
  let title = ''
  let lines = []
  for item in g:items

    " print file line if entering a new file section
    if item.fname != fname
      let fname = item.fname
      let fileline = s:file_line(fname,
            \ (index(s:ui_stat.unfolded, fname) == -1) ? 'folded' : 'unfolded')

      " first line MUST be empty line
      call extend(lines, [
            \ '',
            \ fileline,
            \ ])
    endif

    " print title lines & item lines if current section unfolded
    if (!empty(only_unfold_file) && only_unfold_file == fname)
          \ || empty(only_unfold_file)
      " print title line if entering a new title section
      if item.title != title
        let title = item.title
        call add(lines, s:title_line(title))
      endif
      call add(lines, s:item_line(item))
    endif
  endfor

  setlocal modifiable
  %d_
  call append(0, lines) " last line MUST be empty line
  setlocal nomodifiable
  normal! 1G
endfunction "  }}}1

function! s:file_line(fname, folded)                                                    " {{{1

  " TODO: when closed show how many items it have
  let node = (a:folded == 'folded') ? ' ' : '┐'
  return printf(' %s %s%s',
        \ s:symbol[a:folded],
        \ node,
        \ a:fname,
        \ )
endfunction "  }}}1

function! s:title_line(title)                                                           " {{{1
  let s:title_line_prefix = '   └'
  return printf('%s %s:', s:title_line_prefix, a:title)
endfunction "  }}}1

function! s:item_line(item)                                                             " {{{1
  let max_text_width = 62
  if len(a:item.text) > max_text_width
    let text = a:item.text[:55] . ' ...'
  else
    let text = a:item.text
  endif

  let s:item_line_prefix = repeat("\x20", 6)
  return printf('%s%s %-' . max_text_width . 's %s',
        \ s:item_line_prefix,
        \ s:symbol[a:item.priority],
        \ text,
        \ printf('%s %s', s:symbol.linenr, a:item.linenr),
        \ )
endfunction "  }}}1

function! s:collect()                                                                   " {{{1
  " TODO: need to return them back to under s: scope
  let items = []

  " IDEA!!: is asynchronization necessary?
  " IDEA!: arg list can be handled by `ag`, add it in?

  " INFO: currently only watching listed buffers whose buftype is normal
  for bufnr in range(1, bufnr('$'))
    if bufexists(bufnr) && buflisted(bufnr) && getbufvar(bufnr, '&buftype') == ''
      call extend(items, s:collect_from_bufnr(bufnr))
    endif
  endfor

  return items
endfunction "  }}}1

function! s:collect_from_bufnr(bufnr)                                                   " {{{1
  " TODO!!!: implement s:collect_from_bufnr()
  let items = []

  let s:comment_marker = split(getbufvar(a:bufnr, '&commentstring'), '%s')[0]
  let s:pattern = '\(' . join(s:titles, '\|') . '\)' . '\(!\{,3}\)'
  let s:pattern = printf('^\s*%s\s*%s:\s*', s:comment_marker, s:pattern)
  let g:pattern = s:pattern

  let lines = getbufline(a:bufnr, 1, '$')
  for linenr in range(1, len(lines))
    if lines[linenr - 1] =~ s:pattern
      let item        = {}
      let item.bufnr  = a:bufnr
      let item.linenr = linenr
      let item.fname  = fnamemodify(bufname(a:bufnr), ':p')

      let line = lines[linenr - 1]
      let [item.title, item.priority] = matchlist(line, s:pattern)[1:2]
      " possible value: p, p!, p!!, p!!!
      let item.priority = 'p' . item.priority

      let item.text = line[matchend(line, s:pattern) : ]
      let item.text = s:strip_markers(item.text)

      call add(items, item)
    endif
  endfor

  return items
endfunction " }}}1

function! mudox#todo#main()                                                             " {{{1
  call s:open_todo_win()

  let items = s:collect()

  if g:items != items
    let g:items = items
    call s:show()
  endif
endfunction "  }}}1

function! s:open_todo_win(...)                                                          " {{{1
  " TODO!!: Qpen() here, and Qpen() need to change it's throw habit
  tab drop *TODO*
  let s:bufnr = bufnr('%')
  set filetype=mdxtodo
endfunction " }}}1

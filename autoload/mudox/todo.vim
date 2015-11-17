" vim: fdm=marker
" GUARD                                                                              {{{1
if exists("s:loaded") || &cp || version < 700
  finish
endif
let s:loaded = 1
" }}}1

scriptencoding utf8

" IDEA!!!: add each mapping's doc text within its' corresponding function.
" TODO: need a fallback suite of symbols
" TODO: need to honor user's choice
let s:symbol = {
      \ 'folded'    : '',
      \ 'unfolded'  : '',
      \ 'lnum'      : ' ',
      \ 'fline_cnt' : ' ',
      \ 'p!!!'      : '',
      \ 'p!!'       : ' ',
      \ 'p!'        : '  ',
      \ 'p'         : '   ',
      \ }
let mudox#todo#symbol = s:symbol

let s:titles = [
      \ 'TODO',
      \ 'ISSUE',
      \ 'IDEA',
      \ 'INFO',
      \ ]

" THE MODEL                                                                          {{{1

" the model object & it's old snapshot
" each item in it is a dict has keys:
"  fname: absolute path name
"  lnum: line number
"  ---
"  title: one of word from s:titles
"  priority: one of ['p', 'p!', 'p!!', 'p!!!']
"  text: text after 'TITLE:'
let s:m_items_old = []
let s:m_items = []
lockvar s:m_items

" fallback pattern used to parse files unloaded, capture groups are:
" [title, priority, text]
let s:m_pattern = '^.*\(' . join(s:titles, '\|') . '\)'
      \ . '\(!\{,3}\)'
      \ . '\s*:\s*'
      \ . '\(.*\)\s*$'

function! s:m_sort_items()                                                         " {{{2
  function! s:sort_by_lnum(l, r)
    let left = a:l.lnum
    let right = a:r.lnum
    return left == right ? 0 : left < right ? 1 : -1
  endfunction

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

  unlockvar s:m_items
  call sort(s:m_items, 's:sort_by_lnum')
  call sort(s:m_items, 's:sort_by_priority')
  call sort(s:m_items, 's:sort_by_title')
  call sort(s:m_items, 's:sort_by_fname')
  lockvar s:m_items
endfunction "  }}}2

function! s:m_mkitem(fname, lnum, line)                                            " {{{2
  " parse line, if is a valid item line, construct a dict
  " {
  "   'fname'    :
  "   'lnum'     :
  "   'title'    :
  "   'priority' :
  "   'text'     :
  " }
  " which can be added to s:m_items
  " otherwise, a empty dict is returned

  if a:line =~ s:m_pattern
    let item       = {}
    let item.fname = a:fname
    let item.lnum  = a:lnum

    let [item.title, item.priority, item.text] = matchlist(a:line, s:m_pattern)[1:3]
    let item.priority = 'p' . item.priority

    return item
  else
    return {}
  endif
endfunction " }}}2

function! s:m_collect_buf(bufnr)                                                   " {{{2
  let lines = getbufline(a:bufnr, 1, '$')
  let fname = fnamemodify(bufname(a:bufnr), ':p')

  for idx in range(len(lines))
    let line = lines[idx]
    let lnum = idx + 1
    let item = s:m_mkitem(fname, lnum, line)
    if !empty(item)
      call s:m_add_item(item)
    endif
  endfor
endfunction " }}}2

function! s:m_collect_file(fname)                                                  " {{{2
  if !filereadable(a:fname)
    return
  endif

  let lines = readfile(a:fname)
  for idx in range(len(lines))
    let line = lines[idx]
    let lnum = idx + 1
    let item = s:m_mkitem(a:fname, lnum, line)
    if !empty(item)
      call s:m_add_item(item)
    endif
  endfor
endfunction " }}}2

function! s:m_add_item(item)                                                       " {{{2
  " TODO: implement s:m_add_item(item)
  let w = len(string(a:item.lnum))
  if s:v.max_lnum_width < w
    let s:v.max_lnum_width = w
  endif

  let w = len(a:item.fname)

  if s:v.max_fname_width < w
    let s:v.max_fname_width = w
  endif


  call add(s:m_items, a:item)
endfunction " }}}2

function! s:m_collect()                                                            " {{{2
  " reset stat data
  let s:v.max_lnum_width  = 0
  let s:v.max_fname_width = 0

  unlockvar s:m_items
  let s:m_items = []

  " IDEA: is asynchronization necessary?
  " IDEA!: arg list can be handled by `ag`, add it in?

  " INFO: currently only watching listed buffers whose buftype is normal
  for bufnr in range(1, bufnr('$'))
    if bufexists(bufnr) && buflisted(bufnr) && getbufvar(bufnr, '&buftype') == ''
      if bufloaded(bufnr)
        call s:m_collect_buf(bufnr)
      else
        call s:m_collect_file(bufname(bufnr))
      end
    endif
  endfor

  if len(s:m_items) != 0
    call s:m_sort_items()
  else
    echohl WarningMsg
    echo 'TODO LIST: no todo list collect'
    echohl None
  endif

  lockvar s:m_items

  let s:v.max_cnt_width = len(string(len(s:m_items)))
endfunction "  }}}2

function! s:m_fname_set()                                                          " {{{2
  let fnames = []
  let fname = ''
  for item in s:m_items
    if item.fname != fname
      let fname = item.fname
      call add(fnames, fname)
    endif
  endfor
  return fnames
endfunction " }}}2
" }}}1

" THE VIEW                                                                           {{{1
" the view status object & it's old snapshot
let s:v_bufnr = 0

let s:v_old = {}
let s:v = {}

" fold[fname]: 1 for unfold, 0 for fold
let s:v.fold            = {}
let s:v.max_lnum_width  = 0
let s:v.max_fname_width = 0
let s:v.max_cnt_width   = 0

" patterns used for line identifying & highlighting
let s:v_tline_prefix = '   └'
let s:v_fline_prefix = printf(' \(%s\|%s\)', s:symbol.folded, s:symbol.unfolded)
let mudox#todo#v_fline_prefix = s:v_fline_prefix
let s:v_iline_prefix = repeat("\x20", 6)

function! s:v_show()                                                                 " {{{2

  " only draw when model & view status changed
  if s:v_old == s:v
        \ && s:m_items_old == s:m_items
        \ && s:v_old_pane_width == winwidth(winnr())
    return
  endif

  let s:v_old = deepcopy(s:v)
  let s:m_items_old = deepcopy(s:m_items)
  let s:v_old_pane_width = winwidth(winnr())

  let fname = ''
  let title = ''
  let lines = []
  for item in s:m_items
    " print file line if entering a new file section
    let unfolded = get(s:v.fold, item.fname, 0)

    if item.fname != fname
      let fname = item.fname
      let title = '' " must print whatever title next line if unfolded
      let fileline = s:v_fline(fname,
            \ unfolded ? 'unfolded' : 'folded')

      " first line MUST be empty line
      call extend(lines, [
            \ '',
            \ fileline,
            \ ])
    endif

    if !unfolded
      continue
    endif

    " print title lines & item lines if current section is unfolded
    " print title line if entering a new title section
    if item.title != title
      let title = item.title
      call add(lines, s:v_tline(title))
    endif
    call add(lines, s:v_iline(item))

  endfor

  setlocal modifiable
  silent %d_
  call append(0, lines) " last line MUST be empty line
  setlocal nomodifiable
endfunction "  }}}2

function! s:v_fline(fname, folded)                                                 " {{{2
  " a:folded: one of ['unfoled', 'folded']

  " figure out path width
  let pane_width = max([80, winwidth(winnr())])
  let prefix_width = 4
  let count_width = len(s:symbol.fline_cnt) + 1 + s:v.max_cnt_width
  if a:folded == 'folded'
    let path_width = pane_width - prefix_width - count_width
  else
    let path_width = pane_width - prefix_width
  endif

  if len(a:fname) > path_width
    let path_text = a:fname[ : path_width - 3 - 1] . '...'
  else
    let path_text = a:fname
  endif

  " items count text when section folded
  let fline_cnt = len(filter(copy(s:m_items), 'v:val.fname == a:fname'))
  let count_text = (a:folded == 'unfolded') ? ''
        \ : printf('%s %3s', s:symbol.fline_cnt, fline_cnt)

  " node symbol
  let node = (a:folded == 'folded') ? ' ' : '┐'

  let fmt = printf(' %%s %%s%%-%ds%%s', path_width)
  return printf(fmt,
        \ s:symbol[a:folded],
        \ node,
        \ path_text,
        \ count_text,
        \ )
endfunction "  }}}2

function! s:v_tline(title)                                                         " {{{2
  " TODO!!: add fancy symbol & item count to tline
  return printf('%s %s:', s:v_tline_prefix, a:title)
endfunction "  }}}2

function! s:v_is_tline(line)                                                       " {{{2
  return a:line =~ '^' . s:v_tline_prefix
endfunction "  }}}2

function! s:v_iline(item)                                                          " {{{2
  " compose item line for display
  let pane_width = max([80, winwidth(winnr())])
  let prefix_width = len(s:v_iline_prefix)
  " TODO: remove magic number for priority symbo width
  let priority_width = 4
  let suffix_width = 1 + len(s:symbol.lnum) + 1 + s:v.max_lnum_width
  let text_width = pane_width - prefix_width - priority_width - suffix_width

  " truncat text content if too long
  if len(a:item.text) > text_width
    let text = a:item.text[:text_width - 3 - 1] . '...'
  else
    let text = a:item.text
  endif

  let fmt = printf(' %%s %%-%dd', s:v.max_lnum_width)
  let suffix = printf(fmt, s:symbol.lnum, a:item.lnum)

  let fmt = printf('%%s%%s %%-%ds%%s', text_width)
  return printf(fmt,
        \ s:v_iline_prefix,
        \ s:symbol[a:item.priority],
        \ text,
        \ suffix,
        \ )
endfunction "  }}}2

function! s:v_is_item_line(line)                                                     " {{{2
  return a:line =~ '^' . s:v_iline_prefix
endfunction "  }}}2

function! s:v_open_win(...)                                                          " {{{2
  let bufname = '\|TODO\ LIST\|'

  " if *TODO* window is open in some tabpage, jump to it
  for i in range(tabpagenr('$'))
    if index(tabpagebuflist(i + 1), s:v_bufnr) != -1
      execute 'drop ' . bufname
      return
    endif
  endfor

  " else query & open in a new window
  call Qpen(bufname)
  let s:v_bufnr = bufnr('%')
  set filetype=mdxtodo
endfunction " }}}2

function! s:v_is_fline(line)                                                         " {{{2
  return a:line =~ '^' . s:v_fline_prefix
endfunction "  }}}2

function! s:v_seek_fline(lnum, which)                                                " {{{2
  " TODO!!!: a test suite for s:v_seek_fline()
  " a:lnum is for line()
  " a:which accepts one of 'next', 'cur', 'prev'
  " return:
  "   line number if a valid fline is found
  "   0 if not found
  " keep the cursor within the function body

  let pos = getcurpos()

  let flags = {
        \ 'next' : 'W',
        \ 'cur'  : 'Wbc',
        \ }

  call cursor(a:lnum, 1)

  let lnum = 0
  if a:which =~ 'next\|cur'
    let lnum = search(s:v_fline_prefix, flags[a:which])
  elseif a:which =~ 'prev'
    let lnum = search(s:v_fline_prefix, flags['cur'])
    if lnum == 0 || lnum == 1
      return 0
    endif
    call cursor(lnum - 1, 2)
    let lnum = search(s:v_fline_prefix, flags['cur'])
  else
    echoerr printf(
          \ 'a:which (%s) need a string of  [next, cur, prev] or a line number',
          \ a:which,
          \ )
  endif

  let startofline = &startofline
  set nostartofline
  call setpos('.', pos)
  let &startofline = startofline

  return lnum
endfunction " }}}2
let g:Test = function('s:v_seek_fline')

function! s:v_line2fname(line)                                                     " {{{2
  if ! s:v_is_fline(a:line)
    echoerr printf('invalid fname line: %s', a:line)
  endif

  return substitute(a:line, s:v_fline_prefix . ' .', '', '')
endfunction " }}}2

function! s:v_lnum2fname(lnum)                                                     " {{{2
  " a:lnum must be line number of a valid file line
  " this function is suppose to be used in conjunction with s:v_seek_fline()
  " to get the un-truncated absolute file path stored in s:m_items
  if !s:v_is_fline(getline(a:lnum))
    echoerr printf('%d is not a valid file line line number', a:lnum)
  endif

  let fnames = uniq(map(copy(s:m_items), 'v:val.fname'))

  let i = 0
  let ln = s:v_seek_fline(1, 'next')
  while ln != a:lnum
    let i += 1
    if i > len(fnames) - 1
      throw 'over loop'
    endif

    let ln = s:v_seek_fline(ln, 'next')
  endwhile

  return fnames[i]
endfunction " }}}2
let g:Test1 = function('s:v_lnum2fname')

function! s:v_lnum2item(lnum)                                                      " {{{2
  " a:lnum are the same as line(lnum)

  let line = getline(a:lnum)

  if ! s:v_is_item_line(line)
    return {}
  endif

  " get line number
  let ln = matchstr(line, '\d\+\ze\s*$') + 0

  " get file path
  let fname = s:v_lnum2fname(s:v_seek_fline(a:lnum, 'cur'))

  " look up the item by filename & lnum
  let items = filter(copy(s:m_items),
        \ 'v:val.fname == fname && v:val.lnum == ln')

  if len(items) != 1
    echoerr printf('%d matching items filtered, must be 1', len(items))
    call s:dbg_log(items)
  endif

  return items[0]
endfunction "  }}}2

" mapping implementations ------------------------------

function! mudox#todo#v_toggle_folding()                                            " {{{2
  let unfold_all = 1
  for unfolded in values(s:v.fold)
    if unfolded
      let unfold_all = 0
      break
    endif
  endfor

  for fname in s:m_fname_set()
    let s:v.fold[fname] = unfold_all
  endfor

  call mudox#todo#v_refresh()
endfunction " }}}2

function! mudox#todo#v_change_priority(delta)                                      " {{{2
  let col = col('.')

  " figure out the new priority: new_priority
  let item = s:v_lnum2item(line('.'))
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

  " TODO!!: need to add data view synchronization way

  " re-sort the items & re-show
  call s:v_show()

  " cursor follow the changed line
  let line_pat = s:v_iline(item)
  call cursor(0, 1)
  let lnum = search(line_pat, 'Wc' . a:delta == 1 ? 'b' : '')
  execute printf('normal! %dzz', lnum)

  " apply the change back
  execute 'edit ' . item.fname
  let line = getline(item.lnum)
  let line = substitute(line, item.title . '\zs.\{-}\ze:',
        \ item.priority[1:], '')
  call setline(item.lnum, line)
  update

  execute printf('buffer! %s', s:v_bufnr)

  let startofline = &startofline
  set nostartofline
  call cursor(lnum, col)
  let &startofline = startofline
endfunction "  }}}2

function! mudox#todo#v_nav_sec(which, ...)                                         " {{{2
  " accepts:
  "   a:which: ['next', 'prev', 'cur']
  "   a:1    : 1 to only unfold this section

  let lnum = s:v_seek_fline('.', a:which)

  if lnum
    let fname = s:v_lnum2fname(lnum)
    if a:0 == 1 && a:1 == 1
      let s:v.fold = {fname : 1}
    endif

    call s:v_show()

    call search(fname, 'w')
  endif
endfunction " }}}2

function! mudox#todo#v_goto_source()                                               " {{{2
  let item = s:v_lnum2item('.')
  if empty(item)
    return
  endif

  execute 'drop ' . item.fname
  execute printf('normal! %szz', item.lnum)
  silent! normal! zO
endfunction "  }}}2

function! mudox#todo#v_toggle_section_fold()                                       " {{{2
  let lnum = (s:v_seek_fline('.', 'cur'))
  if lnum == 0
    return
  endif

  let fline = getline(lnum)
  let fname = s:v_lnum2fname(lnum)
  let unfolded = ! (fline =~ s:symbol.unfolded)
  let s:v.fold[fname] = unfolded
  call mudox#todo#v_refresh()

  call search(fname, 'w')
endfunction " }}}2

function! mudox#todo#v_refresh()                                                   " {{{2
  let pos = getcurpos()

  call s:m_collect()
  call s:v_show()

  let startofline = &startofline
  set nostartofline
  call setpos('.', pos)
  let &startofline = startofline
endfunction "  }}}2

" }}}1

function! mudox#todo#main()                                                          " {{{1
  " TODO!!!: rethink about the window open way
  try
    call s:v_open_win()
  catch /^Qpen: Canceled$/
    echohl WarningMsg
    echo '* user canceled *'
    echohl None
    return
  endtry

  call mudox#todo#v_refresh()
endfunction "  }}}1

" LOGGING & DEBUG                                                                    {{{1
function! s:dbg_log(...)                                                           " {{{2
  redir! > /tmp/vim-todo.log

  echo 's:m_items ----'
  for i in s:m_items
    echo i
  endfor

  echo "\ns:v ----"
  echo s:v

  echo "\na:000 ----"
  echo a:000

  redir END
endfunction " }}}2
" }}}1

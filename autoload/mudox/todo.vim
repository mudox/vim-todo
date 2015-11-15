" vim: fdm=marker
" GUARD                                                                                {{{1
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
      \ 'folded'   : '',
      \ 'unfolded' : '',
      \ 'lnum'     : ' ',
      \ 'p!!!'     : '',
      \ 'p!!'      : ' ',
      \ 'p!'       : '  ',
      \ 'p'        : '   ',
      \ }
let mudox#todo#symbol = s:symbol

let s:titles = [
      \ 'TODO',
      \ 'ISSUE',
      \ 'IDEA',
      \ 'INFO',
      \ ]

" THE MODEL                                                                            {{{1

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

" fallback pattern used to parse files unloaded, capture groups are:
" [title, priority, text]
let s:m_pattern = '^.*\(' . join(s:titles, '\|') . '\)'
      \ . '\(!\{,3}\)'
      \ . '\s*:\s*'
      \ . '\(.*\)\s*$'

function! s:m_sort_items()                                                           " {{{2
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

  call sort(s:m_items, 's:sort_by_lnum')
  call sort(s:m_items, 's:sort_by_priority')
  call sort(s:m_items, 's:sort_by_title')
  call sort(s:m_items, 's:sort_by_fname')
endfunction "  }}}2

function! s:m_collect_buf(bufnr)                                                     " {{{2
  " INFO!!!: try use fallback pattern here to see the effect
  "let comment_marker = split(getbufvar(a:bufnr, '&commentstring'), '%s')[0]
  "let pattern = '\(' . join(s:titles, '\|') . '\)' . '\(!\{,3}\)'
  "let pattern = printf('^\s*%s\s*%s:\s*', comment_marker, pattern)

  let lines = getbufline(a:bufnr, 1, '$')
  for idx in range(len(lines))
    let line = lines[idx]
    if line =~ s:m_pattern
      let item        = {}

      let item.lnum = idx + 1
      let item.fname  = fnamemodify(bufname(a:bufnr), ':p')
      let [item.title, item.priority, item.text] = matchlist(line, s:m_pattern)[1:3]
      let item.priority = 'p' . item.priority

      call add(s:m_items, item)
    endif
  endfor
endfunction " }}}2

function! s:m_collect_file(fname)                                                    " {{{2
  " TODO: implement s:m_collect_file(fname)
  let lines = readfile(a:fname)
  for idx in range(len(lines))
    let line = lines[idx]
    if line =~ s:m_pattern
      let item        = {}

      let item.lnum = idx + 1
      let item.fname  = fnamemodify(a:fname, ':p')
      let [item.title, item.priority, item.text] =
            \ matchlist(line, s:m_pattern)[1:3]
      let item.priority = 'p' . item.priority

      call add(s:m_items, item)
    endif
  endfor
endfunction " }}}2

function! s:m_collect()                                                              " {{{2
  let s:m_items = []

  " IDEA!!: is asynchronization necessary?
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

  call s:m_sort_items()
endfunction "  }}}2

" }}}1

" THE VIEW                                                                             {{{1
" the view status object & it's old snapshot
let s:v_old = {}
let s:v = {}

" fold[fname]: 1 for unfold, 0 for fold
let s:v.fold = {}

" patterns used for line identifying & highlighting
let s:v_tline_prefix = '   └'
let s:v_fline_prefix = printf(' \(%s\|%s\)', s:symbol.folded, s:symbol.unfolded)
let mudox#todo#v_fline_prefix = s:v_fline_prefix
let s:v_iline_prefix = repeat("\x20", 6)

function! s:v_show()                                                                 " {{{2

  " only draw when model & view status changed
  if s:v_old == s:v && s:m_items_old == s:m_items
    return
  endif

  let s:v_old = deepcopy(s:v)
  let s:m_items_old = deepcopy(s:m_items)

  let fname = ''
  let title = ''
  let lines = []
  for item in s:m_items
    " print file line if entering a new file section
    let unfolded = get(s:v.fold, item.fname, 0)

    if item.fname != fname
      let fname = item.fname
      let fileline = s:v_fline(fname,
            \ unfolded ? 'unfolded' : 'folded')

      " first line MUST be empty line
      call extend(lines, [
            \ '',
            \ fileline,
            \ ])
    endif

    "if !unfolded
      "continue
    "endif

    " print title lines & item lines if current section is unfolded
    if get(s:v.fold, fname, 0)
      " print title line if entering a new title section
      if item.title != title
        let title = item.title
        call add(lines, s:v_tline(title))
      endif
      call add(lines, s:v_iline(item))
    endif

  endfor

  setlocal modifiable
  silent %d_
  call append(0, lines) " last line MUST be empty line
  setlocal nomodifiable
endfunction "  }}}2

function! s:v_fline(fname, folded)                                                   " {{{2

  " TODO!!: when closed show how many items it have
  let node = (a:folded == 'folded') ? ' ' : '┐'
  return printf(' %s %s%s',
        \ s:symbol[a:folded],
        \ node,
        \ a:fname,
        \ )
endfunction "  }}}2

function! s:v_tline(title)                                                           " {{{2
  return printf('%s %s:', s:v_tline_prefix, a:title)
endfunction "  }}}2

function! s:v_iline(item)                                                            " {{{2
  let max_text_width = 62
  if len(a:item.text) > max_text_width
    let text = a:item.text[:55] . ' ...'
  else
    let text = a:item.text
  endif

  return printf('%s%s %-' . max_text_width . 's %s',
        \ s:v_iline_prefix,
        \ s:symbol[a:item.priority],
        \ text,
        \ printf('%s %s', s:symbol.lnum, a:item.lnum),
        \ )
endfunction "  }}}2

function! s:v_open_win(...)                                                          " {{{2
  " TODO!!: Qpen() here, and Qpen() need to change it's throw habit
  tab drop *TODO*
  let s:bufnr = bufnr('%')
  set filetype=mdxtodo
endfunction " }}}2

function! s:v_is_fline(line)                                                         " {{{2
  return a:line =~ '^' . s:v_fline_prefix
endfunction "  }}}2

function! s:v_is_tline(line)                                                         " {{{2
  return a:line =~ '^' . s:v_tline_prefix
endfunction "  }}}2

function! s:v_is_item_line(line)                                                     " {{{2
  return a:line =~ '^' . s:v_iline_prefix
endfunction "  }}}2

function! s:v_seek_fline(lnum, which)                                                " {{{2
  " a:lnum is for line()
  " a:which accepts 2 kinds of values:
  " - a string that is one of 'next', 'cur', 'prev'
  " - a line number
  " return:
  "   line number if a valid fline is found
  "   0 if not found
  " keep the cursor within the function body

  let pos = getcurpos()

  let flags = {
        \ 'next' : 'W',
        \ 'cur'  : 'Wbc',
        \ 'prev' : 'Wb',
        \ }

  call cursor(line(a:lnum), 1)

  let lnum = 0
  if a:which =~ 'next\|cur\|prev'
    let lnum = search(s:v_fline_prefix, flags[a:which])
  elseif type(a:which) == type(1)
    let lnum = a:which
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

function! s:v_line2fname(line)                                                       " {{{2
  if ! s:v_is_fline(a:line)
    echoerr printf('invalid fname line: %s', a:line)
  endif

  return substitute(a:line, s:v_fline_prefix . ' .', '', '')
endfunction " }}}2

function! s:v_lnum2item(lnum)                                                        " {{{2
  " a:lnum are the same as line(lnum)

  let line = getline(a:lnum)

  if ! s:v_is_item_line(line)
    return {}
  endif

  " get line number
  let lnum = matchstr(line, '\d\+\ze\s*$') + 0

  " get file path
  let fname = s:v_line2fname(getline(s:v_seek_fline(lnum, 'cur')))

  " look up the item by filename & lnum
  let items = filter(copy(s:m_items),
        \ 'v:val.fname == fname && v:val.lnum == lnum')

  if len(items) != 1
    echoerr printf('%d matching items filtered, must be 1', len(items))
    call s:dbg_log(items)
  endif

  return items[0]
endfunction "  }}}2

function! s:v_toggle_folding()                                                       " {{{2
  " TODO!!: implement ui_toggle_folding()
endfunction " }}}2

" mapping implementations ------------------------------

function! mudox#todo#v_change_priority(delta)                                        " {{{2
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

  execute printf('buffer! %s', s:bufnr)

  let startofline = &startofline
  set nostartofline
  call cursor(lnum, col)
  let &startofline = startofline
endfunction "  }}}2

function! mudox#todo#v_nav_sec(which, ...)                                              " {{{2
  " accepts:
  "   a:which: ['next', 'prev', 'cur']
  "   a:1    : 1 to only unfold this section

  let lnum = s:v_seek_fline('.', a:which)

  if lnum
    let fname = s:v_line2fname(getline(lnum))
    if a:0 == 1 && a:1 == 1
      let s:v.fold = {fname : 1}
    endif

    call s:v_show()

    call search(fname, 'w')
  endif
endfunction " }}}2

function! mudox#todo#v_goto_source()                                                 " {{{2
  let item = s:v_lnum2item('.')
  if empty(item)
    return
  endif

  execute 'drop ' . item.fname
  execute printf('normal! %szz', item.lnum)
  silent! normal! zO
endfunction "  }}}2

function! mudox#todo#v_toggle_section_fold()                                         " {{{2
  let fline = getline(s:v_seek_fline('.', 'cur'))
  let fname = s:v_line2fname(fline)
  let folded = ! (fline =~ s:symbol.unfolded)
  let s:v.fold[fname] = folded
  call mudox#todo#v_refresh()
endfunction " }}}2

function! mudox#todo#v_refresh()                                                     " {{{2
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
  call s:v_open_win()
  call mudox#todo#v_refresh()
endfunction "  }}}1

" LOGGING & DEBUG {{{1
function! s:dbg_log(...) " {{{2
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

" vim: fdm=marker
" GUARD                                                                             {{{1
if exists('s:loaded')
  finish
endif
let s:loaded = 1
" }}}1

scriptencoding utf8

" ISSUE!!!: pool collecting porformance using VimL
" TODO!!!: make all function symbol independent
" IDEA!!!: add each mapping's doc text within its' corresponding function.
" TODO!!!: need a fallback suite of symbols
" TODO: need to honor user's choice
let s:symbol = {
      \ 'folded'        : ''    ,
      \ 'unfolded'      : ''    ,
      \ 'lnum'          : ' '   ,
      \ 'lnum_active'   : ' '   ,
      \ 'lnum_inactive' : ' '   ,
      \ 'fline_cnt'     : ' '   ,
      \ 'p!!!'          : ''  ,
      \ 'p!!'           : ' '  ,
      \ 'p!'            : '  '  ,
      \ 'p'             : '   '  ,
      \ }
let g:mudox#todo#symbol = s:symbol

let s:titles = [
      \ 'TODO',
      \ 'ISSUE',
      \ 'IDEA',
      \ 'INFO',
      \ ]

" THE MODEL                                                                         {{{1

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

function! s:m_sort_items() abort                                                  " {{{2
  function! s:sort_by_lnum(l, r) abort
    let left = a:l.lnum
    let right = a:r.lnum
    return left == right ? 0 : left < right ? 1 : -1
  endfunction

  function! s:sort_by_priority(l, r) abort
    let left = a:l.priority
    let right = a:r.priority
    return left == right ? 0 : left < right ? 1 : -1
  endfunction

  function! s:sort_by_title(l, r) abort

    let left = index(s:titles, a:l.title)
    let right = index(s:titles, a:r.title)
    return left == right ? 0 : left > right ? 1 : -1
  endfunction

  function! s:sort_by_fname(l, r) abort
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

function! s:m_mkitem(fname, lnum, line) abort                                     " {{{2
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

function! s:m_collect_buf(bufnr) abort                                            " {{{2
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

function! s:m_collect_file(fname) abort                                           " {{{2
  if !filereadable(a:fname)
    return
  endif

  let lines = readfile(a:fname)
  for idx in range(len(lines))
    let line = lines[idx]
    let lnum = idx + 1
    let item = s:m_mkitem(fnamemodify(a:fname, ':p'), lnum, line)
    if !empty(item)
      call s:m_add_item(item)
    endif
  endfor
endfunction " }}}2

function! s:m_add_item(item) abort                                                " {{{2
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

function! s:m_collect() abort                                                     " {{{2
  " reset stat data
  let s:v.max_lnum_width  = 0
  let s:v.max_fname_width = 0

  unlockvar s:m_items
  let s:m_items = []

  " IDEA: is asynchronization necessary?
  " IDEA!: arg list can be handled by `ag`, add it in?

  " INFO: currently only watching listed buffers whose buftype is normal
  for bufnr in range(1, bufnr('$'))
    if buflisted(bufnr) && getbufvar(bufnr, '&buftype') ==# ''
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

function! s:m_fname_set() abort                                                   " {{{2
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

" THE VIEW                                                                          {{{1
" the view status object & it's old snapshot
let s:v_bufnr = 0

let s:v_old = {}
let s:v = {}

" fold[fname]: 1 for unfold, 0 for fold
let s:v.fold            = {}
" { fname : lnum }
let s:v.flines          = {}
" { printf('%s@%s', fname, title) : lnum }
let s:v.tlines          = {}
" { string(item) : lnum }
let s:v.ilines          = {}
let s:v.max_lnum_width  = 0
let s:v.max_fname_width = 0
let s:v.max_cnt_width   = 0

" patterns used for line identifying & highlighting
let s:v_tline_prefix = '   └'
let s:v_fline_prefix = printf(' \(%s\|%s\)', s:symbol.folded, s:symbol.unfolded)
let g:mudox#todo#v_fline_prefix = s:v_fline_prefix
let s:v_iline_prefix = repeat("\x20", 6)

function! s:v_goto_fline(fname) abort                                             " {{{2
  if ! has_key(s:v.flines, a:fname)
    throw printf('invalid file name: %s', a:fname)
  endif

  let lnum = s:v.flines[a:fname]

  call s:v_stay(lnum, stridx(getline(lnum), '/') + 1)
endfunction " }}}2

function! s:v_goto_iline(item) abort                                              " {{{2
  if ! has_key(s:v.ilines, string(a:item))
    throw printf('invalid item: %s', string(a:item))
  endif

  let col_num = col('.')
  let lnum = s:v.ilines[string(a:item)]

  call s:v_stay(lnum, col_num)
endfunction " }}}2

function! s:v_show() abort                                                        " {{{2
  let s:v.pane_width = winwidth(winnr())

  " only draw when model & view status changed
  if s:v_old == s:v
        \ && s:m_items_old == s:m_items
    return
  endif

  " backup old view status
  let s:v_old = deepcopy(s:v)
  let s:m_items_old = deepcopy(s:m_items)

  let s:v.flines = {}
  let s:v.tlines = {}
  let s:v.ilines = {}

  let fname = ''
  let title = ''
  let lines = []
  let lnum  = 0

  for item in s:m_items
    let unfolded = get(s:v.fold, item.fname, 0)

    " fline
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
      let lnum += 2
      let s:v.flines[fname] = lnum
    endif

    if !unfolded
      continue
    endif

    " print title lines & item lines if current section is unfolded
    " print title line if entering a new title section
    if item.title != title
      let title = item.title
      call add(lines, s:v_tline(title))
      let lnum += 1
      let s:v.tlines[printf('%s@%s', fname, title)] = lnum
    endif

    call add(lines, s:v_iline(item))
    let lnum += 1
    let s:v.ilines[string(item)] = lnum
  endfor

  setlocal modifiable
  silent %d_
  call append(0, lines) " last line MUST be empty line
  setlocal nomodifiable
endfunction "  }}}2

function! s:v_fline(fname, folded) abort                                          " {{{2
  " a:folded: one of ['unfoled', 'folded']

  " figure out path width
  let pane_width = max([80, winwidth(winnr())]) - 3
  let prefix_width = 4
  let count_width = len(s:symbol.fline_cnt) + 1 + s:v.max_cnt_width
  if a:folded ==# 'folded'
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
  let count_text = (a:folded ==# 'unfolded') ? ''
        \ : printf('%s %3s', s:symbol.fline_cnt, fline_cnt)

  " node symbol
  let node = (a:folded ==# 'folded') ? ' ' : '┐'

  let fmt = printf(' %%s %%s%%-%ds%%s', path_width)
  return printf(fmt,
        \ s:symbol[a:folded],
        \ node,
        \ path_text,
        \ count_text,
        \ )
endfunction "  }}}2

function! s:v_tline(title) abort                                                  " {{{2
  return printf('%s %s:', s:v_tline_prefix, a:title)
endfunction "  }}}2

function! s:v_is_tline(line) abort                                                " {{{2
  return a:line =~ '^' . s:v_tline_prefix
endfunction "  }}}2

function! s:v_iline(item) abort                                                   " {{{2
  " compose item line for display
  let pane_width = max([80, winwidth(winnr())])
  let prefix_width = len(s:v_iline_prefix)
  " TODO: remove magic number for priority symbo width
  let priority_width = 4
  let suffix_width = 1 + len(s:symbol.lnum) + 1 + s:v.max_lnum_width
  let text_width = pane_width - prefix_width - priority_width - suffix_width - 3

  " truncat text content if too long
  if len(a:item.text) > text_width
    let text = a:item.text[ : text_width - 3 - 1] . '...'
  else
    let text = a:item.text
  endif

  let fmt = printf(' %%s %%-%dd', s:v.max_lnum_width)
  let suffix_symbol = s:v_opened_win(a:item.fname)
        \ ? s:symbol.lnum_active : s:symbol.lnum_inactive
  let suffix = printf(fmt, suffix_symbol, a:item.lnum)

  let fmt = printf('%%s%%s %%-%ds%%s', text_width)
  return printf(fmt,
        \ s:v_iline_prefix,
        \ s:symbol[a:item.priority],
        \ text,
        \ suffix,
        \ )
endfunction "  }}}2

function! s:v_is_item_line(line) abort                                            " {{{2
  return a:line =~ '^' . s:v_iline_prefix
endfunction "  }}}2

function! s:v_opened_win(fname) abort                                             " {{{2
  let bufnr = bufnr(a:fname)
  if bufnr == -1
    return 0
  endif

  for i in range(tabpagenr('$'))
    if index(tabpagebuflist(i + 1), bufnr) != -1
      return 1
    endif
  endfor

  return 0
endfunction " }}}2

function! s:v_open_win(...) abort                                                 " {{{2
  let bufname = '|TODO LIST|'

  " if *TODO* window is open in some tabpage, jump to it
  if s:v_opened_win(bufname)
    execute 'drop ' . fnameescape(bufname)
    return
  endif

  " else query & open in a new window
  call g:Qpen(fnameescape(bufname))
  let s:v_bufnr = bufnr('%')
  set filetype=mdxtodo
endfunction " }}}2

function! s:v_seek_fline(lnum, which) abort                                       " {{{2
  " a:lnum must be a valid line number
  " a:which accepts one of 'next', 'cur', 'prev'
  " return:
  "   line number if a valid fline is found
  "   0 if not found

  " argument check
  if type(a:lnum) != type(1)
    echoerr printf('invalid a:lnum (%s), need a integer line number', a:lnum)
  endif

  if a:which !~ '^\C\%(prev\|cur\|next\)$'
    echoerr printf(
          \ 'invalid a:which (%s), need one of [prev, cur, next]',
          \ a:which)
  endif

  let lnums = values(s:v.flines)
  call sort(lnums, 'n')

  let found = 0
  if a:which ==# 'next'
    for i in range(len(lnums))
      if lnums[i] > a:lnum
        let found = 1
        break
      endif
    endfor
    return found ? lnums[i] : 0
  elseif a:which ==# 'cur'
    for i in range(len(lnums) - 1, 0, -1)
      if lnums[i] <= a:lnum
        let found = 1
        break
      endif
    endfor
    return found ? lnums[i] : 0
  elseif a:which ==# 'prev'
    let cur_lnum = s:v_seek_fline(a:lnum, 'cur')
    if cur_lnum
      return s:v_seek_fline(cur_lnum - 1, 'cur')
    else
      return 0
    endif
  endif
endfunction " }}}2

function! s:v_lnum2fname(lnum) abort                                              " {{{2
  " a:lnum must be valid fline line number

  for [f, l] in items(s:v.flines)
    if l == a:lnum
      return f
    endif
  endfor

  echoerr printf('a:lnum (%d) is not a valid file line line number', a:lnum)
endfunction " }}}2

function! s:v_lnum2item(lnum) abort                                               " {{{2
  " a:lnum is a line number integer

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

function! mudox#todo#v_toggle_folding(...) abort                                  " {{{2
  if a:0 == 1
    if a:1 == 'folded'
      let unfold = 0
    elseif a:1 == 'unfolded'
      let unfold = 1
    else
      echoerr printf('invalid argument [%s], need "folded" or "unfolded"',
            \ a:1)
    endif
  elseif a:0 == 0
    let unfold = ! search('^' . s:v_iline_prefix, 'wcn')
  else
    echoerr printf(
          \ "%d arguments received, need 0 or 1 ('folded' or 'unfolded')",
          \ a:0)
  endif

  for item in s:m_items
    let s:v.fold[item.fname] = unfold
  endfor

  let lnum = s:v_seek_fline(line('.'), 'cur')
  if lnum != 0
    let fname = s:v_lnum2fname(lnum)
  endif
  call s:v_show()
  if lnum != 0
    call s:v_goto_fline(fname)
  endif
endfunction " }}}2

function! mudox#todo#v_change_priority(delta) abort                               " {{{2
  " a:delta accepts 2 valus: +1 or -1

  " check the existance of source line, if not prompt user to refresh first
  " also change if it can be modified

  " figure out the new priority: new_priority
  let item = s:v_lnum2item(line('.'))
  if empty(item)
    return
  endif

  let src_line = getbufline(item.fname, item.lnum)[0]
  let src_item = s:m_mkitem(item.fname, item.lnum, src_line)
  if src_item != item
    echohl WarningMsg
    echo 'source file has been change, press "r" to refresh the content first'
    echohl None
    return
  endif

  if a:delta == +1 && len(item.priority) < 4
    let item.priority .= '!'
  elseif a:delta == -1 && len(item.priority) > 1
    let item.priority = item.priority[:-2]
  else
    echoerr printf('invalid argument (%s), need +1 or -1', a:delta)
  endif

  " apply the change back
  execute printf('buffer! %s', bufnr(item.fname))
  let line = getline(item.lnum)
  let line = substitute(line, item.title . '\zs.\{-}\ze:',
        \ item.priority[1:], '')
  call setline(item.lnum, line)
  update
  execute printf('buffer! %s', s:v_bufnr)

  call s:v_show()

  " cursor follow the changed line
  call s:v_goto_iline(item)
endfunction "  }}}2

function! mudox#todo#v_nav_sec(which, ...) abort                                  " {{{2
  " accepts:
  "   a:which: ['next', 'prev', 'cur']
  "   a:1    : 1 to only unfold this section

  let lnum = s:v_seek_fline(line('.'), a:which)

  if lnum
    let fname = s:v_lnum2fname(lnum)
    if a:0 == 1 && a:1 == 1
      let s:v.fold = {fname : 1}
      call s:v_show()
    endif

    call search(fname, 'w')
  endif
endfunction " }}}2

function! s:v_stay(line, column) abort                                            " {{{2
  let startofline = &startofline
  set nostartofline
  call cursor(a:line, a:column)
  let &startofline = startofline
endfunction " }}}2

function! mudox#todo#v_goto_source() abort                                        " {{{2
  let item = s:v_lnum2item(line('.'))
  if empty(item)
    return
  endif

  execute 'drop ' . item.fname
  execute printf('normal! %szz', item.lnum)
  silent! normal! zO
endfunction "  }}}2

function! mudox#todo#v_toggle_section_fold() abort                                " {{{2
  let flnum = (s:v_seek_fline(line('.'), 'cur'))
  if flnum == 0
    return
  endif

  let fline = getline(flnum)
  let fname = s:v_lnum2fname(flnum)
  let unfolded = ! (fline =~ s:symbol.unfolded)
  let s:v.fold[fname] = unfolded
  call s:v_show()

  call s:v_goto_fline(fname)
endfunction " }}}2

function! mudox#todo#v_refresh() abort                                            " {{{2
  let lnum = line('.')
  let col_num = col('.')

  call s:m_collect()
  call s:v_show()

  call s:v_stay(lnum, col_num)
endfunction "  }}}2

" }}}1

function! mudox#todo#main() abort                                                 " {{{1
  " TODO!: rethink about the window open way
  let fname = fnamemodify(bufname('%'), ':p')
  let lnum  = line('.')
  let item  = s:m_mkitem(fname, lnum, getline('.'))

  let s:v.fold[fname] = 1

  call s:m_collect()
  if empty(s:m_items)
    return
  endif

  try
    call s:v_open_win()
  catch /^Qpen: Canceled$/
    echohl WarningMsg
    echo '* user canceled *'
    echohl None
    return
  endtry

  call s:v_show()

  " if on a valid item source line, jump to the corresponding item line in the
  " todo window
  " else if the file has a source item line, jump to the file section in the
  " toto window
  " else stay put
  if ! empty(item)
    call s:v_goto_iline(item)
  else
    let idx = match(s:m_items, string({'fname': fname})[1:-2])
    if idx != -1
      call s:v_goto_iline(s:m_items[idx])
    endif
  endif
endfunction "  }}}1

" LOGGING & DEBUG                                                                   {{{1
function! s:dbg_log(title, ...) abort                                             " {{{2
  redir! > /tmp/vim-todo.log
  echo 'Debug Logging: ' . a:title
  echo

  echo 's:m_items ----'
  for i in s:m_items
    echo i
  endfor

  echo "\ns:v ----"
  echo 'flines'
  for [k, v] in items(s:v.flines)
    echo printf('%s -> %d', k, v)
  endfor
  echo 'tlines'
  for [k, v] in items(s:v.tlines)
    echo printf('%s -> %d', k, v)
  endfor
  echo 'ilines'
  for [k, v] in items(s:v.ilines)
    echo printf('%s -> %d', k, v)
  endfor

  echo "\na:000 ----"
  echo a:000

  redir END
endfunction " }}}2
" }}}1

" TODO!: autocmd to refresh after entering todo window

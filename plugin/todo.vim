" vim: fdm=marker
" TODO!!!: make it a plugin
scriptencoding utf8

let g:items = []
let s:files = []

" TODO: need a fallback suite of symbols
" TODO: need to honor user's choice
let s:symbol = {
      \ 'folded'   : '',
      \ 'unfolded' : '',
      \ 'p!!!'     : '',
      \ 'p!!'      : ' ',
      \ 'p!'       : '  ',
      \ 'p'        : '   ',
      \ 'linenr'   : ' ',
      \ }
let s:titles = [
      \ 'TODO',
      \ 'ISSUE',
      \ 'IDEA',
      \ ]
let s:comment_marker = split(&commentstring, '%s')[0]
let s:pattern = '\(' . join(s:titles, '\|') . '\)' . '\(!\{,3}\)'
let s:pattern = printf('^\s*%s\s*%s:\s*', s:comment_marker, s:pattern)
let g:mdx_pat = s:pattern

function! s:strip_markers(line)                                       " {{{1
  let comment_prefix = split(&commentstring, '%s')[0]
  let markers_pat = substitute(&foldmarker, ',', '\\|', '')
  let pattern = printf('\s*\%(%s\)\s*\%(%s\)\d\?\s*',
        \ comment_prefix,
        \ markers_pat,
        \ )
  return substitute(a:line, pattern, ' ', '')
endfunction "  }}}1

function! s:pick()                                                    " {{{1
  let item = {}
  let item.bufnr = bufnr('%')
  let item.linenr = line('.')
  let item.fname = fnamemodify(bufname('%'), ':p')

  let line = getline('.')
  echo matchlist(line, s:pattern)
  let [item.title, item.priority] = matchlist(line, s:pattern)[1:2]
  let item.priority = 'p' . item.priority

  let item.text = line[matchend(line, s:pattern) : ]
  let item.text = s:strip_markers(item.text)

  call add(g:items, item)
endfunction "  }}}1

function! s:handle_file()                                             " {{{1
  if &buftype != ''
    return
  endif

  let full_path = fnamemodify(bufname('%'), ':p')
  if index(s:files, full_path) != -1
    return
  else
    call add(s:files, full_path)
  endif

  execute 'g/' . s:pattern . '/call s:pick()'
endfunction "  }}}1

function! s:sort_items()                                              " {{{1
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

function! s:is_file_line(line)                                            " {{{1
  return a:line =~ '^' . s:file_line_prefix
endfunction "  }}}1

function! s:is_title_line(line)                                           " {{{1
  return a:line =~ '^' . s:title_line_prefix
endfunction "  }}}1

function! s:is_item_line(line)                                            " {{{1
  return a:line =~ '^' . s:item_line_prefix
endfunction "  }}}1

function! s:line2item()                                               " {{{1
  if ! s:is_item_line(getline('.'))
    return {}
  endif

  let cnt = 0

  " get line number
  let linenr = matchstr(getline('.'), '\d\+\ze\s*$') + 0

  " get file path
  for nr in range(line('.'), 1, -1)
    if s:is_file_line(getline(nr))
      " ISSUE: magic number for prefixing bytes
      let fname = strpart(getline(nr), 15)
    endif
  endfor

  " look up the item by filename & linenr
  for item in g:items
    if item.linenr == linenr && item.fname == fname
      return item
    endif
  endfor
  echoerr printf('fail looking up item: %s|%s', fname, linenr)
endfunction "  }}}1

function! s:on_enter()                                                " {{{1
  let item = s:line2item()
  if empty(item)
    return
  endif

  execute 'drop ' . item.fname
  execute printf('normal! %szz', item.linenr)
  silent! normal! zO
endfunction "  }}}1

function! s:refresh()                                                 " {{{1
  let pos = getcurpos()
  call MakeToDo()
  call setpos('.', pos)
endfunction "  }}}1

function! s:change_priority(delta)                                    " {{{1
  let item = s:line2item()
  if empty(item)
    "call setpos('.', pos)
    return
  endif

  if a:delta == +1 && len(item.priority) < 4
    let item.priority .= '!'
  elseif a:delta == -1 && len(item.priority) > 1
    let item.priority = item.priority[:-2]
  else
    return
  endif

  " update view
  call s:show()

  " cursor follow the changed line
  let line_pat = s:item_line(item)
  let linenr = index(getline(1, '$'), line_pat)
  execute printf('normal! %dzz', linenr + 1)

  " apply the change back to buffer
  let pos = [0, line('.'), col('.'), 0]
  execute 'edit ' . item.fname
  let line = getline(item.linenr)
  let line = substitute(line, item.title . '\zs.\{-}\ze:',
        \ item.priority[1:], '')

  execute printf('buffer! %s', s:bufnr)
  call setline(item.linenr, line)
  call setpos('.', pos)
endfunction "  }}}1

function! s:show()                                                    " {{{1
  call s:sort_items()

  let fname = ''
  let lines = []
  let title = ''
  for item in g:items
    if item.fname != fname
      let fname = item.fname
      call extend(lines, [
            \ '',
            \ s:file_line(fname, 'unfolded')
            \ ])
    endif

    if item.title != title
      let title = item.title
      call add(lines, s:title_line(title))
    endif

    call add(lines, s:item_line(item))
  endfor

  tab drop todo\ list
  let s:bufnr = bufnr('')
  " TODO!!: move buffter settings to under /ftplugin
  setlocal buftype=nofile

  " mappings
  nnoremap <silent><buffer> <Cr> :<C-U>call <SID>on_enter()<Cr>
  nnoremap <silent><buffer> - :<C-U>call <SID>change_priority(-1)<Cr>
  nnoremap <silent><buffer> + :<C-U>call <SID>change_priority(1)<Cr>
  nnoremap <silent><buffer> R :<C-U>call <SID>refresh()<Cr>
  " TODO!: mapping <C-N/P> to navigating
  " TODO!: mapping o toggle folding


  " TODO!: move syntax settings to under /syntax
  call clearmatches()
  highlight todoHigh guifg=#ffffff

  let fg = synIDattr(synIDtrans(hlID('todoHigh')), 'fg#')

  let fg = substitute(fg, '[^#]\{2}',
        \ '\=printf("%x", "0x". submatch(0) - 0x35)', 'g')
  silent execute printf('highlight todoMedium guifg=%s', fg)

  let fg = substitute(fg, '[^#]\{2}',
        \ '\=printf("%x", "0x". submatch(0) - 0x25)', 'g')
  silent execute printf('highlight todoLow guifg=%s', fg)

  let fg = substitute(fg, '[^#]\{2}',
        \ '\=printf("%x", "0x". submatch(0) - 0x25)', 'g')
  silent execute printf('highlight todoNormal guifg=%s', fg)

  call matchadd('todoHigh', '  .*$')
  call matchadd('todoMedium', '  .*$')
  call matchadd('todoLow', '  .*$')
  call matchadd('todoNormal', '^ \{9}\zs.*$')

  call matchadd('Keyword','└ .*$')
  call matchadd('Comment','└\| ┐')
  call matchadd('String', ' ┐\zs.*$')
  call matchadd('SpecialChar', '')

  setlocal modifiable
  %d_
  call append(0, lines)
  setlocal nomodifiable
  normal! 1G
endfunction "  }}}1

function! s:file_line(fname, folded)                                  " {{{1
  let s:file_line_prefix = '.*┐'

  if exists('*WebDevIconsGetFileTypeSymbol')
    let ft_symbol = WebDevIconsGetFileTypeSymbol(a:fname)
  else
    let ft_symbol = ''
  end

  return printf(' %s ┐ %s %s',
        \ s:symbol[a:folded],
        \ ft_symbol,
        \ a:fname,
        \ )
endfunction "  }}}1

function! s:title_line(title)                                         " {{{1
  let s:title_line_prefix = '   └'
  return printf('%s %s:', s:title_line_prefix, a:title)
endfunction "  }}}1

function! s:item_line(item)                                           " {{{1
  let max_text_width = 62
  if len(a:item.text) > max_text_width
    let text = a:item.text[:55] . ' ...'
  else
    let text = a:item.text
  endif

  let s:item_line_prefix = repeat("\x20", 5)
  return printf('%s%s %-' . max_text_width . 's %s',
        \ s:item_line_prefix,
        \ s:symbol[a:item.priority],
        \ text,
        \ printf('%s %s', s:symbol.linenr, a:item.linenr),
        \ )
endfunction "  }}}1

function! s:update_items()                                            " {{{1
  " IDEA!!!: the bufdo & argdo may not be the efficient way
  " IDEA: can tab drop here
  " ISSUE: is this marking way robust?
  mark Y
  silent bufdo call s:handle_file()
  if argc() > 0
    silent argdo call s:handle_file()
  endif
  normal! g`Y
endfunction "  }}}1

function! g:MakeToDo()                                                " {{{1
  call s:update_items()
  call s:show()
endfunction "  }}}1

silent call MakeToDo()

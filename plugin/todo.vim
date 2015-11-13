" vim: fdm=marker
" TODO!!!: make it a plugin
scriptencoding utf8

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
let s:titles = [
      \ 'TODO',
      \ 'ISSUE',
      \ 'IDEA',
      \ ]
let s:comment_marker = split(&commentstring, '%s')[0]
let s:pattern = '\(' . join(s:titles, '\|') . '\)' . '\(!\{,3}\)'
let s:pattern = printf('^\s*%s\s*%s:\s*', s:comment_marker, s:pattern)
let g:mdx_pat = s:pattern

function! s:line2fname(which)                                                        " {{{1
  " TODO!!!: refactor it with new parameter types
  " a:which accepts 2 kinds of values,
  "   a string that is one of 'next', 'cur', 'prev'
  "   a line number

  let flags = {
        \ 'next' : 'Wn',
        \ 'cur'  : 'Wnbc',
        \ 'prev' : 'Wnbc',
        \ }
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
endfunction " }}}1

function! s:on_o()                                                                   " {{{1
  let pos = getcurpos()

  let line = getline('.')
  if s:is_file_line(line) && line =~ s:symbol.folded

    " unfold section
    let lnum = line('.')
    let fname = s:line2fname(lnum)
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

  elseif line =~ s:symbol.unfolded || s:is_title_line(line) || s:is_item_line(line)

    " fold section
    let lnum = line('.')
    for i in range(lnum, line('$'))
      if getline(i) == ''
        let end_nr = i - 1
        break
      endif
    endfor
    for i in range(lnum, 1, -1)
      if s:is_file_line(getline(i))
        let start_nr = i + 1
        break
      endif
    endfor

    setlocal modifiable
    silent execute printf('%s,%sd _', start_nr, end_nr)
    let fname = s:line2fname(start_nr - 1)
    call setline(start_nr - 1, s:file_line(fname, 'folded'))
    setlocal nomodifiable

    normal! gk
  endif

endfunction " }}}1

function! s:on_zi()                                                                  " {{{1
  " TODO!!!: implement on_zx()
endfunction " }}}1

function! s:on_zx()                                                                  " {{{1
  " TODO!!!: implement on_zi()
  let fname = s:line2fname('cur')
  if !empty(fname)
    call s:show(fname)
  endif
  call search(fname, 'w')
endfunction " }}}1

function! s:strip_markers(line)                                                      " {{{1
  let comment_prefix = split(&commentstring, '%s')[0]
  let markers_pat = substitute(&foldmarker, ',', '\\|', '')
  let pattern = printf('\s*\%(%s\)\s*\%(%s\)\d\?\s*',
        \ comment_prefix,
        \ markers_pat,
        \ )
  return substitute(a:line, pattern, ' ', '')
endfunction "  }}}1

function! s:pick()                                                                   " {{{1
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

function! s:handle_file()                                                            " {{{1
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

function! s:sort_items()                                                             " {{{1
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

function! s:nav_section(dir)                                                         " {{{1
  let pos = getcurpos()

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

  let fname = s:line2fname(lnum)
  call s:show(fname)

  call search(fname)

endfunction " }}}1

function! s:is_file_line(line)                                                       " {{{1
  return a:line =~ '^' . s:file_line_prefix
endfunction "  }}}1

function! s:is_title_line(line)                                                      " {{{1
  return a:line =~ '^' . s:title_line_prefix
endfunction "  }}}1

function! s:is_item_line(line)                                                       " {{{1
  return a:line =~ '^' . s:item_line_prefix
endfunction "  }}}1

function! s:line2item()                                                              " {{{1
  if ! s:is_item_line(getline('.'))
    return {}
  endif

  let cnt = 0

  " get line number
  let lnum = matchstr(getline('.'), '\d\+\ze\s*$') + 0

  " get file path
  for nr in range(line('.'), 1, -1)
    if s:is_file_line(getline(nr))
      let fname = s:line2fname(nr)
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
endfunction "  }}}1

function! s:on_enter()                                                               " {{{1
  let item = s:line2item()
  if empty(item)
    return
  endif

  execute 'drop ' . item.fname
  execute printf('normal! %szz', item.linenr)
  silent! normal! zO
endfunction "  }}}1

function! s:refresh()                                                                " {{{1
  let pos = getcurpos()

  call MakeToDo()

  let startofline = &startofline
  set nostartofline
  call setpos('.', pos)
  let &startofline = startofline
endfunction "  }}}1

function! s:change_priority(delta)                                                   " {{{1
  let col = col('.')

  let item = s:line2item()
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

  " update view
  call s:show()

  " cursor follow the changed line
  let line_pat = s:item_line(item)
  call cursor(0, 1)
  let lnum = search(line_pat, 'Wc' . a:delta == 1 ? 'b' : '')
  execute printf('normal! %dzz', lnum)

  " apply the change back to buffer
  execute 'edit ' . item.fname
  let line = getline(item.linenr)
  let line = substitute(line, item.title . '\zs.\{-}\ze:',
        \ item.priority[1:], '')

  execute printf('buffer! %s', s:bufnr)
  call setline(item.linenr, line)
  update

  call cursor(lnum, col)
endfunction "  }}}1

function! s:show(...)                                                                " {{{1
  " if arg1 is given and is a file path, then only unfold this file's secition

  if a:0 > 1
    echoerr 'need 0 or 1 argument (file name)'
  endif

  let only_unfold_file = ''
  if a:0 == 1
    let only_unfold_file = a:1
  endif

  call s:sort_items()

  let fname = ''
  let title = ''
  let lines = []
  for item in g:items

    " print file line if entering a new file section
    if item.fname != fname
      let fname = item.fname
      if (!empty(only_unfold_file) && only_unfold_file == fname)
            \ || empty(only_unfold_file)
        let fileline = s:file_line(fname, 'unfolded')
      else
        let fileline = s:file_line(fname, 'folded')
      endif

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

  tab drop todo\ list
  let s:bufnr = bufnr('')
  " TODO!!: move buffter settings to under /ftplugin
  setlocal buftype=nofile

  " mappings
  nnoremap <silent><buffer> <Cr>  :<C-U>call <SID>on_enter()<Cr>
  nnoremap <silent><buffer> -     :<C-U>call <SID>change_priority(-1)<Cr>
  nnoremap <silent><buffer> +     :<C-U>call <SID>change_priority(1)<Cr>
  nnoremap <silent><buffer> r     :<C-U>call <SID>refresh()<Cr>
  nnoremap <silent><buffer> o     :<C-U>call <SID>on_o()<Cr>
  nnoremap <silent><buffer> q     :close<Cr>
  nnoremap <silent><buffer> <C-n> :<C-U>call <SID>nav_section(1)<Cr>
  nnoremap <silent><buffer> <C-p> :<C-U>call <SID>nav_section(-1)<Cr>
  nnoremap <silent><buffer> zx    :<C-U>call <SID>on_zx()<Cr>

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

  " ISSUE!!: magic symbol here, remove them all
  call matchadd('todoHigh', '  .*$')
  call matchadd('todoMedium', '  .*$')
  call matchadd('todoLow', '  .*$')
  call matchadd('todoNormal', '^ \{9}\zs.*$')

  call matchadd('Keyword','└\zs.*$')
  call matchadd('Comment','└\|┐', 100)
  call matchadd('String', s:file_line_prefix . '.\zs.*$')
  call matchadd('Type', s:file_line_prefix)

  setlocal modifiable
  %d_
  call append(0, lines) " last line MUST be empty line
  setlocal nomodifiable
  normal! 1G
endfunction "  }}}1

function! s:file_line(fname, folded)                                                 " {{{1
  let s:file_line_prefix = printf(' \(%s\|%s\)', s:symbol.folded, s:symbol.unfolded)

  let node = (a:folded == 'folded') ? ' ' : '┐'
  return printf(' %s %s%s',
        \ s:symbol[a:folded],
        \ node,
        \ a:fname,
        \ )
endfunction "  }}}1

function! s:title_line(title)                                                        " {{{1
  let s:title_line_prefix = '   └'
  return printf('%s %s:', s:title_line_prefix, a:title)
endfunction "  }}}1

function! s:item_line(item)                                                          " {{{1
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

function! s:update_items()                                                           " {{{1
  let s:files = []
  let g:items = []
  " IDEA!!!: the bufdo & argdo may not be the efficient way
  " IDEA!: study other todo plugin to see how them parsing & collect items
  " ISSUE: is this marking way robust?
  let bufnr = bufnr('')
  silent bufdo call s:handle_file()
  if argc() > 0
    silent argdo call s:handle_file()
  endif
  execute printf('buffer %d', bufnr)
endfunction "  }}}1

function! g:MakeToDo()                                                               " {{{1
  call s:update_items()
  call s:show()
endfunction "  }}}1

silent call MakeToDo()

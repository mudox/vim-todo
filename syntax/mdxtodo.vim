scriptencoding utf8

call clearmatches()
" TODO: magic color number here
highlight todoHigh guifg=#ffffff

" highlight group: todoNormal, todoLow, todoMedium, todoHigh
let s:fg = synIDattr(synIDtrans(hlID('todoHigh')), 'fg#')

let s:fg = substitute(s:fg, '[^#]\{2}',
      \ '\=printf("%x", "0x". submatch(0) - 0x35)', 'g')
silent execute printf('highlight todoMedium guifg=%s', s:fg)

let s:fg = substitute(s:fg, '[^#]\{2}',
      \ '\=printf("%x", "0x". submatch(0) - 0x25)', 'g')
silent execute printf('highlight todoLow guifg=%s', s:fg)

let s:fg = substitute(s:fg, '[^#]\{2}',
      \ '\=printf("%x", "0x". submatch(0) - 0x25)', 'g')
silent execute printf('highlight todoNormal guifg=%s', s:fg)

" ISSUE!!: magic symbol here, remove them all
" TODO!!: replace matchadd() with syntax command
call matchadd('todoHigh', '  .*$')
call matchadd('todoMedium', '  .*$')
call matchadd('todoLow', '  .*$')
call matchadd('todoNormal', '^ \{9}\zs.*$')

highlight link todoTitle          Keyword
highlight link todoLine           Comment
highlight link todoFileName       String
highlight link todoFoldedSymbol   Type
highlight link todoUnfoldedSymbol Type

call matchadd('todoTitle', mudox#todo#v.tline_prefix . '\zs.*$')
call matchadd('todoLine', mudox#todo#v.tline_prefix)
call matchadd('todoLine', mudox#todo#v.symbols.fline_tline_prefix)
call matchadd('String', mudox#todo#v.fline_prefix_pattern . mudox#todo#v.symbols.fline_tline_prefix . '.\zs.*$')
call matchadd('todoFoldedSymbol', mudox#todo#v.symbols.folded)
call matchadd('todoUnFoldedSymbol', mudox#todo#v.symbols.unfolded)

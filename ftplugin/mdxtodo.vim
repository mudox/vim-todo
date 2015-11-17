setlocal buftype=nofile
setlocal nobuflisted

" mappings
" INFO: temporally delay inline modificatin function

nnoremap <silent><buffer> <C-n> :<C-U>call mudox#todo#v_nav_sec('next', 1)<Cr>
nnoremap <silent><buffer> <C-p> :<C-U>call mudox#todo#v_nav_sec('prev', 1)<Cr>
nnoremap <silent><buffer> zx    :<C-U>call mudox#todo#v_nav_sec('cur', 1)<Cr>
nnoremap <silent><buffer> zj    :<C-U>call mudox#todo#v_nav_sec('next')<Cr>
nnoremap <silent><buffer> zk    :<C-U>call mudox#todo#v_nav_sec('prev')<Cr>
nnoremap <silent><buffer> zi    :<C-U>call mudox#todo#v_toggle_folding()<Cr>
nnoremap <silent><buffer> zm    :<C-U>call mudox#todo#v_toggle_folding('folded')<Cr>
nnoremap <silent><buffer> zr    :<C-U>call mudox#todo#v_toggle_folding('unfolded')<Cr>
nnoremap <silent><buffer> <Cr>  :<C-U>call mudox#todo#v_goto_source()<Cr>
nnoremap <silent><buffer> o     :<C-U>call mudox#todo#v_toggle_section_fold()<Cr>
nnoremap <silent><buffer> r     :<C-U>call mudox#todo#v_refresh()<Cr>
nnoremap <silent><buffer> q     :close<Cr>
"nnoremap <silent><buffer> +     :<C-U>call mudox#todo#v_change_priority(1)<Cr>
"nnoremap <silent><buffer> -     :<C-U>call mudox#todo#v_change_priority(-1)<Cr>

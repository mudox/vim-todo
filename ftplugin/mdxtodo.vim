setlocal buftype=nofile
setlocal nobuflisted

" mappings
nnoremap <silent><buffer> +     :<C-U>call mudox#todo#v_change_priority(1)<Cr>
nnoremap <silent><buffer> -     :<C-U>call mudox#todo#v_change_priority(-1)<Cr>
nnoremap <silent><buffer> <C-n> :<C-U>call mudox#todo#v_nav_section(1)<Cr>
nnoremap <silent><buffer> <C-p> :<C-U>call mudox#todo#v_nav_section(-1)<Cr>
nnoremap <silent><buffer> <Cr>  :<C-U>call mudox#todo#v_goto_source()<Cr>
nnoremap <silent><buffer> o     :<C-U>call mudox#todo#v_toggle_fold()<Cr>
nnoremap <silent><buffer> r     :<C-U>call mudox#todo#v_refresh()<Cr>
nnoremap <silent><buffer> zx    :<C-U>call mudox#todo#v_only_unfold_current_section()<Cr>
nnoremap <silent><buffer> q     :close<Cr>

" TODO: <Cr> on title line show only items of this title
" TODO!: zj, zk jump to next/prev file section

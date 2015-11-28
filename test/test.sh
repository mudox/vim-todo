# recreat 'test-todo' tmux window
tmux kill-window -t :=test-todo &>/dev/null
tmux new-window -da -c ~/Git/vim-config/plugged/todo -n test-todo bash
# enable bash '**' globbing
tmux send-keys -t :=test-todo                                                         \
  'shopt -s globstar'                                                                 \
  c-m
# launch nvim & start Vader
tmux send-keys -t :=test-todo                                                         \
  "MDX_CHAMELEON_MODE=test-todo nvim **/*.vim ../gitboard/**/*.vim -c 'Vader test/*'" \
  c-m
tmux select-window -t :=test-todo

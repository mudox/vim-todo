# TODO!!!: add travis ci integratioon
# recreat 'test-todo' tmux window
tmux kill-window -t :=test-todo &>/dev/null
tmux new-window -da -c ~/Git/vim-config/plugged/todo -n test-todo bash

# launch nvim & start Vader
tmux send-keys -t :=test-todo                                    \
  "MDX_CHAMELEON_MODE=test-todo nvim -c 'Vader test/main.vader'" \
  c-m
tmux select-window -t :=test-todo

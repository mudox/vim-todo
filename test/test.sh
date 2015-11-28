#/usr/bin/env bash

tmux kill-window -t :=test-todo &>/dev/null
tmux new-window -da -c ~/Git/vim-config/plugged/todo -n test-todo bash
tmux send-keys -t :=test-todo                                       \
  'shopt -s globstar'                                               \
  c-m
tmux send-keys -t :=test-todo                                       \
  "MDX_CHAMELEON_MODE=test-todo nvim **/*.vim ../gitboard/**/*.vim" \
  c-m
sleep 0.1
tmux send-keys -t :=test-todo ':ToDo' c-m t
tmux select-window -t :=test-todo

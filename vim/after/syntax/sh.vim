
" Clear and redefine command substitution highlighting
syn clear shCommandSub
syn region shCommandSub matchgroup=Normal start="\$(" end=")" contains=@shCommandSubList

" Link to normal text color
hi link shCommandSub Normal

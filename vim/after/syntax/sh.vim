
" Clear existing syntax rules we want to override
syn clear shCommandSub   " Remove default command substitution highlighting
syn clear shComment      " Remove default comment highlighting
syn clear shParen       " Remove default parenthesis highlighting
syn clear shSpecial     " Remove default special character highlighting

" Define new syntax rules
syn region shCommandSub matchgroup=Normal start="\$(" end=")" contains=@shCommandSubList  " Treat $() as normal text
syn match shComment /#.*/ contains=@Spell    " Basic comment highlighting with spell check
syn match shSpecial /%%:*/ contains=NONE     " Treat %%: as normal text
syn match shSpecial /#*:/ contains=NONE      " Treat #: as normal text

" Set highlighting colors
hi link shCommandSub Normal   " Make command substitution look like normal text
hi link shSpecial Normal      " Make special characters look like normal text
" Make matching parentheses more visible
hi MatchParen cterm=bold ctermbg=blue ctermfg=white gui=bold guibg=#4444ff guifg=white

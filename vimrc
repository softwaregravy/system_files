" -----------------------------------------------------------------------------  
" |                            VIM Settings                                   |
" |                   (see gvimrc for gui vim settings)                       |
" |                                                                           |
" | Some highlights:                                                          |
" |   jj = <esc>  Very useful for keeping your hands on the home row          |
" |   ,n = toggle NERDTree off and on                                         |
" |                                                                           |
" |   ,f = fuzzy find all files                                               |
" |   ,b = fuzzy find in all buffers                                          |
" |   ,p = go to previous file                                                |
" |                                                                           |
" |   hh = inserts '=>'                                                       |
" |   aa = inserts '@'                                                        |
" |                                                                           |
" |   ,h = new horizontal window                                              |
" |   ,v = new vertical window                                                |
" |                                                                           |
" |   ,i = toggle invisibles                                                  |
" |                                                                           |
" |   enter and shift-enter = adds a new line after/before the current line   |
" |                                                                           |
" |   :call Tabstyle_tabs = set tab to real tabs                              |
" |   :call Tabstyle_spaces = set tab to 2 spaces                             |
" |                                                                           |
" -----------------------------------------------------------------------------  

set nocompatible

let mapleader = ","
" Professor VIM says '87% of users prefer jj over esc', jj abrams disagrees
imap jj <Esc> 

" Tabs ************************************************************************
"set sta " a <Tab> in an indent inserts 'shiftwidth' spaces

function! Tabstyle_tabs()
  " Using 4 column tabs
  set softtabstop=4
  set shiftwidth=4
  set tabstop=4
  set noexpandtab
endfunction

" function! Tabstyle_spaces()
  " Use 2 spaces
  set softtabstop=2
  set shiftwidth=2
  set tabstop=2
  set expandtab
" endfunction

" why didn't this work?
" call Tabstyle_spaces()


" Indenting *******************************************************************
set ai " Automatically set the indent of a new line (local to buffer)
set si " smartindent (local to buffer)


" Scrollbars ******************************************************************
set sidescrolloff=2
set numberwidth=4


" Windows *********************************************************************
set equalalways " Multiple windows, when created, are equal in size
set splitbelow splitright

" Vertical and horizontal split then hop to a new buffer
:noremap <Leader>v :vsp^M^W^W<cr>
:noremap <Leader>h :split^M^W^W<cr>


" Cursor highlights ***********************************************************
set cursorline
"set cursorcolumn


" Searching *******************************************************************
set hlsearch  " highlight search
set incsearch  " Incremental search, search as you type
set ignorecase " Ignore case when searching 
set smartcase " Ignore case when searching lowercase


" Colors **********************************************************************
set t_Co=256
" Enable true color support - commented out due to screen compatibility issues
"let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
"let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
"set termguicolors
set background=dark 
syntax on " syntax highlighting
colorscheme ir_black


" Status Line *****************************************************************
set showcmd
set ruler " Show ruler
"set ch=2 " Make command line two lines high


" Line Wrapping ***************************************************************
set nowrap
set linebreak  " Wrap at word


" Directories *****************************************************************
" Setup backup location and enable
"set backupdir=~/backup/vim
"set backup

" Set Swap directory
"set directory=~/backup/vim/swap

" Sets path to directory buffer was loaded from
"autocmd BufEnter * lcd %:p:h


" File Stuff ******************************************************************
filetype plugin indent on
" To show current filetype use: set filetype

"autocmd FileType html :set filetype=xhtml


" Insert New Line *************************************************************
map <S-Enter> O<ESC> " awesome, inserts new line without going into insert mode
map <Enter> o<ESC>
"set fo-=r " do not insert a comment leader after an enter, (no work, fix!!)


" Sessions ********************************************************************
" Sets what is saved when you save a session
set sessionoptions=blank,buffers,curdir,folds,help,resize,tabpages,winsize


" Invisible characters *********************************************************
set listchars=trail:.,tab:>-,eol:$
set nolist
:noremap <Leader>i :set list!<CR> " Toggle invisible chars

" Line Numbers ***************************************************************
map <Leader>s :set number!<CR>

" Mouse ***********************************************************************
"set mouse=a " Enable the mouse
"behave xterm
"set selectmode=mouse


" Misc settings ***************************************************************
set backspace=indent,eol,start
set number " Show line numbers
set matchpairs+=<:>
set vb t_vb= " Turn off bell, this could be more annoying, but I'm not sure how
set nofoldenable " Turn off folding 


" Navigation ******************************************************************

" Make cursor move by visual lines instead of file lines (when wrapping)
map <up> gk
map k gk
imap <up> <C-o>gk
map <down> gj
map j gj
imap <down> <C-o>gj
map E ge
" Use CTR to move between split windows
map <C-J> <C-W>j
map <C-K> <C-W>k
map <C-H> <C-W>h
map <C-L> <C-W>l
" use space to search
map <space> /
map <C-space> ?

map <Leader>p <C-^> " Go to previous file


" Ruby stuff ******************************************************************
"compiler ruby         " Enable compiler support for ruby
"map <F5> :!ruby %<CR>
" source: https://github.com/standardrb/standard/wiki/IDE:-vim
let g:ruby_indent_assignment_style = 'variable'
let g:ruby_indent_hanging_elements = 0


" Omni Completion *************************************************************
autocmd FileType html :set omnifunc=htmlcomplete#CompleteTags
autocmd FileType python set omnifunc=pythoncomplete#Complete
autocmd FileType javascript set omnifunc=javascriptcomplete#CompleteJS
autocmd FileType css set omnifunc=csscomplete#CompleteCSS
autocmd FileType xml set omnifunc=xmlcomplete#CompleteTags
autocmd FileType php set omnifunc=phpcomplete#CompletePHP
autocmd FileType c set omnifunc=ccomplete#Complete
" May require ruby compiled in
autocmd FileType ruby,eruby set omnifunc=rubycomplete#Complete 
" Note, this is matching the start of the filename, not the extension
autocmd BufNewFile,BufRead .env* set filetype=sh

" ZSH file handling
autocmd FileType zsh set expandtab
autocmd FileType zsh set tabstop=2
autocmd FileType zsh set softtabstop=2
autocmd FileType zsh set shiftwidth=2
autocmd FileType zsh set autoindent
autocmd FileType zsh set formatoptions+=r
autocmd FileType zsh set formatoptions+=o
autocmd FileType zsh set formatoptions+=j
autocmd FileType zsh set commentstring=#\ %s


" Hard to type *****************************************************************
imap uu _
imap hh =>
imap aa @


" -----------------------------------------------------------------------------  
" |                              Plug-ins                                     |
" -----------------------------------------------------------------------------  

" NERDTree ********************************************************************
:noremap <Leader>n :NERDTreeToggle<CR>
let NERDTreeHijackNetrw=1 " User instead of Netrw when doing an edit /foobar
let NERDTreeMouseMode=1 " Single click for everything
let NERDTreeWinSize=40 " set default width of nerdtree


" NERD Commenter **************************************************************
let NERDCreateDefaultMappings=0 " I turn this off to make it simple

" Toggle commenting on 1 line or all selected lines. Wether to comment or not
" is decided based on the first line; if it's not commented then all lines
" will be commented
" :map <Leader>c :call NERDComment(0, "toggle")<CR><ESC>
:map <Leader>c :call nerdcommenter#Comment(0, "toggle")<CR><ESC>
" let g:NERDCreateDefaultMappings = 1

" rails-vim ***************************************************************
map <Leader>ra :AS<CR>
map <Leader>rs :RS<CR>

" AutoComplPop
set completeopt=menu,longest,preview
let g:AutoComplPop_IgnoreCaseOption = 0
let g:AutoComplPop_BehaviorKeywordLength = 2
set complete=.,w,b,u,t,k
let g:AutoComplPop_CompleteOption = '.,w,b,u,t,k'
" trying this behavior for a while
inoremap <expr> <Tab> pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
" inoremap <Tab> <C-n>

" -----------------------------------------------------------------------------  
" |                             OS Specific                                   |
" |                      (GUI stuff goes in gvimrc)                           |
" -----------------------------------------------------------------------------  

" Mac *************************************************************************
"if has("mac") 
  "" 
"endif
 
" Windows *********************************************************************
"if has("gui_win32")
  "" 
"endif



" -----------------------------------------------------------------------------  
" |                               Startup                                     |
" -----------------------------------------------------------------------------  
" Open NERDTree on start
" Never turn this on cause it opens on all the git commit/rebase stuff
" autocmd VimEnter * exe 'NERDTree' | wincmd l 



" -----------------------------------------------------------------------------  
" |                               Host specific                               |
" -----------------------------------------------------------------------------  
if filereadable(expand("~/.vimrc.local"))
  source ~/.vimrc.local
endif

"if hostname() == "foo"
  " do something
"endif

" Example .vimrc.local:

"call Tabstyle_tabs()
"colorscheme ir_dark

"autocmd User ~/git/some_folder/* call Tabstyle_spaces() | let g:force_xhtml=1

" play nice with rvm https://rvm.beginrescueend.com/integration/vim/
" removing as we are not using rvm anymore
" set shell=/bin/sh

" cause
iabbrev busienss business
iabbrev custmoer customer

" -----------------------------------------------------------------------------
" |                           Clipboard Mappings                               |
" -----------------------------------------------------------------------------
" Map yy and vv to show their copy destinations, vv copies to system clipboard
" nnoremap <expr> yy v:count ? v:count.'yy:echo "'.v:count.' lines copied to buffer"<CR>' : 'yy:echo "1 line copied to buffer"<CR>'
nnoremap yy :<C-u>execute 'normal! '.v:count1.'yy' \| echon v:count1.' lines copied to buffer'<CR>
nnoremap <expr> vv v:count ? "\<ESC>".v:count.'"+yy:echo "'.v:count.' lines copied to system clipboard"<CR>' : '"+yy:echo "1 line copied to system clipboard"<CR>'

" yank to clipboard
if has("clipboard")
  set clipboard=unnamed " copy to the system clipboard

  if has("unnamedplus") " X11 support
    set clipboard+=unnamedplus
  endif
endif

" source: https://github.com/standardrb/standard/wiki/IDE:-vim
" packadd vim-lsp
" Use standard if available
if executable('standardrb')
  au User lsp_setup call lsp#register_server({
        \ 'name': 'standardrb',
        \ 'cmd': ['standardrb', '--lsp'],
        \ 'allowlist': ['ruby'],
        \ })
endif

autocmd VimEnter * echom "Current colorscheme: " . execute('colorscheme')


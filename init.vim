" -----------------------------------------------------------------------------  
" |                            Neovim Configuration                            |
" |                    find me in ~/.config/nvim/init.vim                      |
" -----------------------------------------------------------------------------  

" Auto-install vim-plug
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" -----------------------------------------------------------------------------  
" |                               Plugins                                      |
" -----------------------------------------------------------------------------  
call plug#begin()
" File Explorer
Plug 'nvim-tree/nvim-tree.lua'
Plug 'nvim-tree/nvim-web-devicons'  " Optional, for file icons
Plug 'preservim/nerdcommenter'

" Ruby/Rails
Plug 'vim-ruby/vim-ruby'
Plug 'tpope/vim-rails'

" Fuzzy Finding
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim', { 'branch': '0.1.x' }

" LSP Support
Plug 'neovim/nvim-lspconfig'

" Theme
Plug 'wgibbs/vim-irblack'
call plug#end()

" Auto-install missing plugins on startup
autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
  \| PlugInstall --sync | source $MYVIMRC
\| endif

" -----------------------------------------------------------------------------  
" |                            General Settings                                | 
" -----------------------------------------------------------------------------  
set nocompatible
let mapleader = ","

" Visual Settings
set number          " Show line numbers
set cursorline      " Highlight current line
set nowrap          " Don't wrap lines
set linebreak       " Break lines at word boundaries
set sidescrolloff=2 " Keep 2 chars screen side when scrolling
set numberwidth=4   " Width of line number column
set signcolumn=yes  " Always show signcolumn for LSP diagnostics

" Search Settings
set hlsearch        " Highlight search results
set incsearch       " Incremental search
set ignorecase      " Case insensitive search
set smartcase       " Case sensitive if search contains uppercase

" Window Management
set equalalways     " Keep windows equal size
set splitbelow      " New horizontal splits below
set splitright      " New vertical splits right
set hidden          " Allow switching buffers without saving

" -----------------------------------------------------------------------------  
" |                            Key Mappings                                    |
" -----------------------------------------------------------------------------  
" Quick Escape and Common Symbols
imap jj <Esc>
imap uu _
imap hh =>
imap aa @

" Window Navigation
map <C-J> <C-W>j
map <C-K> <C-W>k
map <C-H> <C-W>h
map <C-L> <C-W>l

" Split Creation
:noremap <Leader>v :vsp^M^W^W<cr>
:noremap <Leader>h :split^M^W^W<cr>

" Line Insertion
map <S-Enter> O<ESC>
map <Enter> o<ESC>

" File Navigation
map <Leader>p <C-^>  " Toggle previous file
map <space> /        " Quick search
map <C-space> ?      " Quick backwards search

" -----------------------------------------------------------------------------  
" |                               Tabs & Indenting                             | 
" -----------------------------------------------------------------------------  
" 4-space tabs
function! Tabstyle_tabs()
  set softtabstop=4
  set shiftwidth=4
  set tabstop=4
  set noexpandtab
  autocmd User Rails set softtabstop=4
  autocmd User Rails set shiftwidth=4
  autocmd User Rails set tabstop=4
  autocmd User Rails set noexpandtab
endfunction

" 2-space tabs
function! Tabstyle_spaces()
  set softtabstop=2
  set shiftwidth=2
  set tabstop=2
  set expandtab
endfunction

" Default to 2-space tabs
call Tabstyle_spaces()

set ai  " Auto indent
set si  " Smart indent

" -----------------------------------------------------------------------------  
" |                               Plugin Settings                              | 
" -----------------------------------------------------------------------------  
" nvim-tree Configuration
lua << EOF
-- disable netrw at the very start of your init.lua (strongly advised)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("nvim-tree").setup({
  view = {
    width = 40,  -- Same width as your previous NERDTree
  },
  actions = {
    open_file = {
      quit_on_open = false,
    },
  },
  renderer = {
    icons = {
      show = {
        file = true,
        folder = true,
        folder_arrow = true,
        git = true,
      },
    },
  },
    filters = {
    dotfiles = true,  -- Hide dotfiles by default
  },
 on_attach = function(bufnr)
    local api = require('nvim-tree.api')

    -- Default mappings
    api.config.mappings.default_on_attach(bufnr)
    vim.keymap.set('n', 's', api.node.open.vertical, { buffer = bufnr })
    vim.keymap.set('n', 'i', api.node.open.horizontal, { buffer = bufnr })
    vim.keymap.set('n', '?', api.tree.toggle_help, { buffer = bufnr })
  end,

})
-- Auto open nvim-tree when opening a file or directory
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    require("nvim-tree.api").tree.toggle(false, true)
  end,
})
EOF
nnoremap <Leader>n :NvimTreeToggle<CR>


" NERDCommenter Configuration
let NERDCreateDefaultMappings=0  " Disable default mappings
:map <Leader>c :call nerdcommenter#Comment(0, "toggle")<CR><ESC>

" Telescope Mappings
"
nnoremap <Leader>f <cmd>Telescope find_files<cr>
nnoremap <Leader>b <cmd>Telescope buffers<cr>
nnoremap <Leader>g <cmd>Telescope live_grep<cr>
nnoremap <Leader>h <cmd>Telescope help_tags<cr>

" -----------------------------------------------------------------------------  
" |                               LSP Configuration                            |
" -----------------------------------------------------------------------------  
" Ruby LSP Setup
"
if executable('solargraph')
    lua << EOF
    require'lspconfig'.solargraph.setup{
        settings = {
            solargraph = {
                diagnostics = true
            }
        }
    }
EOF
endif

" -----------------------------------------------------------------------------  
" |                               File Type Settings                           |
" -----------------------------------------------------------------------------  
"
filetype plugin indent on

" for vimrc files
"
autocmd BufRead,BufNewFile .vimrc,vimrc,init.vim set filetype=vim

" Ruby Indentation Settings
"
let g:ruby_indent_assignment_style = 'variable'
let g:ruby_indent_hanging_elements = 0

" Language-Specific Completion
"
autocmd FileType html :set omnifunc=htmlcomplete#CompleteTags
autocmd FileType python set omnifunc=pythoncomplete#Complete
autocmd FileType javascript set omnifunc=javascriptcomplete#CompleteJS
autocmd FileType css set omnifunc=csscomplete#CompleteCSS
autocmd FileType xml set omnifunc=xmlcomplete#CompleteTags
autocmd FileType php set omnifunc=phpcomplete#CompletePHP
autocmd FileType c set omnifunc=ccomplete#Complete
autocmd FileType ruby,eruby set omnifunc=rubycomplete#Complete 

" -----------------------------------------------------------------------------  
" |                               System Integration                           |
" -----------------------------------------------------------------------------  
" Clipboard Configuration
if has("clipboard")
  set clipboard=unnamed " Copy to system clipboard
  if has("unnamedplus") " X11 support
    set clipboard+=unnamedplus
  endif
endif

" Shell Configuration
set shell=/bin/sh

" -----------------------------------------------------------------------------  
" |                               Common Corrections                           |
" -----------------------------------------------------------------------------  
iabbrev busienss business
iabbrev custmoer customer

" -----------------------------------------------------------------------------  
" |                               Theme Settings                               |
" -----------------------------------------------------------------------------  
set background=dark
syntax on
colorscheme ir_black

" -----------------------------------------------------------------------------  
" |                               Local Settings                               |
" -----------------------------------------------------------------------------  
" Load machine-specific settings if present
if filereadable(expand("~/.config/nvim/local.vim"))
  source ~/.config/nvim/local.vim
endif

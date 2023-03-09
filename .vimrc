" Essentials
set nocompatible                   " vim settings, not vi
set nomodeline                     " disable modelines, they're just asking for trouble
set encoding=utf-8                 " unicode things
set number                         " prefix line numbers
set relativenumber                 " make the line numbers relative for easier movement commands
set nrformats-=octal               " allows <ctrl-a> to increment `07` -> `08` instead of `010`
set ruler                          " show cursor position on last line/status window
set linebreak                      " wrap lines at word boundaries so words aren't split
set nolist                         " `linebreak` doesn't work when `list` is enabled
set showcmd                        " show last commands on last line
set showmode                       " show mode at bottom
set cursorline                     " highlight/underline current line where cursor is
set splitbelow                     " place new split _below_ current window
set splitright                     " place new split _to the right of_ current window
set matchpairs+=<:>                " expand `matchpairs` to jump between pairs with `%`
set showmatch                      " highlight matching tags -> [],{},(),<>
set incsearch                      " incremental search (searches actively as you type)
set hlsearch                       " highlight search matches
set ignorecase                     " case insensitive search...
set smartcase                      " case sensitive search (only if capital letters entered)
set confirm                        " confirm unsaved changes rather than erroring out
set scrolloff=10                   " keep 5 context lines above/below cursor line
set visualbell                     " don't beep, but flash screen
set wildmenu                       " better command line completion
set backspace=indent,eol,start     " allow backspacing over autoindents and such
set laststatus=2                   " always show status line
set ttyfast                        " enable faster terminal rendering
set lazyredraw                     " don't redraw when executing macros/registers/untyped commands
" set autoread                       " re-read file when it's contents have been changed outside of vim
syntax enable                      " enable syntax highlighting
set foldlevelstart=99              " when folding is enabled, always open expanded, never auto close folds

" define ',' as leader and add some custom keybindings
let mapleader=","
" trigger window commands with leader+w instead of ctrl+w
nnoremap <leader>w <C-w>
set listchars=tab:→\ ,trail:·,eol:¬      " set characters for tab, newlines, and trailing whitespace
nmap <leader>l :set list!<CR>            " toggle char display for tabs, eol, etc
nmap <leader>R :source $HOME/.vimrc <CR> " re-source vim config
" open terminal
nmap <leader>T :terminal <CR>
nmap <leader>dt :windo diffthis<CR>      " enable diff
nmap <leader>do :windo diffoff<CR>       " disable diff
nmap <leader>v :read !clip paste<CR>     " read input from system clipboard
                                         " expects: https://github.com/tjhop/clip
nmap <leader>a ggVG                      " 'select all'

" set default tabbing behavior
set expandtab
set softtabstop=4
set shiftwidth=4

" enable filetype based indentation
filetype plugin indent on

" theme/color scheme stuff
set background=dark
" colorscheme solarized
colorscheme gruvbox
let colorscheme_in_use = get(g:, 'colors_name', 'default')

" vim-indent-guides configs
let g:indent_guides_enable_on_vim_startup=1
let g:indent_guides_guide_size=1
let g:indent_guides_auto_colors=0
let g:indent_guides_exclude_filetypes = ['help', 'nerdtree', 'json', 'sh']
if colorscheme_in_use == 'solarized'
    autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  guibg=red   ctermbg=DarkCyan
    autocmd VimEnter,Colorscheme * :hi IndentGuidesEven guibg=green ctermbg=DarkGreen
elseif colorscheme_in_use == 'gruvbox'
    autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  guibg=red   ctermbg=DarkMagenta
    autocmd VimEnter,Colorscheme * :hi IndentGuidesEven guibg=green ctermbg=Yellow
endif

" vim-fugitive configs (git commands)
nnoremap <leader>gs :Git<CR>
nnoremap <leader>gd :Gvdiffsplit<CR>
nnoremap <leader>gb :Git blame<CR>
nnoremap <leader>gc :Git commit<CR>
nnoremap <leader>gmv :GMove<CR>
nnoremap <leader>grm :GRemove<CR>:q<CR>

" gitgutter settings
set updatetime=100

" NERDTree configs
" ----------------
" autocmd vimenter * NERDTree     " Start NERDTree when entering vim
let NERDTreeQuitOnOpen=1      " quit NERDTree when opening file
let NERDTreeShowHidden=1      " show hidden files/dirs
let NERDTreeMinimalUI=1       " hide help menu
let g:NERDTreeWinSize=30      " limit NERDTree window to 30 chars

nnoremap <leader>t :NERDTreeFind<CR>     " toggle NERDTree with leader+t

" NERDcommenter configs
" --------------------
let g:NERDSpaceDelims = 1
let g:NERDCommentEmptyLines = 1
let g:NERDTrimTrailingWhitespace = 1

" MarkdownPreview configs
" --------------------
nnoremap <leader>mps :MarkdownPreview<CR>
nnoremap <leader>mpe :MarkdownPreviewStop<CR>

" Vim Airline configs
" -------------------
let g:airline_solarized_bg='dark'

" Vim Go configs
" --------------
let g:go_imports_autosave = 0
let g:go_fmt_autosave = 0

" Load all plugins and generate helptags for them
" -----------------------------------------------
packloadall
silent! helptags ALL

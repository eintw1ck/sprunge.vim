" ============================================================================
" File:        sprunge.vim
" Description: vim global plugin to paste to http://sprunge.us/
" Maintainer:  Javier Lopez <m@javier.io>
" ============================================================================

function! sprunge#GetVisualSelection() "{{{
  "why is this not a built-in Vim script function?!
  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]
  let lines = getline(lnum1, lnum2)
  try
      let lines[-1] = lines[-1][: col2 - (&selection == 'inclusive' ? 1 : 2)]
      let lines[0] = lines[0][col1 - 1:]
  catch /^Vim\%((\a\+)\)\=:E/
      return ''
  endtry
  return join(lines, "\n")
endfunction

function! sprunge#CopyToClipboard(url) "{{{
  if g:sprunge_clipboard ==? 'vim' || g:sprunge_clipboard ==? 'all'
    call setreg('"', a:url)
  endif
  if g:sprunge_clipboard ==? 'external' || g:sprunge_clipboard ==? 'all'
    if executable('xclip')
      call system('printf "' .  a:url . '"' . ' | ' .
            \ 'xclip -selection clipboard; xclip -o -selection clipboard')
    elseif executable ('xsel')
      call system('printf "' .  a:url . '"' . ' | ' .  'xsel -bi')
    elseif executable ('pbcopy')
      call system('printf "' .  a:url . '"' . ' | ' .
            \ 'pbcopy')
    endif
    if has("win32") || has("win16")
      call setreg('*', a:url)
    endif
  endif
  if exists('g:sprunge_clipboard_cmd')
      call system('printf "' .  a:url . '"' . ' | ' .  g:sprunge_clipboard_cmd)
  endif
endfunction

function! sprunge#CountLeadingWhiteSpaces(line) "{{{
    let l:len = strlen(a:line) - 1
    let l:white_spaces_counter = 0
    while l:white_spaces_counter <= l:len
        let l:char = strpart(a:line, l:white_spaces_counter, 1)
        if l:char == " "
            let l:white_spaces_counter += 1
        else
            return l:white_spaces_counter
        endif
    endwhile
    return 0
endfunction

function! sprunge#GetMinIndent(buffer) "{{{
  let l:min_indent = 9999
  for l:line in split(a:buffer, '\n')
      if l:line =~# '^$' "skip white lines
          continue
      else "otherwise, count whitespaces before 1st character
          let l:white_spaces = sprunge#CountLeadingWhiteSpaces(l:line)
          if l:white_spaces < l:min_indent
              let l:min_indent = l:white_spaces
          endif
      endif
  endfor

  return l:min_indent
endfunction

function! sprunge#Tabs2Spaces(buffer) "{{{
  let l:spaces_per_tab = repeat(' ', &softtabstop)
  let l:buffer = '' | for l:line in split(a:buffer, '\n')
      let l:line = substitute(l:line, l:spaces_per_tab, '\t', 'g')
      let l:line = substitute(l:line, ' \+\ze\t', '', 'g')
      let l:buffer .= substitute(l:line, '\t', l:spaces_per_tab, 'g') . "\n"
  endfor
  return l:buffer
endfunction

function! sprunge#FlushLeft(buffer) "{{{
  let l:min_indent = sprunge#GetMinIndent(a:buffer)
  let l:buffer     = a:buffer

  if l:min_indent > 0
      let l:buffer = '' | for l:line in split(a:buffer, '\n')
          let l:buffer .= strpart(l:line, l:min_indent) . "\n"
      endfor
  endif

  return l:buffer
endfunction

function! sprunge#Post(buffer, ...) "{{{
  return system('curl -sg -F "file=<-" https://0x0.st', a:buffer)
endfunction

function! sprunge#Sprunge(line1, line2)  "{{{
  if !executable('curl')
      echoerr "Sprunge: requires 'curl'"
      return
  endif

  if a:line1 == 1 && a:line2 == line('$')
      let buffer = join(getline(a:line1, a:line2), "\n") . "\n"
  else
      let buffer = sprunge#GetVisualSelection()
      if empty(buffer)
        let buffer = join(getline(a:line1, a:line2), "\n") . "\n"
      endif
  endif

  if g:sprunge_tabs2spaces | let buffer = sprunge#Tabs2Spaces(buffer) | endif
  if g:sprunge_flush_left  | let buffer = sprunge#FlushLeft(buffer)   | endif

  redraw | echon 'Posting ... '
  let url = sprunge#Post(buffer)
  if empty(url)
      let url = system("curl -s http://google.com")
      if empty(url)
          redraw | echohl WarningMsg|echomsg 'Error: no network available' |echohl None
      else
          redraw | echohl WarningMsg|echomsg 'Error: sprunge.us has been shutdown or altered its api' |echohl None
      endif
  else
      call sprunge#CopyToClipboard(url)
      redraw | echomsg 'Done: ' . url
  endif
endfunction

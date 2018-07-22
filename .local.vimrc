if !has_key(b:, 'ale_linters')
  let b:ale_linters = {}
endif

let b:ale_linters.javascript = [ 'eslint' ]
let b:ale_linters.elixir = [ 'credo' ]
let b:ale_javascript_eslint_suppress_eslintignore = 1

let g:ale_lint_on_text_changed = 'normal'

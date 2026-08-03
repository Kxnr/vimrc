# =====
# ZSH Options
# =====
setopt SHARE_HISTORY
setopt rcexpandparam       # Array expension with parameters
setopt nocheckjobs         # Don't warn about running processes when exiting
setopt numericglobsort     # Sort filenames numerically when it makes sense
setopt nobeep              # No beep
setopt incappendhistory    # Immediately append history instead of overwriting

# =====
# Completion Options
# =====

zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' # Case insensitive tab completion
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"                           # Colored completion (different colors for dirs/files/etc)
zstyle ':completion:*' rehash true                                                # automatically find new executables in path

# =====
# Key Bindings
# =====

bindkey '^[[3~'   delete-char                          # Delete key
bindkey '^[[C'    forward-char                         # Right key
bindkey '^[[D'    backward-char                        # Left key
bindkey '^[[5~'   history-beginning-search-backward    # Page up key
bindkey '^[Oc'    forward-word                         # ctrl right
bindkey '^[Od'    backward-word                        # ctrl left
bindkey '^[[1;5D' backward-word                        # ctrl left
bindkey '^[[1;5C' forward-word                         # ctrl right
bindkey '^H'      backward-kill-word                   # delete previous word with ctrl+backspace
bindkey '^[[Z'    undo                                 # Shift+tab undo last action

function Resume {
  fg
  zle push-input
  BUFFER=""
  zle accept-line
}
zle -N Resume
bindkey "^Z" Resume

# =====
# Colors
# =====

autoload -U compinit colors zcalc
compinit -d
colors

# Color man pages
export LESS_TERMCAP_mb=$'\E[01;32m'
export LESS_TERMCAP_md=$'\E[01;32m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;47;34m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;36m'
export LESS=-r

# =====
# Plugins
# =====

source $HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source $HOME/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# =====
# Env Vars
# =====

export PATH="$HOME/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/src/zide/bin:$HOME/libs/flutter_sdk/bin:$PATH"
export SSLKEYLOGFILE="$HOME/.ssl-key.log"
export TERM=xterm-256color
export EDITOR=$(which hx)
export VISUAL=$(which hx)
export GIT_EDITOR=$VISUAL
export EDITOR=$VISUAL
export SUDO_EDITOR=$VISUAL
export AZ_AUTO_LOGIN_TYPE="DEVICE"

export XPAUTH_PATH="$HOME/src/smartbidder/src/projects/python/job_schedules/xpauth_dev.xpr"
export XPRESS="$HOME/src/smartbidder/src/projects/python/job_schedules/xpauth_dev.xpr"

# =====
# Tool Configuration
# =====

eval "$(mise activate zsh)"
eval "$(zoxide init zsh)"
. "$HOME/.atuin/bin/env"
eval "$(atuin init zsh)"
eval "$(starship init zsh)"
eval "$(fzf --zsh)"

# =====
# Libraries
# =====

source "$HOME/src/shell-tools/zsh/init.zsh"

# =====
# Aliases
# =====

alias ls="eza"
alias cat="bat"
alias tree="ls --tree --color always | cat"
alias rm="rm -I"
alias cp="cp -i"
alias mv="mv -i"
alias sbid="project cd smartbidder"
alias wt="project worktree"
alias pj="project"
alias bm="project bookmark"

# =====
# Functions
# =====

function most-recent-tag {
  if ! in_git_repo; then
    print_error "Not in a git repository"
    return 1
  fi

  print_info "Fetching tags..."
  if ! git fetch --tags 2>/dev/null; then
    print_error "Failed to fetch tags"
    return 1
  fi

  local tags=$(git describe --tags $(git rev-list --tags --max-count=5) 2>/dev/null)

  if [[ -z "$tags" ]]; then
    print_warning "No tags found in repository"
    return 0
  fi

  echo "$tags"
}

function review() {
  if [[ -z "$1" ]]; then
    print_error "Usage: review <branch> [base_branch]"
    return 1
  fi

  local branch="$1"
  local base_branch="${2:-main}"

  if ! in_git_repo; then
    print_error "Not in a git repository"
    return 1
  fi

  # Validate branch exists
  if ! git rev-parse --verify "$branch" &>/dev/null; then
    print_error "Branch '$branch' does not exist"
    return 1
  fi

  print_info "Fetching latest changes..."
  if ! git fetch --all --quiet; then
    print_error "Failed to fetch changes"
    return 1
  fi

  print_info "Checking out branch: $branch"
  if ! git checkout "$branch"; then
    print_error "Failed to checkout branch: $branch"
    return 1
  fi

  # Get changed files using utility
  local changed_files=("${(@f)$(git_changed_files "$base_branch")}")

  if is_empty_array "${changed_files[@]}"; then
    print_warning "No files changed compared to $base_branch"
    git checkout -
    return 0
  fi

  print_success "Found ${#changed_files[@]} changed file(s)"

  # Run pre-commit if available
  if command_exists pre-commit; then
    print_info "Running pre-commit hooks..."
    if ! pre-commit run --from-ref "origin/${base_branch}" --to-ref HEAD; then
      print_warning "Pre-commit checks failed (non-fatal)"
    fi
  else
    print_warning "pre-commit not installed, skipping hooks"
  fi

  # Run tests if pants is available
  if command_exists pants; then
    print_info "Running tests with pants..."
    if ! pants test compatible-tests; then
      print_warning "Tests failed (non-fatal)"
    fi
  else
    print_info "pants not installed, skipping tests"
  fi

  # Check with pyrefly if available
  if command_exists pyrefly; then
    print_info "Running pyrefly checks..."
    local py_files=("${(@f)$(git_changed_files "$base_branch" "*.py")}")
    if ! is_empty_array "${py_files[@]}"; then
      if ! pyrefly check "${py_files[@]}"; then
        print_warning "Pyrefly checks failed (non-fatal)"
      fi
    fi
  else
    print_info "pyrefly not installed, skipping type checks"
  fi

  print_success "All automated checks complete"
  read -sk '?Press any key to view files...'
  echo  # New line after keypress

  "$EDITOR" "${changed_files[@]}"

  print_info "Returning to previous branch..."
  git checkout -
}

function ruff-fix() {
  if [[ -z "$1" ]]; then
    print_error "Usage: ruff-fix <fix_code1,fix_code2,...> [base_branch]"
    return 1
  fi

  if ! in_git_repo; then
    print_error "Not in a git repository"
    return 1
  fi

  if ! command_exists ruff; then
    print_error "ruff is not installed"
    return 1
  fi

  local fix_codes="$1"
  local base_ref="${2:-main}"  # Allow override of base branch

  # Use the git_changed_files utility
  local files=("${(@f)$(git_changed_files "$base_ref" '*.py')}")

  if is_empty_array "${files[@]}"; then
    print_warning "No Python files changed compared to $base_ref"
    return 0
  fi

  print_info "Running ruff on ${#files[@]} file(s) with codes: $fix_codes"
  ruff check --fix --select "$fix_codes" "${files[@]}"
}

function dot-run() {
  if [[ -z "$1" ]]; then
    print_error "Usage: dot-run <env_file> <command> [args...]"
    return 1
  fi

  local env_file="$1"

  if [[ -z "${@[2,-1]}" ]]; then
    print_error "No command specified"
    print_info "Usage: dot-run <env_file> <command> [args...]"
    return 1
  fi

  if ! file_readable "$env_file"; then
    print_error "Cannot read file: $env_file"
    return 1
  fi

  env $(grep -v '^#' "$env_file" | xargs -d '\n') ${@[2,-1]}
}


function timed-file() {
  if [[ -z "$1" ]]; then
    print_error "Usage: timed-file <filename>"
    return 1
  fi

  if ! command_exists fuzzydate; then
    print_error "fuzzydate is not installed"
    return 1
  fi

  local ts
  ts="$(fuzzydate now "%y%m%dT%H%M%S")"

  if [[ -z "$ts" ]]; then
    print_error "Failed to generate timestamp"
    return 1
  fi

  echo "${ts}-${1}"
}

function git-fix() {
  if ! in_git_repo; then
    print_error "Not in a git repository"
    return 1
  fi

  local root_dir
  root_dir="$(git_root)"

  # Get files with conflicts (relative paths)
  local files=("${(@f)$(git diff --name-only --diff-filter=U)}")

  if is_empty_array "${files[@]}"; then
    print_warning "No files with conflicts found"
    return 0
  fi

  # Convert to absolute paths
  local abs_files=()
  local file
  for file in "${files[@]}"; do
    abs_files+=("${root_dir}/${file}")
  done

  print_info "Opening ${#abs_files[@]} file(s) with conflicts"
  "$EDITOR" "${abs_files[@]}"
}

function git-create-patch() {
  if ! in_git_repo; then
    print_error "Not in a git repository"
    return 1
  fi

  local base_ref="${1:-main}"
  local patch_file="${2:-$(timed-file "patch.diff")}"

  print_info "Creating patch against: $base_ref"

  if ! git diff "$base_ref" HEAD > "$patch_file"; then
    print_error "Failed to create patch"
    return 1
  fi

  if [[ ! -s "$patch_file" ]]; then
    print_warning "No changes to create patch (empty diff)"
    rm "$patch_file"
    return 0
  fi

  print_success "Patch created: $patch_file"
  print_info "Lines in patch: $(wc -l < "$patch_file")"
}

function git-apply-patch() {
  if [[ -z "$1" ]]; then
    print_error "Usage: git-apply-patch <patch_file> [--check]"
    return 1
  fi

  if ! in_git_repo; then
    print_error "Not in a git repository"
    return 1
  fi

  local patch_file="$1"
  local check_flag="$2"

  if ! file_readable "$patch_file"; then
    print_error "Cannot read patch file: $patch_file"
    return 1
  fi

  # Check mode - see if patch applies without changing files
  if [[ "$check_flag" == "--check" ]]; then
    print_info "Checking if patch applies cleanly..."
    if git apply --check "$patch_file" 2>&1; then
      print_success "Patch can be applied cleanly"
      return 0
    else
      print_error "Patch cannot be applied cleanly"
      return 1
    fi
  fi

  print_info "Applying patch: $patch_file"

  if git apply "$patch_file"; then
    print_success "Patch applied successfully"
  else
    print_error "Failed to apply patch"
    print_info "Try: git-apply-patch $patch_file --check"
    return 1
  fi
}

function cdr() {
  if ! in_git_repo; then
    print_error "Not in a git repository"
    return 1
  fi

  local root
  root="$(git_root)"

  cd "$root" || return 1
}

function zource {
  source ~/.zshrc
}

function zshrc() {
  "$EDITOR" "$HOME/.zshrc"
  zource
}

function list-shell-defs() {
  print -l ${(ok)functions}
  alias | cut -d= -f1
}

function _sb_setup_env_symlinks() {
  local worktree_path="$1"
  local envs_dir="$HOME/envs"

  print_info "Setting up environment file symlinks..."

  # Helper function to create a symlink, removing target if it exists
  _sb_symlink_env() {
    local source="$1"
    local target="$2"
    local project_name="$3"

    if [[ ! -f "$source" ]]; then
      print_warning "Source file not found: $source (skipping $project_name)"
      return 0
    fi

    mkdir -p "$(dirname "$target")"
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
      rm -f "$target"
    fi

    ln -s "$source" "$target"
    print_success "Linked $project_name"
  }

  _sb_symlink_env "$envs_dir/.env-api" "$worktree_path/src/projects/python/api/.env" "api"
  _sb_symlink_env "$envs_dir/.env-data_api" "$worktree_path/src/projects/python/data_api/.env" "data_api"
  _sb_symlink_env "$envs_dir/.env-job_schedules" "$worktree_path/src/projects/python/job_schedules/.env" "job_schedules"
  # _sb_symlink_env "$envs_dir/.env-ui" "$worktree_path/ui/.env" "ui"
}

function sb-worktree-init() {
  if ! in_git_repo; then
    print_error "Not in a git repository"
    return 1
  fi

  local worktree_path
  worktree_path="$(git_root)"
  if [[ -z "$worktree_path" ]]; then
    print_error "Could not determine worktree root"
    return 1
  fi

  cd "${worktree_path}" || return 1

  pants init

  local azure_feed_url="https://VssSessionToken@pkgs.dev.azure.com/ascendanalytics/_packaging/AscendFeed_Battery%40Local/pypi/simple/"

  print_info "Initializing development environment..."

  # Generate pyrefly.toml
  cat > pyrefly.toml << 'PYREFLY_EOF'
project-includes = [
    "**/*.py*",
    "**/*.ipynb",
]

search-path = [
    'src/projects/python/job_schedules',
    'src/projects/python/api',
    'src/projects/python/data_api',
    'src/projects/python/storage_emulator',
    'src/projects/python/dev_cli',
    'src/projects/python/devops',
    'src/projects/python/pagerduty-summary',
    'src/libs/python/smartbidder_schemas',
    'src/libs/python/core_data',
    'src/libs/python/iso_data',
    'src/libs/python/azure',
    'src/libs/python/io',
    'src/libs/python/serialization',
    'src/libs/python/transformations',
]
PYREFLY_EOF
  print_success "Generated pyrefly.toml"

  # Helper: generate .mise.toml for a directory
  _sb_write_mise_toml() {
    cat > .mise.toml << 'MISE_EOF'
[tools]
python = "3.12"

[env]
_.python.venv = { path = ".venv" }
MISE_EOF

mise trust
  }

  # Helper: pick a pants-exported virtualenv directory, using gum when multiple
  # Python versions are present.
  # Usage: _sb_pick_venv <virtualenvs/resolve-name dir>
  # Prints the selected path to stdout; returns non-zero on failure.
  _sb_pick_venv() {
    local venv_base="$1"
    if [[ ! -d "$venv_base" ]]; then
      print_error "Virtualenv base not found: $venv_base"
      return 1
    fi

    local versions=( "${venv_base}"/*(/N) )
    local chosen
    printf '%s\n' "${versions[@]}" | gum choose --select-if-one --header "Select Python environment:"
  }

  print_info "Setting up root environment..."
  (
    cd "${worktree_path}" || return 1

    _sb_write_mise_toml
    print_success "Generated root .mise.toml"

    # Export pants environment to dist/
    pants export --resolve=global

    # link exported venv to expected venv path
    local global_venv
    global_venv=$(_sb_pick_venv "${worktree_path}/dist/export/python/virtualenvs/global") || return 1
    ln -s "${global_venv}" "${worktree_path}/.venv"

    source ${worktree_path}/.venv/bin/activate

    print_success "Root environment setup complete"
  )

  local api_dir="src/projects/python/api"
  print_info "Setting up api environment..."
  (
    # Export pants api environment from the worktree root (where pants.toml lives)
    cd "${worktree_path}" || return 1
    pants export --resolve=projects_api

    # link exported venv to expected venv path
    local api_venv
    api_venv=$(_sb_pick_venv "${worktree_path}/dist/export/python/virtualenvs/projects_api") || return 1
    ln -s "${api_venv}" "${worktree_path}/${api_dir}/.venv"

    # Switch to api dir to set up its .venv
    cd "${worktree_path}/${api_dir}" || return 1
    source .venv/bin/activate

    _sb_write_mise_toml
    print_success "Generated api .mise.toml"

    print_success "API environment setup complete"
  )

  local data_api_dir="src/projects/python/data_api"
  print_info "Setting up data_api environment..."
  (
    # Export pants api environment from the worktree root (where pants.toml lives)
    cd "${worktree_path}" || return 1
    pants export --resolve=projects_data_api

    # link exported venv to expected venv path
    local data_api_venv
    data_api_venv=$(_sb_pick_venv "${worktree_path}/dist/export/python/virtualenvs/projects_data_api") || return 1
    ln -s "${data_api_venv}" "${worktree_path}/${data_api_dir}/.venv"

    # Switch to api dir to set up its .venv
    cd "${worktree_path}/${data_api_dir}" || return 1
    source .venv/bin/activate

    _sb_write_mise_toml
    print_success "Generated data api .mise.toml"

    print_success "API environment setup complete"
  )

  _sb_setup_env_symlinks "${worktree_path}"

  print_success "Development environment initialized!"
  print_info "Worktree location: $worktree_path"
  print_info "Branch: $(git_current_branch)"
}

function yaz() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

function nid() {
  nanoid generate --alphabet 0123456789abcdefghijklmnopqrstuvwxyz
}


jupyter-init() {
  # Fail fast if not in a virtualenv
  if [[ -z "$VIRTUAL_ENV" ]]; then
    print_error "No virtualenv active. Activate one first."
    return 1
  fi

  local wt_name
  wt_name=$(git branch --show-current)

  # Normalize kernel name (safe for Jupyter)
  local kernel_name
  kernel_name=$(echo "$wt_name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-_')

  local kernel_dir="$HOME/.local/share/jupyter/kernels/$kernel_name"
  if directory_exists "$kernel_dir" && command_exists gum; then
    gum confirm "Kernel '$kernel_name' already exists. Overwrite?" || {
      print_info "Aborted"
      return 0
    }
  fi

  print_info "Installing ipywidgets/ipykernel into $VIRTUAL_ENV..."
  pip install --quiet ipywidgets ipykernel

  print_info "Creating Jupyter kernel: $kernel_name"
  print_info "Using Python: $(which python)"

  python -m ipykernel install --user \
    --name "$kernel_name" \
    --display-name "Python ($wt_name)"

  print_success "Kernel created: $kernel_name"
}

jupyter-kernel-rm() {
  if ! command_exists gum; then
    print_error "gum is required for this command"
    return 1
  fi

  local kernels_dir="$HOME/.local/share/jupyter/kernels"
  local kernels=("${kernels_dir}"/*(/N:t))

  if is_empty_array "${kernels[@]}"; then
    print_warning "No Jupyter kernels found"
    return 0
  fi

  local selected
  selected=("${(@f)$(printf '%s\n' "${kernels[@]}" | gum choose --no-limit --header "Select kernel(s) to remove:")}")

  if is_empty_array "${selected[@]}"; then
    print_info "No kernels selected"
    return 0
  fi

  local name
  for name in "${selected[@]}"; do
    rm -rf "${kernels_dir:?}/${name}"
    print_success "Removed kernel: $name"
  done
}

# shell-tools
source "/home/kxnr/src/shell-tools/zsh/init.zsh"

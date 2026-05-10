: <<'WINDOWS_CMD'
@echo off
setlocal EnableExtensions

set "SCRIPT_PATH=%~f0"
set "SCRIPT_DIR=%~dp0"
set "BASH_EXE="

cd /d "%SCRIPT_DIR%" >nul 2>nul

call :find_bash

if not defined BASH_EXE (
  echo Aviso: No se encontro Bash. En Windows este asistente usa Git for Windows.
  call :install_git_for_windows
  call :find_bash
)

if not defined BASH_EXE (
  echo.
  echo Error: No se pudo encontrar Git Bash.
  echo Instala Git for Windows desde:
  echo https://git-scm.com/download/win
  start "" "https://git-scm.com/download/win" >nul 2>nul
  pause
  exit /b 1
)

"%BASH_EXE%" "%SCRIPT_PATH%" %*
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo.
  echo El asistente termino con error: %EXIT_CODE%
  pause
)

exit /b %EXIT_CODE%

:find_bash
if exist "%ProgramFiles%\Git\bin\bash.exe" (
  set "BASH_EXE=%ProgramFiles%\Git\bin\bash.exe"
  exit /b 0
)

if exist "%ProgramFiles%\Git\usr\bin\bash.exe" (
  set "BASH_EXE=%ProgramFiles%\Git\usr\bin\bash.exe"
  exit /b 0
)

if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" (
  set "BASH_EXE=%ProgramFiles(x86)%\Git\bin\bash.exe"
  exit /b 0
)

if exist "%LocalAppData%\Programs\Git\bin\bash.exe" (
  set "BASH_EXE=%LocalAppData%\Programs\Git\bin\bash.exe"
  exit /b 0
)

for /f "delims=" %%I in ('where bash.exe 2^>nul') do (
  if /I not "%%~fI"=="%SystemRoot%\System32\bash.exe" (
    set "BASH_EXE=%%~fI"
    exit /b 0
  )
)

exit /b 0

:install_git_for_windows
where winget.exe >nul 2>nul
if errorlevel 1 (
  echo No se encontro winget para instalar automaticamente.
  echo Se abrira la pagina oficial de Git for Windows.
  start "" "https://git-scm.com/download/win" >nul 2>nul
  pause
  exit /b 0
)

set "ANSWER="
set /p "ANSWER=Deseas instalar Git for Windows automaticamente con winget? [S/n] "
if /I "%ANSWER%"=="n" exit /b 0
if /I "%ANSWER%"=="no" exit /b 0

winget.exe install --id Git.Git -e --source winget
exit /b 0
WINDOWS_CMD

#!/usr/bin/env bash

set -u
IFS=$'\n\t'

# Configuracion para dejar el archivo listo antes de compartirlo:
# 1. Crea el proyecto en GitHub.
# 2. Pega aqui la URL HTTPS o SSH del proyecto.
# 3. Entrega este unico archivo a tus companeros.
DEFAULT_REPO_URL=""
DEFAULT_BRANCH="main"
DEFAULT_PROJECT_DIR=""

if [ -t 1 ]; then
  GREEN=$'\033[0;32m'
  RED=$'\033[0;31m'
  YELLOW=$'\033[1;33m'
  BLUE=$'\033[0;34m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  GREEN=''
  RED=''
  YELLOW=''
  BLUE=''
  BOLD=''
  RESET=''
fi

BRANCH=""
SELF_PATH="$0"
SELF_NAME="$(basename -- "$0")"
CONFIG_DIR="${HOME:-.}/.libro_sync"
WORKSPACE_FILE="$CONFIG_DIR/workspace_path"
SELF_SIGNATURE=""
RESTART_CODE=88

msg() { printf "%b\n" "$*" >&2; }
info() { msg "${BLUE}==>${RESET} $*"; }
ok() { msg "${GREEN}OK:${RESET} $*"; }
warn() { msg "${YELLOW}Aviso:${RESET} $*"; }
err() { msg "${RED}Error:${RESET} $*"; }
die() { err "$*"; exit 1; }

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

is_windows() {
  case "$(uname -s 2>/dev/null || printf unknown)" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT) return 0 ;;
    *) return 1 ;;
  esac
}

is_linux() {
  [ "$(uname -s 2>/dev/null || printf unknown)" = "Linux" ]
}

refresh_self_path() {
  local dir base
  base="$(basename -- "$0")"
  dir="$(dirname -- "$0")"
  if cd "$dir" >/dev/null 2>&1; then
    SELF_PATH="$(pwd -P)/$base"
    cd - >/dev/null 2>&1 || true
  fi
  SELF_NAME="$base"
}

self_signature() {
  if [ -f "$SELF_PATH" ]; then
    git hash-object "$SELF_PATH" 2>/dev/null || cksum "$SELF_PATH" 2>/dev/null || printf "unknown"
  else
    printf "missing"
  fi
}

capture_self_signature() {
  SELF_SIGNATURE="$(self_signature)"
}

request_restart() {
  exit "$RESTART_CODE"
}

restart_if_self_updated() {
  local current_signature

  current_signature="$(self_signature)"
  if [ -n "$SELF_SIGNATURE" ] && [ "$current_signature" != "$SELF_SIGNATURE" ]; then
    warn "El asistente sync.cmd se actualizo desde GitHub."
    warn "Voy a reiniciar el asistente para usar la nueva version."
    request_restart
  fi
}

restart_with_current_script() {
  info "Reiniciando el asistente con la version actualizada..."
  exec env LIBRO_SYNC_GUARD=1 "$BASH" "$SELF_PATH" "$@"
}

prompt_yes_no() {
  local question="$1"
  local default="${2:-s}"
  local suffix answer

  case "$default" in
    s|S|y|Y) suffix="[S/n]" ;;
    n|N) suffix="[s/N]" ;;
    *) suffix="[s/n]" ;;
  esac

  while true; do
    printf "%b " "${YELLOW}${question} ${suffix}${RESET}" >&2
    IFS= read -r answer || exit 1
    answer="${answer:-$default}"
    case "$answer" in
      s|S|si|Si|SI|y|Y|yes|Yes|YES) return 0 ;;
      n|N|no|No|NO) return 1 ;;
      *) warn "Responde con s o n." ;;
    esac
  done
}

prompt_required() {
  local question="$1"
  local answer=""

  while [ -z "$answer" ]; do
    printf "%b " "${YELLOW}${question}${RESET}" >&2
    IFS= read -r answer || exit 1
    answer="${answer#"${answer%%[![:space:]]*}"}"
    answer="${answer%"${answer##*[![:space:]]}"}"
    [ -n "$answer" ] || warn "Este dato no puede quedar vacio."
  done

  printf "%s" "$answer"
}

prompt_default() {
  local question="$1"
  local default="$2"
  local answer=""

  printf "%b " "${YELLOW}${question} [${default}]${RESET}" >&2
  IFS= read -r answer || exit 1
  answer="${answer:-$default}"
  printf "%s" "$answer"
}

pause_enter() {
  local answer
  printf "%b" "${YELLOW}Presiona Enter para continuar...${RESET}" >&2
  IFS= read -r answer || true
}

run_safe_action() {
  local label="$1"
  local status
  shift

  ( "$@" )
  status=$?

  if [ "$status" -eq "$RESTART_CODE" ]; then
    return "$RESTART_CODE"
  fi

  if [ "$status" -ne 0 ]; then
    msg ""
    err "No se pudo completar: $label"
    warn "No se cerro el asistente. Volveras al menu para revisar o reintentar."
    warn "Codigo de salida: $status"
    pause_enter
  fi

  return "$status"
}

normalize_user_path() {
  local path="$1"

  if is_windows && command_exists cygpath; then
    cygpath -u "$path" 2>/dev/null && return
  fi

  printf "%s" "$path"
}

save_workspace_path() {
  local path="$1"

  mkdir -p "$CONFIG_DIR" 2>/dev/null || return 1
  printf "%s\n" "$path" > "$WORKSPACE_FILE" || return 1
}

load_workspace_path() {
  if [ -f "$WORKSPACE_FILE" ]; then
    sed -n '1p' "$WORKSPACE_FILE"
  fi
}

delegate_to_repo_sync_if_available() {
  local repo_sync

  repo_sync="$(pwd -P)/$SELF_NAME"
  if [ -f "$repo_sync" ] && [ "$repo_sync" != "$SELF_PATH" ]; then
    info "El proyecto trae su propia version de $SELF_NAME."
    info "Cambiando a esa version para evitar usar un asistente viejo."
    exec env LIBRO_SYNC_GUARD=1 "$BASH" "$repo_sync"
  fi
}

choose_working_folder() {
  local current selected normalized

  current="$(pwd -P)"
  msg ""
  msg "${BOLD}Primer inicio: carpeta de trabajo${RESET}"
  msg "Ruta actual:"
  msg "  $current"
  msg ""

  if prompt_yes_no "Esta sera tu carpeta de trabajo para el libro?" "s"; then
    selected="$current"
  else
    selected="$(prompt_required "Escribe la ruta de la carpeta de trabajo:")"
    normalized="$(normalize_user_path "$selected")"
    selected="$normalized"
  fi

  mkdir -p "$selected" || die "No pude crear la carpeta: $selected"
  cd "$selected" || die "No pude entrar a la carpeta: $selected"
  ok "Carpeta de trabajo seleccionada: $(pwd -P)"
}

open_saved_workspace_if_available() {
  local saved

  saved="$(load_workspace_path)"
  [ -n "$saved" ] || return 1

  if [ -d "$saved/.git" ]; then
    info "Usando carpeta de trabajo guardada:"
    msg "  $saved"
    cd "$saved" || return 1
    delegate_to_repo_sync_if_available
    repo_bootstrap
    repo_menu
  fi

  if [ -d "$saved" ]; then
    warn "La carpeta guardada existe, pero aun no es una carpeta de proyecto Git:"
    msg "  $saved"
    if prompt_yes_no "Usar esa carpeta para descargar o preparar el proyecto?" "s"; then
      cd "$saved" || die "No pude entrar a la carpeta guardada."
      outside_repo_menu
    fi
  fi

  return 1
}

open_url() {
  local url="$1"

  if is_windows && command_exists cmd.exe; then
    cmd.exe /c start "" "$url" >/dev/null 2>&1 || true
  elif command_exists xdg-open; then
    xdg-open "$url" >/dev/null 2>&1 || true
  elif command_exists open; then
    open "$url" >/dev/null 2>&1 || true
  fi
}

find_gh_bin() {
  if command_exists gh; then
    printf "%s" "gh"
    return 0
  fi

  if is_windows; then
    if [ -x "/c/Program Files/GitHub CLI/gh.exe" ]; then
      printf "%s" "/c/Program Files/GitHub CLI/gh.exe"
      return 0
    fi
    if [ -x "/c/Program Files (x86)/GitHub CLI/gh.exe" ]; then
      printf "%s" "/c/Program Files (x86)/GitHub CLI/gh.exe"
      return 0
    fi
  fi

  return 1
}

install_git_linux() {
  if command_exists pacman; then
    if prompt_yes_no "Se detecto Arch/Manjaro. Instalar Git con 'sudo pacman -S --needed git'?" "s"; then
      sudo pacman -S --needed git
    fi
  elif command_exists apt-get; then
    if prompt_yes_no "Se detecto apt. Instalar Git con apt-get?" "s"; then
      sudo apt-get update
      sudo apt-get install -y git
    fi
  elif command_exists dnf; then
    if prompt_yes_no "Se detecto dnf. Instalar Git con 'sudo dnf install -y git'?" "s"; then
      sudo dnf install -y git
    fi
  elif command_exists zypper; then
    if prompt_yes_no "Se detecto zypper. Instalar Git con 'sudo zypper install -y git'?" "s"; then
      sudo zypper install -y git
    fi
  elif command_exists apk; then
    if prompt_yes_no "Se detecto apk. Instalar Git con 'sudo apk add git'?" "s"; then
      sudo apk add git
    fi
  else
    warn "No reconozco el gestor de paquetes. En Arch usa: sudo pacman -S git"
  fi
}

install_git_windows_hint() {
  warn "En Windows instala Git for Windows. Este archivo .cmd intenta hacerlo con winget antes de llegar aqui."
  if command_exists winget.exe && prompt_yes_no "Intentar instalar Git for Windows con winget?" "s"; then
    winget.exe install --id Git.Git -e --source winget
  else
    warn "Descarga manual: https://git-scm.com/download/win"
    if prompt_yes_no "Abrir pagina de descarga?" "s"; then
      open_url "https://git-scm.com/download/win"
    fi
  fi
}

ensure_git() {
  if command_exists git; then
    ok "$(git --version)"
    return
  fi

  warn "No se encontro Git en el PATH."
  if is_windows; then
    install_git_windows_hint
  elif is_linux; then
    install_git_linux
  else
    warn "Instala Git desde: https://git-scm.com/downloads"
  fi

  hash -r 2>/dev/null || true
  command_exists git || die "Git sigue sin estar disponible. Cierra y vuelve a abrir la terminal, o instalalo manualmente."
  ok "$(git --version)"
}

inside_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

move_to_repo_root_if_needed() {
  local root

  if inside_git_repo; then
    root="$(git rev-parse --show-toplevel)" || die "No pude detectar la raiz del repositorio."
    if [ "$PWD" != "$root" ]; then
      cd "$root" || die "No pude entrar a la raiz del repositorio: $root"
      info "Trabajando desde la raiz del repositorio: $root"
    fi
  fi
}

git_has_commits() {
  git rev-parse --verify HEAD >/dev/null 2>&1
}

current_branch() {
  local branch
  branch="$(git branch --show-current 2>/dev/null || true)"
  if [ -z "$branch" ]; then
    branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  fi
  printf "%s" "${branch:-$DEFAULT_BRANCH}"
}

validate_branch_name() {
  local branch="$1"
  git check-ref-format --branch "$branch" >/dev/null 2>&1
}

repo_url_to_dir() {
  local url="$1"
  local name
  name="${url##*/}"
  name="${name%.git}"
  name="${name:-Libro}"
  printf "%s" "$name"
}

detect_remote_default_branch() {
  local url="$1"
  local fallback="$2"
  local detected

  detected="$(git ls-remote --symref "$url" HEAD 2>/dev/null | awk '/^ref:/ { sub("refs/heads/", "", $2); print $2; exit }')"
  if [ -n "$detected" ]; then
    printf "%s" "$detected"
  else
    printf "%s" "$fallback"
  fi
}

github_slug_from_url() {
  local url="$1"
  local slug

  slug="${url%.git}"
  slug="${slug%/}"
  slug="${slug#https://github.com/}"
  slug="${slug#http://github.com/}"
  slug="${slug#git@github.com:}"
  slug="${slug#ssh://git@github.com/}"

  case "$slug" in
    */*) printf "%s" "$slug" ;;
    *) return 1 ;;
  esac
}

github_compare_url() {
  local upstream_slug="$1"
  local base_branch="$2"
  local login="$3"
  local head_branch="$4"

  printf "https://github.com/%s/compare/%s...%s:%s?expand=1" "$upstream_slug" "$base_branch" "$login" "$head_branch"
}

ensure_gitignore() {
  if [ -f ".gitignore" ]; then
    ok ".gitignore ya existe."
    return
  fi

  info "Creando .gitignore para un proyecto LaTeX limpio."
  cat > .gitignore <<'EOF'
# LaTeX build artifacts
*.aux
*.bbl
*.bcf
*.blg
*.dvi
*.fdb_latexmk
*.fls
*.idx
*.ilg
*.ind
*.lof
*.log
*.lot
*.nav
*.out
*.run.xml
*.snm
*.synctex.gz
*.toc
*.vrb
*.xdv

# Generated documents
*.pdf
!pso final borrador.pdf
!modelo-1.pdf

# LaTeX temporary folders
_minted-*/
*.listing
*.pyg

# Editor and OS noise
*~
*.bak
*.swp
*.swo
.DS_Store
Thumbs.db
desktop.ini

# Common build folders
build/
out/
tmp/
EOF
  ok ".gitignore creado."
}

ensure_gitattributes() {
  if [ -f ".gitattributes" ]; then
    return
  fi

  info "Creando .gitattributes para trabajar igual en Windows y Linux."
  cat > .gitattributes <<'EOF'
*.tex text eol=lf
*.bib text eol=lf
*.cls text eol=lf
*.sty text eol=lf
*.sh text eol=lf
*.cmd text eol=lf
*.bat text eol=crlf
*.ps1 text eol=crlf
EOF
  ok ".gitattributes creado."
}

configure_user() {
  local name email scope

  name="$(git config user.name 2>/dev/null || true)"
  email="$(git config user.email 2>/dev/null || true)"

  if [ -z "$name" ]; then
    name="$(prompt_required "Tu nombre para identificar tus guardados (commits):")"
    if prompt_yes_no "Guardar este nombre para todos tus proyectos Git?" "s"; then
      scope="--global"
    else
      scope="--local"
    fi
    git config "$scope" user.name "$name" || die "No pude guardar user.name."
  else
    ok "user.name configurado: $name"
  fi

  if [ -z "$email" ]; then
    email="$(prompt_required "Tu email para identificar tus guardados (commits):")"
    if prompt_yes_no "Guardar este email para todos tus proyectos Git?" "s"; then
      scope="--global"
    else
      scope="--local"
    fi
    git config "$scope" user.email "$email" || die "No pude guardar user.email."
  else
    ok "user.email configurado: $email"
  fi
}

install_gh_hint() {
  if is_windows; then
    warn "GitHub CLI no esta instalado. En Windows puedes usar: winget install --id GitHub.cli"
    if command_exists winget.exe && prompt_yes_no "Instalar GitHub CLI con winget ahora?" "s"; then
      winget.exe install --id GitHub.cli -e --source winget
      hash -r 2>/dev/null || true
    fi
  elif command_exists pacman; then
    warn "GitHub CLI no esta instalado. En Arch puedes usar: sudo pacman -S github-cli"
    if prompt_yes_no "Instalar GitHub CLI con pacman ahora?" "s"; then
      sudo pacman -S --needed github-cli
      hash -r 2>/dev/null || true
    fi
  elif command_exists apt-get; then
    warn "GitHub CLI no esta instalado. Guia oficial: https://cli.github.com/"
    warn "En Debian/Ubuntu puede requerir agregar el repositorio oficial de GitHub CLI."
  elif command_exists dnf; then
    warn "GitHub CLI no esta instalado. En Fedora puedes usar: sudo dnf install gh"
    if prompt_yes_no "Instalar GitHub CLI con dnf ahora?" "s"; then
      sudo dnf install -y gh
      hash -r 2>/dev/null || true
    fi
  else
    warn "GitHub CLI no esta instalado. Guia: https://cli.github.com/"
  fi
}

ensure_github_login() {
  local gh_bin

  gh_bin="$(find_gh_bin 2>/dev/null || true)"
  if [ -z "$gh_bin" ]; then
    install_gh_hint
    gh_bin="$(find_gh_bin 2>/dev/null || true)"
  fi

  if [ -z "$gh_bin" ]; then
    warn "No pude encontrar GitHub CLI. Git podria pedir credenciales al descargar o enviar cambios."
    warn "Si el proyecto es privado, instala GitHub CLI: https://cli.github.com/"
    return 1
  fi

  info "Verificando login de GitHub."
  if "$gh_bin" auth status -h github.com >/dev/null 2>&1; then
    ok "Sesion de GitHub activa."
    "$gh_bin" auth setup-git >/dev/null 2>&1 || true
    return 0
  fi

  warn "Primero iniciaremos sesion en GitHub para evitar problemas al clonar o subir cambios."
  warn "Se abrira el navegador o se mostrara un codigo de login."
  if "$gh_bin" auth login -h github.com -p https -w; then
    "$gh_bin" auth setup-git >/dev/null 2>&1 || true
    ok "Login de GitHub completado."
    return 0
  fi

  warn "No se completo el login de GitHub. Puedes continuar, pero Git podria pedir credenciales despues."
  return 1
}

create_remote_with_gh() {
  local gh_bin default_owner owner default_repo repo visibility visibility_flag full_repo

  gh_bin="$(find_gh_bin 2>/dev/null || true)"
  if [ -z "$gh_bin" ]; then
    install_gh_hint
    gh_bin="$(find_gh_bin 2>/dev/null || true)"
  fi
  [ -n "$gh_bin" ] || return 1

  if ! "$gh_bin" auth status >/dev/null 2>&1; then
    warn "Debes iniciar sesion en GitHub CLI."
    prompt_yes_no "Ejecutar 'gh auth login' ahora?" "s" || return 1
    "$gh_bin" auth login || return 1
  fi

  default_owner="$("$gh_bin" api user --jq .login 2>/dev/null || true)"
  default_repo="$(basename "$PWD" | tr ' ' '-' | tr -cd '[:alnum:]_.-')"
  [ -n "$default_repo" ] || default_repo="libro-latex"

  owner="$(prompt_default "Cuenta u organizacion de GitHub donde estara el proyecto" "${default_owner:-mi-usuario}")"
  repo="$(prompt_default "Nombre del proyecto en GitHub (repositorio)" "$default_repo")"

  msg "${BOLD}Visibilidad:${RESET}"
  msg "  1) privado (recomendado para borradores)"
  msg "  2) publico"
  msg "  3) interno (solo organizaciones compatibles)"
  printf "%b " "${YELLOW}Elige una opcion [1]${RESET}" >&2
  IFS= read -r visibility || exit 1
  visibility="${visibility:-1}"

  case "$visibility" in
    1) visibility_flag="--private" ;;
    2) visibility_flag="--public" ;;
    3) visibility_flag="--internal" ;;
    *) visibility_flag="--private" ;;
  esac

  full_repo="$repo"
  if [ -n "$owner" ] && [ "$owner" != "mi-usuario" ]; then
    full_repo="$owner/$repo"
  fi

  info "Creando repositorio en GitHub: $full_repo"
  "$gh_bin" repo create "$full_repo" "$visibility_flag" --source=. --remote=origin || return 1
  ok "Enlace del proyecto en GitHub configurado (remote origin)."
  return 0
}

add_or_replace_remote() {
  local remote_url existing
  remote_url="$(prompt_required "Pega el enlace del proyecto en GitHub (remote HTTPS o SSH):")"
  existing="$(git remote get-url origin 2>/dev/null || true)"

  if [ -n "$existing" ]; then
    git remote set-url origin "$remote_url" || return 1
  else
    git remote add origin "$remote_url" || return 1
  fi
  ok "Enlace del proyecto en GitHub configurado (origin): $remote_url"
}

ensure_remote() {
  local remote_url choice

  remote_url="$(git remote get-url origin 2>/dev/null || true)"
  if [ -n "$remote_url" ]; then
    ok "Enlace de GitHub configurado (origin): $remote_url"
    return
  fi

  if [ -n "$DEFAULT_REPO_URL" ]; then
    warn "No existe enlace con GitHub (remote origin)."
    if prompt_yes_no "Usar el repo configurado en este script?" "s"; then
      git remote add origin "$DEFAULT_REPO_URL" || die "No pude configurar origin."
      ok "Enlace de GitHub configurado (origin): $DEFAULT_REPO_URL"
      return
    fi
  fi

  warn "No existe enlace con GitHub (remote origin). Hace falta para descargar/enviar cambios."
  while true; do
    msg "${BOLD}Configurar enlace con GitHub (remote):${RESET}"
    msg "  1) Crear proyecto en GitHub (repositorio) con GitHub CLI (gh)"
    msg "  2) Enlazar un proyecto existente pegando su URL"
    msg "  0) Volver"
    printf "%b " "${YELLOW}Elige una opcion [1]${RESET}" >&2
    IFS= read -r choice || exit 1
    choice="${choice:-1}"

    case "$choice" in
      1)
        if create_remote_with_gh; then
          return
        fi
        warn "No se pudo crear con GitHub CLI. Puedes probar con URL manual."
        ;;
      2)
        add_or_replace_remote || die "No pude configurar el remoto origin."
        return
        ;;
      0)
        return 1
        ;;
      *)
        warn "Opcion no valida."
        ;;
    esac
  done
}

ensure_repo_here() {
  if inside_git_repo; then
    ok "Esta carpeta ya es un proyecto Git (repositorio local)."
    return
  fi

  warn "Esta carpeta aun no esta preparada como proyecto Git."
  prompt_yes_no "Preparar Git aqui (inicializar repositorio)?" "s" || return 1

  if git init -b "$DEFAULT_BRANCH" >/dev/null 2>&1; then
    ok "Proyecto preparado en la linea principal $DEFAULT_BRANCH (rama)."
  else
    git init || die "No pude preparar Git en esta carpeta."
    git checkout -b "$DEFAULT_BRANCH" || die "No pude crear la linea de trabajo $DEFAULT_BRANCH (rama)."
    ok "Proyecto preparado en la linea principal $DEFAULT_BRANCH (rama)."
  fi
}

switch_or_create_branch() {
  local target
  target="$(prompt_default "Nombre de la linea de trabajo (rama)" "$DEFAULT_BRANCH")"
  validate_branch_name "$target" || die "Nombre de linea de trabajo invalido (rama): $target"

  if git show-ref --verify --quiet "refs/heads/$target"; then
    git switch "$target" || die "No pude cambiar a la linea de trabajo $target (rama)."
  else
    git switch -c "$target" || die "No pude crear la linea de trabajo $target (rama)."
  fi
  ok "Linea de trabajo actual (rama): $(current_branch)"
}

normalize_main_branch() {
  local branch
  branch="$(current_branch)"
  if [ "$branch" = "master" ]; then
    warn "La linea de trabajo actual es 'master'. Para el equipo recomiendo usar '$DEFAULT_BRANCH'."
    if prompt_yes_no "Renombrar 'master' a '$DEFAULT_BRANCH' (rama principal)?" "s"; then
      git branch -M "$DEFAULT_BRANCH" || die "No pude renombrar la rama."
      ok "Linea principal renombrada a $DEFAULT_BRANCH (rama)."
    fi
  fi
}

has_unmerged_conflicts() {
  [ -n "$(git diff --name-only --diff-filter=U 2>/dev/null || true)" ]
}

show_conflicts_and_exit() {
  err "Hay choque de cambios (conflicto de Git). El script se detiene para no pisar el trabajo de nadie."
  msg "${YELLOW}Archivos con choque de cambios (conflicto):${RESET}"
  git diff --name-only --diff-filter=U >&2 || true
  msg ""
  msg "Resuelve el choque de cambios, revisa el documento y luego ejecuta de nuevo este script."
  exit 1
}

pull_latest() {
  local pull_log pull_status
  BRANCH="$(current_branch)"

  ensure_remote || die "Sin remoto origin no puedo sincronizar."

  if has_unmerged_conflicts; then
    show_conflicts_and_exit
  fi

  info "Descargando la ultima version del equipo (pull): git pull origin $BRANCH"
  pull_log="${TMPDIR:-/tmp}/libro_sync_pull_$$.log"
  rm -f "$pull_log"

  GIT_MERGE_AUTOEDIT=no git -c pull.rebase=false pull --no-edit --autostash origin "$BRANCH" 2>&1 | tee "$pull_log"
  pull_status=${PIPESTATUS[0]}

  if [ "$pull_status" -ne 0 ] && grep -qiE "unknown option|unrecognized option|usage: git pull" "$pull_log" 2>/dev/null; then
    warn "Tu Git no soporta guardado temporal automatico (--autostash). Reintentando sin esa opcion."
    rm -f "$pull_log"
    pull_log="${TMPDIR:-/tmp}/libro_sync_pull_retry_$$.log"
    GIT_MERGE_AUTOEDIT=no git -c pull.rebase=false pull --no-edit origin "$BRANCH" 2>&1 | tee "$pull_log"
    pull_status=${PIPESTATUS[0]}
  fi

  if [ "$pull_status" -eq 0 ]; then
    rm -f "$pull_log"
    ok "Descarga completada (pull). Tienes la version mas reciente disponible."
    restart_if_self_updated
    return
  fi

  if has_unmerged_conflicts; then
    rm -f "$pull_log"
    show_conflicts_and_exit
  fi

  if grep -qiE "couldn't find remote ref|no such ref|could not find remote ref|fatal: couldn't find remote ref" "$pull_log" 2>/dev/null; then
    rm -f "$pull_log"
    warn "La linea origin/$BRANCH aun no existe. Se continuara como primer envio (push) de esa rama."
    return
  fi

  rm -f "$pull_log"
  die "Fallo la descarga (pull). Revisa conexion, permisos de GitHub o nombre de rama."
}

status_has_changes() {
  [ -n "$(git status --short)" ]
}

remote_branch_ref() {
  local remote="$1"
  local branch="$2"
  printf "%s/%s" "$remote" "$branch"
}

remote_branch_exists_locally() {
  local remote="$1"
  local branch="$2"
  git rev-parse --verify --quiet "$(remote_branch_ref "$remote" "$branch")" >/dev/null
}

unpushed_commit_count() {
  local branch="$1"
  local remote_ref

  remote_ref="$(remote_branch_ref origin "$branch")"
  if remote_branch_exists_locally origin "$branch"; then
    git rev-list --count "${remote_ref}..HEAD" 2>/dev/null || printf "0"
  elif git_has_commits; then
    git rev-list --count HEAD 2>/dev/null || printf "0"
  else
    printf "0"
  fi
}

has_unpushed_commits() {
  local branch="$1"
  [ "$(unpushed_commit_count "$branch")" -gt 0 ]
}

show_unpushed_commits() {
  local branch="$1"
  local remote_ref

  remote_ref="$(remote_branch_ref origin "$branch")"
  msg ""
  warn "Hay guardados locales (commits) que aun no estan en GitHub."
  if remote_branch_exists_locally origin "$branch"; then
    git log --oneline "${remote_ref}..HEAD" >&2 || true
  else
    git log --oneline -5 >&2 || true
  fi
  msg ""
}

add_files_interactively() {
  local path added_any
  added_any="n"

  if prompt_yes_no "Subir todos los cambios listados?" "s"; then
    git add . || die "Fallo 'git add .'."
    return
  fi

  msg "Escribe una ruta por linea. Deja una linea vacia para terminar."
  while true; do
    printf "%b " "${YELLOW}Archivo o carpeta:${RESET}" >&2
    IFS= read -r path || exit 1
    [ -n "$path" ] || break
    git add -- "$path" || die "No pude agregar: $path"
    added_any="s"
  done

  [ "$added_any" = "s" ] || die "No seleccionaste archivos para subir."
}

ensure_fork_remote() {
  local gh_bin="$1"
  local upstream_slug="$2"
  local login="$3"
  local repo_name="$4"
  local fork_url

  fork_url="https://github.com/${login}/${repo_name}.git"

  if git remote get-url fork >/dev/null 2>&1; then
    git remote set-url fork "$fork_url" || die "No pude actualizar el remoto fork."
    return
  fi

  info "Creando o verificando tu copia personal (fork) en GitHub: ${login}/${repo_name}"
  "$gh_bin" api -X POST "repos/${upstream_slug}/forks" >/dev/null 2>&1 || true

  for _ in 1 2 3 4 5; do
    if "$gh_bin" repo view "${login}/${repo_name}" >/dev/null 2>&1; then
      git remote add fork "$fork_url" || git remote set-url fork "$fork_url" || die "No pude configurar el remoto fork."
      ok "Copia personal configurada (fork remoto): $fork_url"
      return
    fi
    sleep 2
  done

  die "No pude confirmar que exista tu copia personal (fork) ${login}/${repo_name}. Revisa GitHub y vuelve a intentar."
}

create_pull_request_from_fork() {
  local branch="$1"
  local gh_bin origin_url upstream_slug login repo_name pr_branch title body pr_output pr_status pr_url compare_url

  gh_bin="$(find_gh_bin 2>/dev/null || true)"
  [ -n "$gh_bin" ] || die "Para solicitar revision (Pull Request) se necesita GitHub CLI (gh)."
  ensure_github_login || die "No se pudo iniciar sesion en GitHub CLI."

  origin_url="$(git remote get-url origin 2>/dev/null || true)"
  upstream_slug="$(github_slug_from_url "$origin_url")" || die "No pude reconocer el proyecto de GitHub desde origin: $origin_url"
  login="$("$gh_bin" api user --jq .login 2>/dev/null || true)"
  [ -n "$login" ] || die "No pude detectar tu usuario de GitHub."
  repo_name="${upstream_slug##*/}"

  ensure_fork_remote "$gh_bin" "$upstream_slug" "$login" "$repo_name"

  pr_branch="sync-${login}-$(date +%Y%m%d-%H%M%S)"
  info "Subiendo tus guardados (commits) a tu copia personal (fork): fork/$pr_branch"
  git push -u fork "HEAD:${pr_branch}" || die "No pude subir tus guardados (commits) a tu copia personal (fork)."

  title="$(git log -1 --pretty=%s 2>/dev/null || printf "Aporte desde sync.cmd")"
  body="Pull request creado automaticamente por sync.cmd porque esta cuenta no tiene permiso directo para escribir en ${upstream_slug}.

Resumen:
- Usuario: ${login}
- Rama local: ${branch}
- Rama del fork: ${login}:${pr_branch}

Revisar y aceptar este PR para incorporar los cambios al libro."

  info "Creando solicitud de revision (Pull Request) hacia ${upstream_slug}:${branch}"
  pr_output="$("$gh_bin" pr create \
    --repo "$upstream_slug" \
    --base "$branch" \
    --head "${login}:${pr_branch}" \
    --title "$title" \
    --body "$body" 2>&1)"
  pr_status=$?

  if [ "$pr_status" -eq 0 ]; then
    ok "Solicitud de revision creada (Pull Request). Un mantenedor debe revisarla y aceptarla."
    msg "$pr_output"
    pr_url="$(printf "%s\n" "$pr_output" | awk '/^https?:\/\// { print; exit }')"
    if [ -n "$pr_url" ]; then
      info "Abriendo la solicitud de revision (Pull Request):"
      msg "  $pr_url"
      open_url "$pr_url"
    fi
    return
  fi

  warn "La linea de trabajo se subio a tu copia personal (fork), pero GitHub CLI no pudo crear la solicitud de revision (Pull Request) automaticamente."
  warn "Detalle devuelto por GitHub CLI:"
  msg "$pr_output"
  compare_url="$(github_compare_url "$upstream_slug" "$branch" "$login" "$pr_branch")"
  msg ""
  warn "Abre este enlace para crear la solicitud de revision (Pull Request) manualmente:"
  msg "  $compare_url"
  open_url "$compare_url"
  ok "Tus cambios ya estan en tu copia personal (fork). Falta confirmar la solicitud de revision (Pull Request) en el navegador."
}

push_current_branch() {
  local branch="$1"
  local push_log push_status

  info "Enviando cambios a GitHub (push): git push -u origin $branch"
  push_log="${TMPDIR:-/tmp}/libro_sync_push_$$.log"
  rm -f "$push_log"

  git push -u origin "$branch" 2>&1 | tee "$push_log"
  push_status=${PIPESTATUS[0]}

  if [ "$push_status" -eq 0 ]; then
    rm -f "$push_log"
    ok "Sincronizacion completada."
    return
  fi

  if grep -qiE "Permission to .* denied|requested URL returned error: 403|Write access to repository not granted|permission denied|ERROR: Permission denied" "$push_log" 2>/dev/null; then
    rm -f "$push_log"
    warn "Tu cuenta de GitHub no tiene permiso directo para escribir en este proyecto."
    warn "Tus guardados (commits) NO se perdieron: estan guardados localmente."
    if prompt_yes_no "Quieres crear una solicitud de revision (Pull Request) desde tu copia personal (fork)?" "s"; then
      create_pull_request_from_fork "$branch"
      return
    fi
    die "Envio cancelado (push). Tus guardados (commits) siguen locales; puedes pedir acceso o volver a intentar luego."
  fi

  rm -f "$push_log"
  die "Fallo el envio (push). Si alguien subio cambios antes que tu, vuelve a ejecutar el asistente para traer cambios y reintentar."
}

commit_and_push() {
  local section description commit_msg custom_msg

  pull_latest

  msg ""
  info "Estado actual de tus cambios:"
  git status -s
  msg ""

  if ! status_has_changes; then
    BRANCH="$(current_branch)"
    if has_unpushed_commits "$BRANCH"; then
      show_unpushed_commits "$BRANCH"
      if prompt_yes_no "Quieres intentar enviar esos guardados pendientes (commits) ahora?" "s"; then
        push_current_branch "$BRANCH"
      else
        warn "No se envio nada. Los guardados (commits) siguen en tu computadora."
      fi
      return
    fi
    ok "No hay archivos modificados ni guardados pendientes por enviar (commits)."
    return
  fi

  section="$(prompt_required "Que seccion o capitulo modificaste?:")"
  description="$(prompt_required "Describe brevemente tu aporte o cambios:")"
  section="${section//$'\n'/ }"
  description="${description//$'\n'/ }"
  commit_msg="Aporte [${section}]: ${description}"

  msg ""
  info "Mensaje para el guardado (commit) propuesto:"
  msg "  $commit_msg"
  if ! prompt_yes_no "Confirmar este mensaje?" "s"; then
    custom_msg="$(prompt_required "Escribe el mensaje completo para el guardado (commit):")"
    commit_msg="$custom_msg"
  fi

  add_files_interactively

  msg ""
  info "Archivos preparados para guardar (commit):"
  git diff --cached --name-status || true
  msg ""

  if git diff --cached --quiet; then
    ok "No hay cambios listos para guardar (commit)."
    return
  fi

  prompt_yes_no "Crear guardado (commit) y enviarlo ahora?" "s" || die "Operacion cancelada antes del guardado (commit)."

  info "Creando guardado local (commit)."
  git commit -m "$commit_msg" || die "Fallo el guardado (commit). Revisa los mensajes anteriores."

  BRANCH="$(current_branch)"
  push_current_branch "$BRANCH"
}

copy_self_into_repo() {
  local target
  refresh_self_path
  target="$PWD/$SELF_NAME"

  if [ -f "$target" ] && [ "$SELF_PATH" != "$target" ]; then
    info "El proyecto ya contiene $SELF_NAME. No lo sobrescribire con una copia externa."
    save_workspace_path "$(pwd -P)" || true
    request_restart
  fi

  if [ -f "$SELF_PATH" ] && [ "$SELF_PATH" != "$target" ]; then
    cp "$SELF_PATH" "$target" 2>/dev/null || {
      warn "No pude copiar este asistente dentro del repo. Puedes seguir usando el archivo original."
      return
    }
    chmod +x "$target" 2>/dev/null || true
    ok "Copie este asistente dentro del proyecto: $target"
  fi
}

directory_has_entries() {
  local dir="$1"
  [ -n "$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]
}

directory_has_user_files() {
  local dir="$1"
  [ -n "$(find "$dir" -mindepth 1 -maxdepth 1 ! -name "$SELF_NAME" -print -quit 2>/dev/null)" ]
}

make_backup_path() {
  local path="$1"
  local stamp base parent
  stamp="$(date +%Y%m%d_%H%M%S)"
  base="$(basename -- "$path")"
  parent="$(dirname -- "$path")"
  printf "%s/%s_BACKUP_EMERGENCIA_%s" "$parent" "$base" "$stamp"
}

backup_existing_path() {
  local path="$1"
  local backup

  [ -e "$path" ] || return 0
  backup="$(make_backup_path "$path")"
  info "Creando backup de emergencia:"
  msg "  $backup"
  mv "$path" "$backup" || die "No pude crear el backup de emergencia."
  ok "Backup creado. Si elegiste reemplazar por error, tu avance esta ahi."
}

clone_repo_into() {
  local url="$1"
  local branch="$2"
  local dest="$3"
  local dest_parent dest_name

  dest_parent="$(dirname -- "$dest")"
  dest_name="$(basename -- "$dest")"
  mkdir -p "$dest_parent" || die "No pude crear la carpeta base: $dest_parent"

  info "Descargando por primera vez la ultima version del proyecto (clone)."
  if (cd "$dest_parent" && git clone --branch "$branch" "$url" "$dest_name"); then
    return
  fi

    warn "No pude descargar la linea '$branch' (rama). Intentare descargar la rama por defecto del proyecto."
  (cd "$dest_parent" && git clone "$url" "$dest_name") || die "No pude descargar el proyecto (clone). Revisa link, conexion y permisos."
}

commit_local_snapshot() {
  local section description commit_msg

  if ! status_has_changes; then
    ok "No hay cambios locales para respaldar en un guardado (commit)."
    return
  fi

  msg ""
  warn "Se detectaron archivos locales antes de descargar el proyecto."
  git status -s
  msg ""
  section="$(prompt_default "Que seccion/capitulo contiene tu avance local" "Borrador local")"
  description="$(prompt_default "Describe brevemente ese avance local" "Respaldo antes de sincronizar con GitHub")"
  commit_msg="Aporte [${section}]: ${description}"

  git add . || die "No pude preparar tus archivos locales."
  git diff --cached --quiet && return
  git commit -m "$commit_msg" || die "No pude crear el guardado de respaldo local (commit)."
  ok "Avance local guardado en un commit."
}

pull_latest_allow_unrelated() {
  local pull_log pull_status
  BRANCH="$(current_branch)"

  info "Descargando y combinando la version de GitHub con tu avance local."
  pull_log="${TMPDIR:-/tmp}/libro_sync_pull_combine_$$.log"
  rm -f "$pull_log"

  GIT_MERGE_AUTOEDIT=no git -c pull.rebase=false pull --no-edit --allow-unrelated-histories origin "$BRANCH" 2>&1 | tee "$pull_log"
  pull_status=${PIPESTATUS[0]}

  if [ "$pull_status" -eq 0 ]; then
    rm -f "$pull_log"
    ok "Combinacion completada."
    restart_if_self_updated
    return
  fi

  if has_unmerged_conflicts; then
    rm -f "$pull_log"
    show_conflicts_and_exit
  fi

  rm -f "$pull_log"
  die "No pude combinar con GitHub. Revisa conexion, permisos o el nombre de la linea de trabajo (rama)."
}

combine_existing_folder_with_repo() {
  local url="$1"
  local branch="$2"
  local dest="$3"

  cd "$dest" || die "No pude entrar a $dest"

  if ! inside_git_repo; then
    if git init -b "$branch" >/dev/null 2>&1; then
      ok "Proyecto local preparado en $branch (repositorio/rama)."
    else
      git init || die "No pude preparar Git aqui."
      git checkout -b "$branch" || die "No pude crear la linea de trabajo $branch (rama)."
    fi
  fi

  configure_user
  ensure_gitignore
  ensure_gitattributes
  git remote remove origin >/dev/null 2>&1 || true
  git remote add origin "$url" || die "No pude configurar origin."
  commit_local_snapshot
  pull_latest_allow_unrelated

  if prompt_yes_no "Enviar ahora el guardado/combinacion local a GitHub (push/merge)?" "s"; then
    push_current_branch "$branch"
  fi

  repo_bootstrap
}

handle_existing_destination() {
  local url="$1"
  local branch="$2"
  local dest="$3"
  local choice

  if [ -d "$dest/.git" ]; then
    info "La carpeta ya es un proyecto Git:"
    msg "  $dest"
    cd "$dest" || die "No pude entrar al proyecto existente."
    git remote remove origin >/dev/null 2>&1 || true
    git remote add origin "$url" || die "No pude configurar origin."
    repo_bootstrap
    pull_latest
    return
  fi

  warn "Ya existe contenido local en:"
  msg "  $dest"
  msg ""
  msg "${BOLD}Que quieres hacer?${RESET}"
  msg "  1) Reemplazar por la version de GitHub (crea backup de emergencia)"
  msg "  2) Conservar/enviar mi avance local y luego descargar GitHub"
  msg "  0) Cancelar"
  printf "%b " "${YELLOW}Elige una opcion [2]${RESET}" >&2
  IFS= read -r choice || exit 1
  choice="${choice:-2}"

  case "$choice" in
    1)
      backup_existing_path "$dest"
      clone_repo_into "$url" "$branch" "$dest"
      cd "$dest" || die "No pude entrar al proyecto clonado."
      ;;
    2)
      combine_existing_folder_with_repo "$url" "$branch" "$dest"
      ;;
    0)
      die "Operacion cancelada para proteger tus archivos locales."
      ;;
    *)
      die "Opcion no valida."
      ;;
  esac
}

clone_project() {
  local url branch repo_dir base final_dest

  ensure_git

  url="$DEFAULT_REPO_URL"
  if [ -z "$url" ]; then
    url="$(prompt_required "Pega el link del repositorio del libro (HTTPS o SSH):")"
  else
    msg "Proyecto configurado: $url"
    if ! prompt_yes_no "Usar este proyecto de GitHub?" "s"; then
      url="$(prompt_required "Pega el link del repositorio del libro (HTTPS o SSH):")"
    fi
  fi

  branch="$(detect_remote_default_branch "$url" "$DEFAULT_BRANCH")"
  ok "Linea principal detectada/usada (rama): $branch"
  validate_branch_name "$branch" || die "Nombre de linea de trabajo invalido (rama): $branch"

  repo_dir="$DEFAULT_PROJECT_DIR"
  [ -n "$repo_dir" ] || repo_dir="$(repo_url_to_dir "$url")"

  base="$(pwd -P)"
  if [ -d "$base/.git" ]; then
    final_dest="$base"
  elif directory_has_user_files "$base"; then
    warn "La carpeta base ya contiene archivos:"
    msg "  $base"
    if prompt_yes_no "Estos archivos son tu avance local del libro y quieres usar esta carpeta como proyecto?" "n"; then
      final_dest="$base"
    else
      final_dest="$base/$repo_dir"
    fi
  elif directory_has_entries "$base"; then
    final_dest="$base/$repo_dir"
  else
    final_dest="$base"
  fi

  if [ -e "$final_dest" ] && directory_has_entries "$final_dest"; then
    handle_existing_destination "$url" "$branch" "$final_dest"
  else
    clone_repo_into "$url" "$branch" "$final_dest"
    cd "$final_dest" || die "No pude entrar al proyecto clonado."
  fi

  copy_self_into_repo
  repo_bootstrap
  ok "Proyecto listo con la ultima version disponible."
}

repo_bootstrap() {
  move_to_repo_root_if_needed
  ensure_gitignore
  ensure_gitattributes
  configure_user
  normalize_main_branch
  save_workspace_path "$(pwd -P)" || warn "No pude recordar esta carpeta para proximos inicios."
}

create_or_link_project_here() {
  ensure_git
  ensure_repo_here || return
  move_to_repo_root_if_needed
  repo_bootstrap
  ensure_remote || return
  ok "Proyecto Git preparado."
  repo_menu
}

show_repo_status() {
  move_to_repo_root_if_needed
  msg ""
  msg "${BOLD}Ruta:${RESET} $(pwd -P)"
  msg "${BOLD}Linea de trabajo (rama):${RESET} $(current_branch)"
  msg "${BOLD}Enlace de GitHub (remote):${RESET} $(git remote get-url origin 2>/dev/null || printf 'sin origin')"
  msg ""
  git status -sb
}

repo_menu() {
  local choice action_status

  while true; do
    move_to_repo_root_if_needed
    BRANCH="$(current_branch)"
    msg ""
    msg "${BOLD}Asistente del libro${RESET}"
    msg "Ruta: $(pwd -P)"
    msg "Linea de trabajo (rama): $BRANCH"
    msg "------------------------------------"
    msg "  1) Descargar la ultima version del equipo (pull)"
    msg "  2) Guardar y enviar mis cambios (pull + commit + push)"
    msg "  3) Ver que archivos cambiaron (status)"
    msg "  4) Configurar mi nombre/correo para guardados (git config)"
    msg "  5) Configurar enlace con GitHub (remote)"
    msg "  6) Cambiar linea de trabajo - avanzado (branch)"
    msg "  0) Salir"
    printf "%b " "${YELLOW}Elige una opcion [2]${RESET}" >&2
    IFS= read -r choice || exit 1
    choice="${choice:-2}"

    case "$choice" in
      1)
        run_safe_action "descargar ultima version del equipo" pull_latest
        action_status=$?
        [ "$action_status" -eq "$RESTART_CODE" ] && request_restart
        [ "$action_status" -eq 0 ] && pause_enter
        ;;
      2)
        run_safe_action "guardar y enviar mis cambios" commit_and_push
        action_status=$?
        [ "$action_status" -eq "$RESTART_CODE" ] && request_restart
        [ "$action_status" -eq 0 ] && pause_enter
        ;;
      3)
        run_safe_action "ver archivos cambiados" show_repo_status
        action_status=$?
        [ "$action_status" -eq "$RESTART_CODE" ] && request_restart
        [ "$action_status" -eq 0 ] && pause_enter
        ;;
      4)
        run_safe_action "configurar nombre/correo para guardados" configure_user
        action_status=$?
        [ "$action_status" -eq "$RESTART_CODE" ] && request_restart
        [ "$action_status" -eq 0 ] && pause_enter
        ;;
      5)
        run_safe_action "configurar enlace con GitHub" ensure_remote
        action_status=$?
        [ "$action_status" -eq "$RESTART_CODE" ] && request_restart
        [ "$action_status" -eq 0 ] && pause_enter
        ;;
      6)
        warn "Para este equipo recomiendo trabajar en una sola linea: $DEFAULT_BRANCH (rama)."
        run_safe_action "cambiar linea de trabajo" switch_or_create_branch
        action_status=$?
        [ "$action_status" -eq "$RESTART_CODE" ] && request_restart
        [ "$action_status" -eq 0 ] && pause_enter
        ;;
      0)
        ok "Listo."
        exit 0
        ;;
      *)
        warn "Opcion no valida."
        ;;
    esac
  done
}

outside_repo_menu() {
  choose_working_folder

  while true; do
    msg ""
    msg "${BOLD}Primer inicio: proyecto del libro en GitHub${RESET}"
    msg "Carpeta de trabajo:"
    msg "  $(pwd -P)"
    msg ""

    run_safe_action "configurar y descargar el proyecto" clone_project
    case "$?" in
      0)
        open_saved_workspace_if_available || {
          warn "El proyecto se preparo, pero no pude abrir la carpeta guardada."
          pause_enter
        }
        ;;
      "$RESTART_CODE")
        request_restart
        ;;
      *)
        warn "Volvemos al paso del link del proyecto."
        ;;
    esac
  done
}

main() {
  if [ ! -t 0 ]; then
    die "Este asistente es interactivo. Ejecutalo desde una terminal o con doble clic en Windows."
  fi

  refresh_self_path
  capture_self_signature
  ensure_git
  ensure_github_login || true

  if inside_git_repo; then
    repo_bootstrap
    repo_menu
  elif open_saved_workspace_if_available; then
    exit 0
  else
    outside_repo_menu
  fi
}

run_supervisor() {
  local status

  while true; do
    env LIBRO_SYNC_GUARD=1 "$BASH" "$0" "$@"
    status=$?

    case "$status" in
      0)
        exit 0
        ;;
      "$RESTART_CODE")
        info "Reiniciando con la version mas reciente del asistente..."
        continue
        ;;
      *)
        msg ""
        err "El asistente encontro un error y se detuvo de forma segura."
        warn "La terminal queda abierta para que puedas leer el mensaje anterior."
        warn "Codigo de salida: $status"
        pause_enter
        if prompt_yes_no "Quieres volver a abrir el asistente?" "s"; then
          continue
        fi
        exit "$status"
        ;;
    esac
  done
}

if [ "${LIBRO_SYNC_GUARD:-}" != "1" ]; then
  run_supervisor "$@"
fi

main "$@"

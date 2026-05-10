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
# 1. Crea el repo en GitHub.
# 2. Pega aqui la URL HTTPS o SSH del repo.
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
    name="$(prompt_required "Tu nombre para los commits:")"
    if prompt_yes_no "Guardar este nombre globalmente para todos tus repositorios?" "s"; then
      scope="--global"
    else
      scope="--local"
    fi
    git config "$scope" user.name "$name" || die "No pude guardar user.name."
  else
    ok "user.name configurado: $name"
  fi

  if [ -z "$email" ]; then
    email="$(prompt_required "Tu email para los commits:")"
    if prompt_yes_no "Guardar este email globalmente para todos tus repositorios?" "s"; then
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
    if command_exists winget.exe && prompt_yes_no "Intentar instalar GitHub CLI con winget?" "n"; then
      winget.exe install --id GitHub.cli -e --source winget
      hash -r 2>/dev/null || true
    fi
  elif command_exists pacman; then
    warn "GitHub CLI no esta instalado. En Arch puedes usar: sudo pacman -S github-cli"
    if prompt_yes_no "Intentar instalar GitHub CLI con pacman?" "n"; then
      sudo pacman -S --needed github-cli
      hash -r 2>/dev/null || true
    fi
  else
    warn "GitHub CLI no esta instalado. Guia: https://cli.github.com/"
  fi
}

create_remote_with_gh() {
  local default_owner owner default_repo repo visibility visibility_flag full_repo

  if ! command_exists gh; then
    install_gh_hint
  fi
  command_exists gh || return 1

  if ! gh auth status >/dev/null 2>&1; then
    warn "Debes iniciar sesion en GitHub CLI."
    prompt_yes_no "Ejecutar 'gh auth login' ahora?" "s" || return 1
    gh auth login || return 1
  fi

  default_owner="$(gh api user --jq .login 2>/dev/null || true)"
  default_repo="$(basename "$PWD" | tr ' ' '-' | tr -cd '[:alnum:]_.-')"
  [ -n "$default_repo" ] || default_repo="libro-latex"

  owner="$(prompt_default "Cuenta u organizacion de GitHub" "${default_owner:-mi-usuario}")"
  repo="$(prompt_default "Nombre del repositorio" "$default_repo")"

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
  gh repo create "$full_repo" "$visibility_flag" --source=. --remote=origin || return 1
  ok "Remoto origin configurado con GitHub."
  return 0
}

add_or_replace_remote() {
  local remote_url existing
  remote_url="$(prompt_required "Pega la URL del repositorio remoto (HTTPS o SSH):")"
  existing="$(git remote get-url origin 2>/dev/null || true)"

  if [ -n "$existing" ]; then
    git remote set-url origin "$remote_url" || return 1
  else
    git remote add origin "$remote_url" || return 1
  fi
  ok "Remoto origin configurado: $remote_url"
}

ensure_remote() {
  local remote_url choice

  remote_url="$(git remote get-url origin 2>/dev/null || true)"
  if [ -n "$remote_url" ]; then
    ok "Remoto origin: $remote_url"
    return
  fi

  if [ -n "$DEFAULT_REPO_URL" ]; then
    warn "No existe remoto origin."
    if prompt_yes_no "Usar el repo configurado en este script?" "s"; then
      git remote add origin "$DEFAULT_REPO_URL" || die "No pude configurar origin."
      ok "Remoto origin configurado: $DEFAULT_REPO_URL"
      return
    fi
  fi

  warn "No existe remoto 'origin'. Hace falta uno para hacer pull/push."
  while true; do
    msg "${BOLD}Configurar remoto:${RESET}"
    msg "  1) Crear repositorio en GitHub con GitHub CLI (gh)"
    msg "  2) Enlazar un repositorio existente pegando su URL"
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
    ok "Este directorio ya es un repositorio Git."
    return
  fi

  warn "Este directorio aun no es un repositorio Git."
  prompt_yes_no "Inicializar Git aqui?" "s" || return 1

  if git init -b "$DEFAULT_BRANCH" >/dev/null 2>&1; then
    ok "Repositorio inicializado en la rama $DEFAULT_BRANCH."
  else
    git init || die "No pude inicializar el repositorio."
    git checkout -b "$DEFAULT_BRANCH" || die "No pude crear la rama $DEFAULT_BRANCH."
    ok "Repositorio inicializado en la rama $DEFAULT_BRANCH."
  fi
}

switch_or_create_branch() {
  local target
  target="$(prompt_default "Nombre de la rama" "$DEFAULT_BRANCH")"
  validate_branch_name "$target" || die "Nombre de rama invalido: $target"

  if git show-ref --verify --quiet "refs/heads/$target"; then
    git switch "$target" || die "No pude cambiar a $target."
  else
    git switch -c "$target" || die "No pude crear la rama $target."
  fi
  ok "Rama actual: $(current_branch)"
}

normalize_main_branch() {
  local branch
  branch="$(current_branch)"
  if [ "$branch" = "master" ]; then
    warn "La rama actual es 'master'. Para el equipo recomiendo usar '$DEFAULT_BRANCH'."
    if prompt_yes_no "Renombrar 'master' a '$DEFAULT_BRANCH'?" "s"; then
      git branch -M "$DEFAULT_BRANCH" || die "No pude renombrar la rama."
      ok "Rama renombrada a $DEFAULT_BRANCH."
    fi
  fi
}

has_unmerged_conflicts() {
  [ -n "$(git diff --name-only --diff-filter=U 2>/dev/null || true)" ]
}

show_conflicts_and_exit() {
  err "Hay conflictos de Git. El script se detiene para no pisar el trabajo de nadie."
  msg "${YELLOW}Archivos en conflicto:${RESET}"
  git diff --name-only --diff-filter=U >&2 || true
  msg ""
  msg "Resuelve los conflictos, revisa el documento, luego ejecuta de nuevo este script."
  exit 1
}

pull_latest() {
  local pull_log pull_status
  BRANCH="$(current_branch)"

  ensure_remote || die "Sin remoto origin no puedo sincronizar."

  if has_unmerged_conflicts; then
    show_conflicts_and_exit
  fi

  info "Descargando cambios del equipo: git pull origin $BRANCH"
  pull_log="${TMPDIR:-/tmp}/libro_sync_pull_$$.log"
  rm -f "$pull_log"

  GIT_MERGE_AUTOEDIT=no git -c pull.rebase=false pull --no-edit --autostash origin "$BRANCH" 2>&1 | tee "$pull_log"
  pull_status=${PIPESTATUS[0]}

  if [ "$pull_status" -ne 0 ] && grep -qiE "unknown option|unrecognized option|usage: git pull" "$pull_log" 2>/dev/null; then
    warn "Tu Git no soporta --autostash en pull. Reintentando sin esa opcion."
    rm -f "$pull_log"
    pull_log="${TMPDIR:-/tmp}/libro_sync_pull_retry_$$.log"
    GIT_MERGE_AUTOEDIT=no git -c pull.rebase=false pull --no-edit origin "$BRANCH" 2>&1 | tee "$pull_log"
    pull_status=${PIPESTATUS[0]}
  fi

  if [ "$pull_status" -eq 0 ]; then
    rm -f "$pull_log"
    ok "Pull completado. Tienes la version mas reciente disponible."
    return
  fi

  if has_unmerged_conflicts; then
    rm -f "$pull_log"
    show_conflicts_and_exit
  fi

  if grep -qiE "couldn't find remote ref|no such ref|could not find remote ref|fatal: couldn't find remote ref" "$pull_log" 2>/dev/null; then
    rm -f "$pull_log"
    warn "La rama origin/$BRANCH aun no existe. Se continuara como primer push de esa rama."
    return
  fi

  rm -f "$pull_log"
  die "Fallo el pull. Revisa conexion, permisos de GitHub o nombre de rama."
}

status_has_changes() {
  [ -n "$(git status --short)" ]
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

commit_and_push() {
  local section description commit_msg custom_msg

  pull_latest

  msg ""
  info "Estado actual de tus cambios:"
  git status -s
  msg ""

  if ! status_has_changes; then
    ok "No hay cambios locales para enviar."
    return
  fi

  section="$(prompt_required "Que seccion o capitulo modificaste?:")"
  description="$(prompt_required "Describe brevemente tu aporte o cambios:")"
  section="${section//$'\n'/ }"
  description="${description//$'\n'/ }"
  commit_msg="Aporte [${section}]: ${description}"

  msg ""
  info "Mensaje de commit propuesto:"
  msg "  $commit_msg"
  if ! prompt_yes_no "Confirmar este mensaje?" "s"; then
    custom_msg="$(prompt_required "Escribe el mensaje de commit completo:")"
    commit_msg="$custom_msg"
  fi

  add_files_interactively

  msg ""
  info "Archivos preparados para commit:"
  git diff --cached --name-status || true
  msg ""

  if git diff --cached --quiet; then
    ok "No hay cambios versionables para commitear."
    return
  fi

  prompt_yes_no "Crear commit y subirlo ahora?" "s" || die "Operacion cancelada antes del commit."

  info "Creando commit."
  git commit -m "$commit_msg" || die "Fallo el commit. Revisa los mensajes anteriores."

  BRANCH="$(current_branch)"
  info "Enviando cambios: git push -u origin $BRANCH"
  git push -u origin "$BRANCH" || die "Fallo el push. Ejecuta de nuevo este script para traer cambios y reintentar."
  ok "Sincronizacion completada."
}

copy_self_into_repo() {
  local target
  refresh_self_path
  target="$PWD/$SELF_NAME"

  if [ -f "$SELF_PATH" ] && [ "$SELF_PATH" != "$target" ]; then
    cp "$SELF_PATH" "$target" 2>/dev/null || {
      warn "No pude copiar este asistente dentro del repo. Puedes seguir usando el archivo original."
      return
    }
    chmod +x "$target" 2>/dev/null || true
    ok "Copie este asistente dentro del proyecto: $target"
  fi
}

clone_project() {
  local url branch default_dir dest parent final_dest choice

  ensure_git

  url="$DEFAULT_REPO_URL"
  if [ -z "$url" ]; then
    url="$(prompt_required "URL del repositorio del libro (HTTPS o SSH):")"
  else
    msg "Repo configurado: $url"
    if ! prompt_yes_no "Usar este repositorio?" "s"; then
      url="$(prompt_required "URL del repositorio del libro (HTTPS o SSH):")"
    fi
  fi

  branch="$(prompt_default "Rama principal para clonar" "$DEFAULT_BRANCH")"
  validate_branch_name "$branch" || die "Nombre de rama invalido: $branch"

  default_dir="$DEFAULT_PROJECT_DIR"
  [ -n "$default_dir" ] || default_dir="$(repo_url_to_dir "$url")"
  dest="$(prompt_default "Nombre de la carpeta donde quedara el libro" "$default_dir")"

  parent="$(pwd -P)"
  final_dest="$parent/$dest"

  if [ -e "$final_dest" ]; then
    if [ -d "$final_dest/.git" ]; then
      warn "La carpeta ya existe y parece ser el repo."
      if prompt_yes_no "Entrar a esa carpeta y abrir el menu del proyecto?" "s"; then
        cd "$final_dest" || die "No pude entrar a $final_dest"
        repo_bootstrap
        repo_menu
        return
      fi
    else
      warn "La carpeta ya existe pero no parece repo Git: $final_dest"
      choice="$(prompt_required "Escribe otro nombre de carpeta:")"
      dest="$choice"
      final_dest="$parent/$dest"
    fi
  fi

  info "Clonando $url en $final_dest"
  if ! git clone --branch "$branch" "$url" "$dest"; then
    warn "No pude clonar la rama '$branch'. Intentare clonar la rama por defecto del repo."
    git clone "$url" "$dest" || die "No pude clonar el repositorio. Revisa URL, conexion y permisos."
  fi

  cd "$final_dest" || die "No pude entrar al proyecto clonado."
  copy_self_into_repo
  repo_bootstrap
  ok "Proyecto listo. Antes de editar usa la opcion 1 para descargar la ultima version."
  repo_menu
}

repo_bootstrap() {
  move_to_repo_root_if_needed
  ensure_gitignore
  ensure_gitattributes
  configure_user
  normalize_main_branch
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
  msg "${BOLD}Rama:${RESET} $(current_branch)"
  msg "${BOLD}Remoto:${RESET} $(git remote get-url origin 2>/dev/null || printf 'sin origin')"
  msg ""
  git status -sb
}

repo_menu() {
  local choice

  while true; do
    move_to_repo_root_if_needed
    BRANCH="$(current_branch)"
    msg ""
    msg "${BOLD}Asistente del libro${RESET}"
    msg "Ruta: $(pwd -P)"
    msg "Rama: $BRANCH"
    msg "------------------------------------"
    msg "  1) Descargar ultima version (pull)"
    msg "  2) Subir mis cambios (pull + commit + push)"
    msg "  3) Ver estado"
    msg "  4) Configurar nombre/email de Git"
    msg "  5) Configurar remoto GitHub"
    msg "  6) Cambiar o crear rama (avanzado)"
    msg "  0) Salir"
    printf "%b " "${YELLOW}Elige una opcion [2]${RESET}" >&2
    IFS= read -r choice || exit 1
    choice="${choice:-2}"

    case "$choice" in
      1)
        pull_latest
        pause_enter
        ;;
      2)
        commit_and_push
        pause_enter
        ;;
      3)
        show_repo_status
        pause_enter
        ;;
      4)
        configure_user
        pause_enter
        ;;
      5)
        ensure_remote || true
        pause_enter
        ;;
      6)
        warn "Para este equipo recomiendo trabajar en una sola rama: $DEFAULT_BRANCH."
        switch_or_create_branch
        pause_enter
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
  local choice

  while true; do
    msg ""
    msg "${BOLD}Asistente Git universal para el libro${RESET}"
    msg "------------------------------------"
    msg "  1) Clonar el proyecto del libro por primera vez"
    msg "  2) Preparar esta carpeta como proyecto Git (admin/primera creacion)"
    msg "  3) Configurar nombre/email de Git"
    msg "  4) Verificar o instalar Git"
    msg "  0) Salir"
    printf "%b " "${YELLOW}Elige una opcion [1]${RESET}" >&2
    IFS= read -r choice || exit 1
    choice="${choice:-1}"

    case "$choice" in
      1)
        clone_project
        ;;
      2)
        create_or_link_project_here
        ;;
      3)
        ensure_git
        configure_user
        pause_enter
        ;;
      4)
        ensure_git
        pause_enter
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

main() {
  if [ ! -t 0 ]; then
    die "Este asistente es interactivo. Ejecutalo desde una terminal o con doble clic en Windows."
  fi

  refresh_self_path
  ensure_git

  if inside_git_repo; then
    repo_bootstrap
    repo_menu
  else
    outside_repo_menu
  fi
}

main "$@"

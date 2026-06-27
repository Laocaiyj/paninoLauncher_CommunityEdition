#!/usr/bin/env bash
set -euo pipefail

HLS_HEAP_LIMIT="${HLS_HEAP_LIMIT:-4G}"
HLS_ALLOC_AREA="${HLS_ALLOC_AREA:-64m}"
HLS_JOBS="${HLS_JOBS:-2}"

find_first_executable() {
  local candidate
  for candidate in "$@"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

find_on_path() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi
  return 1
}

resolve_ghc_version() {
  if [[ -n "${HLS_GHC_VERSION:-}" ]]; then
    printf '%s\n' "$HLS_GHC_VERSION"
    return 0
  fi
  ghc --numeric-version
}

resolve_hls_binary() {
  if [[ -n "${HLS_BIN:-}" ]]; then
    printf '%s\n' "$HLS_BIN"
    return 0
  fi

  local ghc_version
  ghc_version="$(resolve_ghc_version)"

  local path_match=""
  path_match="$(find_on_path "haskell-language-server-${ghc_version}" || true)"
  if [[ -n "$path_match" ]]; then
    printf '%s\n' "$path_match"
    return 0
  fi

  shopt -s nullglob
  local hls_matches=(
    "$HOME/.ghcup/bin"/haskell-language-server-"$ghc_version"
    "$HOME/.ghcup/bin"/haskell-language-server-"$ghc_version"~*
    /opt/homebrew/bin/haskell-language-server-"$ghc_version"
    /opt/homebrew/bin/haskell-language-server-"$ghc_version"~*
    /usr/local/bin/haskell-language-server-"$ghc_version"
    /usr/local/bin/haskell-language-server-"$ghc_version"~*
  )
  shopt -u nullglob

  if find_first_executable "${hls_matches[@]}"; then
    return 0
  fi

  path_match="$(find_on_path "haskell-language-server-wrapper" || true)"
  if [[ -n "$path_match" ]]; then
    printf '%s\n' "$path_match"
    return 0
  fi

  shopt -s nullglob
  local wrapper_matches=(
    "$HOME/.ghcup/bin"/haskell-language-server-wrapper
    "$HOME/.ghcup/bin"/haskell-language-server-wrapper-*
    /opt/homebrew/bin/haskell-language-server-wrapper
    /opt/homebrew/bin/haskell-language-server-wrapper-*
    /usr/local/bin/haskell-language-server-wrapper
    /usr/local/bin/haskell-language-server-wrapper-*
  )
  shopt -u nullglob

  find_first_executable "${wrapper_matches[@]}"
}

hls_bin="$(resolve_hls_binary)"

case "$(basename "$hls_bin")" in
  haskell-language-server-wrapper*)
    printf 'warning: using haskell-language-server-wrapper fallback; set HLS_BIN to the versioned HLS binary if the heap cap is not inherited.\n' >&2
    ;;
esac

add_jobs=true
for arg in "$@"; do
  case "$arg" in
    -j|-j*|--help|-h|--numeric-version|--probe-tools|--project-ghc-version|--version)
      add_jobs=false
      ;;
  esac
done

if [[ "$add_jobs" == true && -n "$HLS_JOBS" ]]; then
  exec "$hls_bin" +RTS "-M${HLS_HEAP_LIMIT}" "-A${HLS_ALLOC_AREA}" -RTS -j "$HLS_JOBS" "$@"
fi

exec "$hls_bin" +RTS "-M${HLS_HEAP_LIMIT}" "-A${HLS_ALLOC_AREA}" -RTS "$@"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_BIN="${CORE_BIN:-$ROOT_DIR/core/dist-newstyle/build/aarch64-osx/ghc-9.6.7/panino-core-0.1.0.0/x/panino-core/build/panino-core/panino-core}"
VERSION="${VERSION:-1.20.1}"
REPEATS="${REPEATS:-3}"
CONCURRENCY="${CONCURRENCY:-16}"
BENCH_ROOT="${BENCH_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/panino-network-bench.XXXXXX")}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-text}"
REPORT_JSON=()

if [[ ! -x "$CORE_BIN" ]]; then
  echo "Core binary not found at $CORE_BIN"
  echo "Run ./scripts/build-core.sh first or set CORE_BIN."
  exit 1
fi

measure_run() {
  local start end status log peak_rss
  log="$(mktemp "${TMPDIR:-/tmp}/panino-time.XXXXXX")"
  start="$(date +%s%3N)"
  set +e
  /usr/bin/time -l "$@" >/dev/null 2>"$log"
  status="$?"
  set -e
  end="$(date +%s%3N)"
  if [[ "$status" -ne 0 ]]; then
    cat "$log" >&2
    rm -f "$log"
    return "$status"
  fi
  peak_rss="$(awk '/maximum resident set size/ { print $1; exit }' "$log")"
  rm -f "$log"
  echo "$((end - start)):${peak_rss:-0}"
}

percentile() {
  local index count
  count="$1"
  index="$2"
  shift 2
  printf '%s\n' "$@" | sort -n | awk -v idx="$index" 'NR == idx { print; exit }'
}

report() {
  local name count p50_index p95_index pair durations rss_values max_rss p50 p95
  name="$1"
  shift
  count="$#"
  durations=()
  rss_values=()
  for pair in "$@"; do
    durations+=("${pair%%:*}")
    rss_values+=("${pair##*:}")
  done
  p50_index=$(((count + 1) / 2))
  p95_index=$(((count * 95 + 99) / 100))
  max_rss="$(printf '%s\n' "${rss_values[@]}" | sort -n | tail -n 1)"
  p50="$(percentile "$count" "$p50_index" "${durations[@]}")"
  p95="$(percentile "$count" "$p95_index" "${durations[@]}")"
  if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    REPORT_JSON+=("{\"name\":\"$name\",\"runsMs\":$(json_array "${durations[@]}"),\"peakRssBytes\":$(json_array "${rss_values[@]}"),\"p50Ms\":$p50,\"p95Ms\":$p95,\"maxPeakRssBytes\":$max_rss}")
  else
    echo "$name"
    echo "  runs_ms: ${durations[*]}"
    echo "  peak_rss_bytes: ${rss_values[*]}"
    echo "  p50_ms: $p50"
    echo "  p95_ms: $p95"
    echo "  max_peak_rss_bytes: $max_rss"
  fi
}

json_array() {
  local IFS=,
  echo "[$*]"
}

run_repeated() {
  local name command_builder durations dir
  name="$1"
  command_builder="$2"
  shift 2
  durations=()
  for run in $(seq 1 "$REPEATS"); do
    dir="$BENCH_ROOT/${name// /-}-$run"
    mkdir -p "$dir"
    durations+=("$(measure_run "$command_builder" "$dir" "$@")")
  done
  report "$name" "${durations[@]}"
}

cold_install() {
  local dir="$1"
  "$CORE_BIN" install --version "$VERSION" --game-dir "$dir" --concurrency "$CONCURRENCY"
}

warm_install() {
  local dir="$1"
  "$CORE_BIN" install --version "$VERSION" --game-dir "$dir" --concurrency "$CONCURRENCY"
}

bench_warm_install() {
  local durations=() dir
  for run in $(seq 1 "$REPEATS"); do
    dir="$BENCH_ROOT/warm-install-$run"
    mkdir -p "$dir"
    "$CORE_BIN" install --version "$VERSION" --game-dir "$dir" --concurrency "$CONCURRENCY" >/dev/null
    durations+=("$(measure_run warm_install "$dir")")
  done
  report "warm install" "${durations[@]}"
}

api_post() {
  local path body
  path="$1"
  body="$2"
  curl -fsS \
    -H "Authorization: Bearer ${PANINO_CORE_TOKEN:?PANINO_CORE_TOKEN required}" \
    -H "Content-Type: application/json" \
    -X POST \
    --data "$body" \
    "${PANINO_CORE_URL:?PANINO_CORE_URL required}$path" >/dev/null
}

bench_api() {
  local durations=()
  for _ in $(seq 1 "$REPEATS"); do
    durations+=("$(measure_run api_post /api/v1/content/search '{"source":"modrinth","text":"sodium","projectTypes":["mod"],"gameVersion":"1.20.1","loaders":["fabric"],"sort":"downloads","offset":0,"limit":30}')")
  done
  report "api content search" "${durations[@]}"

  durations=()
  for _ in $(seq 1 "$REPEATS"); do
    durations+=("$(measure_run api_post /api/v1/content/project '{"source":"modrinth","projectId":"AANobbMI","query":{"source":"modrinth","text":"sodium","projectTypes":["mod"],"gameVersion":"1.20.1","loaders":["fabric"],"sort":"downloads","offset":0,"limit":30}}')")
  done
  report "api project detail" "${durations[@]}"

  durations=()
  for _ in $(seq 1 "$REPEATS"); do
    durations+=("$(measure_run api_post /api/v1/content/loaders '{"minecraftVersion":"1.20.1"}')")
  done
  report "api loader metadata" "${durations[@]}"
}

if [[ "$OUTPUT_FORMAT" != "json" ]]; then
  echo "benchmark root: $BENCH_ROOT"
  echo "version: $VERSION"
  echo "repeats: $REPEATS"
  echo "concurrency: $CONCURRENCY"
fi

run_repeated "cold install" cold_install
bench_warm_install

if [[ -n "${PANINO_CORE_URL:-}" && -n "${PANINO_CORE_TOKEN:-}" ]]; then
  bench_api
else
  if [[ "$OUTPUT_FORMAT" != "json" ]]; then
    echo "Skipping API benchmarks; set PANINO_CORE_URL and PANINO_CORE_TOKEN to include search/detail/loader metadata."
  fi
fi

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  joined="$(IFS=,; echo "${REPORT_JSON[*]}")"
  printf '{"benchmarkRoot":"%s","version":"%s","repeats":%s,"concurrency":%s,"results":[%s]}\n' \
    "$BENCH_ROOT" "$VERSION" "$REPEATS" "$CONCURRENCY" "$joined"
fi

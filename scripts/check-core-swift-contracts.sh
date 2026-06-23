#!/bin/sh
set -eu

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp_dir="${TMPDIR:-/tmp}/panino-contract-check.$$"
failed=0

mkdir -p "$tmp_dir"
trap 'rm -rf "$tmp_dir"' EXIT INT TERM

extract_haskell_fields() {
  file="$1"
  type_name="$2"
  mode="$3"

  PANINO_CONTRACT_TYPE="$type_name" PANINO_CONTRACT_MODE="$mode" perl -0ne '
    BEGIN {
      $type = $ENV{"PANINO_CONTRACT_TYPE"};
      $mode = $ENV{"PANINO_CONTRACT_MODE"};
    }

    $instance = $mode eq "fromjson" ? "FromJSON" : "ToJSON";
    if ($_ !~ /instance\s+$instance\s+\Q$type\E\s+where(.*?)(?=\n(?:instance|data|newtype|type)\s|\z)/s) {
      exit 2;
    }

    $block = $1;
    if ($mode eq "fromjson") {
      while ($block =~ /\.\:\??\s*"([^"]+)"/g) {
        print "$1\n";
      }
    } else {
      while ($block =~ /"([^"]+)"\s*\.=/g) {
        print "$1\n";
      }
    }
  ' "$file" | sort -u
}

extract_swift_fields() {
  file="$1"
  struct_name="$2"

  PANINO_CONTRACT_STRUCT="$struct_name" perl -ne '
    BEGIN {
      $struct = $ENV{"PANINO_CONTRACT_STRUCT"};
      $in_struct = 0;
      $depth = 0;
    }

    if (!$in_struct && /\bstruct\s+\Q$struct\E\b/) {
      $in_struct = 1;
      $depth += tr/{/{/;
      $depth -= tr/}/}/;
      next;
    }

    if ($in_struct) {
      if (/^\s*let\s+([A-Za-z_][A-Za-z0-9_]*)\s*:/) {
        print "$1\n";
      }
      $depth += tr/{/{/;
      $depth -= tr/}/}/;
      exit if $depth <= 0;
    }
  ' "$file" | sort -u
}

require_non_empty() {
  label="$1"
  file="$2"

  if [ ! -s "$file" ]; then
    echo "Contract extraction produced no fields for $label" >&2
    failed=1
  fi
}

check_pair() {
  label="$1"
  haskell_file="$repo_root/$2"
  haskell_type="$3"
  haskell_mode="$4"
  swift_file="$repo_root/$5"
  swift_struct="$6"
  haskell_fields="$tmp_dir/$label.haskell"
  swift_fields="$tmp_dir/$label.swift"

  if ! extract_haskell_fields "$haskell_file" "$haskell_type" "$haskell_mode" > "$haskell_fields"; then
    echo "Could not extract Haskell contract for $label ($haskell_type)" >&2
    failed=1
    return
  fi

  extract_swift_fields "$swift_file" "$swift_struct" > "$swift_fields"
  require_non_empty "$label Haskell $haskell_type" "$haskell_fields"
  require_non_empty "$label Swift $swift_struct" "$swift_fields"

  if [ -s "$haskell_fields" ] && [ -s "$swift_fields" ] && ! cmp -s "$haskell_fields" "$swift_fields"; then
    echo "Core/Swift contract drift: $label" >&2
    diff -u "$haskell_fields" "$swift_fields" || true
    failed=1
  fi
}

check_pair "PaninoLockfile" "core/src/Panino/Lockfile/Types.hs" "PaninoLockfile" "tojson" "macos/PaninoLauncher/PaninoLauncher/CoreLockfileModels.swift" "CorePaninoLockfile"
check_pair "LockfileSolveRequest" "core/src/Panino/Lockfile/Types.hs" "LockfileSolveRequest" "fromjson" "macos/PaninoLauncher/PaninoLauncher/CoreLockfileSolverModels.swift" "CoreLockfileSolveRequest"
check_pair "LockfileChange" "core/src/Panino/Lockfile/Types.hs" "LockfileChange" "tojson" "macos/PaninoLauncher/PaninoLauncher/CoreLockfileSolverModels.swift" "CoreLockfileChange"
check_pair "LockfileChangeset" "core/src/Panino/Lockfile/Types.hs" "LockfileChangeset" "fromjson" "macos/PaninoLauncher/PaninoLauncher/CoreLockfileSolverModels.swift" "CoreLockfileChangeset"
check_pair "LockfileExplainEntry" "core/src/Panino/Lockfile/Types.hs" "LockfileExplainEntry" "tojson" "macos/PaninoLauncher/PaninoLauncher/CoreLockfileSolverModels.swift" "CoreLockfileExplainEntry"
check_pair "LockfileExplain" "core/src/Panino/Lockfile/Types.hs" "LockfileExplain" "tojson" "macos/PaninoLauncher/PaninoLauncher/CoreLockfileSolverModels.swift" "CoreLockfileExplain"
check_pair "SolverResult" "core/src/Panino/Lockfile/Types.hs" "SolverResult" "tojson" "macos/PaninoLauncher/PaninoLauncher/CoreLockfileSolverModels.swift" "CoreLockfileSolverResult"
check_pair "LockfileApplyRequest" "core/src/Panino/Lockfile/Types.hs" "LockfileApplyRequest" "fromjson" "macos/PaninoLauncher/PaninoLauncher/CoreLockfileOperationModels.swift" "CoreLockfileApplyRequest"
check_pair "LockfileVerifyIssue" "core/src/Panino/Lockfile/Types.hs" "LockfileVerifyIssue" "tojson" "macos/PaninoLauncher/PaninoLauncher/CoreLockfileOperationModels.swift" "CoreLockfileVerifyIssue"
check_pair "LockfileVerifyResponse" "core/src/Panino/Lockfile/Types.hs" "LockfileVerifyResponse" "tojson" "macos/PaninoLauncher/PaninoLauncher/CoreLockfileOperationModels.swift" "CoreLockfileVerifyResponse"
check_pair "PackageCoordinate" "core/src/Panino/Lockfile/Types.hs" "PackageCoordinate" "tojson" "macos/PaninoLauncher/PaninoLauncher/CorePackageResolutionModels.swift" "CorePackageCoordinate"
check_pair "PackageConstraint" "core/src/Panino/Lockfile/Types.hs" "PackageConstraint" "tojson" "macos/PaninoLauncher/PaninoLauncher/CorePackageResolutionModels.swift" "CorePackageConstraint"
check_pair "ResolvedPackage" "core/src/Panino/Lockfile/Types.hs" "ResolvedPackage" "tojson" "macos/PaninoLauncher/PaninoLauncher/CorePackageResolutionModels.swift" "CoreResolvedPackage"
check_pair "SolverConflict" "core/src/Panino/Lockfile/Types.hs" "SolverConflict" "tojson" "macos/PaninoLauncher/PaninoLauncher/CorePackageResolutionModels.swift" "CoreSolverConflict"
check_pair "TaskProgress" "core/src/Panino/Api/Types/Tasks.hs" "TaskProgress" "tojson" "macos/PaninoLauncher/PaninoLauncher/TaskProgressModels.swift" "TaskProgress"
check_pair "TaskProgressHost" "core/src/Panino/Api/Types/Tasks.hs" "TaskProgressHost" "tojson" "macos/PaninoLauncher/PaninoLauncher/TaskProgressModels.swift" "TaskProgressHost"
check_pair "TaskProgressMultipart" "core/src/Panino/Api/Types/Tasks.hs" "TaskProgressMultipart" "tojson" "macos/PaninoLauncher/PaninoLauncher/TaskProgressModels.swift" "TaskProgressMultipart"

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "core-swift contract check ok"

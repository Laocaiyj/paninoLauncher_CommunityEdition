#!/bin/sh
set -eu

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
tmp_dir="${TMPDIR:-/tmp}/panino-contract-check.$$"
swift_core_models_dir="macos/PaninoLauncher/PaninoLauncher/Models/Core"
swift_lockfile_models_dir="$swift_core_models_dir/Lockfile"
swift_task_models_dir="$swift_core_models_dir/Tasks"
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

check_pair "PaninoLockfile" "core/src/Panino/Lockfile/Types/Document.hs" "PaninoLockfile" "tojson" "$swift_lockfile_models_dir/CoreLockfileModels.swift" "CorePaninoLockfile"
check_pair "LockfileSolveRequest" "core/src/Panino/Lockfile/Types/Solver.hs" "LockfileSolveRequest" "fromjson" "$swift_lockfile_models_dir/CoreLockfileSolverModels.swift" "CoreLockfileSolveRequest"
check_pair "LockfileChange" "core/src/Panino/Lockfile/Types/Solver.hs" "LockfileChange" "tojson" "$swift_lockfile_models_dir/CoreLockfileSolverModels.swift" "CoreLockfileChange"
check_pair "LockfileChangeset" "core/src/Panino/Lockfile/Types/Solver.hs" "LockfileChangeset" "fromjson" "$swift_lockfile_models_dir/CoreLockfileSolverModels.swift" "CoreLockfileChangeset"
check_pair "LockfileExplainEntry" "core/src/Panino/Lockfile/Types/Solver.hs" "LockfileExplainEntry" "tojson" "$swift_lockfile_models_dir/CoreLockfileSolverModels.swift" "CoreLockfileExplainEntry"
check_pair "LockfileExplain" "core/src/Panino/Lockfile/Types/Solver.hs" "LockfileExplain" "tojson" "$swift_lockfile_models_dir/CoreLockfileSolverModels.swift" "CoreLockfileExplain"
check_pair "SolverResult" "core/src/Panino/Lockfile/Types/Solver.hs" "SolverResult" "tojson" "$swift_lockfile_models_dir/CoreLockfileSolverModels.swift" "CoreLockfileSolverResult"
check_pair "LockfileApplyRequest" "core/src/Panino/Lockfile/Types/Solver.hs" "LockfileApplyRequest" "fromjson" "$swift_lockfile_models_dir/CoreLockfileOperationModels.swift" "CoreLockfileApplyRequest"
check_pair "LockfileVerifyIssue" "core/src/Panino/Lockfile/Types/Verify.hs" "LockfileVerifyIssue" "tojson" "$swift_lockfile_models_dir/CoreLockfileOperationModels.swift" "CoreLockfileVerifyIssue"
check_pair "LockfileVerifyResponse" "core/src/Panino/Lockfile/Types/Verify.hs" "LockfileVerifyResponse" "tojson" "$swift_lockfile_models_dir/CoreLockfileOperationModels.swift" "CoreLockfileVerifyResponse"
check_pair "PackageCoordinate" "core/src/Panino/Lockfile/Types/Package.hs" "PackageCoordinate" "tojson" "$swift_lockfile_models_dir/CorePackageResolutionModels.swift" "CorePackageCoordinate"
check_pair "PackageConstraint" "core/src/Panino/Lockfile/Types/Package.hs" "PackageConstraint" "tojson" "$swift_lockfile_models_dir/CorePackageResolutionModels.swift" "CorePackageConstraint"
check_pair "ResolvedPackage" "core/src/Panino/Lockfile/Types/Package.hs" "ResolvedPackage" "tojson" "$swift_lockfile_models_dir/CorePackageResolutionModels.swift" "CoreResolvedPackage"
check_pair "SolverConflict" "core/src/Panino/Lockfile/Types/Solver.hs" "SolverConflict" "tojson" "$swift_lockfile_models_dir/CorePackageResolutionModels.swift" "CoreSolverConflict"
check_pair "TaskProgress" "core/src/Panino/Api/Types/Tasks.hs" "TaskProgress" "tojson" "$swift_task_models_dir/TaskProgressModels.swift" "TaskProgress"
check_pair "TaskProgressHost" "core/src/Panino/Api/Types/Tasks.hs" "TaskProgressHost" "tojson" "$swift_task_models_dir/TaskProgressModels.swift" "TaskProgressHost"
check_pair "TaskProgressMultipart" "core/src/Panino/Api/Types/Tasks.hs" "TaskProgressMultipart" "tojson" "$swift_task_models_dir/TaskProgressModels.swift" "TaskProgressMultipart"

if [ "$failed" -ne 0 ]; then
  exit 1
fi

echo "core-swift contract check ok"

#!/usr/bin/env bash
set -eo pipefail

app_root="${HOME}/Library/Application Support/Panino Launcher"
minecraft_root="${app_root}/minecraft"
instances_root="${minecraft_root}/versions"
legacy_config_root="${app_root}/Game Configurations"
vanilla_root="${HOME}/Library/Application Support/minecraft"

mkdir -p "${instances_root}"

is_version_instance_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  [[ "$(basename "$dir")" == .* ]] && return 1
  [[ -n "$(version_id_for_dir "$dir")" ]]
}

version_id_for_dir() {
  local dir="$1"
  local name
  name="$(basename "$dir")"
  if [[ -f "$dir/$name.json" || -f "$dir/$name.jar" || -d "$dir/versions/$name" ]]; then
    echo "$name"
    return 0
  fi
  if [[ -d "$dir/versions" ]]; then
    local child
    for child in "$dir"/versions/*; do
      [[ -d "$child" ]] || continue
      local child_name
      child_name="$(basename "$child")"
      if [[ -f "$child/$child_name.json" || -f "$child/$child_name.jar" ]]; then
        echo "$child_name"
        return 0
      fi
    done
  fi
  local json
  for json in "$dir"/*.json; do
    [[ -f "$json" ]] || continue
    local id
    id="$(basename "$json" .json)"
    if [[ -f "$dir/$id.jar" ]]; then
      echo "$id"
      return 0
    fi
  done
}

version_dirs=()
while IFS= read -r -d '' dir; do
  if is_version_instance_dir "$dir"; then
    version_dirs+=("$dir")
  fi
done < <(find "${instances_root}" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)

for dir in "${version_dirs[@]}"; do
  version="$(version_id_for_dir "$dir")"
  mkdir -p \
    "$dir/versions/$version" \
    "$dir/libraries" \
    "$dir/assets" \
    "$dir/natives" \
    "$dir/saves" \
    "$dir/mods" \
    "$dir/resourcepacks" \
    "$dir/shaderpacks" \
    "$dir/logs" \
    "$dir/downloads"

  if [[ -f "$dir/$version.json" && ! -f "$dir/versions/$version/$version.json" ]]; then
    mv "$dir/$version.json" "$dir/versions/$version/$version.json"
  fi
  if [[ -f "$dir/$version.jar" && ! -f "$dir/versions/$version/$version.jar" ]]; then
    mv "$dir/$version.jar" "$dir/versions/$version/$version.jar"
  fi

  [[ -d "$minecraft_root/libraries" ]] && ditto "$minecraft_root/libraries" "$dir/libraries"
  [[ -d "$minecraft_root/assets" ]] && ditto "$minecraft_root/assets" "$dir/assets"
  [[ -d "$minecraft_root/natives/$version" ]] && ditto "$minecraft_root/natives/$version" "$dir/natives/$version"
done

if [[ "${#version_dirs[@]}" -eq 0 ]]; then
  echo "No local version directories found under ${instances_root}; nothing to organize."
  exit 0
fi

primary_dir=""
for dir in "${version_dirs[@]}"; do
  if [[ "$(basename "$dir")" == "1.20.1" ]]; then
    primary_dir="$dir"
    break
  fi
done
if [[ -z "$primary_dir" && "${#version_dirs[@]}" -gt 0 ]]; then
  primary_dir="${version_dirs[0]}"
fi

if [[ -n "$primary_dir" ]]; then
  for data_dir in saves mods resourcepacks shaderpacks logs downloads; do
    if [[ -d "$minecraft_root/$data_dir" ]]; then
      mkdir -p "$primary_dir/$data_dir"
      ditto "$minecraft_root/$data_dir" "$primary_dir/$data_dir"
    fi
  done
  for data_file in options.txt usercache.json; do
    if [[ -f "$minecraft_root/$data_file" && ! -f "$primary_dir/$data_file" ]]; then
      cp "$minecraft_root/$data_file" "$primary_dir/$data_file"
    fi
  done
fi

rm -rf \
  "$minecraft_root/saves" \
  "$minecraft_root/mods" \
  "$minecraft_root/resourcepacks" \
  "$minecraft_root/shaderpacks" \
  "$minecraft_root/logs" \
  "$minecraft_root/downloads" \
  "$minecraft_root/natives" \
  "$minecraft_root/assets" \
  "$minecraft_root/libraries"
rm -f "$minecraft_root/options.txt" "$minecraft_root/usercache.json"

rm -f "$legacy_config_root/.DS_Store" 2>/dev/null || true
rmdir "$legacy_config_root" 2>/dev/null || true

if [[ -d "$vanilla_root" ]]; then
  for data_dir in saves mods resourcepacks shaderpacks logs downloads; do
    rmdir "$vanilla_root/$data_dir" 2>/dev/null || true
  done
  rm -f "$vanilla_root/.DS_Store" 2>/dev/null || true
  rmdir "$vanilla_root" 2>/dev/null || true
fi

instances_file="${app_root}/instances.json"
{
  echo "["
  first=1
  for dir in "${version_dirs[@]}"; do
    version="$(version_id_for_dir "$dir")"
    dir_name="$(basename "$dir")"
    display_name="Minecraft $version"
    if [[ "$dir_name" != "$version" ]]; then
      display_name="$dir_name"
    fi
    status="notInstalled"
    if [[ -f "$dir/versions/$version/$version.json" && -f "$dir/versions/$version/$version.jar" ]]; then
      status="ready"
    fi
    id="$(uuidgen)"
    [[ "$first" -eq 1 ]] || echo ","
    first=0
    cat <<JSON
  {
    "coverPath" : "",
    "gameDirectory" : "$dir",
    "group" : "Local",
    "iconName" : "shippingbox.fill",
    "id" : "$id",
    "isFavorite" : false,
    "javaPath" : "",
    "jvmArguments" : "",
    "memoryMb" : 8192,
    "minecraftVersion" : "$version",
    "name" : "$display_name",
    "preLaunchBehavior" : "Install missing files",
    "status" : "$status"
  }
JSON
  done
  echo
  echo "]"
} > "${instances_file}"

echo "Organized ${#version_dirs[@]} local Minecraft instance(s) under ${instances_root}"

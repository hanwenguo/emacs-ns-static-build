#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  create-emacs-client-app.sh --emacs-app PATH --client-app PATH --version VERSION

Creates an AppleScript-based Emacs Client.app for the packaged Emacs.app.
EOF
}

emacs_app=""
client_app=""
version=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --emacs-app)
      emacs_app="$2"
      shift 2
      ;;
    --client-app)
      client_app="$2"
      shift 2
      ;;
    --version)
      version="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if [[ -z "$emacs_app" || -z "$client_app" || -z "$version" ]]; then
  usage >&2
  exit 64
fi

if [[ ! -d "$emacs_app" ]]; then
  echo "Emacs.app not found: $emacs_app" >&2
  exit 66
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
applescript_source="$script_dir/emacs-client.applescript"
client_plist="$client_app/Contents/Info.plist"
client_resources="$client_app/Contents/Resources"
emacs_plist="$emacs_app/Contents/Info.plist"
emacs_resources="$emacs_app/Contents/Resources"

plist_delete() {
  local plist="$1"
  local key="$2"

  /usr/libexec/PlistBuddy -c "Delete :$key" "$plist" >/dev/null 2>&1 || true
}

plist_add() {
  local plist="$1"
  local key="$2"
  local type="$3"
  local value="$4"

  plist_delete "$plist" "$key"
  /usr/libexec/PlistBuddy -c "Add :$key $type $value" "$plist"
}

rm -rf "$client_app"
osacompile -o "$client_app" "$applescript_source"

plist_add "$client_plist" "CFBundleIdentifier" "string" "org.gnu.EmacsClient"
plist_add "$client_plist" "CFBundleName" "string" "Emacs Client"
plist_add "$client_plist" "CFBundleDisplayName" "string" "Emacs Client"
plist_add "$client_plist" "CFBundleGetInfoString" "string" "Emacs Client $version"
plist_add "$client_plist" "CFBundleVersion" "string" "$version"
plist_add "$client_plist" "CFBundleShortVersionString" "string" "$version"
plist_add "$client_plist" "LSApplicationCategoryType" "string" "public.app-category.productivity"
plist_add "$client_plist" "NSHumanReadableCopyright" "string" "Copyright 1989-$(date +%Y) Free Software Foundation, Inc."

plist_delete "$client_plist" "CFBundleDocumentTypes"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes array" "$client_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0 dict" "$client_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Editor" "$client_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string Text Document" "$client_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$client_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string public.text" "$client_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:1 string public.plain-text" "$client_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:2 string public.source-code" "$client_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:3 string public.script" "$client_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:4 string public.shell-script" "$client_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:5 string public.data" "$client_plist"

plist_delete "$client_plist" "CFBundleURLTypes"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$client_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$client_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string Org Protocol" "$client_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$client_plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string org-protocol" "$client_plist"

if [[ -f "$emacs_resources/Emacs.icns" ]]; then
  cp "$emacs_resources/Emacs.icns" "$client_resources/applet.icns"
fi

rm -f "$client_resources/droplet.icns" "$client_resources/droplet.rsrc" "$client_resources/Assets.car"

if [[ -f "$emacs_resources/Assets.car" ]]; then
  cp "$emacs_resources/Assets.car" "$client_resources/Assets.car"
  icon_name="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconName" "$emacs_plist" 2>/dev/null || true)"
  if [[ -n "$icon_name" ]]; then
    plist_add "$client_plist" "CFBundleIconName" "string" "$icon_name"
  fi
fi

plist_add "$client_plist" "CFBundleIconFile" "string" "applet"
touch "$client_app"

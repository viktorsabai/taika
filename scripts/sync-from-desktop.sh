#!/usr/bin/env bash
# sync-from-desktop.sh
#
# Копирует локальные правки с ~/Desktop/taika → ~/Projects/taika
# (всё, что было изменено/добавлено после последнего коммита в GitHub).
#
# Использование (из корня Projects/taika):
#   chmod +x scripts/sync-from-desktop.sh
#   ./scripts/sync-from-desktop.sh
#
# Перед запуском:
#   1. Закрой Xcode (⌘Q)
#   2. На Desktop: ПКМ по папке taika → «Загрузить сейчас» (если есть облако)
#   3. Cursor открыт на ~/Projects/taika
#
# После скрипта:
#   1. Открой taika.xcodeproj в Xcode
#   2. Product → Clean Build Folder (⇧⌘K)
#   3. File → Packages → Reset Package Caches (если SPM ругается)
#   4. ⌘B

set -euo pipefail

DESKTOP="${DESKTOP_TAIKA:-$HOME/Desktop/taika}"
TARGET="${TARGET_TAIKA:-$HOME/Projects/taika}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}▸${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*" >&2; exit 1; }

# --- checks ---

[[ -d "$DESKTOP/.git" ]] || fail "Нет репозитория: $DESKTOP"
[[ -d "$TARGET/.git" ]]    || fail "Нет репозитория: $TARGET"

if pgrep -xq Xcode; then
  fail "Закрой Xcode (⌘Q) и запусти скрипт снова."
fi

# --- helpers ---

# Предикаты для `if is_corrupt_*`: return 0 = битый (пропускаем), return 1 = ок (копируем).
is_corrupt_swift() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  local size
  size=$(wc -c <"$f" | tr -d ' ')
  [[ "$size" -eq 0 ]] && return 0
  if ! head -c 1 "$f" | grep -q . 2>/dev/null; then
    return 0
  fi
  if grep -q '"use strict"' "$f" 2>/dev/null; then
    return 0
  fi
  if grep -q 'Object\.defineProperty(exports' "$f" 2>/dev/null; then
    return 0
  fi
  return 1
}

is_corrupt_json() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  local size
  size=$(wc -c <"$f" | tr -d ' ')
  [[ "$size" -eq 0 ]] && return 0
  # Успешный parse → не битый (1). Ошибка parse / нет python → битый (0).
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null; then
    return 1
  fi
  return 0
}

should_skip_path() {
  local rel="$1"
  case "$rel" in
    .git/*|.git) return 0 ;;
    .derivedData/*|.derivedData) return 0 ;;
    .swiftpm-cache/*|.swiftpm-cache) return 0 ;;
    */xcuserdata/*|*/xcuserdata) return 0 ;;
    */__pycache__/*|*/__pycache__) return 0 ;;
    *.bak) return 0 ;;
    .DS_Store) return 0 ;;
    .spm_resolve.log) return 0 ;;
  esac
  return 1
}

copy_file() {
  local rel="$1"
  local src="$DESKTOP/$rel"
  local dst="$TARGET/$rel"

  should_skip_path "$rel" && return 0
  [[ -e "$src" ]] || { warn "Нет на Desktop: $rel"; return 0; }

  case "$rel" in
    *.swift)
      if is_corrupt_swift "$src"; then
        warn "ПРОПУСК (битый Swift / iCloud): $rel"
        return 0
      fi
      ;;
    steps.json|lessons.json|taika/Resourses/*.json)
      if is_corrupt_json "$src"; then
        warn "ПРОПУСК (битый JSON): $rel"
        return 0
      fi
      ;;
    taika/Info.plist)
      # В Projects Info.plist лежит в корне — содержимое мержим отдельно
      if [[ -f "$src" ]]; then
        mkdir -p "$TARGET"
        cp "$src" "$TARGET/Info.plist"
        log "Info.plist → корень Projects (из $rel)"
      fi
      return 0
      ;;
  esac

  mkdir -p "$(dirname "$dst")"
  cp -p "$src" "$dst"
  log "OK $rel"
}

fix_xcode_info_plist() {
  local pbx="$TARGET/taika.xcodeproj/project.pbxproj"
  [[ -f "$pbx" ]] || return 0

  # Убрать Info.plist из синхронизированной папки, если вернулся
  [[ -f "$TARGET/taika/Info.plist" ]] && rm -f "$TARGET/taika/Info.plist"

  # Путь в build settings
  if grep -q 'INFOPLIST_FILE = taika/Info.plist' "$pbx"; then
    sed -i '' 's|INFOPLIST_FILE = taika/Info.plist|INFOPLIST_FILE = Info.plist|g' "$pbx"
    log "pbxproj: INFOPLIST_FILE → Info.plist"
  fi

  # Убрать Info.plist из membershipExceptions (если есть)
  sed -i '' '/membershipExceptions = (/,/);/{
    /Info\.plist,/d
  }' "$pbx" 2>/dev/null || true
}

# --- main ---

log "Источник: $DESKTOP"
log "Цель:     $TARGET"
echo

BACKUP="$TARGET/.sync-backup-$(date +%Y%m%d-%H%M%S)"
log "Бэкап цели → $BACKUP"
mkdir -p "$BACKUP"
rsync -a --exclude '.git' --exclude '.derivedData' --exclude '.swiftpm-cache' \
  "$TARGET/" "$BACKUP/" >/dev/null

cd "$DESKTOP"

USE_RSYNC_FALLBACK=0
FILES_FILE="$(mktemp)"

if ! git diff --name-only HEAD >"$FILES_FILE" 2>/dev/null; then
  warn "git на Desktop сломан (iCloud). Используем rsync/ditto вместо списка diff."
  USE_RSYNC_FALLBACK=1
  : >"$FILES_FILE"
else
  {
    cat "$FILES_FILE"
    git diff --name-only --cached HEAD 2>/dev/null || true
    git ls-files --others --exclude-standard 2>/dev/null || true
  } | sort -u >"${FILES_FILE}.all"
  mv "${FILES_FILE}.all" "$FILES_FILE"
fi

COPIED=0
SKIPPED=0

if [[ "$USE_RSYNC_FALLBACK" -eq 1 ]]; then
  log "ditto: taika/ (исходники приложения)"
  ditto "$DESKTOP/taika" "$TARGET/taika"
  COPIED=$((COPIED + 1))

  log "ditto: scripts/"
  [[ -d "$DESKTOP/scripts" ]] && ditto "$DESKTOP/scripts" "$TARGET/scripts"

  for j in lessons.json steps.json taikafm.json; do
    [[ -f "$DESKTOP/$j" ]] && cp -p "$DESKTOP/$j" "$TARGET/$j" && log "OK $j"
  done

  # Убрать Info.plist из синхронизированной папки
  rm -f "$TARGET/taika/Info.plist"

  # Починить известные битые файлы с Desktop (iCloud подменяет Swift на JS)
  while IFS= read -r bad; do
  [[ -n "$bad" ]] || continue
  rel="${bad#$TARGET/}"
  git -C "$TARGET" show "HEAD:$rel" >"$bad" 2>/dev/null && warn "Восстановлен из git: $rel" || warn "Битый файл, проверь вручную: $rel"
  done < <(rg -l '"use strict"|Object\.defineProperty\(exports' "$TARGET/taika" --glob '*.swift' 2>/dev/null || true)
else
  while IFS= read -r rel || [[ -n "$rel" ]]; do
    [[ -n "$rel" ]] || continue
    if should_skip_path "$rel"; then
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
    if copy_file "$rel"; then
      COPIED=$((COPIED + 1))
    fi
  done < "$FILES_FILE"
fi
rm -f "$FILES_FILE"

# pbxproj с Desktop (RevenueCat и т.д.) — отдельно, с фиксом Info.plist
if [[ -f "$DESKTOP/taika.xcodeproj/project.pbxproj" ]]; then
  cp -p "$DESKTOP/taika.xcodeproj/project.pbxproj" "$TARGET/taika.xcodeproj/project.pbxproj"
  log "OK taika.xcodeproj/project.pbxproj (с Desktop)"
  fix_xcode_info_plist
fi

# Содержимое Info.plist с Desktop в корень
if [[ -f "$DESKTOP/Info.plist" ]]; then
  cp -p "$DESKTOP/Info.plist" "$TARGET/Info.plist"
  log "OK Info.plist (корень Desktop)"
elif [[ -f "$DESKTOP/taika/Info.plist" ]]; then
  cp -p "$DESKTOP/taika/Info.plist" "$TARGET/Info.plist"
  log "OK Info.plist (из taika/)"
fi

xattr -cr "$TARGET" 2>/dev/null || true

echo
log "Готово. Скопировано файлов: ~$COPIED (пропущено служебных: ~$SKIPPED)"
warn "Пропущенные / битые файлы смотри выше (⚠)."
echo
echo "Дальше:"
echo "  1. open $TARGET/taika.xcodeproj"
echo "  2. Xcode: ⇧⌘K → ⌘B"
echo "  3. git -C $TARGET status"
echo
echo "Если сборка падает — откат бэкапа:"
echo "  rsync -a $BACKUP/ $TARGET/"

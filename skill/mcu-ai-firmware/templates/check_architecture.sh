#!/bin/sh
# Enforce the layer boundaries described in references/layered-architecture.md.
#
# Usage: ./check_architecture.sh [firmware-root]
#   firmware-root defaults to the current directory. It must contain the
#   layer directories (app service driver bsp common config mcu).
set -u

ROOT=${1:-.}
cd "$ROOT" || { echo "check_architecture: cannot enter $ROOT"; exit 1; }

for dir in app service driver bsp common config mcu; do
    [ -d "$dir" ] || { echo "check_architecture: missing layer directory '$dir' (run from the firmware root)"; exit 1; }
done

status=0

check_absent() {
    description=$1
    pattern=$2
    shift 2

    hits=$(grep -rnE "$pattern" --include='*.c' --include='*.h' "$@" 2>/dev/null)
    if [ -n "$hits" ]; then
        printf 'FAIL: %s\n' "$description"
        printf '%s\n' "$hits" | sed 's/^/  /'
        status=1
    else
        printf 'ok:   %s\n' "$description"
    fi
}

# service/ must not touch STM32 headers or HAL APIs directly.
check_absent "service/ has no direct HAL includes" \
    '^[[:space:]]*#[[:space:]]*include[[:space:]]*[<"](stm32|HAL_)' service
check_absent "service/ has no direct HAL API calls" \
    '\bHAL_[A-Za-z0-9_]+' service

# driver/ talks to hardware only through bsp/.
check_absent "driver/ has no direct HAL includes" \
    '^[[:space:]]*#[[:space:]]*include[[:space:]]*[<"](stm32|HAL_)' driver

# The lowest layers must stay dependency-free.
check_absent "bsp/, common/, config/ have no upper-layer dependencies" \
    '^[[:space:]]*#[[:space:]]*include[[:space:]]*[<"](app/|service/|driver/|mcu/|stm32|HAL_)' \
    bsp common config

# mcu/ must not depend on application or business logic.
check_absent "mcu/ has no app/service/driver dependencies" \
    '^[[:space:]]*#[[:space:]]*include[[:space:]]*[<"](app/|service/|driver/)' mcu

# bsp/ is an interface-only layer.
if find bsp -name '*.c' -print -quit | grep -q .; then
    echo "FAIL: bsp/ must contain headers only"
    find bsp -name '*.c' -print | sed 's/^/  /'
    status=1
else
    echo "ok:   bsp/ contains no .c files"
fi

# No heap allocation in portable/business code (static pools only).
check_absent "no dynamic allocation in app/service/driver/common" \
    '(^|[^A-Za-z0-9_])(malloc|calloc|realloc|free)[[:space:]]*\(' \
    app service driver common

printf '\n'
if [ "$status" -eq 0 ]; then
    echo "architecture: all checks passed"
else
    echo "architecture: violations found"
fi
exit "$status"

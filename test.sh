#! /bin/bash -e

BOARD="$1"
OVERLAY_DIR=""
OUT_DIR="$(dirname "$0")"/output
TMP=""

check_if_valid_board()
{
    local overlays="$(dirname "$0")"/xtensa-overlays

    for dir in "$overlays"/*/; do
        local dir_name="$(basename "$dir")"

        if [[ "$dir_name" == xtensa_* ]]; then
          local board_variant="${dir_name#xtensa_}"

          if [[ "$board_variant" == "$BOARD" ]]; then
            echo "Matched board $board_variant, proceeding..."
            OVERLAY_DIR="$dir"
            return
          fi
        fi
    done

    echo "Specified board is unknown, aborting..."
    exit 1
}

check_if_output_occupied()
{
    if [[ -d "$OUT_DIR" ]]; then
        if [ -z "$(ls -A "$OUT_DIR")" ]; then
            return
        else
            echo "output directory is not empty, please empty it first..."
            exit 1
        fi
    else
        echo "output directory doesn't exist, creating it..."
        mkdir "$OUT_DIR"
    fi
}

combine()
{
    local halpath="$(dirname "$0")"/esp-hal-components/components/xtensa/"$BOARD"/include/xtensa/config
    if ! [ -d "$halpath" ]; then
        echo "Path to HAL files (core-isa.h, tie.h, tie-asm.h) does not exist for the specified board, aborting!"
        exit 1
    fi

    # Note that the core-isa.h file from the HAL is the one named core.h for the kernel build
    local core="$halpath"/core-isa.h
    local tie="$halpath"/tie.h
    local tie_asm="$halpath"/tie-asm.h

    if [ ! -f "$core"  ] || [ ! -f "$tie" ] || [ ! -f "$tie_asm" ]; then
        echo "At least one of the essential HAL files (core-isa.h, tie.h, tie-asm.h) for the specified board, aborting!"
        exit 1
    fi

    echo "Gathering all files..."
    TMP=$(mktemp -d)
    trap "rm -rf "$TMP"" EXIT

    cp -r "$OVERLAY_DIR"/* "$TMP"

    local linux_target="$TMP"/linux/arch/xtensa/variants/"$BOARD"/include/variant
    mkdir -p "$linux_target"

    cp "$core" "$linux_target"/core.h
    cp "$tie" "$linux_target"/tie.h
    cp "$tie_asm" "$linux_target"/tie-asm.h

    echo "Tar all files together into ./output/xtensa-"$BOARD"-overlay.tar.gz..."
    tar -czf "$OUT_DIR"/xtensa-"$BOARD"-overlay.tar.gz -C "$TMP" .
    echo "Finished successfully!"
    exit 0
}


check_if_valid_board
check_if_output_occupied
combine

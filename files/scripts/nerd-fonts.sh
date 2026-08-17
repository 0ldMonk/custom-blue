#!/usr/bin/env bash
set -oue pipefail

# Replaces the `fonts` module, which has no variant filter: all 96 TTFs, 229 MB.
# The .tar.xz is only 6 MB because xz dedups across the near-identical files;
# OCI layer gzip (32 KB window) can't, so the image pays the full 229 MB.

FONT=JetBrainsMono
DEST="/usr/share/fonts/nerd-fonts/${FONT}"

# Mono (single-width icons, terminals) + normal (double-width, editors/UI).
KEEP='^JetBrainsMonoNerdFont(Mono)?-(Regular|Bold|Italic|BoldItalic)\.ttf$'

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

curl -fLsS --retry 5 \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${FONT}.tar.xz" \
    -o "${tmp}/${FONT}.tar.xz"

tar -xf "${tmp}/${FONT}.tar.xz" -C "${tmp}"

mkdir -p "${DEST}"
find "${tmp}" -maxdepth 1 -name '*.ttf' -printf '%f\n' | grep -E "${KEEP}" |
    while read -r f; do install -m 0644 "${tmp}/${f}" "${DEST}/${f}"; done
install -m 0644 "${tmp}/OFL.txt" "${DEST}/OFL.txt"

# An upstream rename would otherwise ship an empty font dir.
n="$(find "${DEST}" -name '*.ttf' | wc -l)"
[ "${n}" -eq 8 ] || { echo "expected 8 TTFs, installed ${n}" >&2; exit 1; }

fc-cache --system-only --really-force "${DEST}"

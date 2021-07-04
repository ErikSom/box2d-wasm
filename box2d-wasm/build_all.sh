#!/usr/bin/env bash
set -eo pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This script just does what the README says, except with some extra validation and interactivity.
# If you're more interested in going through step-by-step, and avoiding rebuilds of files you've 
# already built: you'll probably prefer to cherry-pick lines from the README.

Red='\033[0;31m'
Purple='\033[0;35m'
NC='\033[0m' # No Color

if ! [[ "$PWD" -ef "$DIR" ]]; then
  >&2 echo -e "${Red}This script is meant to be run from <repository_root>/box2d-wasm${NC}"
  exit 1
fi

mkdir -p "build/common"
pushd "build/common"

# use Box2D.idl to create ./box2d_glue.{js,cpp} for invoking functionality from libbox2d
set -x
"$DIR/build_idl_bindings.sh"
{ set +x; } 2>&-
>&2 echo

set -x
"$DIR/build_typings.sh"
{ set +x; } 2>&-

popd

FLAVOUR_NAMES=(vanilla SIMD)
FLAVOUR_DIRNAMES=(standard simd)
SIMD_ENABLED=('' 1)

for i in {0..1}
do
  FLAVOUR_NAME="${FLAVOUR_NAMES["$i"]}"
  FLAVOUR_DIRNAME="${FLAVOUR_DIRNAMES["$i"]}"

  # use JUST_SIMD=1 to save time when prototyping
  if [[ "$JUST_SIMD" = "1" && "$FLAVOUR_NAME" != "simd" ]]; then
    >&2 echo -e "\nSkipping '$FLAVOUR_NAME' flavour build because JUST_SIMD is set."
    continue
  fi


  FLAVOUR_DIR="build/flavour/$FLAVOUR_DIRNAME"
  >&2 echo -e "\nMaking '$FLAVOUR_NAME' flavour in ./$FLAVOUR_DIR directory"
  mkdir -p "$FLAVOUR_DIR"
  pushd "$FLAVOUR_DIR"

  set -x
  SIMD_ENABLED="$SIMD_ENABLED" "$DIR/build_makefile.sh"
  { set +x; } 2>&-

  >&2 echo -e '\nCompiling C++ to LLVM IR (creates ./build/bin/libbox2d.a archive)'
  set -x
  emmake make
  { set +x; } 2>&-
  >&2 echo

  # generate Box2D_*.{wasm,js} from glue code + libbox2d.a
  set -x
  SIMD_ENABLED="$SIMD_ENABLED" "$DIR/build_wasm.sh"
  { set +x; } 2>&-

  >&2 echo -e "Completed '$FLAVOUR_NAME' flavour"

  popd
done    
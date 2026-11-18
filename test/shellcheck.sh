#!/usr/bin/env bash

# Runs shellcheck (0.10 or later) on every shell script in the repository.
#
# Scripts that start with "#!/usr/bin/env ash" run in the busybox image, so they
# are checked as busybox scripts. SC3015 is excluded for them: busybox ash 1.36
# and later supports [[ =~ ]]. Only errors fail, because some existing scripts
# still have warnings.
#
# Usage: test/shellcheck.sh

set -euo pipefail

cd "$(dirname "$0")/.."

ash_scripts=()
other_scripts=()
while IFS= read -r file; do
  if [[ "$(head -n 1 "${file}")" == "#!/usr/bin/env ash" ]]; then
    ash_scripts+=("${file}")
  else
    other_scripts+=("${file}")
  fi
done < <(git ls-files --cached --others --exclude-standard '*.sh')

shellcheck --severity=error --shell=busybox --exclude=SC3015 "${ash_scripts[@]}"
shellcheck --severity=error "${other_scripts[@]}"
echo "shellcheck: no errors in ${#ash_scripts[@]} busybox and ${#other_scripts[@]} other scripts"

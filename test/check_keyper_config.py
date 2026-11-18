#!/usr/bin/env python3
"""Check a keyper.toml written by _container_scripts/configure_keyper.sh.

Usage:
    check_keyper_config.py KEYPER_TOML --metrics-enabled true|false
        [--metrics-port PORT] [--assets-env VARIABLES_ENV]

Fails unless the file is valid TOML, [Metrics] Enabled and Port are the values
the configure step was given, and [P2P.FloodSubDiscovery] Enabled is true
whatever METRICS_ENABLED is (#67). With --assets-env (the assets image's
variables.env), the DKG fields must also have the values from that file.
"""

import argparse
import sys
import tomllib

FLOODSUB_DISCOVERY_ENABLED = True

# keyper.toml field: the variable in the assets image's variables.env that sets it
DKG_FIELDS = {
    "Shuttermint.DKGPhaseLength": "_ASSETS_DKG_PHASE_LENGTH",
    "Shuttermint.DKGStartBlockDelta": "_ASSETS_DKG_START_BLOCK_DELTA",
}


def get(config, path):
    value = config
    for key in path.split("."):
        if not isinstance(value, dict) or key not in value:
            return None
        value = value[key]
    return value


def read_env(path):
    values = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                value = value[1:-1]
            values[key.strip()] = value
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("keyper_toml")
    parser.add_argument("--metrics-enabled", required=True, choices=["true", "false"])
    # docker-compose.yml sets SHUTTER_METRICS_PORT=9200
    parser.add_argument("--metrics-port", type=int, default=9200)
    parser.add_argument("--assets-env")
    args = parser.parse_args()

    try:
        with open(args.keyper_toml, "rb") as f:
            config = tomllib.load(f)
    except tomllib.TOMLDecodeError as e:
        print(f"FAIL {args.keyper_toml} is not valid TOML: {e}")
        sys.exit(1)

    expected = {
        "Metrics.Enabled": args.metrics_enabled == "true",
        "Metrics.Port": args.metrics_port,
        "P2P.FloodSubDiscovery.Enabled": FLOODSUB_DISCOVERY_ENABLED,
    }
    failed = False
    if args.assets_env:
        assets = read_env(args.assets_env)
        for path, variable in DKG_FIELDS.items():
            if not assets.get(variable, "").isdigit():
                print(f"FAIL {variable} in {args.assets_env} is {assets.get(variable)!r}")
                failed = True
                continue
            expected[path] = int(assets[variable])

    for path, want in expected.items():
        got = get(config, path)
        ok = type(got) is type(want) and got == want
        print(f"{'ok  ' if ok else 'FAIL'} {path} = {got!r} (expected {want!r})")
        failed = failed or not ok
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()

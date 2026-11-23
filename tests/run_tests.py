#!/usr/bin/env python3
"""Run SimpleSkillWatch's Lua tests against the mock WoW API.

Each tests/test_*.lua file runs in a fresh Lua 5.1 runtime (WoW uses 5.1),
so tests can't leak state into each other.

Needs:  pip install lupa
Usage:  python tests/run_tests.py            (all tests)
        python tests/run_tests.py lock       (only files whose name contains "lock")
"""
import pathlib
import sys

try:
    import lupa.lua51 as lua51
except ImportError:
    sys.exit("lupa is missing: pip install lupa")

TESTS = pathlib.Path(__file__).resolve().parent
ADDON = TESTS.parent


def run(path):
    rt = lua51.LuaRuntime(unpack_returned_tuples=True)
    g = rt.globals()
    g.TESTS_DIR = str(TESTS)
    g.ADDON_DIR = str(ADDON)
    runner = rt.eval("function(p) local f = assert(loadfile(p)); f() end")
    runner(str(path))


def main():
    pattern = sys.argv[1] if len(sys.argv) > 1 else ""
    files = sorted(p for p in TESTS.glob("test_*.lua") if pattern in p.name)
    failed = 0
    for path in files:
        try:
            run(path)
            print(f"PASS  {path.name}")
        except Exception as e:  # lupa raises LuaError with the Lua message
            failed += 1
            print(f"FAIL  {path.name}\n      {e}")
    print(f"\n{len(files) - failed}/{len(files)} passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Offline checks for the Steam VDF editor used by the Unix setup helper."""
import importlib.util
from pathlib import Path
import tempfile

MODULE_PATH = Path(__file__).with_name("setup-unix.py")
spec = importlib.util.spec_from_file_location("knoxbridge_unix_setup", MODULE_PATH)
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


def check(condition, message):
    if not condition: raise AssertionError(message)


fixture = '''"UserLocalConfigStore" {
    "Software" { "Valve" { "Steam" { "language" "english" } } }
    "apps" {
        "999" { "LaunchOptions" "unrelated" }
        "108600" { "LaunchOptions" "-windowed" }
    }
}
'''
with tempfile.TemporaryDirectory(prefix="knoxbridge-vdf-") as temp:
    config = Path(temp) / "localconfig.vdf"
    config.write_text(fixture, encoding="utf-8")
    argument = "-javaagent:/home/test/.knoxbridge/knoxbridge-agent.jar"
    installed = setup.set_launch_options(config, new_value=argument)
    check('"LaunchOptions" "-windowed ' + argument + ' --"' in installed, "Install must preserve prior launch options")
    check('"999" { "LaunchOptions" "unrelated" }' in installed, "Other games must stay untouched")
    config.write_text(installed, encoding="utf-8")
    repeated = setup.set_launch_options(config, new_value=argument)
    check(repeated.count("-javaagent:") == 1, "Repeat install must not duplicate the agent")
    config.write_text(repeated, encoding="utf-8")
    user_edited = repeated.replace('-windowed ', '-windowed -Duser=keep ')
    config.write_text(user_edited, encoding="utf-8")
    edited = setup.set_launch_options(config, new_value=None, remove_value=argument, remove_added_delimiter=True)
    check('"LaunchOptions" "-windowed -Duser=keep"' in edited, "Uninstall must preserve later user edits")
    check('"999" { "LaunchOptions" "unrelated" }' in edited, "Uninstall must preserve unrelated game config")

before_delimiter = '''"UserLocalConfigStore" { "apps" { "108600" { "LaunchOptions" "-windowed -- %command%" } } }'''
with tempfile.TemporaryDirectory(prefix="knoxbridge-vdf-delimiter-") as temp:
    config = Path(temp) / "localconfig.vdf"
    config.write_text(before_delimiter, encoding="utf-8")
    quoted_agent = '-javaagent:"/home/test user/.knoxbridge/agent.jar"'
    installed = setup.set_launch_options(config, new_value=quoted_agent)
    expected_option = '"LaunchOptions" ' + __import__("json").dumps("-windowed " + quoted_agent + " -- %command%")
    check(expected_option in installed, "Installer must preserve an existing Steam delimiter and quote paths with spaces")
    removed = setup.set_launch_options(config, remove_value=quoted_agent)
    check('"LaunchOptions" "-windowed -- %command%"' in removed, "Uninstall must preserve pre-existing delimiter and command")

missing_option = '''"UserLocalConfigStore" { "apps" { "108600" { "LaunchOptions" "" } } }'''
with tempfile.TemporaryDirectory(prefix="knoxbridge-vdf-missing-") as temp:
    config = Path(temp) / "localconfig.vdf"
    config.write_text(missing_option, encoding="utf-8")
    installed = setup.set_launch_options(config, new_value="-javaagent:/home/test/agent.jar --")
    check("-javaagent:/home/test/agent.jar --" in installed, "Empty launch option must be populated")

print("KnoxBridge Unix setup verification PASS checks=7")

with tempfile.TemporaryDirectory(prefix="knoxbridge-trust-") as temp:
    setup.TRUST = Path(temp) / "trust.properties"
    one_hash = "a" * 64
    other_hash = "b" * 64
    setup.save_trust_decision(one_hash, "allow")
    setup.save_trust_decision(other_hash, "deny")
    setup.save_trust_decision(one_hash, "deny")
    trust_text = setup.TRUST.read_text(encoding="ascii")
    check(trust_text.count(one_hash + "=") == 1, "Changing a decision must replace the existing exact-hash entry")
    check(one_hash + "=deny" in trust_text, "An exact module hash must be blockable")
    check(other_hash + "=deny" in trust_text, "Separate module denial must be preserved")
    rejected = False
    try: setup.save_trust_decision("not-a-hash", "allow")
    except ValueError: rejected = True
    check(rejected, "Trust decision must reject malformed hashes")

print("KnoxBridge trust decision verification PASS checks=4")

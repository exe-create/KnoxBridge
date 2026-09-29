#!/usr/bin/env python3
"""KnoxBridge's independently authored Linux/macOS setup helper."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys

APP_ID = "108600"
VERSION = "0.1.0-alpha9"
BASE = Path.home() / ".knoxbridge"
STATE = BASE / "install-state.json"
BACKUP = BASE / "steam-localconfig.vdf.original"
AGENT = BASE / "knoxbridge-agent.jar"
TOKEN_RE = re.compile(r'"(?:\\.|[^"\\])*"|[{}]|//[^\r\n]*')


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def token_value(token):
    return json.loads(token) if token.startswith('"') else token


def vdf_tokens(text):
    return [(m.group(0), m.start(), m.end()) for m in TOKEN_RE.finditer(text)
            if not m.group(0).startswith("//")]


def vdf_pairs(tokens, opening, closing):
    pairs = {}
    i = opening + 1
    while i < closing:
        key = token_value(tokens[i][0])
        value_index = i + 1
        if value_index >= closing:
            raise ValueError("Steam config ended inside a key/value pair")
        value = tokens[value_index][0]
        if value == "{":
            depth = 1
            j = value_index + 1
            while j < closing and depth:
                if tokens[j][0] == "{": depth += 1
                elif tokens[j][0] == "}": depth -= 1
                j += 1
            if depth:
                raise ValueError("Steam config has an unclosed VDF section")
            pairs[key] = ("block", value_index, j - 1)
            i = j
        else:
            pairs[key] = ("value", value_index, value_index)
            i = value_index + 1
    return pairs


def app_block(text):
    tokens = vdf_tokens(text)
    stack = []
    matching = {}
    for i, (raw, _, _) in enumerate(tokens):
        if raw == "{": stack.append(i)
        elif raw == "}":
            if not stack: raise ValueError("Steam config has an unmatched closing brace")
            opening = stack.pop()
            matching[opening] = i
    if stack: raise ValueError("Steam config has an unclosed section")
    if len(tokens) < 2 or tokens[1][0] != "{": raise ValueError("Unexpected Steam config format")
    root = vdf_pairs(tokens, 1, matching[1])
    apps = root.get("apps")
    if not apps or apps[0] != "block": raise ValueError("Steam config has no apps section")
    app = vdf_pairs(tokens, apps[1], apps[2]).get(APP_ID)
    if not app or app[0] != "block": raise ValueError("Steam config does not contain Project Zomboid settings")
    return tokens, app, matching


def set_launch_options(path, new_value=None, remove_value=None, remove_added_delimiter=False):
    text = path.read_text(encoding="utf-8")
    tokens, app, _ = app_block(text)
    app_pairs = vdf_pairs(tokens, app[1], app[2])
    launch = app_pairs.get("LaunchOptions")
    if launch:
        if launch[0] != "value": raise ValueError("Steam LaunchOptions entry is not a string")
        token_i = launch[1]
        old_value = token_value(tokens[token_i][0])
        start, end = tokens[token_i][1], tokens[token_i][2]
        if new_value is not None:
            if new_value not in old_value:
                if "--" in old_value:
                    before, after = old_value.split("--", 1)
                    merged = f"{before.rstrip()} {new_value} --{after}"
                elif old_value.strip():
                    merged = f"{old_value.rstrip()} {new_value} --"
                else:
                    merged = f"{new_value} --"
            else:
                merged = old_value
            text = text[:start] + json.dumps(merged, ensure_ascii=False) + text[end:]
        else:
            merged = old_value.replace(remove_value, "").strip()
            merged = re.sub(r"[ \t]{2,}", " ", merged)
            if remove_added_delimiter and merged.endswith("--"):
                merged = merged[:-2].rstrip()
            text = text[:start] + json.dumps(merged, ensure_ascii=False) + text[end:]
    elif new_value is not None:
        close_pos = tokens[app[2]][1]
        indent = "\t\t\t\t"
        text = text[:close_pos] + f'\n{indent}"LaunchOptions" {json.dumps(new_value + " --")}\n\t\t\t' + text[close_pos:]
    else:
        return text
    return text


def find_steam_configs():
    roots = []
    if sys.platform == "darwin":
        roots.append(Path.home() / "Library/Application Support/Steam")
    else:
        roots.extend([Path.home() / ".local/share/Steam", Path.home() / ".steam/steam"])
    found = []
    for root in roots:
        users = root / "userdata"
        if users.is_dir():
            found.extend(p / "config/localconfig.vdf" for p in users.iterdir()
                         if p.is_dir() and (p / "config/localconfig.vdf").is_file())
    unique = []
    for path in found:
        resolved = path.resolve()
        if resolved not in unique:
            unique.append(resolved)
    return unique


def choose_config():
    candidates = find_steam_configs()
    matching = []
    for path in candidates:
        try:
            app_block(path.read_text(encoding="utf-8"))
            matching.append(path)
        except ValueError:
            continue
    if not matching:
        entered = input("Steam localconfig.vdf path (close Steam first): ").strip().strip('"')
        path = Path(entered).expanduser()
        app_block(path.read_text(encoding="utf-8"))
        return path
    if len(matching) == 1: return matching[0]
    print("Select your Steam account config:")
    for index, path in enumerate(matching, 1): print(f"{index}. {path}")
    choice = input("Choose number: ").strip()
    return matching[int(choice) - 1]


def install():
    if sys.platform not in ("linux", "darwin"):
        raise RuntimeError("Use KnoxBridge Setup.cmd on Windows.")
    package = Path(__file__).resolve().parent.parent
    packaged_agent = package / f"knoxbridge-agent-{VERSION}.jar"
    if not packaged_agent.is_file():
        raise RuntimeError(f"Agent JAR missing next to the setup download: {packaged_agent}")
    config = choose_config()
    current = config.read_text(encoding="utf-8")
    tokens, app, _ = app_block(current)
    launch = vdf_pairs(tokens, app[1], app[2]).get("LaunchOptions")
    launch_text = token_value(tokens[launch[1]][0]) if launch and launch[0] == "value" else ""
    prior_state = json.loads(STATE.read_text(encoding="utf-8")) if STATE.is_file() else None
    owned_argument = prior_state.get("argument", "") if prior_state else ""
    competing = launch_text.replace(owned_argument, "") if owned_argument else launch_text
    if re.search(r"(?i)(-javaagent:|-agentpath:|-agentlib:)", competing):
        raise RuntimeError("A Java instrumentation runtime already appears in this Steam config. Remove/disable it first; KnoxBridge will not stack agents.")
    BASE.mkdir(parents=True, exist_ok=True)
    if prior_state:
        if prior_state.get("config") != str(config):
            raise RuntimeError("Existing KnoxBridge install belongs to a different Steam config; uninstall it first.")
    elif BACKUP.exists() or AGENT.exists():
        raise RuntimeError("Unmanaged KnoxBridge backup or agent already exists; refusing to overwrite it.")
    else:
        shutil.copy2(config, BACKUP)
    shutil.copy2(packaged_agent, AGENT)
    argument = f'-javaagent:"{AGENT}"'
    delimiter_added = prior_state.get("delimiterAdded", "--" not in launch_text) if prior_state else "--" not in launch_text
    updated = set_launch_options(config, new_value=argument)
    config.write_text(updated, encoding="utf-8")
    state = {"owner": "KnoxBridge Runtime", "version": VERSION, "config": str(config),
             "argument": argument, "delimiterAdded": delimiter_added, "agentSha256": sha(AGENT),
             "installedConfigSha256": hashlib.sha256(updated.encode("utf-8")).hexdigest()}
    STATE.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print(f"Installed KnoxBridge for {sys.platform}; agent SHA-256: {state['agentSha256']}")
    print("Close and reopen Steam, then start Project Zomboid normally. No other Java agent may be enabled.")


def uninstall():
    if not STATE.is_file() or not BACKUP.is_file():
        raise RuntimeError("KnoxBridge-owned install state or Steam config backup is missing; refusing uninstall.")
    state = json.loads(STATE.read_text(encoding="utf-8"))
    config = Path(state["config"])
    current_hash = sha(config)
    if current_hash == state["installedConfigSha256"]:
        shutil.copy2(BACKUP, config)
        result = "original Steam config restored"
    else:
        updated = set_launch_options(config, remove_value=state["argument"], remove_added_delimiter=state.get("delimiterAdded", False))
        config.write_text(updated, encoding="utf-8")
        result = "KnoxBridge launch option removed; other current edits preserved"
    if AGENT.exists() and sha(AGENT) == state["agentSha256"]: AGENT.unlink()
    STATE.unlink()
    BACKUP.unlink()
    print(f"Uninstalled KnoxBridge: {result}.")


def menu():
    while True:
        print("\nKnoxBridge Setup")
        print("1. Install or update KnoxBridge Runtime")
        print("2. Uninstall KnoxBridge")
        print("3. Exit")
        choice = input("Choose 1-3: ").strip()
        try:
            if choice == "1":
                if input("Close Steam before setup? (Y/n): ").strip().lower() not in ("", "y", "yes"):
                    continue
                install()
            elif choice == "2":
                if input("Remove KnoxBridge startup setup? (Y/n): ").strip().lower() in ("", "y", "yes"):
                    uninstall()
            elif choice == "3": return
            else: print("Choose 1, 2, or 3.")
        except (OSError, ValueError, KeyError, IndexError, RuntimeError) as error:
            print(f"Setup stopped safely: {error}")


if __name__ == "__main__":
    menu()

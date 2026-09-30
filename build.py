#!/usr/bin/env python3
"""
--> ["Kite : build"]

Kite is authored in the `const` flavor. Roblox speaks Luau, so this script
does three things:

  1. lowers `const` -> `local`            build/Luau/
  2. emits a Studio ready model          Releases/Kite.rbxmx
  3. prints the package map

usage:
    python3 build.py              # build everything
    python3 build.py --luau       # only the plain Luau tree
    python3 build.py --model      # only the rbxmx
    python3 build.py --check      # report files that still use `local`
"""

import argparse
import os
import re
import sys
import xml.sax.saxutils as saxutils

ROOT = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(ROOT, "Kite")
BUILD = os.path.join(ROOT, "build", "Luau")
RELEASES = os.path.join(ROOT, "Releases")

VERSION = "0.1.0"
AUTHOR = "Makel/Savi (@sacredludt or @.makel)"
GITHUB = "github.com/zqouva"

CONST_LINE = re.compile(r"(?m)^([ \t]*)const(\s)")
CONST_START = re.compile(r"\Aconst(\s)")


def log(message):
    print(f"--> [KITE]: {message}")


REQUIRE = re.compile(r"require\(script((?:\.[A-Za-z_][A-Za-z0-9_]*)+)\)")


def lower(text):
    """const -> local, and only that. Nothing else about the file moves."""
    out = CONST_LINE.sub(r"\1local\2", text)
    out = CONST_START.sub(r"local\1", out)
    return out


def rewrite_requires(text, relative):
    """
    Roblox requires Instances (`require(script.Parent.Util)`). The Luau CLI,
    which is what the test runner uses, requires paths.

    The model keeps the Roblox form. Only the lowered tree, which exists for
    the CLI and for reading, gets the path form.
    """
    parts = relative.split(os.sep)
    here = parts[:-1]

    def convert(match):
        target = list(here)

        for name in match.group(1).split(".")[1:]:
            if name == "Parent":
                if target:
                    target.pop()
            else:
                target.append(name)

        index = 0
        while index < len(here) and index < len(target) and here[index] == target[index]:
            index += 1

        rest = target[index:]
        return 'require("./%s")' % "/".join(rest) if rest else 'require(".")'

    return REQUIRE.sub(convert, text)


def read(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(content)


def escape(text):
    return saxutils.escape(text)


def script_xml(name, source, class_name="ModuleScript"):
    return f"""\t<Item class="{class_name}" referent="RBX{os.urandom(8).hex()}">
\t\t<Properties>
\t\t\t<BinaryString name="AttributesSerialize"></BinaryString>
\t\t\t<SecurityCapabilities name="Capabilities">0</SecurityCapabilities>
\t\t\t<bool name="DefinesCapabilities">false</bool>
\t\t\t<string name="Name">{escape(name)}</string>
\t\t\t<ProtectedString name="Source">{escape(source)}</ProtectedString>
\t\t\t<int64 name="SourceAssetId">-1</int64>
\t\t\t<BinaryString name="Tags"></BinaryString>
\t\t</Properties>
\t</Item>"""


def folder_xml(name, children):
    body = "\n".join("\t" + line for line in children.splitlines())
    return f"""\t<Item class="Folder" referent="RBX{os.urandom(8).hex()}">
\t\t<Properties>
\t\t\t<BinaryString name="AttributesSerialize"></BinaryString>
\t\t\t<SecurityCapabilities name="Capabilities">0</SecurityCapabilities>
\t\t\t<bool name="DefinesCapabilities">false</bool>
\t\t\t<string name="Name">{escape(name)}</string>
\t\t\t<int64 name="SourceAssetId">-1</int64>
\t\t\t<BinaryString name="Tags"></BinaryString>
\t\t</Properties>
{body}
\t</Item>"""


def class_of(filename):
    if filename.endswith(".server.luau"):
        return filename[: -len(".server.luau")], "Script"
    if filename.endswith(".client.luau"):
        return filename[: -len(".client.luau")], "LocalScript"
    if filename.endswith(".luau") or filename.endswith(".lua"):
        stem = filename.rsplit(".", 1)[0]
        return stem, "ModuleScript"
    return filename, "ModuleScript"


def build_luau():
    """Plain Luau tree, for Studio, for the model, and for the test runner."""
    count = 0

    for current, _dirs, files in os.walk(SOURCE):
        for name in sorted(files):
            if not (name.endswith(".luau") or name.endswith(".lua")):
                continue

            source_path = os.path.join(current, name)
            relative = os.path.relpath(source_path, SOURCE)
            target = os.path.join(BUILD, "Kite", relative)

            text = lower(read(source_path))
            text = rewrite_requires(text, relative)
            write(target, text)
            count += 1

    # the CLI resolves `require("./Kite")` to a file, not to Kite/init, so
    # the lowered tree gets one thin shim. Studio never sees it: the model is
    # built from the package source, which uses `require(script.Core.X)`.
    # the CLI resolves `require("./Kite/main")` to a file, and it has no
    # `init` convention, so the lowered tree carries a second entry point
    main_path = os.path.join(BUILD, "Kite", "main.luau")
    if os.path.exists(os.path.join(BUILD, "Kite", "init.luau")):
        write(main_path, read(os.path.join(BUILD, "Kite", "init.luau")))

    log(f"lowered {count} files into build/Luau/Kite")
    return count


BUNDLE_GLOBALS = [
    "Instance",
    "UDim",
    "UDim2",
    "Vector2",
    "Vector3",
    "Color3",
    "CFrame",
    "Rect",
    "ColorSequence",
    "ColorSequenceKeypoint",
    "NumberSequence",
    "NumberSequenceKeypoint",
    "Font",
    "Enum",
    "BrickColor",
    "TweenInfo",
    "game",
    "workspace",
    "task",
    "warn",
]


def bundle_requires(text):
    """require(script.Parent.Util) -> __require("Util"), inside one chunk."""

    def convert(match):
        names = match.group(1).split(".")[1:]
        return '__require("%s")' % names[-1]

    return REQUIRE.sub(convert, text)


def build_bundle():
    """
    The whole package as one chunk.

    Two reasons it exists. The Luau CLI hands every required module its own
    globals table, which Roblox does not, so the test runner needs the
    package in one chunk to see the stub. And some people want a single file
    they can paste instead of a model.
    """
    modules = {}

    for current, _dirs, files in os.walk(SOURCE):
        for name in sorted(files):
            if not (name.endswith(".luau") or name.endswith(".lua")):
                continue

            full = os.path.join(current, name)
            relative = os.path.relpath(full, SOURCE)
            key = "init" if relative == "init.luau" else os.path.splitext(os.path.basename(name))[0]
            modules[key] = bundle_requires(lower(read(full)))

    if "init" not in modules:
        log("no init.luau, skipping the bundle")
        return None

    keys = ["init"] + sorted(k for k in modules if k != "init")

    out = []
    out.append("--[=[")
    out.append('\t--> ["Kite : bundle"]')
    out.append("")
    out.append(f"\tKite {VERSION}, generated by build.py. Do not edit by hand.")
    out.append("")
    out.append("\tOne chunk, no requires. Call it with a table of Roblox globals")
    out.append("\tif you are running outside Studio:")
    out.append("")
    out.append("\t\tlocal Kite = require(path.to.Bundle)({ Instance = ..., game = ... })")
    out.append("")
    out.append("\tInside Roblox, call it with nothing and it uses the real globals.")
    out.append("]=]")
    out.append("")
    out.append("return function(env)")
    out.append("\tif env then")
    for name in BUNDLE_GLOBALS:
        if name in ("print", "typeof"):
            continue
        out.append(f"\t\t{name} = env.{name} or {name}")
    out.append("\tend")
    out.append("")
    out.append("\tlocal __modules = {}")
    out.append("\tlocal __cache = {}")
    out.append("")
    out.append("\t-- one instance per module, exactly like Roblox: requiring the same")
    out.append("\t-- module twice hands back the same table")
    out.append("\tlocal function __require(name)")
    out.append("\t\tlocal hit = __cache[name]")
    out.append("\t\tif hit ~= nil then")
    out.append("\t\t\treturn hit")
    out.append("\t\tend")
    out.append("")
    out.append("\t\tlocal made = __modules[name]()")
    out.append("\t\t__cache[name] = made")
    out.append("\t\treturn made")
    out.append("\tend")
    out.append("")

    for key in keys:
        out.append(f'\t__modules["{key}"] = function()')
        for line in modules[key].splitlines():
            out.append(("\t" + line) if line.strip() else "")
        out.append("\tend")
        out.append("")

    out.append('\treturn __require("init")')
    out.append("end")

    target = os.path.join(BUILD, "Kite", "Bundle.luau")
    write(target, "\n".join(out) + "\n")

    log(f"bundled {len(keys)} modules into build/Luau/Kite/Bundle.luau")
    return target


def build_tree(name, path):
    """Walks one folder into rbxmx items."""
    items = []

    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)

        if os.path.isdir(full):
            items.append(build_tree(entry, full))
            continue

        if not (entry.endswith(".luau") or entry.endswith(".lua")):
            continue

        stem, class_name = class_of(entry)
        items.append(script_xml(stem, lower(read(full)), class_name))

    children = "\n".join(items)
    return folder_xml(name, children) if children else folder_xml(name, "")


def build_model():
    model = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        "<Meta name=\"ExplicitAutoJoints\">true</Meta>\n"
        "<External>null</External>\n"
        "<External>nil</External>\n"
        f"{build_tree('Kite', SOURCE)}\n"
        "</roblox>\n"
    )

    os.makedirs(RELEASES, exist_ok=True)
    target = os.path.join(RELEASES, f"Kite {VERSION}.rbxmx")
    write(target, model)

    log(f"wrote {os.path.relpath(target, ROOT)}")
    return target


def check():
    """Reports files that dropped back into `local`."""
    offenders = []

    for current, _dirs, files in os.walk(SOURCE):
        for name in sorted(files):
            if not name.endswith(".luau"):
                continue
            path = os.path.join(current, name)
            for number, line in enumerate(read(path).splitlines(), start=1):
                if re.match(r"^\s*local\s+(?!function\b)", line):
                    offenders.append((os.path.relpath(path, ROOT), number, line.strip()))

    if offenders:
        log(f"{len(offenders)} package lines still bind values with `local` instead of `const`")
        for path, number, line in offenders[:40]:
            print(f"  {path}:{number}  {line}")
    else:
        log("package source is fully in the const flavor")

    return offenders


def main():
    parser = argparse.ArgumentParser(description="Build Kite.")
    parser.add_argument("--luau", action="store_true", help="only lower the Luau tree")
    parser.add_argument("--model", action="store_true", help="only build the rbxmx")
    parser.add_argument("--check", action="store_true", help="only report `local` usage")
    parser.add_argument("--bundle", action="store_true", help="only build the single chunk bundle")
    args = parser.parse_args()

    log(f"Kite {VERSION} by {AUTHOR}")
    log(GITHUB)

    if args.check:
        check()
        return 0

    if args.luau:
        build_luau()
        return 0

    if args.model:
        build_model()
        return 0

    if args.bundle:
        build_luau()
        build_bundle()
        return 0

    build_luau()
    build_bundle()
    build_model()
    check()

    log("done")
    return 0


if __name__ == "__main__":
    sys.exit(main())

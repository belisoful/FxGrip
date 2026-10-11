#!/usr/bin/env python3
"""
make-fcpxml-schema.py — regenerate FxGrip's FCPXML schema table from Apple's DTDs.

Final Cut Pro ships one DTD per FCPXML version inside its Interchange framework. This
script reads every FCPXMLv1_N.dtd it finds, records for each element the version that
introduced it, the version that removed it, its allowed child elements, and its
attributes (type, enumerated values, default, required flag, introducing version), and
writes the result as the C tables in FxGrip/FCPXML/FxGripFCPXMLSchemaTable.m.

Usage:
    Scripts/make-fcpxml-schema.py [--dtd-dir DIR] [--output FILE] [--json FILE]

The default DTD directory is the installed Final Cut Pro's
Contents/Frameworks/Interchange.framework/Resources. Run the script after a Final Cut Pro
update adds a DTD version, then run the FCPXML tests; FxGripFCPXMLVersionTests pins the
latest version the table knows.
"""

import argparse
import json
import os
import re
import sys

DEFAULT_DTD_DIR = ("/Applications/Final Cut Pro.app/Contents/Frameworks/Interchange.framework"
                   "/Versions/A/Resources")
DEFAULT_OUTPUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "FxGrip", "FCPXML",
                              "FxGripFCPXMLSchemaTable.m")

TIME_SENTINEL = "__TIME__"


def strip_comments(text):
    return re.sub(r"<!--.*?-->", "", text, flags=re.S)


def parse_entities(text):
    entities = {}
    for match in re.finditer(r'<!ENTITY\s+%\s+([\w.-]+)\s+"(.*?)"\s*>', text, flags=re.S):
        entities[match.group(1)] = match.group(2)
    return entities


def expand(value, entities):
    # The time entity is kept as a sentinel so a time-typed attribute stays recognizable.
    previous = None
    while previous != value:
        previous = value

        def replace(match):
            name = match.group(1)
            if name == "time":
                return TIME_SENTINEL
            if name not in entities:
                raise KeyError("Undefined DTD entity %%%s;" % name)
            return entities[name]

        value = re.sub(r"%([\w.-]+);", replace, value)
    return value


def parse_elements(text, entities):
    elements = {}
    for match in re.finditer(r"<!ELEMENT\s+([\w.-]+)\s+(.*?)>", text, flags=re.S):
        name = match.group(1)
        content = expand(match.group(2), entities)
        children = sorted(set(re.findall(r"[A-Za-z][\w.-]*", content)) - {"EMPTY", "ANY", "PCDATA"})
        elements[name] = {"children": children, "attributes": {}}
    return elements


ATTR_PATTERN = re.compile(
    r"([\w.-]+)\s+"                                   # attribute name
    r"(CDATA|ID|IDREF|IDREFS|NMTOKEN|NMTOKENS|ENTITY|ENTITIES|" + TIME_SENTINEL + r"|\([^)]*\))\s+"  # type
    r"(#REQUIRED|#IMPLIED|#FIXED\s+(?:\"[^\"]*\"|'[^']*')|\"[^\"]*\"|'[^']*')",  # default
    flags=re.S)


def parse_attlists(text, entities, elements):
    for match in re.finditer(r"<!ATTLIST\s+([\w.-]+)\s+(.*?)>", text, flags=re.S):
        element = match.group(1)
        body = expand(match.group(2), entities)
        if element not in elements:
            elements[element] = {"children": [], "attributes": {}}
        position = 0
        for attr in ATTR_PATTERN.finditer(body):
            name, kind, default = attr.group(1), attr.group(2), attr.group(3)
            record = {"kind": "cdata", "values": [], "required": False, "default": None, "fixed": False}
            if kind == TIME_SENTINEL:
                record["kind"] = "time"
            elif kind.startswith("("):
                record["kind"] = "enum"
                record["values"] = [v.strip() for v in kind.strip("()").split("|")]
            elif kind == "ID":
                record["kind"] = "id"
            elif kind in ("IDREF", "IDREFS"):
                record["kind"] = "idref"
            if default == "#REQUIRED":
                record["required"] = True
            elif default == "#IMPLIED":
                pass
            elif default.startswith("#FIXED"):
                record["fixed"] = True
                record["default"] = default.split(None, 1)[1].strip().strip("\"'")
            else:
                record["default"] = default.strip("\"'")
            elements[element]["attributes"][name] = record
            position += 1


def parse_dtd(path):
    with open(path, "r", encoding="utf-8") as handle:
        text = strip_comments(handle.read())
    entities = parse_entities(text)
    elements = parse_elements(text, entities)
    parse_attlists(text, entities, elements)
    return elements


def version_of(filename):
    match = re.match(r"FCPXMLv(\d+)_(\d+)\.dtd$", filename)
    if not match:
        return None
    return (int(match.group(1)), int(match.group(2)))


def merge(versions):
    """versions: list of ((major, minor), elements) sorted ascending."""
    merged = {}
    for (major, minor), elements in versions:
        for name, element in elements.items():
            entry = merged.setdefault(name, {"introduced": minor, "removed": None, "children": [],
                                             "attributes": {}, "last_seen": minor})
            if entry["removed"] is not None:
                # Re-introduced after a removal; keep the first introduction and clear the removal.
                entry["removed"] = None
            entry["children"] = element["children"]
            entry["last_seen"] = minor
            for attr_name, attr in element["attributes"].items():
                attr_entry = entry["attributes"].setdefault(attr_name, {"introduced": minor})
                attr_entry.update({k: attr[k] for k in ("kind", "values", "required", "default", "fixed")})
                attr_entry["last_seen"] = minor
        latest_minor = minor
        for name, entry in merged.items():
            if name not in elements and entry["removed"] is None and entry["last_seen"] < minor:
                entry["removed"] = minor
            for attr_name, attr_entry in entry["attributes"].items():
                if name in elements and attr_name not in elements[name]["attributes"] \
                        and attr_entry.get("removed") is None and attr_entry["last_seen"] < minor:
                    attr_entry["removed"] = minor
    return merged, latest_minor


def c_string(value):
    if value is None:
        return "NULL"
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def emit(merged, latest_minor, versions_present, output_path):
    lines = []
    lines.append("/*!")
    lines.append("\t@file       FxGripFCPXMLSchemaTable.m")
    lines.append("\t@copyright  Copyright © 2024 Belisoful All rights reserved.")
    lines.append("\t@author     belisoful")
    lines.append("\t@date       2026-10-10")
    lines.append("\t@header     FxGripFCPXMLSchemaTable")
    lines.append("\t@abstract   The FCPXML element and attribute table, generated from Apple's DTDs.")
    lines.append("\t@discussion Introduced in FxGrip 0.1.0. Generated by Scripts/make-fcpxml-schema.py from the")
    lines.append("\t            FCPXML DTDs " + ", ".join("1.%d" % m for m in versions_present) + " that Final Cut Pro")
    lines.append("\t            installs. Do not edit by hand; rerun the script after a Final Cut Pro update.")
    lines.append("*/")
    lines.append("")
    lines.append("#import <FxGrip/FxGripFCPXMLSchema.h>")
    lines.append("")
    lines.append("const NSInteger FxGripFCPXMLSchemaLatestMinorVersion = %d;" % latest_minor)
    lines.append("")
    lines.append("const FxGripFCPXMLSchemaAttributeRecord FxGripFCPXMLSchemaAttributeRecords[] = {")
    attribute_count = 0
    kinds = {"cdata": "FxGripFCPXMLAttributeKindString", "time": "FxGripFCPXMLAttributeKindTime",
             "enum": "FxGripFCPXMLAttributeKindEnumeration", "id": "FxGripFCPXMLAttributeKindIdentifier",
             "idref": "FxGripFCPXMLAttributeKindReference"}
    for name in sorted(merged):
        entry = merged[name]
        for attr_name in sorted(entry["attributes"]):
            attr = entry["attributes"][attr_name]
            removed = attr.get("removed")
            lines.append("\t{%s, %s, %d, %d, %s, %s, %s, %s}," % (
                c_string(name), c_string(attr_name), attr["introduced"],
                -1 if removed is None else removed, kinds[attr["kind"]],
                "YES" if attr["required"] else "NO", c_string(attr["default"]),
                c_string("|".join(attr["values"])) if attr["values"] else "NULL"))
            attribute_count += 1
    lines.append("};")
    lines.append("const NSUInteger FxGripFCPXMLSchemaAttributeRecordCount = %d;" % attribute_count)
    lines.append("")
    lines.append("const FxGripFCPXMLSchemaElementRecord FxGripFCPXMLSchemaElementRecords[] = {")
    for name in sorted(merged):
        entry = merged[name]
        lines.append("\t{%s, %d, %d, %s}," % (
            c_string(name), entry["introduced"], -1 if entry["removed"] is None else entry["removed"],
            c_string(" ".join(entry["children"]))))
    lines.append("};")
    lines.append("const NSUInteger FxGripFCPXMLSchemaElementRecordCount = %d;" % len(merged))
    lines.append("")
    with open(output_path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dtd-dir", default=DEFAULT_DTD_DIR)
    parser.add_argument("--output", default=os.path.normpath(DEFAULT_OUTPUT))
    parser.add_argument("--json", default=None, help="also write the merged table as JSON")
    args = parser.parse_args()

    found = []
    for filename in os.listdir(args.dtd_dir):
        version = version_of(filename)
        if version is not None:
            found.append((version, os.path.join(args.dtd_dir, filename)))
    if not found:
        sys.exit("No FCPXMLv1_N.dtd files in %s" % args.dtd_dir)
    found.sort()
    versions = [(version, parse_dtd(path)) for version, path in found]
    merged, latest_minor = merge(versions)
    emit(merged, latest_minor, [v[1] for v, _ in versions], args.output)
    if args.json:
        with open(args.json, "w", encoding="utf-8") as handle:
            json.dump({"latest": latest_minor, "elements": merged}, handle, indent=1, sort_keys=True)
    print("Wrote %d elements to %s (latest FCPXML 1.%d)" % (len(merged), args.output, latest_minor))


if __name__ == "__main__":
    main()

#!/bin/bash
# Print the current default app for each claimed extension plus a few that must stay untouched.
# Usage: scripts/handlers.sh [--summary]
cd "$(dirname "$0")/.."
EXTS=$(grep -v '^#' Support/extensions.txt | tr '\n' ' ')
CANARY="html svg txt csv log plist rtf xcconfig entitlements strings storyboard xib metal pdf png"
osascript -l JavaScript -e '
ObjC.import("AppKit");
$.NSBundle.bundleWithPath("/System/Library/Frameworks/UniformTypeIdentifiers.framework").load;
var UT=$.NSClassFromString("UTType"), ws=$.NSWorkspace.sharedWorkspace;
function app(e){var u=ws.URLForApplicationToOpenContentType(UT.typeWithFilenameExtension(e)); return u.isNil()?"-":ObjC.unwrap(u.lastPathComponent)}
var summary="'"$1"'"=="--summary", by={}, out=[];
"'"$EXTS"'".trim().split(/\s+/).forEach(function(e){var a=app(e); (by[a]=by[a]||[]).push(e); out.push("."+e+"\t"+a)});
var res = summary ? Object.keys(by).map(function(a){return a+" ("+by[a].length+"): "+by[a].join(" ")}) : out;
res.push("--- must stay untouched ---");
"'"$CANARY"'".split(" ").forEach(function(e){res.push("."+e+"\t"+app(e))});
res.join("\n")'

#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
"${LUA:-lua}" test/smoke/config.lua
"${LUA:-lua}" test/smoke/server.lua
"${LUA:-lua}" test/smoke/client.lua

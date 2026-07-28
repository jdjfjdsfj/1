#!/bin/sh
if ! command -v node >/dev/null 2>&1; then
    ln -sf /userdisk/PenMods/plugins/kugou/node/bin/node /usr/bin/node
fi

if ! command -v npm >/dev/null 2>&1; then
    ln -sf /userdisk/PenMods/plugins/kugou/node/bin/npm /usr/bin/npm
fi

if ! command -v npx >/dev/null 2>&1; then
    ln -sf /userdisk/PenMods/plugins/kugou/node/bin/npx /usr/bin/npx
fi
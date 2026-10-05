# pstack-sync

Installs and updates a reviewed set of [pstack](https://github.com/cursor/plugins/tree/main/pstack) skills (Lauren Tan, MIT) and a short set of working rules for Claude Code.

`sync.sh` pins the upstream commit that has been reviewed. A weekly check reviews upstream changes before moving the pin.

Run: `curl -fsSL https://raw.githubusercontent.com/workcrew-ltd/pstack-sync/main/sync.sh | bash`

#!/usr/bin/bash

if [ -z "$VIRTUAL_ENV" ]; then echo "VENV is not loaded. Did you remember to run: source ./env-tt10.sh"; exit 1; fi

echo "Regenerating user config..."
./tt/tt_tool.py --create-user-config --openlane2 && (
    echo "Running local hardening..."
    ./tt/tt_tool.py --harden --openlane2
)



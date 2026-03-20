#!/bin/sh
set -e

# Reload systemd to pick up new unit files
if [ -d /run/systemd/system ]; then
    systemctl daemon-reload || true
fi

echo ""
echo "MDEMG installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Verify:  mdemg version"
echo "  2. Init:    cd your-project && mdemg init"
echo "  3. Start:   mdemg start --auto-migrate"
echo ""
echo "Enable as system service:"
echo "  sudo systemctl enable --now mdemg@\$USER"

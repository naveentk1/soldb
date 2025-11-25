#!/bin/bash
echo "Installing SOLDB..."

# Build both executables
echo "Building sol-server and sol-cli..."
zig build -Doptimize=ReleaseSafe

# Install to /usr/local/bin
echo "Installing to /usr/local/bin/"
sudo cp zig-out/bin/sol-server /usr/local/bin/
sudo cp zig-out/bin/sol-cli /usr/local/bin/

echo "SOLDB installed successfully!"
echo ""
echo "Available commands:"
echo "  sol-server    - Start the database server"
echo "  sol-cli       - Connect to the server"
echo ""
echo "Usage:"
echo "  1. Start server: sol-server"
echo "  2. In another terminal: sol-cli"
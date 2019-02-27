#!/bin/sh

echo "🎌 Running LRR Test Suite 🎌"

# Start a redis server instance
/usr/bin/redis-server --daemonize yes

# Run the perl tests on the repo
prove -l tests/*.t


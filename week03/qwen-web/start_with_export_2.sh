#!/bin/bash
cd "$(dirname "$0")" || exit 1
export WEB_PORT="8080"
export MODEL="qwen3:0.6b"
exec ./start.sh

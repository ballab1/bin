#!/bin/bash

declare loc="$(pwd)"

cd ~/GIT/promote
source .venv/bin/activate
python main.py --promote PROMOTE --dir "$loc"

#!/bin/bash

curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py

python3 get-pip.py

export PATH=$PATH:$HOME/.local/bin

pip install pexpect

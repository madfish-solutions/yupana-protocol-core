# Rapid tests for Audit

Powered by PyTezos.

## Prerequisites

Install cryptographic libraries according to your system following the instrucitons here:
https://pytezos.org/quick_start.html#requirements

## Installation

```
python3 -m pip install pytezos
./integration_tests/build.sh
```

## Usage
From the root folder
```
python3 -m pytest . -v -s
```

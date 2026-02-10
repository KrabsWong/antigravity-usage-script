# Antigravity Usage Script

A shell script to fetch and display usage statistics for the Antigravity AI coding assistant. Powered by [OpenCode](https://github.com/anomalyco/opencode) + Pony Alpha

## Features

- Displays account email and prompt credit balance
- Shows remaining quota for each available AI model
- Indicates quota reset time in local timezone
- Highlights low or exhausted model quotas

## Prerequisites

- `jq` - JSON processor (required for parsing API responses)
- Antigravity must be running

## Usage

```bash
./fetch-antigravity-usage.sh
```

## Sample Output

```
Account: user@example.com
Prompt Credits: 450 / 500

Model                                 Remaining  Reset Time           Status
------------------------------------- ---------  -------------------  --------
claude-3.5-sonnet                     85%        2025-02-15 00:00     OK
gpt-4o                                12%        2025-02-15 00:00     Low
o1-preview                            0%         2025-02-15 00:00     Exhausted
```

<img width="727" height="336" alt="image" src="https://github.com/user-attachments/assets/f8ce0dfb-0c9c-4374-a1f3-f5819260138e" />


## How It Works

1. Detects the running Antigravity process
2. Extracts the CSRF token from process arguments
3. Identifies listening ports for the local API
4. Queries the `GetUserStatus` endpoint
5. Formats and displays quota information

## Compatibility

Works on both macOS and Linux.

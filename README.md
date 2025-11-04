# dapenv

A lightweight Neovim plugin that automatically loads environment variables from .env files specified in your .vscode/launch.json debug configurations.
It seamlessly bridges the gap between nvim-dap and VS Code's envFile property, so you don't have to manually define environment variables in your Neovim config.

## Features

- **Automatic:** Patches `dap.run` to automatically intercept any debug configuration.
- **envFile Support:** Reads `envFile` arrays from your `launch.json` configurations.
- **Variable Substitution:** Automatically substitutes `${VAR}` and `$VAR` in your `.env` files.
- **Workspace Detection:** Finds `.env` files relative to your project root (marked by `.git`).
- **Configurable:** You can easily disable variable substitution.

## Requirements

- [neovim/nvim-dap](https://github.com/mfussenegger/nvim-dap) (This plugin is an extension of nvim-dap)
- `nvim-dap` must be configured to load `.vscode/launch.json` files.

## Installation

Install using your favorite plugin manager.

### lazy

Add this to your plugin specifications. If you are using a local copy for development:

```lua
-- /plugins/dapenv.lua
return {
  "wasistdenndas/dapenv.nvim",
  dependencies = { "mfussenegger/nvim-dap" },
  opts = {
  -- Your configuration goes here
  },
}
```

### Configuration

You can configure `dapenv.nvim` by passing an `opts` table in your plugin specification.

#### Default Configuration

```lua
opts = {
  -- Enable/disable variable substitution (e.g., ${VAR} or $VAR)
  substitution = true,
}
```

## How It Works

This plugin is designed to be "zero-config" after installation.

1. On startup (`VimEnter`), it safely patches the `dap.run` function.
2. When you start a debug session, the patch intercepts the configuration you selected.
3. It checks for an `envFile = { ... }`` property.
4. If found, it:
   - Finds your project root.
   - Resolves the file paths (e.g., `${workspaceFolder}/.env`).
   - Reads all variables from those files.
   - Performs variable substitution (if enabled).
   - Merges the loaded variables into the debug configuration's `env` table.
5. The original dap.run function is then called with the new environment, and your debug session starts.

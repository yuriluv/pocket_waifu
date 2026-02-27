# Stabilization Checklist Automation

This repository includes a lightweight automation script for stability checks during Part 2 iteration.

## Script

```bash
./scripts/stabilization_checklist.sh
```

For a quick summary without failing the build:

```bash
./scripts/stabilization_checklist.sh --summary
```

## What It Checks

- Core Live2D bridge and overlay files exist.
- Key state-sync patterns are present.
- Renderer fallback markers are present.

This is not a full replacement for manual review. Extend the script when new stability requirements are added.

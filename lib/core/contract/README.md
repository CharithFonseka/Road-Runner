# Core Contract

Owner: Praveen  
SRS reference: Sections 4.3–4.8

This folder contains the **frozen shared specification** that lets five team members build in parallel without breaking each other's code.

## Files

| File | Language | Purpose |
|---|---|---|
| `contract.dart` | Dart | Channel names, method names, states, event types, error codes, filter config |

The Kotlin mirror is at `android/app/src/main/kotlin/com/roadrunner/app/bridge/Contract.kt`.

## ⚠️ Rules

1. **Do not edit these files** without opening a CCR (GitHub issue titled `CCR: <what>`).
2. Praveen approves after affected owners agree.
3. After approval: update **both** files together in one PR.
4. CI will fail if the files disagree.

## How to verify locally

```bash
bash scripts/check_contract.sh
```

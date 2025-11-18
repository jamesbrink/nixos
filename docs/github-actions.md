# GitHub Actions Troubleshooting

Use these steps when a workflow run hangs in `queued` and refuses to cancel after runner issues or label mismatches.

## Force-Cancel a Stuck Run

1. Identify the `run_id` from the Actions run URL.
2. Run the new REST endpoint (requires `gh` CLI):
   ```bash
   gh api \
     --method POST \
     -H "Accept: application/vnd.github+json" \
     -H "X-GitHub-Api-Version: 2022-11-28" \
     /repos/<owner>/<repo>/actions/runs/<run_id>/force-cancel
   ```
3. Confirm the run flips to `status: completed` and `conclusion: cancelled`:
   ```bash
   gh run view <run_id> -R <owner>/<repo> --json status,conclusion
   ```

If the run still refuses to exit (rare), delete it entirely:

```bash
gh api --method DELETE /repos/<owner>/<repo>/actions/runs/<run_id>
```

## Notes

- Force-cancel is the documented GitHub solution when regular `gh run cancel <id>` leaves a run indefinitely queued.
- We used this to clear `quantierra/dealflow-api` runs `19433417619` and `19432457397` after updating self-hosted runner labels; the command returned `{}` and the runs immediately switched to `cancelled`.
- Deleting a run removes logs/history, so prefer the force endpoint unless the record must be purged.

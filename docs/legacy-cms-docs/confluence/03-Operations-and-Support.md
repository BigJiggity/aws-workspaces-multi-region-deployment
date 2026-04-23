# Operations and Support

## Operational Model
- Deployments are managed per Terragrunt unit to reduce blast radius.
- Remote state lock prevents concurrent modifications.
- Preflight checks are recommended before all plans/applies.

## Standard Operating Procedures
### Routine Change
1. Update code in target unit.
2. Run formatting and validation.
3. Run `terragrunt plan`.
4. Peer review.
5. Run `terragrunt apply`.
6. Capture outputs in change record.

### Failed WorkSpace Provisioning
Use helper cleanup scripts to terminate errored WorkSpaces:
- `./cleanup-workspaces.sh`
- `.\cleanup-workspaces.ps1`

Then:
1. Check AWS WorkSpaces error state/details.
2. Resolve root cause (user object, bundle validity, directory health, quota).
3. Re-run apply.

## State Lock Handling
If lock is orphaned (for example session/token expiry):
1. Re-authenticate AWS CLI
2. Force unlock with lock ID only when lock owner process is no longer running
3. Re-run plan/apply

## Monitoring and Verification
- Validate resource creation in AWS console after apply.
- Validate S3 encryption and public access block settings.
- Validate DynamoDB lock table activity during apply.
- Validate WorkSpaces and Pools in expected state.

## Common Failure Patterns
|| Symptom || Likely Cause || Action ||
| WorkSpaces create ERROR state | User/bundle/directory mismatch or transient AWS issue | Gather diagnostics, terminate errored workspace, retry |
| Unsupported argument in Terraform | Provider/resource mismatch | Align provider version and resource schema |
| Terragrunt source path not found | Relative path drift | Correct `source` path from unit directory |
| State lock acquisition error | Stale lock | Verify lock owner process, then force unlock if safe |

## Escalation Data to Capture
- Unit path executed
- Full plan/apply error output
- Workspace ID / Directory ID / Bundle ID
- Timestamp (local and UTC)
- AWS request IDs (from error output)

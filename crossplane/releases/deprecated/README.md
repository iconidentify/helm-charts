# Deprecated Crossplane Releases

These releases have been deprecated and should not be used in new deployments.

## nginx-proxy
**Reason**: Use the existing cluster ingress controller instead. The nginx-proxy was a custom solution that is no longer needed.

## netatalk
**Reason**: No longer needed. This service has been decommissioned.

## demo-app
**Reason**: Demo application used for testing. Not needed in production.

## mac-connect
**Reason**: Replaced by separate 68k-relay and 68k-web charts. The monolithic mac-connect chart has been split for better separation of concerns.

---

To remove these from your cluster:
1. Delete the Crossplane Release resources
2. The `deletionPolicy: Orphan` will leave the Helm releases in place
3. Manually delete the orphaned Helm releases if desired

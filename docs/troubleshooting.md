# Troubleshooting TSF installation

Use this guide to diagnose and resolve common issues during TSF installation and deployment.

## Quay token error during deployment

**Symptom:** The `tsf deploy` command fails at the `tsf-konflux` chart with:

```
Error: install failed: execution error at (tsf-konflux/templates/quaytoken-secret.yaml:3:19): token field not found in secret
```

**Cause:** The Quay OAuth token is expired, invalid, or was not saved correctly during the integration step.

**Resolution:**

1. Regenerate the Quay OAuth token in your Quay organization.
2. Delete the existing Quay secret:

   ```bash
   oc delete secret tsf-quay-integration -n tsf
   ```

3. Re-run the Quay integration:

   ```bash
   tsf integration quay \
     --organization="$QUAY__ORG" \
     --token="$QUAY__API_TOKEN" \
     --url="$QUAY__URL"
   ```

4. Re-run the deployment:

   ```bash
   tsf deploy
   ```

## Cert-Manager subscription conflict

**Symptom:** The deployment fails with a subscription conflict error for the Cert-Manager operator.

**Cause:** The Red Hat Cert-Manager Operator is already installed on the cluster. The TSF installer attempts to create a second subscription, which conflicts with the existing one.

**Resolution:** Edit the `tsf-config` ConfigMap and set `manageSubscription` to `false` for the Cert-Manager component:

```bash
oc edit configmap tsf-config -n tsf
```

Locate the Cert-Manager entry and change `manageSubscription: true` to `manageSubscription: false`. Then re-run the deployment.

## Red Hat Trusted Profile Analyzer UI URL is not accessible

**Symptom:** The RHTPA UI URL displayed in the deployment output shows `server%s(<nil>)` or returns an error.

**Cause:** The RHTPA service may not have started correctly, or the PostgreSQL database that it depends on is not running.

**Resolution:**

1. Check the RHTPA operator pod status:

   ```bash
   oc get pods -n tsf-tpa
   ```

2. Check the PostgreSQL pod status:

   ```bash
   oc get pods -n tsf-tpa | grep postgres
   ```

3. If pods are in error state, check the logs:

   ```bash
   oc logs -n tsf-tpa deployment/rhtpa-operator
   ```

4. As a workaround, find the correct route URL directly:

   ```bash
   oc get routes -n tsf-tpa
   ```

## Deployment appears to hang

**Symptom:** The `tsf deploy` command runs for an extended period without producing any output.

**Cause:** Some Helm charts take several minutes to deploy, especially when pulling container images for the first time. The installer does not display a progress indicator during these periods.

**Resolution:** The deployment is still running. In a separate terminal, monitor the pod status:

```bash
oc get pods -A --watch
```

Wait for the deployment to complete. The full process typically takes about 15 minutes.

## Browser fails to open during GitHub integration

**Symptom:** The `tsf integration github --create` command logs an error:

```
level=ERROR msg="failed to open browser" error="exec: "xdg-open": executable file not found in $PATH"
```

**Cause:** The installer container does not have a graphical browser or the `xdg-open` utility. The command attempts to open the URL automatically but cannot do so inside the container.

**Resolution:** Copy the `localhost:8228` URL from the command output and open it manually in a web browser on your local machine.

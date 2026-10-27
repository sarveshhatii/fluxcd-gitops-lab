# FluxCD + GitOps Lab --- Commands from Start to End

This guide documents the local Windows PowerShell workflow for the
FluxCD GitOps website project. Each command includes its purpose.

## Project details

-   Repository folder:
    `C:\Users\patil\Desktop\Devops intern Task\fluxcd-gitops-lab\fluxcd-repo`
-   GitHub repository:
    `https://github.com/sarveshhatii/fluxcd-gitops-lab`
-   Branch: `main`
-   k3d cluster: `fluxcd-gitops-lab`
-   Kubernetes context: `k3d-fluxcd-gitops-lab`
-   Flux namespace: `flux-system`
-   Website namespace: `gitops-demo`
-   Docker Hub image: `sarvesh8415/fluxcd-gitops-lab`
-   Deployment and Service: `gitops-website`

**Security:** Never print, decode, commit, or share GitHub PATs, Docker
Hub tokens, SSH private keys, or Kubernetes Secret values. The setup
already exists; do not rerun bootstrap or delete the cluster just to
verify it.

## 1. Open the repository

``` powershell
Set-Location "C:\Users\patil\Desktop\Devops intern Task\fluxcd-gitops-lab\fluxcd-repo"
Get-Location
git status
git remote -v
git branch --show-current
```

**Purpose:** Opens the actual Git repository, shows the current folder,
checks changed files, shows the GitHub remote, and confirms the current
branch.

## 2. Check required tools

``` powershell
docker --version
docker info
kubectl version --client
k3d version
flux version
git --version
```

**Purpose:** Checks installed tools and confirms Docker Engine is
available. If `docker info` fails, start Docker Desktop.

## 3. Start and select the existing cluster

``` powershell
k3d cluster list
k3d cluster start fluxcd-gitops-lab
kubectl config use-context k3d-fluxcd-gitops-lab
kubectl config current-context
kubectl get nodes -o wide
```

**Purpose:** Lists k3d clusters, starts the existing project cluster,
selects its context, and checks that nodes are Ready. Do not start,
delete, or modify `monitoring-lab` or `velero-lab` for this task. If the
cluster is already running, the start command may simply report its
state.

### Initial cluster creation only

Run this only if the cluster does not exist and you intentionally need
to create it:

``` powershell
k3d cluster create fluxcd-gitops-lab --servers 1 --agents 1
```

**Purpose:** Creates a local Kubernetes cluster with one server and one
agent. Do not run it again for an existing cluster.

## 4. Install / bootstrap FluxCD

Flux was bootstrapped to repository `sarveshhatii/fluxcd-gitops-lab`,
branch `main`, path `clusters/fluxcd-gitops-lab`.

A typical bootstrap command has this form:

``` powershell
flux bootstrap github `
  --owner=sarveshhatii `
  --repository=fluxcd-gitops-lab `
  --branch=main `
  --path=clusters/fluxcd-gitops-lab `
  --personal
```

**Purpose:** Installs Flux controllers into the cluster and configures
Git synchronization. This is an example command form, not a command to
rerun on the already-working cluster. Authentication options and
environment setup may differ from the original bootstrap.

Verify the existing installation:

``` powershell
flux check
kubectl get pods -n flux-system
flux get all -A
```

**Purpose:** Checks Flux prerequisites/health, lists controller pods,
and displays Flux resource status.

## 5. Inspect repository configuration

``` powershell
Get-ChildItem .\clusters\fluxcd-gitops-lab -Recurse -Filter *.yaml
```

**Purpose:** Lists YAML configuration files.

``` powershell
Get-ChildItem .\clusters\fluxcd-gitops-lab -Recurse -Filter *.yaml |
  Select-String -Pattern 'interval:|image:|secretRef:|sourceRef:|path:|semver:'
```

**Purpose:** Finds important image names, intervals, Secret references,
source references, update paths, and version-policy settings. Review the
matches in context; `gotk-components.yaml` contains generated controller
definitions and many unrelated fields.

Key files and their purpose:

-   `.github/workflows/docker-build-push.yml` --- builds and pushes the
    website image through GitHub Actions.
-   `clusters/fluxcd-gitops-lab/flux-system/gotk-components.yaml` ---
    Flux controller installation resources.
-   `clusters/fluxcd-gitops-lab/flux-system/gotk-sync.yaml` --- root Git
    source and Kustomization sync configuration.
-   `clusters/fluxcd-gitops-lab/flux-system/kustomization.yaml` ---
    Flux-related resources included by the root setup.
-   `gitrepository-writeback.yaml` --- HTTPS Git source with a reference
    to the write-back Secret.
-   `image-repository.yaml` --- Docker Hub image scanning configuration.
-   `image-policy.yaml` --- chooses an eligible image tag.
-   `image-update-automation.yaml` --- writes image tag changes to Git.
-   `apps/website/namespace.yaml` --- website namespace.
-   `apps/website/deployment.yaml` --- desired pod replicas and
    container image.
-   `apps/website/service.yaml` --- stable network access to the
    website.
-   `apps/website/kustomization.yaml` --- groups the website manifests.

Check the workflow and Dockerfile:

``` powershell
Get-Content .\.github\workflows\docker-build-push.yml
Get-Content .\Dockerfile
```

**Purpose:** Shows the build triggers, build context, Dockerfile path,
tags, and Docker Hub push steps. Check the actual build context and
`COPY` paths before editing website files.

## 6. GitHub Actions → Docker Hub

GitHub repository **Settings → Secrets and variables → Actions**
contains these secret names:

-   `DOCKERHUB_USERNAME`
-   `DOCKERHUB_TOKEN`

**Purpose:** GitHub Actions uses these values to authenticate to Docker
Hub and push the image. Do not hard-code their values into YAML or
commit them.

After making a change to a watched website file, commit and push only
the intended files:

``` powershell
git status
git add .\apps\website
git commit -m "Update website"
git push origin main
```

**Purpose:** Checks changed files, stages the website files, creates a
commit, and pushes `main` to GitHub. Use `git add` paths that match the
files you actually changed.

Check the repository's **Actions** tab to verify that the workflow
succeeded. The workflow builds and pushes tags such as `latest` and
`1.0.<run-number>` according to its actual configuration.

## 7. Docker Hub image scanning

The live `ImageRepository` is named `gitops-website` in namespace
`flux-system`.

``` powershell
kubectl get imagerepository gitops-website -n flux-system -o yaml
kubectl describe imagerepository gitops-website -n flux-system
```

**Purpose:** Shows the image repository, scan interval, last scan
result, discovered tags, Ready condition, and any errors.

The known image is `sarvesh8415/fluxcd-gitops-lab`. The known scan found
tags `latest`, `1.0.1`, `1.0.2`, and `1.0.3`.

Check the version policy:

``` powershell
kubectl get imagepolicy gitops-website -n flux-system -o yaml
kubectl describe imagepolicy gitops-website -n flux-system
```

**Purpose:** Shows which image tags satisfy the configured policy. The
known semver range is `>=1.0.0 <2.0.0`; `latest` is not a semantic
version selected by that policy.

## 8. GitHub read and write-back connections

The regular Flux source uses the bootstrap SSH connection:

``` powershell
kubectl get gitrepositories -n flux-system
kubectl describe gitrepository flux-system -n flux-system
```

**Purpose:** Verifies the source Flux uses to fetch Git configuration.

The separate HTTPS write-back source is `fluxcd-gitops-writeback`:

``` powershell
kubectl get gitrepository fluxcd-gitops-writeback -n flux-system
kubectl describe gitrepository fluxcd-gitops-writeback -n flux-system
```

**Purpose:** Checks the source used by ImageUpdateAutomation to access
GitHub for write-back.

The `github-writeback` Kubernetes Secret in `flux-system` holds the
fine-grained GitHub PAT. Its known permissions are repository access to
`fluxcd-gitops-lab`, Contents read/write, and Metadata read-only. The
original bootstrap SSH deploy key was read-only, so the separate PAT was
used for pushes.

``` powershell
kubectl describe secret github-writeback -n flux-system
```

**Purpose:** Confirms the Secret exists and shows metadata/key names. Do
not use commands that decode or print its data. Never place the PAT in a
YAML file.

## 9. ImageUpdateAutomation

``` powershell
kubectl get imageupdateautomation gitops-website -n flux-system -o yaml
kubectl describe imageupdateautomation gitops-website -n flux-system
```

**Purpose:** Shows the checkout/push branches, Git source, update path,
interval, selected policy tag, last push commit/time, conditions, and
errors. The known configuration checks out and pushes `main`, uses
`fluxcd-gitops-writeback`, and updates `./apps/website` with the
`Setters` strategy.

Check the image setter marker:

``` powershell
Select-String -Path .\apps\website\deployment.yaml -Pattern 'image:|\$imagepolicy'
```

**Purpose:** Shows the Deployment image and the marker linking it to
`flux-system:gitops-website`.

If a new eligible tag is discovered, ImageUpdateAutomation can change
the Deployment YAML and push a commit such as `Update website image`. It
does not create a commit on every interval when the repository is
already up to date.

## 10. End-to-end workflow

1.  A watched source file changes and is pushed to GitHub.
2.  GitHub Actions builds the image and pushes it to Docker Hub.
3.  Flux Image Reflector Controller scans the registry for tags.
4.  ImagePolicy chooses the highest eligible semantic version.
5.  ImageUpdateAutomation changes the image tag in Git and pushes a
    commit to `main` using the `github-writeback` Secret.
6.  The normal Flux Git source fetches the updated Git revision.
7.  Flux Kustomize Controller applies the changed Deployment.
8.  Kubernetes Deployment Controller detects the changed pod template
    and performs a rollout.
9.  The container runtime pulls and runs the requested image.

A one-minute interval is a reconciliation/check interval, not a
guarantee that the whole workflow finishes within one minute.

# 11. Verification after FluxCD deployment

Run these commands after deployment and whenever checking whether a new
image is actually running.

## 11.1 Verify context and nodes

``` powershell
kubectl config current-context
kubectl get nodes -o wide
```

**Purpose:** Confirms the correct cluster is selected and its nodes are
Ready.

## 11.2 Verify Flux controllers and reconciliation

``` powershell
kubectl get pods -n flux-system
flux check
flux get all -A
kubectl get gitrepositories -n flux-system
kubectl get kustomizations -n flux-system
```

**Purpose:** Checks controller health, Flux resources, Git source
readiness, and whether the root Kustomization applied a Git revision.
Look for `Ready=True` and useful status messages.

## 11.3 Verify image scanning and selected tag

``` powershell
kubectl get imagerepository gitops-website -n flux-system -o yaml
kubectl get imagepolicy gitops-website -n flux-system -o yaml
```

**Purpose:** Confirms registry scanning succeeded and identifies the
selected eligible tag.

## 11.4 Verify the automation's Git push

``` powershell
kubectl get imageupdateautomation gitops-website -n flux-system -o yaml
```

**Purpose:** Inspect `observedPolicies`, `lastPushCommit`,
`lastPushTime`, `lastAutomationRunTime`, and status conditions.
`repository up-to-date` means no file change currently needs pushing.

View commit history in GitHub:

`https://github.com/sarveshhatii/fluxcd-gitops-lab/commits/main/`

Or inspect local history:

``` powershell
git pull origin main
git log -5 --oneline
```

**Purpose:** Pulls the latest remote branch and lists recent commits.
Only pull if you want to update the local checkout.

## 11.5 Verify image configured in the live Deployment

``` powershell
kubectl get deployment gitops-website -n gitops-demo -o jsonpath="{.spec.template.spec.containers[*].image}"
Write-Output ""
```

**Purpose:** Prints the image reference in the live Deployment pod
template. This is the desired image recorded by Kubernetes.

## 11.6 Verify the image on running pods --- important check

``` powershell
kubectl get pods -n gitops-demo -o custom-columns="POD:.metadata.name,READY:.status.containerStatuses[*].ready,IMAGE:.spec.containers[*].image,IMAGE_ID:.status.containerStatuses[*].imageID"
```

**Purpose:** Shows each pod's configured image, readiness, and actual
pulled image identifier/digest. Confirm the image tag is the expected
one and `READY` is `true`.

For additional details:

``` powershell
kubectl describe pods -n gitops-demo
```

**Purpose:** Shows image, image ID, readiness, container state, and
events, including image-pull failures.

## 11.7 Verify rollout and ReplicaSets

``` powershell
kubectl rollout status deployment/gitops-website -n gitops-demo
kubectl get replicasets -n gitops-demo
kubectl rollout history deployment/gitops-website -n gitops-demo
```

**Purpose:** Confirms rollout completion, shows ReplicaSets, and lists
Deployment rollout revisions.

## 11.8 Verify Service and open the website

``` powershell
kubectl get service gitops-website -n gitops-demo
kubectl get endpointslices -n gitops-demo
kubectl port-forward -n gitops-demo service/gitops-website 8080:80
```

**Purpose:** Checks the Service and backend endpoints, then forwards
local port `8080` to service port `80`. Keep port-forward running and
open `http://localhost:8080`. Stop it with `Ctrl+C`.

## 11.9 Compare policy, Deployment, and pod image

``` powershell
kubectl get imagepolicy gitops-website -n flux-system -o jsonpath="{.status.latestImage}"
Write-Output ""
kubectl get deployment gitops-website -n gitops-demo -o jsonpath="{.spec.template.spec.containers[*].image}"
Write-Output ""
kubectl get pods -n gitops-demo -o custom-columns="POD:.metadata.name,IMAGE:.spec.containers[*].image,IMAGE_ID:.status.containerStatuses[*].imageID"
```

**Purpose:** Compares the selected image, the Deployment's desired
image, and the image reported by the pods. If `.status.latestImage` is
empty in this CRD version, inspect the complete ImagePolicy YAML
instead.

**Healthy result:** The selected eligible tag, Deployment image tag, and
pod image tag agree; pods are Ready; rollout status succeeds; Flux
resources are Ready. `IMAGE_ID` normally includes a digest and is useful
to confirm the image content pulled by the runtime.

# 12. Troubleshooting commands

Start with read-only diagnostics. Do not delete the cluster, Secrets, or
resources as a first step.

## 12.1 Docker or cluster not running

``` powershell
docker info
k3d cluster list
k3d cluster start fluxcd-gitops-lab
kubectl config use-context k3d-fluxcd-gitops-lab
kubectl get nodes
```

**Purpose:** Checks Docker, lists clusters, starts the existing cluster,
selects its context, and checks node readiness.

## 12.2 Flux pods unhealthy

``` powershell
kubectl get pods -n flux-system -o wide
kubectl get events -n flux-system --sort-by=.metadata.creationTimestamp
kubectl describe pod -n flux-system <pod-name>
kubectl logs -n flux-system <pod-name> --all-containers=true --tail=100
```

**Purpose:** Shows controller pod status, events, detailed pod
information, and logs. Replace `<pod-name>` with a real pod name.

## 12.3 Git source not Ready

``` powershell
kubectl get gitrepositories -n flux-system
kubectl describe gitrepository flux-system -n flux-system
kubectl describe gitrepository fluxcd-gitops-writeback -n flux-system
kubectl get events -n flux-system --sort-by=.metadata.creationTimestamp
```

**Purpose:** Diagnoses repository URL, branch, network, authentication,
and Secret-reference problems.

## 12.4 Write-back authentication or push errors

``` powershell
kubectl describe secret github-writeback -n flux-system
kubectl describe gitrepository fluxcd-gitops-writeback -n flux-system
kubectl describe imageupdateautomation gitops-website -n flux-system
kubectl logs deployment/image-automation-controller -n flux-system --since=30m
```

**Purpose:** Checks the Secret metadata, write-back source, automation
status, and controller logs. If a PAT is expired/revoked or lacks
permissions, replace it securely with a least-privilege token and update
the Secret. Never print the token.

## 12.5 New Docker Hub tag not discovered

``` powershell
kubectl describe imagerepository gitops-website -n flux-system
kubectl get imagerepository gitops-website -n flux-system -o yaml
kubectl describe imagepolicy gitops-website -n flux-system
kubectl logs deployment/image-reflector-controller -n flux-system --since=30m
```

**Purpose:** Checks the last scan, discovered tags, policy, and
image-reflector logs. Confirm GitHub Actions pushed the tag to the
correct Docker Hub repository. Check whether the tag satisfies the
semver policy and whether private-registry credentials are required.

## 12.6 Automation Ready but no commit

``` powershell
kubectl describe imageupdateautomation gitops-website -n flux-system
kubectl get imagepolicy gitops-website -n flux-system -o yaml
kubectl get imageupdateautomation gitops-website -n flux-system -o yaml
```

**Purpose:** Checks the selected tag, setter marker, update path, push
status, and whether the repository is already up to date. No commit is
expected if the selected image reference has not changed.

## 12.7 Deployment still uses old image

``` powershell
kubectl get kustomizations -n flux-system
kubectl describe kustomization flux-system -n flux-system
kubectl get deployment gitops-website -n gitops-demo -o yaml
kubectl get replicasets -n gitops-demo
kubectl rollout history deployment/gitops-website -n gitops-demo
```

**Purpose:** Checks whether Flux applied the latest Git revision and
whether Kubernetes created a new ReplicaSet.

Request reconciliation if needed:

``` powershell
flux reconcile source git flux-system -n flux-system
flux reconcile kustomization flux-system -n flux-system
```

**Purpose:** Requests immediate reconciliation of the main Git source
and root Kustomization. Check their status afterward.

## 12.8 ImagePullBackOff or ErrImagePull

``` powershell
kubectl get pods -n gitops-demo
kubectl describe pods -n gitops-demo
kubectl get events -n gitops-demo --sort-by=.metadata.creationTimestamp
```

**Purpose:** Shows pod events and image-pull errors. Check that the
image and tag exist, that the repository is accessible, and that the
cluster can reach Docker Hub. Private images need correctly configured
pull credentials.

## 12.9 CrashLoopBackOff or pod not Ready

``` powershell
kubectl get pods -n gitops-demo -o wide
kubectl describe pod -n gitops-demo <pod-name>
kubectl logs -n gitops-demo <pod-name> --all-containers=true --tail=100
kubectl logs -n gitops-demo <pod-name> --previous --all-containers=true --tail=100
```

**Purpose:** Shows pod state, events, current logs, and
previous-container logs when available. Replace `<pod-name>` with the
actual pod name.

## 12.10 Service or browser access problem

``` powershell
kubectl get service gitops-website -n gitops-demo
kubectl get endpointslices -n gitops-demo
kubectl port-forward -n gitops-demo service/gitops-website 8080:80
```

**Purpose:** Checks Service endpoints and starts local forwarding. Keep
the command running and visit `http://localhost:8080`.

## 12.11 Request image scan and automation reconciliation

``` powershell
flux reconcile source git fluxcd-gitops-writeback -n flux-system
flux reconcile image repository gitops-website -n flux-system
flux reconcile image update gitops-website -n flux-system
```

**Purpose:** Requests immediate checks of the write-back source, image
scan, and image automation. These commands do not guarantee a new tag or
commit; the underlying tag/policy must actually have changed.

## 12.12 Broad health check

``` powershell
flux get all -A
kubectl get events -A --sort-by=.metadata.creationTimestamp
```

**Purpose:** Summarizes Flux resources and recent Kubernetes events. The
all-namespaces events command may produce a large output.

## 13. Final operational notes

-   GitHub stores the desired Kubernetes configuration; Docker Hub
    stores container images.
-   GitHub Actions pushes images to Docker Hub. Flux Image Automation
    pushes image-tag changes to GitHub.
-   ImageRepository discovers tags; ImagePolicy selects a tag;
    ImageUpdateAutomation writes it to Git; Kustomize Controller applies
    the change; Kubernetes performs the rollout.
-   A one-minute interval is not an end-to-end time guarantee.
-   Check the live Deployment image and running pod image separately.
    The `IMAGE_ID` digest helps identify the actual image content.
-   Do not reveal tokens or decode Secret values.
-   Do not rerun bootstrap or delete the cluster for routine
    troubleshooting.

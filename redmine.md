# FluxCD GitOps Lab — Task Documentation for Redmine

## 1. Task Overview

**Task name:** Kubernetes GitOps and Automated Image Updates Using FluxCD

**Objective:** Build a local Kubernetes environment where website changes are delivered through an automated CI/CD and GitOps workflow. GitHub Actions builds and publishes the Docker image, FluxCD detects and selects an eligible image version, updates the image reference in Git, and reconciles the desired configuration with Kubernetes.

The goal is to demonstrate the full path from a developer changing website code to the updated website running in Kubernetes, while keeping the deployment configuration stored in Git.

## 2. Tools and Technologies

- **Git:** Tracks source-code and configuration changes.
- **GitHub:** Hosts the repository and `main` branch.
- **GitHub Actions:** Runs the automated image build-and-push workflow.
- **Docker:** Packages the static website into a container image.
- **Docker Hub:** Stores the published image and version tags.
- **k3d:** Runs a local Kubernetes cluster using Docker.
- **Kubernetes:** Runs the website Pod(s), Deployment, and Service.
- **FluxCD:** Implements GitOps reconciliation and image automation.
- **PowerShell and kubectl:** Used to manage and inspect the local cluster.

## 3. Environment and Project Details

- **GitHub repository:** https://github.com/sarveshhatii/fluxcd-gitops-lab
- **Docker Hub image:** `sarvesh8415/fluxcd-gitops-lab`
- **k3d cluster:** `fluxcd-gitops-lab`
- **Kubernetes context:** `k3d-fluxcd-gitops-lab`
- **Website namespace:** `gitops-demo`
- **Flux namespace:** `flux-system`
- **Deployment:** `gitops-website`
- **Service:** `gitops-website`
- **Local website URL:** `http://localhost:8080` while port-forward is running

The website is a static HTML/CSS site served by NGINX in a container. The cluster is local; this task does not require deploying the website to AWS.

## 4. Architecture

```text
Developer edits website HTML/CSS
              |
              v
       Git commit and push
              |
              v
     GitHub repository (main)
              |
              v
       GitHub Actions workflow
     builds the Docker image
      and pushes version tags
              |
              v
             Docker Hub
              |
              v
  Flux Image Reflector Controller
     ImageRepository scans tags
              |
              v
       ImagePolicy selects
      an eligible semantic version
              |
              v
   ImageUpdateAutomation reads
   the setter marker in the manifest
              |
              v
  Commits updated image reference
       back to GitHub main
              |
              v
      Flux Source Controller
      fetches updated Git state
              |
              v
     Flux Kustomize Controller
       builds and applies YAML
              |
              v
    Kubernetes Deployment updates
        and performs rollout
              |
              v
     Pod runs the new NGINX image
              |
              v
    Service exposes the website
              |
              v
  Browser via kubectl port-forward
       http://localhost:8080
```

### Architecture components

**GitHub repository:** Holds the website source, Docker build configuration, Kubernetes manifests, Flux configuration, and workflow file. Git is the source of truth for the declared desired configuration.

**GitHub Actions:** Runs when a push changes files matched by the workflow's configured branches and paths. It checks out the repository, authenticates to Docker Hub using GitHub Secrets, builds the image, and pushes tags. The workflow's build context and path filters must match the website files being edited.

**Docker Hub:** Stores the built container image. The version tag identifies the release selected for deployment; `latest` may also be pushed but does not have to be the tag selected by the ImagePolicy.

**Flux ImageRepository:** Configures Flux image automation to scan `sarvesh8415/fluxcd-gitops-lab` for available tags.

**Flux ImagePolicy:** Chooses a tag from the discovered tags according to the configured semantic-version range. In this lab, the configured policy is `>=1.0.0 <2.0.0`, so eligible versions in the 1.x series can be selected.

**Image setter marker:** The Deployment image line contains a comment similar to `# {"$imagepolicy": "flux-system:gitops-website"}`. Kubernetes ignores this YAML comment, while Flux image automation uses it to identify which image field is associated with the policy.

**ImageUpdateAutomation:** Uses the writeback GitRepository and configured credentials to update the marked image field under its configured update path and push the change to the Git branch. The update path must match the actual location of the Deployment manifest.

**GitRepository (`flux-system`):** Fetches the primary repository branch for the cluster configuration. The `gotk-sync.yaml` resource defines this source and the root Flux Kustomization.

**GitRepository (`fluxcd-gitops-writeback`):** Provides the repository source and credentials used by the image-update automation to write changes back to GitHub.

**Flux Kustomize Controller:** Reads the configured repository path and applies the resources included by the relevant Kustomize configuration. The root path is configured as `./clusters/fluxcd-gitops-lab`; files must be included by the relevant `kustomization.yaml` resource lists to be applied.

**Kubernetes Deployment:** Declares the desired Pod count, container image, ports, probes, and resource requests/limits. When the Pod template changes, Kubernetes creates a new ReplicaSet and rolls out replacement Pods according to the Deployment strategy.

**Kubernetes Service:** Selects Pods using labels and exposes the website on port 80 inside the cluster. `kubectl port-forward` provides temporary local access on port 8080.

## 5. Repository Structure

The project contains these key areas (verify exact paths against the current repository if files have been moved):

```text
fluxcd-repo/
├── .github/
│   └── workflows/
│       └── docker-build-push.yml
├── apps/
│   └── website/
│       ├── namespace.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       └── kustomization.yaml
├── clusters/
│   └── fluxcd-gitops-lab/
│       ├── flux-system/
│       │   ├── gotk-components.yaml
│       │   ├── gotk-sync.yaml
│       │   └── kustomization.yaml
│       ├── website/
│       │   ├── index.html
│       │   └── style.css
│       ├── Dockerfile
│       ├── gitrepository-writeback.yaml
│       ├── image-repository.yaml
│       ├── image-policy.yaml
│       └── image-update-automation.yaml
└── commands.md
```

Some website and automation files have appeared at more than one path during development. The CI workflow build context, the Kustomize resource lists, and the ImageUpdateAutomation update path must all point to the intended files. Do not assume similarly named directories are interchangeable.

### Main files

- **`docker-build-push.yml`:** Defines when the GitHub Actions pipeline runs and how it builds and publishes the Docker image.
- **`Dockerfile`:** Uses NGINX as the base image and copies the static website files into NGINX's web root.
- **`index.html` and `style.css`:** Define the website content and appearance.
- **`namespace.yaml`:** Defines the `gitops-demo` namespace.
- **`deployment.yaml`:** Defines the website container, selected image tag, port, health probes, and resource requests/limits.
- **`service.yaml`:** Exposes the selected website Pods within the cluster.
- **`kustomization.yaml`:** Lists the resources Kustomize should build and apply.
- **`gotk-components.yaml`:** Contains Flux controller installation resources.
- **`gotk-sync.yaml`:** Defines the primary Git source and root Flux Kustomization.
- **`image-repository.yaml`:** Configures scanning of Docker Hub image tags.
- **`image-policy.yaml`:** Selects the eligible image version.
- **`gitrepository-writeback.yaml`:** Defines the Git source used by image automation for writeback.
- **`image-update-automation.yaml`:** Configures automated updates of the marked image field and Git push.
- **`commands.md`:** Documents setup, validation, and troubleshooting commands.

## 6. End-to-End Execution Workflow

### Step 1 — Change the website

Edit the website HTML or CSS file that is actually used by the Docker build. Save the change and use a visible text change during the demonstration.

### Step 2 — Commit and push

```powershell
git add .
git commit -m "Update website for GitOps demo"
git pull --rebase origin main
git push origin main
```

`git pull --rebase origin main` integrates remote commits before pushing. This is useful because Flux image automation may push its own commit to `main`. If a conflict occurs, resolve it before pushing. Avoid force-pushing over remote history.

### Step 3 — GitHub Actions builds the image

Open the repository's Actions tab and confirm the workflow run succeeded. The workflow builds the website image and pushes the configured version tag(s) to Docker Hub. If the workflow does not run, check its branch and path filters and confirm the changed files are in the configured build context.

### Step 4 — Flux scans and selects the image

ImageRepository scans Docker Hub at its configured interval. ImagePolicy selects the highest eligible tag under its semantic-version policy. Reconciliation intervals are polling settings, not guarantees that the whole process completes in exactly one minute.

### Step 5 — Flux writes the image tag to Git

ImageUpdateAutomation uses the setter marker in the Deployment manifest to identify the image field. It updates the tag in the configured update path and pushes a commit to GitHub using the writeback GitRepository and Secret.

### Step 6 — Flux applies the desired configuration

The primary GitRepository fetches the updated source. The root Flux Kustomization reconciles `./clusters/fluxcd-gitops-lab`. Kustomize builds and applies the resources that are included in the relevant Kustomize files.

### Step 7 — Kubernetes rolls out the image

When the Deployment Pod template changes, Kubernetes creates replacement Pod(s) using the new image. Readiness and liveness probes check the application according to their configured settings. Resource requests and limits govern scheduling and container resource use.

### Step 8 — Verify the deployment and website

Check the Deployment image, Pod image and runtime image ID, rollout status, and website content. If using port-forward, keep the terminal open. The session may disconnect when the selected Pod is replaced; after the rollout completes, start port-forward again if needed.

## 7. Verification Commands

Check the active Kubernetes context:

```powershell
kubectl config current-context
```

Check Flux controller Pods:

```powershell
kubectl get pods -n flux-system
```

Check the main Git source and root Kustomization:

```powershell
kubectl get gitrepository flux-system -n flux-system
kubectl get kustomization flux-system -n flux-system
```

Check image scanning and policy:

```powershell
kubectl get imagerepository gitops-website -n flux-system
kubectl get imagepolicy gitops-website -n flux-system
```

Check image automation:

```powershell
kubectl get gitrepository fluxcd-gitops-writeback -n flux-system
kubectl get imageupdateautomation gitops-website -n flux-system
```

Show the image configured in the Deployment:

```powershell
kubectl get deployment gitops-website -n gitops-demo -o jsonpath="{.spec.template.spec.containers[*].image}"
```

Show Pod names, image references, and runtime image IDs:

```powershell
kubectl get pods -n gitops-demo -o custom-columns="POD:.metadata.name,IMAGE:.spec.containers[*].image,IMAGE_ID:.status.containerStatuses[*].imageID"
```

 
```

Forward the Service to local port 8080:

```powershell
kubectl port-forward -n gitops-demo service/gitops-website 8080:80
```

Open `http://localhost:8080` while port-forward is running.

 

## 9. Troubleshooting Notes

- **Git push rejected (`fetch first`):** Run `git pull --rebase origin main`, resolve conflicts if any, then push.
- **GitHub Actions did not run:** Check the workflow trigger branch and paths, the changed file location, and GitHub Actions logs.
- **Image did not update:** Check that the image was pushed, the tag matches the ImagePolicy range, ImageRepository and ImagePolicy are Ready, and the setter marker and update path are correct.
- **Automation cannot push to GitHub:** Check the writeback GitRepository and Secret reference, repository permissions, and ImageUpdateAutomation status. Never print or commit token contents.
- **Deployment has an old image:** Check Flux Kustomization status, the applied Git revision, the image reference in Git, and the automation update path.
- **Pod is not ready:** Use `kubectl describe pod <pod-name> -n gitops-demo` and inspect events and logs.
- **Port-forward disconnects:** This can happen when the selected Pod is replaced during rollout. Check `kubectl rollout status`, then rerun port-forward. It does not by itself prove the deployment failed.

## 10. Expected Outcome

A website source-code change pushed to GitHub triggers an image build and publication. Flux discovers the eligible image version, updates the image reference in Git, and reconciles the declared Kubernetes configuration. Kubernetes then rolls out the new container image, and the updated website can be verified in the browser. This demonstrates automated image delivery and GitOps-based deployment management on a local Kubernetes cluster.

## Security Notes

- Store Docker Hub credentials and GitHub writeback credentials in GitHub Secrets or Kubernetes Secrets as appropriate.
- Never commit personal access tokens, private keys, or decoded Secret values.
- Avoid `git push --force` on the shared `main` branch.

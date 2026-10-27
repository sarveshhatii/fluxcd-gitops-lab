# FluxCD + GitOps Lab — Commands in Proper Order

## 1. Open the project folder

```powershell
Set-Location "C:\Users\patil\Desktop\Devops intern Task\fluxcd-gitops-lab\fluxcd-repo"
```
What it does: Opens the project repository in PowerShell.

## 2. Verify pre-installation requirements

```powershell
docker --version
docker info
kubectl version --client
k3d version
flux version
git --version
```
What it does: Checks that Docker, kubectl, k3d, Flux CLI, and Git are installed. `docker info` verifies that Docker Desktop's engine is running.

## 3. Verify and start the Kubernetes cluster

```powershell
k3d cluster list
k3d cluster start fluxcd-gitops-lab
kubectl config use-context k3d-fluxcd-gitops-lab
kubectl config current-context
kubectl get nodes -o wide
```
What it does: Lists clusters, starts this task's existing cluster, selects the correct Kubernetes context, and verifies the nodes.

If the cluster does not exist and you intentionally need to create it, run this once:

```powershell
k3d cluster create fluxcd-gitops-lab --servers 1 --agents 1
```
What it does: Creates a fresh local Kubernetes cluster with one server and one agent.

## 4. Bootstrap / install FluxCD

```powershell
flux bootstrap github `
  --owner=sarveshhatii `
  --repository=fluxcd-gitops-lab `
  --branch=main `
  --path=clusters/fluxcd-gitops-lab `
  --personal
```
What it does: Installs Flux controllers into the selected cluster and configures synchronization with the GitHub repository and specified path.

**Important:** Run bootstrap only for initial setup or intentional reconfiguration. Do not rerun it just to verify an existing working installation. GitHub authentication must be configured.

## 5. Verify Flux installation

```powershell
flux check
kubectl get pods -n flux-system
flux get all -A
```
What it does: Checks Flux prerequisites, lists Flux controller Pods, and shows the status of Flux resources.

## 6. Verify GitHub repository and local branch

```powershell
git status
git remote -v
git branch --show-current
```
What it does: Shows local changes, confirms the GitHub remote URL, and checks the current branch.

## 7. Update the website and push to GitHub

After editing the website files, run:

```powershell
git status
git add .
git commit -m "Update website"
git pull --rebase origin main
git push origin main
```
What it does:
- `git status` shows changed files.
- `git add .` stages changes.
- `git commit` saves them locally.
- `git pull --rebase origin main` brings in remote commits before pushing, including possible Flux image-update commits.
- `git push origin main` pushes the changes to GitHub.

If Git reports there is nothing to commit, no new commit is created. Review `git status` and stage only the files you intended to change when appropriate.

## 8. Verify GitHub Actions and Docker Hub image

What to do: Open the repository's **Actions** tab on GitHub and confirm the Docker build-and-push workflow succeeded. Then check Docker Hub to confirm the new version tag exists.

What it means: GitHub Actions builds the website container image and pushes it to `sarvesh8415/fluxcd-gitops-lab`, using the tags configured in the workflow.

## 9. Verify Flux image scanning and policy

```powershell
kubectl describe imagerepository gitops-website -n flux-system
kubectl describe imagepolicy gitops-website -n flux-system
```
What it does: Shows whether Flux can scan the Docker Hub repository, which tags were found, and which eligible version tag the policy selected.

## 10. Verify Flux image automation and Git write-back

```powershell
kubectl describe gitrepository fluxcd-gitops-writeback -n flux-system
kubectl describe imageupdateautomation gitops-website -n flux-system
```
What it does: Checks the GitHub source used for write-back and whether ImageUpdateAutomation updated the Deployment YAML and pushed a commit to GitHub.

## 11. Verify Flux has applied the latest Git configuration

```powershell
kubectl get gitrepositories -n flux-system
kubectl get kustomizations -n flux-system
flux get all -A
```
What it does: Checks Git source and Kustomization readiness and helps confirm that Flux has applied the latest configuration from Git.

To request immediate reconciliation if needed:

```powershell
flux reconcile source git flux-system -n flux-system
flux reconcile kustomization flux-system -n flux-system
```
What it does: Asks Flux to refresh the main Git source and re-apply the Kubernetes configuration.

## 12. Verify the Deployment's desired image

```powershell
kubectl get deployment gitops-website -n gitops-demo -o jsonpath="{.spec.template.spec.containers[*].image}"
Write-Output ""
```
What it does: Prints the image reference currently specified in the Deployment's Pod template. This is the desired image, not by itself proof that a Pod is running it.

## 13. Verify rollout and Pods have the new image

```powershell
kubectl rollout status deployment/gitops-website -n gitops-demo
kubectl get pods -n gitops-demo -o custom-columns="POD:.metadata.name,READY:.status.containerStatuses[*].ready,IMAGE:.spec.containers[*].image,IMAGE_ID:.status.containerStatuses[*].imageID"
```
What it does:
- `kubectl rollout status` checks whether the Deployment rollout has completed.
- The Pod command shows each Pod's readiness, configured image tag, and actual image ID/digest reported by the container runtime.

Confirm the `IMAGE` tag is the expected new version and `READY` is `true`. The `IMAGE_ID` digest helps identify the image content pulled by the runtime.

For more details if a Pod is not ready:

```powershell
kubectl describe pods -n gitops-demo
kubectl get events -n gitops-demo --sort-by=.metadata.creationTimestamp
```
What it does: Shows Pod events and recent Kubernetes events to help diagnose rollout or image-pull problems.

## 14. Open and verify the updated website

```powershell
kubectl get service gitops-website -n gitops-demo
kubectl port-forward -n gitops-demo service/gitops-website 8080:80
```
What it does: Checks the Service and forwards local port 8080 to the website's Service port 80. Keep this command running and open `http://localhost:8080` in your browser. Stop port-forward with `Ctrl+C`.
 
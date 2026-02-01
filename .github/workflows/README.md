# GitHub Actions Workflows

This directory contains GitHub Actions workflows for automating various tasks in this repository.

## Docker Build Workflow

**File**: `docker-build.yml`

### Purpose
Automatically builds and pushes Docker images to Docker Hub when code changes are made to the repository.

### Triggers
The workflow runs on the following events:
- **Push to `main` branch**: Builds and pushes image with `latest` tag and branch name tag
- **Pushes of version tags** (e.g., `v1.0.62`, `v1.1.0`): Builds and pushes image with semantic version tags
- **Pull Requests**: Builds the image to test (but does NOT push to Docker Hub)
- **Manual trigger**: Can be triggered manually via GitHub Actions UI

### Features
- **Multi-platform builds**: Supports both `linux/amd64` and `linux/arm64` architectures
- **Automatic tagging**: 
  - For tags: Creates semantic version tags (e.g., `v1.0.62`, `1.0`, `1`)
  - For main branch: Creates `latest` tag
  - For commits: Creates SHA-based tags
- **Docker layer caching**: Uses GitHub Actions cache to speed up builds
- **Metadata labels**: Adds OCI-compliant labels to images

### Required Secrets

Before the workflow can push images to Docker Hub, you need to configure the following repository secrets:

1. **`DOCKER_USERNAME`**: Your Docker Hub username
2. **`DOCKER_PASSWORD`**: Your Docker Hub Personal Access Token (PAT) - **NOT** your password

**IMPORTANT**: `DOCKER_PASSWORD` must be a Personal Access Token (starting with `dckr_pat_`), not your actual Docker Hub password. Docker Hub no longer accepts passwords for authentication.

#### How to Configure Secrets

1. Go to your GitHub repository
2. Click on **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add both secrets:
   - Name: `DOCKER_USERNAME`, Value: Your Docker Hub username (must match exactly)
   - Name: `DOCKER_PASSWORD`, Value: Your Docker Hub Personal Access Token (PAT)

**How to create a Docker Hub Personal Access Token**:
1. Log in to Docker Hub at https://hub.docker.com
2. Go to **Account Settings** → **Security**: https://hub.docker.com/settings/security
3. Click **"New Access Token"**
4. Give it a description (e.g., "GitHub Actions")
5. Select **"Read & Write"** permissions (required for pushing images)
6. Click **"Generate"**
7. **Copy the entire token immediately** - you won't be able to see it again!
8. The token will start with `dckr_pat_` followed by a long random string

**Note**: The Docker image will be pushed to `<your-username>/puppy-stardew-server`, where `<your-username>` is the value from your `DOCKER_USERNAME` secret.

### Usage Examples

#### Automatic Build on Push
```bash
# Push to main branch - triggers build with 'latest' tag
git push origin main

# Push a version tag - triggers build with semantic version tags
git tag v1.0.62
git push origin v1.0.62
```

#### Manual Trigger
1. Go to **Actions** tab in GitHub
2. Select **Build and Push Docker Image** workflow
3. Click **Run workflow**
4. Select the branch and click **Run workflow** button

### Image Tags

The workflow creates the following tags:

| Event | Tags Created |
|-------|-------------|
| Push to `main` | `latest`, `main`, `main-{sha}` |
| Tag `v1.0.62` | `v1.0.62`, `1.0.62`, `1.0`, `1` |
| Pull Request #123 | `pr-123` (not pushed to Docker Hub) |

### Workflow Output

After a successful build, you can find:
- Built image at: `truemanlive/puppy-stardew-server:<tag>`
- Build logs in the Actions tab
- Image digest in the workflow summary

### Troubleshooting

#### Build Fails with "unauthorized" error
- **Most common cause**: Your `DOCKER_USERNAME` in GitHub secrets doesn't match your actual Docker Hub username
  - Make sure `DOCKER_USERNAME` is spelled exactly as it appears on Docker Hub (case-sensitive)
  - The workflow pushes images to `<DOCKER_USERNAME>/puppy-stardew-server`
  - You can only push to repositories under your own Docker Hub account
- **Second most common cause**: Using password instead of Personal Access Token
  - `DOCKER_PASSWORD` must be a Personal Access Token (starting with `dckr_pat_`)
  - Create a new PAT at https://hub.docker.com/settings/security
  - Select "Read & Write" permissions when creating the token
- **Other causes**:
  - PAT has expired or been revoked - create a new one
  - PAT doesn't have write permissions - create a new one with "Read & Write"
  - Extra whitespace in the secret values - re-enter them carefully

#### Build Fails with "context" or "Dockerfile not found" error
- Ensure the Dockerfile exists at `docker/Dockerfile`
- Verify the repository structure matches the expected layout

#### Multi-platform build takes too long
- This is normal for multi-platform builds
- GitHub Actions runners emulate ARM64 using QEMU, which can be slow
- Consider removing `linux/arm64` from `PLATFORMS` if you don't need ARM support

### Customization

You can customize the workflow by editing `.github/workflows/docker-build.yml`:

- **Change platforms**: Modify the `PLATFORMS` environment variable
- **Change image name**: Modify the `DOCKER_IMAGE` environment variable
- **Add more triggers**: Add additional events in the `on:` section
- **Modify tags**: Adjust the tag patterns in the `Extract metadata` step

## Future Workflows

Additional workflows can be added to this directory for:
- Running tests
- Code linting
- Automated releases
- Documentation deployment

---

For more information about GitHub Actions, see the [official documentation](https://docs.github.com/en/actions).

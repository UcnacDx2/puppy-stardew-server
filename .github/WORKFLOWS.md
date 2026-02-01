# GitHub Actions Workflow

## Docker Build and Push to GHCR

This workflow automatically builds the Docker image and pushes it to GitHub Container Registry (GHCR).

### Triggers

The workflow runs on:

1. **Push to main branch** - Builds and pushes image with `latest` tag
2. **New version tags** (v*.*.*) - Builds and pushes image with version tags
3. **Pull requests to main** - Builds image (without pushing) for validation
4. **Manual trigger** - Can be manually triggered from GitHub Actions UI

### Image Tags

The workflow creates multiple tags for flexibility:

- `latest` - Latest build from main branch
- `v1.2.3` - Full semantic version (when pushing a tag)
- `v1.2` - Major.minor version
- `v1` - Major version
- `sha-<commit>` - Specific commit SHA
- `main` - Branch name (for main branch)

### Usage

#### Automatic Builds

The workflow runs automatically when you:
1. Push code to the main branch
2. Create a new version tag (e.g., `git tag v1.0.62 && git push origin v1.0.62`)

#### Manual Trigger

You can also trigger the workflow manually:
1. Go to the repository on GitHub
2. Navigate to "Actions" tab
3. Select "Build and Push Docker Image to GHCR"
4. Click "Run workflow"

### Using the Image

After the workflow completes, the image will be available at:

```
ghcr.io/ucnacdx2/puppy-stardew-server:latest
```

Update your `docker-compose.yml` to use the GHCR image:

```yaml
services:
  stardew-server:
    image: ghcr.io/ucnacdx2/puppy-stardew-server:latest
    # ... rest of configuration
```

Or use a specific version:

```yaml
services:
  stardew-server:
    image: ghcr.io/ucnacdx2/puppy-stardew-server:v1.0.62
    # ... rest of configuration
```

### Image Visibility

By default, GitHub Container Registry images are private. To make the image public:

1. Go to the repository's package settings
2. Navigate to Package settings for `puppy-stardew-server`
3. Change visibility to "Public"

### Permissions

The workflow uses `GITHUB_TOKEN` which is automatically provided by GitHub Actions. No additional secrets are required.

Required permissions:
- `contents: read` - To checkout the repository
- `packages: write` - To push to GitHub Container Registry

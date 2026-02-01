# Setting Up Docker Hub Secrets for GitHub Actions

## Problem

If you're seeing this error in GitHub Actions:
```
Error response from daemon: Get "https://registry-1.docker.io/v2/": unauthorized: incorrect username or password
```

This means your Docker Hub credentials are not correctly configured as GitHub secrets.

## Root Cause

The `docker-build.yml` workflow requires two GitHub secrets to authenticate with Docker Hub:
- `DOCKER_USERNAME`: Your Docker Hub username
- `DOCKER_PASSWORD`: Your Docker Hub **Personal Access Token** (NOT your password)

**CRITICAL**: Docker Hub no longer accepts regular passwords for authentication via API/CLI. You MUST use a Personal Access Token (PAT).

## Solution

### Step 1: Create a Docker Hub Personal Access Token

1. Log in to Docker Hub at https://hub.docker.com
2. Go to **Account Settings** → **Security**: https://hub.docker.com/settings/security
3. Click **"New Access Token"**
4. Fill in the details:
   - **Description**: `GitHub Actions - puppy-stardew-server` (or any meaningful name)
   - **Access permissions**: Select **"Read & Write"** (required for pushing images)
5. Click **"Generate"**
6. **IMPORTANT**: Copy the entire token immediately - you won't be able to see it again!
   - The token will start with `dckr_pat_` followed by a long random string
   - Example: `dckr_pat_1234567890abcdefghijklmnopqrstuvwxyz`

### Step 2: Configure GitHub Repository Secrets

1. Go to your GitHub repository: https://github.com/UcnacDx2/puppy-stardew-server
2. Click on **Settings** (in the repository, not your account)
3. In the left sidebar, click **Secrets and variables** → **Actions**
4. Add or update the following secrets:

   **Secret 1: DOCKER_USERNAME**
   - Click **"New repository secret"** (or "Update" if it exists)
   - Name: `DOCKER_USERNAME`
   - Value: Your Docker Hub username (must match exactly, case-sensitive)
   - Click **"Add secret"** or **"Update secret"**

   **Secret 2: DOCKER_PASSWORD**
   - Click **"New repository secret"** (or "Update" if it exists)
   - Name: `DOCKER_PASSWORD`
   - Value: The Personal Access Token you just created (starts with `dckr_pat_`)
   - Click **"Add secret"** or **"Update secret"**

### Step 3: Verify the Configuration

After setting up the secrets, you can verify they work by:

1. Going to the **Actions** tab in your repository
2. Selecting the **"Build and Push Docker Image"** workflow
3. Clicking **"Run workflow"** → **"Run workflow"** button
4. Wait for the workflow to complete - it should now succeed

## Common Mistakes

❌ **Using your Docker Hub password instead of a Personal Access Token**
   - Docker Hub requires PATs for authentication, not passwords

❌ **Username doesn't match your Docker Hub account**
   - The username must be exactly as shown on Docker Hub (case-sensitive)
   - The workflow pushes to `<DOCKER_USERNAME>/puppy-stardew-server`
   - You can only push to your own Docker Hub account

❌ **Personal Access Token has wrong permissions**
   - Make sure to select "Read & Write" when creating the token
   - "Read-only" tokens cannot push images

❌ **Extra whitespace in secret values**
   - Make sure there are no leading/trailing spaces when pasting the values

❌ **Token has expired or been revoked**
   - Personal Access Tokens can be set to expire
   - If expired, create a new one and update the secret

## Testing Locally

You can test your Docker Hub credentials locally before configuring GitHub secrets:

```bash
# Test with your username and Personal Access Token
echo "YOUR_PERSONAL_ACCESS_TOKEN" | docker login -u "YOUR_DOCKER_HUB_USERNAME" --password-stdin

# If successful, you'll see:
# Login Succeeded

# If failed, you'll see:
# Error response from daemon: Get "https://registry-1.docker.io/v2/": unauthorized: incorrect username or password
```

**Note**: Replace `YOUR_DOCKER_HUB_USERNAME` with your actual Docker Hub username and `YOUR_PERSONAL_ACCESS_TOKEN` with the token you created.

## Additional Notes

- The Docker image will be pushed to: `<your-username>/puppy-stardew-server`
- If you want to push to a different repository, you need to:
  1. Have write access to that repository on Docker Hub
  2. Update the `DOCKER_IMAGE` environment variable in `.github/workflows/docker-build.yml`
- For security, never commit your Personal Access Token to the repository
- Store tokens securely (e.g., in a password manager)
- You can revoke and regenerate tokens at any time from Docker Hub

## Need Help?

If you continue to have issues:
1. Double-check that both secrets are set correctly in GitHub
2. Verify your Docker Hub credentials work locally using the test command above
3. Check that your Personal Access Token hasn't expired
4. Make sure you have write access to the Docker Hub repository

For more information, see:
- [GitHub Actions Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Docker Hub Personal Access Tokens](https://docs.docker.com/docker-hub/access-tokens/)

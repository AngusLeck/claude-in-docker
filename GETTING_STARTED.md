# Getting Started: Running Claude "Dangerously, Yet Safely"

This guide walks you through the complete setup to run Claude AI with full development capabilities while keeping your host system completely safe.

## What Does "Dangerously, Yet Safely" Mean?

**Dangerous**: Claude has full access to development tools, can install packages, run scripts, modify code, access networks, and perform any development task you'd normally do.

**Yet Safely**: All of this happens inside a Docker container that can't touch your host system. Claude can only:
- Access repos you explicitly clone into the container
- Make changes that go through proper git/GitHub workflow
- Work within the isolated container environment

## Prerequisites

Before starting, ensure you have:

### 1. Nix with Flakes
```bash
# Check if Nix is installed
nix --version

# If not installed, install Nix (macOS/Linux)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Enable flakes (if not already enabled)
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### 2. Docker and Docker Compose
```bash
# Check if Docker is running
docker --version
docker-compose --version

# If not installed:
# macOS: Install Docker Desktop from https://docker.com
# Linux: Follow your distribution's Docker installation guide
```

### 3. Required Credentials

You'll need:
- **GitHub Personal Access Token** with repo access
- **Claude API Key** from your Anthropic account

## Step-by-Step Setup

### Step 1: Clone and Prepare

```bash
# Navigate to where you want the framework
cd ~/ailo  # or wherever you prefer

# The framework should already be in claude-in-docker/
cd claude-in-docker

# Make scripts executable
chmod +x *.sh
```

### Step 2: Get Your Credentials

#### GitHub Token:
1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Give it a name like "Claude Development"
4. Select scopes: `repo`, `read:org`, `user:email`
5. Click "Generate token"
6. **Copy the token** - you can't see it again!

#### Claude API Key:
1. Go to https://console.anthropic.com/
2. Navigate to "API Keys"
3. Click "Create Key"
4. Give it a name like "Claude Docker Development"
5. **Copy the key**

### Step 3: Configure Environment

```bash
# Create environment file from template
cp .env.example .env

# Edit the .env file with your credentials
nano .env  # or use your preferred editor
```

Fill in your `.env` file:
```bash
# GitHub Personal Access Token
GITHUB_TOKEN=ghp_your_github_token_here

# Claude API Key  
CLAUDE_API_KEY=your_claude_api_key_here
```

### Step 4: Run Setup

```bash
# This will:
# 1. Check that Nix and flakes are working
# 2. Set up git configuration
# 3. Build the Docker image with Nix
# 4. Start the container
./setup.sh
```

**You'll be prompted for:**
- Your git username (e.g., "John Doe")
- Your git email (e.g., "john@example.com")

**Expected output:**
```
🐳 Setting up Claude-in-Docker environment with Nix...
📝 Setting up git configuration...
Enter your Git username: [your name]
Enter your Git email: [your email]
🏗️  Building Claude development environment with Nix...
📦 Loading image into Docker...
🚀 Starting Claude development environment...
✅ Claude-in-Docker is ready!
```

### Step 5: Enter the Safe Environment

```bash
# Enter the containerized development environment
./enter.sh
```

You should see something like:
```
🔗 Entering Claude development environment...
💡 Available commands:
  setup_repo <repo-name> - Clone and enter a repository
  claude                 - Start Claude CLI
  gh auth login          - Authenticate with GitHub (first time only)

root@container:/workspace# 
```

### Step 6: First-Time GitHub Authentication

Inside the container:
```bash
# Authenticate with GitHub (one time only)
gh auth login

# Select: GitHub.com
# Select: HTTPS  
# Paste your token when prompted
# Select: Yes to git protocol
```

### Step 7: Clone Your First Repository

```bash
# Clone one of your repos (replace with actual repo name)
setup_repo customer-service

# This will:
# 1. Create /workspace/repos/ directory (if it doesn't exist)
# 2. Clone the repo to /workspace/repos/customer-service
# 3. cd into the directory  
# 4. Set it up for development
```

### Step 8: Start Claude

```bash
# Start Claude CLI in dangerous mode
claude

# You should see Claude start up and be ready for commands
```

## Using Claude Safely

### What Claude Can Do (Inside Container):
- ✅ Clone and modify any GitHub repo you specify
- ✅ Install npm/pip packages 
- ✅ Run build commands, tests, linters
- ✅ Create branches, commit, push to GitHub
- ✅ Access internet for documentation/APIs
- ✅ Run Docker commands (if needed)
- ✅ Perform any development task

### What Claude Cannot Do (Host Protection):
- ❌ Access your host filesystem
- ❌ Modify files outside the container
- ❌ Access your personal credentials outside the container
- ❌ Affect your host system configuration
- ❌ Access other running applications on your host

### Safe Development Workflow:

1. **Work in Container**: All Claude operations happen inside
2. **Git Workflow**: Changes go through proper git commits/pushes  
3. **GitHub Integration**: Use PRs for code review before merging
4. **Isolated Environment**: Container can be destroyed without data loss
5. **Persistent Workspace**: Your repos and work persist between sessions

## Daily Usage

### Starting Work:
```bash
./enter.sh                    # Enter container
setup_repo my-project         # If first time with this repo
cd repos/my-project           # If repo already exists
claude                        # Start Claude
```

### Ending Work:
```bash
exit                          # Exit Claude
exit                          # Exit container
./stop.sh                     # Stop container (optional)
```

### Resuming Later:
```bash
./enter.sh                    # Container restarts automatically
cd repos/my-project           # Your work is still there
claude                        # Continue where you left off
```

## Troubleshooting

### Container Won't Start:
```bash
# Check Docker is running
docker ps

# Check if image exists
docker images | grep claude-dev

# Rebuild if needed
nix run .#build-docker
docker-compose up -d
```

### Nix Build Issues:
```bash
# Check Nix installation
nix --version

# Check flakes are enabled
nix flake check

# Clean and rebuild
nix store gc
nix run .#build-docker
```

### GitHub Authentication:
```bash
# Inside container, check auth status
gh auth status

# Re-authenticate if needed
gh auth logout
gh auth login
```

### Lost Work:
Don't worry! Your work persists in Docker volumes:
```bash
# List volumes
docker volume ls | grep claude

# Your workspace survives container restarts
./enter.sh
ls /workspace  # Your repos are still there
```

## Advanced Usage

### Adding Tools:
Edit `flake.nix` to add packages:
```nix
buildInputs = with pkgs; [
  # existing tools...
  ripgrep    # Add new tool
  terraform  # Add another
];
```

Then rebuild:
```bash
nix run .#build-docker
docker-compose up -d
```

### Testing Locally:
```bash
# Test environment without Docker
nix develop
```

### Custom Configuration:
- Edit `docker-compose.yml` for container settings
- Edit `flake.nix` for environment packages
- Add scripts to `/credentials/` for custom setup

## Emergency Procedures

### Complete Reset:
```bash
# Stop everything
./stop.sh

# Remove container and volumes (DESTROYS WORKSPACE)
docker-compose down -v
docker rmi claude-dev:latest

# Start fresh
./setup.sh
```

### Backup Workspace:
```bash
# Create backup of workspace
docker run --rm -v claude_workspace:/backup -v $(pwd):/host alpine tar czf /host/workspace-backup.tar.gz -C /backup .

# Restore backup
docker run --rm -v claude_workspace:/restore -v $(pwd):/host alpine tar xzf /host/workspace-backup.tar.gz -C /restore
```

You're now ready to run Claude with full development capabilities while keeping your host system completely safe! 🎉
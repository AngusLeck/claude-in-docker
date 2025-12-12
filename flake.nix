{
  description = "Claude-in-Docker: Safe AI development environment with Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Native packages for the host system (development shell)
        pkgsNative = nixpkgs.legacyPackages.${system};
        
        # Linux packages for Docker container - based on customer-service pattern
        pkgsLinux = import nixpkgs {
          system = "aarch64-linux";
          config = {
            allowUnfree = true;
          };
        };
        
        # Development environment with all tools for Docker container
        devEnv = pkgsLinux.buildEnv {
          name = "claude-dev-env";
          paths = with pkgsLinux; [
            # Essential tools
            bash
            coreutils
            curl
            wget
            git
            vim
            nano
            jq
            unzip
            
            # Development tools  
            nodejs_20
            yarn
            python3
            python311Packages.pip
            python311Packages.setuptools
            
            # GitHub and Docker tools
            gh
            docker
            docker-compose
            
            # Additional utilities
            fzf
            direnv
            awscli2
            kubectl
            yq
          ];
        };

        # Local development shell (for managing the Ubuntu Docker environment)
        devShell = pkgsNative.mkShell {
          name = "claude-dev-shell";
          buildInputs = with pkgsNative; [
            # Essential tools for managing the environment
            bash
            docker
            gh
            git
          ];
          
          shellHook = ''
            echo "🔧 Claude Development Environment Manager"
            echo "📦 Ubuntu-based Docker approach (works reliably on Apple Silicon)"
            echo "🏗️  Build & start: nix run .#build-docker"
            echo "📦 Manual build: docker build --platform linux/arm64 -t claude-dev-ubuntu ."
            echo "🚀 Start: docker-compose up -d"
            echo "🚪 Enter: docker exec -it claude-dev-env bash"
          '';
        };

      in {
        # For local development/testing
        devShells.default = devShell;
        
        # Apps for convenience
        apps = {
          # Build and start the Ubuntu-based docker environment
          build-docker = {
            type = "app";
            program = toString (pkgsNative.writeScript "build-docker" ''
              #!${pkgsNative.bash}/bin/bash
              echo "🏗️  Building Claude Docker image with Ubuntu..."
              docker build --platform linux/arm64 -t claude-dev-ubuntu .
              echo "📦 Starting the development environment..."
              docker-compose up -d
              echo "✅ Claude Docker environment ready!"
              echo "🚀 Enter with: docker exec -it claude-dev-env bash"
              echo "🛠️  Or use: ./enter.sh"
            '');
          };
        };
      }
    );
}
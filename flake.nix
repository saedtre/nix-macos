{
  description = "Development nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    vllm-metal = {
      url = "github:vllm-project/vllm-metal";
      flake = false;
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, home-manager, vllm-metal }:
    let
      configuration = { pkgs, config, ... }: {
        # List packages installed in system profile. To search by name, run:
        # $ nix-env -qaP | grep wget
        system.primaryUser = "sam";
        nixpkgs.config.allowUnfree = true;
        # semgrep pins pyjwt~=2.13.0 but nixpkgs ships 2.14.0; relax the check.
        nixpkgs.overlays = [
          (final: prev: {
            pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
              (pyfinal: pyprev: {
                semgrep = pyprev.semgrep.overridePythonAttrs (old: {
                  pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "pyjwt" ];
                });
              })
            ];
          })
        ];
        nix.enable = false;
        environment.systemPackages =
          [ pkgs.neovim
            pkgs.autoconf
            pkgs.mkalias
            pkgs.obsidian
            pkgs.zed-editor
            pkgs.go
            pkgs.gopls
            pkgs.pinentry_mac
            pkgs.tree-sitter
            pkgs.ripgrep
            pkgs.rustup
            pkgs.emacs
            pkgs.ollama
            pkgs.claude-code
            pkgs.python3
            pkgs.opencode
            pkgs.uv
            pkgs.codex
            pkgs.syncthing
            pkgs.tree
            pkgs.librewolf
            pkgs.inetutils
            pkgs.fastfetch
            pkgs.cowsay
            pkgs.semgrep
          ];

        homebrew = {
          enable = true;
          taps = builtins.attrNames config.nix-homebrew.taps;
          brews = [ 
            "vllm-project/vllm-metal/vllm-metal"
            "cmake"
            "pkg-config"
          ];

          casks = [
            "hammerspoon"
            "firefox"
            "ghostty"
            "protonvpn"
            "proton-mail"
            "proton-pass"
            "discord"
            "iina"
            "the-unarchiver"
            "steam"
          ];
          onActivation.cleanup = "zap";
        };

        fonts.packages = with pkgs; [
          jetbrains-mono
        ];
        # Necessary for using flakes on this system.
        nix.settings.experimental-features = "nix-command flakes";

        launchd.user.agents.syncthing = {
          serviceConfig = {
            ProgramArguments = [
              "${pkgs.syncthing}/bin/syncthing"
              "serve"
              "--no-browser"
              "--no-restart"
            ];
            KeepAlive = true;
            RunAtLoad = true;
            ProcessType = "Background";
            StandardOutPath = "/tmp/syncthing.log";
            StandardErrorPath = "/tmp/syncthing.err.log";
          };
        };

        # Enable alternative shell support in nix-darwin.
        # programs.fish.enable = true;

        # Set Git commit hash for darwin-version.
        system.configurationRevision = self.rev or self.dirtyRev or null;

        # Used for backwards compatibility, please read the changelog before changing.
        # $ darwin-rebuild changelog
        system.stateVersion = 6;

        # The platform the configuration will be used on.
        nixpkgs.hostPlatform = "aarch64-darwin";
      };
    in
      {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#MacBook-Pro
      darwinConfigurations."MacBook-Pro" = nix-darwin.lib.darwinSystem {
        modules = [ 
          configuration
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            users.users.sam.home = "/Users/sam";
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.sam = { pkgs, ... }: {
                # Prebuilt epdfinfo for Doom's pdf-tools, so Emacs never compiles it.
                home.file.".local/bin/epdfinfo".source =
                  let pdf-tools = pkgs.emacsPackages.pdf-tools;
                  in "${pdf-tools}/share/emacs/site-lisp/elpa/pdf-tools-${pdf-tools.version}/epdfinfo";
                home.stateVersion = "26.11";
              };
            };
          }
          {
            nix-homebrew = {
              enable = true;
              # Apple Silicon only
              enableRosetta = true;
              user = "sam";

              taps = {
                "vllm-project/homebrew-vllm-metal" = vllm-metal;
              };
            };
          }
        ];
      };
    };
}

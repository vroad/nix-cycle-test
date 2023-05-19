{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Builds fine with older nixpkgs-unstable
    # nixpkgs-unstable.url = "github:NixOS/nixpkgs/8e3b64db39f2aaa14b35ee5376bd6a2e707cadc2";
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable }:
    let
      system = "x86_64-linux";
      unstablePkgs = import nixpkgs-unstable {
        inherit system;
      };
    in
    {
      nixosConfigurations.b550i =
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs unstablePkgs; };
          modules =
            [
              ./hardware-configuration.nix
              ({ config, pkgs, ... }:
                {
                  # Use the systemd-boot EFI boot loader.
                  boot.loader.systemd-boot.enable = true;
                  boot.loader.efi.canTouchEfiVariables = true;

                  # Set your time zone.
                  time.timeZone = "Asia/Tokyo";

                  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
                  # Per-interface useDHCP will be mandatory in the future, so this generated config
                  # replicates the default behaviour.
                  networking.hostName = "b550i";

                  # Select internationalisation properties.
                  i18n.defaultLocale = "ja_JP.UTF-8";
                  console = {
                    font = "Lat2-Terminus16";
                    useXkbConfig = true;
                  };

                  # Configure keymap in X11
                  services.xserver.layout = "jp";

                  # Define a user account. Don't forget to set a password with ‘passwd’.
                  users.users.nixos = {
                    isNormalUser = true;
                    extraGroups = [
                      "wheel" # Enable ‘sudo’ for the user.
                    ];
                  };

                  # This value determines the NixOS release from which the default
                  # settings for stateful data, like file locations and database versions
                  # on your system were taken. It‘s perfectly fine and recommended to leave
                  # this value at the release version of the first install of this system.
                  # Before changing this value read the documentation for this option
                  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
                  system.stateVersion = "21.11"; # Did you read the comment?

                  boot.kernelPackages = pkgs.linuxPackages_6_1;

                  nix = {
                    extraOptions = ''
                      experimental-features = nix-command flakes
                      builders-use-substitutes = true
                    '';
                  };

                  nixpkgs.overlays = [
                    (self: super: rec {
                      mpv-unwrapped = unstablePkgs.mpv-unwrapped.overrideAttrs (oldAttrs: rec {
                        version = "ec58670a0dc9d4c3970cb4814b2f47ca7011a421";
                        src = unstablePkgs.fetchFromGitHub {
                          owner = "mpv-player";
                          repo = "mpv";
                          rev = version;
                          sha256 = "sha256-NRxV04IpVNPmgLl+AhPjDXXHUe5u1XXz1DS8cizwn80=";
                        };
                        patches = [ ];
                      });
                      # Builds fine if src is not overridden
                      # mpv-unwrapped = unstablePkgs.mpv-unwrapped;
                      mpv = unstablePkgs.wrapMpv mpv-unwrapped {
                        scripts = [
                          unstablePkgs.mpvScripts.mpris
                        ];
                      };
                    })
                  ];

                  environment.systemPackages = with pkgs;
                    [
                      mpv
                    ];
                })
            ];
        };
      apps.${system}.nixos-rebuild = {
        type = "app";
        program = "${nixpkgs.legacyPackages.${system}.nixos-rebuild}/bin/nixos-rebuild";
      };
    };
}

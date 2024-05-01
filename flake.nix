{
  description = "Lockdown python dependency reproducibility, attempt 56";

  inputs.pyproject-nix.url = "github:nix-community/pyproject.nix";
  inputs.pyproject-nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = {
    nixpkgs,
    pyproject-nix,
    ...
  }: let
    # Loads pyproject.toml into a high-level project representation
    # Do you notice how this is not tied to any `system` attribute or package sets?
    # That is because `project` refers to a pure data representation.
    project = pyproject-nix.lib.project.loadPyproject {
      # Read & unmarshal pyproject.toml relative to this project root.
      # projectRoot is also used to set `src` for renderers such as buildPythonPackage.
      projectRoot = ./.;
    };

    # This example is only using aarch64-darwin
    pkgs = nixpkgs.legacyPackages.aarch64-darwin;

    # We are using the default nixpkgs Python3 interpreter & package set.
    #
    # This means that you are p word2numberurposefully ignoring:
    # - Version bounds
    # - Dependency sources (meaning local path dependencies won't resolve to the local path)
    #
    # To use packages from local sources see "Overriding Python packages" in the nixpkgs manual:
    # https://nixos.org/manual/nixpkgs/stable/#reference
    #
    # Or use an overlay generator such as pdm2nix:
    # https://github.com/adisbladis/pdm2nix
    word2number =
      pkgs.python311Packages.buildPythonPackage
      rec {
        pname = "word2number";
        version = "1.03";
        format = "pyproject";
        build-system = [];
        src = builtins.fetchGit {
          url = "https://github.com/bestmahdi2/word2number.git";
          rev = "af1448e4aa86a177968a1c5537731d1e478cce29";
          ref = "v1.03";
        };
        nativeBuildInputs = [pkgs.python311Packages.setuptools];
        postUnpack = ''
          if [ ! -f $sourceRoot/setup.py ]; then
            echo "from setuptools import setup; setup(name='${pname}')" > $sourceRoot/setup.py
          fi
        '';
      };
    python = pkgs.python311.override (oldAttrs: {
      packageOverrides = self: super: {
        inherit word2number;
        tqdm-multiprocess = pkgs.python311Packages.tqdm;
      };
    });
  in {
    # Create a development shell containing dependencies from `pyproject.toml`
    devShells.aarch64-darwin.default = let
      attr = project.renderers.withPackages {
        inherit python;
      };

      # Returns a wrapped environment (virtualenv like) with all our packages
      pythonEnv = python.withPackages attr;
    in
      # Create a devShell like normal.
      pkgs.mkShell {
        packages = [pythonEnv];
      };

    # Build our package using `buildPythonPackage
    packages.aarch64-darwin.default = let
      attrs = project.renderers.buildPythonPackage {
        inherit python;
      };
    in
      python.pkgs.buildPythonPackage (attrs
        // {
          #          env.CUSTOM_ENVVAR = "hello";
        });
  };
}

{
  description = "Lockdown python dependency reproducibility, attempt 56";

  inputs.pyproject.url = "github:nix-community/pyproject.nix";
  inputs.pyproject.inputs.nixpkgs.follows = "nixpkgs";
  inputs.systems.url = "github:nix-systems/default";

  outputs = {
    nixpkgs,
    pyproject,
    systems,
    ...
  }: let
    project = pyproject.lib.project.loadPyproject {
      # Read & unmarshal pyproject.toml relative to this project root.
      # projectRoot is also used to set `src` for renderers such as buildPythonPackage.
      projectRoot = ./.;
    };
    eachSystem = nixpkgs.lib.genAttrs (import systems);
    buildWordNumber = ps:
      ps.python311Packages.buildPythonPackage
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
        nativeBuildInputs = [ps.python311Packages.setuptools];
        postUnpack = ''
          if [ ! -f $sourceRoot/setup.py ]; then
            echo "from setuptools import setup; setup(name='${pname}')" > $sourceRoot/setup.py
          fi
        '';
      };
      buildPython = {
        ps,
        word2number,
      }:
      ps.python311.override (oldAttrs: {
        packageOverrides = self: super: {
          inherit word2number;
          tqdm-multiprocess = ps.python311Packages.tqdm;
        };
      });
  in {
    packages = eachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      word2number = buildWordNumber pkgs;
      python = buildPython {
        inherit word2number;
        ps = pkgs;
      };
      packageAttrs = pyproject.lib.renderers.buildPythonPackage {
        inherit python project;
      };
    in
      python.pkgs.buildPythonPackage (packageAttrs
        // {
          #          env.CUSTOM_ENVVAR = "hello";
        }));

    devShells = eachSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        word2number = buildWordNumber pkgs;
        python = buildPython {
          ps = pkgs;
          inherit word2number;
        };
      in {
        default = pkgs.mkShell {
          packages = [python];
        };
      }
    );
  };
}

{
  description = "Lockdown python dependency reproducibility, attempt 56";
  inputs.nixpkgs.url = "github:numtide/nixpkgs-unfree";
  inputs.nixpkgs.inputs.nixpkgs.follows = "nixpkgs-unstable";

  inputs.nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

  # Optionally, pull pre-built binaries from this project's cache
  nixConfig.extra-substituters = [ "https://numtide.cachix.org" ];
  nixConfig.extra-trusted-public-keys = [ "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE=" ];

  inputs.pyproject.url = "github:nix-community/pyproject.nix";
  inputs.pyproject.inputs.nixpkgs.follows = "nixpkgs";
  inputs.systems.url = "github:nix-systems/default";

  outputs = {
    nixpkgs,
    pyproject,
    systems,
    ...
  }: let
    project = pyproject.lib.project.loadPDMPyproject {
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
        propagatedBuildInputs = [
           ps.python311Packages.tomli
        ];
      };
      buildPython = {
        pkgs,
        word2number,
      }:
      (pkgs.python311.override { 
		packageOverrides = self: super: {
                  inherit word2number;
                };
	}).withPackages (project.renderers.withPackages {
               python = pkgs.python311;
         });
  in  rec {
    packages = eachSystem (system: let     
      pkgs = nixpkgs.legacyPackages.${system};
      word2number = buildWordNumber pkgs;
      python = buildPython {
        inherit pkgs word2number;
      }; in python);

    devShells = eachSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        word2number = buildWordNumber pkgs;
        python = buildPython {
          inherit pkgs word2number;
        };
      in {
        default = pkgs.mkShell {
                preCheck = ''
			export TMPDIR=/tmp

		'';
	  dontUnpack = true;
          doCheck = false;
          packages = [python pkgs.pdm];
        };
      }
    );
	};
}

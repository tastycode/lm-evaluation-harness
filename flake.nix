{
  description = "Lockdown python dependency reproducibility, attempt 56";

  inputs = {
    nixpkgs.url = "github:numtide/nixpkgs-unfree";
   # nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    pyproject.url = "github:nix-community/pyproject.nix";
    pyproject.inputs.nixpkgs.follows = "nixpkgs";
    systems.url = "github:nix-systems/default";
  };

  nixConfig = {
    extra-substituters = [ "https://numtide.cachix.org" "https://cuda-maintainers.cachix.org" ];
    extra-trusted-public-keys = [ "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE=" "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="];
  };

  outputs = { self, nixpkgs, systems, pyproject, ... } @ inputs: let
    forEachSystem = nixpkgs.lib.genAttrs (import systems);
    project = pyproject.lib.project.loadPDMPyproject {
      projectRoot = ./.;
    };

    buildWordNumber = ps:
      ps.python311Packages.buildPythonPackage rec {
        pname = "word2number";
        version = "1.03";
        format = "pyproject";
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
      pkgs,
      word2number,
    }: (pkgs.python311.override {
      packageOverrides = self: super: {
        inherit word2number;
        torch = super.torch-bin;
        sphinxcontrib-jquery = super.sphinxcontrib-jquery.overridePythonAttrs (oldAttrs: {
          propagatedBuildInputs = [ self.sphinx ];
        });
        accelerate = super.accelerate.overridePythonAttrs (oldAttrs: {
          propagatedBuildInputs = [ self.huggingface-hub self.numpy self.psutil self.torch self.safetensors ];
        });
        buildPythonPackage = args: super.buildPythonPackage (args // { doCheck = false; });
      };
    }).withPackages (project.renderers.withPackages {
      python = pkgs.python311;
    });

  in {
    devShells = forEachSystem (system: let
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
        packages = [
          python
          pkgs.hyperfine
          pkgs.pdm
          pkgs.sphinx
          pkgs.git
          pkgs.zlib
          pkgs.stdenv.cc.cc.lib
        ];
        shellHook = ''
          export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
            pkgs.gcc-unwrapped.lib
            pkgs.linuxPackages_latest.nvidia_x11
            pkgs.zlib
            pkgs.cmake
            pkgs.cudaPackages.cudatoolkit
            pkgs.cudaPackages.cudnn
            pkgs.cudaPackages.libcublas
            pkgs.cudaPackages.libcurand
            pkgs.cudaPackages.libcufft
            pkgs.cudaPackages.libcusparse
            pkgs.cudaPackages.cuda_nvtx
            pkgs.cudaPackages.cuda_cupti
            pkgs.cudaPackages.cuda_nvrtc
            pkgs.cudaPackages.nccl
          ]}
          export CUDA_HOME=${pkgs.cudaPackages.cudatoolkit}
          export CUDA_PATH=${pkgs.cudaPackages.cudatoolkit}
        '';
      };
    });
  };
}


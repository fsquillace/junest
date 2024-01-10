{
  description = "The lightweight Arch Linux based distribution that runs without root access upon any Linux distros."; 
  
      inputs.nixpkgs.url = "nixpkgs/nixpkgs-unstable";
      inputs.flake-utils.url = "github:numtide/flake-utils";
      inputs.flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
      
      outputs = { self, nixpkgs, flake-utils, flake-compat }:
        let
           systems = [ "x86_64-linux" "aarch64-linux" ];
        in
        flake-utils.lib.eachSystem systems (system:
            let 
               pkgs = nixpkgs.legacyPackages.${system};

               junest = with pkgs; stdenvNoCC.mkDerivation rec {
                   pname = "junest";
                   version = "7.3.9";
                   src = ./.;
                   
                   doBuild= false;

                   nativeBuildInputs = [ makeWrapper ];

                   installPhase = ''
                       mkdir -p $out/{bin,lib}
                       mv bin/junest $out/bin
                       mv lib/* $out/lib
                       chmod +w $out/bin/junest
                       runHook postInstall
                       '';
                       
                   postInstall = ''
                       substituteInPlace $out/lib/core/common.sh \
                             --replace "PATH=/usr/bin:/bin:/usr/local/bin:/usr/sbin:/sbin:\''${HOME}/.local/bin" " "
                      '';
                      
                    postFixup = ''
                        wrapProgram $out/bin/junest \
                            --prefix PATH ":" "${coreutils}/bin" \
                            --prefix PATH ":" "${getent}/bin/getent" \
                            --prefix PATH ":" "${gzip}/bin/zgrep" \
                            --prefix PATH ":" "${gnutar}/bin/tar" \
                            --prefix PATH ":" "${wget}/bin/wget" \
                            --prefix PATH ":" "${curl}/bin/curl"
                       '';
               };
            in
               rec {
                   packages.junest = junest;
                   defaultPackage = self.packages.${system}.junest;
                   });
 }
        
  
  

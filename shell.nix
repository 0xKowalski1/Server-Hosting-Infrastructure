{ pkgs ? import <nixpkgs> {
    config = {
      allowUnfree = true;
    };
  }
}:

pkgs.mkShell {

     

    allowUnfree = true;
  buildInputs = with pkgs; [
    google-cloud-sdk
    terraform
  ];



  shellHook = ''
    echo "Environment loaded with Google Cloud SDK and Terraform"
  '';
}


{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  openssh,
}:

buildGoModule (finalAttrs: {
  pname = "bast";
  version = "0.11.0";

  src = fetchFromGitHub {
    owner = "ellipse-software";
    repo = "bast";
    tag = "v${finalAttrs.version}";
    hash = "sha256-S7hKt1WvTVY0jZM9h5GHs1Xh7oeJq6aJCcOtuXgzTso=";
  };

  modRoot = "apps/bast";
  vendorHash = "sha256-fZ7NDQ7/RYwMI/v2I+j8CI6/OAigUegxCZ5fozcpxU4=";

  env.CGO_ENABLED = 0;

  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ openssh ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=v${finalAttrs.version}"
  ];

  postInstall = ''
    wrapProgram "$out/bin/bast" \
      --prefix PATH : ${lib.makeBinPath [ openssh ]}
  '';

  meta = {
    description = "Fast terminal SSH host picker, key manager, and CLI";
    homepage = "https://github.com/ellipse-software/bast";
    changelog = "https://github.com/ellipse-software/bast/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ kevinpita ];
    mainProgram = "bast";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
})

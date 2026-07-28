{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  openssh,
}:

buildGoModule (finalAttrs: {
  pname = "bast";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "ellipse-software";
    repo = "bast";
    tag = "v${finalAttrs.version}";
    hash = "sha256-V6PunQ3Kets2W3xLzDZxTCeWfu1ff1IAHgl9WU8LA3M=";
  };

  vendorHash = "sha256-VdBnS/3z3PRMoZ4vbtl7YBZrQcpG1pNQhVqkDRMFZ1Q=";

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

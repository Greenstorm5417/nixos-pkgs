{ pkgs }:

let
  generated = import ./generated.nix;
  system = pkgs.stdenv.hostPlatform.system;
  source = generated.sources.${system};
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "zoeken";
  version = generated.version;

  src = pkgs.fetchurl {
    inherit (source) url hash;
  };

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [ pkgs.stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall

    install -Dm755 zoeken-server "$out/libexec/zoeken-server"
    mkdir -p "$out/share/zoeken/assets" "$out/etc/zoeken"
    cp -R assets/. "$out/share/zoeken/assets/"
    install -Dm644 settings.yml "$out/etc/zoeken/settings.yml"
    install -Dm644 limiter.toml "$out/etc/zoeken/limiter.toml"
    install -Dm644 default.config.yml "$out/share/doc/zoeken/default.config.yml"
    install -Dm644 LICENSE "$out/share/licenses/zoeken/LICENSE"

    substituteInPlace "$out/etc/zoeken/settings.yml" \
      --replace-fail "/etc/zoeken/limiter.toml" "$out/etc/zoeken/limiter.toml"

    makeWrapper "$out/libexec/zoeken-server" "$out/bin/zoeken-server" \
      --set-default APP_ASSETS_DIR "$out/share/zoeken/assets" \
      --set-default APP_SETTINGS_PATH "$out/etc/zoeken/settings.yml"

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Privacy-respecting metasearch engine";
    homepage = "https://github.com/Greenstorm5417/Zoeken";
    license = licenses.agpl3Plus;
    mainProgram = "zoeken-server";
    platforms = builtins.attrNames generated.sources;
  };
}

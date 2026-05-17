# Pin chromaprint + kvazaar to versions known to build on aarch64-darwin.
# nixpkgs-25.11 ships chromaprint 1.6.0 and kvazaar 2.3.2 whose test suites
# get SIGKILL'd in the macOS sandbox (FFmpegAudioReaderTest.ReadRaw / CTest).
# Both ffmpeg-full transitive deps; both were last working at the pinned rev.
{ nixpkgs-ffmpeg-darwin-pin }:
final: prev:
prev.lib.optionalAttrs prev.stdenv.isDarwin (
  let
    pinned = import nixpkgs-ffmpeg-darwin-pin {
      inherit (prev.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    };
  in
  {
    inherit (pinned) chromaprint kvazaar;
  }
)

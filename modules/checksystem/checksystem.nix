{ stdenv, fetchFromGitHub, makeWrapper, perl
, CpanelJSONXS
, DBDPg
, EV
, IOSocketSSL
, IPCRun
, ScalarListUtils
, Minion
, MojoPg
, Mojolicious
, MojoliciousPluginModel
, NetDNSNative
, ProcProcessTable
, SerealDclone
, StringRandom
}:

stdenv.mkDerivation {
  name = "checksystem";

  src = fetchFromGitHub {
    owner = "HackerDom";
    repo = "checksystem";
    rev = "3b2a88c6e9fe8f1e30cf143a8ab777ff8d304ab0";
    sha256 = "16q6qw2iaglvvji64qhpjda1v2xpcxccnmyp70wh15fmpihn5xw3";
  };

  nativeBuildInputs = [ perl makeWrapper ];

  buildInputs = [
    CpanelJSONXS
    DBDPg
    EV
    IOSocketSSL
    IPCRun
    ScalarListUtils
    Minion
    MojoPg
    Mojolicious
    MojoliciousPluginModel
    NetDNSNative
    ProcProcessTable
    SerealDclone
    StringRandom   
  ];

  installPhase = ''
    mkdir -p $out/lib/checksystem $out/bin
    cp -r * $out/lib/checksystem
    patchShebangs "$out/lib/checksystem/script/cs"
    makeWrapper "$out/lib/checksystem/script/cs" "$out/bin/cs" \
      --prefix PERL5LIB ":" "$PERL5LIB" \
      --run "cd $out/lib/checksystem"
    makeWrapper "${Mojolicious}/bin/hypnotoad" "$out/bin/hypnotoad-cs" \
      --prefix PERL5LIB ":" "$PERL5LIB" \
      --add-flags "$out/lib/checksystem/script/cs" \
      --run "cd $out/lib/checksystem"
  '';
}

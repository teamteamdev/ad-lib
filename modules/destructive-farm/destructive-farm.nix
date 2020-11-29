{ stdenv, buildPythonPackage, wrapPython, fetchPypi, fetchFromGitHub
, python
, certifi
, chardet
, click
, flask
, idna
, itsdangerous
, jinja2
, markupsafe
, requests
, urllib3
, werkzeug
}:

let
  themis_finals_attack_helper = buildPythonPackage rec {
    pname = "themis.finals.attack.helper";
    version = "1.1.0";
    format = "wheel";

    propagatedBuildInputs = [ themis_finals_attack_result requests ];

    src = fetchPypi {
      inherit pname version format;
      sha256 = "1xv33g3j13pkr8y7slmn59ns0aiwfq0bdlpqni4nk890m6xv679w";
    };
  };

  themis_finals_attack_result = buildPythonPackage rec {
    pname = "themis.finals.attack.result";
    version = "1.3.0";
    format = "wheel";

    src = fetchPypi {
      inherit pname version format;
      sha256 = "0x5sn6wcpm2d1k8xhysagqzj85xc7gwip6f37prqnpnqi7x1b4jw";
    };
  };

in buildPythonPackage {
  name = "DestructiveFarm";

  src = fetchFromGitHub {
    owner = "ugractf";
    repo = "DestructiveFarm";
    rev = "1c026f38d1d4ffa9c882d6fa012162dfb079f867";
    sha256 = "1kgr6c8jfp9kf56q9wv7jlpl1mj8xf01f0ar21jsszw3gj75pwqq";
  };

  propagatedBuildInputs = [
    certifi
    chardet
    click
    flask
    idna
    itsdangerous
    jinja2
    markupsafe
    requests
    urllib3
    werkzeug
    themis_finals_attack_helper
    themis_finals_attack_result
  ];

  doCheck = false;

  buildPhase = "true";

  installPhase = ''
    mkdir -p $out/bin $out/${python.sitePackages}
    cp -r server $out/${python.sitePackages}/server
    rm $out/${python.sitePackages}/server/standalone.py
    mv $out/${python.sitePackages}/server/submit_loop.py $out/bin/submit_loop
  '';
}

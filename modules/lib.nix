{ lib }:


let
  override = self:
    with self;
    {
      prefix24FromAddress = ipAddress: concatStringsSep "." (take 3 (splitString "." ipAddress) ++ ["0"]);

      pow = 
        let go = r: a: x:
              if x == 0 then r
              else go (r * a) a (x - 1);
        in a: x:
          if x < 0 then throw "Negative powers are not supported"
          else go 1 a x;

      prefixLengthToMask =
        let go = built: left: length:
              if left == 0 then built
              else
                let curr = min length 8;
                    mask = pow 2 curr - 1;
                in go (built ++ [(toString mask)]) (left - 1) (length - curr);
        in length: concatStringsSep "." (go [] 4 length);

      toPerl =
        let
          toPerlString = str: replaceStrings ["$" "@"] ["\\$" "\\@"] (builtins.toJSON str);
          toPerlPair = name: attr: "${toPerlString name} => ${toPerl attr}";
        in value:
          if isDerivation value then
            toPerlString (toString value)
          else if isList value then
            "[${concatMapStringsSep ", " toPerl value}]"
          else if isAttrs value then
            "{${lib.concatStringsSep ", " (lib.mapAttrsToList toPerlPair value)}}"
          else if isString value then
            toPerlString value
          else if isInt value then
            toString value
          else if isBool value then
            if value then "1" else "0"
          else if value == null then
            "undef"
          else
            throw "Can't convert value to Perl string";
    };
  self = lib // override self;
in self

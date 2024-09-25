{ nixpkgs, ... }:
let
  inherit (nixpkgs) lib;
in
{
  toClickhouseXml =
    {
      root ? "clickhouse",
      indent ? "\t",
      boolToString ? lib.boolToString,
    }:
    let
      attr =
        lvl: name: value:
        let
          ind = lib.strings.replicate lvl indent;
        in
        if value == null then
          "${ind}<${name} />\n"
        else if lib.isAttrs value -> lib.isStringLike value then
          "${ind}<${name}>${inlineToString value}</${name}>\n"
        else
          ''
            ${ind}<${name}>
            ${attrs (lvl + 1) value}${ind}</${name}>
          '';
      inlineToString =
        x:
        if lib.isBool x then
          boolToString x
        else if lib.isStringLike x then
          lib.escapeXML x
        else
          lib.escapeXML (toString x);
      attrs =
        lvl:
        lib.flip lib.pipe [
          (lib.mapAttrsToList (name: value: map (attr lvl name) (lib.toList value)))
          builtins.concatLists
          lib.concatStrings
        ];
    in
    attr 0 root;
}

{ pkgs, writeShellApplication, ... }:
{
  record = writeShellApplication {
    name = "git";
    runtimeInputs = with pkgs; [
      git
      jq
      gnused
      coreutils
    ];
    text = ''
      GITLOG=$(realpath -s "$GITLOG")
      mkdir -p "$GITLOG"
      [ ! -s "$GITLOG/contents.json" ] && echo "{}" > "$GITLOG/contents.json"
      REPO="$(basename "$( (git rev-parse --show-toplevel || echo -n) 2>/dev/null)")"
      P="$(realpath -s --relative-to="$GITBASE" "$(pwd)")"
      A="''${*//$GITBASE/GITBASE}"
      OUT=$(echo -n "$P|$A" | md5sum | cut -f1 -d' ')
      STATUS=0
      O=$(GIT_PROGRESS_DELAY=1000000 git "$@" 2>&1 | tee) || STATUS="$?"
      echo -n "''${O//$GITBASE/GITBASE}" > "$GITLOG/$OUT"
      PREV=$(cat "$GITLOG/contents.json")
      echo "$PREV" | \
        jq --arg P "$P" --arg A "$A" --arg OUT "$OUT" --arg S "$STATUS" \
          --arg R "$REPO" \
        '.byPath."\($P)"."\($A)" = {"out": $OUT, "status": $S} | .byRepo."\($R)"."\($A)" = {"out": $OUT, "status": $S}' \
        > "$GITLOG/contents.json"
      cat "$GITLOG/$OUT"
      exit "$STATUS"
    '';
  };
  replay = writeShellApplication {
    name = "git";
    runtimeInputs = with pkgs; [
      git
      jq
      gnused
      coreutils
    ];
    text = ''
      test -n "$GITLOG"
      test -n "$GITBASE"
      if [ -d ".git" ]; then
        REPO="$(basename "$(pwd)")"
      else
        REPO=""
      fi
      P="$(realpath -s --relative-to="$GITBASE" "$(pwd)")"
      A="''${*//$GITBASE/GITBASE}"
      CONTENT=$(jq -r --arg P "$P" --arg A "$A" --arg R "$REPO" \
        '.byRepo."\($R)"."\($A)"' \
        "$GITLOG/contents.json")
      if [ "$CONTENT" = "null" ]; then
        git "$@"
      else
        FILETOPLAY=$(echo "$CONTENT" | jq -r '.out' )
        STATUS=$(echo "$CONTENT" | jq -r '.status' )
        sed "s|GITBASE|$GITBASE|g" < "$GITLOG/$FILETOPLAY" 
        exit "$STATUS"
      fi
    '';
  };
}

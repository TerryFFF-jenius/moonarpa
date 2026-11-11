#!/usr/bin/env python3
"""Check pinned KenLM published vectors without redistributing its test fixture.
This checks reference data, not a locally executed KenLM binary.
"""
import argparse
import base64
import hashlib
import json
import urllib.request
from run_request import invoke
from verify_oracle import close, lookup, parse_tables

COMMIT = "4cb443e60b7bf2c0ddf3c745378f76cb59e254e5"
SHA256 = "fa7d176e45ce43669a4e057c73c112ffe5be047c33a63bb1be0406252976f75c"
URL = "https://api.github.com/repos/kpu/kenlm/contents/lm/test.arpa?ref=" + COMMIT


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target",default="wasm-gc")
    parser.add_argument("--fixture", help="optional already-downloaded lm/test.arpa")
    args = parser.parse_args()
    if args.fixture:
        from pathlib import Path
        data = Path(args.fixture).read_bytes()
    else:
        request = urllib.request.Request(URL,headers={"User-Agent":"MoonARPA-reference-check"})
        with urllib.request.urlopen(request,timeout=30) as response:
            data = base64.b64decode(json.load(response)["content"])
    assert hashlib.sha256(data).hexdigest() == SHA256, "upstream fixture digest mismatch"
    arpa = data.decode("utf-8")
    tables = parse_tables(arpa)
    sequence = ["looking","on","a","little","the","biarritz","not_found","more","."]
    expected = [-0.484652,-0.348837,-0.0155266,-0.00306122,-4.04005,-1.9889,-2.29666,-21.20632,-0.51363,-0.0191651]
    orders = [2,3,4,5,1,1,1,1,2,3]
    scored = invoke({"op":"score","arpa":arpa,"tokens":sequence},args.target)
    for actual, value, matched in zip(scored["tokens"],expected,orders):
        close(actual["log10_probability"],value,tolerance=1e-5)
        assert actual["matched_order"] == matched
    probes = [["looking"],[","],["this_is_not_found"],["also","would","consider","higher","looking"],sequence]
    corpus = invoke({"op":"corpus","arpa":arpa,"sentences":probes},args.target)
    compared = 0
    for sentence, result in zip(probes,corpus["sentence_scores"]):
        history = ["<s>"]
        for word, actual in zip(sentence+["</s>"],result["tokens"]):
            import math
            close(actual["log10_probability"],math.log10(lookup(tables,history,word,5)))
            history.append(word)
            compared += 1
    print(json.dumps({"kenlm_reference":"passed","target":args.target,"commit":COMMIT,"token_comparisons":compared,"published_vector_checks":10}))


if __name__ == "__main__":
    main()

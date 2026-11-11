#!/usr/bin/env python3
"""Independent linear-probability and count oracle; Python standard library only."""
import argparse
from collections import Counter
from itertools import product
import math
from run_request import invoke


def parse_tables(arpa):
    tables = {}
    order = 0
    for line in arpa.splitlines():
        if line.startswith("\\") and line.endswith("-grams:"):
            order = int(line[1:].split("-")[0])
            continue
        fields = line.split()
        if not order or not fields or fields[0].startswith("\\"):
            continue
        logp = float(fields[0])
        words = tuple(fields[1:order+1])
        backoff = float(fields[order+1]) if len(fields) == order+2 else 0.0
        tables[words] = (10.0 ** logp, 10.0 ** backoff)
    return tables


def lookup(tables, history, word, order):
    history = tuple(history[-(order-1):]) if order > 1 else ()
    vocabulary = {gram[0] for gram in tables if len(gram) == 1}
    word = word if word in vocabulary else "<unk>"
    history = tuple(w if w in vocabulary else "<unk>" for w in history)
    def recurse(context):
        gram = context + (word,)
        if gram in tables:
            return tables[gram][0]
        assert context
        return tables.get(context, (0.0, 1.0))[1] * recurse(context[1:])
    return recurse(history)


class CountOracle:
    def __init__(self, sentences, order, discount=0.75, prior=0.5):
        self.order, self.discount, self.prior = order, discount, prior
        self.counts = Counter()
        for sentence in sentences:
            sequence = ["<s>"] + sentence + ["</s>"]
            for end in range(1, len(sequence)):
                for size in range(1, min(order, end + 1) + 1):
                    self.counts[tuple(sequence[end-size+1:end+1])] += 1
        self.vocab = {g[0] for g in self.counts if len(g) == 1} | {"<s>","</s>","<unk>"}
        self.total = sum(c for g,c in self.counts.items() if len(g) == 1)

    def probability(self, history, word):
        history = tuple(history[-(self.order-1):]) if self.order > 1 else ()
        word = word if word in self.vocab else "<unk>"
        history = tuple(w if w in self.vocab else "<unk>" for w in history)
        def recurse(context):
            if not context:
                if word == "<s>":
                    return 0.0
                return (self.counts[(word,)] + self.prior) / (self.total + self.prior * (len(self.vocab)-1))
            continuations = {g[-1]:c for g,c in self.counts.items() if len(g) == len(context)+1 and g[:-1] == context}
            total = sum(continuations.values())
            lower = recurse(context[1:])
            if not total:
                return lower
            residual = self.discount * len(continuations) / total
            direct = max(continuations.get(word,0) - self.discount, 0.0) / total
            return direct + residual * lower
        return recurse(history)


def close(actual, expected, tolerance=2e-10):
    assert math.isclose(actual,expected,rel_tol=tolerance,abs_tol=tolerance),(actual,expected)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", default="wasm-gc")
    args = parser.parse_args()
    compared = 0
    corpora = [[], [[]], [["a"]], [["a","b"],["a"],["b","a"]],
               [["hello","world"],["hello","moon"],["moon","world"]]]
    for order in [1,2,3,5,8]:
        for training in corpora:
            response = invoke({"op":"train","sentences":training,"order":order},args.target)
            tables = parse_tables(response["arpa"])
            reference = CountOracle(training,order)
            # Probe every history over a tiny fixed alphabet, including OOVs.
            probes = [list(p) for length in range(4) for p in product(["a","b"],repeat=length)]
            score = invoke({"op":"corpus","arpa":response["arpa"],"sentences":probes},args.target)
            expected_total = 0.0
            for sequence, result in zip(probes,score["sentence_scores"]):
                history = ["<s>"]
                total = 0.0
                for word, token in zip(sequence+["</s>"],result["tokens"]):
                    probability = reference.probability(history,word)
                    close(lookup(tables,history,word,order),probability)
                    close(token["log10_probability"],math.log10(probability))
                    total += math.log10(probability)
                    history.append(word)
                    compared += 1
                close(result["log10_probability"],total)
                expected_total += total
            close(score["log10_probability"],expected_total)
            close(score["perplexity"],10 ** (-expected_total/score["predicted"]))
            audit = invoke({"op":"audit","arpa":response["arpa"],"history":["<unk>","<unk>"]},args.target)
            close(audit["mass"],1.0)
            canonical = invoke({"op":"canonicalize","arpa":response["arpa"]},args.target)
            assert canonical["arpa"] == response["arpa"]
    print(json_message(args.target,compared))


def json_message(target,compared):
    import json
    return json.dumps({"oracle":"passed","target":target,"training_cases":25,"token_comparisons":compared})


if __name__ == "__main__":
    main()

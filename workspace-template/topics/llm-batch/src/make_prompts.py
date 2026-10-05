#!/usr/bin/env python3
"""Write prompts.jsonl: 40 classification requests in the OpenAI batch format that LLMFlux reads.

Each request gives the model a one-sentence research description (8 for each of 5 fields,
interleaved) and asks for one JSON object {"field": ..., "confidence": ..., "why": ...}.
The output is deterministic (no randomness, fixed order, fixed JSON formatting), so the file in
the kit and a regenerated one are byte-identical. The expected field is part of each custom_id
(`p07-physics`), which analyze.py uses for FIELD_MATCH_RATE.

The request bodies carry no "model", "temperature" or "max_tokens": LLMFlux validates a body
model against the requested one, and the `llmflux run` flags (--temperature, --max-tokens) apply.

    python src/make_prompts.py                 # writes prompts.jsonl in the topic directory
    python src/make_prompts.py --out /tmp/p.jsonl
"""
import argparse
import json
from pathlib import Path

FIELDS = ["biology", "chemistry", "physics", "computer science", "earth science"]

DESCRIPTIONS = {
    "biology": [
        "We sequence the gut microbiome of honeybees across seasons to see how diet shifts bacterial diversity.",
        "This project maps which neurons in the zebrafish hindbrain fire when larvae escape a predator.",
        "We test whether a knocked-out gene slows the regeneration of planarian flatworms after amputation.",
        "The study tracks how drought changes root growth and gene expression in wild sunflowers.",
        "We measure how quickly antibiotic resistance spreads between E. coli strains in a shared culture.",
        "This work compares immune cell responses in bats and mice infected with the same virus.",
        "We model how coral polyps and their symbiotic algae exchange nutrients under warming seawater.",
        "The lab images mitochondria dividing inside living yeast cells to find the proteins that control fission.",
    ],
    "chemistry": [
        "We design a copper catalyst that turns carbon dioxide into methanol at room temperature.",
        "This project synthesizes new metal-organic frameworks that trap water vapour from desert air.",
        "We measure reaction rates of ozone with plant-emitted terpenes in a smog chamber.",
        "The study develops a cheaper electrolyte that stops lithium dendrites from growing in batteries.",
        "We use mass spectrometry to identify unknown pesticide breakdown products in river water.",
        "This work computes how solvent molecules change the colour of a fluorescent dye.",
        "We build polymers that break down in seawater within months instead of centuries.",
        "The lab tunes the size of gold nanoparticles to control how they catalyse glucose oxidation.",
    ],
    "physics": [
        "We cool rubidium atoms to nanokelvin temperatures to study quantum vortices in a condensate.",
        "This project searches detector data for the faint recoil of a dark matter particle hitting xenon.",
        "We measure how sound waves travel through a granular material as it is compressed.",
        "The study simulates turbulence in the plasma at the edge of a tokamak fusion reactor.",
        "We build a superconducting circuit whose qubits keep their state for longer than a millisecond.",
        "This work uses gravitational-wave signals to measure how fast the universe is expanding.",
        "We shine terahertz pulses on graphene to watch its electrons heat up and cool down.",
        "The lab measures the friction of ice sliding on ice at temperatures near melting.",
    ],
    "computer science": [
        "We develop a compiler pass that removes redundant memory copies in GPU programs.",
        "This project trains a small language model to find bugs in student Python code.",
        "We prove that a distributed consensus protocol stays safe when half the messages are lost.",
        "The study designs a scheduler that packs batch jobs onto a cluster to reduce idle cores.",
        "We compress sparse matrices with a new format that speeds up graph algorithms.",
        "This work measures how often web browsers leak private data through third-party scripts.",
        "We build a verified file system whose crash recovery is checked by a theorem prover.",
        "The lab benchmarks vector databases on searching one billion image embeddings.",
    ],
    "earth science": [
        "We date volcanic ash layers in lake sediments to reconstruct eruptions over ten thousand years.",
        "This project uses satellite radar to measure how fast Greenland glaciers flow into the sea.",
        "We model how groundwater in the Midwest aquifer responds to decades of irrigation pumping.",
        "The study records small earthquakes along a fault to see how stress builds before large ruptures.",
        "We measure how much carbon permafrost soils release as the Arctic summers lengthen.",
        "This work reconstructs past ocean temperatures from oxygen isotopes in foraminifera shells.",
        "We track dust storms from the Sahara across the Atlantic with weather-model simulations.",
        "The lab maps soil erosion on farmland after heavy rain using drone photogrammetry.",
    ],
}

SYSTEM = "You are a careful research librarian. You answer with one JSON object and nothing else."

INSTRUCTION = (
    "Classify the research description below into exactly one of these fields: "
    + ", ".join(FIELDS)
    + '. Reply with only a JSON object of the form {"field": "<one of the fields>", '
    '"confidence": <a number from 0 to 1>, "why": "<one short sentence>"}.'
)


def requests():
    """The 40 requests: descriptions interleaved across the fields (biology, chemistry, ... biology, ...)."""
    out = []
    per_field = len(DESCRIPTIONS[FIELDS[0]])
    for i in range(per_field):
        for field in FIELDS:
            n = len(out) + 1
            out.append({
                "custom_id": f"p{n:02d}-{field.replace(' ', '-')}",
                "method": "POST",
                "url": "/v1/chat/completions",
                "body": {
                    "messages": [
                        {"role": "system", "content": SYSTEM},
                        {"role": "user", "content": f"{INSTRUCTION}\n\nDescription: {DESCRIPTIONS[field][i]}"},
                    ]
                },
            })
    return out


def render():
    """The prompts.jsonl text: one compact JSON object per line, keys in a fixed order, ASCII only."""
    return "".join(json.dumps(r, ensure_ascii=True, separators=(", ", ": ")) + "\n" for r in requests())


def main():
    ap = argparse.ArgumentParser(description="Write the 40 llm-batch prompts (OpenAI batch JSONL).")
    ap.add_argument("--out", default=str(Path(__file__).resolve().parent.parent / "prompts.jsonl"),
                    help="output file (default: prompts.jsonl in the topic directory)")
    args = ap.parse_args()
    text = render()
    Path(args.out).write_text(text)
    print(f"wrote {len(text.splitlines())} prompts to {args.out}")


if __name__ == "__main__":
    main()

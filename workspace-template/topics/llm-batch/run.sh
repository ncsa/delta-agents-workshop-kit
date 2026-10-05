#!/usr/bin/env bash
# topics/llm-batch/run.sh: render models.ws.yaml from models.ws.yaml.in, then print and run the
# `ws-submit --via llmflux -- run ...` line of this topic. A dry run unless --yes (passed to ws-submit),
# like every submission in the workshop. Runs from this directory: it is LLMFlux's workspace, so the
# results (results/), the log (logs/<jobid>.out) and the generated job.sh land here.
#
#   usage: bash run.sh [--yes] [--model KEY] [--output FILE]
#     --model   a key of models.ws.yaml (default Qwen2.5-1.5B-Instruct-local; stretch: Qwen2.5-7B-Instruct-local)
#     --output  the results file (default results/results.json)
set -euo pipefail

usage() { sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

model=Qwen2.5-1.5B-Instruct-local
output=results/results.json
yes=()
while [ $# -gt 0 ]; do
    case $1 in
        --yes) yes=(--yes) ;;
        --model) [ $# -ge 2 ] || { echo "run.sh: --model needs a value" >&2; exit 1; }; model=$2; shift ;;
        --model=*) model=${1#--model=} ;;
        --output) [ $# -ge 2 ] || { echo "run.sh: --output needs a value" >&2; exit 1; }; output=$2; shift ;;
        --output=*) output=${1#--output=} ;;
        -h|--help) usage; exit 0 ;;
        *) echo "run.sh: unknown argument: $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
cd "$here"
if [ -z "${WS_KIT_RO:-}" ]; then
    echo "run.sh: WS_KIT_RO is not set: source the kit's env.sh first (it names the kit and its models/)" >&2
    exit 3
fi
models=${WS_KIT_RO%/}/models

# Render only when the content changes, so a second run leaves models.ws.yaml untouched.
tpl=$(<models.ws.yaml.in)
new=${tpl//@MODELS_DIR@/"$models"}
if [ ! -f models.ws.yaml ] || [ "$(<models.ws.yaml)" != "$new" ]; then
    printf '%s\n' "$new" > models.ws.yaml
    echo "run.sh: wrote models.ws.yaml (models from $models)"
fi
if ! grep -q "^  $model:\$" models.ws.yaml; then
    echo "run.sh: no model '$model' in models.ws.yaml; keys: $(grep -E '^  [^ #][^:]*:$' models.ws.yaml | tr -d ' :' | paste -sd' ' -)" >&2
    exit 1
fi
dir=$(awk -v k="  $model:" '$0 == k { f = 1; next } f && /^    hf_name:/ { print $2; exit }' models.ws.yaml)
if [ ! -f "$dir/config.json" ]; then
    echo "run.sh: the model is not staged: $dir/config.json is missing; ask a helper (nothing downloads in a job)" >&2
    if [ "${#yes[@]}" -gt 0 ]; then exit 3; fi
fi

cmd=(ws-submit --via llmflux "${yes[@]}" -- run --model "$model"
    --custom-config-path models.ws.yaml --engine vllm
    --input prompts.jsonl --output "$output"
    --max-tokens 160 --temperature 0 --batch-size 8)
printf 'run.sh: %s\n' "${cmd[*]}"
exec "${cmd[@]}"

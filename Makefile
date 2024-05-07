eval:
	time python -m lm_eval --model hf --model_args "pretrained=./../basephi-hermes-0,parallelize=True,trust_remote_code=True" --batch_size auto:2 --device cuda --task mmlu,gsm8k,hellaswag,truthfulqa,xwinograd_en --output_path results

#!/bin/bash
set -euo pipefail

# 1. Variablen initialisieren
PROFILE=""
POSITIONAL_ARGS=()

# 2. Argumente parsen (--profile extrahieren, Rest behalten)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      if [[ -n "${2:-}" && ! "$2" == -* ]]; then
        PROFILE="$2"
        shift 2
      else
        echo "ERROR: argument for --profile is missing or invalid" >&2
        exit 1
      fi
      ;;
    -*)
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # Speichert deploy, region, stack_name etc.
      shift
      ;;
  esac
done

# 3. Positionsbezogene Argumente wiederherstellen
if [ ${#POSITIONAL_ARGS[@]} -gt 0 ]; then
    set -- "${POSITIONAL_ARGS[@]}"
else
    set --
fi

# 4. Prüfen, ob genug Argumente übergeben wurden
if [[ $# -lt 3 ]]; then
    echo "Usage: $0 [--profile PROFILE_NAME] deploy|preview REGION STACK_NAME TEMPLATE PARAMETERS"
    echo "       $0 [--profile PROFILE_NAME] delete REGION STACK_NAME"
    exit 1
fi

EXECUTION_MODE=$1
REGION=$2
STACK_NAME=$3
TEMPLATE_FILE_NAME=${4:-}
PARAMETERS_FILE_NAME=${5:-}

# 5. AWS Basis-Befehl vorbereiten (fügt --profile automatisch hinzu, falls gesetzt)
AWS_CMD=(aws)
if [[ -n "$PROFILE" ]]; then
    AWS_CMD+=("--profile" "$PROFILE")
    echo "Using AWS Profile: $PROFILE"
fi

# 6. Hauptlogik
case "$EXECUTION_MODE" in
    deploy)
        if [[ -z "$TEMPLATE_FILE_NAME" || -z "$PARAMETERS_FILE_NAME" ]]; then
            echo "ERROR: deploy requires a template and parameter file."
            exit 1
        fi

        STACK_STATUS=$("${AWS_CMD[@]}" cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --query 'Stacks[0].StackStatus' \
            --output text \
            --region "$REGION" 2>/dev/null || true)

        if [[ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ]]; then
            echo "Removing failed stack $STACK_NAME..."
            "${AWS_CMD[@]}" cloudformation delete-stack \
                --stack-name "$STACK_NAME" \
                --region "$REGION"
            "${AWS_CMD[@]}" cloudformation wait stack-delete-complete \
                --stack-name "$STACK_NAME" \
                --region "$REGION"
        fi

        "${AWS_CMD[@]}" cloudformation deploy \
            --stack-name "$STACK_NAME" \
            --template-file "$TEMPLATE_FILE_NAME" \
            --parameter-overrides file://"$PARAMETERS_FILE_NAME" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION"
        ;;

    preview)
        if [[ -z "$TEMPLATE_FILE_NAME" || -z "$PARAMETERS_FILE_NAME" ]]; then
            echo "ERROR: preview requires a template and parameter file."
            exit 1
        fi

        "${AWS_CMD[@]}" cloudformation deploy \
            --stack-name "$STACK_NAME" \
            --template-file "$TEMPLATE_FILE_NAME" \
            --parameter-overrides file://"$PARAMETERS_FILE_NAME" \
            --no-execute-changeset \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION"
        ;;

    delete)
        BUCKET_NAME=$("${AWS_CMD[@]}" cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --query "Stacks[0].Outputs[?OutputKey=='S3BucketName'].OutputValue | [0]" \
            --output text \
            --region "$REGION" 2>/dev/null || true)

        if [[ -n "$BUCKET_NAME" && "$BUCKET_NAME" != "None" ]]; then
            echo "Emptying S3 bucket $BUCKET_NAME..."
            "${AWS_CMD[@]}" s3 rm "s3://$BUCKET_NAME" --recursive --region "$REGION"
        fi

        "${AWS_CMD[@]}" cloudformation delete-stack \
            --stack-name "$STACK_NAME" \
            --region "$REGION"

        echo "Waiting for stack deletion to complete..."
        "${AWS_CMD[@]}" cloudformation wait stack-delete-complete \
            --stack-name "$STACK_NAME" \
            --region "$REGION"
        echo "Stack $STACK_NAME deleted successfully."
        ;;

    *)
        echo "ERROR: Incorrect execution mode. Valid values: deploy, delete, preview."
        exit 1
        ;;
esac
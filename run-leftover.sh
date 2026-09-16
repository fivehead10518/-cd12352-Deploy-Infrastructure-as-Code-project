###-------------

#Iterate over the arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile) #when the --profile option is found
      if [ -n "$2" ]; then
        case "$2" in
         -*)
            echo "ERROR: argument for $1 is missing" >&2
            exit 1
            ;;
          *)
            profile="$2" #set the profile variable to the next argument
            shift 2 #shift past the option and its argument
            continue
            ;;
         esac
      else
      echo "ERROR: argument for $1 is missing" >&2
      exit 1
      fi
      ;;
    *)
      echo "ERROR:Unknown option: $1" >&2
      exit 1
      ;;
   esac
done

# Use the profile variable
if [ -n "$profile" ]; then 
   aws cloudformation create-stack--stack-name udagramserver \
      --template-body file://udagram.yml \
      --parameters file://udagram-parameters.json \
      --capabilities "CAPABILITY_NAMED_IAM" \
      --region=us-east-1 \
      --profile $profile
else 
   aws cloudformation create-stack--stack-name udagramserver \
      --template-body file://udagram.yml \
      --parameters file://udagram-parameters. json \
      --capabilities "CAPABILITY NAMED IAM"\
      --region=us-east-1
fi
#### ------------

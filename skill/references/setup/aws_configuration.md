# AWS Configuration Setup

This guide provides setup instructions for AWS authentication with the architecture-visibility skill.

## Required AWS Access

The skill requires two types of AWS access:

### 1. S3 Bucket Access (Feature Development Workflows)

- **Bucket**: `features-summary-temp`
- **Region**: `us-east-2`
- **Profile**: Configure an AWS profile with S3 read access
- **Required for**: `aggregate_feature_development.sh`, `fetch_feature_development_history.sh`

### 2. AWS Bedrock Access (TDD Workflows)

- **Service**: AWS Bedrock (for LLM metadata extraction)
- **Region**: `us-east-1`
- **Model**: Auto-detects latest Claude Sonnet inference profile
- **Required for**: `fetch_design_docs.sh`

## Setup Instructions

### Verify AWS Profile Configuration

```bash
# Check if profile exists
aws configure list --profile <your-aws-profile>

# Test S3 bucket access (feature development)
aws s3 ls s3://features-summary-temp/ \
  --profile <your-aws-profile> \
  --region us-east-2

# Test AWS Bedrock access (TDD processing)
aws bedrock list-inference-profiles \
  --region us-east-1 \
  --profile <your-aws-profile>
```

### Configure AWS Profile

If the profile doesn't exist, configure it:

```bash
aws configure --profile <your-aws-profile>
# Enter: AWS Access Key ID
# Enter: AWS Secret Access Key
# Default region: us-east-2
# Default output format: json
```

### Verify Permissions

The AWS account needs:

1. **S3 Permissions**:
   - `s3:ListBucket` on `features-summary-temp`
   - `s3:GetObject` on `features-summary-temp/*`

2. **Bedrock Permissions**:
   - `bedrock:ListInferenceProfiles`
   - `bedrock:InvokeModel` on Claude Sonnet inference profiles

### Troubleshooting

**Error: "AWS credentials not configured or expired"**
```bash
# Refresh your AWS session or reconfigure profile
aws configure --profile <your-aws-profile>
```

**Error: "Could not detect Claude Sonnet inference profile"**
```bash
# Verify Bedrock access in us-east-1
aws bedrock list-inference-profiles --region us-east-1

# If no profiles found, check IAM permissions for bedrock:ListInferenceProfiles
```

**Error: "Access Denied" on S3**
```bash
# Verify bucket access
aws s3 ls s3://features-summary-temp/ \
  --profile <your-aws-profile> \
  --region us-east-2

# If access denied, request S3 read permissions from your infrastructure team
```

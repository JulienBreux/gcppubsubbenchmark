# 📈 GCP PubSub Benchmark

## Step 1 - Create service account key file

Create a service account: 
- organization level
- allow to create project
- allow to assin billing account

Create a JSON key file:
- Remove break line
- Rename the file to "credentials.json"
- Create a "$HOME/security/" directory
- Move file to the previous created directory

## Export some variables

    export TF_VAR_gcp_organization_id=XXXXXXXXXXXX
    export TF_VAR_gcp_billing_account_id=XXXXXX-XXXXXX-XXXXXX
    export TF_VAR_project_id=my-project-id
    export GOOGLE_CREDENTIALS=$(< $HOME/security/credentials.json)

## Create infrastructure

    cd infrastructure/
    terraform plan
    terraform apply

## Deploy tools (locust)

    gcloud container clusters get-credentials main-xxxx --region europe-west9 --project pubsub-benchmark
    kubectl apply -f deployment/1.tools


# Terraform AWS CodePipeline Module
Creates a CodePipeline to deploy infrastructure on AWS with Terraform. The pipeline has the following stages:
1. *Source*: Detects and pulls from a source in Github repository.
2. *Builds*: Builds based on the terraform_plan.yml located in the Github repository.
3. *Deploys*: Deploys based on the terraform_apply.yml located in the Github repository. Uses **AWS CodeBuild**

## Requirements
- private github repository containing the terraform_plan.yml and terraform_apply.yml. Should be in the root folder (see example repo for layout)
- AWS account
- Manually connect to Github for Source stage in aws console

## To-Do's
- Research webhook/connection for GitHub v2
- Create SNS to E-mail approval requests
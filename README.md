# reactspa_codepipeline_demo

What this repo contains:
* A set of terraform files that crate a simple CICD pipeline that builds a React SPA and deploys it to a S3 bucket for static website hosting.

What this repo does not contain:
* The terraform required to handle DNS, HTTPS, or redirects.

What this repo assumes:
* You have created a React SPA and committed it to Github
  * Your repo contains a `pipeline` folder and it contains the following files
    `buildspec-build.yml` which will be called to run the build. Ensure this buildspec copies to `build` or `dist` file to the root of the output artifact
  * `Makefile` or other scripts which will be called from within the buildspec-build.yml
  * Examples of these files can be found in `templates/pipeline`
* The account you are using to execute this terraform has the proper S3, CodePipeline, CodeBuild, and CodeDeploy permissions in your target account.

Steps to build the deployment pipeline:
* Generate an OAuth token for your target repository and add it to AWS SSM with the name `GithubOAuthToken`
* Navigate to the `infrastructure` directory
* Create your profile tf variables to configure the correct environment name and repository information'
* Execute `terraform plan -var-file="your-tfvars"`
* Confirm the output of the plan
* Execute `terraform apply -var-file="your-tfvars"`
* Open a browser and navigate to `https://{your-environment-name}-spa-codepipeline-demo.s3.us-east-1.amazonaws.com/index.html`
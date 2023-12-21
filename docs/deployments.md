# Deployments

## Target environment

This project only runs in production and only has the one target environment for deployments.

For this reason, deployment promotion between environments has no meaning for this project.

## Automatic deployment

**This project requires manual deployment.** (This is because the automatic deployment Github user, `govuk-ci`, doesn't have permission to deploy directly to production since it's designed to deploy to integration and take advantage of deployment promotion.)

As with our other projects, when changes are merged, a new release tag is created. As we're deploying manually, there's technically no need to wait for that to complete, but it does make the action log easier to follow if we deploy releases.

## How deployment works

Since the project is run from a scheduled task (a K8s `CronJob`), its deployment process differs slightly from that of our apps and some details might prove useful to be aware of if they're not already familiar to you.

Everytime it's run on its schedule, a new Pod will pull a new copy of this project's Docker image from ECR. This differs from the way apps work in that an app's long-running Pods are reprovisioned with the new image once, during the deployment itself.

## Deploying to integration

Because the scheduled task only usually runs in production, some changes are required to enable a version to be deployed to integration (e.g. for testing),

* "integration" will have to be added to the list of target environments in [this repository's deploy workflow](https://github.com/alphagov/govuk-sli-collector/blob/main/.github/workflows/deploy.yml)
* [the production Helm charts configuration](https://github.com/alphagov/govuk-helm-charts/blob/1adc5596a3fa5df5b030c8248c338ec0293a4ea7/charts/app-config/values-production.yaml#L1275) will have to be copied into [the equivalent integration file](https://github.com/alphagov/govuk-helm-charts/blob/1adc5596a3fa5df5b030c8248c338ec0293a4ea7/charts/app-config/values-integration.yaml)

(If you only need integration temporarily, don't forget to revert these changes when you're done.)

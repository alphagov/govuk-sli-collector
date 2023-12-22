# GOV.UK SLI Collector

Collects data about GOV.UK services and produces SLI metrics for use in SLO dashboards.

## Nomenclature

**SLI — service level indicator**

> a carefully defined quantitative measure of some aspect of the level of service that is provided[^1]

**SLO — service level objective**

> a target value or range of values for a service level that is measured by an SLI[^1]

[^1]: [Site Reliability Engineering: How Google Runs Production Systems](https://sre.google/sre-book/service-level-objectives/)

## Technical documentation

This is a Ruby script.

In production, it's run from a scheduled task via its `./collect` executable.

### Running the linter

`bundle exec rubocop`

### Running the test suite

`bundle exec rspec`

### Deployments

**This project requires manual deployment.**

[More detailed information about deployments...](docs/deployments.md)

## Licence

[MIT License](LICENCE.txt)

<h1 align="center"><a>POSSUM workflows</a></h1>

[AusSRC](https://aussrc.org) contribution to the POSSUM data post-processing pipelines.

## Overview

The AusSRC contribution performs the following steps:

- Ionospheric correction
- Super-mosaicking
- Tiiling
- Stokes I component catalogue cross-matching
- [CADC](https://www.cadc-ccda.hia-iha.nrc-cnrc.gc.ca/en/) data transfer

We will write a [Nextflow](https://www.nextflow.io/) for these steps.

## Execution

The workflow can be triggered from the head node of a slurm cluster with configuration in `params.yaml` using the following command:

```
nextflow run main.nf -params-file params.yaml
```
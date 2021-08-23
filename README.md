<h1 align="center"><a>POSSUM workflows</a></h1>

[AusSRC](https://aussrc.org) contribution to the POSSUM data post-processing pipelines.

## Overview

The overall POSSUM post-processing pipeline can be seen in the diagram

![possum_pipeline](media/POSSUM_pipeline.pdf)

The AusSRC contribution performs the following steps:

- Ionospheric correction
- Super-mosaicking
- Tiiling
- Stokes I component catalogue cross-matching
- [CADC](https://www.cadc-ccda.hia-iha.nrc-cnrc.gc.ca/en/) data transfer

We will write a [Nextflow](https://www.nextflow.io/) for these steps.
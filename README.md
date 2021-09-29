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
nextflow run https://github.com/AusSRC/POSSUM_workflow -r main -params-file params.yaml -latest
```

### Parameters

User-defined parameters are provided to the Nextflow job through the `params.yaml` file. The content of the file looks something like the following

```
{
  "WORKDIR": "/mnt/shared/home/ashen/POSSUM/outputs",
  "CUBES": "/mnt/shared/possum/pilot1/image.restored.i.SB10007.contcube.fits,/mnt/shared/possum/pilot1/image.restored.i.SB10040.contcube.fits",
  "WALLABY_COMPONENTS_IMAGE": "aussrc/wallaby_scripts:latest",
  "LINMOS_OUTPUT_IMAGE_CUBE": "possum_mosaick",
  "LINMOS_CONFIG_FILENAME": "linmos.config",
  "LINMOS_CLUSTER_OPTIONS": "--ntasks=324 --ntasks-per-node=18"
}
```

Users can copy the content above as a starting point, and modify the values of the necessary parameters. The table below gives a description of each

| Parameter | Description |
| --- | --- |
| `WORKDIR` | The working directory that the Nextflow job will run in. Any temporary files created by Nextflow or the processes that are defined in the pipeline will appear inside of this directory. |
| `CUBES` | This is a comma-separated string of the image cubes (full path recommended) for mosaicking. |
| `WALLABY_COMPONENTS_IMAGE` | This is the docker image for the component scripts which are used to execute scripts in support of the mosaicking. In this case, the Python scripts for the downloading of image cubes from CASDA to the local file-system are found here. Note that we intend to refactor this, as these scripts are not exclusively used for WALLABY anymore. |
| `LINMOS_OUTPUT_IMAGE_CUBE` | The filename without extension for the product of the mosaicking. It will be written to the directory specified by `WORKDIR`. |
| `LINMOS_CONFIG_FILENAME` | The filename for the generated configuration file for executing `linmos`. This file is stored in the directory specified by `WORKDIR`. |
| `LINMOS_CLUSTER_OPTIONS` | These parameters specify the number of nodes across which to parallelise the mosaicking job. |
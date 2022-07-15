<h1 align="center"><a>POSSUM workflows</a></h1>

[AusSRC](https://aussrc.org) contribution to the POSSUM data post-processing pipelines.

## Overview

The AusSRC contribution performs the following steps:

- Convolution
- Ionospheric correction
- Super-mosaicking
- Tiling
- Stokes I component catalogue cross-matching
- [CADC](https://www.cadc-ccda.hia-iha.nrc-cnrc.gc.ca/en/) data transfer

We will write a [Nextflow](https://www.nextflow.io/) for these steps.

## Run

The workflow can be triggered from the head node of a slurm cluster with configuration in `params.yaml` using the following command:

```
nextflow run https://github.com/AusSRC/POSSUM_workflow -params-file params.yaml -profile carnaby -resume
```

### Configuration

Current recommended content of the `params.yaml` file

```
{
  "RUN_NAME": "pipeline_test",
  "WORKDIR": "/mnt/shared/home/ashen/POSSUM/runs",

  "I_CUBE": "image.restored.i.SB10040.contcube_3chan.fits",
  "Q_CUBE": "image.restored.q.SB10040.contcube_3chan.fits",
  "U_CUBE": "image.restored.u.SB10040.contcube_3chan.fits",

  "FRION_PREDICT_OUTFILE": "frion_predict.txt",
}
```

# Modules

## Tiling

Involves tiling and reprojection

### Configuration

Parameters required specifically for these steps include:

```
"IMAGE_CUBE": "/mnt/shared/home/ashen/POSSUM/tiling_reprojection/data/image.i.SB10040.cont.taylor.0.restored.fits",
"NSIDE": "32",
"TILING_OUTPUT_DIRECTORY": "headers",
"REPROJECTION_OUTPUT_DIRECTORY": "outputs",
"SINGULARITY_CACHEDIR": "/mnt/shared/possum/apps/singularity",
"MONTAGE_IMAGE": "docker://astroaustin/montage:latest",
"POSSUM_TILING_COMPONENT": "docker://astroaustin/generate_healpix_headers:latest"
```

Note error messages that are raised when running [Montage `mProjectCube`](http://montage.ipac.caltech.edu/docs/mProjectCube.html) are ignored and will not stop the execution of the pipeline because the program will raise an error when there is nothing in the region specified by the automatically generated header.

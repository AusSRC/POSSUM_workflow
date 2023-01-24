<h1 align="center"><a>POSSUM workflows</a></h1>

[AusSRC](https://aussrc.org) contribution to the POSSUM data pre-processing pipelines. The pre-processing of POSSUM data involves 

* Convolution to a common beam (18 arcseconds) [https://github.com/AlecThomson/RACS-tools]
* Ionospheric Faraday rotation correction (for Stokes Q and U) [https://github.com/CIRADA-Tools/FRion]
* Tiling [https://github.com/Sebokolodi/SkyTiles]

Then, complete HPX tiles are mosaicked together and uploaded to [CADC](https://www.cadc-ccda.hia-iha.nrc-cnrc.gc.ca/en/) in a final step. The workflow can be applied to MFS images or full spectral cubes. In this repository there are pipelines for:

* Pre-processing of MFS images (`mfs_preprocess.nf`)
* Mosaicking MFS images (`mfs_mosaic.nf`)
* Pre-processing of spectral cube images (`main.nf`)
* Mosacking spectral cube images (TBA)

## Run

To run the pipeline you need to specify a main script, a parameter file (or provide a list of parameters as arguments) and a deployment environment. Currently we only support `setonix` or `carnaby` (AusSRC development cluster) as the deployment environments. A template parameter file will be provided further

Example code for running these pipelines

```
nextflow run <FILE> -params-file <PARAMETER_FILE> -profile <ENVIRONMENT> -resume
```

or 

```
nextflow run https://github.com/AusSRC/POSSUM_workflow -main-script <PIPELINE> -params-file <PARAMETER_FILE> -profile <ENVIRONMENT> -resume
```

## Configuration

Current recommended content of the `params.yaml` file

```
{
  "RUN_NAME": "pipeline_test",
  "WORKDIR": "/mnt/shared/home/ashen/POSSUM/runs",

  "I_CUBE": "image.restored.i.SB10040.contcube_3chan.fits",
  "Q_CUBE": "image.restored.q.SB10040.contcube_3chan.fits",
  "U_CUBE": "image.restored.u.SB10040.contcube_3chan.fits",
  "WEIGHTS_CUBE": "weights.restored.i.SB10040.contcube_3chan.fits",

  "NSPLIT": "3",
  "NAN_TO_ZERO_NSPLIT": "3"
}
```

### Splitting

We use the [CASA imregrid](https://casadocs.readthedocs.io/en/v6.2.0/_modules/casatasks/analysis/imregrid.html) method to do tiling and reprojection onto a HPX grid. CASA has not been written to allow us to parallelise the tiling and reprojection over a number of nodes, and the size of our worker nodes is not sufficient to store entire cubes in memory (160 GB for band 1 images). We therefore need to split the cubes by frequency, run our program, then join at the end.

We do this twice in our full pre-processing pipeline code: for convolution to allow for using the `robust` method (requires setting nan to zero), and for `imregrid` to produce tiles as described earlier. The number of splits in frequency are specified by the `NAN_TO_ZERO_NSPLIT` and `NSPLIT` parameters respectively. Depending on the size of the cube and the size of the worker nodes, users will have to set these parameters to optimally utilise computing resources.


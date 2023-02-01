<h1 align="center"><a>POSSUM pipelines</a></h1>

[AusSRC](https://aussrc.org) contribution to the POSSUM data pre-processing pipelines. The pre-processing of POSSUM data involves

* Convolution to a common beam (18 arcseconds) [https://github.com/AlecThomson/RACS-tools]
* Ionospheric Faraday rotation correction (for Stokes Q and U) [https://github.com/CIRADA-Tools/FRion]
* Tiling [https://github.com/Sebokolodi/SkyTiles]

Then, complete HPX tiles are mosaicked together and uploaded to [CADC](https://www.cadc-ccda.hia-iha.nrc-cnrc.gc.ca/en/) in a final step. The workflow can be applied to MFS images or full spectral cubes. In this repository there are pipelines for:

* Pre-processing of MFS images (`mfs.nf`)
* Pre-processing of spectral cube images (`main.nf`)
* Mosaicking to complete tile images (`mosaic.nf`)

## Run

To run the pipeline you need to specify a main script, a parameter file (or provide a list of parameters as arguments) and a deployment. Currently we only support `setonix` or `carnaby` (AusSRC development cluster) as the deployments. A template parameter file will be provided further

Example code for running these pipelines

```
nextflow run <FILE> -params-file <PARAMETER_FILE> -profile <DEPLOYMENT> -resume
```

or

```
nextflow run https://github.com/AusSRC/POSSUM_workflow -main-script <PIPELINE> -params-file <PARAMETER_FILE> -profile <DEPLOYMENT> -resume
```

### File structure

This section describes how the output files are organised. All outputs are stored under the location specified by the `WORKDIR` parameter. Here is the structure beneath

```
.
├── ...
├── WORKDIR                             # Parent directory specified in params.WORKDIR
│   ├── <SBID_1>
│   ├── <SBID_2>
│   ├── ...
│   ├── <SBID_N>                        # A sub-folder for each SBID containing observation metadata
│   │   ├── evaluation_files            # Download evaluation files
│   │   └── hpx_tile_map.csv            # Generated map for HPX pixels covered by image cube (map file)
│   ├── TILE_COMPONENT_OUTPUT_DIR       # HPX tile components for each SBID are stored here
│   │   ├── i
│   │   ├── ...
│   │   └── q                           # Subdirectory for each stokes parameter
│   │       ├── <OBS_ID_1>
│   │       ├── ...
│   │       └── <OBS_ID_N>              # All tiled images a separated by observation ID
│   └── HPX_TILE_OUTPUT_DIR             # Complete tiles
└── ...
```

## Configuration

Current recommended content of the `params.yaml` file for running the `main.nf` pipeline

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

For processing MFS images (using the `mfs.nf` pipeline) only a subset of these parameters are required

```
{
  "SBID": "44127",
  "WORKDIR": "/mnt/shared/possum/runs/mfs",
  "I_CUBE": "image.i.POSSUM_0101-72A_band2.SB44127.cont.taylor.0.restored.conv.fits",
  "WEIGHTS_CUBE": "weights.i.POSSUM_0101-72A_band2.SB44127.cont.taylor.0.fits",
  "BEAMCON_NTASKS": "1"
}
```

**NOTE**: We set `BEAMCON_NTASKS = 1` to use only one node for beamcon for the MFS image (do not need to run this in parallel).

Once the data have been post-processed (either using the MFS or 3D pipelines) they are ready for mosaicking. The mosaicking step is executed manually. The user is therefore able to choose when to generate complete tiles with the tile components that have been created. The parameters required for this step include the `WORKDIR` (where all files are stored) and the `HPX_TILE_MAP` which describes the contributing observations for a given HPX tile. Other parameters dictate the output filename of the tiles.

```
{
  "WORKDIR": "/mnt/shared/possum/runs/mfs",
  "HPX_TILE_MAP": "/mnt/shared/possum/config/EMU-PILOT1-BAND2_SINGLE.csv",
  "HPX_TILE_PREFIX": "PSM",
  "CENTRAL_FREQUENCY": "944MHz",
  "TILE_NAME_VERSION_NUMBER": "v1.0"
}
```

### Splitting

We use the [CASA imregrid](https://casadocs.readthedocs.io/en/v6.2.0/_modules/casatasks/analysis/imregrid.html) method to do tiling and reprojection onto a HPX grid. CASA has not been written to allow us to parallelise the tiling and reprojection over a number of nodes, and the size of our worker nodes is not sufficient to store entire cubes in memory (160 GB for band 1 images). We therefore need to split the cubes by frequency, run our program, then join at the end.

We do this twice in our full pre-processing pipeline code: for convolution to allow for using the `robust` method (requires setting nan to zero), and for `imregrid` to produce tiles as described earlier. The number of splits in frequency are specified by the `NAN_TO_ZERO_NSPLIT` and `NSPLIT` parameters respectively. Depending on the size of the cube and the size of the worker nodes, users will have to set these parameters to optimally utilise computing resources.


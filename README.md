# POSSUM pipelines

[AusSRC](https://aussrc.org) contribution to the POSSUM data pre-processing pipelines. The pre-processing of POSSUM data involves

* Convolution to a common beam (20 arcseconds) [https://github.com/AlecThomson/RACS-tools]
* Ionospheric Faraday rotation correction (for Stokes Q and U) [https://github.com/CIRADA-Tools/FRion]
* Tiling [https://github.com/Sebokolodi/SkyTiles]

Then, complete HPX tiles are mosaicked together and uploaded to [CADC](https://www.cadc-ccda.hia-iha.nrc-cnrc.gc.ca/en/) in a final step. The workflow can be applied to MFS images or full spectral cubes. In this repository there are pipelines for:

* Pre-processing of MFS images (`mfs.nf`)
* Pre-processing of spectral cube images (`main.nf`)
* Mosaicking to complete tile images (`mosaic.nf`)

## Running Pipelines

To run the pipeline you need to specify a main script, a parameter file (or provide a list of parameters as arguments) and a deployment. Currently we only support `setonix` as the deployments.

The pipeline needs access to a CASDA credentials file `casda.ini`:

```
[CASDA]
username =
password =
```

### Spectral cube images (`main.nf`)

```
#!/bin/bash
#SBATCH --account=<Pawsey account>
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=32G
#SBATCH --time=24:00:00

module load singularity/4.1.0-slurm
module load nextflow/23.10.0

export MPICH_OFI_STARTUP_CONNECT=1
export MPICH_OFI_VERBOSE=1

export FI_CXI_DEFAULT_VNI=$(od -vAn -N4 -tu < /dev/urandom)

nextflow run main.nf -profile setonix --CASDA_CREDENTIALS=<path to CASDA credentials> --SBID <SBID>
```

Deploy

```
sbatch script.sh
```

### MFS images (`mfs.nf`)

```
#!/bin/bash
#SBATCH --account=<Pawsey account>
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=32G
#SBATCH --time=24:00:00

module load singularity/4.1.0-slurm
module load nextflow/23.10.0

export MPICH_OFI_STARTUP_CONNECT=1
export MPICH_OFI_VERBOSE=1

export FI_CXI_DEFAULT_VNI=$(od -vAn -N4 -tu < /dev/urandom)

nextflow run mfs.nf -profile setonix --CASDA_CREDENTIALS=<path to CASDA credentials> --SBID <SBID>
```

Deploy

```
sbatch script.sh
```


### File structure

This section describes how the output files are organised. All outputs are stored under the location specified by the `WORKDIR` parameter. Here is the structure beneath

```
.
├── ...
└── WORKDIR                             # Parent directory specified in params.WORKDIR
    ├── <SBID_1>
    ├── <SBID_2>
    ├── ...
    ├── <SBID_N>                        # A sub-folder for each SBID containing observation metadata
    │   ├── evaluation_files            # Download evaluation files
    │   └── hpx_tile_map.csv            # Generated map for HPX pixels covered by image cube (map file)
    └── TILE_COMPONENT_OUTPUT_DIR       # HPX tile components for each SBID are stored here
        ├── <OBS_ID_1>
        ├── ...
        └── <OBS_ID_N>                  # All tiled images a separated by observation ID
            ├── i                       # Subdirectory for each stokes parameter
            ├── ...
            └── q

```

### Splitting

We use the [CASA imregrid](https://casadocs.readthedocs.io/en/v6.2.0/_modules/casatasks/analysis/imregrid.html) method to do tiling and reprojection onto a HPX grid. CASA has not been written to allow us to parallelise the tiling and reprojection over a number of nodes, and the size of our worker nodes is not sufficient to store entire cubes in memory (160 GB for band 1 images). We therefore need to split the cubes by frequency, run our program, then join at the end.

We do this twice in our full pre-processing pipeline code: for convolution to allow for using the `robust` method (requires setting nan to zero), and for `imregrid` to produce tiles as described earlier. The number of splits in frequency are specified by the `NAN_TO_ZERO_NSPLIT` and `NSPLIT` parameters respectively. Depending on the size of the cube and the size of the worker nodes, users will have to set these parameters to optimally utilise computing resources.

### Download NASA CDDIS data

The `FRion predict` step of the pipeline (only for `main.nf`) requires you to download data from NASA CDDIS. To do this you will need to create an [EarthData](https://urs.earthdata.nasa.gov/) account. Then you will create a `.netrc` file containing those credentials with the following content:

```
machine urs.earthdata.nasa.gov login <username> password <password>
```

Then you will need to change the file access pattern and move it to the home directory on the cluster which you intend to deploy the pipeline

```
chmod 600 .netrc
mv .netrc ~/
```

For more info: https://urs.earthdata.nasa.gov/documentation/for_users

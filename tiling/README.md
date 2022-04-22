# Tiling and reprojection

Involves

## Configuration

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

#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

// Check output and header directories exist and are empty
process pre_check {
    input:
        val image_cubes

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash

        # Check image cube files exist
        [ ! -f ${params.IMAGE_CUBES} ] && { echo "Image cube not found"; exit 1; }

        exit 0
        """
}

// Run Beamcon_3D for convolution
process beamcon {
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"
    clusterOptions = "--nodes=12 --ntasks-per-node=24 --cpus-per-task=1"

    input:
        val image_cube
        val pre_check
    
    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash

        singularity pull ${params.SINGULARITY_CACHEDIR}/racs-tools.img ${params.RACS_TOOLS_IMAGE}
        singularity exec \
            --bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} \
            ${params.SINGULARITY_CACHEDIR}/racs-tools.img \
            mpirun beamcon_3D --mode total --bmaj 13 --bmin 13 --bpa 0 -v ${image_cube}
        """
}


// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow convolution {
    take: image_cubes

    main:
        pre_check(image_cubes)
        beamcon(image_cubes, pre_check.out.stdout)
}

// ----------------------------------------------------------------------------------------
